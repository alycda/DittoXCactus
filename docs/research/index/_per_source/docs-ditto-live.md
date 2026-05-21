# Ditto Live Documentation: Syncing Data

- **Source ID:** docs-ditto-live
- **Kind:** docs
- **Path:** inspiration/docs/ditto-live/syncing-data.html
- **Density:** 5

## Elevator summary

Official Ditto documentation covering automatic mesh data synchronization, subscription-based query model, and device mesh fundamentals. Core reference for understanding Ditto's CRDT-based sync protocol that underpins Mesh RAG data consistency. Explains how devices express data interests and manage replication.

## Tags

`ditto`, `crdt`, `data-sync`, `mesh-network`, `subscriptions`, `replication`, `local-first`, `official-docs`

## Topics covered

1. Automatic device synchronization in mesh networks
2. Subscription query model for selective sync
3. CRDT-based conflict resolution
4. Peer discovery and presence management
5. Data consistency guarantees
6. Replication topology and sync efficiency
7. Offline-first architecture patterns

## What we'd take from this

- The subscription model design for expressing which portions of the vector index a peer needs to replicate
- CRDT sync protocol fundamentals for understanding how Mesh RAG index updates propagate across peers
- Ditto's approach to eventual consistency and conflict-free replication, directly applicable to distributed RAG indices
- Best practices for local-first data architecture in mesh networks

## Cross-references

- repo-getditto-demoapp-inventory (practical implementation reference)
- paper-2506.09501 (CRDT theory applicable to vector indices)
