# Post-dogfood next steps

Status: dogfood validated on Pixel 6a (commit 12). App boots, tabbed UI
renders, Cactus produces flashcards. Three categories of follow-up below,
roughly ordered by how cheaply they can be tested.

---

## 1. Model swap (cheapest test — single constant)

**Symptom:** flashcards generated, but content is poor / hallucinatory /
detached from the corpus (when there is one).

**Why:** three layered reasons:

1. `qwen3-0.6` is the smallest model in Cactus's catalog (~600M params).
   Coherence falls off cliff-style at this size for any task more
   structured than chit-chat.
2. It is chat-tuned (general-purpose RLHF), not domain-tuned. Science /
   factual-recall benchmarks aren't a strength at this scale.
3. The flashcard prompt in `lib/prompts/flashcard_gen.dart` was tuned
   for Qwen 2.5 1.5B (see comments about plain-text Q/A vs JSON, and
   `<think>` block stripping). Qwen 3 0.6B doesn't share Qwen 2.5's
   quirks; the prompt likely isn't hitting it the way it was tuned to.

**Action:** swap the slug pin in `lib/services/cactus_service.dart`:

```dart
static const String preferredEmbeddingSlug = 'qwen3-1.7';   // up from qwen3-0.6
static const String preferredCompletionSlug = 'qwen3-1.7';
```

**Candidates to evaluate (verify with `_lm.listAvailableModels()` or
Cactus's published catalog first):**

| Slug guess | Size | Why try it |
| --- | --- | --- |
| `qwen3-1.7` | 1.7B | First step up. Probably the inflection point where Q/A starts being coherent on factual tasks. ~2× the latency on a Pixel 6a. |
| `qwen3-4b` | 4B | Substantially better outputs. ~5× slower; download size matters. |
| `gemma-3-1b` / `gemma-3-4b` | 1B / 4B | Gemma tends to outperform Qwen at the same param count on science/factual benchmarks. |
| `phi-3-mini` | 3.8B | Microsoft, hard-tuned on STEM. Strong choice if science framing stays. |

**Prompt retune:** if a non-Qwen model lands, the `<think>` strip + Q/A
format choices may need revisiting. Worth running the U3 eval again
(`docs/spikes/U3-recipe-merge-eval.md` now applies to flashcards, not
recipes, but the method transfers).

---

## 2. Subject matter / corpus choice

**Observation:** small models perform poorly on RAG over well-known
topics. The model already has the topic in training data, so the
retrieved-notes context fights with what the model "knows." Output
drifts to training-time priors instead of retrieved notes — which is
the "cards generated out of thin air" symptom (cards plausible-sounding
but unrelated to the corpus).

**The solar system is the OPPOSITE of a good RAG demo corpus.** Every
base model has solar-system facts cold. Even when retrieval works
(post-mesh wiring), the model has no incentive to use the retrieved
notes; the answer comes from priors.

**Topics where RAG actually shines on tiny models** — the corpus IS the
source of truth, training data wouldn't help:

- **Personal / private knowledge.** Your meeting notes. Your reading
  highlights. Your D&D campaign lore. Your CRM activity log.
- **Niche jargon / specific protocols.** A particular lab's procedures.
  A small startup's internal terminology. A game's deep mechanics.
- **Post-cutoff events.** News, releases, paper preprints from after
  the model's training data.
- **Anti-prior / contrarian readings.** A specific historical
  interpretation, a heterodox technical opinion.

**Recommended swap (if/when corpus changes):** something the audience
can verify is *not* in the model's training data. Memorable + visibly
demo-able even with a 1.7B model.

---

## 3. ditto_live wiring (the deferred "post-clean-history" work)

The current `DittoService` is entirely stubbed — methods return
`const []` or no-op. The 10-commit clean history deliberately deferred
real wiring so the dogfood proved the *structural* shape. Real ditto
wiring is the next coherent commit (or commits).

### Methods to wire

In `lib/services/ditto_service.dart`:

| Method | What needs to happen |
| --- | --- |
| `init()` | Instantiate `Ditto.open(...)` with `DITTO_APP_ID` + `DITTO_LICENSE` from `--dart-define`. Configure transports: `enableAllPeerToPeer()` (BLE + LAN). Call `ditto.startSync()`. Register a presence observer that pushes peer counts onto `_peerCountController`. |
| `upsertNote(note)` | `ditto.store.execute(NotesQueries.upsert, {'doc': note.toMap()})`. |
| `queryMissingEmbedding()` | `SELECT * FROM notes WHERE array_length(embedding) = 0` — or whatever DQL syntax the current SDK supports for empty-array filters. |
| `setEmbedding(id, emb)` | `ditto.store.execute(NotesQueries.setEmbedding, {'id': id, 'embedding': emb})`. |
| `queryWithEmbedding()` | The corpus query that powers `RetrievalService.topK`. Filter to non-empty embedding. |
| `subscribeToNotes(cb)` | `ditto.store.registerObserver(NotesQueries.selectAll, ...)` — return the `StoreObserver` so `NotesTab` can `_observer?.cancel()` on dispose. |
| `isReady` | already a getter on `_initialized`; flips to `true` once `init()` succeeds. |

### `.env` file required at run time

`.env` must exist at project root (gitignored — never check it in):

```
DITTO_APP_ID=<your-app-id-uuid>
DITTO_LICENSE=<your-offline-license-token>
```

The `--dart-define-from-file=.env` flag in `just iphone` / `just android`
already wires this. Get the values from the Ditto developer portal.

### Seed loading

`SeedLoader.instance.loadAndInsert()` exists (commit 3) and calls
`DittoService.upsertNote(n)` for each seed note. **Currently nowhere
called from `main.dart`.** Two choices:

1. Add `await SeedLoader.instance.loadAndInsert();` to `main()`
   between `DittoService.init()` and `runApp(...)`. Eager seed on every
   boot. Idempotent via UUIDv5 keying so no duplicates.
2. Defer to a "load seeds" button in NotesTab — opt-in seeding for
   demos where you want the audience to add their own notes first.

### `--dart-define=PHONE_ROLE=a|b`

The justfile passes this. `SeedLoader.role` reads it (defaults to `a`).
Drives which `seed_notes_<role>.json` is loaded. iPhone = `a`, Pixel =
`b` in the current `just` recipes.

### Embedding fill on app start

`RetrievalService.ensureEmbeddings()` exists (commit 4b) but isn't
called. After seed load + Ditto sync, embeddings need backfilling so
`topK` has something to score. Plumb a call in `main()`:

```dart
await DittoService.instance.init();
await CactusService.instance.initialize();
await SeedLoader.instance.loadAndInsert();
await RetrievalService.instance.ensureEmbeddings();
runApp(const MeshRagApp());
```

Watch out: `ensureEmbeddings` is blocking on Cactus inference per note —
on first boot with a fresh seed corpus, this is a noticeable wait. May
want to move it off the critical path and show a progress UI.

---

## 4. Template improvements surfaced by the dogfood

Findings that should fold back into the `alycda/project` template:

| Finding | Where to fix |
| --- | --- |
| `flutter create`'s default `Flutter.gitignore` is SDK-focused; misses `.idea/` for app projects (commit 2c) | Either curate `.idea/` into the dart/flutter splice in the template, or extend `init-gitignore.sh` to also pull `Global/JetBrains.gitignore` |
| `flutter create` defaults `minSdkVersion = 21`, which fails for any BLE / Bluetooth / native-runtime plugin (commit 12) | The setup skill should bump `minSdk = maxOf(flutter.minSdkVersion, 24)` automatically right after `flutter create` |
| `flutter create` defaults `ndkVersion = 26.3.x`, but most modern plugins ship for `27.0.12077973` (commit 12) | The setup skill should bump `ndkVersion = "27.0.12077973"` after `flutter create`; bump as the ecosystem moves |
| `flutter create` defaults `iOS deployment target = 12.0`; cactus + ditto_live both need 15.0+ (commit 2d) | The setup skill should bump three `IPHONEOS_DEPLOYMENT_TARGET` entries in `ios/Runner.xcodeproj/project.pbxproj` to 15.0 |
| Upstream `Dart.gitignore` includes `pubspec.lock` (correct for libraries, wrong for apps) | The setup skill's dart splice should override (or omit the pubspec.lock line) |
| `init-gitignore.sh`'s upstream-filename resolution looks only at github/gitignore root, not `Global/` | Extend the script to fall through to `Global/` for IDE / OS / framework configs |

---

## 5. Punted from the clean history

Commits that the messy DittoXCactus chain had but the 10-commit clean
scaffold doesn't. These could become commits 14, 15, ... when they
matter:

- `vp` (placeholder 5), `xkm` (placeholder 6): unused orphan
  scaffolding commits, preserved per the "don't abandon" rule.
- The `ouq` rename sibling (recipe → StudyNote) wasn't squashed back
  into earlier commits — narrative breakage in SEED.md and
  RESEARCH-BRIEF.md (food metaphors lost meaning) is still there. A
  proper narrative rewrite, not a mechanical sed, is the next move on
  that branch.
- `pxt`, `ly`, `pqkzmoxl`: empty / undescribed working buffers from
  this session. Cosmetic cleanup later.
- The original messy template's `pypqowlr "DittoXCactus V2"` octopus
  merge as the parallel "what if we had merged the messy work
  unmodified" view. Comparison surface still intact.

---

*Authored: 2026-05-22 post-dogfood. The 12-commit clean history landed
on `kx` (10d); commit 12 fixed Android scaffold gaps; the validation
succeeded on Pixel 6a. Picking back up later from this doc.*
