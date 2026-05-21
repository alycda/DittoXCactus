# libp2p Go Implementation

- **Source ID:** repo-libp2p-go-libp2p
- **Kind:** repo
- **Path:** inspiration/repos/libp2p__go-libp2p
- **Density:** 2

## Elevator summary

The Go implementation of libp2p, a modular networking stack for peer-to-peer applications extracted from IPFS. libp2p provides protocol abstraction, transport negotiation, NAT traversal, and identity management for P2P systems. For Mesh RAG, libp2p is a *non-choice* reference: it is powerful but heavyweight for mobile phones lacking background connectivity and favors IP-routed overlay networks over BLE-adjacent mesh transports. Ditto is the superior fit for our constraints, but studying libp2p clarifies *why* (IP-first, no BLE, complex identity machinery) and validates that standalone P2P networking is a mature, publishable domain.

## Tags

`peer-to-peer`, `networking`, `protocol-abstraction`, `ipfs`, `content-addressing`, `decentralized`, `golang`

## Topics covered

1. Modular networking transport layer (TCP, UDP, QUIC, etc.)
2. Protocol negotiation and upgrade
3. NAT traversal and hole punching
4. Peer identity and addressing
5. Pubsub, DHT, and routing abstractions

## What we'd take from this

- P2P networking is a solved problem at the protocol level; libp2p's modularity (swap transports, upgrade protocols) is the design pattern to admire.
- BLE is not a first-class libp2p transport; it targets IP-routed connectivity and assumes long-lived peer relationships. For Mesh RAG to work on phone-to-phone BLE, we need a Ditto-shaped solution, not libp2p.
- Identity and signature verification in libp2p are orthogonal to our peer-discovery problem; on a local mesh with no adversaries, these are premature complexity. Stage 1+ might reconsider for trust-anchored scenarios.

## Cross-references (optional)

- repo-n0-computer-iroh (modern libp2p alternative; hole-punching focused, not BLE-friendly either)
- docs-docs-ditto-live (the chosen mesh transport layer)
