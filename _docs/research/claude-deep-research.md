# Deep-Research Pass 4: Peer-to-Peer RAG on a CRDT Vector Index (Cactus + Ditto)

## TL;DR

- **The riskiest claim — cross-device embedding determinism — is plausible but unverified in any published source.** The chain of evidence (Thinking Machines Sep 2025 "Defeating Nondeterminism in LLM Inference" + llama.cpp PR #16016 stating "CPU is already deterministic" + arXiv:2406.10816's NEON-intrinsic analysis of llama.cpp on ARMv9) supports a working hypothesis that batch=1, single-stream, CPU-only Cactus/GGUF inference on iOS-ARM and Android-ARM should yield bit-identical vectors — but no one has published the iOS↔Android side-by-side comparison, and the Cactus team has made no public statement on this. **Mandatory week-1 hackathon action: write a 20-line determinism test.**

- **"Vector index as a CRDT" is genuinely novel territory.** The closest published prior art is DRAG (arXiv:2505.00443, May 2025) — peer-to-peer RAG via Topic-Aware Random Walk — but it treats each peer's KB as private data queried over the network rather than as a synchronized CRDT-merged index. The May 2025 HNSW-merge paper (arXiv:2505.16064) is the next-closest and explicitly justifies starting with brute-force cosine instead of HNSW at our scale.

- **Stack is decided:** Cactus Kotlin Multiplatform 1.4.x + EmbeddingGemma 300M (or all-MiniLM-L6-v2 fallback) + **Qwen 2.5 1.5B Q8_0** (Apache-2.0, 95.7% JSON parse rate per AscentCore Apr 2026 — Llama 3.2 3B and SmolLM2 1.7B are disqualified for structured output) + naive top-k cosine over ≤5000-tuple float32 array + Ditto v5 BLE+LAN + Presenterm (MIT) for the deck. The full system fits a 1–4s end-to-end query budget on a mid-range phone with zero network round-trips — and that latency floor, not cost, is the thesis.

## Key Findings

**The determinism story is "CPU-only or bust" and has no smoking-gun primary source.** llama.cpp issue #3625 explicitly shows that disabling GPU offload (`--n-gpu-layers 0`) "fixed" broken embeddings under CUDA; the Oct 2024 buttondown llama.cpp roll-up notes "embedding output discrepancies … GPU vs CPU executions for the same input." llama.cpp PR #16016 (Sep 2025) adds opt-in CUDA determinism while stating CPU is already deterministic — but only within a single binary/single slot. Issue #7052 documents multi-slot/parallel-batch nondeterminism on the same host, which the Thinking Machines paper formalizes as batch-size variance being the dominant cause. The arXiv:2406.10816 paper shows llama.cpp on ARMv9 runs the same hand-written NEON intrinsics (`ggml_compute_forward_rms_norm_f32`, `ggml_fp16_to_fp32_row`) on any compliant ARM core, which is the strongest indirect argument for iOS↔Android bit-equality. None of this is a direct experimental confirmation. **We are first in line to publish that data point.**

**"P2P RAG" exists in 2025 papers but no one has framed the vector index as a CRDT.** DRAG (arXiv:2505.00443) and DGRAG (arXiv:2505.19847) both use peer-to-peer retrieval but assume the data stays local to each owner and queries traverse the network. The blockchain-secured decentralized RAG (arXiv:2511.07577) introduces source-reliability scoring. None merge embedding tuples via CRDT semantics. Stephen Dolan's "The Only Undoable CRDTs are Counters" (arXiv:2006.10494) gives us the formal justification for our grow-only-set choice; Tschudin's "A Connectionless Grow-Only Set CRDT" (DICG 2022 workshop, very low SEO) is the closest analog to what Ditto is doing on BLE.

**Ditto is fit-for-purpose and the airplane-mode demo is explicitly supported.** Per the Ditto FAQ: "Ditto can be used in Airplane Mode. If Bluetooth or WiFi is manually toggled on after selecting Airplane Mode, then Ditto will be able to sync using those modes." Ditto 5.0 release notes claim "validated with up to 40 concurrent devices across iOS, Android, and budget hardware." BLE bandwidth is 20 kB/s (BLE 4.x) up to ~1.8 Mbps average (BLE 5.x). For our corpus shape (50 tuples × ~1.5 kB per embedding) BLE convergence is ~4s — comfortably within a demo window. The Aug 2025 paper arXiv:2508.01110 measures MultipeerConnectivity peer-to-peer latency at 70.4ms mean / p95 < 74ms on 5 GHz Wi-Fi, which is our concrete primary citation for "P2P round-trip beats cloud RTT."

**Latency is the thesis. Numbers anchor it.** Per the Salt Technologies AI Vector Database Benchmark 2026 (CC BY 4.0, 1M vectors / 1536-dim): "Qdrant delivers the lowest p50 latency at 4ms among purpose-built vector databases"; Pinecone sits at 8 ms p50. These are server-side query latencies only, before any network RTT. Per Kunal Ganglani's March 2026 5-model TTFT benchmark (updated May 10 2026): "Claude Haiku 4.5 at 639 ms TTFT on short prompts (p95: 742 ms); GPT-4.1 Mini hit 2,205 ms TTFT (p95: 4,004 ms)" — Ganglani's takeaway: "Four seconds to see the first token in a worst case. In a chatbot, that's brutal." Mobile-to-cloud RTT adds another 30–150ms. Combined cloud RAG p99 is ~700ms–4s before any tokens stream. On-device Cactus claims "sub-50ms time-to-first-token" in their HuggingFace blog (vendor-only, not independently verified); the more conservative PromptQuorum 2026 aggregator shows iPhone 17 Pro running Gemma 3 1B at 35–45 t/s and SmolLM 2 1.7B at 26–32 t/s — meaning a 50-token RAG response is well under 2s. **The moat is c (speed of light) and cold-start queueing, neither of which can be optimized.**

**The Cactus Flutter SDK already ships an HNSW+ObjectBox local RAG class.** This is buried in `cactus-compute/cactus-flutter`'s README and is the single most important "the CLI agents will miss this" finding: the on-device-RAG-on-Cactus part is already a solved problem in the SDK. Our novelty is the *CRDT-merged* part — replacing ObjectBox with a Ditto collection so that tuples are mesh-synced. This sharpens the thesis: we are not inventing on-device RAG, we are inventing the merge.

## Details

### 1. Top 10 must-read sources (ranked)

1. **"Defeating Nondeterminism in LLM Inference," Horace He & Thinking Machines Lab (Sep 2025)** — https://thinkingmachines.ai/blog/defeating-nondeterminism-in-llm-inference/ — Identifies batch-size variance, not float non-associativity, as the dominant cause of nondeterministic LLM inference: "the primary reason nearly all LLM inference endpoints are nondeterministic is that the load (and thus batch-size) nondeterministically varies … this nondeterminism is not unique to GPUs — LLM inference endpoints served from CPUs or TPUs will also have this source of nondeterminism." Companion repo `thinking-machines-lab/batch_invariant_ops`. The single most load-bearing source for our embedding-determinism thesis.

2. **"Distributed Retrieval-Augmented Generation (DRAG)," Xu et al., arXiv:2505.00443** — https://arxiv.org/abs/2505.00443 — First arxiv paper to architect peer-to-peer RAG with a Topic-Aware Random Walk for peer discovery; the only published "P2P RAG" framework prior art we found. Companion repo at github.com/xuchenhao001/DRAG. Sister paper DGRAG (arXiv:2505.19847) extends to edge-cloud.

3. **Cactus GitHub repo + InfoQ launch coverage** — https://github.com/cactus-compute/cactus, https://www.infoq.com/news/2025/12/cactus-on-device-inference/, and the Ndubuaku/Shemet HF blog https://huggingface.co/blog/rshemet/cactus-on-device-inference — Primary docs for our chosen stack; benchmarks, INT4 weights, embedding API surface, NPU acceleration claims, and the Kotlin SDK release we will use.

4. **Ditto official docs + Kotlin 5.0 release notes + transport config** — https://docs.ditto.live, https://docs.ditto.live/sdk/latest/release-notes/kotlin (Ditto 5.0, tested mesh up to 40 concurrent devices), https://docs.ditto.live/sdk/v5/sync/customizing-transport-configurations — Primary docs for mesh sync; BLE typically 20 kB/s, AWDL 1 GB in ~8s, plus cross-platform iOS↔Android BLE interop confirmation.

5. **EmbeddingGemma 300M model cards (Google AI + LiteRT community + Unsloth GGUF)** — https://huggingface.co/google/embeddinggemma-300m, https://huggingface.co/litert-community/embeddinggemma-300m, https://huggingface.co/unsloth/embeddinggemma-300m-GGUF, https://ai.google.dev/gemma/docs/embeddinggemma/model_card — Google's official on-device embedding model with iOS+Android LiteRT variants, Matryoshka 768→128 dims, 22ms EdgeTPU inference. Direct alternative to MiniLM via Cactus's GGUF loader.

6. **Local-first software essay + 2024 follow-up talk (Kleppmann et al.)** — https://martin.kleppmann.com/papers/local-first.pdf (2019), https://martin.kleppmann.com/2024/05/30/local-first-conference.html, https://speakerdeck.com/ept/the-past-present-and-future-of-local-first — Canonical primary source; the 2024 talk proposes the interim definition "in local-first software, the availability of another computer should never prevent you from working" — clean opener quote for our writeup.

7. **"Three Algorithms for Merging HNSW Graphs," arXiv:2505.16064 (May 2025)** — https://arxiv.org/abs/2505.16064 — First published paper on merging independently constructed HNSW indices, exactly the operation a CRDT-merged vector store would need. Frames merging as "particularly relevant in distributed systems, incremental indexing scenarios, and database compaction" — directly justifies our Stage-0 choice of brute-force cosine over HNSW.

8. **AscentCore small-LLM JSON benchmark (Apr 2026)** — https://ascentcore.com/2026/04/01/small-llm-performance-benchmark/ — Best empirical data on which sub-3B models produce reliable structured output. Headline: Qwen 2.5 1.5B Q8_0 hits 95.7% JSON parse rate; SmolLM2 1.7B Q4_K_M collapses at 26.1%; Llama 3.2 3B regresses to 47.8–56.5%.

9. **llama.cpp determinism PR #16016 + embedding GPU/CPU discrepancy threads** — https://github.com/ggml-org/llama.cpp/pull/16016 (Sep 2025, opt-in `GGML_DETERMINISTIC` CUDA mode, "CPU is already deterministic"), https://github.com/ggml-org/llama.cpp/issues/3625 (CPU-only fix for broken embeddings under GPU offload), https://buttondown.com/weekly-project-news/archive/weekly-github-report-for-llamacpp-2024-10-21/ — Hard primary evidence that the embedding determinism story is "CPU-only or bust" for our use case.

10. **USearch (Unum) repo + SQLite extension** — https://github.com/unum-cloud/usearch, https://github.com/unum-cloud/usearch/blob/main/sqlite/README.md — Single-file vector search engine with native Swift, Objective-C, Java, Kotlin, JS, iOS/Android bindings, plus SQLite distance-function loadable extension. Strongest mobile-shaped alternative if naive cosine becomes a bottleneck.

### 2. Per-topic findings

**Task 1 — On-device embedding determinism & cross-platform reproducibility (THE riskiest claim)**

- **Thinking Machines, Sep 2025** — https://thinkingmachines.ai/blog/defeating-nondeterminism-in-llm-inference/ — *Gives us*: canonical statement that batch-size variation is the dominant cause; batch=1 single-stream CPU is the safe regime. *Gap*: blog post, not arxiv; cloud-GPU experiments, not ARM mobile.
- **llama.cpp PR #16016 (Sep 2025)** — https://github.com/ggml-org/llama.cpp/pull/16016 — *Gives us*: maintainer statement "CPU is already deterministic" and the `temperature=0, top_k=1, top_p=1` recipe. *Gap*: scoped to CUDA; no explicit ARM iOS↔Android claim.
- **llama.cpp Issue #2838 (CUDA non-determinism)** — https://github.com/ggml-org/llama.cpp/issues/2838 — *Gives us*: documented evidence GPU offload introduces non-determinism. Establishes the "disable GPU offload for embeddings" rule.
- **llama.cpp Issue #7052 (multi-slot non-determinism)** — https://github.com/ggml-org/llama.cpp/issues/7052 — *Gives us*: parallel batching/multi-slot servers break determinism on a single host, consistent with the batch-invariance thesis. Keep Cactus single-stream.
- **llama.cpp Issue #3625 (embeddings broken under GPU offload)** — https://github.com/ggml-org/llama.cpp/issues/3625 — *Gives us*: user resolution `--n-gpu-layers 0` "fixed my issue with Embeddings." CPU-only is the correct path for the embedding endpoint.
- **Buttondown weekly roll-up (Oct 2024)** — https://buttondown.com/weekly-project-news/archive/weekly-github-report-for-llamacpp-2024-10-21/ — *Gives us*: secondary confirmation "embedding outputs differ between GPU and CPU executions for the same input." *Gap*: roll-up, not original issue.
- **arXiv:2406.10816 (Armv9 / NEON llama.cpp optimization)** — https://arxiv.org/abs/2406.10816 — *Gives us*: documents hand-written NEON intrinsics (`ggml_compute_forward_rms_norm_f32`, `ggml_fp16_to_fp32_row`). Strong INDIRECT evidence: same NEON instructions on iOS-ARM and Android-ARM at batch=1 should yield bit-identical output. *Gap*: no published experiment directly compares iOS↔Android on the same GGUF embedding model.
- **arXiv:2511.17826 ("Deterministic Inference across Tensor Parallel Sizes")** — https://arxiv.org/abs/2511.17826 — *Gives us*: extends batch-invariant operations. *Gap*: multi-GPU TP focus, not mobile.
- **SGLang Issue #10278 (deterministic inference adoption)** — https://github.com/sgl-project/sglang/issues/10278 — *Gives us*: shows the broader community is actively adopting batch-invariant kernels.
- **Cactus primary sources (silence on determinism)** — https://github.com/cactus-compute/cactus, https://huggingface.co/blog/rshemet/cactus-on-device-inference, https://www.infoq.com/news/2025/12/cactus-on-device-inference/ — *Gives us*: confirms `lm.embedding(text, params)` API with `normalize: true`, GGUF backend. *Gap*: **No public statement from the Cactus team confirming or denying bit-identical embeddings across iOS and Android.** Recommend filing a GitHub issue early.

**Adversarial flag:** The combined narrative — batch=1 + CPU-only + single-thread + pinned llama.cpp commit → bit-identical NEON output across iOS and Android — is plausible from the primary evidence but **NOT confirmed by any published experiment**. If bit-equality fails, soft-fallback to cosine ≥ 0.9999 still preserves the CRDT merge (only retrieval ranking would drift).

**Task 2 — CRDT vector indexes / mergeable knowledge stores**

- **DRAG, arXiv:2505.00443** — https://arxiv.org/abs/2505.00443 — *Gives us*: the single closest published prior art to P2P RAG; Topic-Aware Random Walk for peer discovery; near-centralized RAG quality with half the messages of flooding. *Gap*: does NOT treat the index as a CRDT — query traverses network at retrieval time; we sync at insert time and query locally. Our design is genuinely different.
- **DGRAG, arXiv:2505.19847** — https://arxiv.org/abs/2505.19847 — *Gives us*: edge-cloud variant; useful contrast for "no cloud" stance. *Gap*: assumes cloud fallback.
- **Blockchain RAG, arXiv:2511.07577** — https://arxiv.org/abs/2511.07577 — *Gives us*: source-reliability scoring as future-work hook. *Gap*: blockchain dependency.
- **HNSW-merge, arXiv:2505.16064** — https://arxiv.org/abs/2505.16064 — *Gives us*: explicitly frames "merging multiple independently constructed graph indices" as relevant to "distributed systems, incremental indexing scenarios, and database compaction." *Gap*: assumes a central merge coordinator, not P2P.
- **hnswlib Issue #330** — https://github.com/nmslib/hnswlib/issues/330 — *Gives us*: original author Yury Malkov's stance that distributed HNSW build is "feasible." *Gap*: open, unresolved.
- **SHINE, arXiv:2507.17647** — https://arxiv.org/abs/2507.17647 — *Gives us*: distributed HNSW that preserves accuracy via a single global index. *Gap*: RDMA, not mesh.
- **Dolan, "The Only Undoable CRDTs are Counters," arXiv:2006.10494** — https://arxiv.org/abs/2006.10494 — *Gives us*: formal theorem justifying grow-only-set choice. *Gap*: theoretical only.
- **Tschudin, "A Connectionless Grow-Only Set CRDT" (DICG 2022)** — https://dicg-workshop.github.io/2022/papers/tschudin.pdf — *Gives us*: bandwidth-efficient G-Set CRDT for low-power gossip transports (compression-dictionary). Direct analog to what Ditto's BLE protocol is doing. **Very low SEO; CLI agents will miss this.**
- **Riak "Big(ger) Sets," arXiv:1605.06424** — https://arxiv.org/abs/1605.06424 — *Gives us*: hard-won production lessons on CRDT-set growth. *Gap*: 2016, predates embeddings.
- **Willow Protocol family** — https://willowprotocol.org, https://willowprotocol.org/more/willow_compared/index.html, https://github.com/earthstar-project/willow-rs, https://github.com/n0-computer/iroh-willow — *Gives us*: closest "next-generation Earthstar" with fine-grained permissions, prefix deletion, synchronizable stores. *Gap*: no iOS/Android SDK; research bet, not Stage-0.

**Bottom line: nobody has published "CRDT vector index" as a concept.** Closest hits are DRAG (P2P RAG without CRDT) and the May 2025 HNSW-merge paper. Our thesis is genuinely novel territory.

**Task 3 — Mesh sync infrastructure on mobile (Ditto + alternatives)**

- **Ditto SDK Kotlin 5.0 release notes** — https://docs.ditto.live/sdk/latest/release-notes/kotlin — *Gives us*: "Validated with up to 40 concurrent devices across iOS, Android, and budget hardware." *Gap*: marketing language; we'd want the test methodology.
- **Ditto v5 transport config** — https://docs.ditto.live/sdk/v5/sync/customizing-transport-configurations — *Gives us*: `setAvailablePeerToPeerEnabled(true)`; "Ditto can be used in Airplane Mode" with BLE/Wi-Fi manually toggled. Directly addresses our airplane-mode holdout.
- **Ditto FAQ on BLE bandwidth** — https://docs.ditto.live/home/faq — *Gives us*: BLE 5.x ~1.8 Mbps average; BLE 4.x ~20 kB/s; AWDL ~1 GB/8s. At 20 kB/s a 768-dim float32 embedding (~3 kB per tuple) means ~6 tuples/sec over BLE; a 50-tuple corpus is ~8s — fits the demo window.
- **Ditto LAN deployment guide** — https://docs.ditto.live/sdk/latest/deployment/network-deployment — *Gives us*: real ops detail (mDNS frame format `ditto<hashed-app-id>_announce._http-alt._tcp.local`, multicast caveats, 30-clients-per-radio).
- **Apple MultipeerConnectivity docs** — https://developer.apple.com/documentation/multipeerconnectivity — *Gives us*: contrast/justification; iOS↔iOS only (per Apple forum reply: "'multipeer' doesn't mean cross-platform. 'peer' means same kind"). Confirms why a third-party mesh (Ditto) is needed.
- **arXiv:2508.01110 (MultipeerConnectivity latency)** — https://arxiv.org/abs/2508.01110 — *Gives us*: measured 70.4ms mean, p95 < 74ms peer-to-peer over 5 GHz Wi-Fi. **Primary citation for "P2P round-trip beats cloud RTT."**
- **"Breaking Bridgefy," IACR ePrint 2021/214** — https://eprint.iacr.org/2021/214.pdf — *Gives us*: deep dive on the most famous iOS↔Android BLE-only consumer mesh; cautionary tale; documents Hong Kong, India, Iran, US, Zimbabwe, Belarus deployments. *Gap*: security flaws inform our "trust Ditto's CRDT" framing.
- **Iroh** — https://www.iroh.computer, https://github.com/n0-computer/iroh — *Gives us*: modern Rust QUIC-based P2P; mobile via `iroh-ffi`. Strongest "we could have used X" alternative. *Gap*: not BLE-native; requires IP.
- **Earthstar + Willow + iroh-willow** — https://nlnet.nl/project/Earthstar/interview.html, https://opencollective.com/earthstar (LAN sync via DNS-SD in v10.2.0) — *Gives us*: prior art for LAN-based personal-data CRDT sync. *Gap*: TypeScript primary impl; no mobile shipping story.
- **BLE mesh background, arXiv:1910.03345, arXiv:2208.04050** — *Gives us*: reliability/flooding-vs-multi-path tradeoffs. *Gap*: IoT focus.

**Task 4 — On-device LLM frameworks + small-LLM ecosystem + structured-list aggregation**

- **Cactus InfoQ launch coverage (Dec 2025)** — https://www.infoq.com/news/2025/12/cactus-on-device-inference/ — *Gives us*: "sub-50ms time-to-first-token" claim; catalog (Qwen3-0.6B=394MB, Gemma-3-1b-it=642MB, Qwen3-1.7B=1,161MB). *Gap*: vendor-supplied.
- **Cactus Kotlin SDK** — https://github.com/cactus-compute/cactus-kotlin, https://cactuscompute.com/docs/kotlin — *Gives us*: bundled defaults `qwen3-0.6` and `gemma3-270m`; embedding methods on `CactusLM`; KMP iOS path. **Most actionable doc for our build.**
- **Cactus Flutter SDK with `CactusRAG`** — https://github.com/cactus-compute/cactus-flutter — *Gives us*: critical detail — Cactus already ships ObjectBox + HNSW (squared Euclidean) on-device RAG. **Sharpens our thesis: we add the CRDT, not the RAG.**
- **AscentCore small-LLM JSON benchmark (Apr 2026)** — https://ascentcore.com/2026/04/01/small-llm-performance-benchmark/ — *Gives us*: hardest empirical data on structured output at sub-3B: Qwen 2.5 1.5B Q8_0 = 95.7% JSON parse; SmolLM2 1.7B Q4_K_M = 26.1%; Llama 3.2 3B = 47.8–56.5%. **Pre-screens our LLM toward Qwen 2.5 1.5B Q8_0.**
- **PromptQuorum 2026 mobile LLM aggregator** — https://www.promptquorum.com/power-local-llm/mobile-llm-models-phi4-gemma-smollm — *Gives us*: iPhone 17 Pro: Gemma 3 1B ~35–45 t/s, SmolLM 2 1.7B ~26–32 t/s, Phi-4 Mini ~13–18 t/s. The Cactus blog's "70+ tok/sec" claim for Qwen3-600m on flagship devices remains vendor-only and is not corroborated by independent measurement. *Gap*: secondary aggregator.
- **MobileAIBench, arXiv:2406.10290 (Salesforce, 2024)** — https://arxiv.org/abs/2406.10290 — *Gives us*: open-source iOS framework for on-device LLM latency/hardware measurement. *Gap*: pre-dates Gemma 3, Phi-4.
- **SlimLM, arXiv:2411.09944 (Adobe, Nov 2024)** — https://arxiv.org/abs/2411.09944 — *Gives us*: hard Samsung S24 measurements 125M–7B. *Gap*: doc tasks, not list reconciliation.
- **MobileLLM, arXiv:2402.14905** — https://arxiv.org/abs/2402.14905 — *Gives us*: depth > width for sub-1B; architectural background. *Gap*: doesn't ship a usable model.
- **"Challenging GPU Dominance," arXiv:2505.06461** — https://arxiv.org/abs/2505.06461 — *Gives us*: explicit defense of CPU-only mobile inference. Useful citation for "we deliberately disable NPU/GPU for determinism."
- **Recipe-domain LLM prior art** — https://arxiv.org/abs/2412.04922 ("LLMs for Ingredient Substitution," Dec 2024) and https://arxiv.org/abs/2507.17232 (2025) — *Gives us*: Mistral-7B + DPO is current SOTA on Recipe1MSub (Hit@1 = 22.04); even Qwen-2.5-VL-72B struggles with ingredient subtraction. *Implication*: don't promise the audience perfect reconciliation — frame as "synthesis-by-vibes."

**Licensing landmines (called out explicitly):**
- **Llama 3.2 community license** — restricts redistribution to companies under 700M MAU, requires "Built with Llama" attribution, prohibits using outputs to train other LLMs. **Risk for public hackathon repo.**
- **Gemma terms of use** — Google's "Gemma Prohibited Use Policy" applies; redistribution requires linking. Less restrictive. **Acceptable.**
- **Qwen 2.5 1.5B is Apache-2.0** — cleanest license. Combined with AscentCore JSON data, **Qwen 2.5 1.5B Q8_0 is the recommended on-device LLM.**

**Task 5 — On-device embedding models + vector search**

- **EmbeddingGemma 300M** — https://huggingface.co/google/embeddinggemma-300m, https://huggingface.co/litert-community/embeddinggemma-300m, https://ai.google.dev/gemma/docs/embeddinggemma/model_card — *Gives us*: 300M params, Matryoshka 768→128, 22ms EdgeTPU, ~200MB RAM quantized; LiteRT variants explicitly for iOS+Android. Unsloth GGUF at https://huggingface.co/unsloth/embeddinggemma-300m-GGUF for Cactus loading.
- **Cactus official catalog** — https://huggingface.co/Cactus-Compute — *Gives us*: ground truth on pre-converted weights. *Gap*: evolves; check at build time.
- **Sentence-Embeddings-Android (Shubham Panchal)** — https://discuss.huggingface.co/t/on-device-sentence-embeddings-with-all-minilm-l6-v2-in-android/94841 — *Gives us*: working open-source Android demo of all-MiniLM-L6-v2 via ONNX Runtime, 112MB total app size. Strong reference architecture.
- **USearch** — https://github.com/unum-cloud/usearch — *Gives us*: single-file C++ HNSW with Swift, Objective-C, Java, Kotlin, JS, iOS/Android, WASM bindings; uint40_t neighbor refs; SimSIMD kernels. **Apache-2.0** drop-in if naive cosine becomes a bottleneck.
- **USearch SQLite extension** — https://github.com/unum-cloud/usearch/blob/main/sqlite/README.md — *Gives us*: SIMD distance functions as loadable SQLite functions. *Gap*: Cactus Flutter uses ObjectBox; switching means changing the storage layer.
- **Recall, arXiv:2409.15342** — https://arxiv.org/abs/2409.15342 — *Gives us*: rare published paper on multimodal embedding for resource-limited mobile. *Gap*: research code only.

**Task 6 — Local-first AI prior art (writeup framing)**

- **Kleppmann 2019 essay** — https://martin.kleppmann.com/papers/local-first.pdf — Canonical. Already in our baseline.
- **Kleppmann, Local-First Conf 2024 talk** — https://martin.kleppmann.com/2024/05/30/local-first-conference.html, https://speakerdeck.com/ept/the-past-present-and-future-of-local-first — *Gives us*: proposed interim definition "in local-first software, the availability of another computer should never prevent you from working" — clean opener for our writeup. Also: "the benefits to the app developer are perhaps at least as big as those to the end-user."
- **PowerSync "Origins and Evolution"** — https://powersync.com/blog/local-first-software-origins-and-evolution — *Gives us*: rare aggregator citing Tuomas Artman (Linear): "The benefits of going local-first as an engineer are so humongous that I wouldn't want to waste my time handling network errors and making network calls."
- **Local-First Conf 2024 recap (Evil Martians)** — https://evilmartians.com/chronicles/recapping-the-first-local-first-conference-in-15-minutes — *Gives us*: documents DXOS, Jazz, Automerge, Linear sync engine talks; "Server independence" amendment. *Gap*: recap.
- **Alex Good (Automerge), "Local First – Software that still works after the Acquihire," QCon London** — https://www.infoq.com/presentations/local-first-build-software/ — *Gives us*: "You don't even have to use a server, you can run synchronization between two of your own machines if you're really in a pinch." **Best conference-video framing we found.**
- **SE Radio episode #716 with Kleppmann (April 2026)** — https://se-radio.net/2026/04/se-radio-716-martin-kleppmann-local-first-software/ — *Gives us*: most recent Kleppmann conversation; includes AI-via-CRDTs discussion.

**Task 7 — Latency floors and "the network round-trip is the moat"**

- **Salt Technologies AI Vector Database Benchmark 2026 (CC BY 4.0, updated 2026-02-15, 1M vectors / 1536-dim)** — https://www.salttechno.ai/datasets/vector-database-performance-benchmark-2026/ — "Qdrant delivers the lowest p50 latency at 4ms among purpose-built vector databases"; Pinecone at 8 ms p50. **These are server-side query latencies only — no network RTT included.**
- **Vector DB landscape (Firecrawl, Inductivee, Airbyte 2026)** — https://www.firecrawl.dev/blog/best-vector-databases, https://inductivee.com/blog/vector-database-performance-benchmarks-2025, https://airbyte.com/data-engineering-resources/qdrant-vs-pinecone — *Gives us*: managed-cloud p50/p99 query latency consistently 4–25ms p50, 12–35ms p99 at 1M–100M vectors. Pinecone Serverless and Qdrant 1.10 are the leaders. *Gap*: secondary aggregators; the 18.4ms/22.1ms p99 specifics for 100M vectors are aggregator-cited, not in the Salt benchmark dataset; treat as approximate.
- **Turbopuffer cold-query latency (daily.dev compilation)** — https://app.daily.dev/posts/pgvector-vs-pinecone-vs-turbopuffer-vs-qdrant-2026--m1dot7ras — Turbopuffer cold-query 300–800ms (object-storage backend). *Gap*: secondary source.
- **Kunal Ganglani's 5-model TTFT benchmark (Mar 2026, updated May 10 2026)** — Cited in our enrichment: "fastest tested was Claude Haiku 4.5 at 639 ms TTFT on short prompts (p95: 742 ms); GPT-4.1 Mini hit 2,205 ms TTFT (p95: 4,004 ms) on identical prompts — 'Four seconds to see the first token in a worst case. In a chatbot, that's brutal.'" Primary anchor for cloud-LLM TTFT.
- **arXiv:2508.01110 (MultipeerConnectivity P2P latency)** — https://arxiv.org/abs/2508.01110 — 70.4ms mean, p95 < 74ms over 5 GHz Wi-Fi. **Direct primary measurement: on-device P2P round-trip is well under cloud RTT.**
- **Cactus benchmarks** — https://huggingface.co/blog/rshemet/cactus-on-device-inference — "sub-50ms time-to-first-token" claimed for Qwen3-0.6B. The PromptQuorum 2026 aggregator gives independent figures (iPhone 17 Pro: Gemma 3 1B 35–45 t/s, SmolLM2 1.7B 26–32 t/s); the "70+ tok/sec" figure for Qwen3-600m on flagships remains vendor-only and unverified.
- **HNSW-merge paper (already cited)** — at our 5k-tuple scale, brute-force cosine is faster than building/rebuilding HNSW after every sync.

**The Moat Argument (synthesized):** Cloud vector DB p50 query is 4–8ms (Salt 2026). Add mobile→cloud RTT (typically 30–150ms one-way) plus cloud LLM TTFT (639ms p50 best case per Ganglani; up to 4s p95 worst case). Cloud RAG end-to-end p99 is comfortably ~700ms–4s before any tokens stream. On-device P2P RAG removes RTT entirely; TTFT compresses to Cactus's claimed 50ms (vendor) or a more realistic 100–300ms based on PromptQuorum measurements; brute-force cosine over 5k tuples is ~5ms. **The cloud floor is bounded by c (speed of light) and queueing; the on-device floor is bounded only by silicon.**

**Task 8 — Demo aesthetics & presentation tooling**

- **Presenterm** — https://github.com/mfontanini/presenterm — **MIT-licensed**, 8,400 stars / 186 forks per the releases page as of May 2026, active master, themes, images, code highlighting, LaTeX, PDF/HTML export. Used by Orhun Parmaksız (Ratatui maintainer) in several recent talks (visible from README). **Recommended for our writeup deck.** Exemplars at https://github.com/mfontanini/presenterm/tree/master/examples.
- **Ink & Switch "Local-first software" essay (canonical demo-opener quote)** — https://www.inkandswitch.com/local-first/ — "Local-first software is different: because it keeps the primary copy of the data on the local device, there is never a need for the user to wait for a request to a server to complete."
- **Bridgefy origin + Breaking Bridgefy** — https://www.alchemistaccelerator.com/blog/bridgefy-the-offline-messaging-app-revolutionizing-crisis-communication-worldwide ("500,000 Hong Kong residents downloaded Bridgefy, transforming it from a useful tool into a key communication channel"), https://eprint.iacr.org/2021/214.pdf — Demo-narrative anchors. The IACR paper's security flaws are a counter to naive "BLE mesh is magic."
- **Local-First Conf 2024 playlist + Alex Good QCon talk** (cited above) — Best conference-video anchors for the demo aesthetic.

### 3. Tool shortlist (concrete decisions)

| Layer | Decision | Candidate / Repo | Last release | License | Mobile support | Use it / don't / maybe |
|---|---|---|---|---|---|---|
| **On-device embedding model** | **Use:** EmbeddingGemma 300M (GGUF via Cactus), all-MiniLM-L6-v2 as fallback | https://huggingface.co/litert-community/embeddinggemma-300m; https://huggingface.co/unsloth/embeddinggemma-300m-GGUF; fallback https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2 | EmbeddingGemma 2025 | Gemma Terms of Use; MIT for MiniLM | iOS, Android, EdgeTPU | **Use** EmbeddingGemma if Cactus loads the GGUF cleanly; else MiniLM via ONNX Runtime Mobile. Pin a single quantization (FP16 preferred for determinism). |
| **On-device LLM** | **Use:** Qwen 2.5 1.5B Q8_0 via Cactus | https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct (Apache-2.0); GGUF builds under https://huggingface.co/Cactus-Compute | Sep 2024 base | Apache-2.0 | iOS + Android via Cactus | **Use.** Best documented JSON parse rate at sub-2B (AscentCore Apr 2026: 95.7%), cleanest license. Don't use Llama 3.2 3B (license + JSON regression) or SmolLM2 1.7B (JSON collapse at Q4). |
| **On-device vector search** | **Use:** brute-force cosine over float32 array; pre-shortlist USearch as fallback | N/A for naive; https://github.com/unum-cloud/usearch as fallback | USearch active master | Apache-2.0 | iOS, Android, WASM | **Use naive top-k.** Combined corpus ≤5000 tuples × 768 dims = ~15MB; brute-force cosine ~5ms on mid-range phone. HNSW-over-CRDT is unsolved per arXiv:2505.16064. |
| **Mesh sync** | **Use:** Ditto v5 with BLE + LAN, `setAvailablePeerToPeerEnabled(true)`, no websocket URL | https://docs.ditto.live, https://github.com/getditto | Ditto 5.0 GA | Commercial (free dev tier) | iOS, Android, RN, Flutter, Kotlin | **Use.** Already chosen; docs confirm airplane-mode + BLE works as our holdout demands. |
| **On-device runtime** | **Use:** Cactus Kotlin Multiplatform 1.4.x | https://github.com/cactus-compute/cactus-kotlin | 1.4.1-beta active | Source-available (free for hobbyists/SMB) | iOS 12+, Android API 24+ | **Use.** KMP path lets us ship one codebase to both platforms. Disable telemetry: `CactusConfig.isTelemetryEnabled = false`. |
| **Slide deck** | **Use:** Presenterm | https://github.com/mfontanini/presenterm | active master | MIT | N/A | **Use.** 8,400 stars, Markdown-native, asciinema-friendly, Ratatui-ecosystem credentials. |

### 4. Reference architectures (mimic / steal from)

1. **Cactus Flutter `CactusRAG`** — https://github.com/cactus-compute/cactus-flutter — Already implements text chunking + ObjectBox HNSW + cosine search + on-device embedding via `CactusLM`. **Copy:** the chunking / embedding / search pipeline shape; **replace:** ObjectBox storage with a Ditto collection so tuples are CRDT-synced.
2. **DRAG reference impl** — https://github.com/xuchenhao001/DRAG — Topic-Aware Random Walk + per-peer cache. **Copy:** the "each peer holds local KB" mental model — but invert it: in our design the *index* traverses (via Ditto sync), not the query.
3. **Sentence-Embeddings-Android (Shubham Panchal)** — https://discuss.huggingface.co/t/on-device-sentence-embeddings-with-all-minilm-l6-v2-in-android/94841 — Working Android library wrapping MiniLM via ONNX Runtime. **Copy:** the Kotlin embedding wrapper pattern as a fallback if Cactus misbehaves on Android NPUs.
4. **Ditto getditto/quickstart, getditto/demoapp-chat** — https://github.com/getditto — Canonical two-device chat demo with airplane-mode flow. **Copy:** the airplane-mode toggling logic and BLE-permission handling boilerplate. Replace chat messages with recipe tuples.
5. **iroh-willow** — https://github.com/n0-computer/iroh-willow — Most modern P2P sync research codebase. **Copy:** nothing for Stage-0; **study** as future-work direction if we ever want off Ditto's commercial SDK.

### 5. Open research questions (genuine gaps)

1. **No empirical confirmation of iOS↔Android bit-identical embeddings under Cactus/GGUF/llama.cpp on CPU.** Mandatory hackathon week-1 task: 20-line determinism test.
2. **No published work treats a vector embedding store as a CRDT.** DRAG and HNSW-merge are the closest, neither is our design.
3. **No benchmark of 1–3B LLMs on structured-list reconciliation** (ingredient deduplication, quantity normalization). AscentCore covers JSON parse rate; Recipe1MSub only tests 7B+. We will construct an ad-hoc internal eval.
4. **No mobile-shaped library for CRDT-coordinated HNSW** if we outgrow brute-force cosine. arXiv:2505.16064 has the algorithms but no library.
5. **No public Cactus team statement on determinism.** File a GitHub issue.
6. **No primary measurement of Ditto end-to-end BLE convergence time** for our corpus shape (~50 tuples × ~3 kB each). Docs give throughput, not convergence-to-quiescence.
7. **No iOS-via-KMP shipped open-source RAG app** to copy from. The Cactus Kotlin Multiplatform path is documented; example apps target Android primarily.

## Recommendations

**Stage-0 build sequence (in this order — each step has a stop-go gate):**

1. **Week 1 — Determinism smoke test (the single most important experiment):** On both iOS and Android, embed the strings `["hello world", "tomato basil pasta", "preheat oven to 350"]` via Cactus + the same GGUF embedding model + batch=1 + CPU-only + threads=1. Serialize both vectors as JSON, exchange via AirDrop, and `assert numpy.array_equal`. If equal → proceed; if cosine ≥ 0.99999 → soft success, document the discrepancy in the writeup; if cosine < 0.999 → switch to ONNX Runtime Mobile + MiniLM (Shubham Panchal's pattern) which gives more determinism control. **Threshold that changes plans: cosine < 0.999 on any test pair.**

2. **Week 1 — File a public GitHub issue on cactus-compute/cactus titled "Cross-device embedding determinism: is `lm.embedding(text)` bit-identical between iOS and Android for the same GGUF model and quantization?"** Either you get a definitive answer that strengthens the writeup, or you get silence that becomes part of the "what we learned" section.

3. **Week 2 — Ditto + Cactus integration with naive top-k cosine:** start from `getditto/quickstart` template; replace chat messages with `RecipeTuple` schema; embed via `CactusLM.embedding(...)`; query path is `embed(query) → cosine over local Ditto collection → top-k → Cactus LM with retrieved context`. Use **Qwen 2.5 1.5B Q8_0** for the LLM. **Threshold that changes plans: if cold-load > 10s on the slowest target device, swap to Qwen3-0.6B or Gemma 3 270M.**

4. **Week 2 — Airplane-mode + BLE convergence test:** measure time-from-discovery-to-quiescent-merge for a 50-tuple corpus. **Threshold: if convergence > 30s, slim the embedding to 384 dims (EmbeddingGemma Matryoshka truncation) which halves BLE bytes.**

5. **Week 3 — Structured-merge prompt engineering:** because Qwen 2.5 1.5B cannot be trusted to perfectly normalize recipes (per arXiv:2412.04922), constrain the LLM with a JSON schema and treat "merge ingredients" as deduplication-then-format rather than free-form synthesis. Cite the Recipe1MSub paper in the writeup to ground audience expectations.

6. **Week 3 — Presenterm deck + Loom video of the airplane-mode moment.** Open with the Ink & Switch quote and the Kleppmann 2024 reframe ("the availability of another computer should never prevent you from working"). Close with the Alex Good QCon quote ("two of your own machines if you're really in a pinch").

7. **DON'T DO:** (a) HNSW over the synced corpus before Stage 0 ships — arXiv:2505.16064 makes it clear this is unsolved at the algorithmic level; (b) any GPU/Metal/NNAPI offload for embeddings — issue #3625 is hard evidence this breaks them; (c) Llama 3.2 anything in the public repo — license is incompatible with a hackathon writeup and the JSON quality is worse than Qwen 2.5 1.5B anyway; (d) cost framing in the writeup — the thesis is latency + offline.

**Writeup-thesis sharpening:** the single most important framing change suggested by the research is that **we are not inventing on-device RAG (Cactus Flutter's `CactusRAG` already does it). We are inventing the CRDT-merged on-device RAG** — the part where two devices coming into BLE range causes the *index itself* to converge, with no central coordinator. The novelty is the merge, not the retrieval.

## Caveats

- **The "cosine ≥ 0.999 across iOS and Android" holdout is plausible but unverified by any published primary source.** Treat it as the highest-risk technical claim in the project. Multiple sources (Thinking Machines, llama.cpp PR #16016, arXiv:2406.10816) make the hypothesis credible; none confirm it experimentally for our exact stack.
- **All Cactus-supplied benchmarks ("sub-50ms TTFT," "70+ tok/sec on iPhone 17") are vendor-supplied and unverified.** The PromptQuorum 2026 figures (Gemma 3 1B at 35–45 t/s on iPhone 17 Pro) are the closest independent measurement and are roughly half the Cactus claim. Plan for the more conservative number.
- **The May 2025 P2P-RAG papers (DRAG, DGRAG) are recent enough to be unstable;** code repos may have bugs, the framing may shift. Treat them as adjacent prior art to cite, not foundations to depend on.
- **Ditto is a commercial SDK.** Free dev tier is sufficient for hackathon, but a hard rebuild on Iroh/Earthstar/Willow is a real future-work item if commercial dependency becomes problematic. Iroh-willow is the closest open-source replacement, but no production mobile SDK yet.
- **The AscentCore Apr 2026 JSON benchmark is an aggregator, not a peer-reviewed source.** Its numbers are the best public data we have on sub-3B structured output, but they should be re-validated with our own ingredient-list eval before being cited in the final writeup.
- **Earthstar/Willow + iroh-willow are research-stage**, not shipping mobile libraries — useful for future-work framing only.
- **"Big" CRDT sets degrade in production** (Riak Big(ger) Sets arXiv:1605.06424 documents this); at Stage 0 our corpus is small (≤5000 tuples) so this doesn't bite, but the writeup should note that Stage N (1M+ tuples) would need delta-CRDTs.

## 6. Source ledger

https://github.com/cactus-compute/cactus
https://github.com/cactus-compute/cactus-kotlin
https://github.com/cactus-compute/cactus-flutter
https://cactuscompute.com
https://cactuscompute.com/docs/v1.7
https://cactuscompute.com/docs/kotlin
https://huggingface.co/Cactus-Compute
https://huggingface.co/blog/rshemet/cactus-on-device-inference
https://www.ycombinator.com/companies/cactus
https://www.infoq.com/news/2025/12/cactus-on-device-inference/
https://docs.ditto.live
https://docs.ditto.live/home/faq
https://docs.ditto.live/sdk/latest/release-notes/kotlin
https://docs.ditto.live/sdk/latest/release-notes/java
https://docs.ditto.live/sdk/v5/sync/customizing-transport-configurations
https://docs.ditto.live/sdk/latest/install-guides/react-native
https://docs.ditto.live/sdk/latest/deployment/network-deployment
https://docs.ditto.live/v4-5/faq
https://resources.ditto.live/developers
https://github.com/getditto
https://thinkingmachines.ai/blog/defeating-nondeterminism-in-llm-inference/
https://github.com/ggml-org/llama.cpp/pull/16016
https://github.com/ggml-org/llama.cpp/issues/2838
https://github.com/ggml-org/llama.cpp/issues/3625
https://github.com/ggml-org/llama.cpp/issues/7052
https://github.com/ggml-org/llama.cpp/discussions/2658
https://github.com/ggml-org/llama.cpp/issues/22926
https://buttondown.com/weekly-project-news/archive/weekly-github-report-for-llamacpp-2024-10-21/
https://arxiv.org/abs/2406.10816
https://arxiv.org/abs/2511.17826
https://github.com/sgl-project/sglang/issues/10278
https://arxiv.org/abs/2505.00443
https://arxiv.org/abs/2505.19847
https://arxiv.org/abs/2511.07577
https://github.com/xuchenhao001/DRAG
https://arxiv.org/abs/2505.16064
https://arxiv.org/abs/2507.17647
https://github.com/nmslib/hnswlib/issues/330
https://arxiv.org/abs/2006.10494
https://arxiv.org/abs/1605.06424
https://dicg-workshop.github.io/2022/papers/tschudin.pdf
https://willowprotocol.org
https://willowprotocol.org/more/willow_compared/index.html
https://github.com/earthstar-project/willow-rs
https://github.com/n0-computer/iroh
https://github.com/n0-computer/iroh-willow
https://www.iroh.computer
https://nlnet.nl/project/Earthstar/interview.html
https://opencollective.com/earthstar
https://developer.apple.com/documentation/multipeerconnectivity
https://arxiv.org/abs/2508.01110
https://eprint.iacr.org/2021/214.pdf
https://www.alchemistaccelerator.com/blog/bridgefy-the-offline-messaging-app-revolutionizing-crisis-communication-worldwide
https://arxiv.org/abs/1910.03345
https://arxiv.org/abs/2208.04050
https://huggingface.co/google/embeddinggemma-300m
https://huggingface.co/litert-community/embeddinggemma-300m
https://huggingface.co/unsloth/embeddinggemma-300m-GGUF
https://ai.google.dev/gemma/docs/embeddinggemma/model_card
https://ollama.com/library/embeddinggemma
https://discuss.huggingface.co/t/on-device-sentence-embeddings-with-all-minilm-l6-v2-in-android/94841
https://github.com/unum-cloud/usearch
https://github.com/unum-cloud/usearch/blob/main/sqlite/README.md
https://github.com/unum-cloud/usearch-benchmarks
https://arxiv.org/abs/2406.10290
https://arxiv.org/abs/2411.09944
https://arxiv.org/abs/2402.14905
https://arxiv.org/abs/2505.06461
https://arxiv.org/abs/2404.14219
https://arxiv.org/abs/2409.15342
https://arxiv.org/abs/2408.01800
https://arxiv.org/abs/2412.04922
https://arxiv.org/abs/2507.17232
https://arxiv.org/abs/2302.01005
https://ascentcore.com/2026/04/01/small-llm-performance-benchmark/
https://www.promptquorum.com/power-local-llm/mobile-llm-models-phi4-gemma-smollm
https://gorilla.cs.berkeley.edu/leaderboard.html
https://martin.kleppmann.com/papers/local-first.pdf
https://martin.kleppmann.com/2024/05/30/local-first-conference.html
https://martin.kleppmann.com/2024/02/27/local-first-meetup.html
https://martin.kleppmann.com/2026/02/24/local-first-meetup.html
https://speakerdeck.com/ept/the-past-present-and-future-of-local-first
https://www.inkandswitch.com/local-first/
https://www.infoq.com/presentations/local-first-build-software/
https://powersync.com/blog/local-first-software-origins-and-evolution
https://evilmartians.com/chronicles/recapping-the-first-local-first-conference-in-15-minutes
https://se-radio.net/2026/04/se-radio-716-martin-kleppmann-local-first-software/
https://medium.com/google-developer-experts/embedding-gemma-running-on-device-20b0c9aeac30
https://medium.com/google-developer-experts/develop-an-on-device-rag-system-powered-by-gemma-models-f7cdb7bca221
https://www.bentoml.com/blog/a-guide-to-open-source-embedding-models
https://app.daily.dev/posts/pgvector-vs-pinecone-vs-turbopuffer-vs-qdrant-2026--m1dot7ras
https://www.firecrawl.dev/blog/best-vector-databases
https://www.salttechno.ai/datasets/vector-database-performance-benchmark-2026/
https://inductivee.com/blog/vector-database-performance-benchmarks-2025
https://airbyte.com/data-engineering-resources/qdrant-vs-pinecone
https://github.com/mfontanini/presenterm

## 7. What the CLI agents would have missed

1. **Cactus Flutter SDK already ships `CactusRAG` (HNSW + ObjectBox + chunking + cosine)** — buried in the SDK README, not on cactuscompute.com's marketing pages. First-pass agents land on the homepage and miss it. This finding sharpens our whole thesis.
2. **Cactus team's public silence on cross-device embedding determinism** — an absence across GitHub issues, Discord, HF blog, YC profile. CLI agents won't surface absences.
3. **llama.cpp embedding-specific (not text-generation) GPU/CPU divergence** — issue #3625 + the Oct 2024 buttondown roll-up. Most "is llama.cpp deterministic?" hits cover generation, not embeddings.
4. **Tschudin "Connectionless Grow-Only Set CRDT" (DICG 2022)** — workshop paper on a GitHub Pages domain with near-zero SEO; closest primary source to what Ditto is doing at the BLE wire level.
5. **"Three Algorithms for Merging HNSW Graphs," arXiv:2505.16064** — only six months old, niche topic, unlikely to surface in a generic vector-index-CRDT query.
6. **Cactus Kotlin Multiplatform iOS-via-KMP path** — buried in the Kotlin SDK README; an architecture path CLI agents won't propose unprompted.
7. **arXiv:2406.10816 ARMv9 / NEON llama.cpp optimization paper** — Chinese-authored preprint with low English-SEO; documents the exact NEON intrinsics that make iOS↔Android bit-equality plausible.
8. **AscentCore Apr 2026 small-LLM JSON benchmark** — niche aggregator, but the only published number disqualifying SmolLM2 at Q4 for structured output (26.1%).
9. **arXiv:2508.01110 (MultipeerConnectivity P2P latency, Aug 2025)** — Aug 2025 paper with precise p50 70.4ms / p95 < 74ms numbers; niche topic, hard to find without targeted search.
10. **Earthstar LAN sync via DNS-SD in v10.2.0** — Open Collective update by Nick Mosher (Mar 2025), not press-covered, but proves prior art for "sync without internet" in a CRDT-shaped stack.