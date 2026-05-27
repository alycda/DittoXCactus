#!/usr/bin/env python3
"""T2-Cactus — retrieval quality across Cactus-catalog embedders.

Counterpart to t2.py (which used ollama). Loads each candidate embedder via
the Cactus Python bindings and re-runs the T2 gold-set evaluation.

Critical re-test: `qwen3-embedding-0.6b` (the dedicated embedder that
cactus-sdk-quirks.md said "doesn't load"). It loads fine here — possibly a
Flutter-SDK-1.3.0-only bug, not an engine limitation.

Output: `_docs/notes/t2-cactus-results.md`.

Usage:
    python3.14 tools/ollama_eval/t2_cactus.py
"""
from __future__ import annotations

import argparse
import json
import math
import sys
import time
import uuid
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
NS = uuid.UUID("7c2b8e4a-3d5f-4b2c-8e6d-1a4f9e8c7b30")

# Cactus weights live in the Homebrew Cellar.
WEIGHTS_ROOT = Path("/opt/homebrew/Cellar/cactus/1.14_1/libexec/weights")

# Maps cactus CLI's HF-style ID → on-disk weights dir name.
CANDIDATES = {
    "qwen3-0.6":            WEIGHTS_ROOT / "qwen3-0.6b",
    "qwen3-embedding-0.6":  WEIGHTS_ROOT / "qwen3-embedding-0.6b",
    "nomic2-embed-300m":    WEIGHTS_ROOT / "nomic-embed-text-v2-moe",
}

# Same gold set as t2.py (kept parallel for cross-comparison).
GOLD = [
    ("inner planets",   ["Mercury", "Venus", "Mars"]),
    ("outer planets",   ["Jupiter", "Saturn", "Uranus", "Neptune"]),
    ("the Sun",         ["The Sun"]),
    ("gas giants",      ["Jupiter", "Saturn"]),
    ("rocky planets",   ["Mercury", "Venus", "Mars"]),
    ("moons",           ["Earth's Moon"]),
    ("ice giants",      ["Uranus", "Neptune"]),
    ("atmosphere",      ["Venus", "Mars", "Earth's Moon"]),
]


def load_corpus() -> list[dict]:
    notes: list[dict] = []
    for role in ("a", "b"):
        path = REPO_ROOT / "assets" / f"seed_notes_{role}.json"
        for n in json.loads(path.read_text()):
            nid = str(uuid.uuid5(NS, f"{n['contributor']}|{n['topic']}|{n['createdAt']}"))
            notes.append({"id": nid, "topic": n["topic"], "body": n["body"], "role": role})
    return notes


def cosine(a, b) -> float:
    dot = sum(x * y for x, y in zip(a, b))
    na = math.sqrt(sum(x * x for x in a))
    nb = math.sqrt(sum(y * y for y in b))
    return dot / (na * nb) if na and nb else 0.0


def topk_local(query_emb, note_embs, k=3):
    scored = [(n, cosine(query_emb, e)) for n, e in note_embs]
    scored.sort(key=lambda x: x[1], reverse=True)
    return scored[:k]


def recall_at_k(top, gold_topics: set[str]) -> int:
    return sum(1 for n, _ in top if n["topic"] in gold_topics)


def reciprocal_rank(scored, gold_topics: set[str]) -> float:
    for i, (n, _) in enumerate(scored, start=1):
        if n["topic"] in gold_topics:
            return 1.0 / i
    return 0.0


def case_stability(top_lc, top_tc) -> str:
    lc_id = top_lc[0][0]["id"] if top_lc else None
    tc_id = top_tc[0][0]["id"] if top_tc else None
    if lc_id == tc_id:
        return "stable"
    return f"DIFFERS (lc→{top_lc[0][0]['topic']} / tc→{top_tc[0][0]['topic']})"


def run() -> list[dict]:
    # Import inside run() so the script can be inspected/argparse'd without the lib.
    from cactus import cactus_init, cactus_embed, cactus_destroy

    corpus = load_corpus()
    results: list[dict] = []
    for slug, weights_dir in CANDIDATES.items():
        if not weights_dir.exists():
            print(f"[{slug}] SKIP — weights not at {weights_dir}", flush=True)
            results.append({"model": slug, "error": f"weights missing at {weights_dir}"})
            continue
        print(f"[{slug}] init...", flush=True)
        t0 = time.monotonic()
        try:
            model = cactus_init(str(weights_dir), "", False)
            init_t = time.monotonic() - t0
        except Exception as e:
            print(f"  INIT FAILED: {e}", flush=True)
            results.append({"model": slug, "error": f"init: {e}"})
            continue
        try:
            t0 = time.monotonic()
            note_embs = [(n, cactus_embed(model, n["body"], True)) for n in corpus]
            corpus_t = time.monotonic() - t0
            dim = len(note_embs[0][1])
            print(f"  init={init_t:.1f}s, corpus embedded in {corpus_t:.1f}s, dim={dim}",
                  flush=True)

            for topic, gold_topics_list in GOLD:
                gold_topics = set(gold_topics_list)
                q_lc = cactus_embed(model, topic.lower(), True)
                q_tc = cactus_embed(model, topic.title(), True)
                top_lc = topk_local(q_lc, note_embs)
                top_tc = topk_local(q_tc, note_embs)
                scored_lc = sorted(
                    [(n, cosine(q_lc, e)) for n, e in note_embs],
                    key=lambda x: x[1], reverse=True,
                )
                r3 = recall_at_k(top_lc, gold_topics)
                rr = reciprocal_rank(scored_lc, gold_topics)
                cs = case_stability(top_lc, top_tc)
                results.append({
                    "model": slug, "dim": dim, "topic": topic,
                    "gold_topics": gold_topics_list,
                    "top3_topics_lc": [n["topic"] for n, _ in top_lc],
                    "top1_score_lc": round(top_lc[0][1], 3),
                    "top3_topics_tc": [n["topic"] for n, _ in top_tc],
                    "top1_score_tc": round(top_tc[0][1], 3),
                    "recall_at_3": r3,
                    "max_recall": min(3, len(gold_topics)),
                    "mrr": round(rr, 3),
                    "case": cs,
                })
                print(f"  {topic!r}: R@3={r3}/{min(3,len(gold_topics))} "
                      f"MRR={rr:.3f} top_lc={[n['topic'] for n,_ in top_lc]} case={cs}",
                      flush=True)
        finally:
            cactus_destroy(model)
    return results


def render_md(results: list[dict]) -> str:
    out: list[str] = []
    out.append("# T2-Cactus results — retrieval quality (Cactus runtime)")
    out.append("")
    out.append("Generated by `tools/ollama_eval/t2_cactus.py` using the Cactus CLI's "
               "Python bindings (`brew install cactus-compute/cactus/cactus`). "
               "**Same gold set as `t2-results.md` for cross-comparison.**")
    out.append("")
    out.append("## Per-model summary")
    out.append("")
    out.append("| Model | Dim | Mean R@3 | Mean MRR | Case-stable / 8 |")
    out.append("|---|---|---|---|---|")
    by_model: dict[str, list[dict]] = {}
    errors: dict[str, str] = {}
    for r in results:
        if "error" in r:
            errors[r["model"]] = r["error"]
            continue
        by_model.setdefault(r["model"], []).append(r)
    for model, rows in by_model.items():
        mean_r3 = sum(r["recall_at_3"] for r in rows) / len(rows)
        mean_mrr = sum(r["mrr"] for r in rows) / len(rows)
        stable = sum(1 for r in rows if r["case"] == "stable")
        dim = rows[0]["dim"]
        out.append(f"| `{model}` | {dim} | {mean_r3:.2f} | {mean_mrr:.3f} | {stable}/{len(rows)} |")
    for model, e in errors.items():
        out.append(f"| `{model}` | — | — | — | ERROR: {e[:60]} |")
    out.append("")
    out.append("## Per-query detail")
    out.append("")
    out.append("| Model | Topic | R@3 | MRR | Top-3 (lc) | Case |")
    out.append("|---|---|---|---|---|---|")
    for r in results:
        if "error" in r:
            continue
        out.append(
            f"| `{r['model']}` | {r['topic']} | {r['recall_at_3']}/{r['max_recall']} | "
            f"{r['mrr']} | {', '.join(r['top3_topics_lc'])} | {r['case']} |"
        )
    return "\n".join(out)


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--out", default="_docs/notes/t2-cactus-results.md")
    args = p.parse_args()
    results = run()
    out_path = REPO_ROOT / args.out
    out_path.write_text(render_md(results))
    print(f"\nWrote {out_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
