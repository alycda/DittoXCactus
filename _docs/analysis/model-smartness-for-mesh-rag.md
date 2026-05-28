# How "smart" are AI models for this task?

This project asks a small on-device model to do something that sounds
simple but is actually an adversarial stress test of what "intelligence"
means at 1–2 billion parameters.

---

## What the task actually is

The model receives 1–3 short study notes about the solar system (each
~200 characters) and must produce structured flashcards in this exact
format:

```
Q: What makes Venus's atmospheric conditions so extreme?
A: Venus has a thick CO2 atmosphere creating a runaway greenhouse effect with surface temperatures reaching 465°C.
SOURCE: 62ba146b-4c3a-5d91-8f2e-1a9b3c4d5e6f
```

That's it. Read some notes, write some Q/A pairs, cite the source by its
UUID. A human could do this in 30 seconds.

---

## Why this is actually hard for a small model

The task decomposes into **five cognitive subtasks**, and a 1.7B-parameter
model must execute all five simultaneously within a single autoregressive
pass:

### 1. Format adherence (structural intelligence)

The model must emit `Q:` then `A:` then `SOURCE:` on separate lines, with
no markdown, no JSON, no LaTeX, no bullets, no numbering. This is a
**negative constraint** — the model must suppress dozens of familiar output
shapes it was trained on.

**What actually happens:** Qwen 2.5 1.7B was trained on MATH dataset
competitions and instruction-following corpora. When it sees "give me your
final answer in this format," it reaches for `\boxed{...}` (math-mode
habit), `### Section headers` (summary-article habit), or JSON (API habit)
— all shapes it saw thousands of times during training. The Q:/A:/SOURCE:
format is rare enough in its training data that it loses the format war
against more familiar shapes once the task gets complex.

**Benchmark data:** The StructEval benchmark (Tiger AI Lab, 2025) measures
structured output adherence. At >3B parameters, models start holding
format: Qwen3-4B scores 67.04%, Phi-4-mini scores 56.97%. Below 2B, models
"frequently fail to output valid JSON or adhere strictly to structured list
formats." The project confirmed this empirically: format holds at 1 card
from 1 source, collapses at 3 cards from 3 sources.

### 2. Content extraction (reading comprehension)

The model must identify flashcard-worthy facts in the retrieved notes and
extract them accurately — no hallucination, no invention, no paraphrasing
that changes meaning.

**What actually happens:** This is the subtask the model is best at.
Reading comprehension at this parameter scale is genuinely strong. The
problem is that the model is *too thorough* — asked about "moons," it
extracts every fact from a Mars note that mentions moons, including
Olympus Mons height, Martian day length, and atmospheric composition.
It doesn't distinguish "mentioned in a note that's about moons" from
"is a fact about moons."

### 3. Brevity (output discipline)

The answer must be under 30 words — "a direct factual statement." The
model must suppress its trained instinct to explain, qualify, compare, and
contextualize.

**What actually happens:** Qwen was trained on detailed Q/A data. Asked
for a definition, it gives one with caveats, comparisons, units, and
analogies. A 50-word answer for card 1 means card 2 gets truncated by the
token budget. The pipeline compensates by raising per-card token budgets
(160→220 tokens), but this is treating symptoms.

### 4. Citation accuracy (symbolic manipulation)

The model must copy a UUID like `62ba146b-4c3a-5d91-8f2e-1a9b3c4d5e6f`
verbatim from its context window to the SOURCE line. This is pure
character-level copying — no "understanding" required.

**What actually happens:** This is where it gets weird. The model
sometimes emits fullwidth Chinese digits *inside the UUID*:
`c4539818-8885-5305-97bb-04827８７１aa３２`. The bilingual training data
(Chinese + English shared embedding space) bleeds through at the character
level. The model isn't copying bytes — it's generating what it thinks a
UUID looks like, and its Chinese training data influences even structural
identifiers. The pipeline compensates with `backfillCardSources`, which
re-attributes cards to retrieved notes by content matching.

### 5. Multi-task coherence (holding it all together)

Subtasks 1–4 must happen simultaneously. The model doesn't get to do
format compliance in one pass and content extraction in another. Each
generated token is a joint decision across all five axes.

**What actually happens:** The model handles 1 card from 1 source well.
At 3 cards from 3 sources, it collapses to "summary article" mode —
markdown headers, bullet points, and structured prose instead of
Q:/A:/SOURCE: tuples. The model's training distribution contains far more
"summarize these 3 passages" examples than "extract 3 Q/A pairs from 3
passages in this custom format" examples. The familiar shape wins.

---

## The intelligence spectrum across model sizes

The project's research and empirical data paint a clear picture of how
"smartness" scales with parameters for this specific task:

| Size class | What works | What breaks |
|------------|-----------|-------------|
| **~600M** (qwen3-0.6) | Embedding generation, cosine similarity | "Incoherent flashcards" — can't hold format + content simultaneously |
| **~1.7B** (qwen3-1.7, the shipped model) | 1-card generation, content extraction, basic format adherence | Format collapse at n≥3, LaTeX drift, bilingual CoT contamination, verbose answers |
| **~4B** (Qwen3-4B, benchmarked only) | 67% StructEval — format starts holding | Still not reliable enough for production without guardrails |
| **~7B+** (Llama 3.2 3B, Phi-3 Mini) | Format mostly reliable, multi-card generation | Too large for comfortable mobile deployment under R5 cold-load budget |

The project chose 1.7B as the sweet spot: large enough to produce coherent
single cards, small enough to load on a Pixel 6a within the cold-load time
budget.

---

## What "smart" means here vs. what people assume

**What people assume "smart" means:** Can the model answer hard questions?
Does it know facts about Saturn's moons?

**What "smart" actually means for this task:** Can the model hold a
specific output format stable while extracting content from context,
suppressing its trained instincts to elaborate, copying identifiers
verbatim, and doing all of this within a fixed token budget?

The model *knows* plenty about Saturn's moons — it was trained on
Wikipedia. The challenge isn't knowledge. The challenge is **output
discipline under format constraints**, which is a fundamentally different
axis of capability that scales poorly below 3B parameters.

This is the core insight the project's thesis builds on: generalist models
at small scale are victims of their own training distribution. They've
seen millions of "summarize this passage" examples and very few "emit
exactly this format" examples. When the task gets complex enough that the
model has to choose between familiar output shapes and the prompted format,
the familiar shape wins.

---

## The specialist hypothesis

The project's writeup frames this as evidence for **domain-specific
specialist models** as the future of on-device AI:

> "A specialist flashcard-generation model would have no 'summary article'
> mode in its training distribution — format-collapse-under-load is the
> generalist tax."
> — model-quirks.md

A model fine-tuned exclusively on Q:/A:/SOURCE: flashcard generation would
never emit `\boxed{}`, never drift into Chinese chain-of-thought, never
collapse into markdown summary prose — because those shapes wouldn't exist
in its training data. The research cites two supporting papers:

- **Tiny Titans** (arXiv 2402.00841): fine-tuned FLAN-T5-Large rivals
  zero-shot 7B–70B models on meeting summarization
- **LoRA Land** (arXiv 2405.00732): 310 specialized 7B-scale LoRAs rival
  GPT-4 across narrow tasks

The implication: a 600M specialist could outperform a 1.7B generalist on
this exact task, while using less memory and loading faster.

---

## How the pipeline compensates for model limitations

Rather than requiring the model to be "smarter," the project wraps it in a
layered defensive pipeline:

| Layer | What it catches | Where it lives |
|-------|----------------|----------------|
| **Stop sequences** | `\boxed`, `\begin{aligned}`, `\text{` — halts generation before LaTeX drift takes over | `cactus_service.dart` |
| **Title-case normalization** | Case-sensitive embedder produces better cosine separation for proper nouns | `retrieval_service.dart` |
| **Cosine threshold** | `minScore=0.3` — filters irrelevant retrievals before they reach the LLM | `retrieval_service.dart` |
| **Entity-overlap gate** | Drops retrieved notes that don't mention the query topic | `retrieval_service.dart` |
| **Grounding gate** | Skips LLM entirely when retrieval is empty — prevents hallucination | `retrieval_service.dart` |
| **effectiveN cap** | `min(n, retrieved.length)` — never asks for more cards than sources | `retrieval_service.dart` |
| **`<think>` stripping** | Removes chain-of-thought blocks the model emits despite the prompt ban | `flashcard_gen.dart` |
| **On-topic filter** | Drops cards where neither Q nor A mentions the topic | `retrieval_service.dart` |
| **Reasoning-leak filter** | Drops cards with "Wait," "Hmm," "Actually" in the answer | `retrieval_service.dart` |
| **Answer-length cap** | Drops cards with answers exceeding the word budget | `retrieval_service.dart` |
| **Source backfill** | Re-attributes uncited cards via content matching against retrieved notes | `retrieval_service.dart` |
| **Drop-uncited filter** | Removes cards that couldn't be attributed to any source | `retrieval_service.dart` |
| **Deduplication** | Removes near-duplicate questions | `retrieval_service.dart` |

The design principle (pinned in user memory as `feedback_structural_gates`):
**gate on inputs at the service layer, not on outputs at the stream.** The
model is a noisy generator; the pipeline is the quality filter.

---

## The bottom line

A 1.7B model is about as smart as a diligent but inattentive student
copying notes: it knows the material, it can produce correct answers, but
it can't reliably follow formatting instructions, it drifts into familiar
habits under pressure, and it needs a teacher checking its work. The
"teacher" in this project is 12 layers of defensive parsing and filtering
that together absorb the model's predictable failure modes.

The model isn't dumb — it's a generalist being asked to act like a
specialist, and it's working at the edge of its parameter budget. The
project's honest answer to "how smart is it?" is: **smart enough to be
useful with guardrails, not smart enough to be trusted without them.**
