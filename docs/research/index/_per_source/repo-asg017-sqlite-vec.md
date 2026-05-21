# sqlite-vec: Vector Search SQLite Extension

- **Source ID:** repo-asg017-sqlite-vec
- **Kind:** repo
- **Path:** inspiration/repos/asg017__sqlite-vec
- **Density:** 5

## Elevator summary

sqlite-vec is a lightweight C extension for SQLite that adds float, int8, and binary vector storage and approximate nearest neighbor (KNN) search. With zero external dependencies and WASM support, it runs anywhere SQLite runs—phones, browsers, edge devices. It is the canonical local vector index for Mesh RAG implementations, enabling deterministic, portable embedding storage and retrieval without external search infrastructure.

## Tags

`sqlite-extension`, `vector-search`, `on-device`, `knn-search`, `wasm`, `zero-dependency`, `embedding-storage`

## Topics covered

1. Virtual table implementation for vector storage in SQLite
2. Float and binary vector support with configurable dimensions
3. KNN search via distance-based ordering
4. Metadata and auxiliary column support for hybrid search
5. Cross-platform compatibility: Linux, macOS, Windows, WASM, Raspberry Pi

## What we'd take from this

- The virtual table API pattern: how to extend SQLite with custom storage and search operators
- The KNN query interface (match operator in WHERE clauses): declarative vector search integration with SQL
- The float/int8/binary vector type support: practical guidance on embedding quantization for bandwidth
- The WASM build strategy: achieving runtime portability critical for Mesh RAG peer diversity
- The partnership with Mozilla, Fly.io, Turso: validation that this approach is production-ready

## Cross-references (optional)

- paper-2504.06135 (semantic hierarchy could augment vector search)
- paper-2507.17647 (HNSW graph methods for larger indexes)
