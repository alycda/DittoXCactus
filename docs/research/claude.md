---
internal_only: false
worker: claude (Opus 4.7, 1M context)
mode: B (cross-provider parallel)
generated: 2026-05-21
---

# Mesh RAG (Ditto × Cactus) — Prior Art Research (Claude pass)

Research for a peer-to-peer RAG hackathon demo where the vector index is itself a CRDT, synced over Bluetooth LE / LAN via Ditto, with on-device embedding + LLM inference via Cactus on iOS and Android. Recipes corpus; cars is the fallback. Thesis is latency + offline-first, not cost. The future-work angle is small *specialist* models, not generalists.

---

## 1. Top 10 must-read sources (ranked)

1. **Thinking Machines Lab — "Defeating Nondeterminism in LLM Inference" (Sep 2025).** Reframes LLM non-determinism as a *batch-invariance* problem in matmul/RMSNorm/attention kernels rather than a floating-point/concurrency problem, and demonstrates bitwise-identical outputs across 1,000 runs after rewriting three reduction kernels. This is the single most load-bearing source for our embedding-determinism holdout: it tells us what we have to engineer for (single-sample inference paths, fixed reduction order) and what we shouldn't waste time on (chasing FP non-associativity). https://thinkingmachines.ai/blog/defeating-nondeterminism-in-llm-inference/

2. **Cactus engine docs — `cactus_engine.md` (cactus-compute, v1.14, Apr 2026).** Primary source on the `cactus_embed`, `cactus_index_t` (init/add/query/compact/delete), and `cactus_rag_query` C-FFI surface. Confirms Cactus ships a vector-index abstraction with `top_k` and `score_threshold`, supports L2-normalized embeddings (cosine-ready), and packages Nomic, Qwen3-Embedding-0.6B, and Gemma-family embeds — but states **no determinism guarantees**. https://github.com/cactus-compute/cactus/blob/main/docs/cactus_engine.md

3. **Ditto — "An inside look at Ditto's Delta State CRDTs" (engineering blog).** Authoritative description of Ditto's state-based CRDT model, HLC-keyed version vectors, nested CRDT Map document model, and how diffs (not per-peer deltas) make ad-hoc mesh sync tractable. Read this before designing the `RecipeTuple` document. https://www.ditto.com/blog/dittos-delta-state-crdts

4. **Kleppmann, Beyer, McGranaghan, van Hardenberg — "Local-First Software: You Own Your Data, In Spite of the Cloud" (Onward! 2019, Ink & Switch).** The foundational manifesto for the thesis. Frame the writeup against the seven ideals (no spinners, work offline, sync seamlessly, longevity, privacy, user agency, "you own your data"); cite directly when arguing retrieval is the AI primitive that aligns with these. https://www.inkandswitch.com/essay/local-first/

5. **MELTing Point: Mobile Evaluation of Language Transformers (Laskaridis et al., arXiv 2024).** The single best on-device LLM benchmark paper: MELT harness, real iOS + Android devices, llama.cpp and MLC-LLM backends, energy + latency + accuracy, plus the empirical finding that on-device inference is memory-bound and quantization is an accuracy-vs-fit trade. Use its numbers for the latency-floor argument. https://arxiv.org/abs/2403.12844

6. **Wang et al. — "MobileRAG: A Fast, Memory-Efficient, and Energy-Efficient Method for On-Device RAG" (arXiv 2507.01079, Jul 2025).** Directly adjacent: an actual on-device RAG pipeline (`EcoVector` ANN + `SCR` selective content reduction) measured for latency, memory, energy on real phones. Shows 1.72–8.89× retrieval-latency speedup and 10.7–54.5% memory reduction over baselines. Read for what to copy in the local hot path. https://arxiv.org/abs/2507.01079

7. **Liu et al. — "Distributed Retrieval-Augmented Generation (DRAG)" (arXiv 2505.00443, May 2025).** The closest published prior art to our thesis: P2P RAG with each peer holding a local knowledge base, no central index, Topic-Aware Random Walk for peer discovery. The contrast is instructive — DRAG is overlay-network routed, *not* CRDT-merged, and assumes IP connectivity. Cite it as the closest neighbor and note the gap we fill: BLE-mesh + CRDT-merge rather than overlay routing. https://arxiv.org/abs/2505.00443

8. **Vora et al. — "SHIMI: Semantic Hierarchical Memory Index for Scalable Agent Reasoning" (arXiv 2504.06135, Apr 2025).** A decentralized memory architecture that explicitly uses Merkle-DAG summaries + Bloom filters + CRDT-style merging for partial cross-agent sync. This is the prior art for "treat the memory as a CRDT"; gap is they target agent reasoning, not a generic embedding store, and target server-class peers, not phones over BLE. https://arxiv.org/abs/2504.06135

9. **EmbeddingGemma — "Powerful and Lightweight Text Representations" (Google, arXiv 2509.20354).** 308M-parameter multilingual embed, runs in <200MB RAM with quantization, sub-22ms on EdgeTPU, Matryoshka dims (128–768), and is the top open <500M model on MTEB. Plausibly our default embedding choice if Cactus packages it; even if not, it's the comparison baseline. https://arxiv.org/abs/2509.20354

10. **MobileAIBench (Murthy et al., arXiv 2406.10290).** The other major mobile-LLM benchmark harness, complementary to MELT. Important for picking the small-LLM end of the demo (1B–3B class) by reporting latency, memory, and quality across iPhone + Android targets. https://arxiv.org/abs/2406.10290

---

## 2. Per-topic findings

### Task 1 — On-device embedding determinism & cross-platform reproducibility

**Sources**
- Thinking Machines Lab, "Defeating Nondeterminism in LLM Inference" (Horace He et al., Sep 2025). https://thinkingmachines.ai/blog/defeating-nondeterminism-in-llm-inference/
- `thinking-machines-lab/batch_invariant_ops` reference impl (PyTorch). https://github.com/thinking-machines-lab/batch_invariant_ops
- Karnam, "The Hidden Problem With MLX: Why Your Apple Silicon LLM Isn't Reproducible." Empirically shows MLX Metal GPU diverges 142.0 vs NumPy CPU 0.00 on identical inputs; **quantized integer models (Q4_K_M, Q8_0) achieve perfect reproducibility**. https://adityakarnam.com/mlx-non-determinism-apple-silicon/
- Ingonyama, "Solving Reproducibility Challenges in Deep Learning and LLMs" — case study showing llama.cpp CUDA GEMM kernels diverge on order 1e-4 across hardware unless replaced with deterministic variants. https://www.ingonyama.com/post/solving-reproducibility-challenges-in-deep-learning-and-llms-our-journey
- LMSYS / SGLang, "Towards Deterministic Inference in SGLang and Reproducible RL Training" (Sep 2025) — engineering writeup integrating Thinking Machines' batch-invariant kernels into SGLang. https://www.lmsys.org/blog/2025-09-22-sglang-deterministic/
- Cactus engine reference (`cactus_engine.md`) — explicitly states no determinism claims. https://github.com/cactus-compute/cactus/blob/main/docs/cactus_engine.md
- llama.cpp build docs (multi-backend: CPU, CUDA, Metal, Vulkan, ROCm, SYCL). https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md
- "Understanding and Mitigating Numerical Sources of Nondeterminism" (arXiv 2506.09501) — quantifies FP32 vs FP16 vs BF16 cross-GPU divergence; BF16 is worst, INT4/INT8 quantized paths most stable. https://arxiv.org/abs/2506.09501

**What it gives us.** The literature converges on three actionable rules: (a) batch-size variation is the dominant source of non-determinism, fixable by single-sample paths or batch-invariant kernels; (b) integer-quantized inference is dramatically more reproducible than FP16/BF16 — if we run the *same* GGUF/Q4 weights through the *same* kernel implementation on both phones, cosine ≥0.999 is plausible; (c) cross-backend (Metal vs OpenCL vs CPU) is where it actually breaks — so the safest path is "same Cactus build, same quantization, same backend tier on both phones" rather than "let each phone pick optimum."

**Gap.** Nobody has published a head-to-head Cactus iOS-vs-Android embedding cosine-parity measurement. Cactus docs do not promise it. This is genuinely an experiment we have to run as part of the holdout; the prior art tells us *what to instrument* (batch=1, fixed-K reductions, INT4 quantized weights, same kernel selection) but not *whether* Cactus' kernels happen to be batch-invariant or whether iOS Metal vs Android NEON paths converge bitwise. ANE / Hexagon / APU vendor paths are even less studied — if Cactus dispatches to ANE on iPhone and CPU on Android we should expect divergence and pin to CPU/Vulkan for the demo.

### Task 2 — CRDT vector indexes / mergeable knowledge stores

**Sources**
- DRAG, "Distributed Retrieval-Augmented Generation" (arXiv 2505.00443) — P2P RAG, TARW peer discovery, near-centralized recall at half the messages of flooding. Not CRDT-based; overlay-routed. https://arxiv.org/abs/2505.00443
- SHIMI (arXiv 2504.06135) — decentralized hierarchical memory with explicit CRDT-style merging + Merkle-DAG + Bloom filters. https://arxiv.org/abs/2504.06135
- VecDHT — protocol proposal for vector-aware DHT with semantic-similarity routing (DiskANN RobustPrune for routing tables, α-parallel greedy search). No reference impl yet. https://gist.github.com/ostafen/a556180db7d4c41abb325b5ae5e13ca4
- Tschudin, "A Connectionless Grow-Only Set CRDT" (DICG 2022). Foundational G-Set design optimized for connectionless / lossy channels — exactly our BLE regime. https://dl.acm.org/doi/abs/10.1145/3565383.3566110
- Loro (https://github.com/loro-dev/loro), Automerge (https://automerge.org/), Yjs (https://github.com/yjs/yjs) — none of the three have published an embedding-vector use case; treat as "available CRDT libs we are *not* using because Ditto subsumes them."
- arXiv 2407.07871, "Enhancing HNSW Index for Real-Time Updates" — documents the "unreachable points phenomenon" when HNSW receives concurrent inserts/deletes; relevant if we put HNSW on top of the synced set rather than a flat array. https://arxiv.org/abs/2407.07871

**What it gives us.** SHIMI + DRAG validate that the "P2P / decentralized RAG" thesis is publishable and being actively researched in 2025. Tschudin's G-Set paper validates the choice of grow-only set semantics for lossy mesh channels. VecDHT shows the design space if we ever want routing-by-similarity instead of full replication.

**Gap.** Nobody has published the *specific* combination of: (a) CRDT-merged tuple set keyed by id, (b) cosine top-k over the locally-materialized union, (c) BLE-mesh as the sync transport, (d) phone-class peers. SHIMI is server-class. DRAG assumes IP overlay routing. VecDHT is unimplemented. HNSW-over-CRDT correctness under concurrent multi-replica inserts is an open problem. Our Stage-0 escape hatch is exactly the right call: a flat array + linear cosine scan over ≤5k tuples sidesteps HNSW concurrency entirely.

### Task 3 — Peer-to-peer / mesh sync infrastructure on mobile (Ditto + alternatives)

**Sources**
- Ditto docs, "About Ditto" + "Mesh Networking 101" + "Transport Overview". Confirms BLE + LAN + AWDL (iOS) + Wi-Fi Aware (Android) + WebSockets in one mesh; `sync.start()` aggressively explores all transports; "random connection churn" prevents islanding. https://docs.ditto.live/home/about-ditto, https://docs.ditto.live/sdk/v4-7/basic/mesh-networking-101, https://docs.ditto.live/sdk/v4-8/sync/concepts/transports-overview
- Ditto delta-state CRDT blog (HLC version vectors, dot-tagged tree nodes, idempotent merge). https://www.ditto.com/blog/dittos-delta-state-crdts
- Ditto DQL docs — SQL-like query language with REGISTER/MAP/ATTACHMENT types. https://docs.ditto.live/dql/dql
- iroh (n0-computer) — QUIC-based P2P with mobile builds (iOS, Android, WASM). Modular alternative; no BLE transport so not a drop-in. https://github.com/n0-computer/iroh
- Apple MultipeerConnectivity — iOS-only, no Android interop. https://developer.apple.com/documentation/multipeerconnectivity
- Google Nearby Connections — Android-first, iOS implementation incomplete per issue #1720. https://github.com/google/nearby/issues/1720
- Bridgefy SDK — commercial cross-platform BLE mesh, license-restricted. https://bridgefy.me/sdk/
- Bitchat (permissionlesstech/bitchat + bitchat-android) — public-domain BLE-mesh chat, iOS + Android, exists as a working reference for what mesh-only mobile P2P feels like in 2025. https://github.com/permissionlesstech/bitchat, https://github.com/permissionlesstech/bitchat-android
- Willow Protocol + Earthstar — partial sync with private set intersection, mobile-friendly Rust impl. https://willowprotocol.org/earthstar/spec/, https://github.com/earthstar-project/willow-rs
- libp2p — feature-rich but heavyweight on mobile; iroh is the modern hole-punching alternative. https://www.iroh.computer/blog/comparing-iroh-and-libp2p

**What it gives us.** Ditto is uniquely positioned for our brief because it bundles BLE + LAN + the cross-platform P2P bits (AWDL/Wi-Fi Aware) under one SDK with iOS *and* Android first-class. Every alternative either drops BLE (iroh, libp2p), drops one OS (MultipeerConnectivity = iOS only; Nearby Connections = Android-first), or comes with redistribution constraints (Bridgefy). Bitchat is the open-source ergonomic baseline to study for "what does a working iOS↔Android BLE mesh look like in 2025."

**Gap.** Ditto's BLE transport has documented constraints — "a few concurrent connections, each initiation taking several seconds" — which is fine for our 2-device demo but would matter at audience-participation scale. iOS background BLE limitations (the reason Briar has no iOS app) are not solved by anyone in this space and will bite if we ever try to run the demo without the app foregrounded.

### Task 4 — On-device LLM inference frameworks (the small-LLM ecosystem)

**Sources**
- Cactus engine docs + repo, model catalog includes Qwen, Gemma, Llama, DeepSeek, Phi, Mistral families, INT4–FP32 quantization, OpenAI-compatible C-FFI. v1.14 released Apr 2026. https://github.com/cactus-compute/cactus, https://github.com/cactus-compute/cactus/blob/main/docs/cactus_engine.md
- Cactus React Native package — confirms `corpusDir` RAG API and `embed()` surface. https://github.com/cactus-compute/cactus-react-native
- MLC LLM, multi-backend mobile compiler (Metal on iOS A-series, OpenCL on Adreno/Mali). https://github.com/mlc-ai/mlc-llm
- ExecuTorch (PyTorch) — Llama 3.2 1B/3B on phones, 2.5× decode and 4.2× prefill improvement vs baseline on OnePlus 12. https://github.com/pytorch/executorch, https://pytorch.org/blog/executorch-beta/
- MediaPipe LLM Inference / LiteRT — Google's Android+iOS path; Gemma 3 1B IT and Gemma 2 2B IT packaged for it. https://ai.google.dev/edge/mediapipe/solutions/genai/llm_inference/android, https://ai.google.dev/edge/mediapipe/solutions/genai/llm_inference/ios
- MELTing Point (arXiv 2403.12844) — systematic mobile benchmark across llama.cpp + MLC-LLM. https://arxiv.org/abs/2403.12844
- MobileAIBench (arXiv 2406.10290). https://arxiv.org/abs/2406.10290
- On-Device Language Models: A Comprehensive Review (arXiv 2409.00088). https://arxiv.org/abs/2409.00088
- SmolLM2 (Apache-2.0, 135M / 360M / 1.7B; 1.7B beats Llama-3.2-1B on HellaSwag/ARC/PIQA). https://huggingface.co/HuggingFaceTB/SmolLM2-1.7B
- Tiny Titans (arXiv 2402.00841) — fine-tuned FLAN-T5-Large rivals zero-shot 7B–70B on meeting summarization. Primary evidence for "specialist small beats generalist big on narrow tasks." https://arxiv.org/abs/2402.00841
- LoRA Land (arXiv 2405.00732) — 310 fine-tuned 7B-scale LoRAs rival GPT-4 across narrow tasks. https://arxiv.org/abs/2405.00732
- DistilBERT (arXiv 1910.01108) — canonical distillation reference. https://arxiv.org/abs/1910.01108
- Llama Community License — "Built with Llama" attribution + naming requirement + scale clauses. https://www.llama.com/llama3_1/license/
- Gemma Terms of Use (pre-4) and Gemma 4 Apache-2.0 license. https://ai.google.dev/gemma/terms
- Phi-3 Mini technical report — strong-for-size scores, MIT license. https://arxiv.org/abs/2404.14219

**What it gives us — Stage 0 (generalist).** For a 1B–3B mobile generalist with the recipes corpus, the realistic candidate set is **Qwen 2.5 1.5B (Apache-2.0)**, **Gemma 3 1B IT / Gemma 2 2B IT** (Gemma terms — annoying but permissive enough for a hackathon repo), **Llama 3.2 1B / 3B** (Community License — must display "Built with Llama" and prefix model name "Llama" if redistributing weights), **Phi-3 Mini (MIT)**, and **SmolLM2 1.7B (Apache-2.0)**. Cactus packages Qwen, Gemma, Llama, and Phi families. MELT and MobileAIBench give realistic decode-speed expectations (single-digit to low-double-digit tokens/sec on a 2024 iPhone Pro or Galaxy S24 Ultra at 4-bit). SmolLM2 1.7B with Apache-2.0 is the cleanest license story; Phi-3 Mini if quality matters more than size.

**What it gives us — structured-list merge quality.** "Tiny Titans" (FLAN-T5-Large rivaling 7B-70B zero-shot on summarization) and LoRA Land are the primary defenses of the future-work specialist angle. For our *Stage 0* gating question — "does an off-the-shelf 1B–3B model merge ingredient lists coherently?" — there is no published recipe-merge-specific eval. The closest are LLMStructBench (arXiv 2602.14743) for structured extraction, the "Large Language Models for Ingredient Substitution" paper (arXiv 2412.04922) for recipe-domain LLM work, and "Schema-aware Information Extraction Using On-Device Large Language Models" (arXiv 2505.14992) for on-device structured extraction. https://arxiv.org/abs/2412.04922, https://arxiv.org/abs/2505.14992

**Gap.** No published benchmark answers "at what parameter count does ingredient-list merging stop being terrible." This is exactly the screen we need to run ourselves with a small fixed eval (5–10 multi-source recipes, 3 candidate models). The cars fallback exists because we may need to swap if the answer is "≥7B," which doesn't fit. Also: no published cross-iOS/Android Cactus quality parity report — we're flying blind on whether the *same* model+quantization decodes consistently across our two phones.

### Task 5 — On-device embedding models + vector search

**Embedding model sources**
- EmbeddingGemma 300M (arXiv 2509.20354, Sep 2025) — 308M params, <200MB quantized, sub-22ms on EdgeTPU, Matryoshka 128/256/512/768, top open <500M on MTEB. https://arxiv.org/abs/2509.20354, https://huggingface.co/google/embeddinggemma-300m
- all-MiniLM-L6-v2 (sentence-transformers) — 22M params, 384-dim, ~15ms/1K tokens CPU; canonical "small, fast, good enough" baseline. https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2
- Nomic Embed v1.5 (arXiv 2402.01613) — 137M params, Matryoshka 64–768, surpasses OpenAI text-embedding-3-small; Cactus ships `nomic-ai/nomic-embed-text-v2-moe`. https://arxiv.org/abs/2402.01613, https://huggingface.co/nomic-ai/nomic-embed-text-v1.5
- BGE-small-en-v1.5 (BAAI) — 33M params, 384-dim, MIT license. https://huggingface.co/BAAI/bge-small-en-v1.5
- Qualcomm-optimized Nomic-Embed-Text on AI Hub — concrete evidence of mobile-NPU deployment. https://aihub.qualcomm.com/models/nomic_embed_text

**Vector search lib sources**
- USearch (unum-cloud) — Apache-2.0, single-header C++11, iOS + Android + Swift bindings, HNSW, 10× faster than FAISS in their benchmarks, user-defined metrics. v2.25.2 May 2026; very actively maintained. https://github.com/unum-cloud/usearch
- sqlite-vec (Alex Garcia) — Apache-2.0 / MIT dual, pure C, runs on iOS + Android (pre-compiled NDK ABIs since v0.1.2), 151 open issues, "pre-v1 expect breaking changes." https://github.com/asg017/sqlite-vec, https://alexgarcia.xyz/sqlite-vec/android-ios.html
- faiss-mobile community port — Apple-only (iOS/macOS/tvOS/watchOS); no Android. https://github.com/DeveloperMindset-com/faiss-mobile
- Raw cosine over a 5000-element float-array — at our scale (~5k tuples × 384 dims = 7.7 MB) this is by far the simplest correct answer and avoids the HNSW-under-concurrent-insert correctness mess.

**What it gives us.** At our scale (≤5k tuples combined), **raw cosine over a flat array is the right Stage-0 choice** — fits in RAM, exact recall, trivially CRDT-friendly because no index state needs merging. USearch is the right escape if we need ANN. sqlite-vec is right if we want persistence + queries fused with metadata filters. EmbeddingGemma + Nomic-v1.5 are the strongest small-embed candidates; the practical question is which one Cactus exposes most cleanly to both Swift and Kotlin with bitwise-identical outputs.

**Gap.** Same as Task 1: no public cross-mobile-platform cosine-parity benchmark. We'll have to run it. Also: every named embedding model is trained on general web text; recipe-domain cosine separation between (e.g.) "chicken tortilla soup" variants is empirical and untested.

### Task 6 — Local-first AI prior art + writeup framing

**Sources**
- Kleppmann et al., "Local-First Software" (Onward! 2019). https://www.inkandswitch.com/essay/local-first/
- Kleppmann, "The past, present, and future of local-first" — Local-First Conf 2024 keynote. https://martin.kleppmann.com/2024/05/30/local-first-conference.html
- Local-First Conf 2024 program (the inaugural conference); talks include Aaron Boodman on Zero/Replicache, Maggie Appleton closing keynote on AI × local-first. https://www.localfirstconf.com/local-first-conf-2024
- Maggie Appleton, "Home-Cooked Software and Barefoot Developers" — the strongest published articulation of AI × local-first × end-user software. Sets up the writeup's framing that on-device + retrieval is *for users*. https://maggieappleton.com/home-cooked-software, https://www.youtube.com/watch?v=qo5m92-9_QI
- localfirst.fm Ep. 13 (Maggie Appleton). https://www.localfirst.fm/13
- Anytype (P2P sync, E2E, object-graph store) — closest competing personal-data store. https://anytype.io
- Logseq + Obsidian local-AI plugin ecosystems — relevant near-misses; all run local LLMs but none sync the RAG corpus P2P. https://github.com/UNICKCHENG/logseq-ai-assistant
- Apple Foundation Models / Apple Intelligence (WWDC 2025 sessions on on-device prompt design). https://developer.apple.com/videos/play/wwdc2025/248/

**What it gives us.** The Kleppmann manifesto + Appleton "barefoot developers" talk are the two strongest framings for "retrieval is the AI primitive that aligns with local-first." Use Kleppmann for the seven ideals, Appleton for the *human* case (small, home-cooked, composable). Avoid the cost-comparison framing entirely — both these sources lean on user agency, latency, ownership, and offline.

**Gap.** Nobody in the local-first canon has yet published a piece arguing *specifically* that retrieval beats chat-history/weights/KV-cache as the AI-meets-P2P primitive. That's the writeup's contribution.

### Task 7 — Latency floors and "the network round-trip is the moat" argument

**Cloud-side latency sources**
- Qdrant benchmarks — 4ms p50 at high recall on purpose-built hardware. https://qdrant.tech/benchmarks/
- Pinecone published numbers — 16ms p50 / 33ms p99 at 10M vectors; 45ms p50 / 96ms p99 at 600 QPS over 135M vectors. (These are best-case server-side numbers and do *not* include the client RTT, which is the actual moat.)
- Vector DB benchmark roundups (corroborating). https://www.salttechno.ai/datasets/vector-database-performance-benchmark-2026/

**Network floor sources**
- arXiv 2301.07788, "Round Trip Time (RTT) Delay in the Internet: Analysis and Trends." https://arxiv.org/abs/2301.07788
- High Performance Browser Networking primer (Grigorik) — ~5 µs/km in fiber; ~10 ms/1000 km one-way propagation; LTE adds 30–50 ms median RTT. https://hpbn.co/primer-on-latency-and-bandwidth/

**On-device end-to-end sources**
- MobileRAG (arXiv 2507.01079) — measured end-to-end on phones. https://arxiv.org/abs/2507.01079
- EdgeRAG (arXiv 2412.21023) — edge-device RAG, 131% retrieval-latency improvement vs CPU baseline at large index. https://arxiv.org/abs/2412.21023
- EmbeddingGemma — sub-22ms embedding on EdgeTPU. https://arxiv.org/abs/2509.20354
- ExecuTorch + LiteRT decode-speed numbers on real phones (Llama 3.2 1B/3B). https://pytorch.org/blog/executorch-beta/

**What it gives us.** The argument writes itself: a cloud-RAG path is fundamentally bounded by speed-of-light propagation (≈10 ms/1000 km one-way) plus cellular RTT (~30–50 ms median LTE) plus server-side vector-search latency (~5–50 ms) plus LLM-prefill RTT — easily 200–500 ms for the round trip before any tokens decode. An on-device path is ~20 ms for embedding + a few ms for cosine top-k over ≤5k vectors + LLM TTFT (Cactus claims sub-50 ms, MELT shows 100–500 ms is realistic at 1B–3B on a modern phone). Crucially, the cloud path *cannot get faster than physics*; the on-device path can. This is the durable-property argument the brief wants.

**Gap.** No single published paper compares cloud RAG vs on-device RAG end-to-end on the same query under identical conditions. We can assemble the comparison from the above sources but it will be our own composite measurement.

### Task 8 — Hackathon demo aesthetics + presentation tooling

**Sources**
- Presenterm — Rust-based terminal Markdown deck, Mermaid + LaTeX + code execution + speaker notes + PDF export. https://github.com/mfontanini/presenterm
- Presenterm docs and example deck. https://mfontanini.github.io/presenterm/, https://github.com/mfontanini/presenterm/blob/master/examples/demo.md
- Slidev — Vite + Vue + Markdown, Monaco editor for live code, the strongest non-terminal alternative. https://github.com/slidevjs/slidev, https://sli.dev/guide/
- Reveal.js — long-standing web deck framework. https://revealjs.com/
- Apple WWDC 2025 "Explore prompt design & safety for on-device foundation models" — a production-quality on-device-AI demo to imitate for pacing and legibility. https://developer.apple.com/videos/play/wwdc2025/248/
- Bitchat as P2P "moment of magic" UX reference (two phones, no infra, observable state change). https://github.com/permissionlesstech/bitchat

**What it gives us.** Presenterm is purpose-built for the kind of deck the brief wants: terminal-native, Markdown-source-controlled, Mermaid + code-block-execution support, and PDF export for the writeup deliverable. Slidev is the fallback if we want richer visuals during the "before sync / after sync" reveal. The Apple WWDC sessions are the closest professional model for narrating an on-device demo to non-technical audiences.

**Gap.** No published writeup specifically nails the "two devices, airplane mode, BLE handshake, observable state change" demo pattern at hackathon length. The closest analogues are AirDrop demos in early iOS keynotes (unfilmed in detail) and the various Bridgefy protest-mesh demos (no published shape we can lift). We will be inventing this presentation pattern.

---

## 3. Tool shortlist

### On-device embedding model

**Primary candidate: EmbeddingGemma 300M (google/embeddinggemma-300m)**
- Repo: https://huggingface.co/google/embeddinggemma-300m (and Gemma model release tree)
- Last release: Sep 2025
- License: Gemma Terms of Use (custom; permissive for hackathon; OK to redistribute weights with notice)
- Maintenance health: backed by Google DeepMind, actively iterated alongside Gemma family
- Mobile-platform support: runs in llama.cpp, MLX, LiteRT, transformers.js, Ollama — so Cactus' GGUF path inherits it; <200MB RAM with quantization; sub-22ms on EdgeTPU
- Decision: **use it** if Cactus exposes it cleanly to both Swift and Kotlin; it's the strongest small open embedding model and Matryoshka dims let us trade speed for quality late.

**Backup: Nomic Embed Text v1.5 (137M)**
- Repo: https://github.com/nomic-ai/nomic-embed-text-v1.5 (HF: https://huggingface.co/nomic-ai/nomic-embed-text-v1.5)
- License: Apache-2.0 (cleanest hackathon-repo license)
- Mobile: explicitly Qualcomm AI Hub optimized; Cactus ships `nomic-ai/nomic-embed-text-v2-moe`
- Decision: **maybe** — cleanest license and Cactus packages it directly, but slightly smaller community and MTEB score than EmbeddingGemma. Use as Plan B if EmbeddingGemma quantization quality across iOS/Android diverges.

**Floor: all-MiniLM-L6-v2**
- Repo: https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2
- License: Apache-2.0
- Decision: **don't ship as primary** — 22M params is tiny but MTEB scores are dated; only use if EmbeddingGemma + Nomic both fail the cosine-parity test for some reason and we need a known-deterministic ONNX path.

### On-device LLM

**Primary candidate: Qwen 2.5 1.5B Instruct (Apache-2.0)**
- Repo: https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct
- License: Apache-2.0 (zero hackathon-repo friction)
- Maintenance: Alibaba; actively iterated; Cactus catalog lists Qwen3 variants
- Mobile: shown working in MLC, llama.cpp, Cactus; benchmarked across iPhone 16 Pro + Galaxy S24 Ultra in mobile-edge papers
- Decision: **use it** as default; clean license, Cactus packages it, sub-2B fits our latency budget.

**Backup: SmolLM2 1.7B Instruct**
- Repo: https://huggingface.co/HuggingFaceTB/SmolLM2-1.7B-Instruct
- License: Apache-2.0
- Maintenance: Hugging Face team; active
- Mobile: runs in llama.cpp / MLC / Cactus
- Decision: **maybe** — strong scores against Llama-3.2-1B and Apache-2.0 license is the cleanest possible, but Cactus' catalog mentions Qwen/Gemma/Llama/Phi by name and not SmolLM2; verify Cactus actually loads it before committing.

**Quality reach: Gemma 3 1B IT / Gemma 2 2B IT**
- Repos: https://huggingface.co/google/gemma-3-1b-it, https://huggingface.co/google/gemma-2-2b-it (LiteRT-community variants: https://huggingface.co/litert-community/Gemma3-1B-IT, https://huggingface.co/litert-community/Gemma2-2B-IT)
- License: Gemma Terms (note: Gemma 4 moved to Apache-2.0; earlier Gemma still has custom terms with redistribution-notice clause)
- Decision: **maybe** — best quality-per-byte in this size class but the redistribution clause is friction for a public hackathon repo; lean toward Gemma 4 if it's released and Apache-2.0 by demo time.

**Avoid as default: Llama 3.2 1B / 3B**
- Repo: https://huggingface.co/meta-llama/Llama-3.2-1B-Instruct
- License: Llama Community License — requires "Built with Llama" attribution, model name must start with "Llama," scale clauses if we ever cross 700M MAUs
- Decision: **don't ship as primary** for a public hackathon repo — manageable but adds attribution requirements we don't need. Use only if quality measurements at hackathon time make it strictly necessary.

### On-device vector search lib

**Primary candidate: raw cosine over a flat float32 array (≤5k tuples)**
- "Repo": ~50 lines of Swift + Kotlin
- License: ours
- Decision: **use it** for Stage 0. At 5k × 384 dims = 7.7 MB, brute force is exact-recall, sub-millisecond, CRDT-trivial (no index state to merge), and sidesteps the HNSW-concurrent-insert correctness mess.

**Escape hatch: USearch (unum-cloud)**
- Repo: https://github.com/unum-cloud/usearch
- Last release: v2.25.2 (May 2, 2026)
- License: Apache-2.0
- Maintenance: very active — 2,361 commits, 205 releases, 79 open issues
- Mobile: native Swift + Objective-C bindings; Android; single-header C++11 for any-platform compile
- Decision: **maybe** — if we ever cross 10k tuples or want ANN for headroom, USearch is the right answer. Add as a feature flag, not a Stage-0 dependency.

**Persistence option: sqlite-vec**
- Repo: https://github.com/asg017/sqlite-vec
- Last release: v0.1.9 (Mar 31, 2026)
- License: Apache-2.0 OR MIT
- Maintenance: 464 commits, 151 open issues, "pre-v1 expect breaking changes"
- Mobile: pre-compiled iOS + Android NDK ABIs since v0.1.2 (https://alexgarcia.xyz/sqlite-vec/android-ios.html)
- Decision: **don't ship as primary** — Ditto already provides the persistence layer for the tuples; running sqlite-vec on top duplicates state. Reconsider only if we move the embedding column outside Ditto for size reasons.

### Mesh-sync layer (Ditto config)

**Decision: use Ditto with BLE + LAN transports both enabled, no internet, no big-peer**
- Docs: https://docs.ditto.live, https://docs.ditto.live/sdk/v4-8/sync/concepts/transports-overview
- License: commercial (Ditto SDK; check trial/free-tier terms for hackathon redistribution — this is the one license item worth verifying with Ditto directly before publishing the demo repo)
- Maintenance: company product, weekly-cadence releases
- Mobile: Swift, Kotlin, Flutter, React Native, JS Web, C++, Rust, Go, .NET — covers both phones natively
- Mesh: BLE + LAN + AWDL (iOS peer-to-peer Wi-Fi) + Wi-Fi Aware (Android) + WebSockets in one mesh
- Decision: **use it** — there is no comparable cross-platform BLE-included alternative. iroh is the next-best but lacks BLE. The "moment of magic" demo needs BLE specifically.

### Slide-deck framework

**Primary: Presenterm**
- Repo: https://github.com/mfontanini/presenterm
- License: MIT
- Maintenance: very active
- Decision: **use it** — Markdown source matches the rest of the repo, Mermaid for the architecture diagram, PDF export for the writeup deliverable, code-block execution lets us demo the cosine math live.

**Backup: Slidev**
- Repo: https://github.com/slidevjs/slidev
- License: MIT
- Decision: **maybe** — if the demo needs richer visuals or in-browser interactivity for the airplane-mode reveal, Slidev gives us animations Presenterm can't. Default to Presenterm; switch only if visuals demand it.

---

## 4. Reference architectures

### a. Software Mansion — `react-native-rag` + `react-native-executorch`
- Repos: https://github.com/software-mansion-labs/react-native-rag, https://github.com/software-mansion/react-native-executorch
- Key files: `packages/executorch/README.md`, the `Introducing React Native RAG` blog (https://blog.swmansion.com/introducing-react-native-rag-fbb62efa4991), and the three-part "AI-Powered Note-Taking" series (https://blog.swmansion.com/building-an-ai-powered-note-taking-app-in-react-native-part-3-local-rag-868ba75f818b).
- What to copy: the *modular* Embeddings / VectorStore / LLM interfaces — copy the seam shapes even though we'll back them with Cactus instead of ExecuTorch. They also already document the corpus-loading, chunking, retrieval, and prompt-assembly path that we'll need to mirror on the iOS side via Cactus' Swift SDK.

### b. cactus-compute — official RN example agents
- Repo: https://github.com/cactus-compute/example-react-agents
- Key files: agent + tool-calling demo using `cactus-react-native` 0.2.6+.
- What to copy: the React Native shape of "init model from URL → call Cactus → render tokens." We're not building an agent, but the Cactus init lifecycle, model-download UX, and error handling are reusable verbatim. Mirror this for the Android side and adapt the iOS side via Cactus Kotlin or the Swift package.

### c. DeepSense `edge-slm`
- Repo: https://github.com/deepsense-ai/edge-slm
- Companion writeup: https://deepsense.ai/blog/implementing-small-language-models-slms-with-rag-on-embedded-devices-leading-to-cost-reduction-data-privacy-and-offline-use/
- What to copy: a real Android-native RAG pipeline (llama.cpp backend, tested with Phi-2, Gemma, TinyLlama, 1B–3B) — including the chunking / embedding / retrieval / prompt sections of the codebase. This is the closest mature reference for "everything-on-device RAG, no Ditto." We graft Ditto in *on top of* this shape.

### d. Edge-Veda — Flutter on-device RAG
- Repo: https://github.com/ramanujammv1988/edge-veda
- What to copy: the Document Q&A example's dual-model architecture (separate embedder + generator), semantic chunking, and streaming-answer-with-source-attribution. Especially the source-attribution UX is exactly right for our demo — when a recipe answer cites tuples that arrived from the *other* phone, that's the moment of magic visualized.

### e. permissionlesstech/bitchat (+ bitchat-android)
- Repos: https://github.com/permissionlesstech/bitchat, https://github.com/permissionlesstech/bitchat-android
- What to copy: the *BLE-mesh ergonomics* — peer discovery UX, foregrounding requirements, the visual indicator for "you are in mesh with N peers." We're not copying the chat protocol (we're using Ditto), but the user-facing mesh-state affordance is the same demo problem and bitchat is the clearest 2025 reference for it on both iOS and Android.

---

## 5. Open research questions (real gaps)

1. **Cactus iOS↔Android embedding parity.** No published measurement of `cactus_embed("chicken tortilla soup")` cosine similarity across Swift-on-iOS and Kotlin-on-Android with the same GGUF/Q4 weights. Cactus does not promise it. This is our load-bearing experiment.
2. **Specialist parameter floor for ingredient-list merging.** No published benchmark answers "at what model size does multi-source recipe normalization become coherent." The closest analog (Tiny Titans for summarization) is a domain mismatch. We need an internal eval before committing to recipes vs cars.
3. **CRDT + HNSW under concurrent multi-replica inserts.** "Enhancing HNSW for Real-Time Updates" (arXiv 2407.07871) addresses update degradation on a *single* replica. Nobody has analyzed correctness when each replica builds an HNSW independently over a different arrival order of the same eventually-converging CRDT set. We sidestep this with flat-array brute force; an actual paper here would be publishable.
4. **End-to-end on-device RAG vs cloud RAG benchmark on identical queries.** MobileRAG measures only the on-device path. Cloud-RAG benchmarks are server-side only. The composite "phone-to-cloud-and-back vs phone-only" measurement appears not to exist in publishable form.
5. **iOS background-BLE for mesh.** A multi-year unsolved iOS constraint. Briar has no iOS app because of it. Bitchat works only foregrounded. For a live demo this is fine; for "always-on mesh," it's still an open problem at the OS level.
6. **Cactus + Ditto composition.** No published example combines Cactus' `cactus_index_t` with Ditto-synced tuples. We are the first integration point. Risk: Cactus' vector index may want to *own* persistence in a way that fights Ditto's CRDT store; the integration may be "Cactus generates embeddings; Ditto stores tuples; we run our own cosine top-k from the materialized Ditto query result" rather than `cactus_rag_query` directly.

---

## 6. Source ledger

https://github.com/cactus-compute/cactus
https://github.com/cactus-compute/cactus/blob/main/docs/cactus_engine.md
https://github.com/cactus-compute/cactus-react-native
https://github.com/cactus-compute/cactus-kotlin
https://github.com/cactus-compute/example-react-agents
https://cactuscompute.com/docs/v1.7
https://huggingface.co/Cactus-Compute
https://docs.ditto.live
https://docs.ditto.live/home/about-ditto
https://docs.ditto.live/sdk/v4-7/basic/mesh-networking-101
https://docs.ditto.live/sdk/v4-8/sync/concepts/transports-overview
https://docs.ditto.live/dql/dql
https://www.ditto.com/blog/dittos-delta-state-crdts
https://thinkingmachines.ai/blog/defeating-nondeterminism-in-llm-inference/
https://github.com/thinking-machines-lab/batch_invariant_ops
https://adityakarnam.com/mlx-non-determinism-apple-silicon/
https://www.ingonyama.com/post/solving-reproducibility-challenges-in-deep-learning-and-llms-our-journey
https://www.lmsys.org/blog/2025-09-22-sglang-deterministic/
https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md
https://arxiv.org/abs/2506.09501
https://arxiv.org/abs/2505.00443
https://arxiv.org/abs/2504.06135
https://gist.github.com/ostafen/a556180db7d4c41abb325b5ae5e13ca4
https://dl.acm.org/doi/abs/10.1145/3565383.3566110
https://github.com/loro-dev/loro
https://automerge.org/
https://github.com/yjs/yjs
https://arxiv.org/abs/2407.07871
https://github.com/n0-computer/iroh
https://www.iroh.computer/blog/comparing-iroh-and-libp2p
https://developer.apple.com/documentation/multipeerconnectivity
https://github.com/google/nearby/issues/1720
https://bridgefy.me/sdk/
https://github.com/permissionlesstech/bitchat
https://github.com/permissionlesstech/bitchat-android
https://willowprotocol.org/earthstar/spec/
https://github.com/earthstar-project/willow-rs
https://github.com/mlc-ai/mlc-llm
https://github.com/pytorch/executorch
https://pytorch.org/blog/executorch-beta/
https://ai.google.dev/edge/mediapipe/solutions/genai/llm_inference/android
https://ai.google.dev/edge/mediapipe/solutions/genai/llm_inference/ios
https://huggingface.co/litert-community/Gemma3-1B-IT
https://huggingface.co/litert-community/Gemma2-2B-IT
https://arxiv.org/abs/2403.12844
https://arxiv.org/abs/2406.10290
https://arxiv.org/abs/2409.00088
https://huggingface.co/HuggingFaceTB/SmolLM2-1.7B
https://huggingface.co/HuggingFaceTB/SmolLM2-1.7B-Instruct
https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct
https://huggingface.co/google/gemma-3-1b-it
https://huggingface.co/google/gemma-2-2b-it
https://huggingface.co/meta-llama/Llama-3.2-1B-Instruct
https://arxiv.org/abs/2404.14219
https://arxiv.org/abs/2402.00841
https://arxiv.org/abs/2405.00732
https://arxiv.org/abs/1910.01108
https://arxiv.org/abs/2412.04922
https://arxiv.org/abs/2505.14992
https://www.llama.com/llama3_1/license/
https://ai.google.dev/gemma/terms
https://arxiv.org/abs/2509.20354
https://huggingface.co/google/embeddinggemma-300m
https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2
https://arxiv.org/abs/2402.01613
https://huggingface.co/nomic-ai/nomic-embed-text-v1.5
https://huggingface.co/BAAI/bge-small-en-v1.5
https://aihub.qualcomm.com/models/nomic_embed_text
https://github.com/unum-cloud/usearch
https://github.com/asg017/sqlite-vec
https://alexgarcia.xyz/sqlite-vec/android-ios.html
https://github.com/DeveloperMindset-com/faiss-mobile
https://www.inkandswitch.com/essay/local-first/
https://martin.kleppmann.com/2024/05/30/local-first-conference.html
https://www.localfirstconf.com/local-first-conf-2024
https://maggieappleton.com/home-cooked-software
https://www.youtube.com/watch?v=qo5m92-9_QI
https://www.localfirst.fm/13
https://anytype.io
https://github.com/UNICKCHENG/logseq-ai-assistant
https://developer.apple.com/videos/play/wwdc2025/248/
https://qdrant.tech/benchmarks/
https://www.salttechno.ai/datasets/vector-database-performance-benchmark-2026/
https://arxiv.org/abs/2301.07788
https://hpbn.co/primer-on-latency-and-bandwidth/
https://arxiv.org/abs/2507.01079
https://arxiv.org/abs/2412.21023
https://github.com/mfontanini/presenterm
https://mfontanini.github.io/presenterm/
https://github.com/mfontanini/presenterm/blob/master/examples/demo.md
https://github.com/slidevjs/slidev
https://sli.dev/guide/
https://revealjs.com/
https://github.com/software-mansion-labs/react-native-rag
https://github.com/software-mansion/react-native-executorch
https://blog.swmansion.com/introducing-react-native-rag-fbb62efa4991
https://blog.swmansion.com/building-an-ai-powered-note-taking-app-in-react-native-part-3-local-rag-868ba75f818b
https://github.com/deepsense-ai/edge-slm
https://deepsense.ai/blog/implementing-small-language-models-slms-with-rag-on-embedded-devices-leading-to-cost-reduction-data-privacy-and-offline-use/
https://github.com/ramanujammv1988/edge-veda

---

_Confirmation: this file was written to `/Users/alyssaevans/Experiments/DittoXCactus/docs/research/claude.md` by the Claude (Opus 4.7, 1M context) Mode-B worker on 2026-05-21._
