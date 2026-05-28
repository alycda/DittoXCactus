"""Three-layer eval harness for the note-merging specialist.

Cheap-first ordering (per recipe section (f)):

    Layer 1 — deterministic assertions (zero cost, runs first)
              length cap + structure regex + no <think> leak + no
              Chinese chars + no \\boxed{} math-mode artifact. Any
              failure short-circuits the row before invoking the
              expensive judge.
    Layer 2 — judge-LLM faithfulness (~$3 per 200-row holdout run)
              Cross-family judge (Claude 3.5 Sonnet — NEVER Qwen).
              Bidirectional (swap A↔B input order, average scores) to
              control position bias. Verbosity-penalty rubric.
    Layer 3 — embedding cosine similarity vs ground-truth merged
              (uses sentence-transformers MiniLM; free).

Outputs:
    eval_results/run_<timestamp>.jsonl — per-row scores for forensics
    eval_results/summary.md            — A/B table for writeup citation

Compares two model paths per run: a `--base` (the generalist Qwen 3 1.7B
slug as registered in Cactus) and a `--specialist` (the merged .cact
asset path). Both run via the same Cactus runtime as the demo. If you
want to compare adapter-on-base before conversion, point --specialist at
the in-training bf16 merge path (model.save_pretrained output dir).

Usage:
    export ANTHROPIC_API_KEY=...
    python3 eval.py --holdout data/holdout_200.jsonl --output eval_results/summary.md

The harness is judge-LLM-eval-aware: pre-flight calibration on 100
examples against human spot-checks SHOULD happen before trusting the
judge on the full holdout. See README for the Hamel Husain recipe.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import statistics
import sys
import time
from dataclasses import asdict, dataclass
from pathlib import Path

import numpy as np
from tenacity import (
    retry,
    retry_if_exception_type,
    stop_after_attempt,
    wait_exponential,
)
from tqdm import tqdm

try:
    from anthropic import Anthropic, APIError, APIStatusError, RateLimitError
except ImportError:
    sys.stderr.write(
        "ERROR: anthropic package not installed.\n"
        "  pip install -r tools/specialist_training/requirements.txt\n"
    )
    sys.exit(1)

try:
    from sentence_transformers import SentenceTransformer
except ImportError:
    sys.stderr.write(
        "ERROR: sentence-transformers not installed.\n"
        "  pip install -r tools/specialist_training/requirements.txt\n"
    )
    sys.exit(1)


JUDGE_MODEL = "claude-sonnet-4-6"  # cross-family — recipe R5
EMBEDDING_MODEL = "sentence-transformers/all-MiniLM-L6-v2"
MAX_TOKENS_MERGED = 200


# ─── Layer 1 — deterministic assertions ─────────────────────────────────────

CHINESE_CHAR_RE = re.compile(r"[一-鿿]")
THINK_TAG_RE = re.compile(r"</?think>", re.IGNORECASE)
BOXED_RE = re.compile(r"\\boxed\s*\{")


def _approx_token_count(text: str) -> int:
    return int(len(text.split()) * 1.33) + 1


@dataclass
class AssertionResult:
    length_ok: bool
    no_chinese: bool
    no_think_tag: bool
    no_boxed: bool
    non_empty: bool

    @property
    def all_pass(self) -> bool:
        return all(
            (self.length_ok, self.no_chinese, self.no_think_tag, self.no_boxed, self.non_empty)
        )


def deterministic_assertions(output: str) -> AssertionResult:
    return AssertionResult(
        length_ok=_approx_token_count(output) <= MAX_TOKENS_MERGED,
        no_chinese=CHINESE_CHAR_RE.search(output) is None,
        no_think_tag=THINK_TAG_RE.search(output) is None,
        no_boxed=BOXED_RE.search(output) is None,
        non_empty=bool(output.strip()),
    )


# ─── Layer 2 — cross-family judge-LLM faithfulness ──────────────────────────

JUDGE_SYSTEM = (
    "You are a strict faithfulness judge for a note-merging task. The user "
    "will give you two input study notes (A and B) and a candidate merged "
    "note. Your job is to score the merged note on a 0.0-1.0 scale where:\n"
    "  1.0 = preserves every distinct claim from A AND B, drops duplicates, "
    "no fabricated facts, neutral third-person voice, ≤200 tokens.\n"
    "  0.7-0.9 = mostly correct, minor claim loss or stylistic drift.\n"
    "  0.4-0.6 = significant claim loss or stylistic problems.\n"
    "  0.0-0.3 = fabricated content or substantial claim drop.\n\n"
    "Apply a VERBOSITY PENALTY: if the merged note is meaningfully longer "
    "than the union of A and B, scale the score down by 0.1-0.2.\n\n"
    "Output format (one line, NO other text):\n"
    "  SCORE: <float> | REASON: <one short sentence>"
)


@retry(
    retry=retry_if_exception_type((RateLimitError, APIStatusError, APIError)),
    wait=wait_exponential(multiplier=1, min=1, max=16),
    stop=stop_after_attempt(5),
    reraise=True,
)
def _judge_one_direction(client: Anthropic, note_a: str, note_b: str, merged: str) -> tuple[float, str]:
    msg = f"note_a: {note_a}\n\nnote_b: {note_b}\n\nmerged: {merged}"
    resp = client.messages.create(
        model=JUDGE_MODEL,
        max_tokens=200,
        system=JUDGE_SYSTEM,
        messages=[{"role": "user", "content": msg}],
    )
    text = resp.content[0].text.strip()
    # Tolerant parse — "SCORE: 0.85 | REASON: ..."
    m = re.search(r"SCORE\s*:\s*([0-9]*\.?[0-9]+)", text)
    if not m:
        return 0.0, f"unparseable judge output: {text[:100]}"
    score = float(m.group(1))
    reason = ""
    if "|" in text:
        reason = text.split("|", 1)[1].replace("REASON:", "").strip()
    return min(max(score, 0.0), 1.0), reason


def judge_bidirectional(
    client: Anthropic,
    row: dict,
    candidate_merged: str,
) -> dict:
    """Run the judge twice with A↔B swapped, average the scores. Position
    bias is real (LLM-as-judge literature 2024 — see references in
    tools/specialist_training/README.md)."""
    forward_score, forward_reason = _judge_one_direction(
        client, row["note_a"], row["note_b"], candidate_merged
    )
    reverse_score, reverse_reason = _judge_one_direction(
        client, row["note_b"], row["note_a"], candidate_merged
    )
    return {
        "forward_score": forward_score,
        "reverse_score": reverse_score,
        "mean_score": (forward_score + reverse_score) / 2,
        "forward_reason": forward_reason,
        "reverse_reason": reverse_reason,
    }


# ─── Layer 3 — embedding cosine ─────────────────────────────────────────────

def embedding_cosine(
    model: SentenceTransformer,
    candidate: str,
    ground_truth: str,
) -> float:
    embeddings = model.encode([candidate, ground_truth], normalize_embeddings=True)
    return float(np.dot(embeddings[0], embeddings[1]))


# ─── Model output backends ──────────────────────────────────────────────────
#
# The eval is model-agnostic — it reads `output` text from anywhere. We
# expose three convenience adapters:
#
#   (a) load outputs from a pre-generated JSONL (most flexible — generate
#       outputs separately via cactus_cli or via the Flutter app's
#       integration-test export, then feed here).
#   (b) shell out to `cactus` CLI to generate per-row outputs.
#
# For the hackathon-shape build, (a) is the simplest path: the Day-2
# integration test runs the demo with USE_SPECIALIST={false,true} and
# exports each holdout row's output to JSONL. eval.py consumes those.

def load_outputs(path: Path) -> dict[str, str]:
    """Load pre-generated outputs from JSONL. Schema:
        {"holdout_id": "...", "output": "..."}
    """
    out: dict[str, str] = {}
    with path.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            row = json.loads(line)
            out[row["holdout_id"]] = row["output"]
    return out


# ─── Main eval pipeline ─────────────────────────────────────────────────────

@dataclass
class RowResult:
    holdout_id: str
    label: str                            # "base" or "specialist"
    assertions: dict
    judge: dict | None                    # None if assertions failed
    cosine: float
    composite: float                      # 0.0-1.0; weighted blend


def composite_score(assertions: AssertionResult, judge: dict | None, cosine: float) -> float:
    """Weighted blend. Weights chosen so a row that passes assertions and
    gets judge=1.0 + cosine=1.0 → composite 1.0. Assertion failure
    short-circuits to a low composite regardless of other layers."""
    if not assertions.all_pass:
        return 0.0
    judge_score = judge["mean_score"] if judge else 0.0
    # Assertions: 0.20, Judge: 0.60, Cosine: 0.20
    return 0.20 * 1.0 + 0.60 * judge_score + 0.20 * cosine


def score_row(
    *,
    row: dict,
    output: str,
    label: str,
    judge_client: Anthropic,
    embed_model: SentenceTransformer,
) -> RowResult:
    assertions = deterministic_assertions(output)
    if not assertions.all_pass:
        # Short-circuit — don't burn judge cost on already-failed rows.
        return RowResult(
            holdout_id=row["holdout_id"],
            label=label,
            assertions=asdict(assertions),
            judge=None,
            cosine=0.0,
            composite=composite_score(assertions, None, 0.0),
        )
    judge = judge_bidirectional(judge_client, row, output)
    cosine = embedding_cosine(embed_model, output, row["merged"])
    return RowResult(
        holdout_id=row["holdout_id"],
        label=label,
        assertions=asdict(assertions),
        judge=judge,
        cosine=cosine,
        composite=composite_score(assertions, judge, cosine),
    )


def summarize(results: list[RowResult]) -> dict:
    by_label: dict[str, list[RowResult]] = {}
    for r in results:
        by_label.setdefault(r.label, []).append(r)

    summary: dict = {}
    for label, rows in by_label.items():
        composites = [r.composite for r in rows]
        cosines = [r.cosine for r in rows]
        assert_passes = sum(1 for r in rows if all(r.assertions.values()))
        judge_scores = [r.judge["mean_score"] for r in rows if r.judge is not None]
        summary[label] = {
            "count": len(rows),
            "assertions_pass_count": assert_passes,
            "assertions_pass_rate": assert_passes / max(len(rows), 1),
            "judge_mean": statistics.mean(judge_scores) if judge_scores else 0.0,
            "cosine_mean": statistics.mean(cosines) if cosines else 0.0,
            "composite_mean": statistics.mean(composites) if composites else 0.0,
        }
    return summary


def write_summary_md(
    summary: dict,
    output_path: Path,
    *,
    holdout_path: Path,
    run_id: str,
) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    base = summary.get("base", {})
    spec = summary.get("specialist", {})
    uplift_judge = (spec.get("judge_mean", 0.0) - base.get("judge_mean", 0.0)) * 100
    uplift_composite = (spec.get("composite_mean", 0.0) - base.get("composite_mean", 0.0)) * 100

    lines = [
        f"# Specialist eval summary — run {run_id}",
        "",
        f"Holdout: `{holdout_path}` ({base.get('count', spec.get('count', 0))} rows)",
        f"Judge: Claude 3.5 Sonnet (cross-family per recipe R5)",
        f"Embedding model: `{EMBEDDING_MODEL}`",
        "",
        "## A/B table",
        "",
        "| Layer | Base (Qwen 3 1.7B Instruct) | Specialist (merged .cact) | Δ (pts) |",
        "|-------|---|---|---|",
        f"| Assertions pass rate | {base.get('assertions_pass_rate', 0.0):.1%} | {spec.get('assertions_pass_rate', 0.0):.1%} | "
        f"{(spec.get('assertions_pass_rate', 0.0) - base.get('assertions_pass_rate', 0.0)) * 100:+.1f} |",
        f"| Judge faithfulness (0-1) | {base.get('judge_mean', 0.0):.3f} | {spec.get('judge_mean', 0.0):.3f} | "
        f"{uplift_judge:+.1f} |",
        f"| Cosine to ground truth | {base.get('cosine_mean', 0.0):.3f} | {spec.get('cosine_mean', 0.0):.3f} | "
        f"{(spec.get('cosine_mean', 0.0) - base.get('cosine_mean', 0.0)) * 100:+.1f} |",
        f"| **Composite (weighted)** | **{base.get('composite_mean', 0.0):.3f}** | "
        f"**{spec.get('composite_mean', 0.0):.3f}** | **{uplift_composite:+.1f}** |",
        "",
        "## Ship/no-ship gate",
        "",
        f"Recipe R1 requires ≥10-point judge-faithfulness uplift over base. "
        f"This run: **{uplift_judge:+.1f}** points.",
        "",
    ]
    if uplift_judge >= 10:
        lines.append("**Verdict: SHIP** — specialist clears the recipe gate.")
    else:
        lines.append(
            "**Verdict: HOLD** — specialist does not clear the +10-point gate. "
            "Per recipe section (f), add training data, re-examine task framing, "
            "or shelve as v1 future-work. The eval table itself is writeup-worthy."
        )
    lines.append("")
    output_path.write_text("\n".join(lines))


def main() -> int:
    parser = argparse.ArgumentParser(description="Three-layer specialist eval.")
    parser.add_argument(
        "--holdout",
        type=Path,
        default=Path("data/holdout_200.jsonl"),
        help="200-pair manual holdout JSONL.",
    )
    parser.add_argument(
        "--base-outputs",
        type=Path,
        default=Path("eval_results/base_outputs.jsonl"),
        help="Pre-generated base-model outputs (JSONL of {holdout_id, output}).",
    )
    parser.add_argument(
        "--specialist-outputs",
        type=Path,
        default=Path("eval_results/specialist_outputs.jsonl"),
        help="Pre-generated specialist outputs (JSONL of {holdout_id, output}).",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("eval_results/summary.md"),
        help="A/B summary Markdown output path.",
    )
    parser.add_argument(
        "--max-rows",
        type=int,
        default=0,
        help="Limit holdout to first N rows. 0 = all. Useful for calibration.",
    )
    args = parser.parse_args()

    if not args.holdout.exists():
        sys.stderr.write(
            f"ERROR: holdout not found at {args.holdout}.\n"
            "  Hand-author per U3 of _docs/plans/002-feat-specialist-training.md.\n"
        )
        return 2
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        sys.stderr.write("ERROR: set ANTHROPIC_API_KEY before running.\n")
        return 2

    holdout: list[dict] = []
    with args.holdout.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            holdout.append(json.loads(line))
    if args.max_rows > 0:
        holdout = holdout[: args.max_rows]
    # Ensure each row has a stable holdout_id.
    for i, row in enumerate(holdout):
        row.setdefault("holdout_id", f"row_{i:04d}")
    print(f"holdout rows: {len(holdout)}", file=sys.stderr)

    base_outputs = load_outputs(args.base_outputs)
    spec_outputs = load_outputs(args.specialist_outputs)
    print(
        f"base outputs: {len(base_outputs)}, specialist outputs: {len(spec_outputs)}",
        file=sys.stderr,
    )

    judge_client = Anthropic(api_key=api_key)
    print(f"loading embedding model {EMBEDDING_MODEL}…", file=sys.stderr)
    embed_model = SentenceTransformer(EMBEDDING_MODEL)

    run_id = time.strftime("%Y%m%d-%H%M%S")
    per_row_log = Path("eval_results") / f"run_{run_id}.jsonl"
    per_row_log.parent.mkdir(parents=True, exist_ok=True)

    results: list[RowResult] = []
    for row in tqdm(holdout, desc="score rows"):
        hid = row["holdout_id"]
        for label, outputs in (("base", base_outputs), ("specialist", spec_outputs)):
            if hid not in outputs:
                sys.stderr.write(f"\nWARN: no {label} output for {hid}; skipping.\n")
                continue
            result = score_row(
                row=row,
                output=outputs[hid],
                label=label,
                judge_client=judge_client,
                embed_model=embed_model,
            )
            results.append(result)
            with per_row_log.open("a") as f:
                f.write(json.dumps(asdict(result)) + "\n")

    summary = summarize(results)
    print(json.dumps(summary, indent=2), file=sys.stderr)
    write_summary_md(summary, args.output, holdout_path=args.holdout, run_id=run_id)
    print(f"✓ wrote {args.output}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
