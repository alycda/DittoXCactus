#!/usr/bin/env python3
"""T1-Cactus — flashcard fidelity across Cactus-catalog completion models.

Counterpart to t1.py (which used ollama). Drives each candidate through the
Cactus Python bindings on the same prompt as `lib/prompts/flashcard_gen.dart`.

**INT4 caveat.** Cactus CLI defaults to `--precision INT4`, the on-device demo
runs at INT8 (`quantization=8` in the catalog). Reconversion to INT8/FP16
fails locally (`Qwen3ForCausalLM` import error in the CLI's transformers env).
INT4 is the only locally-reproducible precision. Compare cross-model within
this table, but do *not* use absolute scores against ollama's full-precision
T1 table — different precision regime.

Output: `_docs/notes/t1-cactus-results.md`.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import time
import uuid
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
NS = uuid.UUID("7c2b8e4a-3d5f-4b2c-8e6d-1a4f9e8c7b30")
WEIGHTS_ROOT = Path("/opt/homebrew/Cellar/cactus/1.14_1/libexec/weights")

# slug → weights dir on disk
CANDIDATES = {
    "qwen3-1.7":           WEIGHTS_ROOT / "qwen3-1.7b",        # incumbent
    "qwen3-0.6":           WEIGHTS_ROOT / "qwen3-0.6b",
    "lfm2-700m":           WEIGHTS_ROOT / "lfm2-700m",
    "lfm2.5-1.2b":         WEIGHTS_ROOT / "lfm2.5-1.2b-instruct",
    "gemma3-1b":           WEIGHTS_ROOT / "gemma-3-1b-it",
}

SYSTEM_MSG = """You are a careful study buddy. You make study flashcards from short notes.

Output rules:
- Output ONLY flashcards. No reasoning, no preamble.
- Each card has three lines in this exact format:
  Q: <a clear question>
  A: <a short answer, one sentence — under 30 words>
  SOURCE: <one or more note ids, comma-separated>
- The note ids are the bracketed strings at the start of each note line
  (for example, `[400ba2af-...]`). Use them verbatim in SOURCE. Never
  write labels like "Note 1" — those are not ids.
- No markdown emphasis (no **Q:**, no italics). No JSON. No bullets. No numbering.
- No LaTeX (no \\boxed, no \\begin{aligned}, no math-display blocks).
- No <think> blocks. No chain-of-thought.
- The answer must be a direct factual statement. No words like "Wait,"
  "Hmm,", "Actually,", "Let me check", "perhaps", or "I think" — those
  are reasoning, not an answer.
- Every card must be about the Topic. Skip facts in the notes that are
  off-topic, even if they are interesting.
- Do not make up facts. If the notes do not support a claim, do not make the claim.
- Avoid near-duplicate questions.

Example:

Q: What is escape velocity?
A: The minimum speed needed to break free of a body's gravity without further propulsion.
SOURCE: 400ba2af-8714-5fbb-ae78-b7858c60eaf7"""

QUERIES = [
    ("inner planets", "a", "on-topic"),
    ("outer planets", "b", "on-topic"),
    ("the Sun", None, "cross-corpus"),
    ("Roman emperors", "empty", "off-corpus"),
]


def load_corpus() -> list[dict]:
    notes: list[dict] = []
    for role in ("a", "b"):
        path = REPO_ROOT / "assets" / f"seed_notes_{role}.json"
        for n in json.loads(path.read_text()):
            nid = str(uuid.uuid5(NS, f"{n['contributor']}|{n['topic']}|{n['createdAt']}"))
            notes.append({"id": nid, "topic": n["topic"], "body": n["body"],
                          "contributor": n["contributor"], "role": role})
    return notes


def filter_retrieved(corpus, filt):
    if filt == "empty":
        return []
    if filt is None:
        return list(corpus)
    return [n for n in corpus if n["role"] == filt]


def build_user_message(topic, n, retrieved):
    lines = [f"Topic: {topic}", f"Number of flashcards (N): {n}", "",
             "Notes (each line starts with [<id>] — copy these ids verbatim into SOURCE):"]
    if not retrieved:
        lines.append("(no notes available — output nothing.)")
        return "\n".join(lines)
    for r in retrieved:
        lines.append(f"[{r['id']}] {r['body']}")
    lines.append("")
    word = "flashcard" if n == 1 else "flashcards"
    lines.append(
        f'Now output exactly {n} {word} in the Q: / A: / SOURCE: format, '
        f'each about "{topic}". Start with "Q:" on its own line. No reasoning, no preamble.'
    )
    return "\n".join(lines)


QUIRK_PATTERNS: list[tuple[str, re.Pattern]] = [
    ("think_block",       re.compile(r"<think>", re.IGNORECASE)),
    ("boxed_math",        re.compile(r"\\boxed|\\begin\{aligned\}|\\text\{")),
    ("cjk_drift",         re.compile(r"[一-鿿]")),
    ("markdown_emphasis", re.compile(r"\*\*[QAS]")),
    ("bullet_prefix",     re.compile(r"^\s*[-*]\s*Q:", re.MULTILINE)),
    ("numbered_prefix",   re.compile(r"^\s*\d+[.)]\s*Q:", re.MULTILINE)),
    ("reasoning_hedge",   re.compile(r"\b(Wait|Hmm|Actually|Let me check|perhaps|I think)\b", re.IGNORECASE)),
    ("json_output",       re.compile(r'^\s*\{|^\s*\[', re.MULTILINE)),
    ("bracket_in_source", re.compile(r"SOURCE\s*:\s*\[", re.IGNORECASE)),
]


def detect_quirks(raw):
    return [name for name, pat in QUIRK_PATTERNS if pat.search(raw)]


LABEL_RE = re.compile(r"^\s*(?:[-*]\s*|\d+[.)]\s*)?(?:\*\*)?\s*(Q|A|SOURCE|Question|Answer|Source|Notes|From)\s*(?:\*\*)?\s*:\s*(.*)$",
                      re.IGNORECASE)


def parse_cards(raw):
    stripped = re.sub(r"<think>.*?</think>", "", raw, flags=re.DOTALL | re.IGNORECASE)
    cards = []
    cur = {"q": "", "a": "", "s": ""}
    section = None
    def commit():
        if cur["q"].strip() and cur["a"].strip():
            raw_tokens = re.split(r"[,\s]+", cur["s"])
            sources = [re.sub(r"[\[\]{}()]", "", t).strip() for t in raw_tokens]
            sources = [s for s in sources if s]
            cards.append({
                "question": cur["q"].strip(),
                "answer": cur["a"].strip(),
                "sources": sources,
            })
        cur["q"] = cur["a"] = cur["s"] = ""
    for line in stripped.split("\n"):
        if not line.strip():
            continue
        m = LABEL_RE.match(line)
        if m:
            kind, content = m.group(1).upper(), m.group(2).strip()
            if kind in ("Q", "QUESTION"):
                commit()
                cur["q"] = content; section = "q"
            elif kind in ("A", "ANSWER") and section is not None:
                cur["a"] = content; section = "a"
            elif kind in ("SOURCE", "SOURCES", "NOTES", "FROM"):
                cur["s"] = content; section = "s"
        elif section:
            body = re.sub(r"\*+", "", line.strip())
            cur[section] = (cur[section] + " " + body) if cur[section] else body
    commit()
    return cards


TOPIC_KEYWORDS = {
    "inner planets":  {"mercury", "venus", "earth", "mars", "moon", "sun", "inner"},
    "outer planets":  {"jupiter", "saturn", "uranus", "neptune", "pluto", "gas giant", "ice giant"},
    "the sun":        {"sun", "solar", "g2v", "fusion", "core"},
    "roman emperors": {"caesar", "augustus", "nero", "rome", "emperor"},
}


def grade(topic, raw, retrieved):
    quirks = detect_quirks(raw)
    cards = parse_cards(raw)
    allowed_ids = {n["id"] for n in retrieved}
    keywords = TOPIC_KEYWORDS.get(topic.lower(), set())
    on_topic = 0; off_source = 0; well_formed = 0
    for c in cards:
        text = (c["question"] + " " + c["answer"]).lower()
        if keywords and any(k in text for k in keywords):
            on_topic += 1
        if c["sources"] and all(s not in allowed_ids for s in c["sources"]):
            off_source += 1
        if c["question"] and c["answer"] and c["sources"]:
            well_formed += 1
    no_output = len(cards) == 0
    return {
        "cards_total": len(cards),
        "cards_well_formed": well_formed,
        "cards_on_topic": on_topic,
        "cards_off_source": off_source,
        "no_output": no_output,
        "quirks": quirks,
    }


def run(n=3) -> list[dict]:
    from cactus import cactus_init, cactus_complete, cactus_destroy

    corpus = load_corpus()
    results = []
    for slug, weights_dir in CANDIDATES.items():
        if not weights_dir.exists() or not any(weights_dir.iterdir()):
            print(f"[{slug}] SKIP — weights missing at {weights_dir}", flush=True)
            results.append({"model": slug, "error": f"weights missing at {weights_dir}"})
            continue
        print(f"[{slug}] init...", flush=True)
        try:
            model = cactus_init(str(weights_dir), "", False)
        except Exception as e:
            print(f"  INIT FAILED: {e}", flush=True)
            results.append({"model": slug, "error": f"init: {e}"})
            continue
        try:
            for topic, filt, tag in QUERIES:
                retrieved = filter_retrieved(corpus, filt)
                user = build_user_message(topic, n, retrieved)
                messages = json.dumps([
                    {"role": "system", "content": SYSTEM_MSG},
                    {"role": "user", "content": user},
                ])
                options = json.dumps({
                    "max_tokens": 512,
                    "temperature": 0.7,
                    "stop_sequences": ["\\boxed", "\\begin{aligned}", "\\text{"],
                })
                t0 = time.monotonic()
                try:
                    envelope = cactus_complete(model, messages, options, "[]", None)
                    # Cactus wraps the model output in a JSON envelope:
                    # {"success":..., "response":"<actual output>", "decode_tps":..., ...}
                    try:
                        raw = json.loads(envelope).get("response", envelope)
                    except json.JSONDecodeError:
                        raw = envelope
                except Exception as e:
                    print(f"  [{topic!r}] ERROR: {e}", flush=True)
                    results.append({
                        "model": slug, "topic": topic, "tag": tag,
                        "retrieved": len(retrieved), "error": str(e),
                    })
                    continue
                dt = time.monotonic() - t0
                g = grade(topic, raw, retrieved)
                g.update({
                    "model": slug, "topic": topic, "tag": tag,
                    "retrieved": len(retrieved), "duration_s": round(dt, 1),
                    "raw": raw,
                })
                results.append(g)
                print(f"  {topic!r}: {dt:.1f}s | cards={g['cards_total']} "
                      f"well={g['cards_well_formed']} on_topic={g['cards_on_topic']} "
                      f"off_source={g['cards_off_source']} quirks={g['quirks']}",
                      flush=True)
        finally:
            cactus_destroy(model)
    return results


def render_md(results):
    out = []
    out.append("# T1-Cactus results — flashcard fidelity (Cactus runtime, INT4)")
    out.append("")
    out.append("Generated by `tools/ollama_eval/t1_cactus.py`. **INT4 precision** "
               "(Cactus CLI default). The on-device demo runs at INT8 per the "
               "Flutter catalog's `quantization=8`. Reconversion to INT8/FP16 fails "
               "locally with `Qwen3ForCausalLM` import error. Compare *within* this "
               "table; do **not** compare absolute numbers against `t1-results.md`.")
    out.append("")
    out.append("## Summary table")
    out.append("")
    out.append("| Model | Topic | Tag | Cards | Well-formed | On-topic | Off-source | No-output | Quirks | Time |")
    out.append("|---|---|---|---|---|---|---|---|---|---|")
    for r in results:
        if "error" in r:
            out.append(f"| `{r['model']}` | {r.get('topic','—')} | {r.get('tag','—')} | — | — | — | — | — | ERROR: {r['error'][:60]} | — |")
            continue
        out.append(
            f"| `{r['model']}` | {r['topic']} | {r['tag']} | "
            f"{r['cards_total']} | {r['cards_well_formed']} | {r['cards_on_topic']} | "
            f"{r['cards_off_source']} | {'✓' if r['no_output'] else '·'} | "
            f"{','.join(r['quirks']) or '—'} | {r['duration_s']}s |"
        )
    out.append("")
    out.append("## Raw outputs")
    out.append("")
    for r in results:
        if "error" in r or "raw" not in r:
            continue
        out.append(f"### `{r['model']}` — {r['topic']} ({r['tag']})")
        out.append("")
        out.append("```")
        out.append(r["raw"].rstrip())
        out.append("```")
        out.append("")
    return "\n".join(out)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--n", type=int, default=3)
    p.add_argument("--out", default="_docs/notes/t1-cactus-results.md")
    args = p.parse_args()
    results = run(n=args.n)
    out_path = REPO_ROOT / args.out
    out_path.write_text(render_md(results))
    print(f"\nWrote {out_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
