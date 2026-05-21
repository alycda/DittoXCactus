# MobileRAG: A Fast, Memory-Efficient, and Energy-Efficient Method for On-Device RAG

- **Source ID:** paper-2507.01079
- **Kind:** paper
- **Path:** inspiration/papers/2507.01079.pdf
- **Density:** 5

## Elevator summary

MobileRAG measures end-to-end on-device RAG (EcoVector ANN + SCR selective reduction) on real phones, demonstrating 1.72–8.89x retrieval-latency speedup and 10.7–54.5% memory reduction over baselines. This is the single most load-bearing source for the Mesh RAG implementation: it validates both the latency argument and shows exactly what the local hot path should look like.

## Tags

`on-device-rag`, `mobile-latency`, `memory-efficiency`, `energy-efficiency`, `vector-search`, `anaphoric-search`

## Topics covered

1. EcoVector: efficient ANN index for mobile
2. Selective content reduction (SCR) for memory bounds
3. Energy and latency measurements across real iPhone and Android devices
4. Trade-offs between recall, latency, and power consumption

## What we'd take from this

- The latency numbers: embedding + top-k search + LLM inference totals 20-50ms on modern phones; this is our design target.
- Memory reduction techniques (selective chunking, quantization) directly map to our Ditto tuple compression strategy.
- The energy measurement framework shows that on-device paths are not just faster but also more power-efficient than cloud round-trips.
- Concrete evidence that the stage-0 flat-array approach (linear cosine scan) is defensible at ≤5k tuples without HNSW complexity.

## Cross-references

- paper-2412.21023 (EdgeRAG — related edge-device acceleration work)
- repo-mlc-ai__mlc-llm (MLC backend used in mobile RAG systems)
