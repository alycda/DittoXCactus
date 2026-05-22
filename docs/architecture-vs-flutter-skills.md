# Architecture review — Mesh RAG Stage 0 vs `flutter/skills`

Reference: [github.com/flutter/skills](https://github.com/flutter/skills) (the Flutter team's
2026 recommended-architecture skill pack). Evaluated against `lib/` at
commit `8122fd2b` (post-DQL-fix, post-iOS-deployment-target-bump).

## Verdict in one paragraph

Stage 0 is **structurally MVC, not MVVM**, and uses **singleton services
instead of DI**. Those are intentional simplifications for a single-screen
hackathon demo (≤500 LOC of app code). The separation-of-concerns *direction*
matches `flutter/skills` (data wrappers separated from UI), just with one
service tier instead of two. Below are the concrete deviations and a
refactor map for Stage 1+ if the project grows beyond demo scope.

## Side-by-side

| `flutter/skills` recommends | Stage 0 implementation | Gap severity |
|---|---|---|
| **MVVM**: View ↔ ViewModel ↔ Repository ↔ Service | StatefulWidget state ↔ singleton Service | Medium — works at one screen, locks in at three+ |
| **Repository pattern**: Services return raw, Repos return Domain Models | `DittoService` is both (raw FFI wrap + `queryAll`/`upsertRecipe`) | Medium |
| **`data/`, `domain/`, `ui/features/`** structure | `models/`, `prompts/`, `services/`, `widgets/` | Low — same idea, different names |
| **ViewModels extend `ChangeNotifier`**; views are lean + use `ListenableBuilder` | `QueryScreen` is a `StatefulWidget` that subscribes to the answer stream and writes to `_answer` directly | Medium |
| **Constructor injection** via `provider` or `get_it` | `DittoService.instance`, `CactusService.instance`, etc. | Medium |
| **`freezed` / `built_value`** for immutable models | Hand-rolled `RecipeTuple` with manual `copyWith` | Low — one model |
| **`fromJson` / `toJson` on data classes** | `RecipeTuple.toDittoDoc` / `fromDittoValue` | ✓ matches |
| **`compute()` for >16ms JSON parsing** | Synchronous parse of 5 small recipes | ✓ trivial corpus, not needed |
| **Widget tests** with `WidgetTester` + `find.byType` / `find.text` | Unit tests only (cosine math, UUIDv5, prompt assembly) | Medium — `QueryScreen` is untested |
| **Integration tests** under `integration_test/` with `IntegrationTestWidgetsFlutterBinding` | U7 is a procedural runbook (`docs/spikes/U7-sync-verification.md`) | Medium — the moment-of-magic flow has no automated coverage |
| **Throw on HTTP non-2xx** at the boundary; UI handles Result | Errors bubble from `DittoService` / `CactusService` → caught in `BootScreen._boot` | ✓ matches in spirit |

## What we kept right

- **Single source of truth** for recipes (Ditto). No second cache.
- **DQL is centralized** in `lib/prompts/dql_queries.dart` (one place to fix when the SDK syntax shifts — and it already did, see the `len(array)` → drop-and-filter fix).
- **`RecipeTuple` is immutable** with a `copyWith`; matches the Domain-Model spirit even without `freezed`.
- **Boot orchestration is sequenced**: Ditto → seed → Cactus → `ensureEmbeddings` → UI. The Flutter team's "Workflow: Implementing a New Feature" checklist has the same shape (Models → Services → Repository → ViewModel → View).
- **Error visibility**: `BootScreen` renders the exception text + writes to `debugPrint` so `adb logcat` shows the trace.

## Concrete refactor map for Stage 1+

If the project goes beyond Stage 0 (audience-participation Stage 1, real-corpus Stage 2, or any second screen), the order below is the lowest-friction path:

1. **Split `DittoService`** into:
   - `DittoClientService` — `Ditto.init`, `Ditto.open`, transport config, license. No domain knowledge.
   - `RecipeRepository` — `queryAll`, `queryWithEmbedding`, `upsertRecipe`, `setEmbedding`, `subscribeToRecipes`. Owns DQL.
2. **Split `RetrievalService`** into:
   - `EmbeddingService` (or merge into `CactusService`) — `embed(text)` → `Float32List`.
   - `RetrievalRepository` — `ensureEmbeddings`, `topK`, public cosine math.
   - `AnswerUseCase` — the streaming `answerQuery` orchestration that combines embedding + retrieval + LLM completion.
3. **Add ViewModels**:
   - `BootViewModel extends ChangeNotifier` — owns the init sequence + `_stage` / `_modelDownloadProgress` / `_error`.
   - `QueryViewModel extends ChangeNotifier` — owns `_answer`, `_retrieved`, `_busy`. Subscribes to `AnswerUseCase`. `QueryScreen` becomes a `StatelessWidget` wrapping `ListenableBuilder`.
4. **DI container**: pick `provider` (lightweight, official-blessed) or `get_it` (singleton-style). Replace the `.instance` singletons. Constructor-inject `DittoClientService → RecipeRepository → RetrievalRepository → AnswerUseCase → QueryViewModel`.
5. **Restructure** to `lib/data/{services,repositories,models}`, `lib/domain/{models,use_cases,prompts}`, `lib/ui/{core,features/query,features/boot}`. The `models/` rename is low-friction since there's one class.
6. **Adopt `freezed`** when we hit ≥3 immutable domain models (today's count: 1).
7. **Add widget tests** for `QueryScreen`: mock `AnswerUseCase`, verify input flow → answer render → attribution count.
8. **Add an integration test** for the boot → query path: load app, mock the network, verify "drew on N tuples (0 from peers)" appears (R1 sans sync).

## What deliberately stays the way it is

The Flutter team's skill is general-purpose; some of its prescriptions are wrong for *this* codebase:

- **No `http` package** — we don't make any HTTP calls; Cactus + Ditto are FFI-bound.
- **No declarative routing** (`go_router`) — we have one screen.
- **No localization** — one language, hackathon scope.
- **No `compute()` isolate** — corpus is ≤10 rows; parse takes microseconds.
- **`flat float32 array` cosine instead of an ANN library** — this is the *plan's* call (Stage 0 §Key Technical Decisions), and the right one.

## Source

Read 21 May 2026 from
[github.com/flutter/skills](https://github.com/flutter/skills) at HEAD
(`ffe7a5d6b2daa137a38470106886145462a285c0`). The 10 published skills are:

```
flutter-add-integration-test
flutter-add-widget-preview
flutter-add-widget-test
flutter-apply-architecture-best-practices
flutter-build-responsive-layout
flutter-fix-layout-issues
flutter-implement-json-serialization
flutter-setup-declarative-routing
flutter-setup-localization
flutter-use-http-package
```

The four read in depth: `flutter-apply-architecture-best-practices`,
`flutter-add-widget-test`, `flutter-add-integration-test`,
`flutter-implement-json-serialization`. The others are domain-mismatches (no
HTTP, no routing, no localization, no responsive-layout pressure) and were
skipped after reading the SKILL.md frontmatter.
