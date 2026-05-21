# Mesh RAG (Ditto × Cactus) — Research Index

> Entry point for a downstream coding agent. You are starting work on a peer-to-peer RAG system where the vector index is a CRDT, synced over BLE/LAN via Ditto, with on-device embedding + LLM inference via Cactus on iOS and Android. This index points at the prior art that has already been collected. **Start with [top-N.md](top-N.md) — twenty-two sources, ~45 minutes of reading, ranked.**

## What's in this directory

| File | Purpose | Read when |
|---|---|---|
| [top-N.md](top-N.md) | 22 must-read sources, ranked, with one-paragraph annotations | First. Always. |
| [clusters.md](clusters.md) | 13 thematic research narratives — different lens than `by-topic.md`, every source lands in at least one cluster | When you need a *story-shaped* dive into one area |
| [by-topic.md](by-topic.md) | 13 macro-topic groupings mapped to the SEED.md task structure | When orienting on a concrete sub-problem (embeddings, LLMs, CRDTs, mesh sync, ...) |
| [by-tag.md](by-tag.md) | Tag → sources inverted index (1192 distinct tags across 281 sources) | For wide-net searches by exact tag |
| [cross-references.md](cross-references.md) | Source-to-source citation graph (541 edges, 230 sourceful nodes, foundational sources ranked) | When you've found one good source and want adjacent ones |
| [open-questions.md](open-questions.md) | Gaps the prior art doesn't answer + the four-thread future-work arc the writeup should land on | Before designing anything new; before writing the post |
| `_per_source/*.md` | One ~30-line summary per source (281 files, canonical 7-section template) | When the index points you at a specific source — read the summary before opening the underlying material |

## Density legend

Every per-source file carries a density score in its metadata block:

- **5 — must-read.** Directly load-bearing for the demo or writeup; 64 sources at this level.
- **4 — strong relevance.** Worth reading in full; 90 sources.
- **3 — partial relevance.** Read the elevator + key takeaways; 79 sources.
- **2 — adjacent / supporting.** Skim only if you're working in the specific area; 32 sources.
- **1 — barely relevant.** Kept for completeness; 16 sources.

## How to navigate

- If you want to understand the **whole thesis in one sitting,** read [top-N.md](top-N.md) end-to-end.
- If you want to **build the demo,** start with C3 (Ditto) and C5 (Cactus + LLM runtimes) in [clusters.md](clusters.md), then C9 (vector search).
- If you want to **write the post,** start with C1 (case for on-device), C6 (determinism), and C7 (specialists), then read [open-questions.md](open-questions.md) for the future-work arc.
- If you want **closest prior art,** read C8 (Distributed/decentralized RAG) — SHIMI, DRAG, MobileRAG, EdgeRAG — and the corresponding [cross-references.md](cross-references.md) section.

## Materials on disk

- `inspiration/papers/` — arxiv PDFs
- `inspiration/repos/` — shallow git clones
- `inspiration/docs/` — mirrored docs subtrees
- `inspiration/articles/` and `inspiration/other/` — HTML mirrors of blogs and reference pages
- `docs/research/downloads.yaml` — canonical manifest with `status: done | failed | skipped | pending`

## Data-flow honesty (read before trusting the index)

The index is the synthesis of three independent layers:

1. **Mode B web research** (`docs/research/claude.md`, `docs/research/codex.md`, `docs/research/gemini.md`). Three independent researchers ran the brief via web search/fetch; the Claude pass is the highest-signal anchor narrative. **For paper-level content, prefer the worker outputs over the per-source files** — those workers actually read the abstracts and engineering blogs they cite.
2. **Per-source Map summaries** (`_per_source/*.md`). One file per item on disk. These are *catalog entries* — tags, density score, "what we'd take from this." For papers without full PDF extraction, summaries are derived from titles + topical inference; cross-reference against the worker outputs before treating any paper claim as load-bearing.
3. **The Reduce-phase aggregations** (the seven `*.md` files at the root of this directory). Synthesized from the per-source files + worker outputs.

## The project this is for

See [`../../SEED.md`](../../SEED.md) and [`../../RESEARCH-BRIEF.md`](../../RESEARCH-BRIEF.md) at the repo root, plus the narrative anchor at [`../CLAUDE.md`](../CLAUDE.md). One-line version: *Your knowledge base wants to be a CRDT.* The hackathon deliverable is a two-device demo (iOS + Android), airplane mode toggled live; the corpus is recipes (audience-submitted "virtual potluck" variants); the writeup's thesis is **latency + offline-first** (not cost) as durable properties cloud RAG cannot match.

## The writeup arc to land on

Detailed in [open-questions.md](open-questions.md). The writeup should treat Stage-0 (generalist small LLM + flat grow-only CRDT union) as a stepping stone, not the destination, and gesture at a four-thread future-work arc — *specialists, not generalists; preference-aware merge; adversarial filtering; generational evolution.* Family recipes through generations is the load-bearing analogy.

`_per_source/` is the source-of-truth detail. Edit the aggregation files only when re-running the Reduce phase against a fresh `_per_source/`.
