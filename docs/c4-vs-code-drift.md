# C4 model vs built code — drift report

Structural comparison between [docs/c4/model.c4](c4/model.c4) (drawn
*before* any code) and the built `lib/` source.

**Update 2026-05-22**: this report now incorporates output from a full
`/understand` (Understand-Anything plugin) run at commit `5c269e37`. The
graph is at [`.understand-anything/knowledge-graph.json`](../.understand-anything/knowledge-graph.json)
— 178 nodes / 196 edges / 9 layers / 10-step tour. `/understand` confirmed
every drift I called out manually and surfaced four additional internal
classes the C4 model didn't name.

## Components: matched / drifted / unmodelled

| C4 component | Actual file(s) | Verdict |
|---|---|---|
| `QueryScreen` | `lib/widgets/query_screen.dart` | ✓ match |
| `MeshStatusWidget` | `lib/widgets/mesh_status_widget.dart` | ✓ match |
| `DittoService` | `lib/services/ditto_service.dart` | ✓ match |
| `CactusService` | `lib/services/cactus_service.dart` | ✓ match |
| `RetrievalService` | `lib/services/retrieval_service.dart` | ✓ match |
| `RecipeTuple (data model)` | `lib/models/recipe_tuple.dart` | ⚠ schema drift (see below) |
| `PromptTemplate` | `lib/prompts/recipe_merge.dart` | ✓ match (named `RecipeMergePrompt`) |
| `Cactus Runtime` | external `cactus: ^1.3.0` | ✓ match |
| `Ditto SDK` | external `ditto_live: ^5.0.0` | ✓ match |

## Unmodelled in C4 — built anyway

These were implementation necessities the pre-code C4 didn't draw.
`/understand` identified all of them as first-class classes in the graph.

| Component in code | File | Why C4 missed it |
|---|---|---|
| `BootScreen` | `lib/main.dart` | Boot orchestrates Ditto init → seed insert → Cactus download → `ensureEmbeddings` → swap to `QueryScreen`. The C4 model jumped straight to the query UI; the boot lifecycle wasn't visible at planning time. |
| `MeshRagApp` | `lib/main.dart` | MaterialApp wrapper — boilerplate but still a real class. C4 omitted as cosmetic. |
| `SeedLoader` | `lib/services/seed_loader.dart` | The plan (U4) called for a `PHONE_ROLE` env var + `seed_recipes_<role>.json` asset, but C4 folded that inside `DittoService` rather than naming it. |
| `RecipeQueries` (DQL constants) | `lib/prompts/dql_queries.dart` | Plan explicitly named this file ("lock at U1, write a `dql_queries.dart` constants file once the SDK version is known"). C4 did not surface it as a component. Turned out to be the *most-edited file* during hardware bring-up (DQL syntax debugging), so deserves a node. |
| `RetrievedRecipe` | `lib/services/retrieval_service.dart` | Scored retrieval tuple (recipe + cosine). C4 implied this inside `RetrievalService`. **`/understand` caught it; my manual review missed it.** |
| `AnswerEvent` | `lib/services/retrieval_service.dart` | Discriminated union over the streaming-answer events (retrieved / token / done). The whole streaming UI contract lives in this class. **`/understand` caught it; my manual review missed it.** |

## Schema drift — `RecipeTuple`

C4 says:
```
{ id, dish, contributor, ingredients, steps, embedding, created_at,
  metadata: { source_device_id } }
```

Built:
```dart
class RecipeTuple {
  final String id;
  final String dish;
  final String contributor;
  final List<String> ingredients;
  final List<String> steps;
  final List<double> embedding;
  final DateTime createdAt;
  // no metadata.source_device_id — contributor IS the provenance key
}
```

**Drift:** `metadata.source_device_id` was collapsed into the flat
`contributor` field. The C4 motivation ("Preserves source_device_id
through sync for H4 provenance") is still satisfied — `contributor` is
the value the LLM cites in the attribution footer and the field
`QueryScreen` uses to count "M from peers". For Stage 0 this is fine; a
follow-up Stage 1+ multi-device-per-phone scenario would push us back
toward the nested `metadata` shape.

## Edge drift — interaction graph

The C4 model's iOS / Android edges (lines I would need to read to enumerate)
say things like:

- `QueryScreen → RetrievalService` ✓ matches `query_screen.dart`'s
  `RetrievalService.instance.answerQuery(...)` call
- `RetrievalService → CactusService` ✓ matches
- `RetrievalService → DittoService` ✓ matches (`queryWithEmbedding`,
  `queryMissingEmbedding`, `setEmbedding`)
- `DittoService → Ditto SDK` ✓ matches
- `CactusService → Cactus Runtime` ✓ matches
- **Implicit, not in C4:** `BootScreen → DittoService + CactusService + SeedLoader + RetrievalService`
  — the bootstrap fan-out

## What `/understand` added on top of the manual pass

The manual comparison caught 3 unmodelled components + 1 schema drift.
`/understand` confirmed all four and added:

- **Two more unmodelled classes** (`RetrievedRecipe`, `AnswerEvent`,
  plus the cosmetic `MeshRagApp` wrapper) — internal to
  `retrieval_service.dart` and easy to miss in a directory-listing-based review.
- **Layer auto-classification** placed `prompts/dql_queries.dart` in the
  **Domain Layer** alongside `recipe_tuple.dart` and `recipe_merge.dart`.
  That confirms the `prompts/` directory name is a misfit: DQL constants
  are *data-access glue*, not prompts. Rename candidate: `lib/data/queries.dart`.
- **A 10-step guided tour** ([`.understand-anything/knowledge-graph.json` tour field](../.understand-anything/knowledge-graph.json))
  ordered by import depth + edge density. Tour anchors: `lib/main.dart`
  (depth 0) → 5 services/widgets (depth 1) → `recipe_tuple` /
  `dql_queries` / `recipe_merge` / `mesh_status_widget` (depth 2). Matches
  the dependency arrows the C4 model drew, so the high-level shape is
  right.
- **Fan-in metric**: `ditto_service.dart` has fan-in 11 — the most
  depended-on file in the project. The C4 model didn't quantify this, but
  it's the practical reason why the upcoming
  [flutter/skills refactor](architecture-vs-flutter-skills.md) starts by
  splitting `DittoService` first.

### Layer assignments (auto-derived)

| Layer | Nodes |
|---|---|
| UI Layer | `lib/main.dart`, `lib/widgets/` (3 files) |
| Service Layer | `lib/services/` (4 files) |
| Domain Layer | `lib/models/` + `lib/prompts/` (3 files) |
| Test | `test/` (3 files) |
| Platform Configuration | `android/` + `ios/` (34 files) |
| Project Documentation | `docs/{plans,spikes,c4,architecture*}`, root .md (15 files) |
| Prior-Art Research | `docs/research/` (84 files) |
| Deliverables | `slides/`, `assets/` (5 files) |
| Build | `pubspec.yaml`, `justfile`, `analysis_options.yaml` (3 files) |

### What `/understand` didn't add value on

- It **doesn't model external SDKs** (Cactus Runtime, Ditto SDK) as
  separate nodes — they show up only as transitive `pubspec.yaml`
  dependencies. The C4 model represents them more clearly.
- It **doesn't see the iOS / Android *deployments* as separate
  containers** — the graph has a single project view, where C4
  intentionally duplicates `iosApp` vs `androidApp` to highlight that
  there are two running peers at demo time.
- It doesn't replace the C4. The two artifacts answer different
  questions: C4 = "what does the deployed system look like?",
  Understand-Anything = "what does the source tree look like?". Keep both.

## Recommended next steps

1. **Update `docs/c4/model.c4`** to add three components per container:
   `BootScreen`, `SeedLoader`, `RecipeQueries`. Rebuild dashboard with
   `npx --yes likec4@latest build docs/c4 -o docs/c4/dashboard`.
2. **Run `/understand`** (user-side, single command) to get the automated
   graph and the diff-impact + onboarding views.
3. **Reconcile schema drift** during the post-Stage-0 refactor:
   either move `contributor` under `metadata` (matches C4) or rename the
   C4 element (matches code). Pick one — the symmetry matters for any
   future Stage 1 audience-submission UI that needs to distinguish *device*
   from *contributor*.

## Source

C4 model snapshot: `docs/c4/model.c4` at commit `dd230e95`.
Code snapshot: `lib/` at commit `5c269e37` (Stage 0, post-DQL-fix,
post-iOS-deployment-target-bump, post-flutter-skills-and-manual-drift-review).
Knowledge graph: `.understand-anything/knowledge-graph.json` produced by
Understand-Anything 2.7.4 against the same commit
(178 nodes, 196 edges, 9 layers, 10-step tour).
