# BitChat — Decentralized Peer-to-Peer Messaging (Bluetooth + Nostr)

- **Source ID:** repo-permissionlesstech-bitchat
- **Kind:** repo
- **Path:** inspiration/repos/permissionlesstech__bitchat
- **Density:** 4

## Elevator summary

BitChat is a decentralized messaging app with dual transport architecture (Bluetooth LE mesh for offline, Nostr for internet fallback). Directly relevant to Mesh RAG: validates iOS↔Android Bluetooth interop, demonstrates mesh topology without servers, and exemplifies the "moment of magic" demo pattern (devices meet, state composes, no central authority).

## Tags

`bluetooth-mesh`, `p2p-messaging`, `decentralized`, `dual-transport`, `ios-android-interop`, `mesh-networking`

## Topics covered

1. Bluetooth LE mesh network topology and multi-hop relay
2. Noise Protocol encryption for mesh, NIP-17 for Nostr
3. Location-based channels via geohash coordinates
4. Intelligent transport selection (BLE → Nostr fallback)
5. Native iOS and macOS implementation (Swift)

## What we'd take from this

- Proven Bluetooth LE mesh patterns for mobile platforms
- iOS↔Android interoperability validation and known pain points
- Demo narrative: offline-first messaging "moment of magic" (applies to synced recipes)
- Privacy-first architecture without accounts or persistent identifiers

## Cross-references (optional)

- docs-docs-ditto-live (Ditto's comparable mesh-sync layer)
