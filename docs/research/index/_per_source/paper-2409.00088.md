# On-Device Small LLM Inference & Latency Characterization

- **Source ID:** paper-2409.00088
- **Kind:** paper
- **Path:** inspiration/papers/2409.00088.pdf
- **Density:** 3

## Elevator summary

Benchmarks end-to-end latency for small language models (1B–3B parameters) on mobile hardware, directly informing the choice of on-device LLM for Mesh RAG's synthesis stage. Provides empirical data on cold-load time, token-generation latency, and quality tradeoffs—critical for meeting Holdout 5's ~10s target on mid-range Android. Validates whether a small generalist LLM can coherently merge structured recipe lists post-sync.

## Tags

`on-device-llm`, `mobile-latency`, `small-models`, `inference-benchmark`, `cold-start`, `edge-ai`

## Topics covered

1. Token-generation latency across Snapdragon, Bionic, and Apple Neural Engine
2. Model-quantization effects (int8, int4) on quality and speed
3. Cold-load latency including model initialization and memory mapping
4. Quality evaluation of 1B–3B models on structured aggregation tasks

## What we'd take from this

- Empirical latency floor for 3B-param LLM synthesis on mid-range Android (gates the model choice in Cactus)
- Cold-load latency breakdown (model load vs. first inference) for budgeting against the ~10s target
- Quality measurements on list-aggregation / recipe-merging tasks at different model scales—essential for corpus-choice validation

## Cross-references

- repo-qwenlm-qwen3-embedding (embeddings + reranking pipeline)
