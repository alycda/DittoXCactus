# Mesh RAG — hackathon build doc

**Status:** narrowing
**Frame:** personal weekend build, deliverable is a blog-post-shaped artifact (working demo + writeup that teaches something)
**Parent brainstorm:** [README](../README.md)
**Date:** 2026-05-21

## The thesis

**Your knowledge base wants to be a CRDT.**

Vector stores are additive (every embedding is a point in a space; nothing ever needs to be reconciled). Relevance is a local function over a set. So a vector index is the cleanest possible CRDT shape: a grow-only set of (embedding, payload) tuples. Put one inside Ditto and corpora compound additively as devices meet, with no central store and no upload.

The writeup argues that *retrieval-augmented* is the AI primitive most naturally aligned with peer-to-peer sync — more so than chat history, more so than weights, more so than caches.

## What it actually is

Each device runs:
- A Cactus-loaded embedding model (identical across devices)
- A Cactus-loaded small LLM for final answer generation
- A Ditto store holding `{ id, text, embedding[], metadata }` tuples

At query time:
- Embed the query locally with Cactus
- Run cosine similarity against the local Ditto store
- Hand top-k tuples + query to the local LLM
- Return an answer

When two devices come into range:
- Ditto syncs the tuples bidirectionally over BLE/LAN
- Next query draws on the combined corpus, instantly

No central server. No internet. The mesh *is* the index.

## Staged build plan

Ship the smallest version first; escalate only if there's runway left.

### Stage 0 — Toy

- Two phones (likely 2 × Android or 1 × iPhone + 1 × Android, both Flutter)
- ~5 short text notes preloaded per device, hardcoded
- Single text-box query interface, no chat history
- Cactus runs the embedding model + a small LLM for the final answer
- Ditto stores notes + embeddings, mesh-syncs them over LAN/BLE
- **Moment of magic:** ask the same query on phone A before and after phone B comes into range. The answer visibly draws on phone B's notes the second they sync.
- **Limitation:** with ~5 hardcoded notes, Stage 0 is optimized for curated queries; surviving an audience-picked query is explicitly Stage 1 territory.

### Stage 1 — Plausible 

- ~50 notes per device, simple paste-in or import flow
- Maybe add photos with captions as a second corpus type
- Slightly less staged — the demo can survive a query the audience picks

### Stage 2 — Convincing (if Sunday is free)

- Real corpus integration on one device (notes app contents, a small PDF library)
- Demo becomes "I brought my real notes; ask anything"
- Diminishing returns vs. risk of ingestion-plumbing eating the writeup time

## The hard part to watch

- **Embedding model must be identical and stable across devices.** Otherwise cosine distances aren't comparable and the merge is meaningless. Cactus's model packaging story is the critical-path dependency — confirm one runs deterministically across both devices in the chosen pair (and across iOS and Android if the pair is mixed) before anything else.
- If the embedding model is large, Cactus's zero-copy memory-mapping capability matters — cold-load time on a mid-range Android could dominate the demo.
- **Fallback if blocked:** pivot to brainstorm option C ("Narrate the mesh" — use the local LLM to produce a human-readable activity feed over the Ditto change stream, retrofittable to any Ditto app). C does not depend on Cactus's model packaging story.

## Open decisions

- **Corpus theme for Stage 0** — generic notes (movies/study notes/travel), Ditto's canonical `cars`-collection vibe (notes *about* cars), or a niche that makes the demo more memorable?
- **Add a laptop as a third surface?** — Stage 0 commits to phones-only. Adding a macOS laptop would make heterogeneity visible and show Cactus on a third platform. Worth the demo complexity?
- **Durability of the thesis** — the writeup needs a non-rising-tide answer to "why does this still matter when cloud RAG is cheaper and faster in a year?" TBD.

## Notes / scratch

- Cactus claims: 120ms on-device latency, hybrid cloud fallback, supports Flutter + Swift + Kotlin + RN + C++ + Python, zero-copy memory mapping for embeddings. All to be verified empirically during the loop.
- The Flutter overlap is the cheapest entry point — both SDKs are already known territory.
- The `cars` collection is Ditto's canonical demo data; default to `car1, car2, ...` if scenario is abstract.
