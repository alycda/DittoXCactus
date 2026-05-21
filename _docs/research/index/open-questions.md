# Open Questions & Future Work

> Gaps the prior art doesn't answer. Read before designing anything new — these are the places Mesh RAG will have to invent rather than borrow.

The file has two sections:
1. **Empirical open questions** — load-bearing for Stage 0 holdouts; need experiments to resolve.
2. **Future-work arc** — what the writeup should leave the reader with, organized as a four-thread story.

These are *real* gaps — places where the 281-source corpus indexed at [`./`](./) is genuinely silent or contradictory. For sources mentioned by ID below (e.g. `paper-2402.00841`), look in `_per_source/<id>.md` for the per-source summary; [`top-N.md`](top-N.md), [`clusters.md`](clusters.md), and [`by-topic.md`](by-topic.md) provide topical paths in.

---

## 1. Empirical open questions (Stage 0)

These are the gaps where prior art is silent or contradictory, and where the holdouts can only be passed by running our own experiments.

### 1.1. Cactus iOS↔Android embedding parity

**Question:** Does `cactus_embed("chicken tortilla soup")` produce cosine ≥ 0.999 (ideally bit-identical) across Swift-on-iOS and Kotlin-on-Android using the same GGUF/Q4 weights?

**What prior art says:**
- The Thinking Machines work + Karnam's MLX investigation + arXiv 2602.17099 converge on: INT4/INT8 paths are dramatically more stable than FP16/BF16 across hardware, and batch=1 single-sample inference sidesteps batch-invariance bugs.
- Cactus's own engine docs explicitly do **not** promise determinism.

**Gap:** Nobody has measured Cactus' cross-platform embedding parity head-to-head on real iPhone vs real Android.

**How we close it:** Stage 0 holdout #2. Pin both phones to the same GGUF model + Q4 quantization + CPU backend, embed an identical fixture string, dump first 16 components of each vector, compute cosine. If < 0.999, pivot to brainstorm option C (Narrate the mesh).

### 1.2. Specialist parameter floor for ingredient-list merging

**Question:** At what model size does an off-the-shelf small LLM (Qwen 2.5 1.5B / SmolLM2 1.7B / Phi-3 Mini / Gemma 3 1B / Llama 3.2 1B / 3B) stop producing incoherent merged recipes from heterogeneous variants?

**What prior art says:**
- "Tiny Titans" (paper-2402.00841) shows fine-tuned FLAN-T5-Large rivals zero-shot 7B–70B on summarization — strong evidence for specialists, weaker evidence for generalists at small parameter counts.
- LoRA Land (paper-2405.00732) shows 310 specialized 7B-scale LoRAs rival GPT-4 on narrow tasks — but at 7B, not 1–3B.
- Schema-aware Extraction (paper-2505.14992) shows on-device structured extraction is feasible with constrained generation, but doesn't benchmark recipe-merge specifically.

**Gap:** No published benchmark answers the actual question. The recipe-merge eval is novel.

**How we close it:** A 30-minute internal eval. Take 5 multi-source chicken-tortilla-soup variants; run 3 candidate models on each; rank merged outputs by a coherence rubric. If the answer is "≥ 7B," fall back to **cars** as the demo corpus per SEED.md's gating clause.

### 1.3. End-to-end on-device RAG latency on demo hardware

**Question:** What's the realistic TTFT (time to first token) for `embed → cosine top-k → LLM` on the slowest demo phone, given our model choices?

**What prior art says:**
- MELT (paper-2403.12844) and MobileAIBench (paper-2406.10290) give 1B–3B mobile-LLM latency baselines.
- MobileRAG (paper-2507.01079) measures full pipeline; 1.72–8.89× retrieval speedup over baselines.
- EmbeddingGemma quotes sub-22ms on EdgeTPU.

**Gap:** Specific Cactus + chosen-model + chosen-phone numbers are not in any published source. Has to be measured.

**How we close it:** Stage 0 holdout #5 (cold-load latency < ~10s; first-answer latency we'll measure as a side effect).

### 1.4. Cactus + Ditto integration shape

**Question:** Do we use Cactus's `cactus_index_t` and `cactus_rag_query` directly, or do we keep Cactus's role narrow (embedding generation + LLM inference) and run our own cosine top-k from a Ditto-materialized result set?

**What prior art says:**
- Cactus docs confirm both APIs exist. Cactus's vector index handles add/query/compact/delete; `cactus_rag_query` provides top-k + score-threshold.
- Ditto docs confirm DQL can return arbitrary materialized result sets.
- **No published example combines the two.** We are the first integration point.

**Gap:** Whether Cactus's vector index can be backed by a Ditto-managed tuple set, or whether it wants to own persistence in a way that fights Ditto's CRDT store.

**How we close it:** Spike during Stage 0. Default plan: keep Cactus narrow (embed + LLM), use a flat-array cosine top-k over the Ditto query result. Revisit `cactus_rag_query` only if Cactus' implementation provides batched embedding compactly enough to be worth integrating.

### 1.5. iOS background-BLE for "always-on" mesh

**Question:** Can the Mesh RAG app stay in mesh while backgrounded on iOS?

**What prior art says:** Briar has no iOS app because of this. Bitchat works only foregrounded. The Ditto BLE transport docs note "a few concurrent connections, each initiation taking several seconds." Apple does not provide a path to arbitrary background BLE scanning for non-paired peripherals.

**Gap:** Solving this is an OS-level problem nobody has solved at user-app scope.

**How we close it:** **We don't.** The hackathon demo runs foregrounded; the writeup acknowledges this as an environmental constraint on the current shape rather than a project failure.

---

## 2. The four-thread future-work arc (writeup framing)

This is the arc the writeup should leave the reader with. **Stage 0 ships the simplest possible version of Mesh RAG — a generalist small LLM, a flat grow-only CRDT union, and recipes as a corpus.** The thesis the writeup lands on is that the simplest version is *only* the beginning, and that the deeper claim — *the mesh's natural unit is specialists, and the merge's natural shape is preference-aware* — sketches a much more interesting destination.

### Thread 1: Specialists, not generalists

**Stage 0 today:** one generalist small LLM (~1.5B–3B) does everything — embed query, retrieve, synthesize answer.

**The future move:** the mesh's right granularity is a *bag of small specialists*, one per domain. A sous-chef LLM for recipes. A maintenance-manual expert for cars. A first-aid triage model for symptoms. Each device carries the specialists relevant to its owner; when devices meet, *expertise composes* as freely as data composes.

**What the prior art says:** LoRA Land (paper-2405.00732) shows 310 specialized 7B-scale LoRAs rivaling GPT-4 across narrow tasks; DistilBERT (paper-1910.01108) is the canonical compression reference; Tiny Titans (paper-2402.00841) shows fine-tuned small beats zero-shot huge on narrow tasks. The infrastructure for "ship a tiny domain expert" already exists.

**The gap:** Nobody has built a mesh-aware specialist-bag where models compose across devices. The writeup can claim this slot.

### Thread 2: Preference-aware merge

**Stage 0 today:** the CRDT is a flat grow-only union. Every contribution wins. If someone adds avocado to chicken tortilla soup, the merged recipe has avocado.

**The future move:** the *set* stays grow-only — every contribution is preserved as a tuple in the CRDT — but the *retrieval/synthesis* at query time is preference-weighted by who's asking. If I hate avocados, my phone's synthesized recipe quietly omits them. Unless the small LLM judges I wouldn't notice in this dish, in which case it leaves them in.

**What the prior art says:** Recommender systems and federated learning have decades of work on preference-weighted aggregation, but it's not been applied to CRDT-merged knowledge stores. None of the CRDT theory papers (paper-1106.4374, SHIMI paper-2504.06135, etc.) treat preferences as a first-class dimension of merge.

**The gap:** What does "preference-aware retrieval over a grow-only CRDT" look like, formally? Per-user query-time reranking is the easiest shape; per-user-pair embedding bias is more interesting; explicit preference vectors broadcast in the mesh is most interesting.

### Thread 3: Adversarial / mistake filtering

**Stage 0 today:** every suggestion wins. Someone who adds "1 cup of bleach" to the chicken tortilla soup permanently corrupts the corpus.

**The future move:** the CRDT *keeps* everything — that's the merge semantic and we don't want to lose history — but *promotion into the canonical recipe* needs a gate. Reputation of the contributor; consensus from other diners; provenance of the source; cooking-grammar plausibility check by the small LLM. The mesh becomes a multi-write log, with curation as a separate layer.

**What the prior art says:** Distributed systems have plenty of voting/reputation/consensus literature, but mostly for byzantine fault tolerance, not collaborative knowledge curation. CRDT theory deliberately avoids this question (the whole point of conflict-free is "you don't need consensus"). So this is a real CRDT-extension problem.

**The gap:** A *curation layer* over a grow-only CRDT is its own design space. Multi-vote promotion? LLM-graded promotion? Trust-weighted promotion? Promotion that branches when tastes diverge? Open.

### Thread 4: Generational evolution

**Stage 0 today:** the corpus is a snapshot. If the same group of people uses Mesh RAG for a year, nothing in the system encodes "the recipe got better over time."

**The future move:** family recipes drift over time even with the same people involved — taste shifts, ingredients become available, old steps get pruned, kids stop liking what their parents make for them. A temporal weighting layer on retrieval ("recent contributions weigh more") or an explicit "branch when tastes diverge" semantic would model this. **Family recipes through generations is the load-bearing analogy** — written down, passed through generations, quietly mutating along the way, and recognizably "ours" even though almost nothing is exactly what grandma wrote.

**What the prior art says:** Operational transformation literature handles temporal sequences for collaborative text. Yjs and Loro support history/time-travel as first-class operations. Nothing — nothing — applies this lens to AI-mediated knowledge stores.

**The gap:** Designing the *temporal* dimension of a preference-aware mesh CRDT. This is where the writeup's most interesting unsolved problem lives.

### The thesis the writeup lands on

> Today's Mesh RAG ships a generalist LLM and a flat union. The mesh's natural unit is *small specialists*; the merge's natural shape is *preference-aware*; the curation layer's natural mechanism is *adversarial filtering*; the corpus's natural form is *generational drift*. Family recipes — written down, passed through generations, quietly mutating along the way — are what this looks like when it works for humans. The vector index isn't just a CRDT. It's a culture.

---

## 3. Smaller open questions surfaced by individual sources

These came out of the per-source summaries' "what we'd take from this" + "gap" sections, plus the worker outputs' open-questions sections.

- **HNSW + CRDT correctness:** paper-2407.07871 documents HNSW's "unreachable points phenomenon" under concurrent updates on a *single* replica. Nobody has analyzed correctness when each replica builds an HNSW independently over a different arrival order of the same eventually-converging CRDT set. We sidestep this with flat-array brute force; an actual paper here would be publishable.
- **End-to-end cloud vs on-device RAG benchmark:** MobileRAG measures only on-device; cloud-RAG benchmarks are server-side only. The "phone-to-cloud-and-back vs phone-only" composite measurement appears not to exist in publishable form. We can assemble it from existing sources but it'll be our own composite.
- **Audience-participation timing:** No published writeup nails the "two devices, airplane mode, BLE handshake, observable state change" demo pattern at hackathon length. AirDrop in Apple keynotes is the closest analog and isn't filmed in implementation detail. We're inventing the presentation shape.
- **License footprint of redistributing models in a public hackathon repo:** Llama Community License requires "Built with Llama" attribution and the "Llama" prefix on model names if redistributing weights. Gemma terms (pre-4) include a redistribution-notice clause. Apache-2.0 candidates (Qwen 2.5 1.5B, SmolLM2 1.7B, Phi-3) are the cleanest license stories. Decide before publishing.
- **Recipe corpus theme robustness:** the demo's "moment of magic" depends on the small LLM producing visibly composed-from-both-devices output. Cars (per SEED.md) is the fallback; recipes is the user-preferred primary; the gating eval (open question 1.2 above) decides which we ship.
