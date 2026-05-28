#!/usr/bin/env python3
"""Regenerate the pre-computed embedding vectors in
`assets/seed_notes_{a,b}.json` against a different Cactus embedder.

Why: the seed JSONs ship with pre-computed embeddings so the on-device boot
doesn't re-embed five notes at startup. Swapping the default embedder (e.g.,
chat-tuned `qwen3-0.6` → dedicated `qwen3-0.6-embed` per issue #9) requires
regenerating those embedding arrays so the cached vectors live in the same
space as what the device will use for query-side embeddings.

**Text-formula invariant.** This script must embed exactly the same text as
the on-device backfill path (`RetrievalService._embeddingInputFor`). That
formula is `'{topic}. {body[:200]}'`. If those two formulas diverge, seed
embeddings and runtime-backfilled embeddings land in different sub-spaces
and cosine retrieval geometry breaks silently. Keep these in lockstep on
any future change.

**Two different "slugs" — pay attention.**

- The *Flutter SDK catalog slug* (e.g., `qwen3-0.6-embed`) is what
  `CactusService.preferredEmbeddingSlug` in `lib/services/cactus_service.dart`
  uses to fetch a model on-device.
- The *local Cactus weights directory name* (e.g., `qwen3-embedding-0.6b`)
  is the folder the brew-installed `cactus download` CLI writes weights to.

These often differ. The `--weights-dir` flag below names the *local
directory*, not the SDK slug.

Usage:
    python3 tools/regen_seed_embeddings.py [--weights-dir qwen3-embedding-0.6b] \\
        [--weights-root /opt/homebrew/opt/cactus/libexec/weights] \\
        [--dry-run]
"""
from __future__ import annotations

import argparse
import json
import math
import os
import sys
import time
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parent.parent
# Brew's stable symlink path — survives `brew upgrade cactus`.
DEFAULT_WEIGHTS_ROOT = Path("/opt/homebrew/opt/cactus/libexec/weights")
# Local directory name under WEIGHTS_ROOT — NOT the Flutter SDK slug.
DEFAULT_WEIGHTS_DIR_NAME = "qwen3-embedding-0.6b"

EXPECTED_EMBEDDING_DIM = 1024


def _embedding_input_for(note: dict[str, Any]) -> str:
    """Mirror `RetrievalService._embeddingInputFor` in lib/services/retrieval_service.dart.

    The on-device backfill path embeds `'{topic}. {body[:200]}'`. Seed
    embeddings MUST use the same input formula to avoid sub-space drift.
    """
    body = note["body"]
    preview = body[:200] if len(body) > 200 else body
    return f"{note['topic']}. {preview}"


def _atomic_write(path: Path, content: str) -> None:
    """POSIX-atomic write via tempfile + os.replace on the same filesystem."""
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(content)
    os.replace(tmp, path)


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument(
        "--weights-dir",
        default=DEFAULT_WEIGHTS_DIR_NAME,
        help=(
            f"Local Cactus weights directory name under --weights-root "
            f"(default: {DEFAULT_WEIGHTS_DIR_NAME!r}). NOT the Flutter SDK "
            f"catalog slug."
        ),
    )
    p.add_argument(
        "--weights-root",
        default=str(DEFAULT_WEIGHTS_ROOT),
        help=(
            f"Parent dir containing Cactus weight folders "
            f"(default: {str(DEFAULT_WEIGHTS_ROOT)!r}, brew's stable symlink)."
        ),
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="Embed + diff but do not write back to disk.",
    )
    args = p.parse_args()

    weights_path = Path(args.weights_root) / args.weights_dir
    if not weights_path.exists():
        print(f"ERROR: weights not found at {weights_path}", file=sys.stderr)
        print(
            f"  Run: cactus download Qwen/Qwen3-Embedding-0.6B "
            f"(or correct --weights-root / --weights-dir).",
            file=sys.stderr,
        )
        return 1

    from cactus import cactus_init, cactus_embed, cactus_destroy

    print(f"[init] loading {weights_path.name} ...")
    t0 = time.monotonic()
    model = cactus_init(str(weights_path), "", False)
    if not model:
        print(
            f"ERROR: cactus_init returned falsy handle for {weights_path}",
            file=sys.stderr,
        )
        return 1
    print(f"  init in {time.monotonic() - t0:.2f}s")

    # Embed everything into memory first, validate dims + non-zero, then write
    # all role files in a second pass. Prevents partial-state where role 'a'
    # writes successfully and role 'b' fails mid-run.
    pending: list[tuple[Path, list[dict[str, Any]]]] = []

    try:
        for role in ("a", "b"):
            path = REPO_ROOT / "assets" / f"seed_notes_{role}.json"
            notes: list[dict[str, Any]] = json.loads(path.read_text())
            print(f"\n[seed_notes_{role}] {len(notes)} notes")
            for n in notes:
                old_dim = len(n.get("embedding", []))
                text = _embedding_input_for(n)
                t0 = time.monotonic()
                new_emb = list(cactus_embed(model, text, True))
                dt = time.monotonic() - t0

                # Fail-fast on degenerate vectors. Cactus has surfaced bad
                # embeddings via RC>=0 in the past; an all-zero or wrong-dim
                # vector silently corrupts retrieval geometry.
                if len(new_emb) != EXPECTED_EMBEDDING_DIM:
                    raise RuntimeError(
                        f"embedding dim mismatch for {n['topic']!r}: "
                        f"got {len(new_emb)}, expected {EXPECTED_EMBEDDING_DIM}"
                    )
                if not any(abs(x) > 1e-9 for x in new_emb):
                    raise RuntimeError(
                        f"embedding is all-zero for {n['topic']!r}; "
                        f"cactus_embed likely failed silently"
                    )

                if old_dim == len(new_emb):
                    old = n["embedding"]
                    dot = sum(a * b for a, b in zip(old, new_emb))
                    na = math.sqrt(sum(a * a for a in old))
                    nb = math.sqrt(sum(b * b for b in new_emb))
                    sim = dot / (na * nb) if na and nb else 0.0
                else:
                    sim = float("nan")
                print(
                    f"  [{n['topic']:<16}] {dt * 1000:5.0f}ms  "
                    f"old_dim={old_dim} new_dim={len(new_emb)} "
                    f"old_vs_new_cos={sim:+.3f}  text={text[:60]!r}"
                )
                n["embedding"] = new_emb
            pending.append((path, notes))
    finally:
        cactus_destroy(model)

    if args.dry_run:
        print(f"\n(dry-run, not writing {len(pending)} file(s))")
        return 0

    # Second pass — write both files atomically. If we got here, all
    # embeddings passed validation.
    total_notes = 0
    for path, notes in pending:
        _atomic_write(path, json.dumps(notes, indent=2) + "\n")
        print(f"  wrote {path}")
        total_notes += len(notes)
    print(f"\ntotal: {total_notes} notes re-embedded against {weights_path.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
