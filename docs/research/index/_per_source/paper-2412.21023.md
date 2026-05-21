# EdgeRAG: Edge-Device Retrieval-Augmented Generation

- **Source ID:** paper-2412.21023
- **Kind:** paper
- **Path:** inspiration/papers/2412.21023.pdf
- **Density:** 5

## Elevator summary

EdgeRAG demonstrates end-to-end on-device RAG with 131% retrieval-latency improvement vs CPU baseline at large vector indexes, showing that accelerated (EdgeTPU/NPU) embedding+search is practical and measurable on real devices. This is direct load-bearing evidence that our on-device RAG latency thesis is empirically grounded and the network round-trip is indeed the moat.

## Tags

`on-device-rag`, `vector-search`, `edge-acceleration`, `embedding-latency`, `retrieval-optimization`, `mobile-inference`

## Topics covered

1. On-device RAG pipeline architecture
2. Accelerator utilization (EdgeTPU/NPU) for embedding and search
3. Latency and memory measurements on real edge devices
4. Comparison against baseline CPU inference

## What we'd take from this

- The concrete numbers: 131% retrieval speedup demonstrates that edges have meaningful acceleration over CPU-only; our flat-array brute force will be in that ballpark or better for ≤5k tuples.
- Empirical validation that on-device embedding + search is the right design point vs cloud-round-trip (which always loses to physics).
- Reference for the "latency floor" argument in the writeup: on-device paths are bounded by local speed, cloud paths are bounded by light-speed propagation + RTT.

## Cross-references

- paper-2507.01079 (MobileRAG — broader on-device RAG measurement including energy)
- repo-mlc-ai__mlc-llm (backend framework for on-device inference)
