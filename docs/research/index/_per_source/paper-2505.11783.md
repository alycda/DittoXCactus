# Efficient Vector Search on Disaggregated Memory with d-HNSW

- **Source ID:** paper-2505.11783
- **Kind:** paper
- **Path:** inspiration/papers/2505.11783.pdf
- **Density:** 1

## Elevator summary

Liu, Fang, and Qian (May 2025) introduce d-HNSW, a disaggregated HNSW design for RDMA-based remote memory systems that handles vector datasets too large for a single machine. The contribution is server-class: representative-index caching, RDMA-friendly layout, batched query-aware data loading. Almost entirely off-topic for Mesh RAG — we are mobile, BLE-transported, ≤5k vectors per device, and explicitly avoiding HNSW concurrency issues by using flat-array brute force.

## Tags

`hnsw`, `disaggregated-memory`, `rdma`, `server-class`, `large-scale-vector-search`, `off-topic`

## Topics covered

1. Disaggregating the HNSW data structure across memory and compute pools
2. RDMA-friendly data layout for vector indexes
3. Representative-index caching as a compute-pool optimization
4. Latency benchmarking on SIFT1M

## What we'd take from this

- Negative example: this is what "scale-up vector search" looks like — RDMA, memory pools, 117× speedups. It is exactly the world Mesh RAG is *not* in. Useful as a reference point in the writeup to underscore "we are in a fundamentally different regime."

## Cross-references

- (none directly applicable)

## Caveat

This summary is based on the arxiv abstract (fetched May 2026), not a direct read of the PDF (poppler-utils not installed in the indexing environment). Density was downgraded from the Haiku worker's hallucinated 5 to a realistic 1 — this paper is far from Mesh RAG's scope.
