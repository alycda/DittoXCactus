# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Flutter hackathon demo pursuing the **"Mesh RAG"** framing of Ditto × Cactus (Stage 0). Two phones each hold a slice of a study-notes corpus; they meet over BLE/Wi-Fi and the vector index merges as a CRDT, so a query on phone A draws on phone B's notes after handshake — with WAN off. See [README.md](README.md) and [SEED.md](SEED.md) for the thesis. Other framings (B/C/D) live in [docs/c4/model.c4](docs/c4/model.c4) and the brainstorm at https://hackmd.io/4ChwPprHQBOvgi_DyWur0g; only A is implemented.

## Common commands

Run targets all read `.env` (must contain `DITTO_APP_ID` + `DITTO_LICENSE`):

- `just iphone` — physical iPhone as phone-a (release mode; debug-attach to physical iOS is flaky).
- `just android` — Pixel 6a as phone-b (debug mode; hot reload works).
- `just android-release` — same Android device, AOT-compiled. Use this — not `just android` — when measuring inference latency; debug mode adds 2–4× overhead.
- `just sim [a|b]` — iOS simulator, fastest debug loop.
- `flutter test` — unit tests in `test/`. There are no widget or integration tests. Filter with `flutter test --name "<group or test name>"`.
- `flutter analyze` — lints (flutter_lints), excludes `inspiration/`, `docs/`, `build/`, `.dart_tool/`.
- `just serve` / `just build` / `just open-dashboard` — Likec4 dashboard for the architecture model at [docs/c4/](docs/c4/).

Device IDs are pinned in [justfile](justfile) — override on the CLI if hardware changes.

## Architecture

Singleton services own all global state and are initialized in a fixed boot order by [`BootScreen`](lib/main.dart) in [lib/main.dart](lib/main.dart): **Ditto init + sync → seed insert → Cactus init (downloads model on first launch) → ensureEmbeddings → QueryScreen**. There is no settings UI, no retry button — Stage 0 is "run once on demo day."

- [`DittoService`](lib/services/ditto_service.dart) — small-peers-only Ditto (no Big Peer), DQL store over `StudyNote`. Configured via `--dart-define DITTO_APP_ID=… DITTO_LICENSE=…`.
- [`CactusService`](lib/services/cactus_service.dart) — holds **two** `CactusLM` instances, completion and embedding. Slug separation is load-bearing: chat-tuned slugs (e.g. `qwen3-1.7`) return result code `-2` on `generateEmbedding`. Slug archaeology is documented inline at the top of the file — read it before swapping models.
- [`RetrievalService`](lib/services/retrieval_service.dart) — materializes the corpus from Ditto and ranks with a flat-array cosine top-k. Cactus is held intentionally narrow: do not introduce `cactus_rag_query` or `cactus_index_*` — we own retrieval so the index merges as a CRDT.
- [`SeedLoader`](lib/services/seed_loader.dart) — loads `assets/seed_notes_{a,b}.json` per `PHONE_ROLE`. `StudyNote.seed` uses deterministic UUIDv5 so seed inserts are idempotent across peers.

`PHONE_ROLE` (`a` or `b`) is set per device in the `just` recipes and decides which seed slice the phone loads.

## Things that bite

- **First launch needs Wi-Fi** for the Cactus model download (~1 GB). Subsequent launches are fully offline.
- **Demo-day reproducibility**: model slugs are pinned in [CactusService](lib/services/cactus_service.dart). The inline notes record which swaps failed and why — don't re-derive.
- **`.gitignore` is canonicalized in the init commit** (change `pmn` / bookmark `main`). New ignore patterns belong there, not in ad-hoc later commits. Adding them later requires the no-`@`-movement pattern documented in memory; see VCS section below.
- **No web target.** `kIsWeb` branches short-circuit BLE/permissions; the app only runs on iOS/Android.

## VCS — jujutsu (colocated)

- Prefer `jj` over `git`. The repo is colocated (`.jj/` and `.git/` both exist); raw `git` commits or rebases can desync state. Read-only `git log`/`git status`/`git diff` is fine.
- Default remote is `origin` → `git@github.com:alycda/DittoXCactus.git`. The bookmark `main` tracks the init commit.
- Prefer the `gh` CLI over the GitHub web for issues, PRs, and repo metadata.
- **Never `jj edit <ancestor>` to modify a path in that ancestor** — it materializes the ancestor's tree, auto-snapshot grabs stray working-copy files, and pollutes the commit. See the user's memory under `feedback_jj_never_move_at.md` for the in-between-commit recipe (`jj new --no-edit --insert-after <ancestor>` + `jj restore --from @ --to <new> <path>`).

## Repo map

- `lib/` — app code (`main.dart`, `models/`, `prompts/`, `services/`, `widgets/`). The README of each service file is the contract.
- `test/` — unit tests for `StudyNote`, `RetrievalService`, and `flashcard_gen` prompts.
- `assets/seed_notes_{a,b}.json` — demo corpora; role-dependent.
- `docs/plans/` — implementation plans (one per stage). `docs/c4/` — Likec4 architecture model (browsable via `just serve`). `docs/research/` — research artifacts from the bootstrap pipeline.
- `SEED.md`, `SEED-A.md`, `RESEARCH-BRIEF.md`, `WEB-PROMPT.md` — research-pipeline scaffolding driving the writeup, not runtime concerns.
- `slides/` — Slidev presentation.

## Tooling (preserved from prior CLAUDE.md)

- jujutsu (prefer over git)
- prefer the gh tool over web for github urls
- https://github.com/Lum1104/Understand-Anything
