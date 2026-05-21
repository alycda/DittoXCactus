# Yjs: CRDT Framework for Shared Data Types

- **Source ID:** repo-yjs-yjs
- **Kind:** repo
- **Path:** inspiration/repos/yjs__yjs
- **Density:** 3

## Elevator summary

Yjs is a production CRDT library exposing shared types (Array, Map, Text, XML) with automatic conflict-free merging, offline editing, version snapshots, and an extensive provider ecosystem (WebRTC, WebSocket, persistence backends). It is relevant as a reference CRDT design and alternative to Ditto's delta-state CRDTs, though Mesh RAG selects Ditto for native mobile-BLE support rather than Yjs which targets collaborative editors and web-first environments.

## Tags

`crdt`, `shared-types`, `collaborative-editing`, `offline-editing`, `providers`, `undo-redo`, `network-agnostic`

## Topics covered

1. CRDT algorithm internals: state-based vs operation-based, client ID assignment, causality tracking
2. Shared types: Y.Array, Y.Map, Y.Text with automatic merging and change observation
3. Provider abstraction: network providers (WebRTC, WebSocket, etc.) and persistence providers (IndexedDB, MongoDB, etc.)
4. Document updates: commutative and idempotent encoding, state vectors for efficient sync
5. Bindings ecosystem: ProseMirror, Quill, CodeMirror, Slate, Lexical, Tiptap and 100+ collaborative tools

## What we'd take from this

- CRDT type design patterns: how Y.Array and Y.Map handle concurrent inserts/deletes without merge conflicts — applicable to designing a "RecipeTuple set" type in Ditto if native support is insufficient
- Provider abstraction: the separation of network (y-websocket, y-webrtc) from persistence (y-indexeddb) is a valuable architecture pattern for Mesh RAG
- Offline editing + sync: proven pattern for queuing local changes and merging on reconnection
- Comparison point: where Yjs excels (editor bindings, web ecosystem) vs where Ditto excels (native mobile, BLE) — clarifies the architecture choice

## Cross-references (optional)

- repo-earthstar-project-earthstar (similar P2P / distributed-storage scope; Yjs more CRDT-focused)
