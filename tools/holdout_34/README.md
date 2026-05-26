# Holdouts 3 + 4 — sync idempotence + bidirectional merge

Live-device runner for **R3** (sync idempotence) and **R4** (bidirectional
merge), the two CRDT-layer holdouts that make the mesh-RAG thesis observable
end-to-end. The plan ([`§U15a`](../../_docs/plans/001-feat-mesh-rag-demo.md))
allows either an orchestrated runner or a manual checklist; this directory
ships the **checklist downgrade** for the two-phone hackathon demo.

## What's here

```
tools/holdout_34/
├── README.md         # this file — semantics + how to run
├── runner.sh         # interactive bash walkthrough, captures evidence
├── verdict.dart      # pure-Dart CLI: snapshot JSONs → PASS/FAIL JSON
└── runs/             # gitignored; one subdir per run, holds evidence
    └── <timestamp>/
        ├── a-pre.json, b-pre.json
        ├── a-post.json, b-post.json
        ├── a-remeet.json, b-remeet.json
        ├── verdict.json
        └── sign-off.md
```

The math lives in [`lib/holdouts/idempotence_check.dart`](../../lib/holdouts/idempotence_check.dart);
the unit tests at [`test/holdouts/idempotence_check_test.dart`](../../test/holdouts/idempotence_check_test.dart)
exercise it without devices, so the verdict logic stays green on every CI
run even when no holdout has fired.

## Requirements verified

- **R3 (sync idempotence).** Re-meeting after no edits → no new ids, no
  removed ids, no per-id content change, no top-k drift for the fixture
  query.
- **R4 (bidirectional merge).** After two devices meet over BLE, both
  hold the union of their pre-meet corpora, with shared ids carrying
  structurally-equal content on both sides.

## How to run

1. **Boot both phones** with disjoint seed corpora:
   ```sh
   just app-run-a <iphone-device-id>     # PHONE_ROLE=a, seed_notes_a.json
   just app-run-b <pixel-device-id>      # PHONE_ROLE=b, seed_notes_b.json
   ```
   Confirm each pill shows `mesh: alone`.

2. **Kick off the runner** from the repo root:
   ```sh
   just holdout-34
   # or directly: tools/holdout_34/runner.sh
   ```
   The script walks 6 phases and prompts at each: pre-meet capture →
   meet → post-meet capture → re-meet → post-re-meet capture → verdict.

3. **Capture snapshots** when prompted. The fastest path is the in-app
   long-press "export corpus JSON" action on the Notes tab (U10) →
   AirDrop / Drive / adb pull off the device → paste the local path
   when the script asks.

4. **Sign off** the run by filling in `runs/<timestamp>/sign-off.md`
   after a PASS verdict. The sign-off is the artifact U17's recorded
   demo cites as evidence the R3/R4 bars cleared on the recorded
   hardware pair.

## Snapshot shape

A snapshot is a JSON array of `StudyNote.toDittoDoc()`-shaped maps —
exactly what `INSERT INTO notes DOCUMENTS (:doc)` consumes. Minimal
example:

```json
[
  {
    "_id": "a4b8…",
    "topic": "jupiter-moons",
    "contributor": "a",
    "body": "Io, Europa, Ganymede, Callisto",
    "tags": ["space"],
    "embedding": [0.123, -0.456, ...],
    "createdAt": "2026-05-25T12:00:00.000Z",
    "acceptedBy": [],
    "originalNoteId": "",
    "originalContributor": ""
  }
]
```

The top-k input (optional `--topk-pre` / `--topk-post`) is a JSON array
of `_id` strings in retrieval order.

## Verdict CLI (standalone)

The verdict is independently invokable for ad-hoc checks (e.g., a
post-mortem on a recorded-artifact run):

```sh
dart run tools/holdout_34/verdict.dart \
  --pre-a   path/to/a-pre.json   --pre-b   path/to/b-pre.json   \
  --post-a  path/to/a-post.json  --post-b  path/to/b-post.json  \
  --remeet-a path/to/a-remeet.json [--remeet-b path/to/b-remeet.json] \
  [--topk-pre path/to/topk-pre.json --topk-post path/to/topk-post.json] \
  [--ci]
```

Exit codes mirror the determinism harness: `0` on PASS, `1` on FAIL,
`2` on usage / file-read error. `--ci` (alias `--json`) emits a
single-line JSON for downstream parsing.

## Cut-order placement

Per `_docs/SEED.md`, U15a sits at cut-order item 5 (same tier as R6a).
If the loop runs out of time before this runs cleanly, the demo can
still satisfy R3 + R4 by capturing them **manually during the recorded
artifact**: the audience sees the mesh-status pill flip from `alone`
to `1 peer`, the two corpora visibly merge, and a second meet with no
edits leaves the state unchanged. The runner formalizes that into a
reusable evidence package.

U15b (holdout 7 — end-to-end offline) is held separately under
[`tools/holdout_7/`](../holdout_7/) because R7 is **never cut**.
