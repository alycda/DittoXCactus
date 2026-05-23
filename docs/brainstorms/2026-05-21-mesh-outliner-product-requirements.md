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

- R1. Every bullet has a stable UUID assigned at creation, preserved across saves, sync, and round-trip through markdown on disk
- R2. Bullets support hierarchy via indent/outdent and zoom-into-bullet navigation
- R3. The default view is distraction-free bullets; no sidebar widgets, no kanban, no databases, no Notion-style block menu
- R4. Tag syntax (`#tag`) and page-link syntax (`[[Page]]`) create outgoing links from a bullet; a backlinks pane aggregates inbound references per page and per tag
- R5. Block-level backlinks: viewing any bullet shows every other bullet that references it by UUID

**Outliner mirrors (v1)**

- R6. The user can mirror a bullet to another location; the mirror and the source share the same UUID and are logically one bullet
- R7. Editing a bullet in any of its locations propagates the edit to every location; the rendered view shows no block-reference syntax
- R8. The markdown-on-disk format records bullet identity such that mirrors round-trip through plain markdown without losing their relationship

**Outliner performance (v1)**

- R9. The app sustains snappy interaction (capture, navigation, search, zoom) at 10k+ bullets on mobile hardware

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
- Specialist small models (writeup-thesis Stage 1): replacing the generalist on-device LLM with domain-tuned tiny models (note-curator, summarizer, retriever)
- Preference-aware merge (writeup-thesis Stage 2): when two users' outliners mesh, the merge respects each user's preferences rather than performing a flat union
- Adversarial filtering (writeup-thesis Stage 3): promotion of merged content into canonical form needs reputation, consensus, or provenance — not flat union
- Generational evolution (writeup-thesis Stage 4): temporal weighting or branch-on-divergence semantics for notes that drift over time
- App naming — deferred to a separate pass closer to v1 ship; this doc uses "the outliner" as the working reference

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

- Cactus and qwen3-1.7 (or comparable small model) can generate clues from a small audience-captured corpus in under ~10 seconds per clue on phone hardware in active use. Decode-speed measurement under live audience load has not yet been performed; the u10 spike measured single-phone steady-state.
- Ditto BLE / local-wifi mesh can sustain replication across 10-30 phones in a room without dropping. The current build verifies 2-3 phone sync; demo-scale behavior is an unverified assumption that planning should measure before commit.
- Markdown-on-disk with embedded block IDs is portable enough that the user can move bullets to Logseq or another markdown outliner without losing identity. Exact block-ID embedding convention (Logseq `id::` property syntax, HTML comments, or frontmatter) is a planning decision; this assumption depends on convergence on a format that at least one other tool can read.
- The current `lib/models/study_note.dart` data model (stable UUID, body, tags, `acceptedBy` OR-set, clone semantics) is a near-substrate for the outliner. The gap is hierarchy (parent_id + position), mirror semantics, and outliner UI. Whether to extend `StudyNote` or replace it is a planning decision; this doc assumes meaningful reuse is possible.
- The hackathon audience is willing to open the app on their phones during a 60-90s demo. The R19 corpus floor (demoer's own bullets) is the explicit mitigation if this fails.

---

## Outstanding Questions

### Deferred to Planning

- [Affects R1, R13, R14][Technical] Block-UUID embedding convention in markdown: Logseq `id::` property syntax vs HTML comments vs YAML-frontmatter. Choose for interop with Logseq specifically vs neutral portability across markdown outliners.
- [Affects R9][Technical] Engine architecture: Dart-only Flutter vs Flutter UI + Rust core for the corpus engine. The 10k+ bullet perf bar is the gate; measure before committing.
- [Affects R6, R7, R11][Technical] Mirror-merge conflict semantics: when two devices concurrently edit the source of a mirror, the CRDT merge must converge predictably. Ditto's underlying CRDT primitives shape what is feasible.
- [Affects R1-R8, R16-R20][Technical] Salvage vs rewrite of the current `lib/widgets/flashcards_tab.dart` + `lib/models/study_note.dart` layer for the outliner data model — specifically, whether to extend `StudyNote` with hierarchy + mirror semantics or replace it. Sequencing the hackathon demo build against the outliner v1 build depends on this choice.
- [Affects R17][Needs research] Ditto mesh scale at 10-30 phones in a single room: practical replication latency, failure modes, and BLE channel contention. Measure before committing to live-audience capture as the demo format.
- [Affects R18][Needs research] Cactus decode-speed budget for clue generation on qwen3-1.7 under live load: per-clue latency target and how to keep the demo's perceived pace if a clue takes longer than expected.
