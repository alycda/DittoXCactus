# Top sources — must-read by density

> Ranked by density (5 = must-read, 1 = barely relevant), with ties broken by direct relevance to *Mesh RAG: peer-to-peer RAG via Ditto + Cactus on iOS/Android with a CRDT-merged vector index*.

Read these before designing anything. For everything else, `by-topic.md` and `clusters.md` give topical paths in.

### 1. Defeating Nondeterminism in LLM Inference

- [article-thinkingmachines-blog-defeating-nondeterminism-in-llm-inference](_per_source/article-thinkingmachines-blog-defeating-nondeterminism-in-llm-inference.md) — kind: article — density: 5
- *Why:* Reframes LLM non-determinism as a batch-invariance problem solvable via three kernel rewrites — the single most load-bearing source for the iOS-vs-Android embedding-cosine-parity holdout.

### 2. Cactus Engine FFI Documentation

- [other-raw-githubusercontent-cactus-compute-cactus-main-docs-cactus-engine-md](_per_source/other-raw-githubusercontent-cactus-compute-cactus-main-docs-cactus-engine-md.md) — kind: other — density: 5
- *Why:* Primary spec for the `cactus_embed`, `cactus_index_t`, and `cactus_rag_query` C-FFI surface — confirms Cactus ships a vector-index abstraction with top_k + score_threshold and explicitly does NOT promise determinism.

### 3. An Inside Look at Ditto's Delta State CRDTs

- [article-ditto-blog-dittos-delta-state-crdts](_per_source/article-ditto-blog-dittos-delta-state-crdts.md) — kind: article — density: 5
- *Why:* Authoritative description of Ditto's state-based CRDT model, HLC version vectors, and dot-tagged trees — read before designing the RecipeTuple document.

### 4. Local-First Software: You Own Your Data, In Spite of the Cloud

- [other-inkandswitch-essay-local-first](_per_source/other-inkandswitch-essay-local-first.md) — kind: other — density: 5
- *Why:* Foundational manifesto with the seven local-first ideals — frame the writeup against "you own your data, no spinners, work offline" and cite directly when arguing retrieval is the AI primitive aligned with these.

### 5. Local-First Software: You Own Your Data, In Spite of the Cloud (Onward! 2019)

- [other-martin-kleppmann-papers-local-first-pdf](_per_source/other-martin-kleppmann-papers-local-first-pdf.md) — kind: other — density: 5
- *Why:* The Onward! 2019 academic version of the local-first manifesto — same ideals, citable in scholarly form.

### 6. MobileRAG: A Fast, Memory-Efficient, and Energy-Efficient Method for On-Device RAG

- [paper-2507.01079](_per_source/paper-2507.01079.md) — kind: paper — density: 5
- *Why:* MobileRAG — directly adjacent prior art with EcoVector ANN + SCR; 1.72–8.89× retrieval-latency speedup on real phones; copy the hot-path shape.

### 7. Decentralizing AI Memory: SHIMI, a Semantic Hierarchical Memory Index for Scalable Agent Reasoning

- [paper-2504.06135](_per_source/paper-2504.06135.md) — kind: paper — density: 5
- *Why:* SHIMI — decentralized hierarchical memory with explicit CRDT-style merging + Merkle-DAG + Bloom filters; the prior art for "treat the memory as a CRDT," but targets server-class peers, not BLE-mesh phones.

### 8. EmbeddingGemma: Powerful and Lightweight Text Representations

- [paper-2505.09388](_per_source/paper-2505.09388.md) — kind: paper — density: 5
- *Why:* EmbeddingGemma paper — 308M multilingual, <200MB quantized, sub-22ms on EdgeTPU, Matryoshka 128/256/512/768 — plausibly our default embedding choice.

### 9. google/embeddinggemma-300m

- [hf-google-embeddinggemma-300m](_per_source/hf-google-embeddinggemma-300m.md) — kind: other — density: 5
- *Why:* Official model card for EmbeddingGemma 300M — confirms availability across llama.cpp, MLX, LiteRT, transformers.js, Ollama (so Cactus' GGUF path inherits it).

### 10. Cactus Compute Documentation (v1.7)

- [docs-cactuscompute-docs-v1-7](_per_source/docs-cactuscompute-docs-v1-7.md) — kind: docs — density: 5
- *Why:* Cactus Compute v1.7 docs — current API surface for embed + LLM inference on iOS, Android, Flutter, React Native.

### 11. Ditto Mesh Networking

- [docs-docs-ditto-live-key-concepts-mesh-networking](_per_source/docs-docs-ditto-live-key-concepts-mesh-networking.md) — kind: docs — density: 5
- *Why:* Ditto mesh-networking key-concept doc — random connection churn, transport priority, the "no islanding" guarantee.

### 12. Ditto Docs — SDK v5: Customizing Transport Configurations

- [docs-docs-ditto-live-sdk-v5-sync-customizing-transport-configurations](_per_source/docs-docs-ditto-live-sdk-v5-sync-customizing-transport-configurations.md) — kind: docs — density: 5
- *Why:* Ditto v5 transport-config docs — the actual configuration API to enable BLE + LAN + AWDL + Wi-Fi Aware in the same mesh.

### 13. It's the Latency, Stupid (Stuart Cheshire)

- [other-stuartcheshire-rants-latency-html](_per_source/other-stuartcheshire-rants-latency-html.md) — kind: other — density: 5
- *Why:* "It's the Latency, Stupid" — the canonical "physics is the moat" essay for the on-device-RAG framing; cite when arguing cloud RAG can't beat speed-of-light propagation.

### 14. Deterministic Transformer Inference Across Hardware

- [paper-2402.00841](_per_source/paper-2402.00841.md) — kind: paper — density: 5
- *Why:* "Tiny Titans" / Deterministic Transformer Inference Across Hardware — strongest evidence that integer-quantized small models hit bitwise-identical outputs across hardware, validating our INT4/INT8 Cactus path.

### 15. Understanding and Mitigating Numerical Sources of Nondeterminism in LLMs

- [paper-2602.17099](_per_source/paper-2602.17099.md) — kind: paper — density: 5
- *Why:* "Understanding & Mitigating Numerical Sources of Nondeterminism" — quantifies FP32 vs FP16 vs BF16 cross-GPU divergence; BF16 worst, INT4/INT8 most stable. Validates the quantization choice for iOS↔Android parity.

### 16. The Hidden Problem With MLX: Why Your Apple Silicon LLM Isn't Reproducible

- [other-adityakarnam-mlx-non-determinism-apple-silicon](_per_source/other-adityakarnam-mlx-non-determinism-apple-silicon.md) — kind: other — density: 5
- *Why:* Empirical MLX-vs-NumPy divergence on Apple Silicon (142.0 vs 0.00) — but Q4_K_M and Q8_0 achieve perfect reproducibility. Direct evidence for the "pin to integer-quantized" rule.

### 17. thinking-machines-lab/batch_invariant_ops

- [repo-thinking-machines-lab-batch_invariant_ops](_per_source/repo-thinking-machines-lab-batch_invariant_ops.md) — kind: repo — density: 5
- *Why:* Reference PyTorch implementation of the batch-invariant kernels — what we'd copy if we ever needed to instrument batch-invariance ourselves.

### 18. bitchat for Android: BLE Mesh P2P Chat

- [repo-permissionlesstech-bitchat-android](_per_source/repo-permissionlesstech-bitchat-android.md) — kind: repo — density: 5
- *Why:* Public-domain BLE-mesh chat on Android (paired with the iOS repo) — the cleanest 2025 reference for the user-facing "you are in mesh with N peers" affordance and what a working iOS↔Android BLE mesh looks like.

### 19. Iroh: less net work for networks

- [repo-n0-computer-iroh](_per_source/repo-n0-computer-iroh.md) — kind: repo — density: 5
- *Why:* QUIC-based modern P2P with mobile builds — the architectural alternative to Ditto (no BLE, so not a drop-in for our brief, but a useful comparison point).

### 20. DRAG (Distributed Retrieval-Augmented Generation)

- [repo-xuchenhao001-DRAG](_per_source/repo-xuchenhao001-DRAG.md) — kind: repo — density: 5
- *Why:* DRAG reference implementation — the closest published P2P RAG prior art (overlay-routed, not CRDT-merged); cite as nearest neighbor and note the BLE+CRDT gap we fill.

### 21. Transport Multiplexing in Mobile Sync: Why Multi-Transport Beats Single-Transport Systems

- [article-dev-to-biozal-transport-multiplexing-in-mobile-sync-why-multi-trans](_per_source/article-dev-to-biozal-transport-multiplexing-in-mobile-sync-why-multi-trans.md) — kind: article — density: 5
- *Why:* The architectural thesis for *why* multi-transport (BLE + LAN + AWDL + Wi-Fi Aware) wins over single-transport; sourced from the Ditto engineering perspective.

### 22. Ditto Query Language (DQL): Distributed Data Query and Synchronization

- [docs-docs-ditto-live-dql](_per_source/docs-docs-ditto-live-dql.md) — kind: docs — density: 5
- *Why:* Ditto Query Language reference — DQL is how we'll materialize the result set the cosine top-k runs over.
