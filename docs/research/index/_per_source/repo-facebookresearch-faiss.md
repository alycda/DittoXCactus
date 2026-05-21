# Faiss

- **Source ID:** repo-facebookresearch-faiss
- **Kind:** repo
- **Path:** inspiration/repos/facebookresearch__faiss
- **Density:** 5

## Elevator summary

The canonical open-source library for efficient similarity search and clustering of dense vectors, developed by Meta's Fundamental AI Research team. Faiss underpins vector databases, retrieval-augmented generation systems, and large-scale search infrastructure. For Mesh RAG, Faiss represents the "centralized, optimized, full-scale" baseline we are redesigning for distributed peer-to-peer operation. Understanding Faiss's index types (IVF, HNSW, quantization strategies) is essential for reasoning about what we *drop* in Stage 0 (ANN complexity) and what we *inherit* in Stage 1+ (approximate search at scale, bitwise stability across platforms).

## Tags

`vector-search`, `similarity-search`, `approximate-nearest-neighbor`, `gpu-acceleration`, `clustering`, `dense-retrieval`, `information-retrieval`

## Topics covered

1. Index construction: IVF, HNSW, LSH, quantization methods
2. GPU acceleration for large-scale search
3. Clustering algorithms (k-means, brute-force)
4. Parameter tuning and evaluation frameworks
5. Python and C++ APIs, benchmarking harness

## What we'd take from this

- Modern vector search separates concerns: (a) index structure (inverted lists, graph, quantization), (b) distance metric (L2, dot product, cosine), (c) search algorithm (exact k-NN or approximate). This modularity lets us swap (a) for "Ditto-synced sorted tuple list" without changing (b) or (c).
- Quantization (product quantization, scalar quantization, binary codes) reduces memory while preserving ranking order; critical for phones where RAM is constrained.
- Multi-GPU and batched-query optimizations in Faiss assume a static index and pre-warmed GPU; a mesh-synced on-device setting needs single-query latency and low memory footprint — orthogonal optimization targets.

## Cross-references (optional)

- paper-2401.02385 (this library's paper)
- repo-unum-cloud-usearch (modern alternative; single-header C++, smaller ecosystem, similar algorithmic core)
- repo-developermindset-com-faiss-mobile (mobile port)
