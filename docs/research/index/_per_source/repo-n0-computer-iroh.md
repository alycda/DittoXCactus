# Iroh: less net work for networks

- **Source ID:** repo-n0-computer-iroh
- **Kind:** repo
- **Path:** inspiration/repos/n0-computer__iroh
- **Density:** 5

## Elevator summary

Iroh is a Rust library providing dialing by public key with automatic hole-punching and relay server fallback over QUIC. It includes protocol composition primitives (iroh-blobs, iroh-gossip, iroh-docs) for building content-addressed transfer, pub-sub overlays, and eventually-consistent KV stores. Iroh is the canonical peer-to-peer networking substrate for Mesh RAG: it solves NAT traversal, authenticated encryption, and protocol composition at the transport layer.

## Tags

`p2p-networking`, `hole-punching`, `quic`, `relay-fallback`, `protocol-composition`, `content-addressed`, `eventually-consistent`

## Topics covered

1. Public-key based dialing and endpoint discovery
2. Hole-punching strategies with relay fallback
3. QUIC-based transport with stream prioritization
4. iroh-blobs: BLAKE3-based content-addressed blob transfer
5. iroh-gossip: publish-subscribe overlay networks
6. iroh-docs: eventually-consistent KV store with CRDT semantics
7. Cross-language FFI bindings (iroh-ffi)

## What we'd take from this

- The hole-punching and relay architecture (Section Hole-punching): practical fallback strategies for unreliable networks
- The QUIC composition (Built on QUIC): authenticated encryption and concurrent streams by default
- The protocol composition model: iroh-blobs (content transfer), iroh-gossip (overlay), iroh-docs (replication) as building blocks
- The iroh-docs design: eventually-consistent KV replication pattern applicable to RAG context sharing
- The relaying performance optimization (perf.iroh.computer): continuous measurement for network quality

## Cross-references (optional)

- paper-2504.06135 (CRDT memory sync over iroh transport)
- repo-asg017-sqlite-vec (local storage for iroh-docs values)
