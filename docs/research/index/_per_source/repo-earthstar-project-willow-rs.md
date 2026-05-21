# Willow Protocol (Rust Implementation)

- **Source ID:** repo-earthstar-project-willow-rs
- **Kind:** repo
- **Path:** inspiration/repos/earthstar-project__willow-rs
- **Density:** 5

## Elevator summary

Rust implementation of the Willow data model and synchronization protocol—a CRDT-backed replicated data store with fine-grained capabilities and destructive edits. Load-bearing for Mesh RAG: Willow's core design (grow-only entries, capability-based access, synchronization primitives) is a reference architecture for storing embeddings as a CRDT across the mesh.

## Tags

`crdt`, `data-model`, `mesh-sync`, `capabilities`, `destructive-edits`, `replicated-store`

## Topics covered

1. Willow Data Model (parameters, paths, entries, groupings, encodings)
2. Meadowcap capability system (adaptable to local needs)
3. Sideloading protocol (eventually consistent delivery)
4. General Purpose Sync protocol (private, efficient synchronization)
5. Store trait and persistent storage implementation (Sled backend)

## What we'd take from this

- Reference implementation of grow-only semantics and entry-based replication
- Capability-based permission model adaptable to recipe-sharing scenarios
- Sideloading and sync protocol design patterns applicable to BLE/LAN mesh
- Fuzz testing strategies for CRDT correctness

## Cross-references (optional)

- docs-docs-ditto-live (similar mesh-sync architecture)
- paper-2505.11783 (distributed indexing over replicated stores)
