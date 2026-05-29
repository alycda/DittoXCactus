# Demo script — Holdout 1, "airplane-mode moment of magic"

> Origin: U12 in [plans/001-feat-mesh-rag-demo.md](plans/001-feat-mesh-rag-demo.md).
> Holdout 1 spec: [`SEED.md` §Holdout Scenarios row 1](SEED.md). Requirements: R1, R7, R10.
> Demo-craft rubric this script implements: [`demo-playbook.md`](demo-playbook.md).

This script is rehearsable end-to-end. The recorded artifact targets a single take; B-roll for the BLE-pairing moment is permitted **only with on-camera disclosure** per [SEED.md §Real Environment](SEED.md).

## The one thing (say it, then prove it)

Everything below serves a single sentence (playbook Rule "The one thing"):

> **Two phones meet, their knowledge composes, and neither touched the cloud.**

**Open on the shared pain, in "you" framing** — not the architecture: *"You're
somewhere with no signal, and the answer you need is sitting on a phone in
someone else's pocket. Watch what happens when those two phones just… meet."*
That's the whole intro — keep context to 1–2 sentences and get to beat 1.

**No apologies.** Don't open with "this is just a hackathon build" or "the
model is small, so bear with me." The small on-device model *is* the thesis,
not a caveat. Say what it does; never pre-lower expectations.

The whole demo runs **with no internet** — Wi-Fi off, cellular off, BLE on (R7 / Holdout 7, the never-cut holdout). Each phone has loaded the app once on a real network before stage so model weights are already on disk.

## Pre-flight checklist (offstage, 5 minutes before)

Tick every box. Anything missed surfaces on stage as a stall.

- [ ] Phone A: launched via `just app-run-a-demo <device-a>` (or `just app-run-a` with `PHONE_ROLE=a`). Boot complete, on **Notes** tab, 5 notes visible (Sun, Mercury, Venus, Earth's Moon, Mars). `mesh: alone` pill is gray.
- [ ] Phone B: launched via `just app-run-b-demo <device-b>` (or `just app-run-b`). Boot complete, on **Notes** tab, 5 notes visible (Jupiter, Saturn, Uranus, Neptune, Pluto). `mesh: alone` pill is gray.
- [ ] Both phones in **airplane mode**, **Bluetooth manually re-enabled from Control Center** (iOS quirk — airplane mode disables BT by default). Wi-Fi off. Cellular off.
- [ ] Phones at least 3 m apart so BLE peer discovery hasn't fired yet (we want beat 2 to land on camera, not pre-stage).
- [ ] One **rehearsed query** picked and verified during the dry run. Recommended primary: `Saturn`.
  Why: Saturn is on phone-b only. Before BLE meet → phone-a retrieval misses entirely or returns a weak inner-planet match. After meet → Saturn's note lands top-1 with a `phone-b` SOURCE chip. The footer `0 from peers` → `1+ from peers` is the visible R1 signal.
- [ ] Backup query if Saturn doesn't land: `planets` (mixed inner+outer; less dramatic but more robust).
- [ ] Demo overlay enabled on at least the demonstrator's phone (phone A) via `--dart-define=DEMO_OVERLAY=true`. The overlay shows peer count + note count + last-query latency in the top-right corner. Audience can't easily read it; it's a confidence monitor for the demonstrator and the recording.
- [ ] **Models pre-warmed (R5 pacing).** Both phones have completed one full boot → first answer *offstage* so the cold-load cost (embed + LLM init) is already paid. The 10s R5 budget is for the demo's credibility; don't spend it on camera. Stage the **slower** device as phone B (its notes sync *in*) so the warm phone A owns the interactive path.
- [ ] **Technical setup (playbook Rule 8 / Tip 14):** notifications + Do-Not-Disturb on **both** phones and the recording machine; phones silenced; screen brightness up; any projector/capture tested at the real resolution. If screen-mirroring, bump the mirror zoom so the mesh pill and footer are camera-legible from the back of the room.
- [ ] **Backups staged:** the rehearsal B-roll of a clean pairing moment is on the recording machine and cued (F4), and a screenshot of a good post-meet card stack is saved — so a stall never becomes dead air.

## Three beats

The whole choreography is **~90 seconds on camera**. Don't pad. The point is the visible state change in beats 2 and 3.

### Beat 1 — "phone A alone"

**Verbal:** *"Phone A holds five study notes about the inner solar system. I'll ask it about Saturn — which isn't in its corpus."*

**On phone A:**
1. Tap **Flashcards** tab. (FlashcardsTab is empty; topic field shows pre-fill if `initialTopic` is wired.)
2. Type `Saturn` (or accept the pre-filled topic). Tap **Generate**.
3. Wait for the streaming indicator. On Pixel 6a debug ~30-60s — narrate while you wait. Tap the **show thinking** chevron if you want the audience to see the model reasoning.

**On screen, audience should see:**
- Footer: `drew on N notes (0 from peers)` — N is whatever inner-planet notes the retrieval surfaced (Saturn isn't there). The "0 from peers" is the load-bearing pre-meet signal.
- If retrieval surfaces *nothing* relevant, the model may produce no card or a generic card. **That's fine for the script** — it sets up beat 3's contrast.
- `mesh: alone` pill in the AppBar (gray).

### Beat 2 — "they meet"

**Verbal:** *"Now I'll bring phone B into Bluetooth range. Phone B holds notes on the outer planets — Jupiter, Saturn, Uranus, Neptune, Pluto. Watch the Notes tab on phone A."*

**On both phones:**
1. Move phone B physically within 1-2 m of phone A.
2. On phone A, tap the **Notes** tab.
3. Wait. BLE peer discovery typically lands within 2-5 s.

**On screen, audience should see — and this is the moment:**
- The `mesh: alone` pill flips to `mesh: 1 peer` and turns **green**. Camera-legible monospace 16pt, can't miss it.
- The Notes list grows: a new `phone-b` contributor group appears under phone-a's notes, with Jupiter / Saturn / Uranus / Neptune / Pluto syncing in.

**Hold for ~2 seconds before regenerating.** This pause matters:
1. It gives the audience time to read the new notes.
2. It gives Ditto's CRDT sync time to absorb all 5 of B's notes (not just 1-2).
3. It gives `RetrievalService.ensureEmbeddings` time to backfill embeddings for the newly-synced notes if any are missing.

If `ensureEmbeddings` hasn't run on the synced notes by the time you regenerate in beat 3, retrieval will silently drop them (the `embedding.length != queryVec.length` guard at the [rankTopK](../lib/services/retrieval_service.dart) boundary). Two seconds is usually enough on a Pixel 6a.

### Beat 3 — "ask again"

**Verbal:** *"Now I ask phone A the same question. Same query, same model — but now its corpus includes phone B's notes."*

**On phone A:**
1. Switch back to **Flashcards**.
2. Tap **Regenerate**.

**On screen, audience should see:**
- Footer: `drew on N notes (M from peers)` — **M ≥ 1**. This is the R1 signal. Read it aloud: *"Drew on five notes, three from a peer."*
- The generated card stack now includes Saturn-specific content with `…<short-id>` SOURCE chips drawn from phone-b's note ids.
- Latest generation sits at the top of the history; older generations stay below — the audience can scroll down to verify it was different before.

**Closing line:** *"Two phones met, their knowledge composed, and neither used the cloud."*

Deliver it with **descending intonation and a beat of silence** — that's the
signal the audience can clap (playbook Rule 7 / Tip 13). Don't trail off into
"...so, yeah, that's basically it." Land the sentence; it's the same one-liner
R8 (narrative pickup) is won or lost on.

**Call to action (Tip 4):** immediately follow with one actionable thing —
*"The corpora are in `assets/`, the repo's on screen, clone it and pair your
own two phones."* A QR to the repo on the final frame does this without
spoken words. The room should leave knowing the one sentence **and** what to do
with it.

---

## Fallbacks

Per [SEED.md §Cut Order](SEED.md) and §Real Environment.

### F1 — BLE pairing fails on stage

**Symptoms:** mesh pill stays gray after 10+ seconds with phones <1 m apart.

**Recovery:** stop the rehearsed take. Open Settings → Bluetooth on each phone, confirm BT is on. If still gray after a second attempt, escalate to F2 or F4.

### F2 — LAN fallback

Join both phones to the same Wi-Fi network (a portable hotspot with Wi-Fi but cellular off is fine; the LAN transport is enabled in Ditto config and doesn't require internet). Ditto's LAN transport discovers peers without BLE. Mesh pill should flip green within 5 seconds.

**This still satisfies R7** (end-to-end offline) — the hotspot has no internet, just LAN.

### F3 — Stage-0-only ship (per SEED cut order item 5)

If Stage 1 (LLM generation) is unreliable on the day, drop the FlashcardsTab beat entirely. The demo becomes:

1. *"Phone A has five notes."* Show Notes tab on A. Mesh pill gray.
2. *"Watch when B comes into range."* BLE pairing happens. Mesh pill turns green. B's 5 notes stream into A's Notes tab under the `phone-b` contributor group.
3. *"The corpora composed. No cloud, no internet."*

This is a complete R1-style demo on the Notes tab + per-contributor grouping alone. The visible signal is the same: gray → green, list grows.

The writeup must explicitly name the Stage-1 omission per [SEED.md loop exit condition](SEED.md).

### F4 — B-roll insertion

If both F1 and F2 fail mid-take, the recorded artifact substitutes B-roll for the pairing moment **with on-camera disclosure** (the demonstrator says: *"this clip is from rehearsal"*). The verbal claim alone — no visible state change — is the last-resort and only acceptable if F3 also can't be staged in time.

---

## What can go wrong on stage (and what to do)

| Symptom | Cause | On-stage move |
|---|---|---|
| Mesh pill stays gray | BLE not discovering | F1 → F2 |
| Notes tab on A doesn't fill in | Sync stalled or notes not in B's corpus | Tap Notes tab again to force a re-paint; wait 5s; if still nothing, F2 |
| Footer says `0 from peers` after regen | Peer's embeddings not backfilled yet, OR retrieval dimension mismatch | Wait 5s more, regenerate; if still 0, F3 (skip beat 3) |
| Card stack is empty / "no cards in this generation" | Model spent budget inside `<think>`, no parseable Q/A | Tap **show thinking** to acknowledge the model was working; F3 if it persists |
| Card contains obviously fabricated content (no SOURCE chips) | Model fabricated under empty retrieval | Don't read the card aloud; mention the SOURCE chips are how grounding shows; F3 |

The demo overlay (top-right corner, demonstrator-only legibility) helps you spot the first three before they show on screen.

---

## Recording notes

- Single take preferred. If a take fails at beat 1, restart from pre-flight (relaunch both apps with the same role flags). State persists in Ditto's local store, so re-runs are idempotent.
- Hold the camera or tripod so both the mesh pill AND the Notes/Flashcards body are framed.
- Speaking pace matters more than perfect English — the audience needs to *see* beat 2 land. Don't talk over the green flip.
- 3 of 3 successful dry-run takes on the chosen device pair is the U12 verification gate. If you can't reproduce in 3 takes, escalate fallback.
