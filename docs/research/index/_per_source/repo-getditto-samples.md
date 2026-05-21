# Ditto Sample Projects

- **Source ID:** repo-getditto-samples
- **Kind:** repo
- **Path:** inspiration/repos/getditto__samples
- **Density:** 3

## Elevator summary

This repository catalogs sample applications demonstrating Ditto's local-first, eventually-consistent database across multiple platforms (Swift, Kotlin, C#, Electron/React, Rust, MAUI). The samples showcase authentication patterns, real-time collaboration features, and multi-platform integration, providing concrete reference implementations for how Ditto handles CRDT replication and sync. It validates Ditto as the peer-to-peer data substrate for Mesh RAG prototyping.

## Tags

`ditto-platform`, `local-first`, `crdt`, `multi-platform`, `sample-apps`, `authentication-integration`

## Topics covered

1. Getting started templates across multiple platforms and languages
2. Authentication and permissions management integration
3. Change data capture and external sync patterns
4. End-to-end monitoring (heartbeat) of Big Peer status
5. Testing strategies for local-first applications

## What we'd take from this

- The authentication pattern: integration with Auth0 and custom auth providers (repo structure and naming conventions)
- The change data capture example: synchronizing Ditto with external systems like MongoDB
- The Big Peer heartbeat pattern: monitoring replication health in production
- The language/platform diversity: evidence of Ditto's polyglot support (Swift, Kotlin, Rust, C#, etc.)
- The template structure: reference layouts for bootstrapping new on-device apps

## Cross-references (optional)

- repo-n0-computer-iroh (p2p transport layer)
