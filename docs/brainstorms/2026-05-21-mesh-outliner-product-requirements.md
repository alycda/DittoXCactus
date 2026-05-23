---
date: 2026-05-21
topic: mesh-outliner-product
---

# Mesh-Synced Outliner + Hackathon Demo

## Summary

A Workflowy-UX × Logseq-data-ownership outliner with Ditto-based offline mesh sync across the user's own devices. v1 ships capture-only (greenfield) with no AI; the hackathon demo wraps this substrate as Mesh Jeopardy with live audience capture during a 60-90s mini-talk. AI augmentation, Logseq/Workflowy migration, and writeup-thesis features (specialist models, preference-aware merge) are deferred.

---

## Problem Frame

The user maintains tens of thousands of bullets across Workflowy (UX/speed lead, data-ownership lag) and Logseq (data-ownership lead, UX/perf lag). They have been incrementally moving from Workflowy to Logseq + iCloud, but Workflowy's mirrors and backreferences are hard to extract intact — so a large slice of their externalized cognition remains stuck. Neither tool is satisfactory: Workflowy puts the user's "literal brain" at vendor risk; Logseq's mobile UX and 10k+ bullet performance lag the daily-driver bar. Trust in AI to "eat" notes is also low — the user wants hands-on every note before AI authorship enters the loop.

On a separate axis, the user is at a work hackathon with a Flutter app built on Cactus (on-device LLM) and Ditto (offline mesh transport) and wants a demo that probes the combination without committing to a multiplayer-game product identity. The seed exploration in `docs/IDEAS-MULTIPLAYER.md` (Jeopardy Together / CAH-style / Bar trivia) treated multiplayer as the product; brainstorm pressure-testing exposed that the only direction with first-person lived evidence (collaborating notes at an AI conference with a coworker) was actually evidence for the *outliner* product, not a game. The hackathon needs a demo surface; the demo surface is not the product.

The intellectual lineage is Sönke Ahrens's *How to Take Smart Notes* — atomic, linked notes with stable IDs and bottom-up structure that emerges from connections rather than imposed taxonomy. Mirrors are the Zettelkasten "register"; backreferences are the bidirectional link that makes structure emerge.

---

## Actors

- A1. **Note author** — the user, capturing bullets on phone or laptop, building a personal knowledge graph through mirrors and backreferences over time
- A2. **Demoer** — the user at the hackathon, presenting and orchestrating the Mesh Jeopardy demo
- A3. **Demo audience member** — anyone in the hackathon room who opens the app on their own phone during the demo, captures bullets during the mini-talk, and participates in the Jeopardy round
- A4. **Ditto transport** (system) — peer-to-peer offline mesh sync over BLE / local wifi, the substrate for both multi-device-for-one-user and multi-phone-audience cases
- A5. **Cactus on-device LLM** (system) — qwen3-1.7 or comparable small model running locally on each phone; generates clues for the demo and (post-v1) augments the user's notes against their corpus

---

## Key Flows

- F1. **Capture and outline (v1 outliner core)**
  - **Trigger:** A1 opens the app on phone or laptop and starts typing
  - **Actors:** A1
  - **Steps:** Type a bullet; Tab to indent under previous; Shift+Tab to outdent; zoom into a bullet to focus; create a `[[Page]]` link or `#tag` inline; close keyboard and capture the next bullet
  - **Outcome:** A hierarchical bullet structure persisted to markdown on disk with each bullet carrying a stable UUID; tags and page references are searchable via the backlinks pane
  - **Covered by:** R1, R2, R3, R4, R5

- F2. **Mirror a bullet (v1 outliner mirrors)**
  - **Trigger:** A1 invokes the "mirror to" command on an existing bullet
  - **Actors:** A1
  - **Steps:** Select bullet B; invoke mirror command; pick or create the target location; mirror appears at target; edits in either location propagate to the other; the backlinks pane shows the bullet's two homes
  - **Outcome:** One logical bullet present in two physical locations, identity preserved via stable UUID, no syntax leak in the rendered view
  - **Covered by:** R6, R7, R8

- F3. **Multi-device mesh sync (v1 mesh)**
  - **Trigger:** A1 brings a second device (laptop, second phone, iPad) into BLE / local-wifi range of the device that already holds the corpus
  - **Actors:** A1, A4
  - **Steps:** Devices discover each other over Ditto; bullets and structure replicate; A1 edits a bullet on device D1; edit visible on device D2 within seconds; A1 disconnects D1 from the network and keeps editing on D2; reconnects D1 later; changes converge without manual conflict resolution
  - **Outcome:** The user's corpus stays consistent across their personal devices without any cloud server
  - **Covered by:** R10, R11, R12

- F4. **Hackathon demo: Mesh Jeopardy with live audience capture**
  - **Trigger:** A2 launches the demo on stage at the hackathon
  - **Actors:** A2, A3, A4, A5
  - **Steps:** A2 asks the audience to open the app; A2 gives a 60-90s scripted mini-talk; A3 members capture bullets during the talk; phones discover each other via Ditto and replicate the audience corpus; A2 ends the talk and triggers Jeopardy mode; A5 generates clues from the merged corpus; A2 reads each clue; A3 members race to answer from their own phone's view; A2 reveals
  - **Outcome:** The audience experiences (1) an on-device LLM generating contextual clues from notes they themselves captured 60 seconds earlier, (2) mesh-sync working without wifi, (3) the substrate that becomes the outliner product post-hackathon. The demo completes gracefully if zero audience phones engage — A2's own bullets captured during the talk act as the corpus floor.
  - **Covered by:** R16, R17, R18, R19, R20

---

## Requirements

**Outliner core (v1)**

- R1. Every bullet has a stable block ID (a UUID at the implementation level) assigned at creation, preserved across saves, sync, and round-trip through markdown on disk
- R2. Bullets support hierarchy via indent/outdent and zoom-into-bullet navigation
- R3. The default view is distraction-free bullets; no sidebar widgets, no kanban, no databases, no Notion-style block menu
- R4. Tag syntax (`#tag`) and page-link syntax (`[[Page]]`) create outgoing links from a bullet; a backlinks pane aggregates inbound references per page and per tag
- R5. Block-level backlinks: viewing any bullet shows every other bullet that references it by block ID

**Outliner mirrors (v1)**

- R6. The user can mirror a bullet to another location; the mirror and the source share the same UUID and are logically one bullet
- R7. Editing a bullet in any of its locations propagates the edit to every location; the rendered view shows no block-reference syntax
- R8. The markdown-on-disk format records bullet identity such that mirrors round-trip through plain markdown without losing their relationship

**Outliner performance (v1)**

- R9. The app sustains snappy interaction (capture, navigation, search, zoom) at corpus sizes encountered during v1 dogfood, on the architectural trajectory toward 10k+ bullets on mobile. The 10k+ ceiling is a Stage 1 stretch test, *not* a v1 ship gate — v1 acceptance is "no perf cliff observed at the user's actual v1 corpus size."

**Mesh sync (v1)**

- R10. The user's bullets replicate across all of their own devices (phone, second phone, laptop, iPad) via Ditto P2P with no cloud server
- R11. Offline edits on one device merge cleanly with offline edits on another device when both reconnect; mirror semantics survive concurrent edits across devices
- R12. The user can see which of their devices are currently in mesh range and which are syncing

**Storage and portability (v1)**

- R13. Bullets persist to markdown files on local disk on each device
- R14. The markdown format embeds stable block IDs so the corpus can be read by other markdown tools without losing bullet identity
- R15. The user can export the entire corpus as plain markdown files at any time

**Hackathon demo (Stage 0)**

- R16. The demoer can give a 60-90s scripted mini-talk and the audience can capture bullets during it on their own phones
- R17. Phones in the hackathon room discover each other via Ditto mesh and replicate the audience bullet corpus across all participating phones
- R18. After the mini-talk, the demoer can trigger Jeopardy mode; Cactus generates clues from the merged audience corpus and the demoer's UI displays the current clue
- R19. If zero audience phones engage, the demoer's own bullets captured during the talk act as the corpus floor and the demo completes
- R20. The demo surfaces visible "mesh joined" / "Cactus generating" / "clue ready" feedback states so the audience can follow the technical moment

---

## Acceptance Examples

- AE1. **Covers R6, R7.** Given a bullet B is mirrored to a second location, when the user edits B in either location, both locations show the updated text within the same UI interaction.
- AE2. **Covers R10, R11.** Given two of the user's devices D1 and D2 have the corpus replicated, when D1 goes offline and the user edits a bullet on D1 while also editing a different bullet on D2, when both devices reconnect, the corpus on both devices reflects both edits without manual conflict resolution.
- AE3. **Covers R18, R19.** Given zero audience phones have engaged during the mini-talk, when the demoer triggers Jeopardy mode, the demo proceeds using bullets the demoer captured during their own talk as the sole corpus.
- AE4. **Covers R5.** Given a bullet B exists at locations X and Y (via mirror) and is referenced from a third bullet C, when the user opens the backlinks pane for B, references from X, Y, and C are all listed.

---

## Success Criteria

- The user starts capturing new notes in v1 in parallel with their Logseq use; within one week of dogfood the v1 outliner feels faster than Logseq on mobile at their corpus size and the user keeps reaching for v1 by reflex
- The hackathon demo runs in front of the work audience; the room visibly experiences the mesh-sync moment and the Cactus clue generation; the demoer can reproduce the demo with one other practiced collaborator without surprises
- ce-plan can produce an implementation plan from this doc without inventing product behavior, scope boundaries, or success criteria — only technical architecture decisions (engine choice, data-model evolution from current `lib/models/study_note.dart`, mesh conflict resolution semantics) remain open

---

## Scope Boundaries

### Deferred for later

- AI augmentation against personal corpus (Cactus RAG, AI-assisted note strengthening) — trust-gated; ships only when the user is willing to let AI read and suggest against their corpus
- Granola-shaped post-capture synthesis — AI fills in connections, action items, and decisions against external context (e.g., meeting audio) or against the corpus itself
- Willow-shaped voice capture as an input modality
- Logseq corpus import (markdown + block UUIDs + page backlinks round-trip)
- Workflowy corpus import with mirrors round-trip — the largest deferred work; the "I trust this with my brain" gate
- App naming — deferred to a separate pass closer to v1 ship; this doc uses "the outliner" as the working reference

### Writeup-thesis connection (research framing, not product roadmap)

These are stages of the user's separate Mesh-RAG writeup thesis, not implementation milestones for this product. They appear here so a planning agent does not interpret them as deferred features.

- Specialist small models (Stage 1): domain-tuned tiny models (note-curator, summarizer, retriever) replacing the generalist on-device LLM
- Preference-aware merge (Stage 2): when two users' outliners mesh, the merge respects each user's preferences rather than performing a flat union
- Adversarial filtering (Stage 3): promotion of merged content into canonical form needs reputation, consensus, or provenance
- Generational evolution (Stage 4): temporal weighting or branch-on-divergence semantics for notes that drift over time

### Outside this product's identity

- CAH-style party game built on Cactus card generation — fun but no trajectory-fit with the outliner; was seed direction (b), now dead
- Bar trivia / commercial venue play — a different product with a different actor set, corpus model, and sales motion; was seed direction (c), parked as out-of-identity rather than deferred
- Audience-as-multiplayer beyond the hackathon-room demo — the product is multi-device-for-one-user, not multi-user co-edit
- Transclusion (read-only embed of a block or subtree) — user explicitly excluded
- Aliases (multi-label resolution to one entity) — user explicitly excluded; tags suffice
- Notion-style multi-feature workspace (kanban boards, databases, embedded widgets, page templates)
- General-purpose AI chat assistant — when AI is eventually added, scope is corpus-bound augmentation, not chat
- Cloud-based sync as the primary transport — Ditto P2P is the v1 transport identity

---

## Key Decisions

- **v1 is greenfield capture-only, not migration-gated.** v1 ships when new captures feel right; migration is v2+. The user already has Logseq + iCloud for existing notes; v1's job is to be a better daily-driver for new bullets and to prove mesh + speed on a fresh real corpus the user authored themselves.
- **No AI in v1.** Deferred to v2+ behind a trust gate. The user explicitly wants hands-on every note before AI is allowed to suggest or rewrite; the hackathon already proves Cactus on the demo path.
- **Outliner-first, not Notion-shaped.** Distraction-free bullets only, no widgets or databases. Notion's bell-and-whistle bloat was explicitly named as the anti-pattern; the product's identity is Workflowy UX with Logseq data, both bullet-shaped.
- **Mesh is the transport, not the differentiator.** Ditto P2P replaces iCloud as the sync layer, not as a marketed feature. Data ownership is the user's primary concern; P2P mesh is the cleanest expression of "no cloud holding my brain."
- **Mirrors are non-negotiable.** Without mirror semantics at Workflowy-grade UX, the product fails its switch-bar even for new notes. Mirrors are also load-bearing for the eventual migration of stuck Workflowy bullets.
- **Hackathon demo wraps the substrate, not the product identity.** Mesh Jeopardy is a one-off demo veneer; the product is the outliner. The brainstorm exposed that the seed's three multiplayer directions were all demo wrappers, not product directions; the doc keeps them visibly separated.

---

## Dependencies / Assumptions

- Cactus and qwen3-1.7 (or comparable small model) can generate clues from a small audience-captured corpus in under ~10 seconds per clue on phone hardware in active use. **This is an unmeasured assumption — no spike under `docs/spikes/` has yet measured Cactus decode speed: U2 measures embedding determinism, U3 measures merge-eval quality, U7 measures sync, U9 is rehearsal, and U10 is the Presenterm slide deck.** Planning must measure decode speed under realistic clue-generation load before the demo commits to live audience capture.
- Ditto BLE / local-wifi mesh can sustain replication across 10-30 phones in a room without dropping. The current build verifies 2-3 phone sync; demo-scale behavior is an unverified assumption that planning should measure before commit.
- Markdown-on-disk with embedded block IDs is portable enough that the user can move bullets to Logseq or another markdown outliner without losing identity. Exact block-ID embedding convention (Logseq `id::` property syntax, HTML comments, or frontmatter) is a planning decision; this assumption depends on convergence on a format that at least one other tool can read.
- The current `lib/models/study_note.dart` data model (stable UUID, body, tags, `acceptedBy` OR-set, clone semantics) is a near-substrate for the outliner. The gap is hierarchy (parent_id + position), mirror semantics, and outliner UI. Whether to extend `StudyNote` or replace it is a planning decision; this doc assumes meaningful reuse is possible.
- The hackathon audience is willing to open the app on their phones during a 60-90s demo. The R19 corpus floor (demoer's own bullets) is the explicit mitigation if this fails.

---

## Outstanding Questions

### Resolve Before Planning

- [Affects R10, R17, F3, F4][Security] **Corpus isolation between demo mesh and personal mesh** — the doc currently lets both modes share the same Ditto transport with no specified partition. Without a collection-level / namespace-level boundary, audience phones in demo mode could replicate the user's personal corpus, and the demo's untrusted writes could leak into the personal corpus. Decide on the isolation mechanism (separate Ditto collections per mode, demo-session-scoped namespace, kill personal mesh during demo) before any v1 architecture work.
- [Affects Problem Frame, Key Decisions][Strategic] **Adjacent products not surveyed** — Reflect, Tana, Capacities, RemNote, and Roam occupy adjacent UX-plus-data-ownership space with block-reference primitives. The build-vs-use justification was never tested. Resolve by surveying these tools before committing significant v1 build time; if any already meets the bar, switch the question from "build vs Logseq" to "build vs the actual incumbent."
- [Affects R18, Dependencies][Needs research] **Cactus decode-speed baseline** — no existing spike has measured Cactus clue-generation latency under realistic load (the doc previously misattributed this to the U10 Presenterm spike, which it isn't). The live-audience demo format depends on a budget that hasn't been bounded. Resolve by running an explicit decode-speed spike before the demo locks.

### Deferred to Planning

- [Affects R1, R13, R14][Technical] Block-ID embedding convention in markdown: Logseq `id::` property syntax vs HTML comments vs YAML-frontmatter. Choose for interop with Logseq specifically vs neutral portability across markdown outliners.
- [Affects R9][Technical] Engine architecture: Dart-only Flutter vs Flutter UI + Rust core for the corpus engine. The 10k+ bullet trajectory is the architectural anchor; measure first.
- [Affects R6, R7, R11][Technical] Mirror-merge conflict semantics: when two devices concurrently edit the source of a mirror, the CRDT merge must converge predictably. Ditto's underlying CRDT primitives shape what is feasible.
- [Affects R1-R8, R16-R20][Technical] Salvage vs rewrite of the current `lib/widgets/flashcards_tab.dart` + `lib/models/study_note.dart` layer for the outliner data model — specifically, whether to extend `StudyNote` with hierarchy + mirror semantics or replace it. Sequencing the hackathon demo build against the outliner v1 build depends on this choice.
- [Affects R17][Needs research] Ditto mesh scale at 10-30 phones in a single room: practical replication latency, failure modes, and BLE channel contention. Measure before committing to live-audience capture as the demo format.

### From 2026-05-21 doc review (deferred to planning)

The review surfaced concerns that did not block requirements scope but should be resolved as planning proceeds. Persona attribution in brackets.

**Product / strategy** [product-lens, adversarial]

- Side-by-side dogfood with Logseq risks indefinite stall: new captures get stranded outside the corpus they need to link into. Surface a "switch reflex" leading indicator (e.g., percent of week's captures landing here vs Logseq) as a v1 health metric.
- "Mesh is the transport, not the differentiator" tension: the demo stages mesh as the awe-moment, but the product treats it as plumbing. Either re-positioning or explicit acknowledgement that mesh is plural-purpose (plumbing + demo moment).
- "Notion as anti-pattern" overstates the user's actual statement ("too many bells and whistles"). Tighten the framing so it doesn't act as a veto on legitimate features later.
- Inversion risk: hackathon deadline can eat the product timeline. Name the explicit tiebreaker if both v1 dogfood and demo can't ship clean.
- Mirror-merge semantics in v1 implicitly commit to Workflowy-import shape in v2. Mirror conflict resolution chosen now will constrain migration design later.
- Competitive obsolescence: Logseq's ongoing DB rewrite could close the perf gap before v1 ships. Define a kill-switch criterion or a watch metric.
- v1 scope bypasses the actual lived evidence (collaborative conference notes; Workflowy mirror migration). Greenfield-only is a fast-ship choice that punts both pieces of concrete evidence.
- "No-syntax-leak mirrors at Workflowy-grade UX" asserts a UX bar Logseq has not met in years. Commit to a specific UX strategy (rendering, edit-mode, dual-shape) before treating this as solved.

**Feasibility** [feasibility, adversarial]

- 2-phone Ditto sync baseline is itself unrecorded (U7 results still `_todo_`). The 10-30-phone extrapolation has no measured floor.
- Markdown-on-disk persistence is fully greenfield in this codebase — `StudyNote` is Ditto-doc only, no filesystem persistence stratum exists. Planning must scope that as net-new, not as `StudyNote` extension.
- Flutter at 10k+ bullets on mobile is largely unprecedented — Capacities, Tana, Logseq all run on web stacks. The Dart-only path may not clear R9's trajectory bar; measure before locking architecture.
- "Markdown portability via block IDs" is asserted but Logseq's `id::` syntax is read correctly by approximately one tool. Pick a convention with eyes open; portability may be one-way in practice.

**Design / UX** [design-lens]

- Mirror command invocation on mobile (gesture, slash-command, long-press menu) is unspecified — planning must pick before mirror UX can be designed.
- Backlinks pane: trigger, location, dismissal all unspecified. Three independent UI decisions.
- Zoom-into-bullet breadcrumb and back-affordance unnamed. Workflowy and Logseq differ; pick one.
- Demo feedback states (mesh joined / Cactus generating / clue ready) need visual treatment sized for room-scale visibility.
- Audience onboarding flow for the demo (first-launch, permission prompts, "you're in the mesh" confirmation) is absent.
- Inline rendering of `#tag` and `[[Page]]` as chips vs raw syntax — not stated; "no syntax leak" only commits this for mirrors.
- Device-presence indicator (R12) needs a UI surface compatible with R3's distraction-free constraint.
- Empty-corpus first-launch state — what does a new user see before they have any bullets?
- Demoer's Jeopardy-mode UI — trigger, clue advance, audience-side state — needs a screen-level spec.
- Capture-during-talk in v1 is mobile-keyboard only (Willow voice is deferred); thumb-typing under demo time pressure is a real constraint.

**Security / privacy** [security-lens]

- Demo mesh has no admission control: anyone in BLE range can join, sniff, or inject bullets that flow to Cactus.
- Bullets persist on audience phones post-demo with no stated cleanup or notice. Audience members' implicit consent boundary is unspecified.
- No encryption / identity stated for bullets in transit on BLE / local wifi. Verify Ditto's default TLS/DTLS configuration applies.
- At-rest encryption and device-loss posture for the personal corpus (data labeled the user's "literal brain") is unmechanized — iOS Data Protection class, file encryption, export security.
- iCloud backup of markdown files: NSURLIsExcludedFromBackupKey decision needed, given the data-ownership posture explicitly rejects vendor exposure.
- Prompt-injection vector: mesh-received bullets feed Cactus (R18); a crafted bullet can manipulate clue generation. Becomes a larger risk when v2 AI augmentation reads the personal corpus.
- Multi-device personal sync has no pairing / auth ceremony — what makes a device "the user's own device"?

**Scope** [scope-guardian]

- The doc encodes two distinct products (outliner v1 + hackathon demo) with different timelines and actors in one requirements list. Consider splitting into two docs if planning sequencing gets tangled.
- Mirrors-in-v1 is the hardest UX *and* CRDT requirement simultaneously. The "switch-bar" justification cites Workflowy migration which is itself deferred — reconsider whether mirrors can ship with the migration milestone instead of v1.
- R10 names laptop and iPad in v1 mesh, but the success criterion only references mobile. Confirm whether v1 desktop client is in or out.
- Block-level backlinks (R5) is load-bearing for mirrors more than for standalone backlinks UX at v1 corpus size; if scoped as mirror-infrastructure rather than user-facing feature, the doc text should say so.

**Demo coherence** [adversarial]

- R19 fallback collapses the demo's differentiation: single-phone Cactus clue gen is achievable on Logseq + Ollama or any iOS shortcut. Plan for partial-engagement scenarios, not just zero-engagement.
- Mesh Jeopardy frame survived from the pre-reframe seed. Worth a sanity check: is a non-game demo (e.g., live two-phone conference-pair-sync) more honest about the actual product?
- Audience-willingness assumption is the demo — TestFlight / sideload friction would force the R19 fallback to be the expected path, not the exception. Resolve install/onboarding mechanism before committing to live-capture format.

### FYI observations (anchor 50, no decision required)

- Terminology: "UUID" / "block ID" / "stable block IDs" now normalized to "block ID" (R1, R5, R14) [coherence]. Applied in this review pass.
- No-AI-in-v1 may also mean no AI-relevant telemetry — if the writeup-thesis stages eventually need preference signals, v1 silently records-or-doesn't is a planning question worth flagging [product-lens].
- The four-way fusion premise (Workflowy × Logseq × Ditto × Cactus) is asserted as a positioning summary but the *combined* product feel hasn't been articulated beyond the sum of parts [product-lens].
- Voice capture deferral (Willow) leaves the demo's capture-during-talk surface dependent on thumbing; if voice slips earlier, it could land in the demo path itself [design-lens].
- Multi-device personal sync (R10) doesn't specify a pairing/auth ceremony; depending on Ditto's default identity model, this may be implicit but is worth confirming [security-lens].
- R12 device-visibility UI lacks a user-benefit framing in success criteria — useful but may be over-built for a two-device user [scope-guardian].
- Product roadmap (v1 → v2 → vN + writeup-thesis stages) is built on what the user described as "exploratory" hackathon premise — kill criterion for the underlying probe is unnamed [adversarial].
- "Mesh-as-transport-not-differentiator" + demo staging mesh as awe-moment is a low-severity framing tension worth resolving in marketing copy if it ever ships [adversarial].
