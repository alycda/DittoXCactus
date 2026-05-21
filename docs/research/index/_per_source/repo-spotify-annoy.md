# Annoy: Approximate Nearest Neighbors Oh Yeah

- **Source ID:** repo-spotify-annoy
- **Kind:** repo
- **Path:** inspiration/repos/spotify__annoy
- **Density:** 3

## Elevator summary

Annoy is a production-grade ANN library using random-projection trees, optimized for small memory footprint and static index sharing across processes. Relevant as a stage-1 escape hatch if we outgrow the ≤5k tuple flat-array approach and need HNSW-free approximate search, though the current design avoids ANN complexity entirely.

## Tags

`approximate-nearest-neighbors`, `vector-search`, `tree-index`, `memory-efficient`, `static-index`, `spotify`

## Topics covered

1. Locality-sensitive hashing via random projections
2. Forest-of-trees ANN algorithm
3. Multiple distance metrics (Euclidean, cosine, Manhattan, Hamming, dot product)
4. Memory-mapped index files for multi-process sharing
5. Tuning trade-offs: n_trees (precision) vs search_k (latency)

## What we'd take from this

- If we need ANN at >10k tuples: Annoy's random-projection approach is simpler than HNSW and avoids the concurrent-insert correctness mess we inherit with HNSW + CRDT merging.
- The memory-mapped index design is good reference for "offline-first": build the index once, serialize it, share across devices.
- Concrete distance metric implementations (especially cosine for L2-normalized embeddings) if we ever hand-roll indexing.

## Cross-references

- repo-mlc-ai__mlc-llm (vector-search libraries are alternatives to Annoy for embedding retrieval)
