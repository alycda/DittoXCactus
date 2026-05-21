# SEED: Mesh RAG

> Entry point for agentic development. Follow the loop: Validation → Feedback → repeat until holdout scenarios pass and stay passing.

---

## What We're Building

A peer-to-peer retrieval-augmented generation system in which the vector index *is* a CRDT. Each device runs an identical on-device embedding model (Cactus), an on-device small LLM (Cactus), and a Ditto store of `{ id, text, embedding[], metadata }` tuples. Queries are answered locally; when two devices meet, Ditto syncs the tuples bidirectionally over BLE/LAN, and each device's next query draws on the combined corpus instantly — with no central server, no internet, no upload.

The deliverable is a blog-post-shaped artifact: a working two-device demo plus a writeup that argues *retrieval-augmented* is the AI primitive most naturally aligned with peer-to-peer sync — more so than chat history, more so than weights, more so than caches.

**One-line version:** Your knowledge base wants to be a CRDT.

---

## Why This Exists

**Current state:** RAG today assumes a centralized vector store. Every corpus is uploaded, indexed server-side, and queried over the network. This is fine for cloud-only deployments but breaks the local-first story: it cannot work offline, cannot compose corpora across devices without a sync server, and forces a privacy tradeoff that on-device inference otherwise avoids.

**Target state:** A demonstrable existence proof that the vector-index shape — a grow-only set of (embedding, payload) tuples whose retrieval is a local function over the set — is the cleanest possible CRDT for AI. Two phones running airplane-mode, meeting briefly over BLE, leave with the union of each other's corpora and can answer questions that neither could before.

**Secondary use case:** A live hackathon demo + writeup that frames Ditto's mesh-sync primitive as the missing infrastructure layer for edge AI, and Cactus's identical-cross-platform model packaging as the missing primitive for distributed inference. Both companies get a concrete shared story.

---

## Validation Harness

> Must be end-to-end, as close to real as possible: real binary, real protocol, real platform matrix.

### Holdout Scenarios (loop runs until these pass and stay passing)

| # | Scenario | Platform |
|---|----------|----------|
| 1 | "Airplane-mode moment of magic": phone A queries its local corpus and returns answer X. Phone B comes into BLE range. Phone A re-queries and returns answer X + Y, visibly drawing on phone B's notes. Recorded on camera with airplane mode toggled live. | 2 phones (iOS+iOS or iOS+Android) |
| 2 | Embedding determinism: the exact same text embedded on device A and device B produces vectors with cosine similarity > 0.999 (ideally bit-identical). Cross-platform if the demo uses iOS+Android. | iOS + Android (or iOS + macOS) |
| 3 | Sync idempotence: re-meeting after no changes produces no duplicate tuples and no change to top-k results for any query. | Two devices, repeated BLE meet |
| 4 | Bidirectional merge: notes pushed from A appear in B's index and vice versa, observable through queries whose nearest neighbors live on the other device. | Two devices |
| 5 | Cold-load latency: on the slowest target device, the embedding + LLM models load and produce a first answer in under ~10s after app start. | Slowest target device (likely mid-range Android if used) |
| 6 | Stage 1 audience survival: the audience picks a free-text query, the system retrieves top-k from the combined corpus and the small LLM generates a coherent answer that visibly references retrieved notes. | Two devices, ~50 notes/device |
| 7 | End-to-end offline: the full demo runs with no network connectivity available to either device (Wi-Fi off, cellular off, only BLE/LAN). | Two devices |

### What "Real Environment" Means Here

- Real Cactus runtime loading a real model on each device (not a stub or a server proxy).
- Real Ditto SDK with real mesh sync over BLE and/or LAN (not a mocked sync layer).
- Heterogeneous hardware on at least one holdout (iOS + Android, or iOS + macOS) to prove the cross-platform identical-embedding claim.
- Demo conditions: live airplane-mode toggle, on camera, in a single take.
- A small but real corpus per device — text the audience can read on screen and follow along with.

### What Is NOT "Real" (explicitly out of scope)

- Cloud fallback / Cactus hybrid mode. The thesis breaks if we cheat with cloud.
- Document ingestion plumbing for arbitrary file types (PDFs, EPUBs, archives). Stage 2 territory only if Sunday is free.
- Multi-user identity, authentication, or access control on the synced corpus.
- Persistent chat history.
- Streaming token output.
- Production-grade UI polish, settings panels, error toasts.
- Web/desktop clients beyond the demo machine (one optional macOS via Flutter; no browser client).

---

## Feedback Loop

Each run of the validation harness produces a feedback signal fed back into the inputs:

| Output | Fed Back As |
|--------|-------------|
| Live demo dry-run video (Holdout 1) | Direct visual evidence of which step looks unconvincing — feeds corpus selection, UI affordances, query phrasing. |
| Cross-device embedding determinism trace (Holdout 2) | If cosine ≤ 0.999, forces model swap, version-pinning, or pivoting to brainstorm option C. |
| BLE peer-discovery + sync timing trace | Tunes Ditto small-peer config; may force LAN-first demo if BLE pairing is flaky on the chosen hardware. |
| Cold-load latency profile on slowest device (Holdout 5) | Forces model-size downgrade, zero-copy mmap verification, or eager-load on app start. |
| Top-k retrieval miss on a known-good query | Triggers corpus pruning, re-embedding, or model-eval comparison. |
| Stage 1 audience-query miss (Holdout 6) | Broadens or re-themes corpus; may force Stage-0-only ship if Stage 1 is not survivable. |
| Writeup draft reactions (informal review) | Sharpens the "why mesh RAG matters in a year" framing; may force restructuring around a non-obvious thesis. |

**Loop exit condition:** Holdouts 1–5 + 7 pass on the chosen hardware in a single recorded take; Holdout 6 passes for at least 3 of 5 audience-picked queries; writeup draft is complete enough to share publicly.

---

## Apply More Tokens

> For every obstacle, ask: how can we convert this problem into a representation the model can understand?

| Obstacle | Token Form |
|----------|------------|
| Cactus model packaging must produce identical embeddings across iOS + Android + macOS | Cactus official docs, GitHub repo + example projects, model card / weights manifest, any release-notes mention of determinism guarantees, community issues/discussions about cross-platform parity. |
| Ditto mesh sync over BLE on mixed iOS/Android pairs has known quirks | Ditto SDK docs (especially small-peer + BLE transport guides), example apps, blog posts from prior Ditto demos, public CI traces / issue threads. |
| Choosing a small LLM that runs at acceptable latency on a mid-range Android and is shipped by Cactus | Cactus model catalog, on-device LLM benchmarks (mobile inference latency tables), HF model cards for candidate small models. |
| Cosine equivalence verification across platforms is hard to debug visually | Side-by-side device traces / screen captures of identical inputs; a small CLI harness that prints first-N components of each vector for diff. |
| Selecting an audience-survivable corpus theme | Past hackathon demo videos / writeups; common RAG-demo failure modes documented in blog posts; Ditto's canonical `cars` collection as a baseline anchor. |
| Writeup framing — answering "why does mesh RAG still matter when cloud RAG is cheaper next year?" | Local-first software essays (Kleppmann et al.), CRDT survey papers, edge-AI manifestos, prior writeups on offline-first AI, and the parent brainstorm at https://hackmd.io/@alyssaditto/rkeKeeaJzg. |
| BLE pairing flakiness on demo day | Pre-recorded "airplane mode + meet" capture as fallback B-roll; rehearsed LAN-only fallback path; second hardware pair on standby. |

---

## Related Tickets

- Parent brainstorm: https://hackmd.io/@alyssaditto/rkeKeeaJzg
- Source idea doc: [IDEA-A.md](IDEA-A.md)
- Fallback option (if Cactus embedding determinism blocks): brainstorm option C, "Narrate the mesh"

---

## Open Questions

The following items are unresolved as of seed authoring. Resolutions should be folded back in-line and the section retitled "Open Questions (Resolved)".

1. **Corpus theme for Stage 0** — generic notes (movies / recipes / travel), Ditto-canonical `cars`-collection vibe (notes *about* cars), or a niche that makes the demo memorable? The choice affects which query phrasings work and how legible the "moment of magic" is on camera.

2. **Hardware mix** — two phones only (cleanest visual story), or include a laptop to make heterogeneity visible and show Cactus running on macOS too? Heterogeneity is part of the thesis; the question is whether it's worth the demo complexity.

3. **Connectivity reveal mechanism** — toggle airplane mode on camera (high credibility, slight risk of mid-demo radio quirks), or take "offline" on faith with a verbal claim (low risk, lower credibility)?

4. **Durability of the thesis** — the writeup needs a non-rising-tide answer to "why does this still matter when cloud RAG is cheaper and faster in a year?" Candidate framings: privacy / offline-by-default / "knowledge composes when devices meet, like Bluetooth pairing for ideas" / mesh as the substrate for AI between strangers. Which one carries the writeup?

5. **Cactus small-LLM choice** — which model under Cactus runs at acceptable latency on the slowest target device AND produces coherent answers given the small corpus + retrieved context? Open dependency on the Cactus model catalog at research time.

6. **Demo artifact form** — is the deliverable "blog post + recorded demo video", "blog post + working repo", or both? Affects how much code polish vs. writeup time gets prioritized in the final hours.

7. **Embedding model selection criteria** — small enough to load fast, large enough to give meaningful cosine separation on a hand-picked ~50-note corpus, and shipped by Cactus with deterministic cross-platform output. Which model in the Cactus catalog clears that bar?

---

*Seed authored: 2026-05-21. Loop not yet started. Holdout scenarios: not yet green.*
