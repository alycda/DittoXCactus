# Determinism Harness — U1 pre-flight gate + U13 CI regression

Standalone Flutter package for the Mesh RAG demo's **iOS↔Android embedding
determinism spike** (Implementation Units U1 + U13, Requirement R2). It
answers two questions:

> **U1 (pre-flight, one-shot):** Do iOS and Android agree on top-k retrieval
> ordering for ≥95% of a 20-query fixture under the chosen Cactus slug?

> **U13 (regression, every model swap or framework upgrade):** Does a fresh
> measurement on a reference device still match the checked-in baseline?
> Any drift signals an intentional or accidental pin change.

If yes, the demo loop proceeds. If no, the SEED.md cut order pivots to
brainstorm option C ("Narrate the mesh") rather than weakening the thesis.
See [`_docs/plans/001-feat-mesh-rag-demo.md`](../../_docs/plans/001-feat-mesh-rag-demo.md)
§ U1 and `_docs/SEED.md` for context.

This harness is deliberately **not** depended on by the main app. It loads the
same Cactus slug the app uses but runs in its own pubspec sandbox so a model
swap during the gate doesn't ripple into the demo build.

> **First run (2026-05-23):** iPhone 14 Pro ↔ Pixel 6a on `qwen3-0.6` lands at
> **0.85** — in the plan's "fixable by kernel-pin tightening before pivoting"
> diagnostic band, not pivot territory. Pixel↔Pixel is 1.0000 (same hardware
> → bit-for-bit identical). Three iOS↔Android disagreements; two are
> within-top-k reorderings, one (Q10) is a top-1 swap between semantic-twin
> passages. See [`baselines/2026-05-23/README.md`](baselines/2026-05-23/README.md)
> for the full result and the per-device JSONs.

---

## Anatomy

```
tools/determinism_harness/
├── pubspec.yaml                       # standalone Flutter package
├── fixtures/queries.json              # 20 queries + 20 passages, 5 topical clusters
├── baselines/
│   ├── latest/                        # U13 — canonical baseline (overwrite on
│   │                                  # intentional pin change; see its README)
│   │   ├── iphone.json
│   │   ├── pixel-a.json
│   │   ├── pixel-b.json
│   │   └── README.md
│   └── <date>/                        # historical snapshots; preserved lineage
├── lib/
│   ├── agreement.dart                 # pure-Dart math: cosine, top-k (with
│   │                                  # (score desc, id asc) tie-break),
│   │                                  # agreement_rate, fixture parsing
│   ├── output_format.dart             # per-device measurement JSON (read/write)
│   └── cli.dart                       # subcommand dispatch + report rendering;
│                                      # testable without spawning a subprocess
├── integration_test/
│   └── measure_test.dart              # ON-DEVICE: loads Cactus, embeds the
│                                      # fixture, writes a per-device output JSON
├── run.dart                           # CLI entry: `check` (U1 cross-platform)
│                                      # and `check-baseline` (U13 regression);
│                                      # both accept `--ci` for JSON output.
├── test/
│   ├── agreement_test.dart            # pure-Dart unit tests for the math
│   ├── output_format_test.dart        # JSON round-trip tests
│   └── cli_test.dart                  # subcommand routing, exit codes, --ci
│                                      # JSON schema (the CI parsing contract)
└── README.md                          # this file
```

### Why measurement is split from check

Cactus is a Flutter FFI plugin. Its model-loading path needs `path_provider`
and a live `FlutterBinding`, so the measurement half can only run inside a
Flutter integration test (on a real device). The check half is pure
deterministic math over two JSON blobs and benefits from being runnable on a
CI workstation without device access.

The plan's "two modes in `run.dart`" intent is preserved — they're just split
across two files because of Cactus' platform shape.

---

## Workflow

### 1. Measure on each device

From `tools/determinism_harness/`:

```sh
flutter pub get

# iPhone
flutter test integration_test/measure_test.dart -d <ios-device-id>

# Android phone
flutter test integration_test/measure_test.dart -d <android-device-id>
```

Each run downloads + initializes `qwen3-0.6` (one-time per device), embeds
the 20-fixture set, and writes a JSON output to the app's documents directory.
The path is logged at the end of the run, e.g.:

```
Wrote /var/mobile/.../determinism_ios_qwen3_0_6.json
```

The test log also includes a TSV preview between `--- BEGIN TOPK ---` and
`--- END TOPK ---` markers so you can spot-check without pulling the file.

### 2. Pull both outputs to a workstation

```sh
# iOS — use Xcode's "Devices and Simulators" → app container → Download Container
# Android
adb pull /data/data/com.example.determinism_harness/app_flutter/determinism_android_qwen3_0_6.json ./
```

(The exact paths depend on the app's bundle id and Flutter's container layout;
use whatever your tooling exposes.)

### 3. Check (two modes)

**U1 cross-platform** — compare two devices against each other:

```sh
just harness-check ios_output.json pixel-a_output.json
# or directly:
dart run run.dart check ios_output.json pixel-a_output.json
```

**U13 regression** — compare a fresh device run against the checked-in baseline:

```sh
just harness-check-baseline baselines/latest/pixel-a.json fresh-pixel-a.json
```

Add `--ci` (or `--json`) to either form to get a single-line JSON summary on
stdout instead of the human report — stable schema for CI parsing:

```sh
just harness-check-ci ios.json pixel-a.json
just harness-check-baseline-ci baselines/latest/pixel-a.json fresh-pixel-a.json
```

Exit codes (same across all four):

| Code | Meaning |
|------|---------|
| `0`  | `agreement_rate ≥ 0.95` — **R2 gate clears**. Loop proceeds. |
| `1`  | `agreement_rate < 0.95` — **R2 gate fails**. For `check`, cut-order pivot to option C. For `check-baseline`, the model pin drifted — investigate framework/quantization/SoC changes. Disagreeing queries are listed on stdout (human mode) or in the JSON's `disagreements` array (CI mode). |
| `2`  | Usage error (missing args, file not found, malformed JSON, baseline absent). |

The JSON summary schema is pinned by [`test/cli_test.dart`](test/cli_test.dart)
("schema lock for CI parsing"). Required keys: `mode`, `rate`, `matched`,
`total`, `k`, `clearsGate`, `diagnosticBand`, `disagreements`, `a`, `b`.

When the rate lands in the 0.85–0.95 diagnostic band, the human-report CLI
prints a follow-up note suggesting kernel-pin tightening (batch invariance,
quant, backend lock — see the
[Thinking Machines determinism blog post](https://thinkingmachines.ai/blog/defeating-nondeterminism-in-llm-inference/))
before treating the failure as a pivot signal.

### 4. Regenerate the baseline (rare, intentional)

See [`baselines/latest/README.md`](baselines/latest/README.md) for the full
procedure. Short version: capture fresh measurements → cross-check → overwrite
`baselines/latest/*.json` → archive under `baselines/<date>/` for lineage.

---

## Run the unit tests

```sh
cd tools/determinism_harness
flutter test
```

46 tests cover the math layer (cosine, top-k tie-break, agreement_rate
helpers, fixture parsing, JSON round-trip), an end-to-end pass with synthetic
embeddings, and the CLI surface (subcommand dispatch, exit codes, `--ci` JSON
schema). None depend on Cactus — they ensure the agreement-rate calculation
and the operator/CI contract are never where bugs hide. The on-device sanity
gate (a "≥80% of fixture queries put expectedTop1 in top-3" floor) lives in
the integration test and only fires against real Cactus output.

---

## Fixture design

[`fixtures/queries.json`](fixtures/queries.json) is 20 queries × 20 passages
across **5 topical clusters** (planets/moons, stars/galaxies, programming
algorithms, history dates, biology/anatomy). Each query has a clear-cut
expected top-1 passage in its own cluster.

Why 5 clusters of 4 instead of a flat 20: inter-cluster cosine distance is
large enough that top-1 selection is unambiguous, while intra-cluster top-k
ordering is the actual stress on the embedding kernel's numerical
determinism. The 20-fixture size is what the plan specifies; the cluster
structure is the implementer's call (see [`agreement_test.dart`](test/agreement_test.dart),
the `end-to-end with synthetic embeddings` group, for the proof that the
math handles this shape correctly).

---

## Edge cases the math handles

- **Cosine ties**: `topK` applies `(score desc, id asc)` as a deterministic
  tie-break. This is **load-bearing** for R2 and R3 — without it, two devices
  with bitwise-identical embeddings can still produce different top-k ordering
  on tied scores.
- **Dimension mismatch**: `cosineSimilarity` throws `ArgumentError` (loud);
  `topK` drops the offending passage (quiet) — so a model swap mid-corpus is
  contained at the query boundary instead of crashing the harness.
- **Zero vectors**: treated as similarity 0, not NaN (NaN would poison the
  sort).
- **Map iteration order**: `topK` re-sorts by `(score, id)` after collecting
  scores, so the input map's iteration order does not affect output.
  ([`agreement_test.dart`](test/agreement_test.dart) has a regression test for
  this — caught it pre-CI when a hash-map-iteration shortcut was tempting.)

---

## What this gate does **not** measure

- **Cold-load latency** (R5). Lives in `lib/holdouts/cold_load_timer.dart`
  (U14) once that exists.
- **End-to-end retrieval coherence with LLM generation** (R6a). Lives in
  `lib/holdouts/coherence_dryrun.dart` (U16).
- **CRDT sync / idempotence** (R3, R4). Lives in
  `lib/holdouts/idempotence_check.dart` (U15a).

This harness only answers the embedding-determinism question. The U1
pre-flight pass produces the first measurements; U13 promotes the canonical
set under [`baselines/latest/`](baselines/latest/) and adds the
`check-baseline` regression mode + `--ci` JSON output for repeatable CI use.
