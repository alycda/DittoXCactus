# Pre-baked seed embeddings — R5 cold-load lever

The on-device U14 cold-load measurement on 2026-05-25 (Pixel 6a, debug) showed:

```
total_ms                          12390
  app_init_done                     129
  ditto_initialized                 776
  sync_started                     1490
  corpus_seeded                    1621
  cactus_completion_downloaded     1704  (cached)
  cactus_embedding_downloaded      1728  (cached)
  cactus_initialized               2649
  embeddings_backfilled           12388  ← 78% of total cold-load
```

**`embeddings_backfilled` is the dominant tail** (~9.7s of 12.4s total). The model load is fine; the per-note Cactus embedding inference at ~1.95s × 5 notes is what overshoots R5's 10s bar.

The plan's §U14 H5 remediation playbook focused on the LLM (mmap, parallelize-with-splash, max_tokens, model shrink). None address per-note embedding cost. **This doc names the missing lever:** ship the embedding bytes inside the seed JSON, skip on-device backfill entirely.

## The lever

`SeedLoader.parseSeedJson` reads an optional `embedding` field on each seed row. When present, the embedding is passed through to `StudyNote.seed(embedding: ...)`. `RetrievalService.ensureEmbeddings` is already a no-op on notes whose `embedding` is non-empty (see [retrieval_service.dart](../lib/services/retrieval_service.dart)).

So: if the seed JSON ships with embeddings, `embeddings_backfilled` drops from ~9.7s to ~0ms.

## How to bake the embeddings

The bake is a developer-time operation: run the app on a device with `--dart-define=BAKE_EMBEDDINGS=true`, let it embed the corpus once, pull the resulting JSON back into the asset bundle.

### Step 1 — boot in bake mode

```sh
just bake-seeds-a <android-device-id>
# or
just bake-seeds-b <android-device-id>
```

This is just `app-run-a` / `app-run-b` with `BAKE_EMBEDDINGS=true` added. The app boots normally, runs `ensureEmbeddings` (slow, ~9.7s for 5 notes), then writes the embedded JSON to the device's app documents directory. The exact path is logged:

```
[BakeEmbeddings] wrote 5 note(s) with embeddings to:
  /data/data/com.dittoxcactus.mesh_rag/files/seed_notes_a_baked.json
```

Once you see that line, stop the app (Ctrl-C in the Flutter runner).

### Step 2 — pull the baked JSON into the asset bundle

```sh
just bake-seeds-pull-a   # or bake-seeds-pull-b
```

This `adb exec-out`s into the app's data directory and overwrites
`assets/seed_notes_<role>.json` with the baked version. The recipe uses `run-as`
so it works on debuggable builds without root.

For iOS: use Xcode → Window → Devices and Simulators → select the device →
Installed Apps → mesh_rag → ⚙ → Download Container, then copy the JSON out of
the downloaded `.xcappdata` bundle.

### Step 3 — commit the asset diff

```sh
git diff assets/seed_notes_a.json   # should show the embedding field populated
git add assets/seed_notes_a.json
git commit -m "chore: bake seed-A embeddings (R5 cold-load lever)"
```

Repeat for role=b.

## When to re-bake

Only when the seed corpus's text changes (new note added, edit to an existing
body). The embedding is deterministic for the same `(model, body)` pair, so the
JSON diff should be 100% deterministic across re-bakes on the same hardware.

**Not when:** the model changes. A model swap requires re-baking because the
embedding space differs. The R2 determinism harness (`tools/determinism_harness/`)
is the place to catch unintended model swaps.

## Caveats worth knowing

### Cross-platform drift

The on-device determinism harness measured **0.85 cross-platform agreement** on
the locked `qwen3-0.6` slug (Pixel 6a ↔ iPhone 14 Pro). Pre-baked embeddings
inherit whichever platform the bake ran on. Concretely: if you bake on Android,
the iPhone will use Android-baked embeddings — that's fine for retrieval
because cosine similarity over the *same* vector space holds, but it does mean
on-device-embedded user notes will land in a slightly different space than the
shipped seed notes.

For Stage 0/1 demo: users don't add notes, so this doesn't matter. For Stage 2+
(user-authored notes), the right move is to re-embed user notes against the
on-device model rather than expect them to match the baked seed space.

### User notes are never baked

The bake exports only notes whose `contributor` matches this device's role
(`phone-a` baking only touches `phone-a` notes). User-authored notes — if the
demo ever lets users author — should not be touched by the bake; their
embeddings get computed on-device at the time of the user edit.

This is the cleanest separation: seed notes are content; user notes are state.
The bake operates on content only.

### Asset size

Each note adds ~20KB of embedding bytes (1024 floats × ~5 chars per JSON-encoded
float). For a 5-note seed: ~100KB total per role. Negligible for a hackathon
demo; revisit if the seed corpus grows past a few hundred notes.

## What the JSON looks like

Before bake:

```json
{
  "topic": "Mars",
  "contributor": "phone-a",
  "createdAt": "2026-05-22T19:31:00.000Z",
  "tags": ["red-planet"],
  "body": "Mars has Olympus Mons..."
}
```

After bake (the `embedding` field is appended):

```json
{
  "topic": "Mars",
  "contributor": "phone-a",
  "createdAt": "2026-05-22T19:31:00.000Z",
  "tags": ["red-planet"],
  "body": "Mars has Olympus Mons...",
  "embedding": [0.0273, -0.0411, 0.0185, /* ... 1021 more floats ... */]
}
```

## Cross-references

- [main.dart](../lib/main.dart) — `kBakeEmbeddings` flag + `_exportBakedSeedNotes()` helper.
- [seed_loader.dart](../lib/services/seed_loader.dart) — `parseSeedJson` reads the optional `embedding` field.
- [model-quirks.md](model-quirks.md) — broader catalogue of Qwen 2.5 1.7B on-device quirks; the slow embedding cost is documented there too.
- Plan §U14 H5 remediation playbook — the original list of cold-load levers. This doc names the lever the playbook missed.
