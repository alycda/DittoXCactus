# OrbitDB: CRDT-Based Distributed Database on IPFS

- **Source ID:** repo-orbitdb-orbitdb
- **Kind:** repo
- **Path:** inspiration/repos/orbitdb__orbitdb
- **Density:** 2

## Elevator summary

OrbitDB is a peer-to-peer database using Merkle-CRDTs for conflict-free writes and IPFS/Libp2p for data distribution. It proves that decentralized databases can achieve eventual consistency without central coordination. The OpLog (operation log) foundation is directly applicable to building a distributed vector index: peers append embeddings/documents as CRDT operations, merge automatically, and never corrupt shared state.

## Tags

`crdt`, `peer-to-peer-database`, `ipfs`, `libp2p`, `merkle-crdt`, `conflict-free-replication`, `eventlog`

## Topics covered

1. Merkle-CRDT formalization and operation log (OpLog) implementation
2. Multiple database types (events, documents, keyvalue) all built on OpLog
3. IPFS content addressing and Libp2p pubsub for peer discovery and sync
4. Replication and eventual consistency guarantees
5. Access controllers and encryption support
6. Custom database models via CRDT interface

## What we'd take from this

- OpLog abstraction: Mesh RAG can model a vector index as a sequence of "add embedding" and "add document chunk" operations, replicated via CRDT
- Merkle trees enable efficient sync: only changed branches are transferred between peers, reducing bandwidth for incremental index updates
- Libp2p pubsub allows peers to announce new indexed content, triggering selective replication to interested peers
- Open-source reference for CRDT implementation in JavaScript/Node.js

## Cross-references (optional)

- paper-2505.00443 (local-first and CRDT principles)
