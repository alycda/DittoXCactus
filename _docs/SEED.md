# SEED: Mesh RAG

> Entry point for agentic development. Follow the loop: Validation → Feedback → repeat until holdout scenarios pass and stay passing.

---

## What We're Building

A peer-to-peer retrieval-augmented generation system in which the vector index is a CRDT. Each device runs an identical on-device embedding model (Cactus), an on-device small LLM (Cactus), and a Ditto store of `{ id, text, embedding[], metadata }` tuples. Queries are answered locally; when two devices meet, Ditto syncs the tuples bidirectionally over BLE/LAN, and each device's next query draws on the combined corpus instantly — with no central server, no internet, no upload.

The deliverable is a working two-device demo plus a writeup that argues *retrieval-augmented* is a particularly natural fit for peer-to-peer sync among AI primitives. Weights mutate non-monotonically (averaging is lossy and requires coordination); chat history is per-author and doesn't compose into new answerable knowledge across users; caches are derived state. RAG's corpus is the rare AI substrate that is monotonic, composable, and queryable.

**One-line version:** Your knowledge base wants to be a CRDT.

---

## Why This Exists

**Current state:** RAG today assumes a centralized vector store. Every corpus is uploaded, indexed server-side, and queried over the network. This works for cloud-only deployments but breaks the local-first story: it cannot work offline, cannot compose corpora across devices without a sync server, and routes all corpus content through a third-party operator.

**Target state:** A demonstrable existence proof that the vector-index shape — a grow-only set of (embedding, payload) tuples whose retrieval is a local function over the set — is a clean CRDT fit for AI. The construction itself is a textbook G-set (Shapiro et al., 2011); the novelty here is the *composition* — retrieval is a pure function over the G-set, so mesh sync is correctness-preserving by construction, and that property is what the demo makes legible. Two phones running airplane-mode, meeting briefly over BLE, leave with the union of each other's corpora and can answer questions that neither could before.

**Secondary use case:** A live hackathon demo + writeup that frames Ditto's mesh-sync primitive as a candidate infrastructure layer for edge AI, and Cactus's cross-platform packaging (with determinism verified empirically by Holdout 2) as a candidate primitive for distributed inference. Both companies share a concrete joint story: mesh-RAG as a reference architecture for edge AI that composes across devices.

**Privacy scope.** This design eliminates the cloud operator from the trust boundary — corpus content stays on devices that choose to mesh. It does *not* provide device-to-device confidentiality: any peer that runs the same Ditto app and enters BLE/LAN range will absorb tuples from any other. Mesh sharing is intentional disclosure to chosen peers, not privacy from peers. See "Threat model bound" below.

**Threat model bound.** Corpus injection and embedding poisoning are known out-of-scope threats for this demo. The grow-only CRDT has no peer authentication, no tuple provenance signatures, and no corpus access-control list — a hostile peer in range can inject arbitrary tuples, including adversarial embeddings crafted to hijack top-k retrieval. A production system would need peer authentication, signed provenance, and a corpus ACL; this demo doesn't have those and the writeup will say so plainly.

---

## Validation Harness

> Must be end-to-end, as close to real as possible: real binary, real protocol, real platform matrix.

### Staging

- **Stage 0** — two-device CRDT sync demo. Required holdouts: 1–5 + 7. Goal served: existence proof.
- **Stage 1** — audience-survivable RAG-over-mesh (LLM generation over retrieved tuples). Required holdouts: Stage 0 plus Holdout 6a (rehearsed coherence). Holdout 6b (free-text audience survival) is a stretch gate, not exit-blocking.
- **Stage 2** — out of scope. Document ingestion plumbing for arbitrary file types is not part of this seed and not part of the loop. If significant time is left after Stage 1 ships, it gets handled in a follow-on seed, not by widening this one mid-loop.

### Holdout Scenarios (loop runs until these pass and stay passing)

| # | Scenario | Platform |
|---|----------|----------|
| 1 | "Airplane-mode moment of magic": phone A queries its local corpus and returns answer X (visibly citing its retrieved note IDs). Demonstrator toggles airplane mode ON, then re-enables Bluetooth from Control Center (iOS disables BT when entering airplane mode). Phone B comes into BLE range. Phone A re-queries and returns answer X + Y, with Y citing a retrieved note that lives on phone B. Corpora are authored disjoint-by-design so at least one rehearsed query has zero hits in A's corpus and ≥1 hit in B's. | 2 phones (iOS+Android required) |
| 2 | Embedding determinism (mandatory on the chosen two-device pair): the same query against the same combined corpus on A and B returns the same top-k ordering for ≥95% of N rehearsed queries. Cosine similarity is reported as a diagnostic but is not the gate. | iOS + Android |
| 3 | Sync idempotence: re-meeting after no changes produces no duplicate tuples and no change to top-k results for any query. | Two devices, repeated BLE meet |
| 4 | Bidirectional merge: notes pushed from A appear in B's index and vice versa, observable through queries whose nearest neighbors live on the other device. | Two devices |
| 5 | Cold-load latency: on the slowest target device, the embedding + LLM models load from disk and the system produces a first answer (embedding + top-k retrieval + generation) in under ~10s, measured end-to-end from app launch to answer display. | Slowest target device (mid-range Android) |
| 6a | Rehearsed coherence (recorded artifact): for 5 of 5 rehearsed queries against the combined corpus, the small LLM generates a coherent buffered answer that visibly references the retrieved notes (note IDs/titles shown next to the answer; tokens are buffered then displayed, streaming is out of scope). | Two devices, ~50 notes/device |
| 6b | Free-text audience survival (stretch, not exit-blocking): the audience picks 5 free-text queries; ≥3 produce coherent answers. Only included in the recorded artifact if it clears. | Two devices, ~50 notes/device |
| 7 | End-to-end offline: the full demo runs with no internet connectivity to either device (Wi-Fi off, cellular off; BLE remains on after the airplane-mode toggle described in Holdout 1). | Two devices |

### What "Real Environment" Means Here

- Real Cactus runtime loading a real model on each device (not a stub or a server proxy).
- Real Ditto SDK with real mesh sync over BLE and/or LAN (not a mocked sync layer).
- Heterogeneous mobile hardware required (iOS + Android — iOS+macOS does not satisfy the mobile-edge claim).
- Demo conditions: live airplane-mode toggle on camera. The single recorded take is preferred; pre-recorded B-roll for the BLE-pairing moment is permitted as a fallback if disclosed on camera ("this clip is from rehearsal").
- A small but real corpus per device (target ~50 notes/device, sized to satisfy Holdout 6a's cold-start constraints) — text the audience can read on screen and follow along with. Corpora are jointly reviewed before demo day: any plausible audience query is pre-run and the combined top-k inspected to ensure no unintended content lands on the big screen.

### What Is NOT "Real" (explicitly out of scope)

- Cloud fallback / Cactus hybrid mode. The thesis breaks if we cheat with cloud.
- Document ingestion plumbing for arbitrary file types (PDFs, EPUBs, archives) — Stage 2, handled in a follow-on seed.
- Multi-user identity, authentication, or access control on the synced corpus (see Threat model bound).
- Persistent chat history.
- Streaming token output (Holdout 6a generates and buffers a complete answer before display).
- Production-grade UI polish, settings panels, error toasts.
- Web/desktop clients beyond the demo machine (one optional macOS via Flutter; no browser client).

### Cut order under time pressure

If a forcing function arrives mid-loop, drop in this order (first to last). Each cut names which goal it compromises.

1. Optional macOS third device — compromises neither goal.
2. UI polish beyond what makes the moment of magic legible — compromises neither goal.
3. Corpus pre-review on every query the audience *might* ask (instead, pre-screen a smaller set) — compromises Holdout 6b only.
4. Holdout 6b (free-text audience survival) — already a stretch; compromises neither goal.
5. Holdout 6a (rehearsed coherent LLM generation) → ship as Stage-0-only, demo becomes "mesh vector sync" — compromises Stage 1; the demo loses the RAG-in-mesh-RAG story but Stage 0 still demonstrates the CRDT thesis.
6. Holdout 7 (end-to-end offline) — compromises both goals; do not drop unless every option above has been taken.

---

## Feedback Loop

Each run of the validation harness produces a feedback signal fed back into the inputs:

| Output | Fed Back As |
|--------|-------------|
| Live demo dry-run video (Holdout 1) | Direct visual evidence of which step looks unconvincing — feeds corpus selection, UI affordances, query phrasing. |
| Cross-device top-k stability trace (Holdout 2) | If top-k agreement drops below 95% on the rehearsed query set, forces model swap, version-pinning, or pivoting to brainstorm option C. Cosine drift is logged as a diagnostic alongside. |
| BLE peer-discovery + sync timing trace | Tunes Ditto small-peer config; may force LAN-first demo if BLE pairing is flaky on the chosen hardware. |
| Cold-load latency profile on slowest device (Holdout 5) | Forces model-size downgrade, zero-copy mmap verification, or eager-load on app start. |
| Top-k retrieval miss on a known-good query | Triggers corpus pruning, re-embedding, or model-eval comparison. |
| Holdout 6a coherence miss | Re-curates rehearsed query set, broadens or re-themes corpus, or escalates LLM choice. |
| Holdout 6b audience-query miss | Logged for analysis; does not block ship. If 6b consistently fails, the recorded artifact omits the free-text section. |
| Writeup reviewer reactions | Sharpens the "why mesh RAG matters in a year" framing; may force restructuring around a non-obvious thesis. |

**Loop exit condition:** Holdouts 1, 2, 3, 4, 5, 6a, and 7 pass on the chosen hardware in the recorded artifact (single take preferred; B-roll for the BLE-pairing moment permitted with on-camera disclosure). Holdout 6b is non-blocking and is included only if it clears. The writeup draft has a named primary audience ("devs evaluating local-first AI infrastructure") and a 2–3 person review pass against three pre-publish comprehension questions: (i) what does Ditto do here, (ii) what does Cactus do here, (iii) why does mesh change the RAG story. A Stage-0-only ship is permitted with explicit logging — the published artifact still satisfies the exit condition, but the writeup names the omission of Stage 1.

---

## Goal-to-holdout alignment

The seed pursues two goals; each holdout primarily serves one or both. If a holdout fails and a fallback is forced, the table makes the goal cost visible.

| Holdout | Existence proof (CRDT thesis) | Co-marketing (Ditto + Cactus joint story) |
|---------|-------------------------------|--------------------------------------------|
| 1 | Primary | Secondary (the BLE-meet moment is what readers screenshot) |
| 2 | Secondary | Primary (validates Cactus's cross-platform claim) |
| 3 | Primary | — |
| 4 | Primary | — |
| 5 | — | Primary (on-device speed is the Cactus story) |
| 6a | Secondary | Primary (RAG is what makes the joint story coherent) |
| 6b | — | Secondary |
| 7 | Primary | Primary |
| 8 — Narrative pickup | — | Primary |

### Holdout 8 — Narrative pickup

Three independent readers of the writeup draft can, unprompted, articulate (i) what role Ditto plays in this architecture, (ii) what role Cactus plays, and (iii) why mesh changes the RAG story. Not exit-blocking on its own, but a failure here means the co-marketing goal hasn't been met even if every technical holdout passes.

---

## Apply More Tokens

> For every obstacle, ask: how can we convert this problem into a representation the model can understand?

| Obstacle | Token Form |
|----------|------------|
| Cactus determinism prerequisite — before loop start, verify that the chosen Cactus embedding model produces top-k-stable embeddings across iOS + Android on a small fixed query set | Cactus official docs, GitHub repo + example projects, model card / weights manifest, any release-notes mention of determinism guarantees, community issues/discussions about cross-platform parity. If unverified, soften the secondary-use-case sentence accordingly. |
| Ditto mesh sync over BLE on mixed iOS/Android pairs has known quirks | Ditto SDK docs (especially small-peer + BLE transport guides), example apps, blog posts from prior Ditto demos, public CI traces / issue threads. |
| Choosing a small LLM that runs at acceptable latency on a mid-range Android and is shipped by Cactus | Cactus model catalog, on-device LLM benchmarks (mobile inference latency tables), HF model cards for candidate small models. |
| Top-k stability verification across platforms is hard to debug visually | A small CLI harness that runs a fixed query set against identical corpora on each device, prints top-k ID lists side-by-side, and computes the agreement rate. Cosine first-N components surface as diagnostic. |
| Selecting an audience-survivable corpus theme | Past hackathon demo videos / writeups; common RAG-demo failure modes documented in blog posts; Ditto's canonical `cars` collection as a baseline anchor. Theme must support disjoint-by-design pairs (see Open Q1). |
| Writeup framing — pre-loop, write the 250-word version of each Q4 candidate framing and stress-test each against the strongest skeptic. If none survives, expand the candidate set (e.g., "opportunistic knowledge composition in bandwidth-denied environments — disaster zones, ships, transit") before committing the demo to a writeup it can't carry. | Local-first software essays (Kleppmann et al.), CRDT survey papers, edge-AI manifestos, prior writeups on offline-first AI, the parent brainstorm at [README](../README.md). |
| BLE pairing flakiness on demo day | Pre-recorded "airplane mode + meet" capture as fallback B-roll (used with on-camera disclosure per the exit condition); rehearsed LAN-only fallback path; second hardware pair on standby. |

---

## Related Tickets

- Parent brainstorm: [README](../README.md)
- Source idea doc: [IDEA-A.md](IDEA-A.md)
- Fallback option (if Cactus determinism prerequisite fails): brainstorm option C, "Narrate the mesh"

---

## Open Questions

The following items are unresolved as of seed authoring. Resolutions should be folded back in-line and the section retitled "Open Questions (Resolved)".

1. **Corpus theme for Stage 0 — RESOLVED 2026-05-23 (U3).** Theme is audience-submitted study notes on **the solar system**. 5 notes per device, 10 post-sync. The split is **contrived for legibility**: phone-a holds the inner solar system (Sun, Mercury, Venus, Earth's Moon, Mars); phone-b holds the outer (Jupiter, Saturn, Uranus, Neptune, Pluto). Real audience-submitted notes would overlap heavily — a clean inner/outer partition is staged so R1's "moment of magic" (ask before BLE-meet → no hit; ask after → hit citing the other phone) is visually obvious. The writeup must call this out so the demo's clean separation doesn't read as a load-bearing claim. Files: `assets/seed_notes_a.json`, `assets/seed_notes_b.json`, with `assets/README.md` carrying the design rationale. UUIDv5 IDs are mechanically disjoint across files (verified). At least 10 R1-style queries land on exactly one device (5 A-only, 5 B-only); formal capture of the query → expected-source map is U16's job. Bound to U2 framing (iii) — the disjoint solar-system split embodies the "Bluetooth pairing for ideas" metaphor at demo time.

2. **Hardware mix.** iOS + Android is required by Holdout 2 (see Real Environment). Open question: which specific devices? Optional macOS as a third surface for the writeup screenshots is at the demonstrator's discretion.

3. **Connectivity reveal mechanism.** Airplane-mode toggle on camera is the default (with manual BT re-enable per Holdout 1); the verbal-claim fallback is a last resort only.

4. **Durability of the thesis — RESOLVED 2026-05-23 (U2).** The writeup needs a non-rising-tide answer to "why does this still matter when cloud RAG is cheaper and faster in a year?" Candidate framings stress-tested: (i) data sovereignty / consent-scoped sharing; (ii) offline-by-default; (iii) "knowledge composes when devices meet, like Bluetooth pairing for ideas"; (iv) opportunistic composition in bandwidth-denied environments. **Pick: framing (iii).** Composition between proximate devices is a topological pattern that cloud RAG cannot copy — the dissolution when devices leave range is the point, not a feature gap a vendor might close. The demo's "moment of magic" choreography (R1, R6a) literally enacts the metaphor, so R8 narrative-pickup is winnable on a one-line ("two phones meet, their corpora compose") that non-engineers retell unprompted. The audience-submitted study-notes corpus from Q1's resolution embodies the metaphor — classmates whose phones briefly meet leave with combined understanding none of them had alone. Each thread of the four-thread future-work arc (specialists, preference-aware merge, adversarial filtering, generational evolution) extends the metaphor naturally as "*who* you pair with and on what terms." Framings (i), (ii), and (iv) survive their skeptic tests but appear as supporting structure in the writeup, not as the headline. Full stress-test and rationale: [`_docs/thesis-framings.md`](thesis-framings.md).

5. **Cactus small-LLM choice.** Which model under Cactus runs at acceptable latency on the slowest target device AND produces coherent answers given the small corpus + retrieved context? Open dependency on the Cactus model catalog at research time.

6. **Demo artifact form — RESOLVE BEFORE LOOP STARTS.** Recorded demo video, working repo, or both? The exit-condition wording "writeup draft has a named primary audience and 2–3 reviewer comprehension pass" works for any form, but the answer to this question changes whether code polish is in scope during the loop.

7. **Embedding model selection criteria.** Small enough to load fast, large enough to give meaningful top-k separation on a hand-picked ~50-note corpus, and shipped by Cactus with top-k-stable cross-platform output (verified per the Cactus determinism prerequisite in Apply More Tokens). Which model in the Cactus catalog clears that bar?

---

*Seed authored: 2026-05-21. Updated 2026-05-23 with ce-doc-review auto-resolved fixes. Loop not yet started. Holdout scenarios: not yet green.*
