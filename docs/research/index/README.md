# Mesh RAG (Ditto × Cactus) — Research Index

> Entry point for a downstream coding agent. You are starting work on a peer-to-peer RAG system where the vector index is a CRDT, synced over BLE/LAN via Ditto, with on-device embedding + LLM inference via Cactus on iOS and Android. This index points at the prior art that has already been collected. **Start with [top-N.md](top-N.md) — it's twelve sources, twenty minutes of reading, ranked.**

## What's in this directory

| File | Purpose | Read when |
|---|---|---|
| [top-N.md](top-N.md) | Twelve must-read sources, ranked, with one-paragraph annotations | First. Always. |
| [clusters.md](clusters.md) | Ten thematic clusters with density-ordered source lists | When you need to dive into a specific area |
| [by-topic.md](by-topic.md) | Topic → sources lookup | When orienting on a concrete sub-problem |
| [by-tag.md](by-tag.md) | Tag → sources lookup (323 unique tags across 69 sources) | For wide-net searches |
| [cross-references.md](cross-references.md) | Source-to-source citation graph | When you've found one good source and want adjacent ones |
| [open-questions.md](open-questions.md) | Gaps the prior art doesn't answer + the four-thread future-work arc that the writeup should land on | Before designing anything new; before writing the post |
| `_per_source/*.md` | One ~30-line summary per source (69 files) | When the index points you at a specific source — read the summary before opening the underlying material |

## Materials on disk

- `inspiration/papers/` — 30 arxiv-style PDFs (~57 MB)
- `inspiration/repos/` — 31 shallow git clones (`--depth=1`, ~423 MB)
- `inspiration/docs/` — 11 mirrored docs subtrees (~2.8 MB)
- `docs/research/downloads.yaml` — the canonical manifest; status field tracks `done | failed | skipped | pending`. **72 entries (mostly `kind: other` HuggingFace model cards + `kind: article` blog posts) are still `pending` — triaged out of the initial download pass for being lower signal; fetch ad-hoc as needed.**

## Data-flow honesty (read before trusting the index)

The index is the synthesis of three independent layers:

1. **Mode B web research** (`docs/research/claude.md`, `docs/research/codex.md`, `docs/research/gemini.md`). Three independent researchers ran the brief via web search/fetch; the Claude pass is the highest-signal (425 lines, 100 URLs cited with paragraph annotations). **For paper-level content, prefer the worker outputs over the per-source files** — those workers actually read the abstracts and engineering blogs they cite.
2. **Per-source Map summaries** (`_per_source/*.md`). One file per item on disk; produced by Haiku sub-agents in eight parallel batches. These are *catalog entries* — tags, density score, "what we'd take from this." For repos and docs the Map agents read READMEs and HTML directly. **For papers, PDF text extraction was not available in the indexing environment (`poppler-utils` not installed), so paper summaries are derived from titles + topical inference, not direct PDF reads.** Three known-fabricated paper summaries (paper-2308.14963, paper-2406.10290, paper-2505.11783) were corrected by Opus from arxiv abstract pages and now carry an explicit caveat. Other paper summaries should be cross-referenced against the worker outputs before being load-bearing.
3. **The Reduce-phase aggregations** (the seven `*.md` files at the root of this directory). Synthesized by Opus from the worksheet + worker outputs, with explicit cross-checks against the worker findings where claims were load-bearing.

## The project this is for

See [`../../SEED.md`](../../SEED.md) and [`../../RESEARCH-BRIEF.md`](../../RESEARCH-BRIEF.md) at the repo root. One-line version: *Your knowledge base wants to be a CRDT.* The hackathon deliverable is a two-device demo (iOS + Android), airplane mode toggled live; the corpus is recipes (audience-submitted "virtual potluck" variants); the writeup's thesis is **latency + offline-first** (not cost) as durable properties cloud RAG cannot match.

## The writeup arc to land on

This is in [open-questions.md](open-questions.md) too but worth stating once at the top: the writeup should treat Stage-0 (generalist small LLM + flat grow-only CRDT union) as a stepping stone, not the destination, and gesture at a four-thread future-work arc — *specialists, not generalists; preference-aware merge; adversarial filtering; generational evolution.* Family recipes through generations is the load-bearing analogy.
