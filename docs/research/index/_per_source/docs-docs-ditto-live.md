# Ditto Mesh Documentation

- **Source ID:** docs-docs-ditto-live
- **Kind:** docs
- **Path:** inspiration/docs/docs.ditto.live
- **Density:** 5

## Elevator summary

Official Ditto documentation covering mesh formation, BLE/LAN transport, conflict resolution, DQL (Ditto Query Language), and small-peer model. Load-bearing for Mesh RAG: Ditto is the chosen sync layer; these docs detail the concrete APIs, mesh topology, and CRDT semantics we will rely on for syncing RecipeTuples across iOS and Android.

## Tags

`ditto`, `mesh-sync`, `crdt`, `ble-transport`, `lan-transport`, `query-language`, `small-peer`

## Topics covered

1. Mesh formation and peer discovery (BLE, LAN, cloud fallback)
2. CRDT-based conflict resolution and eventual consistency
3. DQL (SQL-like query language for distributed queries)
4. Offline-first data sync and convergence properties
5. Small-peer model and resource constraints
6. Collection design patterns and canonical examples

## What we'd take from this

- Concrete API surface for storing and querying RecipeTuples
- Mesh topology guarantees and convergence proofs
- Performance profile for small collections (≤5000 items) on mobile
- Integration patterns with iOS (Swift) and Android (Kotlin)

## Cross-references (optional)

- repo-earthstar-project-willow-rs (related CRDT data model)
- repo-permissionlesstech-bitchat (mesh topology and BLE interop)
