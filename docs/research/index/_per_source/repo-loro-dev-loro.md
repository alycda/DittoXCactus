# Loro: CRDT Data Structure Library (Rust + JS + Swift)

- **Source ID:** repo-loro-dev-loro
- **Kind:** repo
- **Path:** inspiration/repos/loro-dev__loro
- **Density:** 3

## Elevator summary

Modern CRDT library with cross-platform bindings (Rust, JS/WASM, Swift) supporting rich data structures (text, tree, list, map) with version control and time-travel. While Mesh RAG uses Ditto's grow-only semantics directly, Loro exemplifies state-of-the-art CRDT composition patterns and Fast Document Loading techniques that could inform future evolution beyond Stage 0's flat grow-only set.

## Tags

`crdt`, `local-first`, `collaborative-editing`, `time-travel`, `version-control`, `cross-platform-bindings`

## Topics covered

1. CRDT algorithms for text (Fugue), tree (movable), list (movable), and map (LWW)
2. Fast document loading via shallow snapshots (Git-like)
3. Time-travel / version control with real-time collaboration
4. Bindings and deployment across Rust, JS, Swift, and Flutter

## What we'd take from this

- The Fugue algorithm for text-CRDT merging (reference for future specialist models handling recipe text)
- Movable-list pattern if Mesh RAG evolves to allow reordering/deletion in Stage 1+
- Bindings pattern for shipping identical CRDT logic across iOS/Android/Flutter platforms
- Examples of CRDT composition for knowledge-store evolution beyond flat grow-only

## Cross-references

- paper-1106.4374 (foundational CRDT theory)
