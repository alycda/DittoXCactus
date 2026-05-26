# Ditto × Cactus — Mesh RAG demo

**Status:** Stage 0 / 1 in flight — retrieval pipeline + determinism harness shipped, demo-day flow rehearsable.
**Originally framed:** weekend hackathon brainstorm (Pursuing framing **A — "Mesh RAG"** of the four candidates below; see [SEED.md](_docs/SEED.md) and the [implementation plan](_docs/plans/001-feat-mesh-rag-demo.md).)

## What this is

Two phones each hold a slice of a study-notes corpus. They meet over BLE/Wi-Fi
and the vector index merges as a CRDT, so a query on phone A draws on phone B's
notes after handshake — with WAN off. The Cactus on-device LLM does both the
embedding (`qwen3-0.6`) and the flashcard generation (`qwen3-1.7`); Ditto syncs
the notes + their embeddings as a grow-only union.

The blog-post-shaped artifact is the writeup: *"Your knowledge base wants to be
a CRDT."*

## Why this pair is interesting

- **Ditto** — peer-to-peer offline-first CRDT sync over BLE / LAN / mesh. Flutter SDK.
- **Cactus** — on-device AI runtime (LLM, embedding) with hybrid cloud fallback (disabled here; cloud is not in the trust boundary).
- Both are edge-native, both are privacy-forward. The interesting question isn't *whether* they compose — it's which compound claim the writeup argues.
- The thesis chosen: **vector indexes want to be CRDTs**. Embeddings are additive; relevance is a local function over a set. `topK(corpus_A ∪ corpus_B)` produces the same result regardless of which device runs it, because the union is associative and retrieval has no hidden state.

## How to run it

`.env` (gitignored) holds `DITTO_APP_ID` and `DITTO_LICENSE`. Then:

```sh
# List devices
flutter devices

# Boot one phone as 'a' and the other as 'b' — they have disjoint seed corpora.
just app-run-a <android-or-ios-device-id>
just app-run-b <other-device-id>

# Rehearsed Holdout-1 demo flow (DEMO_OVERLAY HUD + INITIAL_TOPIC pre-filled):
just app-run-a-demo <device-id>           # defaults to "Saturn"
just app-run-a-demo <device-id> "moons"   # or override

# Unit + widget tests for the main app
just app-test
# Static analysis
just app-analyze
# Both together
just ci
```

The cross-platform embedding-determinism gate (Holdout 2 / R2) lives in
its own package under `tools/determinism_harness/`:

```sh
just harness-test                                            # pure-Dart math
just harness-measure <device-id>                             # on-device measure
just harness-check <ios.json> <android.json>                 # cross-platform gate (U1)
just harness-check-baseline <baselines/latest/X.json> <X.json>  # regression (U13)
```

See [`tools/determinism_harness/README.md`](tools/determinism_harness/README.md) for
the determinism story; the locked baseline lives under
[`baselines/latest/`](tools/determinism_harness/baselines/latest/).

## Architecture in 30 seconds

**Boot** ([lib/main.dart](lib/main.dart) → `BootScreen._boot`):
Ditto initialize → `startSync` → SeedLoader parses
[`assets/seed_notes_<role>.json`](assets/) and upserts each note → CactusService
downloads + initializes both LMs → RetrievalService backfills any note that
doesn't already have an embedding.

**Retrieval pipeline** ([lib/services/retrieval_service.dart](lib/services/retrieval_service.dart)):

```
topK(query)
  └─ cosine ranking (Float32) over the materialized Ditto snapshot
     ├─ deterministic tie-break: (score desc, _id asc)
     └─ minScore filter (default 0.3) drops weak retrievals
  └─ filterByEntityMention(retrieved, topic)
     └─ substring scan of topic over note.topic / body / tags
        catches the "semantically adjacent but wrong entity" case
        (Jupiter notes scoring high on "Saturn", etc.)

generateFlashcards(topic):
  └─ retrieved.isEmpty? → skip LLM, emit empty cards (structural grounding gate)
  └─ effectiveN = min(n, retrieved.length) — scales request to retrieval reality
  └─ Cactus stream → parse → cleanCards pipeline:
       on-topic → reasoning-leak → answer-length → drop-uncited → dedupe → cap
  └─ Backfill SOURCE when retrieval is unambiguous (single note) or
     when card text mentions a retrieved note's topic (multi-retrieval).
```

The pipeline is six structural gates between retrieval and the rendered card.
Each gate was added in response to a specific on-device failure mode; see the
*Small-model quirks the pipeline absorbs* section below and the per-commit
history for the receipts.

## Small-model quirks the pipeline absorbs

The demo runs Qwen 2.5 1.7B for completion and `qwen3-0.6` for embedding —
both modest, both stretched at this task. The pipeline is layered the way it
is because each layer absorbs a specific quirk the model exhibits in practice.
None of these are bugs in the model; they're predictable consequences of how
a 1.7B-class generalist LLM was trained.

The longer catalogue (with example logs and source citations) lives in
[`_docs/notes/model-quirks.md`](_docs/notes/model-quirks.md). Headline summary:

1. **Bilingual chain-of-thought drift.** Qwen drifts into Mandarin tokens
   mid-`<think>` ("CO₂大气层"). Never reaches final Q/A output — the parser
   strips closed `<think>` blocks. **Benign cosmetic artifact**, useful as
   writeup evidence that the generalist's training distribution leaks
   through the seams.

2. **LaTeX `\boxed{}` drift.** Qwen's MATH-dataset training fires on
   "give me your final answer" cues. Mitigated by an explicit "no LaTeX"
   rule + a line-based parser that ignores math-display blocks.

3. **`<think>` blocks despite the prompt ban.** `/no_think` is Qwen3-only;
   our 2.5 always thinks. Parser strips closed blocks; unclosed prefixes
   anchor at the first `Q:` line; `cleanCards` drops reasoning-marker
   leaks downstream.

4. **Verbose answers exhaust the per-card token budget.** Model trained on
   detailed Q/A produces multi-clause answers; with `n=2` requested and a
   verbose first card, the second card sometimes truncates. Mitigation:
   tight `A: <under 20 words, one clause>` rule in the prompt + a 300-char
   length cap in `cleanCards` as a structural backstop.

5. **Off-topic content padding when retrieval is thin.** For `topic="moons"`
   with one Mars note retrieved, the model dutifully made cards about
   Olympus Mons and Valles Marineris too. Mitigation: `effectiveN = min(n,
   retrieved.length)` so the model isn't pressured to pad, plus
   `cleanCards`' on-topic substring filter as the structural drop.

6. **SOURCE omitted under tight budgets.** Model writes a clean `Q:` + `A:`
   then truncates before the `SOURCE:` line. Mitigation:
   `backfillCardSources` attributes uncited cards either unconditionally
   (single retrieval — unambiguous) or by content matching against
   retrieved note topics (multi-retrieval). Cards mentioning no retrieved
   entity stay uncited and drop downstream.

The bigger story this catalogue carries: **structural gates beat stream
heuristics.** When small-model output is wrong, fix the input to the model
(or filter at the parse boundary), not the output detector inside the
stream. The
[rolled-back-watchdog memory](file:///Users/alyssaevans/.claude/projects/-Users-alyssaevans-Experiments-DittoXCactus/memory/feedback_structural_gates.md)
captures the worked example.

## Cross-platform embedding determinism

The mesh-RAG thesis only works if both phones agree on what the embedding of
a given string IS. Otherwise `topK(corpus_A ∪ corpus_B)` differs by which
device ran it.

`tools/determinism_harness/` ships:

- A 20-query × 20-passage fixture across 5 topical clusters
([`fixtures/queries.json`](tools/determinism_harness/fixtures/queries.json)).
- A Flutter integration test (`integration_test/measure_test.dart`) that runs
  the fixture through Cactus on-device and writes a per-device JSON.
- A pure-Dart CLI ([`run.dart`](tools/determinism_harness/run.dart)) with
  `check`, `check-baseline`, and `--ci` modes for offline analysis.
- Locked baselines under
  [`baselines/latest/`](tools/determinism_harness/baselines/latest/) so any
  unintended model swap shows up as a CI failure (U13).

First measurement on the locked `qwen3-0.6` slug:

| Comparison | matched | rate | gate |
|---|---|---|---|
| Pixel A ↔ Pixel B | 20/20 | **1.0000** | PASS |
| iPhone ↔ Pixel | 17/20 | **0.8500** | FAIL — diagnostic band |

Same-hardware is bit-perfect; cross-platform sits in the plan's "kernel-pin
tightening" diagnostic band. See
[`baselines/2026-05-23/README.md`](tools/determinism_harness/baselines/2026-05-23/README.md)
for the full result and the three disagreeing queries (Q03, Q05, Q10 — two
within-top-k reorderings, one top-1 swap between semantic-twin passages).

## Knowledge graph — interactive dashboard

**[Live dashboard ↗ alycda.github.io/DittoXCactus](https://alycda.github.io/DittoXCactus/)**

A browsable graph of every file in the repo, grouped into 10 architectural
layers, with a 12-step guided tour from "The Thesis: Mesh RAG" through
"Build, CI, and Demo Day." 202 nodes, 246 edges. Useful for new readers who
want to orient before reading the plan, or for finding the file behind a
specific behavior ("where does the title-case query normalization live?").

Built with [Understand-Anything](https://github.com/Lum1104/Understand-Anything).
The committed graph lives at [`.understand-anything/knowledge-graph.json`](.understand-anything/knowledge-graph.json)
and is published to GitHub Pages by [`.github/workflows/pages.yml`](.github/workflows/pages.yml).

To rebuild after structural code changes:

```sh
# In Claude Code with the Understand-Anything plugin installed:
/understand
# Then commit the new .understand-anything/knowledge-graph.json — the
# Pages workflow redeploys automatically.
```

## Deeper reading

- [`_docs/IDEA-A.md`](_docs/IDEA-A.md) — the thesis essay ("Your knowledge base wants to be a CRDT").
- [`_docs/SEED.md`](_docs/SEED.md) — validation harness + holdouts R1–R11 + cut order.
- [`_docs/plans/001-feat-mesh-rag-demo.md`](_docs/plans/001-feat-mesh-rag-demo.md) — implementation plan with U-IDs for each implementation unit.
- [`_docs/notes/model-quirks.md`](_docs/notes/model-quirks.md) — full quirks catalogue (six on-device-observed Qwen 2.5 behaviors, with mitigations linked to source files).
- [`_docs/notes/thesis-framings.md`](_docs/notes/thesis-framings.md) — the writeup's four-thread arc (specialists → preference-aware merge → adversarial filtering → generational evolution).
- [`_docs/demo-script.md`](_docs/demo-script.md) — the rehearsed Holdout 1 three-beat sequence.
- [`_docs/research/`](_docs/research/) — six deep-research passes (3 web-research, 3 hosted) with a 281-source synthesis index.
- [`docs/c4/model.c4`](docs/c4/model.c4) — Likec4 architecture model (containers + components). `just c4-model` to serve the dashboard at `http://localhost:8000`.

---

## How we got here — original brainstorm (2026-05-23)

The four framings that were on the table during the weekend's planning loop.
Pursuing **A**; B/C/D kept for the brainstorm record. **C** is the
explicit fallback if A's Cactus-determinism prerequisite fails (which it
hasn't — see U1 result above).

### A. "Mesh RAG" — corpora that compound additively *(pursuing)*

Each device indexes some local material into a vector store kept inside
Ditto. Cactus does embedding and inference locally. When two devices meet
over BLE/LAN, their indexes merge — no central store, no upload. The query
you ask on phone A draws on phone B's material if B is nearby.

- **Thesis:** vector indexes want to be CRDTs (embeddings are additive;
  relevance is a local function over a set).
- **Demo:** two phones, no wifi. Each preloaded with different docs. Ask a
  question on one; the answer gets better the moment the second comes
  into range.
- **Hard part:** keeping the embedding model identical and stable across
  devices so vectors are comparable. Mechanically modest at weekend
  scale; conceptually rich.
- **Blog-post shape:** "Your knowledge base wants to be a CRDT."

### B. "LLM-mediated merge" — AI repairs what CRDTs can't reach

Ditto's CRDTs already merge structured fields correctly. The places they
can't help are the unstructured ones — free-text descriptions, lists of
ideas, plans. Cactus runs an on-device LLM that proposes a semantic merge
when two human edits collide on those fields, and explains the merge in
plain language.

- **Thesis:** AI is good at intent; CRDTs are good at structure. The fusion is bigger than either alone.
- **Demo:** two phones, both offline, both editing shared study notes. Reconnect. The LLM proposes the merged version with a one-line "I combined your additions" footer.
- **Blog-post shape:** "What AI is actually good for in collaborative editing."

### C. "Narrate the mesh" — smallest, sharpest post *(fallback)*

Don't use AI for the user feature. Use it to make the *sync itself*
legible. A local LLM watches the Ditto change stream and produces a
human-readable activity feed: "Maya marked the route as cleared," "two
devices in Block 3 went offline," instead of raw document diffs.

- **Thesis:** the most undersold use of on-device LLMs is interpreting structured local state for humans.
- **Blog-post shape:** "On-device LLMs are interfaces, not products."

### D. *Challenger:* "Model weights gossip" — federated learning over mesh

Each device collects examples. Cactus does on-device LoRA fine-tuning.
The LoRA deltas are tiny enough to gossip over BLE via Ditto. Phone A
trains, phone B inherits, the model improves additively as the mesh
grows.

- **Thesis:** model deltas are mesh-friendly payloads. If embeddings are CRDTs (A), so are LoRA tensors.
- **Hard part:** real risk this overflows the weekend. Not pursued.
- **Blog-post shape:** "Federated learning, without the federation."

### Comparison at decision time

| | A. Mesh RAG | B. LLM-mediated merge | C. Narrate the mesh | D. Weight gossip |
|---|---|---|---|---|
| Claim strength | High | High (contrarian) | Medium | Highest |
| Weekend feasibility | Medium | Medium | High | Low |
| Demo legibility | High | High (if scripted) | Very high | Medium |
| Novelty for a writeup | High | High | Medium | Very high |
| Risk of partial ship | Low | Medium | Very low | High |

**Why A:** the strongest, most quotable thesis ("Your knowledge base wants
to be a CRDT") and the cleanest demo construction — two phones, no wifi,
the answer gets better when B comes into range. Bigger swing than C with
a tractable hard part (cross-platform embedding stability) that the
determinism harness verifies before commit.
