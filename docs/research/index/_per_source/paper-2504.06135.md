# Decentralizing AI Memory: SHIMI, a Semantic Hierarchical Memory Index for Scalable Agent Reasoning

- **Source ID:** paper-2504.06135
- **Kind:** paper
- **Path:** inspiration/papers/2504.06135.pdf
- **Density:** 5

## Elevator summary

SHIMI proposes a decentralized semantic memory architecture where agents maintain local hierarchical concept trees and synchronize asynchronously using CRDT-style conflict resolution and Merkle-DAG summaries. The system models knowledge retrieval by semantic meaning rather than surface similarity, directly addressing the core challenge of Mesh RAG: enabling distributed agents to share and retrieve context without centralized indexes. The lightweight sync protocol enables partial synchronization with minimal bandwidth overhead.

## Tags

`crdt`, `semantic-memory`, `hierarchical-indexing`, `decentralized-rag`, `merkle-dag`, `conflict-resolution`, `agent-reasoning`

## Topics covered

1. Semantic hierarchical memory architecture for distributed agents
2. CRDT-style synchronization protocol with Merkle-DAG summaries
3. Bloom filter optimization for memory synchronization bandwidth
4. Meaning-based retrieval via concept hierarchy traversal
5. Asynchronous agent coordination without central broker

## What we'd take from this

- The hierarchical memory model: how to structure knowledge as layered semantic nodes for top-down traversal from intent to entities
- The sync protocol in Section 4: Merkle-DAG construction, Bloom filter differential sync, and conflict resolution semantics
- The decentralized architecture patterns: local trees with async partial-sync gossip, enabling agents to maintain divergent but consistent views
- The semantic indexing strategy: concept hierarchy enables meaning-based retrieval more precise than vector-only approaches

## Cross-references (optional)

- repo-asg017-sqlite-vec (vector indexing infrastructure)
- repo-n0-computer-iroh (p2p sync transport)
