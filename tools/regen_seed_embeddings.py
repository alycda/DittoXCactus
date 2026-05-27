#!/usr/bin/env python3.14
"""Regenerate the pre-computed embedding vectors in
`assets/seed_notes_{a,b}.json` against a different Cactus embedder slug.

Why: the seed JSONs ship with pre-computed embeddings so the on-device boot
doesn't re-embed five notes at startup. They were computed against the
default `qwen3-0.6` (chat-tuned, embedding-head-repurposed) model. Swapping
the default embedder to `qwen3-0.6-embed` (dedicated, per issue #9) requires
regenerating those embedding arrays so the cached vectors match the model
the device will use for query-side embeddings — otherwise retrieval mixes
two embedding spaces and cosine scores are meaningless.

Usage:
    python3.14 tools/regen_seed_embeddings.py [--slug qwen3-embedding-0.6b] \
        [--weights /opt/homebrew/Cellar/cactus/.../weights]

Default weights directory is the brew-managed Cactus weights cache. Default
slug is the dedicated embedder we downloaded via `cactus download
Qwen/Qwen3-Embedding-0.6B` (see _docs/notes/cactus-cpp-bypass-spike.md for
how the brew formula's venv handles this).
"""
from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_WEIGHTS_DIR = Path("/opt/homebrew/Cellar/cactus/1.14_1/libexec/weights")
DEFAULT_SLUG = "qwen3-embedding-0.6b"


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--slug", default=DEFAULT_SLUG,
                   help="Cactus weights dir name (default: qwen3-embedding-0.6b)")
    p.add_argument("--weights-root", default=str(DEFAULT_WEIGHTS_DIR),
                   help="Parent dir containing the Cactus weight folders")
    p.add_argument("--dry-run", action="store_true",
                   help="Embed + diff but do not write back to disk")
    args = p.parse_args()

    weights_path = Path(args.weights_root) / args.slug
    if not weights_path.exists():
        print(f"ERROR: weights not found at {weights_path}", file=sys.stderr)
        print(f"  Run: cactus download Qwen/Qwen3-Embedding-0.6B", file=sys.stderr)
        return 1

    from cactus import cactus_init, cactus_embed, cactus_destroy

    print(f"[init] loading {weights_path.name} ...")
    t0 = time.monotonic()
    model = cactus_init(str(weights_path), "", False)
    print(f"  init in {time.monotonic()-t0:.2f}s")

    try:
        total_notes = 0
        for role in ("a", "b"):
            path = REPO_ROOT / "assets" / f"seed_notes_{role}.json"
            notes = json.loads(path.read_text())
            print(f"\n[seed_notes_{role}] {len(notes)} notes")
            for n in notes:
                old_dim = len(n.get("embedding", []))
                t0 = time.monotonic()
                new_emb = list(cactus_embed(model, n["body"], True))
                dt = time.monotonic() - t0
                # Sanity: cosine of old vs new embedding (just for human read).
                # We expect *low* cosine — they're from different models.
                if old_dim == len(new_emb):
                    old = n["embedding"]
                    dot = sum(a*b for a, b in zip(old, new_emb))
                    import math
                    na = math.sqrt(sum(a*a for a in old))
                    nb = math.sqrt(sum(b*b for b in new_emb))
                    sim = dot / (na * nb) if na and nb else 0.0
                else:
                    sim = float("nan")
                print(f"  [{n['topic']:<16}] {dt*1000:5.0f}ms  "
                      f"old_dim={old_dim} new_dim={len(new_emb)} "
                      f"old_vs_new_cos={sim:+.3f}")
                n["embedding"] = new_emb
                total_notes += 1
            if not args.dry_run:
                # Stable formatting that matches the existing seed shape.
                path.write_text(json.dumps(notes, indent=2) + "\n")
                print(f"  wrote {path}")
            else:
                print(f"  (dry-run, not writing)")
        print(f"\ntotal: {total_notes} notes re-embedded against {weights_path.name}")
    finally:
        cactus_destroy(model)
    return 0


if __name__ == "__main__":
    sys.exit(main())
