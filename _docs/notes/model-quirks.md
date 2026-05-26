# Qwen 2.5 1.7B model quirks observed on-device

A running catalogue of small-model behaviors this demo's pipeline absorbs (or
deliberately doesn't). Useful for anyone who clones this repo and wonders why
the parser / `cleanCards` pipeline is so layered. None of these are bugs in
the model — they're predictable consequences of how a 1.7B-class generalist
LLM was trained.

For the broader thesis arc this connects to, see [memory entry
`project_writeup_thesis_arc`](#) — the *specialists vs generalists* thread
in the planned writeup uses these quirks as concrete evidence.

---

## Bilingual chain-of-thought drift (Chinese mid-`<think>`)

**What you'll see in logs:**

```
[generateFlashcards] --- raw stream begin ---
  | <think>
  | ...
  | The second note talks about Venus's thick CO₂大气层 causing extreme...
  | </think>
  |
  | Q: What makes Venus's atmospheric conditions so extreme?
  | A: ...
  | SOURCE: [62ba146b-...]
```

That `大气层` is Mandarin for "atmosphere" (literally *big air layer*). Qwen
2.5 is heavily bilingual — trained on a Chinese-and-English corpus with a
shared embedding space. The model's chain-of-thought training data is itself
bilingual, so under `<think>` conditions the model can drift into Chinese
for high-frequency concepts. It's most likely on words where Chinese has a
shorter, more token-efficient form than English ("大气层" is one token; "thick
atmospheric layer" is several).

**Where it appears:** only inside `<think>` blocks. The final Q/A/SOURCE
output is consistently English. This matches Qwen's training distribution —
final-answer data is more English-monolingual, reasoning data is more
bilingual.

**Why it's benign:** [`FlashcardGenPrompt.parse`](../lib/prompts/flashcard_gen.dart)
strips closed `<think>...</think>` blocks before commit-extraction, so the
Chinese never reaches the rendered card. Verified on the 2026-05-25
"atmosphere" dry-run: model wrote `CO₂大气层` inside `<think>`, then closed
the block, then wrote the English card.

**Suppression attempt not worth the cost.** An "English only" rule in the
prompt mostly works but Qwen ignores it intermittently (same way it ignores
"no `<think>` blocks"). Each rule we add lengthens the prompt and eats
context-window budget. Since the drift is invisible to users, leave it.

---

## LaTeX `\boxed{}` drift on structured-output prompts

**What you'll see:** the model wraps its final answer in `\boxed{\begin{aligned}
... \end{aligned}}` instead of plain `Q: / A: / SOURCE:` lines.

**Why:** Qwen 2.5 was trained heavily on the MATH dataset and similar
math-competition corpora where `\boxed{...}` is the canonical "final answer"
delimiter. When the model interprets a structured-output prompt as "give me
your final answer", it has a math-mode habit of reaching for `\boxed`.

**Mitigation, layered:**

1. **Stop sequences at the model layer (2026-05-26).** Cactus's
   `CompletionParams.stopSequences` halts inference the moment `\boxed`,
   `\begin{aligned}`, or `\text{` enters the stream. The structural
   backstop the prompt rule couldn't be — see
   [`lib/services/cactus_service.dart`](../../lib/services/cactus_service.dart)
   `_kDefaultStopSequences`. Pinned by `feedback_structural_gates`: on
   small-model paths, gate at the model layer, not at the parser.
2. Explicit rule in the system prompt: *"No LaTeX (no `\boxed`, no
   `\begin{aligned}`, no math-display blocks)."* Still useful as a
   first-line nudge; ignored often enough that #1 was needed.
3. The parser is line-based and looks for `Q:` / `A:` / `SOURCE:` labels —
   any LaTeX content that survives the stop sequence and isn't shaped
   that way lands as no-op noise.
4. `cleanCards` drops the artifact card via cite-required or
   reasoning-leak filters if any LaTeX-shaped card survives parse.

**Observed on 2026-05-26 moons-query dry-run:** Phone A querying
"moons" against the merged corpus produced clean Q:/A:/SOURCE: cards
in the first half of the stream, then drifted into:
- `**Final Answer**\nIn boxed format:\n\\boxed{Titan}, \\boxed{Geysers}, \\boxed{Rhea}`
- followed by `\box{}` (sic, missing the `d`) and `$\boxed{\text{Titan}}$`
The first half's cards were structurally fine but lost downstream
because the A field gobbled the LaTeX trail via the parser's
multi-line continuation. Stop sequence + this writeup landed the same
day; future runs should halt before the LaTeX section opens.

---

## `<think>` blocks despite the prompt ban

**What you'll see:** every generation starts with a `<think>...</think>`
block of model reasoning, even though the prompt explicitly says *"No `<think>`
blocks. No chain-of-thought."*

**Why:** Qwen 2.5 was instruction-tuned with `<think>` as a built-in token
behavior. Suppressing it requires `/no_think`, which is **Qwen3-only** — the
model we use can't disable it.

**Mitigation:**

- The parser strips closed `<think>...</think>` blocks (handles the common case).
- An unclosed `<think>` prefix is treated as preamble and ignored; parsing
  anchors at the first `Q:` line.
- If the model never closes `<think>` and writes prose, `cleanCards`
  drops the offending cards via reasoning-marker detection
  (`answerLooksLikeReasoning`).

This is the **single largest source** of parsing complexity in this repo.
A `/no_think`-capable model would let us delete most of the parser's
tolerance code.

---

## Verbose answers exhaust the per-card token budget

**What you'll see:** for `n=2` requested cards, only 1 card lands because
the model wrote a 50-word answer for the first card and ran out of
`maxTokens` before the second.

**Why:** Qwen was trained on detailed Q/A data. Asked for a definition,
it gives one with caveats, comparisons, units, and analogies. The
"`A: <a short answer, one sentence — under 20 words>`" rule reduces this
but doesn't eliminate it.

**Two experiments tested on the 2026-05-25 "atmosphere" dry-run:**

| Approach | Trade-off |
|---|---|
| Tighter prompt: A under 20 words, "one clause, no semicolons, no 'which'" | Choppier answers; more cards fit; model may ignore the rule on harder topics |
| Per-card budget 160 → 220 tokens | Verbose-but-correct answers survive; ~37% more wall-clock per generation |

The current `_kMaxTokensPerCard` constant in
[`lib/services/retrieval_service.dart`](../lib/services/retrieval_service.dart)
reflects whichever experiment won. The commit message there documents
why.

---

## Off-topic content padding when retrieval is thin

**What you'll see:** topic="moons", 1 retrieved Mars note containing
moons-and-other-Mars-facts → model produces 3-4 cards, only 1 actually
about moons (others about Olympus Mons, day-length, etc.).

**Why:** the model dutifully extracts every fact from the retrieved note
even if most aren't on-topic. It's trained on "summarize this passage",
not "produce only-on-topic flashcards from this passage".

**Mitigation:**

- `effectiveN = min(n, retrieved.length)` — never ask for more cards than
  retrieved notes, so the model doesn't feel pressured to pad.
- `cleanCards`' on-topic filter (Q or A must mention the topic substring)
  drops off-topic cards structurally.

See [`feedback_structural_gates`](../.claude/projects/-Users-alyssaevans-Experiments-DittoXCactus/memory/feedback_structural_gates.md)
in user-memory for the broader rule this expresses.

---

## SOURCE omitted under tight budgets

**What you'll see:** model writes a clean Q + A but stream ends before
`SOURCE:` is emitted. Parser yields the card with `sourceNoteIds: []`.
Without intervention, `cleanCards`' cite-required filter drops it.

**Why:** the model treats SOURCE as the least-important line and runs
out of budget for it. Especially common when retrieval is thin and the
model spent its think-budget reasoning before writing cards.

**Mitigation:**
[`RetrievalService.backfillCardSources`](../lib/services/retrieval_service.dart)
attributes uncited cards either unconditionally (single retrieval — only
one possible source) or by content matching (multi-retrieval — match each
card's Q+A against retrieved note `topic` substrings). Cards mentioning no
retrieved entity stay uncited and drop downstream.

---

## Format-collapse to "summary article" at n ≥ 3 with multiple retrievals

**What you'll see in logs:**

```
[generateFlashcards] topic="moons" k=5 n=3 effectiveN=3 retrieved=3 maxTokens=1172
[generateFlashcards] --- raw stream begin ---
  | <think>
  | Okay, let me try to figure out how to approach this. The user wants
  | exactly three flashcards about moons, each following the Q:A:S format...
  | [~2500 tokens of reasoning across multiple candidate breakdowns]
  | </think>
  | </system>
  |
  | ### Planet - Moon Relationship Summary
  | #### **1. Planetary Moons: Pluto's Largest Moon – Charon**
  | - **Moon Name**: *Charon* (the largest moon of Pluto)
  | - **Size Relative to Earth**: 0.6% of Earth's diameter
  | - **Distance from Sun**: Approximately 597 million kilometers
  | ...
[generateFlashcards] --- raw stream end (4550 chars) ---
[generateFlashcards] parsed 0 card(s)
```

The model emitted 4,550 characters of markdown-headered prose — `###`
section titles, `####` subsections, bulleted facts, and a phantom
`</system>` tag — instead of the prompted Q:/A:/SOURCE: tuples. The
parser correctly returned 0 cards.

**Pattern across observed generations (2026-05-25):**

| Topic | retrieved | effectiveN | maxTokens | Cards parsed |
|-------|-----------|------------|-----------|--------------|
| Saturn | 1 | 1 | 732 | 1 ✓ |
| moons | 3 | 3 | 1172 | 0 ✗ |

The format holds at `effectiveN = 1` and breaks at `effectiveN = 3` with
multiple retrievals. Three correlated changes happen at once: more
retrieved notes in the prompt, more cards requested, larger token budget.
The `<think>` block grows proportionally to digest the extra context,
and once the model exits `<think>` it picks a more familiar generation
shape — "structured summary article" — over the few-shot Q:/A:/SOURCE:
anchor.

**Why:** Qwen 2.5 was instruction-tuned on lots of "summarize/synthesize
across multiple sources" data, and that gradient pulls hard once N
sources are in scope. The few-shot Q:/A:/SOURCE: example in the prompt
demonstrates the format with **one** card; the model interprets
"output three cards" + "three retrieved sources" as a different task
than the example shows, and reaches for the closest matching shape from
its training distribution. The phantom `</system>` confirms this — the
model is rendering structure tokens it saw in mixed-shape training data,
not following the prompt's structural constraint.

**Companion artifact in the same generation:**

```
[c4539818-8885-5305-97bb-04827８７１aa３２]
```

That source citation contains **fullwidth Chinese digits** (`８７１` and
`３２`) interleaved with the real UUID's hex chars. The Chinese-CoT
drift (see *Bilingual chain-of-thought drift* above) didn't stay inside
`<think>` this time — it contaminated a *structural identifier*. Any
downstream content-matching to that source ID would miss because the
bytes don't match the real UUID. New surface area for the bilingual-drift
quirk: not just prose, but identifiers.

**Mitigations not yet taken (the demo accepts this for now):**

- Tighter prompt anchor: more Q:/A:/SOURCE: few-shot examples covering
  the multi-source case (currently one example covers all N). Costs
  prompt-budget tokens.
- Stricter `effectiveN` cap: clamp at 2 even when retrieval > 2. Costs
  card coverage when the corpus has more on-topic content.
- Server-side enforcement: structured grammar / constrained decoding
  (e.g., GBNF) to force Q:/A:/SOURCE: emission. Cactus 1.3.0 doesn't
  expose this; would need an SDK upgrade or a parser rewrite.

For the writeup's specialists thread: a specialist flashcard-generation
model would have no "summary article" mode in its training distribution
— format-collapse-under-load is the generalist tax. Three cards from
three sources is the exact shape the demo wants, and it's the shape the
generalist degrades on.

---

## What this list is NOT

These are model-side quirks that the **demo pipeline absorbs**. They're not
bugs to file, and they're not unique to this repo — anyone deploying
Qwen 2.5 1.7B on-device will see them.

For Ditto-side bugs (queryMissingEmbedding, the v5 IS NULL trap) see
[`dry-run-findings.md`](dry-run-findings.md). For the rolled-back stuck-
`<think>` watchdog see [`rolled-back-watchdog.md`](rolled-back-watchdog.md).
For the broader thesis this evidence supports see the project's user-
memory entry on the writeup arc.
