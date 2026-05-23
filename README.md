# Ditto × Cactus — hackathon brainstorm

**Status:** pursuing A — see [docs/SEED.md](docs/SEED.md)
**Frame:** personal weekend build, deliverable is a blog-post-shaped artifact (working demo + writeup that teaches something)
**Date:** 2026-05-21

## Why this pair is interesting at all

- **Ditto** — peer-to-peer offline-first CRDT sync over BLE / LAN / mesh. Flutter SDK.
- **Cactus** — on-device AI runtime (LLM, speech, vision) with hybrid cloud fallback. Flutter SDK, plus Swift/Kotlin/RN/C++/Python.
- Both are edge-native, both are privacy-forward, both have Flutter SDKs. The composition isn't just stacking — they share a worldview (local-first, no cloud required) and each completes the other (Cactus produces AI outputs that need to travel; Ditto syncs content that benefits from intelligence).
- The interesting question isn't *whether* they compose. It's **which compound claim the writeup argues.**

## Candidate framings

### A. "Mesh RAG" — corpora that compound additively

Each device indexes some local material (notes, PDFs, photos with captions) into a vector store kept inside Ditto. Cactus does embedding and inference locally. When two devices meet over BLE/LAN, their indexes merge — no central store, no upload. The query you ask on phone A draws on phone B's material if B is nearby.

- **Thesis:** vector indexes want to be CRDTs (embeddings are additive; relevance is a local function over a set).
- **Demo:** two phones, no wifi. Each preloaded with different docs. Ask a question on one; the answer gets better the moment the second comes into range.
- **Hard part:** keeping the embedding model identical and stable across devices so vectors are comparable. Mechanically modest at weekend scale; conceptually rich.
- **Blog-post shape:** "Your knowledge base wants to be a CRDT."
- **→ Pursuing this one** — see [docs/SEED.md](docs/SEED.md).

### B. "LLM-mediated merge" — AI repairs what CRDTs can't reach

Ditto's CRDTs already merge structured fields correctly. The places they can't help are the unstructured ones — free-text descriptions, lists of ideas, plans. Cactus runs an on-device LLM that proposes a semantic merge when two human edits collide on those fields, and explains the merge in plain language.

- **Thesis:** AI is good at intent; CRDTs are good at structure. The fusion is bigger than either alone.
- **Demo:** two phones, both offline, both editing shared study notes (or an itinerary, or a grocery list). Reconnect. The LLM proposes the merged version with a one-line "I combined your additions" footer.
- **Hard part:** you have to construct a believable conflict. With a good demo script this is one of the most memorable framings — it inverts the usual AI-generates-new-content story.
- **Blog-post shape:** "What AI is actually good for in collaborative editing."
- **→ Not pursued** — kept for the brainstorm record.

### C. "Narrate the mesh" — smallest, sharpest post

Don't use AI for the user feature. Use it to make the *sync itself* legible. A local LLM watches the Ditto change stream and produces a human-readable activity feed: "Maya marked the route as cleared," "two devices in Block 3 went offline," instead of raw document diffs. Retrofittable to any Ditto app in an afternoon.

- **Thesis:** the most undersold use of on-device LLMs is interpreting structured local state for humans — and it has to be local because the state is local.
- **Demo:** a tiny shared planner or `cars`-collection scene. Same data on both screens. One narrates itself.
- **Hard part:** there isn't one. That's the point — and the blog post argues that's a category of usage the industry keeps skipping past.
- **Blog-post shape:** "On-device LLMs are interfaces, not products."
- **→ Not pursued** — kept as the fallback if A's determinism prerequisite fails (see [docs/SEED.md](docs/SEED.md) Related Tickets).

### D. *Challenger:* "Model weights gossip" — federated learning over mesh

Riskier, higher upside. Each device collects examples (custom labels, wake words, sample images). Cactus does on-device LoRA fine-tuning. The LoRA deltas are tiny enough to gossip over BLE via Ditto. Phone A trains, phone B inherits, the model improves additively as the mesh grows.

- **Thesis:** model deltas are mesh-friendly payloads. If embeddings are CRDTs (A), so are LoRA tensors.
- **Demo:** train a custom classifier on phone A by tapping examples; phone B inherits the model and classifies the same things without ever having been trained.
- **Hard part:** real risk this overflows the weekend. Quantized LoRA + Cactus + delta-sync is a multi-day commit, not a Saturday.
- **Blog-post shape:** "Federated learning, without the federation."
- **→ Not pursued** — kept for the brainstorm record.

## Comparison

| | A. Mesh RAG | B. LLM-mediated merge | C. Narrate the mesh | D. Weight gossip |
|---|---|---|---|---|
| Claim strength | High | High (contrarian) | Medium | Highest |
| Weekend feasibility | Medium | Medium | High | Low |
| Demo legibility | High | High (if scripted) | Very high | Medium |
| Novelty for a writeup | High | High | Medium | Very high |
| Risk of partial ship | Low | Medium | Very low | High |

## Why A

**A** carries the strongest, most quotable thesis ("Your knowledge base wants to be a CRDT") and the cleanest demo construction — two phones, no wifi, the answer gets better when B comes into range. It's a bigger swing than C with a tractable hard part (cross-platform embedding stability) that the seed's validation loop verifies before commit.

### Considered alternatives

- **B (LLM-mediated merge)** — most contrarian and probably the most *fun*; the demo construction is the whole game. Lost out to A on quotable-thesis strength.
- **C (Narrate the mesh)** — sharpest claim, ships Saturday, leaves Sunday for the writeup. Kept warm as the fallback if A's Cactus determinism prerequisite fails.
- **D (Model weights gossip)** — highest upside but high risk of weekend overflow. Not pursued.

## Open decisions

- Hardware target — phones only, or include a laptop/wearable to make the heterogeneity visible? (Open Q2 in [docs/SEED.md](docs/SEED.md).)
- Demo scenario — abstract (`cars` collection) or applied (field-ops, study notes, planner)? (Open Q1 in [docs/SEED.md](docs/SEED.md).)
- Does the demo need to *visibly run without internet* on camera, or is that taken on faith? (Open Q3 in [docs/SEED.md](docs/SEED.md).)

## Notes / scratch

- Cactus claims 120ms on-device latency, hybrid cloud fallback, supports Flutter + Swift + Kotlin + RN + C++ + Python.
- The Flutter overlap is the cheapest entry point — both SDKs are already known territory.
- The `cars` collection is Ditto's canonical demo data; default to `car1, car2, ...` over `dogs` if scenario is abstract.
