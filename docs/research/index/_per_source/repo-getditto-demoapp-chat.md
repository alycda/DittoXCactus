# Ditto Chat Demo App (iOS + Android)

- **Source ID:** repo-getditto-demoapp-chat
- **Kind:** repo
- **Path:** inspiration/repos/getditto__demoapp-chat
- **Density:** 3

## Elevator summary

Production Ditto demo showcasing BLE/LAN mesh sync and public/private collections across iOS and Android in a real app. Validates the core Ditto sync infrastructure and peer-discovery mechanics that Mesh RAG will build on, but in a messaging domain rather than knowledge-base domain. Serves as a reference architecture for credential setup, collection schemas, and cross-platform sync testing.

## Tags

`ditto-sdk`, `mesh-sync`, `ble-connectivity`, `ios-android-interop`, `demo-app`, `local-first`

## Topics covered

1. Ditto environment variable setup (app ID, playground token, WebSocket URL)
2. Public and private collection patterns for data isolation
3. Message-deletion and edit operations (semantic precedent for knowledge-base mutations)
4. File attachment handling in synced collections

## What we'd take from this

- Reference pattern for Ditto environment configuration in a multi-platform app
- BLE peer-discovery latency expectations and troubleshooting (from README setup flow)
- Collection schema pattern applicable to RecipeTuple storage
- Cross-platform testing workflow for validating sync across iOS + Android

## Cross-references

- docs-ditto-live (SDK documentation for deeper setup details)
