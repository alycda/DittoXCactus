# Edge Small Language Model: On-Device RAG Pipeline

- **Source ID:** repo-deepsense-ai-edge-slm
- **Kind:** repo
- **Path:** inspiration/repos/deepsense-ai__edge-slm
- **Density:** 4

## Elevator summary

This reference implementation demonstrates a complete RAG pipeline (embedding + retrieval + LLM generation) running on mobile devices (Samsung S20/S24). It uses quantized models (Phi-2, TinyLLama for LLM; gte-base for embeddings) and proves the feasibility of on-device semantic search. The end-to-end demo is directly applicable to Mesh RAG peer implementations.

## Tags

`on-device-llm`, `mobile-rag`, `edge-deployment`, `quantized-inference`, `ggml`, `gte-embeddings`, `android`

## Topics covered

1. Complete RAG system architecture for mobile (embedding → retrieval → generation)
2. Model selection for constrained devices (Phi-2 Q8, TinyLLama Q4, gte-base)
3. GGUF model format and llama.cpp integration
4. Conan build system for cross-platform compilation
5. Android NDK integration for native binary deployment
6. Embedding database format (JSON with pre-computed vectors)

## What we'd take from this

- Demonstrates feasibility: full RAG (embeddings + LLM) on a smartphone proves Mesh RAG is realistic
- GGUF + quantization pattern: use standardized GGUF format for model distribution across peers
- Pre-computed embedding dumps (JSON) allow offline index preparation on fast machines, then deploy to slower peers
- Conan for dependency management across Android, iOS, and desktop

## Cross-references (optional)

- repo-ggml-org-ggml (model format and inference engine)
- repo-unum-cloud-usearch (vector search component)
