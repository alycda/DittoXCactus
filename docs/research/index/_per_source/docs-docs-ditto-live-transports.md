# Ditto Mesh Networking & Transports

- **Source ID:** docs-docs-ditto-live-transports
- **Kind:** docs
- **Path:** inspiration/docs/docs.ditto.live-transports
- **Density:** 5

## Elevator summary

Ditto's official Mesh Networking documentation describes the multi-transport architecture (BLE, LAN, AWDL, Wi-Fi Aware, WebSocket) with aggressive peer discovery, the Ditto Multiplexer for seamless handoff between transports, and the presence graph for mesh topology awareness. It is load-bearing for Mesh RAG's P2P sync infrastructure: it specifies the exact BLE + LAN configuration, connection limits ("a few concurrent connections, each initiation taking several seconds"), and presence-graph query surface needed for the demo narrative of two phones forming a mesh.

## Tags

`mesh-networking`, `ble`, `lan`, `awdl`, `wifi-aware`, `websocket`, `multiplexer`, `presence-graph`, `ditto-sdk`, `transports`

## Topics covered

1. Mesh formation: aggressive concurrent peer discovery and connection on app launch via sync.start()
2. Transport types: BLE (short range), LAN (local area), AWDL (iOS P2P Wi-Fi), Wi-Fi Aware (Android P2P), WebSocket (fallback)
3. Ditto Multiplexer: intelligent switching between active transports, packet fragmentation and reassembly, no data duplication
4. Presence graph: peer discovery advertisement, session establishment, topology-aware routing
5. Transport prioritization: Ditto favors Wi-Fi > LAN > BLE based on bandwidth and latency

## What we'd take from this

- **BLE limitations**: "a few concurrent connections, each initiation taking several seconds" — exactly what we need for 2-device demo validation; informs UX expectation-setting
- **Multi-transport agility**: Ditto automatically falls back from Wi-Fi to BLE if connectivity degrades — critical for demo reliability (no microphone/laptop WiFi required for BLE to work)
- **Presence graph query API**: "Using Mesh Presence" section (referenced but not fully detailed in excerpt) is the integration point for "visualize peers joining the mesh" in UI
- **Configuration guidance**: which transports to enable/disable for airplane-mode demo (WebSocket: off; BLE + LAN: on)
- **Architecture validation**: Ditto's published constraints ("aggressive mesh formation," "seamless transport switching") match the Mesh RAG brief exactly

## Cross-references (optional)

- repo-permissionlesstech-bitchat-android (lower-level BLE implementation reference; Ditto abstracts this)
- repo-earthstar-project-earthstar (alternative P2P stack; Ditto has superior native mobile support)
