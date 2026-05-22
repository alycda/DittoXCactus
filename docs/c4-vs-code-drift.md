# C4 model vs built code — drift report

Manual structural comparison between [docs/c4/model.c4](c4/model.c4) (drawn
*before* any code) and `lib/` at commit `38d59c5e` (Stage 0 verified on
Pixel 6a). Substitutes for a full `/understand` run; that requires the
user to type `/understand` since Claude Code plugins aren't auto-invokable
from inside an Agent session.

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

These three were implementation necessities but weren't drawn in the
pre-code model:

| Component in code | File | Why C4 missed it |
|---|---|---|
| `BootScreen` | `lib/main.dart` | Boot orchestrates Ditto init → seed insert → Cactus download → `ensureEmbeddings` → swap to `QueryScreen`. The C4 model jumped straight to the query UI; the boot lifecycle wasn't visible at planning time. |
| `SeedLoader` | `lib/services/seed_loader.dart` | The plan (U4) called for a `PHONE_ROLE` env var + `seed_recipes_<role>.json` asset, but C4 folded that inside `DittoService` rather than naming it. |
| `RecipeQueries` (DQL constants) | `lib/prompts/dql_queries.dart` | Plan explicitly named this file ("lock at U1, write a `dql_queries.dart` constants file once the SDK version is known"). C4 did not surface it as a component. Turned out to be the *most-edited file* during hardware bring-up (DQL syntax debugging), so deserves a node. |

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

## What an automated `/understand` run would add

The manual comparison above catches the structural drift (3 unmodelled
components, 1 schema drift). What `/understand` adds on top:

- **Per-file fingerprints** (which file imports which), so the Dart import
  graph becomes a queryable knowledge graph.
- **Layer auto-classification** (UI / Service / Data / Util) — would catch
  that `prompts/dql_queries.dart` is *data* but the `prompts/` directory
  name implies UI/domain; that's a naming-vs-role drift worth surfacing.
- **Diff-impact view**: when we later split `DittoService` into
  `DittoClientService` + `RecipeRepository` (per the
  [flutter/skills review](architecture-vs-flutter-skills.md)), `/understand-diff`
  shows the blast radius.
- **Guided tour generation**: orders the components by dependency so a new
  reader walks the codebase in the right sequence.

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
Code snapshot: `lib/` at commit `38d59c5e` (Stage 0, post-DQL-fix,
post-iOS-deployment-target-bump).
