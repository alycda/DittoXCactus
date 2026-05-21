# USearch: Fast Vector Similarity Search for Constrained Environments

- **Source ID:** repo-unum-cloud-usearch
- **Kind:** repo
- **Path:** inspiration/repos/unum-cloud__usearch
- **Density:** 4

## Elevator summary

USearch is a single-header C++11 HNSW vector search library optimized for speed, memory efficiency, and portability across languages (Python, Rust, JavaScript, etc.). It enables 10x faster indexing than FAISS on modest hardware and supports quantization + custom metrics. USearch directly solves the peer-local retrieval problem: peers build compact indices in-memory or on-disk, search with custom filtering predicates, and serve results to local queries without network latency.

## Tags

`vector-search`, `hnsw`, `approximate-nearest-neighbor`, `quantization`, `portable`, `single-file`, `user-defined-metrics`

## Topics covered

1. HNSW algorithm with configurable connectivity and expansion parameters
2. Quantization to f16, bf16, int8, or binary for memory efficiency (37.5% reduction with uint40_t IDs)
3. User-defined metrics and JIT compilation for custom similarity functions
4. Heterogeneous lookups, filtering predicates, and semantic joins
5. Clustering and hierarchical indexing for billions of vectors
6. Multi-index parallel search for federated query across shards

## What we'd take from this

- Portability: same precompiled index works across Python, Rust, JavaScript — peers in different languages can share indices
- Quantization: int8 reduces index size 4x with <1% recall loss — critical for mobile peers
- User-defined metrics: peers can apply peer-specific scoring (e.g., trust weights, recency boosting) during search without re-indexing
- Filtered search: predicates enable access control (only search docs peer has permission to see) without building separate indices
- Single-file serialization: save/load via binary format, compatible with version control and content addressing

## Cross-references (optional)

- repo-deepsense-ai-edge-slm (uses USearch-like functionality for retrieval)
- paper-2404.14219 (quantization and efficiency)
