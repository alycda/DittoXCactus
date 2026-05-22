# SPRINT-0001 — CLAUDE's critique of the CODEX and GEMINI drafts

Authored: 2026-05-21. Reviewing `SPRINT-0001-CODEX.md` and `SPRINT-0001-GEMINI.md` against my own `SPRINT-0001-CLAUDE.md`.

I am the author of CLAUDE; I have biases in its favor. I tried to read both sibling drafts charitably and look for places where they are simply correct and I am wrong.

---

## A. CODEX critique

### What CODEX does better than my draft

- **Deterministic tuple IDs derived from stable content fields** (CODEX, *Repo And App Foundation*: "Add deterministic tuple IDs derived from stable content fields so repeated sync cannot create duplicate logical notes"). I conflated "idempotent first-run seeding" with "stable IDs" and did not call out the ID-derivation rule. This is directly load-bearing for H3 (sync idempotence) and I missed it.
- **Deterministic tie-breaking on top-k score ties** (CODEX, *Sync creates duplicates...*: "Sort top-k ties deterministically by score, then tuple ID"). My draft will silently re-order top-k across re-meets if two embeddings score identically, which fails H3 noisily even when nothing is actually duplicated. CODEX is right; I missed this entirely.
- **Pinning the prompt template *before* the Gate B corpus judgment** (CODEX, *Gate B*: "Pin the first Cactus small-LLM candidate and prompt template before judging corpus quality"). My §6.1 Spike B does not separate prompt-variance from corpus-variance — if the recipe merge is bad, I will not know whether the prompt or the corpus is responsible. CODEX's ordering is more honest.
- **Adversarial-but-benign fixture diversity for Gate B** (CODEX, *Gate B*: "missing ingredient quantities, conflicting optional ingredients, substitutions, duplicate steps, and preference-sensitive ingredients such as avocado"). My "5 dishes × 3 variants" is a quantity statement; CODEX specifies the *failure-mode dimensions* the eval needs to cover. The CODEX rubric will catch failure classes mine will not.
- **Explicit "8 of 10" pass threshold for Gate B** (CODEX, *Gate B*: "Pass recipes only if at least 8 of 10 scripted merge cases are coherent..."). My Spike B has a rubric and a pass/fail column but no numeric bar; under time pressure that becomes "good enough", which is exactly the failure mode we are trying to avoid.
- **Gate B runs on the slowest target device** (CODEX, *Gate B*: "Run the recipe eval on the slowest target device, not only on the faster phone"). I push slowest-device measurement to H5 cold-load only. CODEX correctly notes that *merge quality* can degrade on slower-device quantization paths too, not just latency.
- **Paranoid offline check** (CODEX, *Cactus Integration*: "Keep all inference local and verify that no request path can call a server"). My H7 trusts airplane mode to enforce offline; CODEX's "no path can call a server" is an inspectable invariant rather than a property of the test environment.
- **Honest-failure rule** (CODEX, *Gate A*: "If all Cactus embedding candidates miss cosine >= 0.999, document the failure and switch the sprint to a non-claiming fallback that does not pretend cross-platform embedding parity passed"). My draft has a "≥ 0.99 fallback" note in R1 but does not commit to *not claiming parity* in the deck if we miss the bar. CODEX is more disciplined here.
- **Demo-ergonomic affordances:** "one-tap reset for demo data" and "one-tap seed action" (CODEX, *Demo UI And Offline Moment*). I rely on cold launch resetting nothing — which means on demo day, a flaky take leaves dirty state and I have no fast recovery path.
- **Qwen3-Embedding-0.6B as first candidate.** Both CODEX and GEMINI name this model; my draft names EmbeddingGemma 300M first. I am not confident EmbeddingGemma 300M is actually packaged by Cactus for both targets, and the open question in my §8 admits as much. CODEX's choice has fewer integration unknowns and should at minimum be considered an alternate first try, not a fallback.

### What CODEX does worse than my draft

- **No hour-level sequencing.** CODEX's §Sequencing is four bullets ("Day 0", "Day 1 morning", "Day 1 afternoon", "Day 2 morning", "Day 2 afternoon"). At a 48-hour sprint cadence with two empirical gates, parallelism inside each phase is most of the schedule's value. My §5 ASCII timeline and CODEX's prose sequencing are not equivalent — mine is more enforceable.
- **No B-roll backup or second hardware pair.** CODEX mentions "Keep a backup hardware pair or backup recorded take available" once as a bullet inside *Demo UI And Offline Moment*, but does not commit a B-roll file or a second-pair build to the repo. My §6.8 makes both into concrete deliverables.
- **No Presenterm PDF export deliverable.** CODEX has a deck task ("Create a Presenterm deck in the repo for the Stage 0 demo") but no PDF artifact gate, no commit path, no "exports to PDF" acceptance criterion.
- **No explicit cold-load remediation playbook.** CODEX has "Downgrade model size or switch corpus if the selected LLM cannot answer within the demo budget" — but my §6.5 lists four concrete remediations (shrink LLM to 1B, mmap weight load verification, splash pre-warm, max-tokens reduction). When H5 is failing at 22:00 Saturday this matters.
- **No embedding-storage-shape decision.** CODEX says "Keep embedding vectors stored in Ditto-owned documents for Stage 0 so the vector index itself is the synced CRDT state." That is a *consequence*, not a *decision* — there is no analysis of inline float32 vs sidecar blob, no per-doc size bound check, no escape hatch. My §6.2 *Data model & corpus* commits to inline float32 with a back-of-envelope size argument; CODEX leaves the implementer to discover it.
- **No mention of Ditto trial/license terms for public repo redistribution.** A hackathon repo we cannot legally publish is a sprint-critical blocker. My §6.0 task and R6 risk catch this; CODEX is silent.
- **No mention of the Cactus-owns-persistence integration risk.** Cactus ships `cactus_rag_query` and clearly wants to own RAG. My R8 explicitly forbids that path; CODEX has no equivalent warning, which means an executor reading the plan cold could waste hours integrating against the wrong Cactus surface.
- **No RN-vs-native bindings decision.** Cactus has both native (Swift/Kotlin) and React Native bindings; their version-skew is a real source of parity bugs. My R9 names the choice; CODEX is silent.
- **No iOS background-BLE caveat.** CODEX's BLE risk section talks about flakiness on camera but does not address the foregrounded-only constraint for iOS. My R5 catches it; CODEX does not.
- **The acceptance-criteria H5 wording weakens the test.** CODEX, *Acceptance Criteria*: "Holdout 5 passes with cold-load to first answer under roughly 10 seconds on the slowest target device, **or the miss is documented with an explicit mitigation**." That second clause is a back-door pass. My §6.5 *H5 measurement* fails closed.

### Tasks missing from CODEX

- Mermaid architecture diagram slide.
- Cactus version-pin in iOS/Android dependency manifests (named as a concrete `Package.swift` / `build.gradle.kts` edit).
- Stopwatch / slide-trim rehearsal task.
- Ditto trial-terms legal resolution.
- L2-normalize-at-insertion convention (CODEX has "Normalize embedding vectors consistently before similarity scoring or document why Cactus outputs are already normalized" — that is a *check*, not a *convention*, so two implementers could diverge).
- Latency-floor-argument deck slide (200ms RTT physical floor vs <100ms on-device).
- Future-work landing line ("family recipes through generations") — CODEX has the four-thread bullet but not the kicker.

### Risks underweighted in CODEX

- **R6 (license) entirely absent.**
- **R8 (Cactus persistence conflict) entirely absent.**
- **R9 (RN binding drift) entirely absent.**
- **R10 (demo legibility from across the hall) entirely absent.** CODEX has "Add a device label control or build-time label so camera viewers can tell iOS and Android apart" inside *Demo UI* — that is one piece of legibility but not the whole problem (tuple-card typography, mesh-state badge, "from other device" counter).

### Sequencing CODEX gets wrong

- **No mid-sprint dry-run on Saturday night.** CODEX's Sunday morning is "harden the holdout paths"; mine has the H3/H4/H7 dry-run at 21:00–22:00 Saturday. CODEX's flow has no chance to discover sync-wiring bugs while there is still build time to fix them.
- **Holdout-checklist re-run cadence.** CODEX, *Validation Harness*: "Run the full holdout checklist after every major integration change on Day 2." Re-running the *full* checklist after every change on a 48-hour clock is unrealistic and will be skipped. My §6.5 names the *specific* holdouts to re-run at the dry-run and at the morning pass; that is what will actually happen.

---

## B. GEMINI critique

### What GEMINI does better than my draft

- **Names FP16 vs INT8 quantization drift explicitly** (GEMINI, *Risks*: "Quantization Drift: FP16 vs INT8 might break the 0.999 cosine gate. Mitigation: Pin exact model versions and quantization methods across both runtimes"). My R1 talks about backend pinning (CPU/Vulkan vs ANE/Hexagon) but does not name the quantization-format axis. A small-LLM running Q4_K_M on one phone and Q4_0 on the other will silently break parity; GEMINI flags the dimension.
- **Concise, scannable structure.** GEMINI's eight tasks fit on a screen. For a hackathon where one person is the executor, that is genuine value — the executor will not re-read a 250-line plan every hour. My draft is more complete but harder to use as a *day-of* checklist.
- **Calls out the iOS↔Android BLE pairing pain explicitly** (GEMINI, *Risks*: "Mixed iOS/Android BLE pairing is notoriously hard"). My R3 says BLE flakes; GEMINI's framing makes the *cross-platform* aspect the specific risk, which is more useful guidance — same-platform BLE generally works.
- **Explicit RAG prompt template shape** (GEMINI, *Task 4*: `Context: {top_k_texts} \n Question: {user_query} \n Answer:`). My §6.2 *Generation* describes the prompt in prose; GEMINI gives a concrete starting string. For a sprint, having something to type and modify is faster than having a paragraph of requirements.
- **Picks Qwen3-Embedding-0.6B as first candidate** — same point as in the CODEX section. Two-out-of-three drafts converging on this model is signal I should weight against my EmbeddingGemma-first choice.
- **"Mesh State visualization (Discovery indicator, Peer count)" as a single named UI task.** My §6.3 buries this in two separate bullets ("mesh-state indicator UI" and "Tuples seen from other device counter"). GEMINI's version is one task, easier to test against.

### What GEMINI does worse than my draft

- **Drops Holdout 6 entirely from the acceptance criteria.** GEMINI's *Success Metric* line in the header says "Holdouts 1–5 + 7" — Holdout 6 (audience-survivable Stage 1) is silently omitted. The acceptance-criteria list at the bottom also lists Scenarios 1, 2, 3, 4, 5, 7 — no 6. That is the largest single error in the GEMINI draft: it cuts the only holdout that tests whether the LLM half of the demo actually works in front of an audience.
- **Determinism fixture set is half the size.** GEMINI: "10 standard recipe strings." CODEX and mine: 20. With 10 fixtures and a 0.999 threshold, one bad fixture is a 10% failure rate and the noise floor swallows real signal.
- **Gate B is one prompt and one judgment call.** GEMINI, *Task 2*: "Prompt the Cactus small LLM (Qwen-1.5B/3B) with two slightly different versions of a recipe (e.g., one with avocado, one without). Evaluate the LLM's ability to normalize and synthesize a single coherent recipe." That is *one* fixture, no rubric, no fallback-model trial, no scoring discipline. A single-fixture eval will mislead — recipe merge quality varies a lot across dish complexity.
- **No fallback embedding model is named.** GEMINI's Task 1 gate says "If failed, investigate quantization parity or switch model" — does not say *which* model. CODEX and mine both name fallbacks (Nomic, all-MiniLM).
- **No deterministic-ID rule.** Same H3 risk as CODEX flagged correctly and I missed — GEMINI also misses it. With first-run seeding fired twice across an uninstall/reinstall, GEMINI's plan duplicates tuples.
- **No L2-normalization convention.** GEMINI's Task 4 says "Implement flat-array cosine similarity search" without committing to whether vectors are normalized at insertion or at query time. iOS and Android can diverge here and the bug looks like a parity bug.
- **No B-roll, no second hardware pair, no single-take H1 capture deliverable.** GEMINI's Task 7 includes "Record the 'Moment of Magic' dry run (Holdout 1)" — a *dry run* recording, not a single-take final. The final on-camera deliverable is unspecified.
- **No PDF export gate for the deck.**
- **Mobile UI is on Day 2 morning** (GEMINI, *Phase 3: Mobile App & Sync Integration (Day 2 Morning)*) — see sequencing section below.
- **No Cactus-owns-persistence warning, no RN-vs-native binding decision, no Ditto-license task, no iOS background-BLE caveat.** Same gaps as CODEX; GEMINI is shorter so the omissions are more glaring.
- **No future-work four-thread landing.** GEMINI says "create a deck" but does not commit the specialists / preference-aware merge / adversarial filtering / generational evolution arc as deck content. That arc is the *reason* the writeup is interesting; losing it loses the punchline.
- **No cold-load remediation playbook.** Task 7 names the H5 measurement but no plan for what to do when it fails.

### Tasks missing from GEMINI

- Holdout 6 (audience-survival rehearsal) as a first-class task.
- Deterministic tuple IDs.
- L2-normalization convention.
- Cactus and Ditto SDK version pins.
- Ditto license resolution.
- B-roll recording.
- Second hardware pair on standby.
- Single-take H1 final capture as a committed file.
- Presenterm PDF export.
- Mermaid architecture diagram.
- Latency-floor argument slide.
- Future-work four-thread arc as deck content.
- Stopwatch rehearsal / slide-trimming.

### Risks underweighted in GEMINI

- **Audience-query failure (H6) — not present at all.** GEMINI's risk table covers BLE, model size/latency, and quantization drift. It does not cover "Stage 1 LLM answer is not legible to a non-technical audience" — and worse, the corresponding holdout is removed from the acceptance criteria. This is the single biggest risk failure in the draft.
- **License / repo-publish risk: absent.**
- **Cactus persistence conflict: absent.**
- **Demo legibility from across the hall: absent.**
- **iOS background-BLE foregrounded-only constraint: absent.**

### Sequencing GEMINI gets wrong

- **Mobile UI on Day 2 morning.** GEMINI's *Phase 3* (UI + E2E sync verification) is "Day 2 Morning". UI is the *test instrument* for every other holdout — every dry-run before that point is on a CLI or a partial app. Building UI on Day 2 morning means the first time the demo affordances (peer-state indicator, top-k cards, answer panel) are exercised together is ~24 hours before demo. My §6.3–§6.4 puts UI on Saturday afternoon/evening so Saturday-night dry-runs use the actual demo surface.
- **Task 6 (E2E sync verification) and Task 7 (Holdout validation) are sequenced after UI is built.** That ordering is correct, but it leaves no time between them and the deck (Task 8) on Day 2 afternoon — if Task 7's holdouts surface a sync bug, there is no slack. My draft buys back slack by dry-running H3/H4/H7 on Saturday night.
- **"Task 3 can run in parallel with Task 5 if mocked"** (GEMINI, *Sequencing & Dependencies*). Mocking Ditto and then un-mocking it is a 1-hour task that becomes a 6-hour task in practice. For a 48-hour sprint with one or two implementers I would not parallelize this way; I would build Ditto integration first and use the real subscription stream from the start. The mocking suggestion will burn time.

---

## C. If I were merging

**From CODEX, keep:**
- Deterministic tuple IDs derived from stable content fields (replace my "idempotent first-run seeding" wording).
- Top-k tie-breaking rule (score then tuple ID) — fold into §6.2 *Retrieval*.
- Pin prompt template before judging Gate B corpus quality.
- Gate B adversarial-fixture diversity (missing quantities, conflicting optionals, substitutions, duplicate steps, preference-sensitive ingredients).
- Explicit "8 of 10" Gate B pass threshold.
- "No request path can call a server" as an inspectable H7 invariant alongside the airplane-mode test.
- "Document the failure and switch to a non-claiming fallback" if Gate A misses — strengthen R1.
- One-tap reset for demo data + one-tap seed for demo-day recovery.
- Run Gate B on the slowest target device, not just the faster phone.
- Qwen3-Embedding-0.6B as first embedding candidate (demote EmbeddingGemma 300M to a "if Cactus exposes it" alternate).

**From GEMINI, keep:**
- Explicit quantization-format pin (Q4_K_M vs Q4_0, etc.) added to R1 alongside backend pinning.
- "Mixed iOS↔Android BLE pairing" framing for R3 (the *cross-platform* aspect is the risk).
- Mesh-state visualization as a single named UI task rather than two separate bullets.
- Concrete RAG prompt template string in §6.2 *Generation* as the starting point.

**Drop / do not adopt:**
- GEMINI's removal of Holdout 6 — keep H6 as a first-class acceptance criterion, with the audience-survival rehearsal task intact.
- GEMINI's Day-2-morning UI sequencing — keep UI on Saturday so Saturday-night dry-runs use real affordances.
- CODEX's "or the miss is documented" back-door pass on H5 — keep the hard 10s bar; document mitigations as a *remediation* path, not a *pass* path.
- CODEX's "re-run the full holdout checklist after every major integration change" — replace with the targeted Saturday-night and Sunday-morning passes from my §6.5.

**Net effect on my draft:** ~12 specific edits to §2 (deterministic IDs, tie-breaking, quantization pin), §6.1 (Gate B fixture diversity, prompt-pinning order, slowest-device, 8/10 threshold, Qwen3-Embedding-0.6B first), §6.2 (concrete prompt template string, L2-norm convention), §6.3 (mesh-state visualization as one task), §6.8 (one-tap reset, one-tap seed), §7 (R1 quantization sub-bullet, R3 cross-platform framing), and §2 (server-path-invariant clause on H7). Sequencing stays mine; deliverables stay mine; H6 stays load-bearing.
