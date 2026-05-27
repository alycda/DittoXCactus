#!/usr/bin/env python3
"""T1 — host-side flashcard fidelity harness.

Compares ollama-reachable small models on the *exact* flashcard prompt used by
the on-device pipeline (see `lib/prompts/flashcard_gen.dart`). Builds the same
system + user message, runs each model, applies a minimal grading rubric (format,
grounding, quirks), writes a markdown results table.

Output: `_docs/notes/t1-results.md`.

Usage:
    python3 tools/ollama_eval/t1.py [--models qwen3:1.7b,qwen2.5:1.5b,...]
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import time
import uuid
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
OLLAMA_URL = "http://localhost:11434/api/chat"

# Mirrors `_meshRagNamespace` at lib/models/study_note.dart:32.
NS = uuid.UUID("7c2b8e4a-3d5f-4b2c-8e6d-1a4f9e8c7b30")

# Mirrors `_systemMessage` at lib/prompts/flashcard_gen.dart:76-103. Kept
# byte-for-byte; the on-device test pins this verbatim.
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

DEFAULT_MODELS = [
    "qwen3:1.7b",       # incumbent baseline (matches Cactus's qwen3-1.7)
    "qwen2.5:1.5b",
    "qwen2.5:0.5b",
    "gemma3:1b",
    "llama3.2:1b",
]

# Topic, retrieved-role-filter, expectation tag.
QUERIES = [
    ("inner planets", "a", "on-topic"),
    ("outer planets", "b", "on-topic"),
    ("the Sun", None, "cross-corpus"),    # all notes; Sun is in role A
    ("Roman emperors", "empty", "off-corpus"),  # empty retrieved → expect nothing
]


def load_corpus() -> list[dict]:
    notes: list[dict] = []
    for role in ("a", "b"):
        path = REPO_ROOT / "assets" / f"seed_notes_{role}.json"
        for n in json.loads(path.read_text()):
            nid = str(uuid.uuid5(NS, f"{n['contributor']}|{n['topic']}|{n['createdAt']}"))
            notes.append({
                "id": nid,
                "topic": n["topic"],
                "body": n["body"],
                "contributor": n["contributor"],
                "role": role,
            })
    return notes


def build_user_message(topic: str, n: int, retrieved: list[dict]) -> str:
    """Mirrors `_buildUserMessage` at lib/prompts/flashcard_gen.dart:105."""
    lines = [
        f"Topic: {topic}",
        f"Number of flashcards (N): {n}",
        "",
        "Notes (each line starts with [<id>] — copy these ids verbatim into SOURCE):",
    ]
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


def filter_retrieved(corpus: list[dict], filt: str | None) -> list[dict]:
    """Stand-in for cosine retrieval. Either role-filter, all, or empty."""
    if filt == "empty":
        return []
    if filt is None:
        return list(corpus)
    return [n for n in corpus if n["role"] == filt]


def chat(model: str, system: str, user: str, timeout: int = 180) -> tuple[str, float]:
    payload = {
        "model": model,
        "stream": False,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "options": {"temperature": 0.7},
    }
    req = urllib.request.Request(
        OLLAMA_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )
    t0 = time.monotonic()
    with urllib.request.urlopen(req, timeout=timeout) as r:
        body = json.loads(r.read().decode("utf-8"))
    dt = time.monotonic() - t0
    return body.get("message", {}).get("content", ""), dt


# ───── Quirk detectors (mirror model-quirks.md) ──────────────────────────

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


def detect_quirks(raw: str) -> list[str]:
    return [name for name, pat in QUIRK_PATTERNS if pat.search(raw)]


# ───── Minimal tolerant parser ───────────────────────────────────────────

LABEL_RE = re.compile(r"^\s*(?:[-*]\s*|\d+[.)]\s*)?(?:\*\*)?\s*(Q|A|SOURCE|Question|Answer|Source|Notes|From)\s*(?:\*\*)?\s*:\s*(.*)$",
                      re.IGNORECASE)


def parse_cards(raw: str) -> list[dict]:
    """Returns list of {question, answer, sources}. Tolerant — same idea as Dart."""
    # Strip closed <think>...</think> blocks.
    stripped = re.sub(r"<think>.*?</think>", "", raw, flags=re.DOTALL | re.IGNORECASE)
    cards: list[dict] = []
    cur = {"q": "", "a": "", "s": ""}
    section = None

    def commit():
        if cur["q"].strip() and cur["a"].strip():
            # Strip surrounding brackets/braces — models often copy the [<id>]
            # form from the prompt example into SOURCE. Mirrors the on-device
            # `_splitSourceList` tolerance.
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
                cur["q"] = content
                section = "q"
            elif kind in ("A", "ANSWER") and section is not None:
                cur["a"] = content
                section = "a"
            elif kind in ("SOURCE", "SOURCES", "NOTES", "FROM"):
                cur["s"] = content
                section = "s"
        elif section:
            # Continuation
            body = re.sub(r"\*+", "", line.strip())
            cur[section] = (cur[section] + " " + body) if cur[section] else body
    commit()
    return cards


# ───── Grading ──────────────────────────────────────────────────────────

# Per-topic keyword sets for the on-topic heuristic. Lowercase.
TOPIC_KEYWORDS: dict[str, set[str]] = {
    "inner planets":  {"mercury", "venus", "earth", "mars", "moon", "sun", "inner"},
    "outer planets":  {"jupiter", "saturn", "uranus", "neptune", "pluto", "gas giant", "ice giant"},
    "the sun":        {"sun", "solar", "g2v", "fusion", "core"},
    "roman emperors": {"caesar", "augustus", "nero", "rome", "emperor"},
}


def grade(topic: str, raw: str, retrieved: list[dict]) -> dict:
    quirks = detect_quirks(raw)
    cards = parse_cards(raw)
    allowed_ids = {n["id"] for n in retrieved}
    keywords = TOPIC_KEYWORDS.get(topic.lower(), set())

    on_topic = 0
    off_source = 0
    well_formed = 0
    for c in cards:
        text = (c["question"] + " " + c["answer"]).lower()
        if keywords and any(k in text for k in keywords):
            on_topic += 1
        if c["sources"] and all(s not in allowed_ids for s in c["sources"]):
            off_source += 1
        if c["question"] and c["answer"] and c["sources"]:
            well_formed += 1

    # For off-corpus + empty retrieved: success = produced ZERO cards.
    no_output = len(cards) == 0
    return {
        "cards_total": len(cards),
        "cards_well_formed": well_formed,
        "cards_on_topic": on_topic,
        "cards_off_source": off_source,
        "no_output": no_output,
        "quirks": quirks,
    }


# ───── Driver ───────────────────────────────────────────────────────────

def run(models: list[str], n: int = 3) -> list[dict]:
    corpus = load_corpus()
    results: list[dict] = []
    for model in models:
        for topic, filt, tag in QUERIES:
            retrieved = filter_retrieved(corpus, filt)
            user = build_user_message(topic, n, retrieved)
            print(f"[{model}] {topic!r} (retrieved={len(retrieved)}, tag={tag}) ...", flush=True)
            try:
                raw, dt = chat(model, SYSTEM_MSG, user)
            except Exception as e:
                results.append({
                    "model": model, "topic": topic, "tag": tag,
                    "retrieved": len(retrieved), "error": str(e),
                })
                print(f"  ERROR: {e}", flush=True)
                continue
            g = grade(topic, raw, retrieved)
            g.update({
                "model": model, "topic": topic, "tag": tag,
                "retrieved": len(retrieved), "duration_s": round(dt, 1),
                "raw": raw,
            })
            results.append(g)
            print(f"  {dt:.1f}s | cards={g['cards_total']} well={g['cards_well_formed']} "
                  f"on_topic={g['cards_on_topic']} off_source={g['cards_off_source']} "
                  f"quirks={g['quirks']}", flush=True)
    return results


# ───── Markdown output ──────────────────────────────────────────────────

def render_md(results: list[dict]) -> str:
    out: list[str] = []
    out.append("# T1 results — flashcard fidelity (ollama)")
    out.append("")
    out.append(f"Generated by `tools/ollama_eval/t1.py`. Mirrors the on-device prompt "
               f"at `lib/prompts/flashcard_gen.dart`. **Host-side fidelity only; not a "
               f"deployment recommendation** — winners must be Cactus-catalog-reachable. "
               f"See `ollama-eval-plan.md` for context.")
    out.append("")
    out.append("## Summary table")
    out.append("")
    out.append("| Model | Topic | Tag | Cards | Well-formed | On-topic | Off-source | No-output | Quirks | Time |")
    out.append("|---|---|---|---|---|---|---|---|---|---|")
    for r in results:
        if "error" in r:
            out.append(f"| `{r['model']}` | {r['topic']} | {r['tag']} | — | — | — | — | — | "
                       f"ERROR: {r['error'][:60]} | — |")
            continue
        out.append(
            f"| `{r['model']}` | {r['topic']} | {r['tag']} | "
            f"{r['cards_total']} | {r['cards_well_formed']} | {r['cards_on_topic']} | "
            f"{r['cards_off_source']} | {'✓' if r['no_output'] else '·'} | "
            f"{','.join(r['quirks']) or '—'} | {r['duration_s']}s |"
        )
    out.append("")
    out.append("## Reading the table")
    out.append("")
    out.append("- **Cards / Well-formed**: raw parse count vs. cards with Q+A+SOURCE all present.")
    out.append("- **On-topic**: heuristic — does the Q or A mention a topic-keyword? "
               "(Per-topic keyword sets in the script.)")
    out.append("- **Off-source**: cards whose SOURCE cites an ID not in the retrieved set. "
               "Strict hallucination signal.")
    out.append("- **No-output ✓**: model produced zero cards. *Desired* for the `off-corpus` "
               "tag (empty retrieved → grounding rule says output nothing). *Undesired* otherwise.")
    out.append("- **Quirks**: each flag is one of the failure modes catalogued in "
               "`model-quirks.md`. Multiple quirks per cell are comma-separated.")
    out.append("")
    out.append("## Raw outputs")
    out.append("")
    for r in results:
        if "error" in r:
            continue
        out.append(f"### `{r['model']}` — {r['topic']} ({r['tag']})")
        out.append("")
        out.append("```")
        out.append(r["raw"].rstrip())
        out.append("```")
        out.append("")
    return "\n".join(out)


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--models", default=",".join(DEFAULT_MODELS),
                   help="comma-separated ollama model tags")
    p.add_argument("--n", type=int, default=3, help="flashcards per query")
    p.add_argument("--out", default="_docs/notes/t1-results.md",
                   help="output markdown path (repo-relative)")
    args = p.parse_args()
    models = [m.strip() for m in args.models.split(",") if m.strip()]
    results = run(models, n=args.n)
    out_path = REPO_ROOT / args.out
    out_path.write_text(render_md(results))
    print(f"\nWrote {out_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
