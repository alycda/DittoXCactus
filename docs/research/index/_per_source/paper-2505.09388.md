# EmbeddingGemma: Powerful and Lightweight Text Representations

- **Source ID:** paper-2505.09388
- **Kind:** paper
- **Path:** inspiration/papers/2505.09388.pdf
- **Density:** 5

## Elevator summary

EmbeddingGemma is a 308M-parameter multilingual embedding model optimized for mobile deployment, achieving sub-22ms inference on EdgeTPU and sub-200MB quantized footprint while ranking top on MTEB among models under 500M parameters. It is the primary candidate embedding model for Mesh RAG's on-device retrieval pipeline and directly addresses the embedding-determinism requirement: small enough to run on both iOS and Android with cosine-parity testing feasible within the demo scope.

## Tags

`embedding-model`, `mobile-inference`, `matryoshka-dimensions`, `multilingual`, `mteb-benchmark`, `on-device-deployment`, `parameter-efficiency`

## Topics covered

1. Matryoshka dimension scaling: 128–768 dims allow dynamic speed-quality tradeoffs
2. Multilingual cross-lingual transfer and zero-shot generalization
3. Mobile deployment benchmarks: latency and memory on EdgeTPU, CPU, and quantized backends
4. Distillation and compression techniques for embedding models
5. MTEB evaluation: head-to-head comparison with OpenAI text-embedding-3-small and Nomic Embed

## What we'd take from this

- Primary embedding model for Stage 0: EmbeddingGemma's 308M size, Matryoshka dims, and documented EdgeTPU performance make it the strongest open-source candidate for on-device retrieval
- Quantization guidance: Q4/Q8 paths for <200MB mobile footprint and determinism testing baseline
- Cross-platform deployment validation points: if Cactus packages this, cosine-parity measurement across iOS/Android becomes concrete
- Multilingual coverage: recipes span languages; EmbeddingGemma's multilingual training is directly relevant

## Cross-references (optional)

- paper-2509.20354 (prior version or related embedding research)
- paper-2402.01613 (Nomic Embed v1.5 — alternative candidate, less mobile-optimized but referenced for comparison)
