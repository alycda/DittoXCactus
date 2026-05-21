# Cross-references — directed graph view

> Reads the `## Cross-references` section of every per-source file (281 files, 541 edges) and reorganizes them as a directed graph. Format: `source-A → target (context)`. Sources without cross-references are omitted. The "most-cited" list at the bottom surfaces the foundational sources — the ones the rest of the corpus points at.

**Edges:** 541. **Sources with outgoing edges:** 230. **Distinct targets referenced:** 236.

## Outgoing edges by source

### [article-deepsense-blog-implementing-small-language-models-slms-with-rag-on-emb](_per_source/article-deepsense-blog-implementing-small-language-models-slms-with-rag-on-emb.md) (density 5)

- → `article-blog-swmansion-introducing-react-native-rag-fbb62efa4991` [d4] — RN equivalent reference arch
- → `article-blog-swmansion-building-an-ai-powered-note-taking-app-in-react-native-pa` [d4] — RN note-taking RAG
- → `paper-2507.01079` [d5] — MobileRAG — published academic version of this idea
- → `paper-1106.4374` [d5] — CRDT foundation we layer on top

### [article-dev-to-biozal-transport-multiplexing-in-mobile-sync-why-multi-trans](_per_source/article-dev-to-biozal-transport-multiplexing-in-mobile-sync-why-multi-trans.md) (density 5)

- → `article-ditto-blog-getting-started-with-bluetooth-file-sync` [d4] — Ditto's primary BLE write-up
- → `docs-docs-ditto-live-transports` [d5] — Ditto transport overview docs
- → `docs-mesh-networking-101` [d1] — Ditto mesh fundamentals
- → `paper-1106.4374` [d5] — CRDT layer that makes multi-transport coherent

### [article-ditto-blog-dittos-delta-state-crdts](_per_source/article-ditto-blog-dittos-delta-state-crdts.md) (density 5)

- → `paper-1106.4374` [d5] — foundational CRDT theory
- → `article-ditto-blog-how-to-build-robust-offline-first-apps` *(external or unknown)* — application-level framing of the same CRDT model
- → `article-powersync-blog-ditto-vs-powersync` [d4] — independent description of the same architecture
- → `docs-docs-ditto-live` [d5] — Ditto SDK reference

### [article-thinkingmachines-blog-defeating-nondeterminism-in-llm-inference](_per_source/article-thinkingmachines-blog-defeating-nondeterminism-in-llm-inference.md) (density 5)

- → `article-lmsys-blog-2025-09-22-sglang-deterministic` [d4] — engineering writeup integrating these kernels into SGLang
- → `paper-2506.09501` [d3] — cross-hardware FP determinism quantification
- → `docs-docs-ditto-live` [d5] — Ditto-side spec; determinism matters because embeddings sync as opaque vectors

### [docs-ai-google-gemma-docs-embeddinggemma-model-card](_per_source/docs-ai-google-gemma-docs-embeddinggemma-model-card.md) (density 5)

- → `paper-2509.20354` [d4] — EmbeddingGemma paper
- → `paper-2402.01613` [d4] — Nomic Embed v1.5
- → `docs-cactuscompute-docs-v1-7-rag` [d4]
- → `docs-ai-google-gemma-docs-core-model-card-3` [d4]

### [docs-cactuscompute-docs-v1-7](_per_source/docs-cactuscompute-docs-v1-7.md) (density 5)

- → `docs-cactuscompute-docs-v1-7-rag` [d4]
- → `github-cactus-compute-cactus` *(external or unknown)*
- → `docs-developer-apple-documentation-foundationmodels` [d4]
- → `docs-docs-ditto-live-home-about-ditto` [d4]

### [docs-ditto-live](_per_source/docs-ditto-live.md) (density 5)

- → `repo-getditto-demoapp-inventory` [d5] — practical implementation reference
- → `paper-2506.09501` [d3] — CRDT theory applicable to vector indices

### [docs-docs-ditto-live-key-concepts-mesh-networking](_per_source/docs-docs-ditto-live-key-concepts-mesh-networking.md) (density 5)

- → `docs-docs-ditto-live-home-about-ditto` [d4]
- → `docs-developer-apple-documentation-multipeerconnectivity` [d3]
- → `docs-docs-ditto-live-home-faq` [d2]

### [docs-docs-ditto-live-key-concepts-syncing-data](_per_source/docs-docs-ditto-live-key-concepts-syncing-data.md) (density 5)

- → `docs-docs-ditto-live-sdk-v4-8-sync-concepts-transports-overview` [d5] — how this gets carried over BLE/LAN
- → `docs-docs-ditto-live-dql` [d5] — the query language used in subscriptions
- → `paper-1106.4374` [d5] — the CRDT theory under this
- → `ditto-delta-state-crdts` *(external or unknown)* — blog (deeper engineering writeup)

### [docs-docs-ditto-live-sdk-v4-8-sync-concepts-transports-overview](_per_source/docs-docs-ditto-live-sdk-v4-8-sync-concepts-transports-overview.md) (density 5)

- → `docs-docs-ditto-live-key-concepts-syncing-data` [d5] — what flows over these transports
- → `docs-docs-ditto-live-sdk-v5-sync-customizing-transport-configurations` [d5] — how to configure them
- → `docs-docs-ditto-live-sdk-latest-deployment-network-deployment` [d4] — network-layer details
- → `docs-mesh-networking-101` [d1] — introductory companion

### [docs-docs-ditto-live-sdk-v5-sync-customizing-transport-configurations](_per_source/docs-docs-ditto-live-sdk-v5-sync-customizing-transport-configurations.md) (density 5)

- → `docs-docs-ditto-live-sdk-v4-8-sync-concepts-transports-overview` [d5] — the concepts under this API
- → `docs-docs-ditto-live-key-concepts-syncing-data` [d5] — what's flowing over the configured transports
- → `docs-docs-ditto-live-sdk-latest-release-notes-kotlin` [d3] — v5 release context

### [hf-Qwen-Qwen2.5-1.5B-Instruct](_per_source/hf-Qwen-Qwen2.5-1.5B-Instruct.md) (density 5)

- → `hf-Qwen-Qwen3-1.7B` [d3] — next-gen successor, larger context
- → `hf-Qwen-Qwen3-Embedding-0.6B` [d4] — sibling embedding model from same family
- → `hf-google-gemma-2-2b-it` [d4] — competing small-LLM card with Gemma terms friction
- → `hf-meta-llama-Llama-3.2-1B-Instruct` [d3] — competing card with Community License friction

### [hf-blog-rshemet-cactus-on-device-inference](_per_source/hf-blog-rshemet-cactus-on-device-inference.md) (density 5)

- → `docs-cactus-engine` *(external or unknown)* — Cactus engine reference docs — primary technical complement
- → `paper-2402.01613` [d4] — Nomic Embed, packaged by Cactus
- → `paper-2509.20354` [d4] — EmbeddingGemma — small embed, likely a Cactus catalog target

### [hf-google-embeddinggemma-300m](_per_source/hf-google-embeddinggemma-300m.md) (density 5)

- → `hf-litert-community-embeddinggemma-300m` [d2] — LiteRT-quantized variant for mobile
- → `hf-unsloth-embeddinggemma-300m-GGUF` [d2] — GGUF variant for llama.cpp/Cactus
- → `hf-nomic-ai-nomic-embed-text-v1.5` [d4] — competing small embed; Apache-2.0
- → `hf-Qwen-Qwen3-Embedding-0.6B` [d4] — larger Cactus-bundled embed

### [other-adityakarnam-mlx-non-determinism-apple-silicon](_per_source/other-adityakarnam-mlx-non-determinism-apple-silicon.md) (density 5)

- → `paper-2403.12844` [d4] — MELTing Point — mobile LLM benchmarking

### [other-aihub-qualcomm-models-nomic-embed-text](_per_source/other-aihub-qualcomm-models-nomic-embed-text.md) (density 5)

- → `paper-2402.01613` [d4] — Nomic Embed Text v1 paper
- → `paper-2509.20354` [d4] — EmbeddingGemma comparison baseline

### [other-ascentcore-2026-04-01-small-llm-performance-benchmark](_per_source/other-ascentcore-2026-04-01-small-llm-performance-benchmark.md) (density 5)

- → `paper-2403.12844` [d4] — MELTing Point mobile LLM benchmark
- → `paper-2406.10290` [d4] — MobileAIBench
- → `hf-HuggingFaceTB-SmolLM2-1.7B-Instruct` [d3] — model card
- → `hf-Qwen-Qwen2.5-1.5B-Instruct` [d5] — cross-batch model card

### [other-cactuscompute](_per_source/other-cactuscompute.md) (density 5)

- → `other-huggingface-co-cactus-compute` [d4] — HF org page with model weights
- → `paper-2509.20354` [d4] — EmbeddingGemma, one of Cactus's packaged embeds

### [other-dicg-workshop-github-2022-papers-tschudin-pdf](_per_source/other-dicg-workshop-github-2022-papers-tschudin-pdf.md) (density 5)

- → `paper-1106.4374` [d5] — Shapiro et al. foundational CRDT theory
- → `other-automerge` [d4] — richer CRDT library
- → `other-gist-a556180db7d4` *(external or unknown)* — VecDHT — also targets P2P semantic structures

### [other-ditto-platform-edge-sync](_per_source/other-ditto-platform-edge-sync.md) (density 5)

- → `other-ditto-products-edge-sdk` [d4] — the SDK page; this is the platform page
- → `other-ditto-solutions-offline-first-architecture` [d3] — companion solutions framing
- → `other-ditto-solutions-conflict-resolution-powered-by-crdts` [d5] — the CRDT layer this transport feeds into

### [other-ditto-solutions-conflict-resolution-powered-by-crdts](_per_source/other-ditto-solutions-conflict-resolution-powered-by-crdts.md) (density 5)

- → `paper-1106.4374` [d5] — CRDT theoretical foundation
- → `other-ditto-platform-edge-sync` [d5] — the transport that delivers the CRDT diffs
- → `other-ditto-solutions-offline-first-architecture` [d3] — the application-level promise CRDTs enable

### [other-infoq-news-2025-12-cactus-on-device-inference](_per_source/other-infoq-news-2025-12-cactus-on-device-inference.md) (density 5)

- → `other-raw-githubusercontent-cactus-compute-cactus-main-docs-cactus-engine-md` [d5] — the API surface
- → `paper-2403.12844` [d4] — MELT — community benchmark of mobile LLM inference
- → `paper-2406.10290` [d4] — MobileAIBench — complementary benchmark

### [other-inkandswitch-essay-local-first](_per_source/other-inkandswitch-essay-local-first.md) (density 5)

- → `other-localfirstconf-local-first-conf-2024` [d3] — where the manifesto became a community
- → `other-localfirst-fm-13` [d3] — Maggie Appleton interview extending the argument to AI
- → `other-youtube-watch` [d4] — Appleton's keynote at the conf above

### [other-libraries-cargo-peat-protocol](_per_source/other-libraries-cargo-peat-protocol.md) (density 5)

- → `None` *(external or unknown)*

### [other-maggieappleton-home-cooked-software](_per_source/other-maggieappleton-home-cooked-software.md) (density 5)

- → `other-martin-kleppmann-2024-05-30-local-first-conference-html` [d3] — same conference, same week
- → `other-martin-kleppmann-papers-local-first-pdf` [d5] — the local-first manifesto Appleton builds on

### [other-martin-kleppmann-papers-local-first-pdf](_per_source/other-martin-kleppmann-papers-local-first-pdf.md) (density 5)

- → `other-martin-kleppmann-2024-05-30-local-first-conference-html` [d3] — Kleppmann's 5-year retrospective
- → `other-martin-kleppmann-2026-02-24-local-first-meetup-html` [d3] — sovereignty extension
- → `other-maggieappleton-home-cooked-software` [d5] — AI extension
- → `paper-1106.4374` [d5] — CRDT theory cited in the paper

### [other-ollama-library-embeddinggemma](_per_source/other-ollama-library-embeddinggemma.md) (density 5)

- → `paper-2509.20354` [d4] — EmbeddingGemma technical paper
- → `other-raw-githubusercontent-cactus-compute-cactus-main-docs-cactus-engine-md` [d5] — the engine that would load the GGUF
- → `other-raw-githubusercontent-ggml-org-ggml-master-docs-gguf-md` [d4] — the file format

### [other-raw-githubusercontent-cactus-compute-cactus-main-docs-cactus-engine-md](_per_source/other-raw-githubusercontent-cactus-compute-cactus-main-docs-cactus-engine-md.md) (density 5)

- → `other-infoq-news-2025-12-cactus-on-device-inference` [d5] — Cactus v1 release context, sub-50ms TTFT claim, ARM-CPU kernels
- → `paper-2509.20354` [d4] — EmbeddingGemma — candidate model loadable via Cactus

### [other-stuartcheshire-rants-latency-html](_per_source/other-stuartcheshire-rants-latency-html.md) (density 5)

- → `hpbn.co-primer-on-latency-and-bandwidth` *(external or unknown)* — modern mobile-network supplement
- → `arXiv` *(external or unknown)* — 2301.07788 (round-trip-time analysis paper)
- → `other-pinecone` [d3] — , other-pinecone-product (the cloud-RAG paths whose latency hits this floor)

### [paper-1106.4374](_per_source/paper-1106.4374.md) (density 5)

- → `paper-2305.00583` *(external or unknown)* — Fugue text CRDT, cited in Loro

### [paper-1908.10084](_per_source/paper-1908.10084.md) (density 5)

- → `repo-ukplab-sentence-transformers` [d3] — implementation framework for SBERT models

### [paper-2402.00841](_per_source/paper-2402.00841.md) (density 5)

- → `paper-2506.05176` [d5] — Qwen3 Embedding model spec
- → `Cactus` *(external or unknown)* — official documentation (implicit reference for implementation details)

### [paper-2402.14905](_per_source/paper-2402.14905.md) (density 5)

- → `paper-2411.09944` [d4] — SlimLM benchmarks on Samsung S24
- → `paper-2408.01800` [d3] — MiniCPM-V on-device MLLM trends
- → `paper-2605.17653` [d3] — LLMForge NAS for edge LMs

### [paper-2412.21023](_per_source/paper-2412.21023.md) (density 5)

- → `paper-2507.01079` [d5] — MobileRAG — broader on-device RAG measurement including energy
- → `repo-mlc-ai__mlc-llm` *(external or unknown)* — backend framework for on-device inference

### [paper-2505.16064](_per_source/paper-2505.16064.md) (density 5)

- → `paper-1605.06424` [d4] — Practical big-set CRDT engineering
- → `paper-2512.22280` [d5] — Deterministic memory substrate for vector indexes

### [paper-2506.05176](_per_source/paper-2506.05176.md) (density 5)

- → `repo-qwenlm-qwen3-embedding` [d4] — reference implementation

### [paper-2507.01079](_per_source/paper-2507.01079.md) (density 5)

- → `paper-2412.21023` [d5] — EdgeRAG — related edge-device acceleration work
- → `repo-mlc-ai__mlc-llm` *(external or unknown)* — MLC backend used in mobile RAG systems

### [paper-2511.17826](_per_source/paper-2511.17826.md) (density 5)

- → `paper-2512.22280` [d5] — Valori deterministic memory substrate
- → `paper-2605.19537` [d5] — Silent hyperparameter / inference-backend reproducibility

### [paper-2512.22280](_per_source/paper-2512.22280.md) (density 5)

- → `paper-2511.17826` [d5] — Tree-based invariant kernels
- → `paper-2605.19537` [d5] — Silent hyperparameter / inference-backend variance

### [paper-2605.19537](_per_source/paper-2605.19537.md) (density 5)

- → `paper-2512.22280` [d5] — Valori deterministic memory substrate
- → `paper-2511.17826` [d5] — Tree-based invariant kernels for TP determinism

### [repo-cactus-compute-cactus-flutter](_per_source/repo-cactus-compute-cactus-flutter.md) (density 5)

- → `repo-github-cactus-compute-cactus-docs-cactus-engine-md` [d5]
- → `repo-github-cactus-compute-cactus-tree-main-examples` [d5]
- → `repo-github-cactus-compute-cactus-react-native-tree-main-example` [d5]

### [repo-getditto-demoapp-inventory](_per_source/repo-getditto-demoapp-inventory.md) (density 5)

- → `docs-ditto-live` [d5] — foundational Ditto documentation

### [repo-getditto-demoapp-pos-kds](_per_source/repo-getditto-demoapp-pos-kds.md) (density 5)

- → `docs-docs-ditto-live` [d5] — authoritative docs on Ditto's CRDT model and mesh

### [repo-github-cactus-compute-cactus-docs-cactus-engine-md](_per_source/repo-github-cactus-compute-cactus-docs-cactus-engine-md.md) (density 5)

- → `repo-cactus-compute-cactus-flutter` [d5]
- → `repo-github-cactus-compute-cactus-react-native-tree-main-example` [d5]
- → `repo-github-cactus-compute-cactus-tree-main-examples` [d5]

### [repo-github-cactus-compute-cactus-react-native-tree-main-example](_per_source/repo-github-cactus-compute-cactus-react-native-tree-main-example.md) (density 5)

- → `repo-cactus-compute-cactus-flutter` [d5]
- → `repo-github-cactus-compute-cactus-docs-cactus-engine-md` [d5]
- → `repo-github-cactus-compute-cactus-tree-main-examples` [d5]

### [repo-github-cactus-compute-cactus-tree-main-examples](_per_source/repo-github-cactus-compute-cactus-tree-main-examples.md) (density 5)

- → `repo-github-cactus-compute-cactus-docs-cactus-engine-md` [d5]
- → `repo-cactus-compute-cactus-flutter` [d5]
- → `repo-github-cactus-compute-cactus-react-native-tree-main-example` [d5]

### [repo-github-mfontanini-presenterm-tree-master-examples](_per_source/repo-github-mfontanini-presenterm-tree-master-examples.md) (density 5)

- → `repo-hakimel-reveal.js` [d2]

### [repo-sqliteai-sqlite-vector](_per_source/repo-sqliteai-sqlite-vector.md) (density 5)

- → `repo-unum-cloud-usearch-benchmarks` [d4]
- → `repo-github-nmslib-hnswlib-issues-330` [d4]
- → `url-https-alexgarcia-xyz-sqlite-vec-android-ios` *(external or unknown)*

### [repo-thinking-machines-lab-batch_invariant_ops](_per_source/repo-thinking-machines-lab-batch_invariant_ops.md) (density 5)

- → `repo-github-sgl-project-sglang-issues-10278` [d3]
- → `repo-github-ggml-org-llama-cpp-issues-3625` [d4]
- → `url-https-thinkingmachines-ai-blog-defeating-nondeterminism-in-llm-inference` *(external or unknown)*
- → `url-https-arxiv-org-abs-2506-09501` *(external or unknown)*

### [repo-xuchenhao001-DRAG](_per_source/repo-xuchenhao001-DRAG.md) (density 5)

- → `url-https-arxiv-org-abs-2505-00443` *(external or unknown)*
- → `url-https-arxiv-org-abs-2504-06135` *(external or unknown)* — SHIMI
- → `paper-1106.4374` [d5]

### [article-ai-google-edge-litert-performance-delegates](_per_source/article-ai-google-edge-litert-performance-delegates.md) (density 4)

- → `article-ai-google-edge-mediapipe-solutions-genai-llm-inference` [d4] — MediaPipe sits on top of LiteRT
- → `article-ai-google-edge-mediapipe-solutions-genai-llm-inference-android` [d4]
- → `article-ai-google-edge-mediapipe-solutions-genai-llm-inference-ios` [d3]
- → `paper-2506.09501` [d3] — numerical sources of non-determinism, FP16/BF16 vs INT

### [article-ai-google-edge-mediapipe-solutions-genai-llm-inference](_per_source/article-ai-google-edge-mediapipe-solutions-genai-llm-inference.md) (density 4)

- → `article-ai-google-edge-mediapipe-solutions-genai-llm-inference-android` [d4]
- → `article-ai-google-edge-mediapipe-solutions-genai-llm-inference-ios` [d3]
- → `article-ai-google-edge-litert-performance-delegates` [d4]
- → `article-ai-google-gemma-terms` [d3]

### [article-ai-google-edge-mediapipe-solutions-genai-llm-inference-android](_per_source/article-ai-google-edge-mediapipe-solutions-genai-llm-inference-android.md) (density 4)

- → `article-ai-google-edge-mediapipe-solutions-genai-llm-inference` [d4] — overview
- → `article-ai-google-edge-mediapipe-solutions-genai-llm-inference-ios` [d3] — iOS counterpart
- → `hf-blog-rshemet-cactus-on-device-inference` [d5] — alternative engine
- → `article-pytorch-blog-executorch-beta` [d4] — sister Android on-device path

### [article-blog-swmansion-building-an-ai-powered-note-taking-app-in-react-native-pa](_per_source/article-blog-swmansion-building-an-ai-powered-note-taking-app-in-react-native-pa.md) (density 4)

- → `article-blog-swmansion-introducing-react-native-rag-fbb62efa4991` [d4] — the library
- → `article-deepsense-blog-implementing-small-language-models-slms-with-rag-on-emb` [d5] — Android-native parallel
- → `hf-blog-rshemet-cactus-on-device-inference` [d5] — the engine we substitute in

### [article-blog-swmansion-introducing-react-native-rag-fbb62efa4991](_per_source/article-blog-swmansion-introducing-react-native-rag-fbb62efa4991.md) (density 4)

- → `article-blog-swmansion-building-an-ai-powered-note-taking-app-in-react-native-pa` [d4] — Part 3 worked example
- → `article-deepsense-blog-implementing-small-language-models-slms-with-rag-on-emb` [d5] — Android-native sibling
- → `hf-blog-rshemet-cactus-on-device-inference` [d5] — alternative engine for the same seams

### [article-dev-to-learnwithvikzzy-conflict-free-replicated-data-types-crdts-ij](_per_source/article-dev-to-learnwithvikzzy-conflict-free-replicated-data-types-crdts-ij.md) (density 4)

- → `paper-1106.4374` [d5] — the formal CRDT paper
- → `article-www-ditto-blog-dittos-delta-state-crdts` *(external or unknown)* — Ditto's CRDT implementation specifically
- → `docs-ditto-live` [d5]

### [article-ditto-blog-ditto-sdk-v5](_per_source/article-ditto-blog-ditto-sdk-v5.md) (density 4)

- → `docs-docs-ditto-live` [d5] — Ditto reference docs
- → `docs-docs-ditto-live-dql` [d5] — DQL documentation
- → `article-ditto-blog-dittos-delta-state-crdts` [d5] — the underlying CRDT model unchanged across v4 → v5

### [article-ditto-blog-getting-started-with-bluetooth-file-sync](_per_source/article-ditto-blog-getting-started-with-bluetooth-file-sync.md) (density 4)

- → `article-ditto-blog-dittos-delta-state-crdts` [d5] — the underlying CRDT model that documents containing attachment tokens still merge cleanly
- → `docs-docs-ditto-live-transports` [d5] — transport layer details — BLE + AWDL + Wi-Fi Aware all in one mesh
- → `docs-mesh-networking-101` [d1] — Ditto mesh primer

### [article-ditto-blog-how-to-build-robust-offline-first-apps-a-technical-guid](_per_source/article-ditto-blog-how-to-build-robust-offline-first-apps-a-technical-guid.md) (density 4)

- → `article-ditto-blog-dittos-delta-state-crdts` [d5] — engineering-side companion piece
- → `paper-1106.4374` [d5] — CRDT theory
- → `article-powersync-blog-ditto-vs-powersync` [d4] — independent description of the same CRDT semantics

### [article-lmsys-blog-2025-09-22-sglang-deterministic](_per_source/article-lmsys-blog-2025-09-22-sglang-deterministic.md) (density 4)

- → `article-thinkingmachines-blog-defeating-nondeterminism-in-llm-inference` [d5] — the theoretical basis this implements
- → `paper-2506.09501` [d3] — cross-hardware FP-determinism quantification

### [article-powersync-blog-ditto-vs-powersync](_per_source/article-powersync-blog-ditto-vs-powersync.md) (density 4)

- → `article-ditto-blog-dittos-delta-state-crdts` [d5] — Ditto-side authoritative description of the same CRDT model
- → `article-ditto-blog-how-to-build-robust-offline-first-apps` *(external or unknown)* — Ditto-side framing of CRDT conflict resolution
- → `docs-docs-ditto-live` [d5] — Ditto SDK reference

### [article-powersync-blog-local-first-software-origins-and-evolution](_per_source/article-powersync-blog-local-first-software-origins-and-evolution.md) (density 4)

- → `article-thinkingmachines-blog-defeating-nondeterminism-in-llm-inference` [d5] — a complementary "you can engineer determinism" argument
- → `article-powersync-blog-ditto-vs-powersync` [d4] — architectural framing of the P2P vs server-auth trade

### [article-pytorch-blog-executorch-beta](_per_source/article-pytorch-blog-executorch-beta.md) (density 4)

- → `paper-2403.12844` [d4] — MELTing Point — independent mobile-LLM benchmark including ExecuTorch class
- → `paper-2406.10290` [d4] — MobileAIBench — complementary harness
- → `article-thinkingmachines-blog-defeating-nondeterminism-in-llm-inference` [d5] — kernel-level determinism applies across ExecuTorch/Cactus alike

### [docs-ai-google-gemma-docs-core-model-card-3](_per_source/docs-ai-google-gemma-docs-core-model-card-3.md) (density 4)

- → `docs-ai-google-gemma-docs-embeddinggemma-model-card` [d5]
- → `paper-2403.12844` [d4] — MELTing Point
- → `paper-2406.10290` [d4] — MobileAIBench
- → `docs-cactuscompute-docs-v1-7` [d5]

### [docs-cactuscompute-docs-v1-7-rag](_per_source/docs-cactuscompute-docs-v1-7-rag.md) (density 4)

- → `docs-cactuscompute-docs-v1-7` [d5]
- → `github-cactus-compute-cactus` *(external or unknown)*
- → `docs-ai-google-gemma-docs-embeddinggemma-model-card` [d5]
- → `paper-2507.01079` [d5] — MobileRAG

### [docs-developer-apple-documentation-foundationmodels](_per_source/docs-developer-apple-documentation-foundationmodels.md) (density 4)

- → `docs-developer-apple-videos-play-wwdc2025-248` [d3]
- → `docs-cactuscompute-docs-v1-7` [d5]
- → `docs-developer-apple-documentation-coreml-mlcomputeunits` [d2]

### [docs-docs-ditto-live-dql-dql](_per_source/docs-docs-ditto-live-dql-dql.md) (density 4)

- → `docs-docs-ditto-live-home-about-ditto` [d4]
- → `docs-docs-ditto-live-home-faq` [d2]
- → `docs-docs-ditto-live-key-concepts-mesh-networking` [d5]

### [docs-docs-ditto-live-home-about-ditto](_per_source/docs-docs-ditto-live-home-about-ditto.md) (density 4)

- → `docs-docs-ditto-live-key-concepts-mesh-networking` [d5]
- → `docs-docs-ditto-live-dql-dql` [d4]
- → `docs-docs-ditto-live-home-faq` [d2]
- → `docs-docs-ditto-live-home-mcp-integration` [d3]

### [docs-docs-ditto-live-sdk-latest-deployment-network-deployment](_per_source/docs-docs-ditto-live-sdk-latest-deployment-network-deployment.md) (density 4)

- → `docs-docs-ditto-live-sdk-v4-8-sync-concepts-transports-overview` [d5] — higher-level transport story
- → `docs-docs-ditto-live-sdk-v5-sync-customizing-transport-configurations` [d5] — the API surface that operationalizes this
- → `docs-mesh-networking-101` [d1] — introductory companion

### [docs-docs-ditto-live-sdk-latest-install-guides-react-native](_per_source/docs-docs-ditto-live-sdk-latest-install-guides-react-native.md) (density 4)

- → `docs-docs-ditto-live` [d5] — top-level
- → `docs-docs-ditto-live-sdk-latest-deployment-network-deployment` [d4] — network setup once installed
- → `cactus-react-native` *(external or unknown)* — the LLM side of the same RN app

### [docs-firebase-google-docs-ai-assistance-agent-skills](_per_source/docs-firebase-google-docs-ai-assistance-agent-skills.md) (density 4)

- → `docs-docs-ditto-live` [d5] — the product these skills would teach

### [docs-llm-mlc-docs-deploy-android-html](_per_source/docs-llm-mlc-docs-deploy-android-html.md) (density 4)

- → `docs-llm-mlc-docs-deploy-ios-html` [d4] — sibling iOS deploy guide
- → `cactus-engine` *(external or unknown)* — documentation (the competitor we're actually shipping)

### [docs-llm-mlc-docs-deploy-ios-html](_per_source/docs-llm-mlc-docs-deploy-ios-html.md) (density 4)

- → `docs-llm-mlc-docs-deploy-android-html` [d4] — sibling Android deploy guide
- → `cactus-engine` *(external or unknown)* — documentation (the competitor we're actually shipping)
- → `developer-apple-com` *(external or unknown)* — Foundation Models docs as a third comparison

### [gist-a556180db7d4](_per_source/gist-a556180db7d4.md) (density 4)

- → `paper-2505.00443` [d3] — DRAG — P2P RAG with TARW routing
- → `paper-2504.06135` [d5] — SHIMI — decentralized hierarchical memory
- → `other-dicg-workshop-github-2022-papers-tschudin-pdf` [d5] — CRDT-based alternative

### [hf-Qwen-Qwen3-Embedding-0.6B](_per_source/hf-Qwen-Qwen3-Embedding-0.6B.md) (density 4)

- → `hf-google-embeddinggemma-300m` [d5] — smaller, faster competing embed
- → `hf-nomic-ai-nomic-embed-text-v1.5` [d4] — other Cactus-bundled embed
- → `hf-sentence-transformers-all-MiniLM-L6-v2` [d4] — smaller baseline embed

### [hf-google-gemma-2-2b-it](_per_source/hf-google-gemma-2-2b-it.md) (density 4)

- → `hf-google-gemma-3-1b-it` [d4] — smaller, newer Gemma in same family
- → `hf-litert-community-Gemma2-2B-IT` [d2] — LiteRT mobile variant of this card
- → `hf-Qwen-Qwen2.5-1.5B-Instruct` [d5] — preferred default with cleaner license

### [hf-google-gemma-3-1b-it](_per_source/hf-google-gemma-3-1b-it.md) (density 4)

- → `hf-google-gemma-2-2b-it` [d4] — larger sibling in same family
- → `hf-litert-community-Gemma3-1B-IT` [d2] — LiteRT mobile variant
- → `hf-meta-llama-Llama-3.2-1B-Instruct` [d3] — competing 1B-class with Community License
- → `hf-Qwen-Qwen2.5-1.5B-Instruct` [d5] — preferred default with cleaner license

### [hf-nomic-ai-nomic-embed-text-v1.5](_per_source/hf-nomic-ai-nomic-embed-text-v1.5.md) (density 4)

- → `hf-google-embeddinggemma-300m` [d5] — primary embedding candidate
- → `hf-Qwen-Qwen3-Embedding-0.6B` [d4] — larger Cactus-bundled embed
- → `hf-sentence-transformers-all-MiniLM-L6-v2` [d4] — floor baseline

### [hf-sentence-transformers-all-MiniLM-L6-v2](_per_source/hf-sentence-transformers-all-MiniLM-L6-v2.md) (density 4)

- → `hf-google-embeddinggemma-300m` [d5] — modern primary candidate
- → `hf-nomic-ai-nomic-embed-text-v1.5` [d4] — Apache-2.0 alternative
- → `hf-Qwen-Qwen3-Embedding-0.6B` [d4] — larger Cactus-bundled embed

### [other-anytype](_per_source/other-anytype.md) (density 4)

- → `other-evilmartians-chronicles-recapping-the-first-local-first-conference-in-15-minutes` *(external or unknown)* — local-first community context

### [other-automerge](_per_source/other-automerge.md) (density 4)

- → `other-evilmartians-chronicles-recapping-the-first-local-first-conference-in-15-minutes` *(external or unknown)* — Kleppmann talk recap
- → `paper-2305.00583` *(external or unknown)* — Fugue text CRDT
- → `paper-1106.4374` [d5] — foundational CRDT theory

### [other-developers-google-nearby-connections-overview](_per_source/other-developers-google-nearby-connections-overview.md) (density 4)

- → `docs-bridgefy-sdk` [d3] — cross-platform BLE mesh alternative
- → `docs-developer-apple-com` [d3] — MultipeerConnectivity, iOS counterpart

### [other-ditto-products-edge-sdk](_per_source/other-ditto-products-edge-sdk.md) (density 4)

- → `other-ditto-platform-edge-sync` [d5] — the platform-level positioning
- → `other-resources-ditto-live-developers` [d3] — the developer resources hub
- → `other-ditto-solutions-conflict-resolution-powered-by-crdts` [d5] — the CRDT story the SDK enables

### [other-evilmartians-chronicles-recapping-the-first-local-first-conference-in-15-](_per_source/other-evilmartians-chronicles-recapping-the-first-local-first-conference-in-15-.md) (density 4)

- → `other-automerge` [d4] — Ink & Switch CRDT lib
- → `other-anytype` [d4] — local-first product example

### [other-hpbn-co-primer-on-latency-and-bandwidth](_per_source/other-hpbn-co-primer-on-latency-and-bandwidth.md) (density 4)

- → `paper-2301.07788` [d5] — RTT delay in the Internet

### [other-huggingface-co-cactus-compute](_per_source/other-huggingface-co-cactus-compute.md) (density 4)

- → `other-cactuscompute` [d5] — main Cactus website
- → `other-huggingface-co-liquidai` [d3] — LiquidAI / LFM2 family that Cactus ships

### [other-icml-cc-virtual-2025-poster-43950](_per_source/other-icml-cc-virtual-2025-poster-43950.md) (density 4)

- → `None` *(external or unknown)*

### [other-ingonyama-post-solving-reproducibility-challenges-in-deep-learning-and](_per_source/other-ingonyama-post-solving-reproducibility-challenges-in-deep-learning-and.md) (density 4)

- → `thinkingmachines.ai` *(external or unknown)* — "Defeating Nondeterminism in LLM Inference" — same root cause, different fix (batch-invariant kernels rather than deterministic GEMM)
- → `other-themoonlight` *(external or unknown)* — Silent Hyperparameter review

### [other-irohputer](_per_source/other-irohputer.md) (density 4)

- → `docs-ditto-live` [d5] — and related Ditto docs entries (our chosen layer)
- → `other-stuartcheshire-rants-latency-html` [d5] — motivates why P2P matters

### [other-llm-mlc-docs](_per_source/other-llm-mlc-docs.md) (density 4)

- → `None` *(external or unknown)*

### [other-mfontanini-github-presenterm](_per_source/other-mfontanini-github-presenterm.md) (density 4)

- → `None` *(external or unknown)*

### [other-promptquorum-power-local-llm-mobile-llm-models-phi4-gemma-smollm](_per_source/other-promptquorum-power-local-llm-mobile-llm-models-phi4-gemma-smollm.md) (density 4)

- → `huggingface.co-Qwen-Qwen2.5-1.5B-Instruct` *(external or unknown)*
- → `huggingface.co-HuggingFaceTB-SmolLM2-1.7B` *(external or unknown)* — and -Instruct variant
- → `huggingface.co-google-gemma-3-1b-it` *(external or unknown)*
- → `huggingface.co-google-gemma-2-2b-it` *(external or unknown)*

### [other-raw-githubusercontent-ggml-org-ggml-master-docs-gguf-md](_per_source/other-raw-githubusercontent-ggml-org-ggml-master-docs-gguf-md.md) (density 4)

- → `other-raw-githubusercontent-ggml-org-llama.cpp-master-docs-build-md` *(external or unknown)* — the executor that consumes GGUF
- → `other-raw-githubusercontent-cactus-compute-cactus-main-docs-cactus-engine-md` [d5] — Cactus v1 moved off GGUF but the format vocabulary stays

### [other-raw-githubusercontent-ggml-org-llama-cpp-master-docs-build-md](_per_source/other-raw-githubusercontent-ggml-org-llama-cpp-master-docs-build-md.md) (density 4)

- → `other-raw-githubusercontent-ggml-org-ggml-master-docs-gguf-md` [d4] — the file format llama.cpp consumes
- → `other-raw-githubusercontent-cactus-compute-cactus-main-docs-cactus-engine-md` [d5] — Cactus, the successor engine

### [other-raw-githubusercontent-unum-cloud-usearch-main-sqlite-readme-md](_per_source/other-raw-githubusercontent-unum-cloud-usearch-main-sqlite-readme-md.md) (density 4)

- → `other-raw-githubusercontent-cactus-compute-cactus-main-docs-cactus-engine-md` [d5] — whose `cactus_index_t` would be the other escape hatch

### [other-salttechno-datasets-vector-database-performance-benchmark-2026](_per_source/other-salttechno-datasets-vector-database-performance-benchmark-2026.md) (density 4)

- → `other-pinecone` [d3] — , other-pinecone-product
- → `airbyte.com-data-engineering-resources-qdrant-vs-pinecone` *(external or unknown)*
- → `other-stuartcheshire-rants-latency-html` [d5] — network-floor argument
- → `hpbn.co-primer-on-latency-and-bandwidth` *(external or unknown)*

### [other-se-radio-net-2026-04-se-radio-716-martin-kleppmann-local-first-software](_per_source/other-se-radio-net-2026-04-se-radio-716-martin-kleppmann-local-first-software.md) (density 4)

- → `paper-1106.4374` [d5] — CRDT foundational theory
- → `other-speakerdeck-ept-the-past-present-and-future-of-local-first` [d4] — Kleppmann's 2024 Local-First Conf keynote
- → `other-infoq-presentations-local-first-build-software` [d3] — related InfoQ talk on local-first

### [other-speakerdeck-ept-the-past-present-and-future-of-local-first](_per_source/other-speakerdeck-ept-the-past-present-and-future-of-local-first.md) (density 4)

- → `other-se-radio-net-2026-04-se-radio-716-martin-kleppmann-local-first-software` [d4] — the spoken interview
- → `other-infoq-presentations-local-first-build-software` [d3] — the practitioner's take

### [other-themoonlight-fr-review-the-silent-hyperparameter-quantifying-the-impact-o](_per_source/other-themoonlight-fr-review-the-silent-hyperparameter-quantifying-the-impact-o.md) (density 4)

- → `other-thejournal-club-c-paper-938963` [d3] — paper landing
- → `other-ingonyama-post-solving-reproducibility-challenges-in-deep-learning-and` [d4]
- → `thinkingmachines.ai` *(external or unknown)* — Thinking Machines Lab determinism writeup

### [other-willowprotocol](_per_source/other-willowprotocol.md) (density 4)

- → `other-willowprotocol-more-willow-compared-index-html` [d4] — Willow's own comparison to other protocols
- → `other-nlnet-nl-project-earthstar-interview-html` [d3] — the interview with Willow's authors
- → `paper-1106.4374` [d5] — CRDT foundational theory

### [other-willowprotocol-more-willow-compared-index-html](_per_source/other-willowprotocol-more-willow-compared-index-html.md) (density 4)

- → `other-willowprotocol` [d4] — parent home page
- → `other-nlnet-nl-project-earthstar-interview-html` [d3] — Earthstar/Willow author interview
- → `paper-1106.4374` [d5] — CRDT foundational theory — Willow uses CRDT-adjacent semantics

### [other-ycombinator-companies-cactus](_per_source/other-ycombinator-companies-cactus.md) (density 4)

- → `cactuscompute.com` *(external or unknown)* — Cactus marketing/docs site
- → `huggingface.co-Cactus-Compute` *(external or unknown)* — Cactus model org page
- → `other-reddit-r-deeplearning-comments-1kbucat-cactus-framework-for-ondevic` [d1] — blocked Reddit thread

### [other-youtube-watch](_per_source/other-youtube-watch.md) (density 4)

- → `maggieappleton.com-home-cooked-software` *(external or unknown)* — essay version
- → `other-localfirst-fm-13` [d3] — podcast interview
- → `other-localfirstconf-local-first-conf-2024` [d3] — the conf where this talk happened

### [paper-1605.06424](_per_source/paper-1605.06424.md) (density 4)

- → `paper-1106.4374` [d5] — Shapiro et al. foundational CRDT theory
- → `paper-2006.10494` [d4] — Limits of undoable set CRDTs

### [paper-1910.01108](_per_source/paper-1910.01108.md) (density 4)

- → `paper-2402.00841` [d5] — Tiny Titans — related: specialist finetuning of small models
- → `paper-2405.00732` [d4] — LoRA Land — related: parameter-efficient adaptation

### [paper-1910.03345](_per_source/paper-1910.03345.md) (density 4)

- → `paper-2208.04050` [d4] — BLE mesh for power-limited IoT
- → `paper-2006.02859` [d2] — Transport-protocol latency over 5G/LTE/WiFi

### [paper-2006.10494](_per_source/paper-2006.10494.md) (density 4)

- → `paper-1106.4374` [d5] — Shapiro et al. foundational CRDT theory
- → `paper-1605.06424` [d4] — Practical big-set CRDT engineering in Riak

### [paper-2208.04050](_per_source/paper-2208.04050.md) (density 4)

- → `paper-1910.03345` [d4] — BLE Mesh performance characterization

### [paper-2402.01613](_per_source/paper-2402.01613.md) (density 4)

- → `paper-1908.10084` [d5] — foundational embedding models that require determinism

### [paper-2402.04351](_per_source/paper-2402.04351.md) (density 4)

- → `docs-docs-ditto-live` [d5] — background on Ditto's CRDT merge requirements for parity-sensitive indexes

### [paper-2406.10290](_per_source/paper-2406.10290.md) (density 4)

- → `paper-2403.12844` [d4] — MELTing Point — complementary mobile-LLM benchmark; covers Android in more depth where MobileAIBench focuses on iOS
- → `paper-2409.00088` [d3] — On-Device Language Models survey — frames where MobileAIBench fits in the broader landscape

### [paper-2409.15342](_per_source/paper-2409.15342.md) (density 4)

- → `paper-2402.14905` [d5] — MobileLLM design principles
- → `paper-2411.09944` [d4] — SlimLM on-device benchmarks

### [paper-2411.09944](_per_source/paper-2411.09944.md) (density 4)

- → `paper-2402.14905` [d5] — MobileLLM sub-billion architectures
- → `paper-2505.06461` [d4] — CPU vs GPU on iPhone for LLM
- → `paper-2603.23640` [d4] — Sustained-load mobile benchmarks

### [paper-2505.06461](_per_source/paper-2505.06461.md) (density 4)

- → `paper-2406.10816` [d3] — Llama.cpp ARM optimization
- → `paper-2411.09944` [d4] — SlimLM Android benchmarks
- → `paper-2603.23640` [d4] — Sustained-load mobile thermal trade-offs

### [paper-2505.19847](_per_source/paper-2505.19847.md) (density 4)

- → `paper-2511.07577` [d4] — Decentralized RAG with blockchain reliability
- → `paper-2505.00443` [d3] — DRAG distributed retrieval - cited in claude-deep-research

### [paper-2511.07577](_per_source/paper-2511.07577.md) (density 4)

- → `paper-2505.19847` [d4] — DGRAG edge-cloud distributed RAG
- → `paper-2505.00443` [d3] — DRAG topic-aware random walk, cited in claude-deep-research

### [paper-2603.23640](_per_source/paper-2603.23640.md) (density 4)

- → `paper-2411.09944` [d4] — SlimLM single-iteration S24 benchmarks
- → `paper-2505.06461` [d4] — CPU vs GPU on iPhone 15 Pro
- → `paper-2406.10816` [d3] — ARM optimization details

### [repo-github-asg017-sqlite-vec-releases](_per_source/repo-github-asg017-sqlite-vec-releases.md) (density 4)

- → `repo-asg017-sqlite-vss` [d3]
- → `repo-DeveloperMindset-com-faiss-mobile` *(external or unknown)*

### [repo-github-getditto-demoapp-inventory-tree-main-android](_per_source/repo-github-getditto-demoapp-inventory-tree-main-android.md) (density 4)

- → `repo-github-getditto-demoapp-inventory-tree-main-ios` [d4]
- → `repo-github-getditto-demoapp-pos-kds-tree-main-android` [d4]
- → `repo-github-getditto-demoapp-pos-kds-tree-main-ios` [d4]

### [repo-github-getditto-demoapp-inventory-tree-main-ios](_per_source/repo-github-getditto-demoapp-inventory-tree-main-ios.md) (density 4)

- → `repo-github-getditto-demoapp-inventory-tree-main-android` [d4]
- → `repo-github-getditto-demoapp-pos-kds-tree-main-ios` [d4]
- → `repo-github-getditto-demoapp-pos-kds-tree-main-android` [d4]

### [repo-github-getditto-demoapp-pos-kds-tree-main-android](_per_source/repo-github-getditto-demoapp-pos-kds-tree-main-android.md) (density 4)

- → `repo-github-getditto-demoapp-pos-kds-tree-main-ios` [d4]
- → `repo-github-getditto-demoapp-inventory-tree-main-android` [d4]
- → `repo-github-getditto-demoapp-inventory-tree-main-ios` [d4]

### [repo-github-getditto-demoapp-pos-kds-tree-main-ios](_per_source/repo-github-getditto-demoapp-pos-kds-tree-main-ios.md) (density 4)

- → `repo-github-getditto-demoapp-pos-kds-tree-main-android` [d4]
- → `repo-github-getditto-demoapp-inventory-tree-main-ios` [d4]
- → `repo-github-getditto-demoapp-inventory-tree-main-android` [d4]

### [repo-github-ggml-org-llama-cpp-issues-3625](_per_source/repo-github-ggml-org-llama-cpp-issues-3625.md) (density 4)

- → `repo-github-ggml-org-llama-cpp-issues-7052` [d3]
- → `repo-github-ggml-org-llama-cpp-issues-16016` *(external or unknown)*
- → `repo-thinking-machines-lab-batch_invariant_ops` [d5]
- → `url-https-thinkingmachines-ai-blog-defeating-nondeterminism-in-llm-inference` *(external or unknown)*

### [repo-github-nmslib-hnswlib-issues-330](_per_source/repo-github-nmslib-hnswlib-issues-330.md) (density 4)

- → `repo-unum-cloud-usearch-benchmarks` [d4]
- → `arXiv-2407.07871` *(external or unknown)* — HNSW real-time updates

### [repo-ljwagerfield-crdt](_per_source/repo-ljwagerfield-crdt.md) (density 4)

- → `paper-1106.4374` [d5]
- → `docs-ditto-live` [d5]

### [repo-n0-computer-iroh-willow](_per_source/repo-n0-computer-iroh-willow.md) (density 4)

- → `url-https-willowprotocol-org` *(external or unknown)*
- → `docs-ditto-live` [d5]

### [repo-qwenlm-qwen3-embedding](_per_source/repo-qwenlm-qwen3-embedding.md) (density 4)

- → `repo-UKPLab-sentence-transformers` *(external or unknown)*
- → `paper-2402.01613` [d4]

### [repo-software-mansion-labs-react-native-rag](_per_source/repo-software-mansion-labs-react-native-rag.md) (density 4)

- → `repo-ukplab-sentence-transformers` [d3] — embeddings models used by React Native RAG
- → `paper-1908.10084` [d5] — foundation for embedding models in the framework

### [repo-unum-cloud-usearch-benchmarks](_per_source/repo-unum-cloud-usearch-benchmarks.md) (density 4)

- → `repo-github-nmslib-hnswlib-issues-330` [d4]
- → `repo-sqliteai-sqlite-vector` [d5]
- → `repo-upb-cn-MoRAGBench` [d4]

### [repo-upb-cn-MoRAGBench](_per_source/repo-upb-cn-MoRAGBench.md) (density 4)

- → `url-https-arxiv-org-abs-2507-01079` *(external or unknown)* — MobileRAG
- → `url-https-arxiv-org-abs-2406-10290` *(external or unknown)* — MobileAIBench
- → `url-https-arxiv-org-abs-2403-12844` *(external or unknown)* — MELT

### [article-ai-google-edge-mediapipe-solutions-genai-llm-inference-ios](_per_source/article-ai-google-edge-mediapipe-solutions-genai-llm-inference-ios.md) (density 3)

- → `article-ai-google-edge-mediapipe-solutions-genai-llm-inference` [d4] — overview
- → `article-ai-google-edge-mediapipe-solutions-genai-llm-inference-android` [d4] — Android counterpart
- → `article-ai-google-edge-litert-performance-delegates` [d4] — iOS Core ML delegate
- → `hf-blog-rshemet-cactus-on-device-inference` [d5] — the unified alternative

### [article-ai-google-gemma-terms](_per_source/article-ai-google-gemma-terms.md) (density 3)

- → `article-ai-google-edge-mediapipe-solutions-genai-llm-inference` [d4] — Gemma is its default model
- → `paper-2509.20354` [d4] — EmbeddingGemma — same license family

### [article-ai-meta-blog-llama-3-2-connect-2024-vision-edge-mobile-devices](_per_source/article-ai-meta-blog-llama-3-2-connect-2024-vision-edge-mobile-devices.md) (density 3)

- → `paper-2403.12844` [d4] — MELT — benchmarks Llama 3.2-class
- → `paper-2406.10290` [d4] — MobileAIBench
- → `hf-blog-rshemet-cactus-on-device-inference` [d5] — Cactus runs Llama families
- → `article-pytorch-blog-executorch-beta` [d4] — ExecuTorch's Llama 3.2 1B/3B mobile path

### [article-bentoml-blog-a-guide-to-open-source-embedding-models](_per_source/article-bentoml-blog-a-guide-to-open-source-embedding-models.md) (density 3)

- → `paper-2509.20354` [d4] — EmbeddingGemma
- → `paper-2402.01613` [d4] — Nomic Embed
- → `article-supermemory-blog-best-open-source-embedding-models-benchmarked-and-ranke` [d3] — parallel 2024 survey, less current

### [article-firebase-blog-posts-2026-05-google-io-2026-announcements](_per_source/article-firebase-blog-posts-2026-05-google-io-2026-announcements.md) (density 3)

- → `hf-blog-rshemet-cactus-on-device-inference` [d5] — the Cactus pairing for skills
- → `docs-ditto-live` [d5] — the Ditto pairing for skills

### [article-irohputer-blog-comparing-iroh-and-libp2p](_per_source/article-irohputer-blog-comparing-iroh-and-libp2p.md) (density 3)

- → `docs-docs-ditto-live-transports` [d5] — Ditto's actual multi-transport mesh, including BLE

### [article-supermemory-blog-best-open-source-embedding-models-benchmarked-and-ranke](_per_source/article-supermemory-blog-best-open-source-embedding-models-benchmarked-and-ranke.md) (density 3)

- → `paper-2402.01613` [d4] — Nomic Embed paper
- → `paper-2509.20354` [d4] — EmbeddingGemma, post-dates this article and dominates it
- → `article-bentoml-blog-a-guide-to-open-source-embedding-models` [d3] — parallel 2026 update with broader model set

### [docs-apphub-qualcomm-docs-hub-quantize-examples-html](_per_source/docs-apphub-qualcomm-docs-hub-quantize-examples-html.md) (density 3)

- → `docs-developer-apple-documentation-coreml-mlcomputeunits` [d2]
- → `paper-2506.09501` [d3] — Numerical sources of nondeterminism
- → `docs-cactuscompute-docs-v1-7` [d5]

### [docs-developer-apple-documentation-multipeerconnectivity](_per_source/docs-developer-apple-documentation-multipeerconnectivity.md) (density 3)

- → `docs-docs-ditto-live-key-concepts-mesh-networking` [d5]
- → `docs-docs-ditto-live-home-about-ditto` [d4]
- → `github-permissionlesstech-bitchat` *(external or unknown)*

### [docs-developer-apple-videos-play-wwdc2025-248](_per_source/docs-developer-apple-videos-play-wwdc2025-248.md) (density 3)

- → `docs-developer-apple-documentation-foundationmodels` [d4]
- → `docs-cactuscompute-docs-v1-7` [d5]

### [docs-docs-ditto-live-home-mcp-integration](_per_source/docs-docs-ditto-live-home-mcp-integration.md) (density 3)

- → `docs-docs-ditto-live-home-about-ditto` [d4]
- → `docs-docs-ditto-live-dql-dql` [d4]

### [docs-docs-ditto-live-sdk-latest-release-notes-java](_per_source/docs-docs-ditto-live-sdk-latest-release-notes-java.md) (density 3)

- → `docs-docs-ditto-live-sdk-latest-release-notes-kotlin` [d3] — same release, Kotlin-specific notes
- → `docs-docs-ditto-live-dql` [d5] — the query language v5 unifies on

### [docs-docs-ditto-live-sdk-latest-release-notes-kotlin](_per_source/docs-docs-ditto-live-sdk-latest-release-notes-kotlin.md) (density 3)

- → `docs-docs-ditto-live-sdk-latest-release-notes-java` [d3] — sibling release notes
- → `docs-docs-ditto-live-dql` [d5] — the query language

### [docs-onnxruntime-docs-execution-providers-nnapi-executionprovider-html](_per_source/docs-onnxruntime-docs-execution-providers-nnapi-executionprovider-html.md) (density 3)

- → `docs-onnxruntime-docs-performance-model-optimizations-quantization-html` [d3] — sibling — quantization tooling

### [docs-onnxruntime-docs-performance-model-optimizations-quantization-html](_per_source/docs-onnxruntime-docs-performance-model-optimizations-quantization-html.md) (density 3)

- → `docs-onnxruntime-docs-execution-providers-nnapi-executionprovider-html` [d3] — where these quantized ops actually run on Android
- → `paper-2506.09501` [d3] — FP16/BF16 cross-GPU divergence — companion empirical evidence
- → `karnam-mlx-non-determinism` *(external or unknown)* — Q4_K_M / Q8_0 reproducibility result

### [hf-BAAI-bge-small-en-v1.5](_per_source/hf-BAAI-bge-small-en-v1.5.md) (density 3)

- → `other-discuss-huggingface-co-t-on-device-sentence-embeddings-with-all-minilm-l6-` [d3] — sibling small embed
- → `paper-2402.01613` [d4] — Nomic Embed v1
- → `paper-2509.20354` [d4] — EmbeddingGemma

### [hf-HuggingFaceTB-SmolLM2-1.7B](_per_source/hf-HuggingFaceTB-SmolLM2-1.7B.md) (density 3)

- → `hf-HuggingFaceTB-SmolLM2-1.7B-Instruct` [d3] — chat-tuned sibling, our actual candidate
- → `other-ascentcore-2026-04-01-small-llm-performance-benchmark` [d5] — SmolLM2 weak JSON reliability data

### [hf-HuggingFaceTB-SmolLM2-1.7B-Instruct](_per_source/hf-HuggingFaceTB-SmolLM2-1.7B-Instruct.md) (density 3)

- → `hf-HuggingFaceTB-SmolLM2-1.7B` [d3] — base sibling
- → `other-ascentcore-2026-04-01-small-llm-performance-benchmark` [d5] — head-to-head benchmark

### [hf-Qwen-Qwen3-1.7B](_per_source/hf-Qwen-Qwen3-1.7B.md) (density 3)

- → `hf-Qwen-Qwen2.5-1.5B-Instruct` [d5] — predecessor; default Stage 0
- → `hf-Qwen-Qwen3-Embedding-0.6B` [d4] — sibling embedding model

### [hf-meta-llama-Llama-3.2-1B-Instruct](_per_source/hf-meta-llama-Llama-3.2-1B-Instruct.md) (density 3)

- → `hf-meta-llama-Llama-3.2-3B-Instruct` [d3] — larger sibling for quality reach
- → `hf-Qwen-Qwen2.5-1.5B-Instruct` [d5] — preferred default with cleaner license
- → `hf-google-gemma-3-1b-it` [d4] — other 1B-class competitor

### [hf-meta-llama-Llama-3.2-3B-Instruct](_per_source/hf-meta-llama-Llama-3.2-3B-Instruct.md) (density 3)

- → `hf-meta-llama-Llama-3.2-1B-Instruct` [d3] — smaller sibling
- → `hf-Qwen-Qwen2.5-1.5B-Instruct` [d5] — preferred default at smaller size
- → `hf-google-gemma-2-2b-it` [d4] — competing quality reach in 2B class

### [other-discuss-huggingface-co-t-on-device-sentence-embeddings-with-all-minilm-l6-](_per_source/other-discuss-huggingface-co-t-on-device-sentence-embeddings-with-all-minilm-l6-.md) (density 3)

- → `hf-BAAI-bge-small-en-v1.5` [d3] — sibling small embedding model

### [other-ditto-demo-apps](_per_source/other-ditto-demo-apps.md) (density 3)

- → `other-ditto-platform-edge-sync` [d5] — companion platform page
- → `other-ditto-products-edge-sdk` [d4] — companion SDK page

### [other-ditto-solutions-offline-first-architecture](_per_source/other-ditto-solutions-offline-first-architecture.md) (density 3)

- → `other-ditto-platform-edge-sync` [d5] — the underlying platform
- → `other-ditto-solutions-conflict-resolution-powered-by-crdts` [d5] — the CRDT layer

### [other-eprint-iacr-2021-214-pdf](_per_source/other-eprint-iacr-2021-214-pdf.md) (density 3)

- → `docs-bridgefy-sdk` [d3] — vendor SDK
- → `docs-mesh-networking-101` [d1] — Ditto's mesh model, contrast

### [other-gafferongames-post-floating-point-determinism](_per_source/other-gafferongames-post-floating-point-determinism.md) (density 3)

- → `other-adityakarnam-mlx-non-determinism-apple-silicon` [d5] — modern on-Apple-Silicon counterpart

### [other-huggingface-co-liquidai](_per_source/other-huggingface-co-liquidai.md) (density 3)

- → `other-cactuscompute` [d5] — Cactus runs LFM2 as demo model
- → `other-huggingface-co-cactus-compute` [d4] — model-weights org

### [other-infoq-presentations-local-first-build-software](_per_source/other-infoq-presentations-local-first-build-software.md) (density 3)

- → `other-se-radio-net-2026-04-se-radio-716-martin-kleppmann-local-first-software` [d4] — Kleppmann's interview
- → `other-speakerdeck-ept-the-past-present-and-future-of-local-first` [d4] — Kleppmann's keynote slides
- → `paper-1106.4374` [d5] — CRDT foundation Automerge builds on

### [other-localfirst-fm-13](_per_source/other-localfirst-fm-13.md) (density 3)

- → `other-localfirstconf-local-first-conf-2024` [d3]
- → `other-youtube-watch` [d4] — Appleton's keynote video
- → `maggieappleton.com-home-cooked-software` *(external or unknown)* — essay

### [other-localfirstconf-local-first-conf-2024](_per_source/other-localfirstconf-local-first-conf-2024.md) (density 3)

- → `other-inkandswitch-essay-local-first` [d5] — the manifesto the conference was built around
- → `other-localfirst-fm-13` [d3] — podcast with Appleton
- → `other-youtube-watch` [d4] — Appleton's keynote
- → `martin.kleppmann.com-2024-05-30-local-first-conference.html` *(external or unknown)* — Kleppmann's writeup of the event

### [other-martin-kleppmann-2024-05-30-local-first-conference-html](_per_source/other-martin-kleppmann-2024-05-30-local-first-conference-html.md) (density 3)

- → `other-maggieappleton-home-cooked-software` [d5] — same conference
- → `other-martin-kleppmann-papers-local-first-pdf` [d5] — the 2019 paper being retrospected
- → `other-martin-kleppmann-2024-02-27-local-first-meetup-html` [d1] — earlier 2024 talk
- → `other-martin-kleppmann-2026-02-24-local-first-meetup-html` [d3] — 2026 follow-up

### [other-martin-kleppmann-2026-02-24-local-first-meetup-html](_per_source/other-martin-kleppmann-2026-02-24-local-first-meetup-html.md) (density 3)

- → `other-martin-kleppmann-2024-05-30-local-first-conference-html` [d3] — prior keynote
- → `other-martin-kleppmann-2024-02-27-local-first-meetup-html` [d1] — prior LoFi talk
- → `other-martin-kleppmann-papers-local-first-pdf` [d5] — foundational paper

### [other-neuropilot-mediatek](_per_source/other-neuropilot-mediatek.md) (density 3)

- → `aihub.qualcomm.com-models-nomic_embed_text` *(external or unknown)* — parallel Qualcomm NPU optimization

### [other-nlnet-nl-project-earthstar-interview-html](_per_source/other-nlnet-nl-project-earthstar-interview-html.md) (density 3)

- → `other-willowprotocol` [d4] — Willow protocol home
- → `other-willowprotocol-more-willow-compared-index-html` [d4] — Willow's protocol comparison

### [other-pinecone](_per_source/other-pinecone.md) (density 3)

- → `other-pinecone-product` [d3] — sibling product-detail page
- → `other-salttechno-datasets-vector-database-performance-benchmark-2026` [d4] — third-party benchmark including Pinecone
- → `other-stuartcheshire-rants-latency-html` [d5] — the physics ceiling that any cloud answer hits

### [other-pinecone-product](_per_source/other-pinecone-product.md) (density 3)

- → `other-pinecone` [d3] — sibling homepage
- → `airbyte.com-data-engineering-resources-qdrant-vs-pinecone` *(external or unknown)* — third-party comparison
- → `other-salttechno-datasets-vector-database-performance-benchmark-2026` [d4]

### [other-raw-githubusercontent-mfontanini-presenterm-master-examples-demo-md](_per_source/other-raw-githubusercontent-mfontanini-presenterm-master-examples-demo-md.md) (density 3)

- → `other-revealjs` [d2] — the JS-based alternative we're not using

### [other-resources-ditto-live-developers](_per_source/other-resources-ditto-live-developers.md) (density 3)

- → `other-ditto-platform-edge-sync` [d5] — sister marketing page
- → `other-ditto-products-edge-sdk` [d4] — sister marketing page

### [other-sy6xxuj5rs5nwwun-public-blob-vercel-storage-images-mongodb-ditto-reference](_per_source/other-sy6xxuj5rs5nwwun-public-blob-vercel-storage-images-mongodb-ditto-reference.md) (density 3)

- → `other-ditto-platform-edge-sync` [d5] — the standalone Ditto platform without MongoDB

### [other-tensorflow-api-docs-python-tf-config-experimental-enable-op-determinism](_per_source/other-tensorflow-api-docs-python-tf-config-experimental-enable-op-determinism.md) (density 3)

- → `other-ingonyama-post-solving-reproducibility-challenges-in-deep-learning-and` [d4] — CUDA-kernel-level determinism
- → `other-themoonlight-fr-review-the-silent-hyperparameter-quantifying-the-impact-o` [d4] — downstream benchmark impact
- → `gafferongames.com-post-floating_point_determinism` *(external or unknown)* — game-physics precedent for the same problem

### [other-thejournal-club-c-paper-938963](_per_source/other-thejournal-club-c-paper-938963.md) (density 3)

- → `other-themoonlight-fr-review-the-silent-hyperparameter-quantifying-the-impact-o` [d4] — substantive review of the same paper
- → `other-ingonyama-post-solving-reproducibility-challenges-in-deep-learning-and` [d4]
- → `thinkingmachines.ai` *(external or unknown)* — Defeating Nondeterminism in LLM Inference

### [paper-2302.01005](_per_source/paper-2302.01005.md) (density 3)

- → `paper-2507.17232` [d3] — Clean recipe dataset with ingredient state annotations
- → `paper-2412.04922` [d3] — LLM ingredient substitution, cited in chatgpt-deep-research

### [paper-2403.13187](_per_source/paper-2403.13187.md) (density 3)

- → `paper-2402.14905` [d5] — MobileLLM sub-billion architectures
- → `paper-2602.11089` [d3] — DataChef RL for data recipes

### [paper-2406.10816](_per_source/paper-2406.10816.md) (density 3)

- → `paper-2402.14905` [d5] — MobileLLM sub-billion design
- → `paper-2511.17826` [d5] — Tree-based invariant kernels for determinism

### [paper-2408.01800](_per_source/paper-2408.01800.md) (density 3)

- → `paper-2402.14905` [d5] — MobileLLM sub-billion architectures
- → `paper-2411.09944` [d4] — SlimLM document assistance on S24

### [paper-2409.00088](_per_source/paper-2409.00088.md) (density 3)

- → `repo-qwenlm-qwen3-embedding` [d4] — embeddings + reranking pipeline

### [paper-2412.04922](_per_source/paper-2412.04922.md) (density 3)

- → `paper-2402.01613` [d4] — deterministic embeddings for ANN index keys

### [paper-2506.09501](_per_source/paper-2506.09501.md) (density 3)

- → `paper-2412.04922` [d3] — distributed vector search foundations

### [paper-2507.17232](_per_source/paper-2507.17232.md) (density 3)

- → `paper-2302.01005` [d3] — Recipe and ingredient embeddings

### [paper-2508.01110](_per_source/paper-2508.01110.md) (density 3)

- → `paper-2006.02859` [d2] — Mobile transport-protocol latency

### [paper-2512.17108](_per_source/paper-2512.17108.md) (density 3)

- → `paper-2408.01800` [d3] — MiniCPM-V on-device MLLM trends
- → `paper-2604.21026` [d3] — MCAP memory-constrained inference

### [paper-2602.11089](_per_source/paper-2602.11089.md) (density 3)

- → `paper-2403.13187` [d3] — Evolutionary model merging
- → `paper-2402.14905` [d5] — MobileLLM design principles

### [paper-2604.21026](_per_source/paper-2604.21026.md) (density 3)

- → `paper-2406.10816` [d3] — ARM-side llama.cpp optimization
- → `paper-2402.14905` [d5] — MobileLLM sub-billion design
- → `paper-2603.23640` [d4] — Sustained-load mobile thermal behavior

### [paper-2605.17653](_per_source/paper-2605.17653.md) (density 3)

- → `paper-2402.14905` [d5] — MobileLLM sub-billion architectures
- → `paper-2604.21026` [d3] — MCAP load-time per-layer routing

### [repo-asg017-sqlite-vss](_per_source/repo-asg017-sqlite-vss.md) (density 3)

- → `repo-github-asg017-sqlite-vec-releases` [d4]
- → `repo-DeveloperMindset-com-faiss-mobile` *(external or unknown)*

### [repo-developermindset-com-faiss-mobile](_per_source/repo-developermindset-com-faiss-mobile.md) (density 3)

- → `repo-asg017-sqlite-vss` [d3]
- → `repo-github-asg017-sqlite-vec-releases` [d4]

### [repo-getditto-demoapp-chat](_per_source/repo-getditto-demoapp-chat.md) (density 3)

- → `docs-ditto-live` [d5] — SDK documentation for deeper setup details

### [repo-github-ggml-org-llama-cpp-discussions-2658](_per_source/repo-github-ggml-org-llama-cpp-discussions-2658.md) (density 3)

- → `repo-github-ggml-org-llama-cpp-issues-22926` [d3]
- → `repo-github-ggml-org-llama-cpp-issues-2838` [d2]
- → `repo-github-cactus-compute-cactus-docs-cactus-engine-md` [d5]

### [repo-github-ggml-org-llama-cpp-issues-22926](_per_source/repo-github-ggml-org-llama-cpp-issues-22926.md) (density 3)

- → `repo-github-ggml-org-llama-cpp-discussions-2658` [d3]
- → `repo-github-ggml-org-llama-cpp-issues-2838` [d2]

### [repo-github-ggml-org-llama-cpp-issues-7052](_per_source/repo-github-ggml-org-llama-cpp-issues-7052.md) (density 3)

- → `repo-github-ggml-org-llama-cpp-issues-3625` [d4]
- → `repo-github-ggml-org-llama-cpp-issues-16016` *(external or unknown)*

### [repo-github-ggml-org-llama-cpp-pull-16016](_per_source/repo-github-ggml-org-llama-cpp-pull-16016.md) (density 3)

- → `repo-github-ggml-org-llama-cpp-issues-3625` [d4]
- → `repo-github-ggml-org-llama-cpp-issues-7052` [d3]
- → `repo-thinking-machines-lab-batch_invariant_ops` [d5]

### [repo-github-sgl-project-sglang-issues-10278](_per_source/repo-github-sgl-project-sglang-issues-10278.md) (density 3)

- → `repo-thinking-machines-lab-batch_invariant_ops` [d5]
- → `url-https-thinkingmachines-ai-blog-defeating-nondeterminism-in-llm-inference` *(external or unknown)*
- → `url-https-www-lmsys-org-blog-2025-09-22-sglang-deterministic` *(external or unknown)*

### [repo-loro-dev-loro](_per_source/repo-loro-dev-loro.md) (density 3)

- → `paper-1106.4374` [d5] — foundational CRDT theory

### [repo-mlc-ai-mlc-llm](_per_source/repo-mlc-ai-mlc-llm.md) (density 3)

- → `paper-2403.12844` [d4] — MELT — benchmark suite that measures MLC-LLM performance
- → `paper-2507.01079` [d5] — MobileRAG — deployed using MLC backend

### [repo-spotify-annoy](_per_source/repo-spotify-annoy.md) (density 3)

- → `repo-mlc-ai__mlc-llm` *(external or unknown)* — vector-search libraries are alternatives to Annoy for embedding retrieval

### [repo-ukplab-sentence-transformers](_per_source/repo-ukplab-sentence-transformers.md) (density 3)

- → `repo-QwenLM-Qwen3-Embedding` *(external or unknown)*

### [repo-varshith-Git-Valori-Kernel](_per_source/repo-varshith-Git-Valori-Kernel.md) (density 3)

- → `repo-thinking-machines-lab-batch_invariant_ops` [d5]
- → `paper-1106.4374` [d5]

### [article-alchemistaccelerator-blog-bridgefy-the-offline-messaging-app-revolutioni](_per_source/article-alchemistaccelerator-blog-bridgefy-the-offline-messaging-app-revolutioni.md) (density 2)

- → `docs-bridgefy-sdk` [d3] — Bridgefy SDK reference

### [article-businessmodelcanvastemplate-blogs-how-it-works-ditto-how-it-works](_per_source/article-businessmodelcanvastemplate-blogs-how-it-works-ditto-how-it-works.md) (density 2)

- → `docs-ditto-live` [d5] — primary
- → `article-ditto-blog-getting-started-with-bluetooth-file-sync` [d4]
- → `article-dev-to-biozal-transport-multiplexing-in-mobile-sync-why-multi-trans` [d5]
- → `docs-mesh-networking-101` [d1]

### [article-cleanlab-blog-structured-output-benchmark](_per_source/article-cleanlab-blog-structured-output-benchmark.md) (density 2)

- → `paper-2412.04922` [d3] — LLM ingredient substitution
- → `paper-2505.14992` [d3] — on-device structured extraction

### [article-firecrawl-blog-best-vector-databases](_per_source/article-firecrawl-blog-best-vector-databases.md) (density 2)

- → `article-inductivee-blog-vector-database-performance-benchmarks-2025` [d2] — narrower 5-database benchmark

### [article-inductivee-blog-vector-database-performance-benchmarks-2025](_per_source/article-inductivee-blog-vector-database-performance-benchmarks-2025.md) (density 2)

- → `article-firecrawl-blog-best-vector-databases` [d2] — parallel landscape survey, more vendors
- → `paper-2301.07788` [d5] — RTT floor that bounds cloud-side benchmarks

### [docs-developer-apple-documentation-coreml-mlcomputeunits](_per_source/docs-developer-apple-documentation-coreml-mlcomputeunits.md) (density 2)

- → `docs-apphub-qualcomm-docs-hub-quantize-examples-html` [d3]
- → `docs-developer-apple-documentation-foundationmodels` [d4]
- → `paper-2506.09501` [d3] — Numerical sources of nondeterminism

### [docs-docs-ditto-live-home-faq](_per_source/docs-docs-ditto-live-home-faq.md) (density 2)

- → `docs-docs-ditto-live-home-about-ditto` [d4]
- → `docs-docs-ditto-live-dql-dql` [d4]

### [docs-docs-ditto-live-v4-5-faq](_per_source/docs-docs-ditto-live-v4-5-faq.md) (density 2)

- → `docs-docs-ditto-live` [d5] — top-level
- → `docs-docs-ditto-live-sdk-latest-release-notes-java` [d3] — current v5 release notes supersede this

### [hf-litert-community-Gemma2-2B-IT](_per_source/hf-litert-community-Gemma2-2B-IT.md) (density 2)

- → `hf-google-gemma-2-2b-it` [d4] — upstream model card
- → `hf-litert-community-Gemma3-1B-IT` [d2] — 1B sibling in LiteRT packaging
- → `hf-litert-community-embeddinggemma-300m` [d2] — LiteRT embed variant

### [hf-litert-community-Gemma3-1B-IT](_per_source/hf-litert-community-Gemma3-1B-IT.md) (density 2)

- → `hf-google-gemma-3-1b-it` [d4] — upstream model card
- → `hf-litert-community-Gemma2-2B-IT` [d2] — sibling LiteRT package

### [hf-litert-community-embeddinggemma-300m](_per_source/hf-litert-community-embeddinggemma-300m.md) (density 2)

- → `hf-google-embeddinggemma-300m` [d5] — upstream model card
- → `hf-unsloth-embeddinggemma-300m-GGUF` [d2] — parallel GGUF mobile variant

### [hf-unsloth-embeddinggemma-300m-GGUF](_per_source/hf-unsloth-embeddinggemma-300m-GGUF.md) (density 2)

- → `hf-google-embeddinggemma-300m` [d5] — upstream FP16 weights
- → `hf-litert-community-embeddinggemma-300m` [d2] — parallel LiteRT mobile variant

### [other-airbyte-data-engineering-resources-qdrant-vs-pinecone](_per_source/other-airbyte-data-engineering-resources-qdrant-vs-pinecone.md) (density 2)

- → `other-app-daily-posts-pgvector-vs-pinecone-vs-turbopuffer-vs-qdrant-2026-m1d` [d2] — sibling vector DB comparison

### [other-app-daily-posts-pgvector-vs-pinecone-vs-turbopuffer-vs-qdrant-2026-m1d](_per_source/other-app-daily-posts-pgvector-vs-pinecone-vs-turbopuffer-vs-qdrant-2026-m1d.md) (density 2)

- → `other-airbyte-data-engineering-resources-qdrant-vs-pinecone` [d2] — sibling cloud vector DB comparison

### [other-gorilla-cs-berkeley-edu-leaderboard-html](_per_source/other-gorilla-cs-berkeley-edu-leaderboard-html.md) (density 2)

- → `other-ascentcore-2026-04-01-small-llm-performance-benchmark` [d5] — JSON schema compliance for small LLMs

### [other-inkandswitch-malleable-software](_per_source/other-inkandswitch-malleable-software.md) (density 2)

- → `other-inkandswitch-essay-local-first` [d5]

### [other-revealjs](_per_source/other-revealjs.md) (density 2)

- → `other-raw-githubusercontent-mfontanini-presenterm-master-examples-demo-md` [d3] — the chosen alternative

### [paper-1811.10737](_per_source/paper-1811.10737.md) (density 2)

- → `paper-2006.02859` [d2] — 5G transport latency floor for mobile

### [paper-2006.02859](_per_source/paper-2006.02859.md) (density 2)

- → `paper-1811.10737` [d2] — Internet fiber latency floor

### [repo-github-ggml-org-llama-cpp-issues-2838](_per_source/repo-github-ggml-org-llama-cpp-issues-2838.md) (density 2)

- → `repo-github-ggml-org-llama-cpp-discussions-2658` [d3]
- → `repo-github-ggml-org-llama-cpp-issues-22926` [d3]

### [repo-github-google-nearby-issues-1720](_per_source/repo-github-google-nearby-issues-1720.md) (density 2)

- → `docs-ditto-live` [d5]
- → `docs-mesh-networking-101` [d1]

### [repo-hakimel-reveal.js](_per_source/repo-hakimel-reveal.js.md) (density 2)

- → `repo-github-mfontanini-presenterm-tree-master-examples` [d5]

### [repo-slidevjs-slidev](_per_source/repo-slidevjs-slidev.md) (density 2)

- → `None` *(external or unknown)* — explicitly; adjacent to presentation aesthetics research task only

### [docs-mesh-networking-101](_per_source/docs-mesh-networking-101.md) (density 1)

- → `docs-developer-apple-com` [d3] — concrete iOS API constraints on mesh formation

### [other-harrisjose-notes](_per_source/other-harrisjose-notes.md) (density 1)

- → `other-evilmartians-chronicles-recapping-the-first-local-first-conference-in-15-` [d4] — Local-First Conf 2024 recap

### [other-inkandswitch-local-first](_per_source/other-inkandswitch-local-first.md) (density 1)

- → `other-inkandswitch-essay-local-first` [d5] — canonical target

### [other-llama-llama3-1-license](_per_source/other-llama-llama3-1-license.md) (density 1)

- → `other-llama-llama3-2-license` [d1] — same license family, same blocking pattern
- → `huggingface.co-meta-llama-Llama-3.2-1B-Instruct` *(external or unknown)* — and -3B-Instruct (model cards)

### [other-llama-llama3-2-license](_per_source/other-llama-llama3-2-license.md) (density 1)

- → `other-llama-llama3-1-license` [d1] — same family, same blocking
- → `huggingface.co-meta-llama-Llama-3.2-1B-Instruct` *(external or unknown)*
- → `huggingface.co-meta-llama-Llama-3.2-3B-Instruct` *(external or unknown)*

### [other-reddit-r-deeplearning-comments-1kbucat-cactus-framework-for-ondevic](_per_source/other-reddit-r-deeplearning-comments-1kbucat-cactus-framework-for-ondevic.md) (density 1)

- → `other-ycombinator-companies-cactus` [d4] — Cactus YC company profile
- → `cactuscompute.com` *(external or unknown)* — Cactus marketing/docs site
- → `huggingface.co-Cactus-Compute` *(external or unknown)* — Cactus model org page

### [other-reddit-r-localllama-comments-19f9z64-running-a-local-model-with-8gb](_per_source/other-reddit-r-localllama-comments-19f9z64-running-a-local-model-with-8gb.md) (density 1)

- → `arXiv` *(external or unknown)* — 2403.12844 (MELT) and 2406.10290 (MobileAIBench) for actual mobile-LLM benchmark numbers

### [other-reddit-r-python-comments-1qlx02c-generate-openai-embeddings-locally](_per_source/other-reddit-r-python-comments-1qlx02c-generate-openai-embeddings-locally.md) (density 1)

- → `huggingface.co-sentence-transformers-all-MiniLM-L6-v2` *(external or unknown)*
- → `discuss.huggingface.co` *(external or unknown)* — on-device sentence embeddings thread

### [other-reddit-r-rust-comments-gyeaik-this-month-in-rustsim-11-april-may-20](_per_source/other-reddit-r-rust-comments-gyeaik-this-month-in-rustsim-11-april-may-20.md) (density 1)

- → `gafferongames.com-post-floating_point_determinism` *(external or unknown)*
- → `other-reddit-r-unity3d-comments-lkxb9d-crossplatform-deterministic-physic` [d1] — sibling blocked source

### [other-reddit-r-unity3d-comments-lkxb9d-crossplatform-deterministic-physic](_per_source/other-reddit-r-unity3d-comments-lkxb9d-crossplatform-deterministic-physic.md) (density 1)

- → `gafferongames.com-post-floating_point_determinism` *(external or unknown)* — canonical writeup of the same topic
- → `other-tensorflow-api-docs-python-tf-config-experimental-enable-op-determinism` [d3]

## Most-cited sources (foundational)

Targets ranked by how many other sources reference them. High counts here mean "the rest of the corpus orbits this source" — read these first if you're onboarding.

### Resolved targets (have per-source files)

- **[paper-1106.4374](_per_source/paper-1106.4374.md)** (20 citations) — Conflict-free Replicated Data Types (CRDTs)
- **[paper-2509.20354](_per_source/paper-2509.20354.md)** (10 citations) — Deterministic Embeddings and Reproducible Semantic Search
- **[docs-ditto-live](_per_source/docs-ditto-live.md)** (9 citations) — Ditto Live Documentation: Syncing Data
- **[docs-docs-ditto-live](_per_source/docs-docs-ditto-live.md)** (9 citations) — Ditto Mesh Documentation
- **[paper-2403.12844](_per_source/paper-2403.12844.md)** (8 citations) — MELTing point: Mobile Evaluation of Language Transformers
- **[paper-2402.01613](_per_source/paper-2402.01613.md)** (8 citations) — Embeddings and Determinism in Small Language Models
- **[paper-2402.14905](_per_source/paper-2402.14905.md)** (8 citations) — MobileLLM: Optimizing Sub-billion Parameter Language Models for On-Device Use Cases
- **[paper-2506.09501](_per_source/paper-2506.09501.md)** (7 citations) — Conflict-Free Vector Indices for Collaborative Mesh Systems
- **[docs-mesh-networking-101](_per_source/docs-mesh-networking-101.md)** (7 citations) — Mesh Networking 101: Topology, Routing, and Resilience
- **[hf-blog-rshemet-cactus-on-device-inference](_per_source/hf-blog-rshemet-cactus-on-device-inference.md)** (6 citations) — Cactus: High-Performance AI Inference on Any Smartphone
- **[docs-docs-ditto-live-home-about-ditto](_per_source/docs-docs-ditto-live-home-about-ditto.md)** (6 citations) — What is Ditto? (About Ditto)
- **[hf-Qwen-Qwen2.5-1.5B-Instruct](_per_source/hf-Qwen-Qwen2.5-1.5B-Instruct.md)** (6 citations) — Qwen/Qwen2.5-1.5B-Instruct
- **[other-ditto-platform-edge-sync](_per_source/other-ditto-platform-edge-sync.md)** (6 citations) — Ditto Edge Sync Platform
- **[paper-2406.10290](_per_source/paper-2406.10290.md)** (5 citations) — MobileAIBench: Benchmarking LLMs and LMMs for On-Device Use Cases
- **[docs-cactuscompute-docs-v1-7](_per_source/docs-cactuscompute-docs-v1-7.md)** (5 citations) — Cactus Compute Documentation (v1.7)
- **[hf-Qwen-Qwen3-Embedding-0.6B](_per_source/hf-Qwen-Qwen3-Embedding-0.6B.md)** (5 citations) — Qwen/Qwen3-Embedding-0.6B
- **[hf-google-embeddinggemma-300m](_per_source/hf-google-embeddinggemma-300m.md)** (5 citations) — google/embeddinggemma-300m
- **[other-raw-githubusercontent-cactus-compute-cactus-main-docs-cactus-engine-md](_per_source/other-raw-githubusercontent-cactus-compute-cactus-main-docs-cactus-engine-md.md)** (5 citations) — Cactus Engine FFI Documentation
- **[paper-2411.09944](_per_source/paper-2411.09944.md)** (5 citations) — SlimLM: An Efficient Small Language Model for On-Device Document Assistance
- **[article-ai-google-edge-mediapipe-solutions-genai-llm-inference](_per_source/article-ai-google-edge-mediapipe-solutions-genai-llm-inference.md)** (4 citations) — MediaPipe LLM Inference guide (overview)
- **[paper-2507.01079](_per_source/paper-2507.01079.md)** (4 citations) — MobileRAG: A Fast, Memory-Efficient, and Energy-Efficient Method for On-Device RAG
- **[docs-docs-ditto-live-dql](_per_source/docs-docs-ditto-live-dql.md)** (4 citations) — Ditto Query Language (DQL): Distributed Data Query and Synchronization
- **[article-ditto-blog-dittos-delta-state-crdts](_per_source/article-ditto-blog-dittos-delta-state-crdts.md)** (4 citations) — An Inside Look at Ditto's Delta State CRDTs
- **[hf-google-gemma-2-2b-it](_per_source/hf-google-gemma-2-2b-it.md)** (4 citations) — google/gemma-2-2b-it
- **[repo-github-cactus-compute-cactus-docs-cactus-engine-md](_per_source/repo-github-cactus-compute-cactus-docs-cactus-engine-md.md)** (4 citations) — Cactus Engine (docs/cactus_engine.md)
- **[repo-thinking-machines-lab-batch_invariant_ops](_per_source/repo-thinking-machines-lab-batch_invariant_ops.md)** (4 citations) — thinking-machines-lab/batch_invariant_ops
- **[article-ai-google-edge-mediapipe-solutions-genai-llm-inference-android](_per_source/article-ai-google-edge-mediapipe-solutions-genai-llm-inference-android.md)** (3 citations) — MediaPipe LLM Inference guide for Android
- **[article-ai-google-edge-mediapipe-solutions-genai-llm-inference-ios](_per_source/article-ai-google-edge-mediapipe-solutions-genai-llm-inference-ios.md)** (3 citations) — MediaPipe LLM Inference guide for iOS
- **[docs-bridgefy-sdk](_per_source/docs-bridgefy-sdk.md)** (3 citations) — Bridgefy SDK — On-device AI + Mesh Networking
- **[paper-2412.04922](_per_source/paper-2412.04922.md)** (3 citations) — Approximate Nearest Neighbor Search for Distributed Vector Indices

### Unresolved targets (referenced but no per-source file in the corpus)

These are sources flagged in cross-references that did not make it into `_per_source/` — usually because they are mentioned in passing rather than reviewed in full. Useful as a follow-up reading list.

- `None` (5 citations)
- `thinkingmachines.ai` (3 citations)
- `gafferongames.com-post-floating_point_determinism` (3 citations)
- `repo-mlc-ai__mlc-llm` (3 citations)
- `url-https-thinkingmachines-ai-blog-defeating-nondeterminism-in-llm-inference` (3 citations)
- `article-ditto-blog-how-to-build-robust-offline-first-apps` (2 citations)
- `github-cactus-compute-cactus` (2 citations)
- `cactus-engine` (2 citations)
- `other-evilmartians-chronicles-recapping-the-first-local-first-conference-in-15-minutes` (2 citations)
- `paper-2305.00583` (2 citations)
- `huggingface.co-meta-llama-Llama-3.2-1B-Instruct` (2 citations)
- `maggieappleton.com-home-cooked-software` (2 citations)
- `airbyte.com-data-engineering-resources-qdrant-vs-pinecone` (2 citations)
- `cactuscompute.com` (2 citations)
- `huggingface.co-Cactus-Compute` (2 citations)
- `arXiv` (2 citations)
- `hpbn.co-primer-on-latency-and-bandwidth` (2 citations)
- `repo-DeveloperMindset-com-faiss-mobile` (2 citations)
- `repo-github-ggml-org-llama-cpp-issues-16016` (2 citations)
- `article-www-ditto-blog-dittos-delta-state-crdts` (1 citations)
