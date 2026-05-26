# Holdout 7 — end-to-end offline witness (NEVER CUT)

**R7. End-to-end offline.** The full demo runs with Wi-Fi off and cellular off;
BLE remains on after the airplane-mode toggle described in R1.

This holdout is the **non-droppable Stage-0 floor** — see [`_docs/SEED.md`]
(../../_docs/SEED.md) and plan [`§U15b`]
(../../_docs/plans/001-feat-mesh-rag-demo.md). Every other holdout has a
defined cut order; this one does not. It is also the only holdout where the
*absence* of something — outbound network traffic — is the evidence. Treat the
witness as a demo-day go/no-go gate, not a once-and-done check.

> **CLAUDE.md cross-link.** "The cloud is not in the trust boundary." If R7
> ever fails — even silently in a recording — the demo's thesis collapses. The
> witness exists to make that failure mode loud.

---

## Pre-demo witness (run on BOTH phones)

Run immediately before each recording take. Re-run if anything is unplugged,
re-paired, or rebooted between takes.

### Phone A

- [ ] **Airplane mode ON.** Status bar shows the airplane icon. No Wi-Fi
      indicator, no cellular bars, no roaming icon.
- [ ] **Wi-Fi explicitly OFF** in Settings (airplane mode is the master
      switch but iOS / some Android skins keep Wi-Fi auto-on after toggle —
      verify the per-radio switch shows OFF too).
- [ ] **Cellular explicitly OFF** (same: airplane mode disables it, but the
      per-radio switch in Settings should also show OFF).
- [ ] **Bluetooth manually ON** after the airplane-mode toggle (R1's
      "re-enable BT" step). Status bar shows the BT indicator.
- [ ] **Photograph** the status bar (or the Settings → Wi-Fi /
      Settings → Cellular screens) into `tools/holdout_7/witness/<date>/`
      so the recorded artifact has a still frame to cut to if needed.

### Phone B

- [ ] Repeat all four steps above.

### Host machine (if any host-side observation is set up)

- [ ] **Optional:** if a controlled hotspot + a host-side capture tool
      (Charles, Proxyman, Wireshark) is set up, start the capture window
      *before* the recording rolls. Stop it after. The capture log should
      contain **zero** non-Ditto request URLs during the recording window —
      that's the diagnostic evidence U6's `CactusConfig.isTelemetryEnabled =
      false` pin actually holds under load.
- [ ] **Default (no host-side capture):** the device-side status-bar
      indicators ARE the canonical evidence. The on-camera airplane-mode
      toggle in R1 is what the audience sees; this witness is what the
      demonstrator confirms off-camera.

---

## What this witness does NOT verify

- **Background-radio liveness.** iOS may still attempt to maintain
  cellular registration for emergency calls; this is OS-level and not a
  thesis-breaker for the demo. We don't claim "no electromagnetic
  emission at all" — we claim no internet-protocol traffic the app
  (Ditto, Cactus) initiates.
- **BLE-vs-Wi-Fi-Aware distinction.** R7 only requires BLE; the C4
  model documents that AWDL is the iOS peer-to-peer Wi-Fi transport but
  on a phone in airplane mode + BT-only, AWDL is unavailable anyway.
  See [`docs/c4/model.c4`](../../docs/c4/model.c4) `ditto_store` and
  user memory `project_demo_already_exists`.
- **R5 (cold-load latency).** Covered by U14's `ColdLoadTimer`. R7's
  airplane-mode toggle does NOT reset the boot — cold-load is measured
  separately, on first launch.

---

## Failure modes (what to look for during the recording)

- **"App requires internet" prompts** from any system component (Google
  Play services, iCloud, Cactus model download path). If this fires
  *during* the recording window, the witness has failed — Stage-0
  scope assumed model assets were already cached pre-recording, and
  the seed corpus was pre-baked (see U14 cold-load lever).
- **A mesh peer-count that flickers without a re-pairing event.** BLE
  + airplane mode is robust on both iOS and Android in our testing,
  but if peers drop and re-attach during the recording, narrate it
  rather than hide it.
- **A persistent "no internet" toast.** Generally cosmetic; ignore
  unless it covers the demo UI. The demo doesn't depend on internet,
  so the toast is informational.

---

## Sign-off

Fill this in for each take that survives into the recorded artifact:

```
Date (UTC):
Demonstrator:
Hardware pair:
mesh_rag build commit:
Witness photo set: tools/holdout_7/witness/<date>/
Notes (any anomaly during the take):
```

Then commit the photo set (and update the sign-off line above) to the
run's evidence directory. The recorded artifact's metadata
([`_docs/recording-checklist.md`](../../_docs/recording-checklist.md))
references this file by relative path.
