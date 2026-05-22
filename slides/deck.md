---
title: "Mesh RAG — your knowledge base wants to be a CRDT"
sub_title: "A Ditto × Cactus existence proof"
author: "Alyssa Evans"
---

Your knowledge base wants to be a CRDT
---

> Two phones. Airplane mode. They meet over Bluetooth. The vector index merges.
> The answer changes on camera.

<!-- pause -->

Stage 0 thesis: **retrieval is the AI primitive that aligns with local-first.**
Not chat history. Not weights. Not KV cache. The grow-only set of tuples.

<!-- end_slide -->

The problem with cloud RAG
---

Every retrieval round-trip is bounded by physics.

```
Phone → BTS    ≈ 30–50 ms        (LTE median RTT)
BTS  → DC     ≈ 10 ms / 1000 km  (fiber, one way)
DC   → ANN    ≈  5–50 ms         (Qdrant / Pinecone best case)
DC   → LLM    ≈ 50–200 ms        (prefill RTT)
```

**Floor: 200–500 ms before the first token decodes.** And ~always-on connectivity
is assumed.

<!-- pause -->

A phone-only pipeline:

```
embed query    ≈  20 ms          (EmbeddingGemma on CPU)
cosine top-k   ≈ <1 ms           (5k tuples × 384 dims = 7.7 MB)
LLM TTFT       ≈ 50–500 ms       (Qwen 2.5 1.5B Q4 on phone)
```

Cloud cannot get faster than light. On-device can.

<!-- end_slide -->

The CRDT insight
---

Treat the **vector index itself** as a grow-only set CRDT.

```
RecipeTuple {
  _id:         uuid,        // deterministic across re-runs
  dish:        string,
  contributor: string,
  ingredients: [string],
  steps:       [string],
  embedding:   [float],     // 384 dims
  createdAt:   timestamp,
}
```

- Each phone holds a partial corpus.
- Ditto delta-state CRDT syncs tuples over BLE/LAN. No central index.
- Retrieval is cosine top-k over the **locally materialized union**.

**No HNSW under concurrent inserts. No coordinator. No cloud.**

<!-- end_slide -->

Architecture
---

```mermaid +render
sequenceDiagram
    participant A as Phone A (iOS)
    participant B as Phone B (Android)
    Note over A,B: Airplane mode — BLE only
    Note over A: corpus = {α₁..α₅}
    Note over B: corpus = {β₁..β₅}
    A->>A: cactus_embed(q)
    A->>A: cosine top-3 over α
    A->>A: cactus_complete(prompt + α)
    Note over A,B: Phone B enters BLE range
    A->>B: Ditto handshake
    B-->>A: sync(β); A: corpus = {α ∪ β}
    A->>A: cactus_embed(q)
    A->>A: cosine top-3 over α∪β
    A->>A: cactus_complete(prompt + α∪β)
    Note over A: Answer visibly drew on Phone B's tuples
```

- **Cactus** stays narrow: `embed()` + `complete()`. No `cactus_rag_query`.
- **Ditto** owns persistence + sync.
- **We** own the cosine loop. ≤5k tuples → flat float32 array.

<!-- end_slide -->

Live demo
---

Phone A (left). Phone B (right). Both in airplane mode.

1. Ask "what's in chicken tortilla soup?" on phone A → answer X.
2. Bring phone B into BLE range. Watch the mesh pill turn green.
3. Ask the same question. Answer X + Y. Attribution shows tuples from `phone-b`.

> If BLE handshakes slowly on demo hardware, we cut to the B-roll take.

<!-- end_slide -->

What this is — and isn't
---

**Is:**

- Two-device existence proof. iOS + Android, single Flutter codebase.
- ~10 tuples after sync. ~5 per device. Cosine top-3.
- Airplane mode. No cloud. No big peer.
- Off-the-shelf small generalist (Qwen 2.5 1.5B Q4).

**Isn't:**

- Production. Stage 0 is a hackathon existence proof.
- Audience-participation submission (Stage 1).
- Real-corpus integration (Stage 2: notes app, PDF library).
- A specialist model. Yet.

<!-- end_slide -->

Where this goes — the four-thread arc
---

Stage 0 ships **generalist on-device + flat union**.
The interesting future is **specialist small models**, four threads:

1. **Specialists.** A 360M model fine-tuned on recipe-merge will beat a 1.5B
   generalist on the demo task. Tiny Titans, LoRA Land already showed this on
   adjacent tasks.
2. **Preference-aware merge.** "Combine, preferring *my* variants" — the
   index is per-peer ground truth, not a shared truth-claim.
3. **Adversarial filtering.** When the mesh is open, anyone can insert.
   Adversarial filtering is a CRDT-shaped problem (signed witnesses, reputation
   in the document).
4. **Generational evolution.** Each peer keeps a different sub-model. New
   variants train against the corpus. The mesh becomes an evolutionary substrate.

<!-- end_slide -->

Q & A — and the build
---

- **Plan:** `docs/plans/2026-05-21-001-feat-mesh-rag-stage-0-implementation-plan.md`
- **SEED:** `SEED.md` (holdouts, decisions, scope)
- **Stack:** Flutter · Ditto `5.0.0` · Cactus `1.3.0` · Qwen 2.5 1.5B Q4 · 384-dim embeddings · flat float32 cosine
- **License:** Apache-2.0 throughout

```
flutter run \
  --dart-define=DITTO_APP_ID=<uuid> \
  --dart-define=DITTO_LICENSE=<offline-token> \
  --dart-define=PHONE_ROLE=a   # or b on the second phone
```

Thank you. Questions welcome.
