# Earthstar: Distributed Storage Protocol for P2P Networks

- **Source ID:** repo-earthstar-project-earthstar
- **Kind:** repo
- **Path:** inspiration/repos/earthstar-project__earthstar
- **Density:** 4

## Elevator summary

Earthstar is a small, resilient distributed-storage protocol with a TypeScript reference implementation that enables P2P applications with offline editing, ephemeral documents, and append-only replica drivers. It provides a CRDT-like sync model without full CRDT overhead, supporting discovery (LAN-based), multi-replica sync, and storage abstraction across browsers, Deno, and Node — offering a direct architectural precedent for how to structure on-device document sync in Mesh RAG, though it does not expose vector-index merge semantics.

## Tags

`crdt-adjacent`, `distributed-storage`, `p2p-sync`, `ephemeral-documents`, `replica-model`, `typescript`, `append-only`

## Topics covered

1. Replica driver abstraction: filesystem, IndexedDB, in-memory, with document and attachment sub-drivers
2. Share and author keypairs: asymmetric cryptography for write authorization and share membership
3. Document querying: path-based filtering, history modes, ephemeral lifetime
4. Peer sync protocol and state-vector based sync (computing diffs)
5. Discovery LAN for local peer auto-discovery

## What we'd take from this

- Replica and driver abstraction patterns: the dual doc-driver + attachment-driver split is a useful model for separating metadata (tuple set) from large content (embeddings)
- State-vector sync model (encodeStateAsUpdate / encodeStateVector) as a reference for "compute only diffs" efficiency
- Ephemeral document model: if we want temporary scratch space for intermediate retrieval results, this pattern is proven
- Open-source reference: if Ditto integration hits friction, Earthstar provides an alternative P2P foundation (though without BLE in v11 beta)

## Cross-references (optional)

- repo-yjs__yjs (alternative CRDT; Earthstar is lighter-weight)
