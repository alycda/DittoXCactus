# Qwen3 Embedding (Official Repository)

- **Source ID:** repo-qwenlm-qwen3-embedding
- **Kind:** repo
- **Path:** inspiration/repos/QwenLM__Qwen3-Embedding
- **Density:** 4

## Elevator summary

Official Qwen3 Embedding repository with model weights, inference code, and integration examples for Transformers, vLLM, and Sentence Transformers. Provides the reference implementation for on-device embedding inference, including determinism guarantees and instruction-based customization. Direct practical resource for integrating into Cactus or validating cross-platform consistency.

## Tags

`embedding-inference`, `transformers-compatible`, `vllm-support`, `instruction-aware`, `quantization`, `model-weights`

## Topics covered

1. Model loading and inference across Transformers, vLLM, and Sentence Transformers
2. Instruction-aware embedding queries with task-specific prompting
3. Reranker models (0.6B, 4B, 8B variants) for retrieval refinement
4. Configuration for flexible output dimensions via MRL support

## What we'd take from this

- Complete inference recipe for embedding a corpus on mobile (Transformers example at lines 70–137)
- Instruction formulation for "recipe retrieval" task to optimize Qwen3 on the demo corpus
- Reranker integration (optional Stage 1 feature for improving top-k quality post-sync)
- Last-token-pooling + cosine-normalization pattern directly applicable to on-device embedding

## Cross-references

- paper-2506.05176 (Qwen3 Embedding paper)
