# DittoPOS: Point-of-Sale Demo App

- **Source ID:** repo-getditto-demoapp-pos-kds
- **Kind:** repo
- **Path:** inspiration/repos/getditto__demoapp-pos-kds
- **Density:** 5

## Elevator summary

Ditto's official demo app for iOS and Android showcasing real-time order sync across devices (POS + Kitchen Display System) using Ditto's CRDT mesh without cloud connectivity. This is the closest production reference for cross-platform BLE mesh sync, multi-device state coherence, and the UX patterns we need for the "moment of magic" demo. Direct learning path for Ditto SDK integration.

## Tags

`ditto-official`, `mesh-sync`, `crdt-application`, `ios-android`, `real-time-collaboration`, `pos-system`

## Topics covered

1. Ditto SDK initialization and mesh configuration
2. CRDT document model (orders, transactions, status)
3. Cross-device synchronization without central server
4. Real-time UI updates on data sync
5. Location-scoped data partitioning

## What we'd take from this

- The exact Ditto SDK seam: how to initialize, how to define documents, how to query and listen for changes.
- The CRDT document design for state that must merge correctly: order status, transaction IDs, location hierarchy.
- UI pattern for "mesh connected" indicator and "devices in sync" feedback (critical for our demo).
- Proof that iOS ↔ Android sync via BLE is production-ready at Ditto's hands.
- Template for how to scope data by location (our equivalent: scope by recipe or by peer).

## Cross-references

- docs-docs-ditto-live (authoritative docs on Ditto's CRDT model and mesh)
