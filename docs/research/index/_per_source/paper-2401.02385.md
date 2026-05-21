# The Faiss Library

- **Source ID:** paper-2401.02385
- **Kind:** paper
- **Path:** inspiration/papers/2401.02385.pdf
- **Density:** 5

## Elevator summary

This is the official Faiss library paper (arXiv 2401.08281 / Douze et al., 2024), documenting efficient similarity search and clustering for dense vectors. Faiss underpins modern vector-database infrastructure at scale and is load-bearing for understanding the baseline retrieval system we are decentralizing into a mesh. Mesh RAG must solve the same core problem (k-NN search over embedding collections) but distribute it across peers.

## Tags

`faiss`, `similarity-search`, `vector-indexing`, `approximate-nearest-neighbor`, `clustering`, `gpu-acceleration`, `information-retrieval`

## Topics covered

1. Efficient similarity search algorithms (IVF, HNSW, LSH)
2. Clustering and k-means for vector indexing
3. GPU and CPU implementation strategies
4. Quantization and compression for billion-scale search
5. Index construction, parameter tuning, and evaluation

## What we'd take from this

- Vector search separates into "indexing" (one-time construction) and "search" (query-time k-NN retrieval) — a clean seam for distributing across a CRDT-merged peer collection rather than a centralized index.
- Approximate-nearest-neighbor (ANN) methods trade perfect recall for speed and memory; at our scale (≤5k tuples), exact brute-force cosine is tractable and avoids CRDT merge-order sensitivity.
- Quantization dramatically reduces memory footprint without accuracy loss — relevant for storing normalized embeddings on phone-class devices.

## Cross-references (optional)

- paper-2407.07871 (HNSW concurrent update challenges)
- repo-unum-cloud-usearch (open ANN library for potential Stage-1 escape hatch)
- repo-facebookresearch-faiss (source implementation)
