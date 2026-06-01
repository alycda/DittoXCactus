---
title: "Package mesh-RAG reusable parts as agent skills — ship-or-skip parallel deliverable"
date: 2026-06-01
category: tooling-decisions
module: agent-skills
problem_type: tooling_decision
component: tooling
severity: low
applies_when:
  - Stage 0 + Stage 1 demo holdouts are not at risk
  - There is runway between the recorded artifact and the writeup deadline
  - Reviewing what the hackathon produces beyond the recorded demo
  - Scoping a parallel deliverable that compounds beyond the single artifact
related_components:
  - tooling
  - documentation
tags:
  - agent-skills
  - hackathon
  - deliverable
  - flutter-skills
  - firebase-ai-assistance
  - compounding
---

# Package mesh-RAG reusable parts as agent skills — ship-or-skip parallel deliverable

## Context

The DittoXCactus hackathon's primary deliverable is a recorded artifact: two phones, mesh sync, on-device retrieval-augmented flashcards, end-to-end offline. A demo. The demo's value compounds further if it also produces **reusable infrastructure** that future agents can reach for as a skill, instead of starting from scratch.

The product-lens persona's review of the SEED flagged this as a gap: *"seed treats deliverable as self-contained; doesn't name reusable byproducts."* Agent-skills packaging is the answer to that gap. The build harness for the demo itself already loads several `flutter-*` skills from [flutter/skills](https://github.com/flutter/skills), which is a working example of the format we're targeting — eat what we ship.

This decision is **runway-gated**, not load-bearing: if the demo's hard holdouts (airplane-mode moment of magic, top-k stability, sync idempotence, cold-load latency, full-offline) are at risk, skip this entirely. Tracked in `_docs/RESEARCH-BRIEF.md` under Holdouts as "ship-or-skip; build alongside if Stage 0/1 isn't at risk."

## Guidance

If runway permits, package the demo's reusable parts as agent skills in two formats:

1. **Firebase AI assistance agent skills** — https://firebase.google.com/docs/ai-assistance/agent-skills
2. **Flutter skills** — https://github.com/flutter/skills (already in active use as this demo's build harness, so we know the format works for both authors and consumers)

The parts genuinely worth packaging (in priority order):

- **The Ditto + Cactus pairing pattern for on-device RAG.** Ditto for the materialized vector layer (`{ _id, text, embedding[], metadata }` G-set), Cactus for embedder + completion. The interesting move is treating embeddings as content-addressed CRDT rows so the index merges by construction.
- **The embedding-as-CRDT pattern.** Specifically: UUIDv5 content-addressed `_id` over normalized text, `ON ID CONFLICT DO UPDATE` upsert semantics, brute-force cosine over the materialized snapshot. Trivially adaptable to any small-corpus on-device RAG.
- **The carsapp-shape adaptation for tuples.** Composite `_id`, upsert/observe/delete DQL — Ditto's carsapp template is the closest published example; this is the "what would it look like if the corpus were study notes instead of cars" adaptation.

## Why This Matters

A recorded artifact has a half-life — once the hackathon ends, the demo is a static reference. Skills are different: they get pulled into other agents' contexts, executed, modified, criticized. They compound across projects in a way a YouTube clip cannot.

The compounding-engineering thesis specifically rewards this kind of byproduct. The recorded demo is the headline result; the skills are the lasting infrastructure. If both ship, the writeup's "what we built that compounds" section becomes much stronger — and the skills become evidence that the demo's patterns are extractable, not bespoke.

## When to Apply

- After Stage 0/1 hard holdouts have **passed live** on the Pixel pair (R1+R3+R4+R7 cleared 2026-05-26)
- Before the writeup deadline closes
- Specifically NOT during weeks when blocking demo work is open
- If a holdout pivot has triggered (e.g. R2 determinism check fails and the project shifts to brainstorm option C), drop this entirely

## Examples

Reusable parts at concrete repo locations:

- **Embedding-as-CRDT G-set substrate:** [lib/services/seed_loader.dart](../../../lib/services/seed_loader.dart) — UUIDv5 content-addressed `_id`, upsert semantics, idempotent re-seed
- **Brute-force cosine on materialized rows:** [lib/services/retrieval_service.dart:506](../../../lib/services/retrieval_service.dart) — `dot(normalize(query), normalize(doc))`, threshold + entity filter
- **Ditto config for mesh-only / offline:** [lib/services/ditto_service.dart](../../../lib/services/ditto_service.dart) — `DittoConfigConnectSmallPeersOnly` + offline-only license, BLE + LAN + AWDL
- **Cactus seam workarounds:** [_docs/notes/cactus-sdk-quirks.md](../../../_docs/notes/cactus-sdk-quirks.md) — the SDK gotchas a skill consumer needs to know about

A useful litmus test before authoring a skill: *would I want a future me to start a different mesh-RAG project by writing this code from scratch, or by invoking this skill?* If the answer is "from scratch" — it's not a skill, it's just code.

## Related

- Flutter skills already in active use: see CLAUDE.md "Flutter agent tooling" section
- SEED context: `_docs/SEED.md` (validation harness + holdouts)
- Research brief that named this as a deliverable: `_docs/RESEARCH-BRIEF.md` (Holdouts section)
- Compounding-engineering plugin: this skill itself is an example of what a well-shaped skill looks like (`/Users/alyssaevans/.claude/plugins/cache/compound-engineering-plugin/`)
