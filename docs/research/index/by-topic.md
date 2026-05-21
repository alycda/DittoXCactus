# By Topic

> Topic-level lookup. Faster than [clusters.md](clusters.md) when you have a specific sub-question. Topics are coarse — for fine-grained search, use [by-tag.md](by-tag.md).

---

## Mesh sync infrastructure (Ditto + alternatives)

**Use Ditto:** docs-docs-ditto-live, docs-docs-ditto-live-transports, docs-docs-ditto-live-dql, docs-ditto-live, repo-getditto-demoapp-pos-kds, repo-getditto-demoapp-inventory, repo-getditto-demoapp-chat, repo-getditto-samples.

**Alternatives you might benchmark against:** repo-n0-computer-iroh, repo-earthstar-project-willow-rs, repo-earthstar-project-earthstar, repo-permissionlesstech-bitchat, repo-permissionlesstech-bitchat-android, repo-libp2p-go-libp2p, repo-orbitdb-orbitdb, docs-bridgefy-sdk.

**Background:** docs-mesh-networking-101.

## CRDT theory (background; Ditto subsumes the implementation)

paper-1106.4374, paper-2504.06135 (SHIMI), paper-2506.09501, paper-2505.00443, repo-loro-dev-loro, repo-yjs-yjs.

## Embedding determinism / cross-platform numerical reproducibility

paper-2602.17099 (FP precision quantification), paper-2402.00841 (deterministic transformer inference), paper-2402.04351 (numerical stability), paper-2402.01613 (small-model embedding determinism), paper-2509.20354 (deterministic embeddings + reproducible semantic search), repo-thinking-machines-lab-batch-invariant-ops, docs-docs-pytorch-org.

## On-device embedding models

paper-2505.09388 (EmbeddingGemma — top candidate), paper-2506.05176 (Qwen3 Embedding — other top candidate), repo-qwenlm-qwen3-embedding, paper-1908.10084 (Sentence-BERT foundational), repo-ukplab-sentence-transformers.

## On-device LLM inference frameworks

repo-ggml-org-ggml (GGUF + ggml runtime), repo-mlc-ai-mlc-llm (MLC LLM), repo-google-ai-edge-gallery (LiteRT + Gemma). Cactus is the chosen stack but Cactus does not have an inspiration/-resident summary; rely on the Mode B worker outputs for the Cactus-specific findings (`docs/research/claude.md` sections "Cactus engine docs" + "Cactus React Native package").

## On-device LLM benchmarks (model selection)

paper-2403.12844 (MELT — iOS + Android + Jetson), paper-2406.10290 (MobileAIBench — iOS-side instrumentation), paper-2409.00088 (small LLM latency characterization).

## Vector search libraries (Stage 0 = flat array; this is for escape hatch)

repo-asg017-sqlite-vec (sqlite extension, iOS + Android), repo-unum-cloud-usearch (single-header C++ HNSW), repo-spotify-annoy (tree ANN), repo-developermindset-com-faiss-mobile (Faiss mobile port; iOS only), repo-facebookresearch-faiss, paper-2401.02385 (Faiss paper), paper-2404.14219 (vector search + quantization for edge), paper-2412.04922 (ANN for distributed indices).

## HNSW specifically (background / negative examples)

paper-2407.07871 (Real-Time Updates — "unreachable points"), paper-2507.17647 (SHINE — disaggregated), paper-2505.11783 (d-HNSW — disaggregated), paper-2308.14963 (Lucene-HNSW argument).

## End-to-end on-device RAG (reference implementations)

paper-2507.01079 (MobileRAG — measured benchmark), paper-2412.21023 (EdgeRAG — accelerator-aware), paper-2301.07788 (original RAG), repo-deepsense-ai-edge-slm (Android Phi-2 + gte pipeline), repo-ramanujammv1988-edge-veda (Flutter), repo-software-mansion-labs-react-native-rag (React Native modular framework).

## Specialist small models / parameter-efficient adaptation (future-work writeup arc)

paper-2405.00732 (LoRA Land), paper-1910.01108 (DistilBERT), paper-2106.09685 (LoRA original), paper-2505.14992 (schema-aware extraction — closest recipe-merge analog).

## Local-first framing for writeup

paper-2505.00443 (local-first computing principles), docs-developer-apple-com (Apple Foundation Models — on-device patterns from a polished vendor), repo-unickcheng-logseq-ai-assistant (local knowledge + LLM pattern).

## Demo & presentation tooling

repo-mfontanini-presenterm (user-stated primary), repo-slidevjs-slidev, repo-hakimel-reveal-js.

## iOS↔Android BLE-mesh UX references

repo-permissionlesstech-bitchat-android, repo-permissionlesstech-bitchat, repo-getditto-demoapp-pos-kds, repo-getditto-demoapp-inventory.

## Embedding determinism / latency — what the *workers* found that's not in any single per-source file

Cross-reference the Mode B worker outputs:
- `docs/research/claude.md` — the highest-signal pass; full Cactus + Ditto integration analysis, Llama/Gemma license breakdown, latency-floor argument with cloud RTT vs. on-device numbers, four reference architectures with file-level pointers.
- `docs/research/codex.md` — Codex CLI pass; complementary URLs and engineering-blog finds.
- `docs/research/gemini.md` — Gemini CLI pass; thinner due to heavy rate-limiting but distinct angle on latency.
