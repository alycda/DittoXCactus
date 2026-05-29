# Demo playbook — how the remaining holdouts produce a demo worth watching

> Origin: applies PostHog's ["How to demo"](https://newsletter.posthog.com/p/how-to-demo)
> craft guidance to the holdouts that still gate the recorded artifact.
> Companion to [`demo-script.md`](demo-script.md) (the beat-by-beat run sheet)
> and [`SEED.md`](SEED.md) (the pass/fail gates). This file is the *craft*
> layer: the script says what to do, the gates say what counts as passing,
> and this says what makes it land.

The technical holdouts that prove the thesis are mostly green — R1 + R3 + R4 +
R7 cleared on a Pixel pair (2026-05-26). What's left is the work that turns a
passing test into a demo someone remembers: **R2** (the determinism pre-flight
that keeps the demo honest), **R5** (latency, which is really pacing),
**R6a/R6b** (the generated content the audience actually reads), and **R8**
(whether the story survives retelling). Those are exactly the holdouts where
"it passes" and "it lands" are different bars — so they get a craft rubric, not
just a gate.

## The one thing

> **Pick one main point and make everything revolve around it.** (Tip 1)

For this demo the single message is:

> **Two phones meet, their knowledge composes, and neither touched the cloud.**

Every beat, every spoken line, every card on screen is in service of that
sentence or it gets cut. This is the same one-liner SEED Q4 bets R8 on
("two phones meet, their corpora compose") — the demo's job is to make a
non-engineer able to retell it unprompted. If a beat doesn't move that
sentence forward, it's padding (Tip 2: *get to the point; context is 1–2
sentences max*).

## The craft rubric (24 tips → 8 rules we hold ourselves to)

Distilled from the article and bound to our holdouts. The script implements
these; the holdout sign-offs check them.

1. **Lead with the shared pain, in "you" framing.** (Tips 5, 8) Open on a
   problem the room already feels: *"You're somewhere with no signal, and the
   answer you need is on the phone in someone else's pocket."* Not "here is our
   architecture." → gates the **R6a** opening line and the **R8** comprehension test.

2. **Show the before/after side by side.** (Tip 9) The whole demo *is* a
   comparison: same query, same model, same phone — once before the mesh meet
   (`0 from peers`) and once after (`M from peers`). Comparisons create stakes.
   The pre-meet miss is not a bug to hide; it's beat 1's setup. → **R1/R6a**.

3. **Show, don't tell; defer the *how*.** (Tips 10, 20) The audience watches
   the mesh pill flip green and the peer count move from 0 → M. CRDmaths,
   cosine tie-breaks, and the embedding-determinism story are *post-demo
   reading* (this repo, the writeup), never spoken over the live moment.

4. **Real data, readable on screen.** (Tip 15) The solar-system corpus is
   contrived-for-legibility on purpose (SEED Q1) but it is *real* notes the
   audience can read and follow, not lorem ipsum. Cards cite real note IDs. →
   **R6a/R6b** corpus review.

5. **No apologies, high energy, no disclaimers.** (Tips 11, 12) We do **not**
   open with "this is just a hackathon thing" or "the model is small so bear
   with me." The small model is a *feature* of the thesis (edge-native), not an
   excuse. Work-in-progress is expected at a demo (Tip 18) — say what it does,
   not what it doesn't.

6. **Kill dead time: pre-load and cache.** (Tip 16) The ~10s cold load (R5) and
   the 30–60s debug-mode generation are the two stalls that can sink the demo.
   Mitigations are mandatory, not optional — see "Pacing" below. → **R5/R6a**.

7. **Signal the ending; give a call to action.** (Tips 13, 4) Land the closing
   line with descending intonation on "neither touched the cloud," then point
   the room at something they can act on (repo QR / "clone it, the corpora are
   in `assets/`"). The audience should know when to clap and what to do next.

8. **Technical checklist is non-negotiable.** (Tip 14) Notifications off, phones
   silenced, screen-zoom up, URLs bookmarked, **screenshot/B-roll backups
   staged**. Codified in [`demo-script.md`](demo-script.md) pre-flight and the
   R7 offline witness ([`tools/holdout_7/offline_witness.md`](../tools/holdout_7/offline_witness.md)).

## How each remaining holdout produces the demo

### R2 — determinism is the pre-flight that keeps the demo *honest*

R2 isn't an audience-facing beat; it's the gate that makes beat 3 truthful.
"Same query, same model, better answer" is only true if both phones agree on
what an embedding *is*. Same-hardware is bit-perfect (20/20); cross-platform
sits at 0.85 in the diagnostic band (see
[`determinism harness`](../tools/determinism_harness/)). **Demo-craft
consequence:** until cross-platform tightens, rehearse and record on a
**same-model pair** (Pixel ↔ Pixel) so the comparison in beat 3 is
defensible, and let the cross-platform number live in the writeup as honest
diagnostic detail, not on stage. Never narrate a top-k ordering you haven't
re-verified on the exact demo hardware that morning.

### R5 — latency is pacing, not a number

The 10s gate matters because dead air kills a live demo (Tip 16). Treat R5 as
a *pacing budget*:
- **Pre-warm both models before going on stage** — first answer on app launch
  is paid offstage, not in front of the room (the [`cold_load_timer`](../lib/holdouts/cold_load_timer.dart)
  measures this so we know the real number per device).
- **Narrate during the unavoidable wait.** The 30–60s debug-mode generation is
  filled with the beat-2 mesh-meet narration, not silence.
- **Stage the slowest device as phone B** (the one whose notes sync *in*), so
  phone A — the demonstrator's phone, already warm — owns the interactive path.
- If generation can't be made to pace well on the day, that's the documented
  trigger for the Stage-0-only fallback (F3), not an on-stage stall.

### R6a — the rehearsed content is the product the audience reads

R6a's gate is "5 of 5 coherent buffered answers citing the retrieved notes."
Craft layered on top:
- Each of the 5 rehearsed queries is chosen to make the **before/after**
  contrast obvious (Tip 9) — a query whose answer is impossible pre-meet and
  clean post-meet (e.g. `Saturn`).
- Cards are **functional over beautiful** (Tip 22): the SOURCE chip and the
  `M from peers` footer carry the message; nothing decorative competes with
  them.
- The model's quirks (`<think>` drift, etc.) are absorbed structurally before
  they reach the card (see [`model-quirks.md`](notes/model-quirks.md)) — so we
  never have to *apologize* for output on stage (Rule 5).

### R6b — free-text survival is the unscripted credibility moment

Audience-picked queries (≥3 of 5 coherent) are the highest-trust beat *if* they
clear — an unscripted win reads as real in a way a rehearsed one can't (Tip
15's credibility, taken live). Craft: pre-screen the corpus so no audience
query can surface something embarrassing on the big screen (SEED Real
Environment), keep it optional (it's a stretch gate), and **only include it in
the recorded artifact if it lands clean** — a fumbled free-text query violates
Rule 5. If it's flaky, cut it silently; never stage it and apologize.

### R8 — the demo is the raw material for the retelling

R8 passes when three independent readers can articulate Ditto's role, Cactus's
role, and why mesh changes RAG — unprompted. The live demo is what they'll
quote. Craft consequence: the **closing line and the one-liner are written
first and rehearsed verbatim** (Tip 13's ending signal + Tip 1's single
message), because that sentence is what survives into the writeup and the
reader's retelling. The recorded artifact should be cut with Tip 21 polish
(zoom/animate the pill-flip and footer change) so the screenshot a reader
shares carries the message without a caption.

## What this playbook does *not* change

- It adds **no new pass/fail gates.** The holdout definitions in
  [`SEED.md`](SEED.md) and the [plan](plans/001-feat-mesh-rag-demo.md) are
  untouched; this is the presentation layer that sits on top of them.
- It does **not** weaken any thesis-bearing constraint. No cloud path, offline
  (R7) is still never cut, iOS+Android (R10) is still the standing requirement
  even when we *rehearse* on a same-model pair for R2 defensibility.
- The [cut order](SEED.md) still governs under time pressure. Craft polish
  (Tip 21 recording, Tip 24 flourishes) is the *first* thing to drop, not the
  message.
