# R2 determinism baselines — 2026-05-23 (first device run)

First three-device run of the U1 harness against the locked Cactus slug:
`qwen3-0.6` (embedding head, 1024 dims).

| File | Device | Hardware | iOS / Android | qwen3-0.6 cold-load → finish |
|---|---|---|---|---|
| [`pixel-a.json`](pixel-a.json) | `23211JEGR01492` | Pixel 6a | Android 16 (API 36) | ~1m32s (model cached) |
| [`pixel-b.json`](pixel-b.json) | `28191JEGR17016` | Pixel 6a | Android 16 (API 36) | ~1m36s (model cached) |
| [`iphone.json`](iphone.json) | `00008110-00110CEC1AEB601E` | iPhone 14 Pro | iOS 18.6.2 | ~1m30s (model cached) |

## Findings

| Comparison | matched | rate | gate |
|---|---|---|---|
| Pixel A ↔ Pixel B | 20/20 | **1.0000** | PASS |
| iOS ↔ Pixel A | 17/20 | **0.8500** | FAIL — diagnostic band |
| iOS ↔ Pixel B | 17/20 | **0.8500** | FAIL — diagnostic band |

**Same-platform floor is perfect.** Pixel↔Pixel agreement is 1.0000 — the
embedding kernel produces bit-for-bit identical numbers on identical hardware.
That rules out flakiness; the cross-platform drift is signal, not noise.

**Cross-platform sits in the diagnostic band.** Three disagreements out of 20:

| Q | iOS top-k | Android top-k | Nature |
|---|---|---|---|
| Q03 | `P04 P03 P08 P01 P02` | `P04 P03 P01 P08 P02` | Within-top-k reorder, pos 3↔4. Same set. |
| Q05 | `P08 P05 P03 P06 P15` | `P08 P03 P05 P06 P15` | Within-top-k reorder, pos 2↔3. Same set. |
| Q10 | `P10 P12 P11 P08 P03` | `P12 P10 P11 P08 P03` | **Top-1 differs.** iOS retrieves the hash-table passage (correct); Android retrieves the binary-search-tree passage. Same cluster, different first hit. |

Top-1 cosine drift on Q16 and Q17 is on the order of 1e-4 — small enough that
the deterministic `(score desc, id asc)` tie-break can't rescue ordering when
two scores are close.

## What this means for the demo

The 0.85 result lands in the plan's "fixable by kernel-pin tightening before
pivoting to option C" band. Cactus' Flutter SDK currently doesn't expose
quantization/backend/batch knobs, so kernel-pin tightening isn't free.

Status: not pivoting yet. See [`_docs/research/index/open-questions.md`](../../../../_docs/research/index/open-questions.md)
for the live decision log on R2 / Q10.

## Reproduction

```sh
just harness-measure 23211JEGR01492            # Pixel A
just harness-measure 28191JEGR17016            # Pixel B
just harness-measure 00008110-00110CEC1AEB601E # iPhone
# Extract JSON from each test log (BEGIN/END DETERMINISM_JSON markers).
just harness-check iphone.json pixel-a.json
```
