"""Filter the raw synthetic JSONL down to a clean training set.

Three filter passes per recipe section (c):
    1. Embedding-cluster dedup — drop rows whose `merged` embedding has
       cosine ≥0.95 with a kept row's `merged` embedding.
    2. Judge-LLM completeness — every claim in note_a + note_b is
       attributable in `merged` (cross-family judge: Claude 3.5 Sonnet).
    3. Length cap — `merged` ≤ 200 tokens.

Then stratifies the output across {claim-heavy, definition-heavy, list-heavy}
buckets (using the teacher's self-labelled topic_bucket field) and stops
once each bucket has approximately equal count up to the target.

Usage:
    export ANTHROPIC_API_KEY=...
    python3 filter_synthetic.py --input data/synthetic_raw.jsonl --output data/synthetic_filtered.jsonl

The judge pass is the expensive layer (~$0.50-1.50 per 1k rows at Claude 3.5
Sonnet pricing) — we run the cheap passes first to short-circuit.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from collections import Counter
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
    from anthropic import Anthropic, APIError as AnthropicAPIError, APIStatusError, RateLimitError
except ImportError:
    sys.stderr.write(
        "ERROR: anthropic package not installed. Run:\n"
        "  pip install -r tools/specialist_training/requirements.txt\n"
    )
    sys.exit(1)

try:
    from sentence_transformers import SentenceTransformer
except ImportError:
    sys.stderr.write(
        "ERROR: sentence-transformers not installed. Run:\n"
        "  pip install -r tools/specialist_training/requirements.txt\n"
    )
    sys.exit(1)


JUDGE_MODEL = "claude-sonnet-4-6"  # cross-family; never use Qwen-as-judge
EMBEDDING_MODEL = "sentence-transformers/all-MiniLM-L6-v2"  # 22M params, fast, free
DEDUP_THRESHOLD = 0.95
MAX_TOKENS_MERGED = 200  # approximate; word count proxy
DEFAULT_TARGET = 1500
BUCKETS = ("claim-heavy", "definition-heavy", "list-heavy")


# ─── Layer 3: length cap ────────────────────────────────────────────────────

def _approx_token_count(text: str) -> int:
    """Conservative token proxy: 1 token ≈ 0.75 words for English chat-tuned
    tokenizers. Counting words and adding 33% gives a tight upper bound
    without needing the actual tokenizer."""
    word_count = len(text.split())
    return int(word_count * 1.33) + 1


def length_pass(rows: list[dict]) -> list[dict]:
    kept = []
    for row in rows:
        if _approx_token_count(row.get("merged", "")) <= MAX_TOKENS_MERGED:
            kept.append(row)
    return kept


# ─── Layer 1: embedding-cluster dedup ───────────────────────────────────────

def dedup_pass(rows: list[dict]) -> list[dict]:
    if not rows:
        return rows
    print(f"loading embedding model {EMBEDDING_MODEL}…", file=sys.stderr)
    model = SentenceTransformer(EMBEDDING_MODEL)
    print("embedding merged notes…", file=sys.stderr)
    embeddings = model.encode(
        [r["merged"] for r in rows],
        show_progress_bar=True,
        normalize_embeddings=True,
    )

    kept_rows: list[dict] = []
    kept_embeddings: list[np.ndarray] = []

    for row, emb in zip(rows, embeddings, strict=True):
        if not kept_embeddings:
            kept_rows.append(row)
            kept_embeddings.append(emb)
            continue
        # All kept embeddings are normalized → cosine == dot product.
        sims = np.dot(np.stack(kept_embeddings), emb)
        if sims.max() < DEDUP_THRESHOLD:
            kept_rows.append(row)
            kept_embeddings.append(emb)
    return kept_rows


# ─── Layer 2: judge-LLM completeness ────────────────────────────────────────

JUDGE_SYSTEM = (
    "You are a strict eval judge. The user will give you two short input "
    "notes (note_a and note_b) and a merged candidate note. Decide whether "
    "the merged note preserves every distinct factual claim from note_a "
    "AND note_b. Drop trivial duplicates between A and B. Reply with one "
    "of: PASS, FAIL_MISSING (merged drops claims), FAIL_FABRICATED (merged "
    "introduces new claims not in A or B). Then a one-sentence reason. "
    "Format: '<verdict>: <reason>'."
)


@retry(
    retry=retry_if_exception_type((RateLimitError, APIStatusError, AnthropicAPIError)),
    wait=wait_exponential(multiplier=1, min=1, max=16),
    stop=stop_after_attempt(5),
    reraise=True,
)
def _judge_one(client: Anthropic, row: dict) -> tuple[str, str]:
    user_msg = (
        f"note_a: {row['note_a']}\n\n"
        f"note_b: {row['note_b']}\n\n"
        f"merged: {row['merged']}"
    )
    resp = client.messages.create(
        model=JUDGE_MODEL,
        max_tokens=200,
        system=JUDGE_SYSTEM,
        messages=[{"role": "user", "content": user_msg}],
    )
    text = resp.content[0].text.strip()
    verdict = text.split(":", 1)[0].strip().upper()
    reason = text.split(":", 1)[1].strip() if ":" in text else ""
    return verdict, reason


def judge_pass(rows: list[dict], client: Anthropic) -> list[dict]:
    kept = []
    for row in tqdm(rows, desc="judge"):
        try:
            verdict, reason = _judge_one(client, row)
        except Exception as exc:  # noqa: BLE001
            sys.stderr.write(f"\njudge error on row, skipping: {exc}\n")
            continue
        if verdict == "PASS":
            kept.append(row)
        else:
            # Could log to a discards.jsonl for manual review; skip for now.
            pass
    return kept


# ─── Stratification ─────────────────────────────────────────────────────────

def stratify(rows: list[dict], target_total: int) -> list[dict]:
    """Take up to target_total rows, balanced across buckets. Rows without a
    recognized bucket are kept in proportion to their occurrence (no
    re-bucketing — that would lie about the teacher's labels)."""
    per_bucket_target = target_total // len(BUCKETS)
    by_bucket: dict[str, list[dict]] = {b: [] for b in BUCKETS}
    other: list[dict] = []
    for row in rows:
        bucket = row.get("topic_bucket", "").strip()
        if bucket in by_bucket:
            by_bucket[bucket].append(row)
        else:
            other.append(row)

    output: list[dict] = []
    for bucket in BUCKETS:
        output.extend(by_bucket[bucket][:per_bucket_target])
    # Backfill with "other" if buckets underfill.
    remaining = target_total - len(output)
    if remaining > 0:
        output.extend(other[:remaining])
    return output


# ─── Main ───────────────────────────────────────────────────────────────────

def main() -> int:
    parser = argparse.ArgumentParser(
        description="Filter synthetic note-merging data to a clean training set."
    )
    parser.add_argument(
        "--input",
        type=Path,
        default=Path("data/synthetic_raw.jsonl"),
        help="Raw synthetic JSONL from generate_synthetic.py.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("data/synthetic_filtered.jsonl"),
        help="Clean output JSONL. Overwritten on each run.",
    )
    parser.add_argument(
        "--target",
        type=int,
        default=DEFAULT_TARGET,
        help="Target row count post-stratification.",
    )
    parser.add_argument(
        "--skip-judge",
        action="store_true",
        help="Skip the (expensive) judge-LLM completeness pass. Use only when "
        "calibrating filter parameters on a small batch.",
    )
    args = parser.parse_args()

    if not args.input.exists():
        sys.stderr.write(f"ERROR: input not found: {args.input}\n")
        return 2

    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not args.skip_judge and not api_key:
        sys.stderr.write("ERROR: set ANTHROPIC_API_KEY (or pass --skip-judge).\n")
        return 2

    rows: list[dict] = []
    with args.input.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    print(f"input rows: {len(rows)}", file=sys.stderr)

    after_length = length_pass(rows)
    print(f"after length pass: {len(after_length)}", file=sys.stderr)

    after_dedup = dedup_pass(after_length)
    print(f"after dedup pass: {len(after_dedup)}", file=sys.stderr)

    if args.skip_judge:
        print("skipping judge pass (--skip-judge)", file=sys.stderr)
        after_judge = after_dedup
    else:
        client = Anthropic(api_key=api_key)
        after_judge = judge_pass(after_dedup, client)
        print(f"after judge pass: {len(after_judge)}", file=sys.stderr)

    final = stratify(after_judge, args.target)
    bucket_counts = Counter(r.get("topic_bucket", "?") for r in final)
    print(f"final rows: {len(final)}", file=sys.stderr)
    print(f"bucket distribution: {dict(bucket_counts)}", file=sys.stderr)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w") as f:
        for row in final:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")
    print(f"wrote {args.output}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
