#!/usr/bin/env python3.14
"""Smoke-test driver for a Cactus model bundle (any catalog or off-catalog
weights dir). Loads via Python bindings, runs a few queries against the
demo's actual prompt, captures throughput + a sample of the output.

Usage:
    python3.14 tools/ollama_eval/smoke_cactus_model.py <weights_dir>

Outputs to stdout. Designed to make the success/failure pattern obvious
without ceremony.
"""
from __future__ import annotations

import json
import sys
import time
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent

# Same system message as t1_cactus.py — the on-device flashcard prompt.
SYSTEM_MSG = """You are a careful study buddy. You make study flashcards from short notes.

Output rules:
- Output ONLY flashcards. No reasoning, no preamble.
- Each card has three lines in this exact format:
  Q: <a clear question>
  A: <a short answer, one sentence — under 30 words>
  SOURCE: <one or more note ids, comma-separated>
- The note ids are the bracketed strings at the start of each note line.
- No markdown emphasis. No JSON. No bullets. No LaTeX. No <think> blocks.
- Do not make up facts. If the notes do not support a claim, do not make the claim.

Example:

Q: What is escape velocity?
A: The minimum speed needed to break free of a body's gravity without further propulsion.
SOURCE: 400ba2af-8714-5fbb-ae78-b7858c60eaf7"""


def smoke_query(model, topic: str, retrieved_notes_md: str, n: int = 2) -> dict:
    from cactus import cactus_complete
    user = (
        f"Topic: {topic}\n"
        f"Number of flashcards (N): {n}\n\n"
        f"Notes (each line starts with [<id>] — copy these ids verbatim into SOURCE):\n"
        f"{retrieved_notes_md}\n\n"
        f"Now output exactly {n} flashcards in the Q: / A: / SOURCE: format, "
        f'each about "{topic}". Start with "Q:" on its own line. No reasoning, no preamble.'
    )
    messages = json.dumps([
        {"role": "system", "content": SYSTEM_MSG},
        {"role": "user", "content": user},
    ])
    options = json.dumps({"max_tokens": 400, "temperature": 0.0})
    t0 = time.monotonic()
    envelope_str = cactus_complete(model, messages, options, "[]", None)
    dt = time.monotonic() - t0
    try:
        env = json.loads(envelope_str)
    except json.JSONDecodeError:
        return {"raw": envelope_str, "duration_s": dt, "error": "non-JSON envelope"}
    return {
        "response": env.get("response", "")[:600],
        "prefill_tps": env.get("prefill_tps"),
        "decode_tps": env.get("decode_tps"),
        "duration_s": round(dt, 2),
        "ram_usage_mb": env.get("ram_usage_mb"),
        "total_tokens": env.get("total_tokens"),
    }


def main():
    if len(sys.argv) != 2:
        print("usage: smoke_cactus_model.py <weights_dir>")
        return 2
    weights_dir = Path(sys.argv[1]).resolve()
    if not weights_dir.exists():
        print(f"ERROR: weights dir not found: {weights_dir}")
        return 1
    config = weights_dir / "config.txt"
    if config.exists():
        print(f"=== config.txt ===")
        print(config.read_text())
        print()

    from cactus import cactus_init, cactus_destroy

    print(f"=== loading {weights_dir.name} ===")
    t0 = time.monotonic()
    try:
        model = cactus_init(str(weights_dir), "", False)
        print(f"init in {time.monotonic()-t0:.1f}s ✓")
    except Exception as e:
        print(f"INIT FAILED: {type(e).__name__}: {str(e)[:200]}")
        return 1

    try:
        # Two demo queries: on-corpus (inner planets) + off-corpus (Roman emperors).
        inner_notes_md = (
            "[3e21e507-f68f-5aa1-8903-8026e29b824f] Mercury is the smallest planet "
            "and closest to the Sun. Its day is 176 Earth days but its year is only 88 Earth days. "
            "It has no atmosphere and surface temperatures swing from -180°C at night to 430°C at noon.\n"
            "[62ba146b-d730-56ca-9a75-3d5ff91ece4c] Venus has a thick CO2 atmosphere creating a runaway "
            "greenhouse effect. Surface temperature reaches 465°C, hotter than Mercury despite being "
            "farther from the Sun.\n"
            "[400ba2af-8714-5fbb-ae78-b7858c60eaf7] Mars has the largest volcano in the solar system "
            "(Olympus Mons, 22km high) and polar ice caps made of water and frozen CO2."
        )

        print("\n=== query 1: 'inner planets' (on-corpus, n=2) ===")
        r1 = smoke_query(model, "inner planets", inner_notes_md, n=2)
        print(json.dumps(r1, indent=2))

        print("\n=== query 2: 'Roman emperors' (off-corpus, empty retrieved, n=2) ===")
        r2 = smoke_query(model, "Roman emperors", "(no notes available — output nothing.)", n=2)
        print(json.dumps(r2, indent=2))

    finally:
        cactus_destroy(model)
    return 0


if __name__ == "__main__":
    sys.exit(main())
