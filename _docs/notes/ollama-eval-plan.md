# Local-model evaluation plan (ollama + Needle)

Working bookmark: `experiment/ollama-needle-eval`. **Not for merge into main** until
the eval produces something the writeup actually leans on.

## Why this exists

The current pipeline is locked in:

- Embedding: `qwen3-0.6` (chat-tuned, embedding head)
- Completion: `qwen3-1.7`

Both picks are Cactus catalog constraints, not free choices — see
[cactus-sdk-quirks.md](cactus-sdk-quirks.md) for why the dedicated `qwen3-embedding-0.6`
slug doesn't load, and the comments at the top of
[cactus_service.dart](../../lib/services/cactus_service.dart) for the 600M vs 1.7B
flashcard-coherence cutoff.

Two questions worth answering before the writeup ships:

1. **Is Qwen3-1.7B actually the best completion choice at this size class for our
   flashcard task?** Or did we lock in early on the first thing that produced
   coherent cards?
2. **Where does a specialist model — Needle, distilled tool-caller — fit
   relative to a generalist of comparable size?** This is the load-bearing question
   for the writeup's *specialists thread* (memory `project_writeup_thesis_arc`).

## Eval ≠ deployment

**Ollama is a host-side fidelity harness. It does not ship.** The demo runs on
Cactus on-device. Anything we measure with ollama must be checked against the
Cactus catalog before it influences the demo. So this eval has two outputs:

- A **dev-host comparison table** (objective: which models would produce better
  flashcards / better retrieval if Cactus could load them?)
- A **portability note** (objective: which winners are actually reachable from
  Cactus 1.3.0's catalog, vs. which are stuck behind the Supabase metadata wall)

## Candidates

### Completion (target: <= 2B, beats Qwen3-1.7B on our prompt)

| Model | Params | Ollama slug | Cactus catalog? |
| --- | --- | --- | --- |
| Qwen3-1.7B (incumbent) | 1.7B | — (use Cactus directly) | yes |
| Qwen2.5-1.5B | 1.5B | `qwen2.5:1.5b` | likely (different gen, untested) |
| Qwen2.5-0.5B | 0.5B | `qwen2.5:0.5b` | likely |
| Gemma 3 1B | 1B | `gemma3:1b` | unknown |
| Llama 3.2 1B | 1B | `llama3.2:1b` | unknown |

### Embedding (target: keep dim small, match cosine quality)

| Model | Dim | Ollama slug | Notes |
| --- | --- | --- | --- |
| Qwen3-0.6 head (incumbent) | runtime-captured | — | chat-tuned, repurposed head |
| nomic-embed-text | 768 | `nomic-embed-text` | dedicated embedder; baseline |

### Specialist (out-of-pipeline comparison)

**Needle (cactus-compute/needle).** 26M params, distilled from Gemini 3.1, single-shot
function-call only. Not a completion model — cannot produce flashcards directly.
Used here as a **qualitative reference point** for the specialists thread of the
writeup: how does a 26M tool-caller compare with a 600M general embedder + 1.7B
generalist when the task is narrowly defined?

Likely framing for the writeup: *"Needle proves the size floor isn't where you think
it is, but only if the task is narrow. Our flashcard task is closer to general
summarization than tool-calling, so the comparison illustrates the gap rather than
closing it."* — to be revised once we actually run it.

## Eval tasks

### T1 — flashcard fidelity (host-side, ollama)

Input: the existing seed corpora (`assets/seed_notes_a.json`, `assets/seed_notes_b.json`).

For each candidate completion model, run the same prompt template as
[`FlashcardGenPrompt`](../../lib/prompts/flashcard_gen.dart) on a fixed query
(`"inner planets"`, `"outer planets"`, plus 3 off-corpus queries to test grounding).

Grade on:
- **Format compliance** — `Q:` / `A:` / `SOURCE:` triples land cleanly?
- **Grounding** — does the model hallucinate or stick to retrieved content?
- **Quirk inventory** — `<think>` leakage, `\boxed{}` drift, bilingual drift,
  off-topic padding. (See model-quirks.md for the catalogue.)

### T2 — retrieval quality (host-side, ollama)

For each candidate embedder, embed the merged corpus + the same query set, score by:
- **Top-K precision** vs. a hand-labelled gold set (~20 query/note pairs)
- **Cross-language stability** (does case sensitivity matter the same way? Qwen3-0.6
  is famously case-sensitive on proper nouns; title-casing fixed it for the demo —
  see `retrieval_service.dart`)

### T3 — Needle qualitative (no host harness)

Originally scoped as "run Needle locally on a study-session tool schema." After
reading `_inspiration/cactus-compute/needle/docs/simple_attention_networks.md` it
turns out the architectural argument is the writeup-load-bearing part, not a
playground transcript. T3 collapses to: **the observation paragraph below**, plus a
note in the writeup. The harness install was denied on principle (external repo
auto-setup); not regrettable — the observation lands either way.

#### Observation (specialists thread)

> Needle's design thesis is one line from its architecture doc: *"MLPs can be
> completely dropped from transformer networks, as long as the model relies on
> external knowledge source."* The 26M result is what falls out when you take that
> seriously for function-calling — a task whose entire surface is `(query, tools)
> → JSON`, where the tools list *is* the external knowledge. About two-thirds of
> the parameters in a normal transformer are FFN doing per-position feature
> rewriting; Needle deletes them and replaces deep cross-attention from the encoded
> tools to the generated answer. The result runs on Cactus at 6000 tok/s prefill
> and 1200 tok/s decode — roughly an order of magnitude above our current Qwen3-1.7B
> on-device numbers.
>
> The interesting question for the Mesh RAG writeup is whether our flashcard task
> has the same shape. Needle calls function-calling "retrieval-and-assembly" —
> match query to tool, extract argument values, assemble JSON. Our pipeline does
> almost the same thing: match query to note (cosine), extract Q/A grounded in
> retrieved content, assemble `Q: / A: / SOURCE:` triples. The difference is the
> *assembly* step: Needle copies argument values; we paraphrase notes into
> question/answer pairs. That paraphrase step is where the FFN actually earns its
> keep on Qwen3-1.7B — every quirk we documented in `model-quirks.md` (bilingual
> CoT drift, `\boxed{}` math-mode, off-topic padding) is a paraphrasing-stage
> failure, not a retrieval-stage failure. Strip the FFN and those quirks go away,
> but so does the model's ability to generalize the paraphrase across topics it
> wasn't trained on.
>
> The specialists thread of the writeup should land this directly: *Needle is what
> happens when the assembly step is structured-output-only. A mesh-RAG flashcard
> specialist would look similar — encoder over the merged CRDT corpus, decoder
> generates Q/A grounded in cross-attention — but the assembly step's "free-form
> rewriting" budget is what we'd need to negotiate. The architectural lesson
> transfers; the off-the-shelf weights don't.*
>
> Bonus observation for the writeup: Needle's **contrastive tool-selection head**
> shares the encoder with generation. Our pipeline keeps these separate (Qwen3-0.6
> for embed, Qwen3-1.7B for complete). A unified-encoder specialist would let
> retrieval and assembly share representations — relevant to the *preference-aware
> merge* thread, where the embedding space is what determines which peer's notes
> outrank which.

#### Deploy-path note

Even if we wanted to use Needle in the demo, we can't drop it into the current
pipeline:

- It's a function-call specialist, not a flashcard generator. No paraphrasing.
- It's JAX/Flax weights, not GGUF; Cactus's Flutter SDK 1.3.0 only loads its
  curated catalog of GGUF-format models.
- The Cactus repo would need a separate Needle adapter on the runtime side.
  Plausible future work, out of scope for the demo.

## What success looks like

This eval is a writeup investment, not a pipeline change. Success = three
artifacts:

1. A small results table (this file or a sibling) ranking candidates on T1 + T2.
2. A Needle observation paragraph that supports the specialists thread.
3. A one-line decision in CLAUDE.md: *"Qwen3-1.7B / Qwen3-0.6 remain the demo
   defaults because <reason>"* — or, if something beats them and is Cactus-reachable,
   a follow-up bookmark to actually swap.

## Status

- [x] Candidate models pulled — `qwen2.5:0.5b`, `qwen2.5:1.5b`, `gemma3:1b`,
      `llama3.2:1b`, `nomic-embed-text`
- [x] Needle cloned into `_inspiration/cactus-compute/needle/` (gitignored)
- [x] Writeup observation drafted (T3 — see above)
- [ ] T1 harness wired up (host-side flashcard fidelity)
- [ ] T2 harness wired up (host-side retrieval quality)
- [ ] Results table populated
- [ ] CLAUDE.md model-default decision committed
