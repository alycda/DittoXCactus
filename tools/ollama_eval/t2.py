#!/usr/bin/env python3
"""T2 — host-side retrieval quality harness.

Compares embedding models reachable via ollama on the seed corpus (10 notes,
roles a + b). Measures Recall@3 and MRR against a small hand-labelled gold
set, plus title-case stability (proper-noun sensitivity — Qwen3-0.6 is famously
case-sensitive; the on-device pipeline title-cases queries to compensate, see
`retrieval_service.dart`).

Output: `_docs/notes/t2-results.md`.

Usage:
    python3 tools/ollama_eval/t2.py [--models nomic-embed-text,qwen3:0.6b,...]
"""
from __future__ import annotations

import argparse
import json
import math
import sys
import time
import uuid
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
OLLAMA_URL = "http://localhost:11434/api/embed"
NS = uuid.UUID("7c2b8e4a-3d5f-4b2c-8e6d-1a4f9e8c7b30")

DEFAULT_MODELS = [
    "nomic-embed-text",
    "qwen3:0.6b",          # incumbent-equivalent (chat-tuned, embedding head)
    "mxbai-embed-large",
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
                "role": role,
            })
    return notes


def embed(model: str, text: str, timeout: int = 60) -> list[float]:
    req = urllib.request.Request(
        OLLAMA_URL,
        data=json.dumps({"model": model, "input": text}).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=timeout) as r:
        body = json.loads(r.read().decode("utf-8"))
    return body["embeddings"][0]


def cosine(a: list[float], b: list[float]) -> float:
    dot = sum(x * y for x, y in zip(a, b))
    na = math.sqrt(sum(x * x for x in a))
    nb = math.sqrt(sum(y * y for y in b))
    return dot / (na * nb) if na and nb else 0.0


# Topic → expected-top note topics (resolved to IDs at runtime). At least one
# of these should appear in the model's top-3 for a passing recall.
GOLD = [
    ("inner planets",   ["Mercury", "Venus", "Mars"]),
    ("outer planets",   ["Jupiter", "Saturn", "Uranus", "Neptune"]),
    ("the Sun",         ["The Sun"]),
    ("gas giants",      ["Jupiter", "Saturn"]),
    ("rocky planets",   ["Mercury", "Venus", "Mars"]),
    ("moons",           ["Earth's Moon"]),
    ("ice giants",      ["Uranus", "Neptune"]),
    ("atmosphere",      ["Venus", "Mars", "Earth's Moon"]),  # all have body-text atmosphere mentions
]


def topk(query_emb: list[float], note_embs: list[tuple[dict, list[float]]], k: int = 3) -> list[tuple[dict, float]]:
    scored = [(n, cosine(query_emb, e)) for n, e in note_embs]
    scored.sort(key=lambda x: x[1], reverse=True)
    return scored[:k]


def recall_at_k(top: list[tuple[dict, float]], gold_topics: set[str]) -> int:
    return sum(1 for n, _ in top if n["topic"] in gold_topics)


def reciprocal_rank(scored: list[tuple[dict, float]], gold_topics: set[str]) -> float:
    for i, (n, _) in enumerate(scored, start=1):
        if n["topic"] in gold_topics:
            return 1.0 / i
    return 0.0


def case_stability(top_lc: list[tuple[dict, float]], top_tc: list[tuple[dict, float]]) -> str:
    """Compare top-1 identity for lowercase vs title-case query."""
    lc_id = top_lc[0][0]["id"] if top_lc else None
    tc_id = top_tc[0][0]["id"] if top_tc else None
    if lc_id == tc_id:
        return "stable"
    return f"DIFFERS (lc→{top_lc[0][0]['topic']} / tc→{top_tc[0][0]['topic']})"


def run(models: list[str]) -> list[dict]:
    corpus = load_corpus()
    results: list[dict] = []
    for model in models:
        print(f"[{model}] embedding corpus ({len(corpus)} notes)...", flush=True)
        t0 = time.monotonic()
        note_embs: list[tuple[dict, list[float]]] = []
        try:
            for n in corpus:
                note_embs.append((n, embed(model, n["body"])))
            corpus_t = time.monotonic() - t0
            dim = len(note_embs[0][1])
            print(f"  corpus embedded in {corpus_t:.1f}s, dim={dim}", flush=True)
        except Exception as e:
            results.append({"model": model, "error": str(e)})
            print(f"  ERROR: {e}", flush=True)
            continue

        for topic, gold_topics_list in GOLD:
            gold_topics = set(gold_topics_list)
            # lowercase variant
            q_lc = embed(model, topic.lower())
            top_lc = topk(q_lc, note_embs)
            # title-case variant
            q_tc = embed(model, topic.title())
            top_tc = topk(q_tc, note_embs)
            # MRR uses full ranking
            scored_lc = sorted(
                [(n, cosine(q_lc, e)) for n, e in note_embs],
                key=lambda x: x[1], reverse=True,
            )
            r3 = recall_at_k(top_lc, gold_topics)
            rr = reciprocal_rank(scored_lc, gold_topics)
            cs = case_stability(top_lc, top_tc)
            results.append({
                "model": model, "dim": dim, "topic": topic,
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
    return results


def render_md(results: list[dict]) -> str:
    out: list[str] = []
    out.append("# T2 results — retrieval quality (ollama)")
    out.append("")
    out.append("Generated by `tools/ollama_eval/t2.py`. Compares embedding models on the "
               "10-note seed corpus (roles a + b merged). **Host-side fidelity only**; "
               "winners must be Cactus-catalog-reachable. See `ollama-eval-plan.md` for context.")
    out.append("")

    # Per-model summary
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

    # Per-query detail
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
    out.append("")

    out.append("## Reading the table")
    out.append("")
    out.append("- **R@3**: number of expected-topic notes that appear in the top 3 / max possible.")
    out.append("- **MRR**: reciprocal rank of the *first* matching note in the full ranking.")
    out.append("- **Case**: does the top-1 note change when the query is lowercase vs. title-case? "
               "`stable` is good; anything else means the model's embedding head is case-sensitive "
               "in a way that affects retrieval. The on-device pipeline title-cases queries to "
               "compensate (see `retrieval_service.dart`).")
    return "\n".join(out)


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--models", default=",".join(DEFAULT_MODELS))
    p.add_argument("--out", default="_docs/notes/t2-results.md")
    args = p.parse_args()
    models = [m.strip() for m in args.models.split(",") if m.strip()]
    results = run(models)
    out_path = REPO_ROOT / args.out
    out_path.write_text(render_md(results))
    print(f"\nWrote {out_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
