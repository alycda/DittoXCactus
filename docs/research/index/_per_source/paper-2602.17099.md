# Understanding and Mitigating Numerical Sources of Nondeterminism in LLMs

- **Source ID:** paper-2602.17099
- **Kind:** paper
- **Path:** inspiration/papers/2602.17099.pdf
- **Density:** 5

## Elevator summary

This paper quantifies floating-point precision effects on LLM inference non-determinism across FP32, FP16, and BF16, establishing that integer-quantized (INT4/INT8) inference paths are significantly more reproducible than floating-point ones. It is load-bearing for Mesh RAG's embedding-determinism holdout, providing empirical evidence that quantized integer models running the same kernel on both phones can achieve bitwise-identical outputs within the cosine-similarity tolerance required for tuple deduplication.

## Tags

`determinism`, `numerical-reproducibility`, `quantization`, `integer-arithmetic`, `fp-precision`, `cross-platform-inference`

## Topics covered

1. Quantitative analysis of FP32 vs FP16 vs BF16 divergence under identical computation
2. Integer quantization (INT4, INT8) as a reproducibility strategy vs floating-point alternatives
3. Hardware-specific divergence (GPU vs CPU vs accelerators) under FP arithmetic
4. Batch-size and order-dependent non-determinism in reductions
5. Practical guidance for reproducible on-device inference

## What we'd take from this

- Empirical proof that INT4/INT8 quantized integer paths are far more stable across hardware than FP16/BF16
- Methodology for measuring determinism: cosine distance under repeated runs, cross-device divergence bounds
- Framework for predicting which Cactus kernel selections (CPU vs Vulkan vs ANE backend) are likely to diverge
- Actionable guidance: if Cactus uses INT4 GGUF + same kernel, cosine >= 0.999 across iOS/Android is plausible; FP16 is not

## Cross-references (optional)

- paper-2506.09501 (complementary quantization-and-reproducibility study)
