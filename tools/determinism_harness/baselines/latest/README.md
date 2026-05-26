# Canonical R2 baseline (U13)

The per-device measurement JSONs in this directory are the **frozen reference
output** for the locked Cactus slug. `run.dart check-baseline` compares fresh
device measurements against these files; any drift signals an intentional or
accidental pin change.

| File | Device label | Hardware | Originally captured |
|---|---|---|---|
| [`iphone.json`](iphone.json) | `ios` | iPhone 14 Pro | 2026-05-23 |
| [`pixel-a.json`](pixel-a.json) | `android` | Pixel 6a (`23211JEGR01492`) | 2026-05-23 |
| [`pixel-b.json`](pixel-b.json) | `android` | Pixel 6a (`28191JEGR17016`) | 2026-05-23 |

The originals live under [`../2026-05-23/`](../2026-05-23/) with the full
findings narrative. This directory is the always-current alias; promoting a
new pin overwrites these files (the old ones stay in `../<date>/`).

## Pin parameters

- Model: `qwen3-0.6` (Cactus embedding head)
- Dimension: 1024
- k: 5
- Fixture: [`../../fixtures/queries.json`](../../fixtures/queries.json) (20×20, 5 clusters)

## When to regenerate

Only on **intentional** pin change. Examples:

- Cactus framework upgrade that bumps the embedding kernel.
- Quantization or batch-invariance settings exposed by Cactus.
- Switching to a different embedding slug (e.g. evaluating EmbeddingGemma).
- Hardware swap on the reference devices (different SoC may produce different
  same-platform numbers — though for R2 we expect bit-identical same-hardware
  output).

Procedure:

```sh
# 1. Capture fresh measurements on each reference device.
just harness-measure <iphone-id>
just harness-measure <pixel-a-id>
just harness-measure <pixel-b-id>

# 2. Pull the per-device JSONs to the workstation (see harness README §2).

# 3. Cross-check the new measurements against each other first.
just harness-check ios.json pixel-a.json

# 4. Only if cross-check looks sane, overwrite the baselines.
cp ios.json     tools/determinism_harness/baselines/latest/iphone.json
cp pixel-a.json tools/determinism_harness/baselines/latest/pixel-a.json
cp pixel-b.json tools/determinism_harness/baselines/latest/pixel-b.json

# 5. Also archive under a fresh date so the lineage is preserved.
mkdir tools/determinism_harness/baselines/$(date +%Y-%m-%d)
cp tools/determinism_harness/baselines/latest/*.json tools/determinism_harness/baselines/$(date +%Y-%m-%d)/
```

The diff on `baselines/latest/*.json` in the resulting commit is the
audit trail for the pin change.

## How CI uses these

```sh
# After a fresh measurement, regression-check against the baseline.
just harness-check-baseline-ci baselines/latest/pixel-a.json fresh-pixel-a.json
```

`--ci` (alias `--json`) emits a single-line JSON summary on stdout; non-zero
exit signals `agreement_rate < 0.95`. The JSON schema is locked by tests in
[`../../test/cli_test.dart`](../../test/cli_test.dart) — change with care.
