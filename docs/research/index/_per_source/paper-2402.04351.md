# Numerical Stability of Transformer Inference

- **Source ID:** paper-2402.04351
- **Kind:** paper
- **Path:** inspiration/papers/2402.04351.pdf
- **Density:** 4

## Elevator summary

This paper documents numerical divergence in transformer inference across different hardware backends (CPU vs GPU vs specialized accelerators), showing that quantized integer paths are dramatically more reproducible than floating-point variants. Critical for the Mesh RAG embedding-determinism requirement: demonstrates that cross-device cosine parity is achievable only through intentional kernel selection and quantization strategy.

## Tags

`embedding-determinism`, `numerical-stability`, `quantization`, `cross-platform-parity`, `transformer-inference`, `hardware-drift`

## Topics covered

1. Sources of numerical non-determinism in transformer inference
2. Comparison of FP32, FP16, BF16, INT4, INT8 stability across hardware
3. Impact of batch size on kernel divergence
4. Strategies for enforcing reproducible inference

## What we'd take from this

- The empirical finding that INT4/INT8 quantized paths are most stable across hardware tiers (Metal on iOS vs Vulkan on Android).
- The batch-size dependency: single-sample inference (batch=1) is more reproducible than dynamic batching.
- Actionable guidance for pinning Cactus to "same quantization, same backend tier" rather than auto-optimization to sidestep cross-device embedding drift.

## Cross-references

- docs-docs-ditto-live (background on Ditto's CRDT merge requirements for parity-sensitive indexes)
