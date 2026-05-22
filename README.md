# Ditto × Cactus — Mesh RAG Stage 0

Two-device peer-to-peer RAG demo. Each phone holds a slice of a recipe corpus;
they meet over BLE/Wi-Fi and the **vector index merges as a CRDT**, so a query
on phone A visibly draws on phone B's tuples after handshake — even with all
WAN connectivity off.

See [docs/plans/2026-05-21-001-feat-mesh-rag-stage-0-implementation-plan.md](docs/plans/2026-05-21-001-feat-mesh-rag-stage-0-implementation-plan.md)
for the full plan, and [SEED.md](SEED.md) for the thesis + holdout scenarios.

## Stack

- **Flutter** dual-target (iOS + Android), single codebase.
- **[`ditto_live`](https://pub.dev/packages/ditto_live) 5.0.0** — P2P sync + DQL store. Owns persistence and replication.
- **[`cactus`](https://pub.dev/packages/cactus) 1.3.0** — on-device embeddings + small-LLM completion. Held narrow: no `cactus_rag_query`, no `cactus_index_*`. We materialize the corpus from Ditto and run a flat-array cosine top-k ourselves.

## Run

```bash
# Get a Ditto development app ID and offline license token from https://portal.ditto.live
# Then:
flutter pub get
flutter run \
  --dart-define=DITTO_APP_ID=<your-app-id> \
  --dart-define=DITTO_LICENSE=<your-offline-license-token>
```

First launch downloads the Cactus model (~hundreds of MB) — wait for the
progress bar before backgrounding. Subsequent launches load from disk in ~2s.

## Other ideas considered (writeup-only)

- B) LLM merge
- C) Narrate the mesh
- D) Federated learning over mesh
