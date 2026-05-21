# PyTorch Documentation — Reproducibility

- **Source ID:** docs-docs-pytorch-org
- **Kind:** docs
- **Path:** inspiration/docs/docs.pytorch.org
- **Density:** 2

## Elevator summary

PyTorch's reference documentation on reproducibility in deep learning, including seeding, deterministic algorithms, and platform-specific behavior. For Mesh RAG, this is the canonical resource for understanding the embedding-determinism constraint: if PyTorch-based embedding models diverge across CPU/GPU/Metal backends, our on-device Cactus pipeline will too. The docs quantify the cost-benefit trade-offs (determinism often reduces performance) and enumerate the configuration knobs we must pin to achieve cross-platform cosine parity for embeddings.

## Tags

`reproducibility`, `determinism`, `deep-learning`, `pytorch`, `random-seeds`, `floating-point-arithmetic`

## Topics covered

1. Setting random seeds and reproducibility controls
2. GPU determinism and backwards-compatibility
3. Floating-point arithmetic and precision
4. Platform-specific behavior (CPU vs CUDA vs Metal)
5. Benchmark vs production trade-offs

## What we'd take from this

- Reproducibility requires explicit configuration (seed, deterministic flags, fixed-algorithm selection); it does not happen by default even on the same machine.
- GPU determinism incurs performance penalty; the trade-off is explicit. For Mesh RAG, we accept slower embedding if it gains cross-platform cosine parity.
- Platform-specific quirks (Metal on iOS, Vulkan/OpenCL on Android) require per-backend validation; PyTorch's framework-level docs apply downstream to Cactus, our Cactus selection must validate.

## Cross-references (optional)

- paper-2506.09501 (numerical reproducibility challenges quantified)
- thinkingmachines.ai blog (batch-invariant kernels for deterministic LLM inference)
