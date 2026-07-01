---
title: "Prep Android devices against thermal throttling before sustained-inference holdout runs"
date: 2026-07-01
category: conventions
module: tooling
problem_type: convention
component: development_workflow
severity: medium
applies_when:
  - Running a latency-sensitive holdout on-device (R2 determinism/latency, R5 cold-load)
  - Any run that pins the CPU/NPU with sustained inference for more than ~30s
  - Comparing per-device numbers across two phones (the Pixel pair) where a hot phone would skew one side
  - Recording an offline/mesh capture where a mid-run clock throttle would be visible on camera
related_components:
  - development_workflow
  - determinism_harness
  - documentation
tags:
  - android
  - adb
  - thermal-throttling
  - reproducibility
  - holdout
  - device-ops
  - justfile
---

# Prep Android devices against thermal throttling before sustained-inference holdout runs

## Context

The live Pixel-pair holdout runs on 2026-05-26 (R1/R3/R4/R7 cleared) and the R2/R5 measurement passes pin the on-device Qwen models for minutes at a time. A phone plugged into USB during those runs fights **two** heat sources simultaneously: sustained inference *and* charge current. The kernel thermal governor hits its skin-temperature backoff sooner, drops clocks mid-run, and the latency numbers stop being reproducible — they depend on how hot the phone happened to be when the run started.

A `ce-sessions` search on 2026-07-01 (plus shell-history, repo, and GitHub-issue grep) found **no record** of how this was handled during the demo: no `dumpsys`, no `adb` thermal commands, no discussion — in any session, either shell-history file, the justfile, or the issues. The most likely explanation is that the demo-run device wrangling happened at a terminal that didn't persist to any durable artifact, and any thermal workaround was done ad-hoc and never captured. This doc closes that gap: it names the mitigation and ships it as reproducible `just` recipes so the next run isn't unreproducible for the same reason.

> **Verification status:** the command *forms* below are standard Android (`dumpsys battery set`, `cmd thermalservice` — API 29+). They were **not** re-verified on the exact 2026-05-26 Pixel pair while writing this doc. Re-confirm on-device before trusting a measurement pass.

## Guidance

Before a latency/cold-load run on an Android device, run `just thermal-prep <device-id>`; after, **always** run `just thermal-reset <device-id>`. Read the starting state with `just thermal-status <device-id>` first — if the phone is already hot, let it cool rather than masking it.

Two levers, with **different guarantees** — this distinction is the whole point:

1. **`dumpsys battery set ac|usb|wireless 0`** — makes the framework report the phone as *not charging*, so the battery HAL stops drawing charge current while the cable stays plugged in (still needed for adb + `flutter run`). This is a **real** heat reduction: no charge current means less waste heat next to the SoC. Restore with `dumpsys battery reset`.
2. **`cmd thermalservice override-status 0`** — forces the *reported* thermal status to `NONE` (0). This **only changes what the framework and apps see**; the kernel/HAL can still physically throttle the silicon under genuine heat. It stops framework-level mitigation (e.g. skin-temp backoff, background-work deferral), it does **not** override physics. Restore with `cmd thermalservice reset`.

Keep the USB cable connected the whole time — `set usb 0` stops the charge *current*, not the data connection.

## Why This Matters

- **Reproducibility of the R2/R5 numbers.** The determinism harness (`tools/determinism_harness/`) and the R5 cold-load timer produce numbers that only mean something if the device wasn't throttling. A silent mid-run clock drop makes two identical builds look different, or makes the Pixel pair look asymmetric when the only difference was thermal headroom.
- **On-camera risk.** For the offline/mesh capture, a throttle-induced latency spike mid-demo reads as "the mesh is slow," not "the phone got hot." Prepping removes a confounder from the recording.
- **It was invisible before.** The single most-cited reason this wasn't documented is that it never landed anywhere durable. A `just` recipe is the durable record of *what we ran* — the same argument the justfile-recipes convention makes for offline captures.

## When to Apply

- Any R2 latency or R5 cold-load measurement pass (`just harness-measure`, `just bake-seeds-*`)
- Any holdout capture where mid-run latency is observable
- Cross-device comparison runs on the Pixel pair
- **Not** needed for pure-Dart holdout math (`just holdout-34-test`, `just harness-test`) — those don't touch a device.

## Examples

```sh
# Before a measurement pass:
just thermal-status 23211JEGR01492   # is it already hot? let it cool if so
just thermal-prep   23211JEGR01492   # halt charge current + mask framework throttling
just harness-measure 23211JEGR01492  # the actual run
just thermal-reset  23211JEGR01492   # ALWAYS — restores charging + real reporting
```

Forgetting `thermal-reset` leaves the phone reporting "not charging" until it reboots — a confusing state for the next person to pick it up.

## Related

- Recipes: `thermal-status` / `thermal-prep` / `thermal-reset` in the [`justfile`](../../../justfile)
- Sibling convention: [justfile-recipes-for-repeated-commands-2026-06-01.md](justfile-recipes-for-repeated-commands-2026-06-01.md) — the "durable record of what we ran" argument
- Research note flagging thermal throttling as a latency/bit-parity risk: `_docs/research/gemini-deep-research.md` (line ~161), `_docs/research/gemini.md` (bit-parity Q under accelerator switching), indexed under the `thermal-throttling` tag in `_docs/research/index/by-tag.md`
- Determinism harness whose numbers this protects: `tools/determinism_harness/`
