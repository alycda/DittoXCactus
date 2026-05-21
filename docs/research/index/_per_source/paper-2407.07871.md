# Enhancing HNSW Index for Real-Time Updates

- **Source ID:** paper-2407.07871
- **Kind:** paper
- **Path:** inspiration/papers/2407.07871.pdf
- **Density:** 4

## Elevator summary

This paper addresses the "unreachable points phenomenon" in HNSW (Hierarchical Navigable Small World) when the index receives concurrent inserts and deletes. HNSW is the standard ANN method for high-dimensional similarity search, but its graph-building invariants degrade under real-time updates on a single replica. For Mesh RAG, this is a cautionary tale: if each peer independently builds an HNSW over a CRDT-merged set, each replica's graph structure can diverge depending on update arrival order, potentially producing different neighbors for identical queries. The paper motivates why we use flat-array brute-force search for Stage 0.

## Tags

`hnsw`, `vector-indexing`, `dynamic-indexing`, `approximate-nearest-neighbor`, `concurrent-updates`, `real-time-retrieval`

## Topics covered

1. HNSW graph construction and neighbor-selection invariants
2. Update/delete operations in dynamic indexes
3. The "unreachable points" phenomenon and its causes
4. Strategies for maintaining index quality during updates
5. Experimental validation on real-time insertion workloads

## What we'd take from this

- HNSW assumes a relatively static index; real-time updates require careful handling to avoid isolated node clusters.
- Multi-replica HNSW with different insertion orders can build different graphs over the same data, leading to inconsistent query results — a CRDT-incompatible property.
- For a mesh-synced index, either (a) commit to flat-array brute-force until convergence is proven, (b) each peer materializes then rebuilds HNSW from the fully-synced frozen snapshot, or (c) investigate HNSW reconstruction cost vs linear-scan speed at our scale (≤5k vectors).

## Cross-references (optional)

- paper-2401.02385 (foundational Faiss/ANN theory)
- repo-unum-cloud-usearch (production ANN library; relevant if Stage 0 scale exceeds brute-force budget)
