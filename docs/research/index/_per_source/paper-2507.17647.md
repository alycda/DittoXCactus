# SHINE: A Scalable HNSW Index in Disaggregated Memory

- **Source ID:** paper-2507.17647
- **Kind:** paper
- **Path:** inspiration/papers/2507.17647.pdf
- **Density:** 3

## Elevator summary

SHINE extends Hierarchical Navigable Small World (HNSW) graphs to disaggregated memory environments, maintaining accuracy equivalent to single-machine indexes while distributing the index across multiple nodes. The graph-preserving approach is relevant for Mesh RAG's distributed vector search problem, demonstrating how to partition approximate nearest neighbor indexes without sacrificing quality. The methodology informs strategies for balancing local and remote retrieval in peer networks.

## Tags

`approximate-nearest-neighbor`, `hnsw`, `distributed-indexing`, `graph-partitioning`, `vector-search`, `disaggregated-systems`

## Topics covered

1. HNSW graph structure and search navigation
2. Graph-preserving partitioning for distributed environments
3. Accuracy maintenance under index distribution
4. Memory-computation trade-offs in disaggregated architectures
5. Comparison with graph-partitioning approaches

## What we'd take from this

- The graph-preserving index partitioning strategy: how to distribute HNSW edges while maintaining search accuracy
- The quantitative comparison with partitioned approaches: evidence that naive graph partitioning sacrifices too much accuracy
- The insertion and search algorithms for disaggregated graphs (Section 3)
- Guidelines for degree-of-distribution: when local indexing is sufficient vs. when remote peers are beneficial

## Cross-references (optional)

- repo-asg017-sqlite-vec (local vector index implementation)
- paper-2504.06135 (semantic memory hierarchy could complement ANN search)
