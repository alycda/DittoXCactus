# Deterministic Transformer Inference Across Hardware

- **Source ID:** paper-2402.00841
- **Kind:** paper
- **Path:** inspiration/papers/2402.00841.pdf
- **Density:** 5

## Elevator summary

Addresses numerical reproducibility and bit-equivalent outputs in transformer inference across CPU, GPU, and accelerator backends—the exact problem blocking Mesh RAG's cross-platform embedding determinism claim. Settles whether Cactus can deliver identical embeddings on iOS (Apple Neural Engine) vs. Android (Qualcomm/MediaTek NPUs). Critical for validating the core technical claim that two devices produce the same vector for the same text.

## Tags

`determinism`, `transformer-inference`, `cross-platform`, `embedding-reproducibility`, `on-device-llm`, `numerical-precision`

## Topics covered

1. Floating-point representation variance across hardware backends
2. GPU vs. CPU cumulative rounding error in transformer layers
3. Accelerator-specific precision modes and their impact on output stability
4. Testing strategies for verifying bit-equivalent reproducibility

## What we'd take from this

- Concrete test recipes for checking cosine similarity >= 0.999 between iOS and Android embeddings (Holdout 2 in SEED.md)
- Understanding of which tensor operations are determinism-bottlenecks (normalization, attention matmul)
- Vendor-specific workarounds (e.g., Apple's float-precision options, Qualcomm DSP quirks)

## Cross-references

- paper-2506.05176 (Qwen3 Embedding model spec)
- Cactus official documentation (implicit reference for implementation details)
