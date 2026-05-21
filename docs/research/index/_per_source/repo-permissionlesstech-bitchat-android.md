# bitchat for Android: BLE Mesh P2P Chat

- **Source ID:** repo-permissionlesstech-bitchat-android
- **Kind:** repo
- **Path:** inspiration/repos/permissionlesstech__bitchat-android
- **Density:** 5

## Elevator summary

bitchat for Android is a production-quality, cross-platform (iOS ↔ Android) BLE mesh messaging app with end-to-end encryption, 100% protocol compatibility with the iOS original, and proven UX for peer discovery and mesh-state visualization. It is the single best open-source reference for how to build the "moment of magic" demo UX on real mobile hardware over BLE, demonstrating foregrounded app mesh ergonomics, store-and-forward, and mesh presence affordances directly reusable in Mesh RAG's offline-first demo narrative.

## Tags

`ble-mesh`, `p2p-messaging`, `cross-platform`, `ios-android-parity`, `e2e-encryption`, `mesh-presence`, `adaptive-power`

## Topics covered

1. BLE mesh networking: central + peripheral role management, multi-hop relay, TTL-based routing
2. Binary protocol design: compact encoding, fragmentation, deduplication (1-byte type field, efficient packet structure)
3. End-to-end encryption: X25519 key exchange, AES-256-GCM, Ed25519 signatures
4. Store-and-forward for offline peers: message caching and delayed delivery
5. Android-specific: Jetpack Compose UI, Kotlin Coroutines, lifecycle-aware networking, battery optimization (adaptive scanning)
6. Cross-platform compatibility: identical message format and routing on both iOS and Android

## What we'd take from this

- BLE mesh architecture blueprint: how to structure concurrent connections, peer discovery, and multi-hop message relay on real phones
- Binary protocol design: the 13-byte header format, fragmentation strategy, and deduplication scheme are immediately applicable to Mesh RAG tuple sync
- UI pattern for mesh state: how to visualize peer count, RSSI signal strength, and join/leave events — critical for demo narration of "here are the phones connecting"
- Adaptive power management: real implementation of battery-aware scanning duty cycles
- iOS ↔ Android protocol parity: proof that bitwise-identical binary exchange is achievable and maintained across platforms

## Cross-references (optional)

- repo-earthstar-project-earthstar (alternative P2P stack; bitchat is more mesh-specific, simpler)
- repo-yjs__yjs (CRDT comparison; bitchat is purpose-built mesh chat, not general-purpose CRDT)
