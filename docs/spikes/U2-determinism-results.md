# U2 — Cross-platform embedding determinism

**Goal:** `cactus.generateEmbedding(text)` produces cosine ≥ 0.999 across iOS
and Android with the same Cactus model slug, same Q4 quantization, same CPU
backend.

**Gate:** R2 (load-bearing for the CRDT-merge thesis).

## Procedure

1. Lock both phones to the same Cactus model slug (Stage 0 default:
   `qwen3-0.6`). Verify in app boot logs.
2. Pre-warm: launch app on both phones with internet on; let the model
   download. Confirm `Cactus: ready` on the boot screen.
3. Go to airplane mode. Close + relaunch app on both phones.
4. From a debug screen (TODO if not added during rehearsal) or via a temporary
   `scripts/determinism_spike.dart` entry point, embed each fixture string and
   dump the result to `<app docs>/embed_<phone>_<i>.json`.
5. AirDrop / adb-pull the JSON files to this machine.
6. Run `dart scripts/determinism_compare.dart <a.json> <b.json>` (also TODO —
   straightforward host-side cosine compare).

## Fixture strings

| # | Length | Text |
|---|--------|------|
| 1 | 1 char | "x" |
| 2 | 10 char | "tortilla" |
| 3 | 50 char | "what's in a classic chicken tortilla soup recipe?" |
| 4 | 200 char | One full ingredient list joined with commas. |
| 5 | 500 char | One full recipe (ingredients + steps). |

## Results

| Fixture | iOS first 4 dims | Android first 4 dims | Cosine | Pass |
|---------|------------------|----------------------|--------|------|
| 1 | _todo_ | _todo_ | _todo_ | _todo_ |
| 2 | _todo_ | _todo_ | _todo_ | _todo_ |
| 3 | _todo_ | _todo_ | _todo_ | _todo_ |
| 4 | _todo_ | _todo_ | _todo_ | _todo_ |
| 5 | _todo_ | _todo_ | _todo_ | _todo_ |

## Decision

- [ ] **Pass** — cosine ≥ 0.999 on all 5. Lock embedding choice + backend.
- [ ] **Borderline** (0.99 ≤ cosine < 0.999) — swap embedding model and re-test.
- [ ] **Fail** (cosine < 0.99) — pivot Stage 0 to brainstorm option C
      ("Narrate the mesh"; does not depend on embedding determinism).

Chosen model: _todo_
Chosen backend: _todo_
Decision date: _todo_
