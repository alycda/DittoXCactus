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
set (`"inner planets"`, `"outer planets"`, `"the Sun"`, `"Roman emperors"`). The
last is an **off-corpus grounding test** — retrieved is empty, model should output
nothing per the in-prompt rule.

Harness: [`tools/ollama_eval/t1.py`](../../tools/ollama_eval/t1.py).
Raw outputs: [`t1-results.md`](t1-results.md) (auto-generated; safe to regenerate).

Grade on:
- **Format compliance** — `Q:` / `A:` / `SOURCE:` triples land cleanly?
- **Grounding** — does the model hallucinate or stick to retrieved content?
  Off-corpus query is the strict test.
- **Quirk inventory** — `<think>` leakage, `\boxed{}` drift, bilingual drift,
  bracketed SOURCE IDs, JSON output, off-topic padding. (See model-quirks.md
  for the catalogue.)

#### T1 verdict

**Qwen3-1.7B (incumbent) stays.** No candidate model at the ≤ 1.5B size class
beats it on the off-corpus grounding test, and that test is the load-bearing
one for the demo's "no fabrication" claim.

Detail:

| Model | Inner | Outer | Sun | Off-corpus (must output nothing) |
| --- | --- | --- | --- | --- |
| `qwen3:1.7b` (incumbent) | clean 3/3 | clean 3/3 | clean 3/3 | **✓ outputs nothing** |
| `qwen2.5:1.5b` | clean 3/3 | 3/3 but cites Mars UUID as Jupiter source | 3/3 (2 well-formed) | **✓ outputs nothing** |
| `qwen2.5:0.5b` | 1 card | format collapse (`A1:/A2:/A3:`) | 1 card | ✗ fabricates 3 cards |
| `gemma3:1b` | clean 3/3 | clean 3/3 | clean 3/3 | ✗ fabricates 1 card |
| `llama3.2:1b` | clean 3/3 | clean 3/3 | clean 3/3 | ✗ fabricates 3 cards |

Three discriminators surfaced:

1. **Off-corpus grounding is the cliff.** All three of the 1B-or-smaller candidates
   fabricate when `retrieved` is empty, despite the prompt's explicit "output
   nothing" rule. Only Qwen3-1.7B and Qwen2.5-1.5B respect it. This isn't a
   size law (Gemma3-1B and Llama3.2-1B differ by training, not size, and both
   fail). It is a *training-distribution* signal — Qwen's post-training appears
   to weight follow-the-rules harder than Gemma's and Llama's at this size class.

2. **Example-ID anchoring on Qwen2.5-1.5B.** The model wrote `SOURCE: 400ba2af-...`
   (Mars's UUID from the system prompt's example) as a citation for a Jupiter
   card. The notes for Jupiter were in context, with their actual UUID. This is
   the worst-case prompt-leakage failure mode — the model treats the example
   as part of the world it can cite from. Not a deal-breaker (1 of 12 cards),
   but it'd be visible to a user who clicks through to the "source" note.
   *Hard to detect with structural gates because the cited ID is still a valid
   UUID-shaped string.*

3. **`bracket_in_source` is nearly universal.** Most models add brackets around
   UUIDs in SOURCE (e.g. `SOURCE: [c4539818-...]`), copying the format from the
   `[<id>] <body>` listing rather than from the example's `SOURCE: 400ba2af-...`.
   The on-device parser tolerates this; it's a mild format-compliance signal,
   not a failure.

**Carry-overs to the writeup specialists thread.** The off-corpus failure is
the same shape as Needle's "external knowledge source" framing in reverse:
small generalists fabricate when the external knowledge contradicts the rule
because their FFN-heavy paraphrasing capability *can't easily emit nothing*.
A flashcard specialist trained on (notes → cards) pairs with explicit empty
targets when retrieved is empty would refuse fabrication structurally, not
by following an instruction. This is the strongest empirical case in the
writeup so far for *specialists by training*, not specialists by architecture.

### T2 — retrieval quality (host-side, ollama)

For each candidate embedder, embed the merged corpus + the gold query set, score by:
- **Recall@3** vs. a hand-labelled gold set (8 query/expected-topic tuples)
- **MRR** (reciprocal rank of first matching note)
- **Case stability** — does the top-1 change when the query is lowercase vs.
  title-cased? (Qwen3-0.6 is case-sensitive on proper nouns; title-casing fixed
  it for the demo, see `retrieval_service.dart`. T2 tests whether other
  embedders share the same brittleness.)

Harness: [`tools/ollama_eval/t2.py`](../../tools/ollama_eval/t2.py).
Raw outputs: [`t2-results.md`](t2-results.md) (auto-generated; safe to regenerate).

#### T2 verdict

**Qwen3-0.6 (incumbent) stays as the embedder** — but for a more interesting
reason than the T1 verdict.

| Model | Dim | Mean R@3 | Mean MRR | Case-stable / 8 |
| --- | --- | --- | --- | --- |
| `qwen3:0.6b` (incumbent-equivalent) | — | — | — | **HTTP 501 — ollama refused to embed** |
| `nomic-embed-text` | 768 | 1.25 | 0.59 | 3/8 |
| `mxbai-embed-large` | 1024 | 1.13 | 0.54 | **8/8** |

**Three findings worth pinning:**

1. **`qwen3:0.6b` is not embeddable through ollama's standard `/api/embed`
   endpoint.** It returns HTTP 501. The on-device pipeline only embeds it
   because Cactus exposes the chat-tuned model's embedding head as a separate
   surface (`CactusLM` with the embedding initialization flag — see
   `cactus_service.dart`). This is itself a writeup observation: **the demo
   relies on a non-portable surface.** A purpose-built dedicated embedder is the
   obvious alternative path *if* Cactus can load one, and per
   `cactus-sdk-quirks.md` the dedicated `qwen3-embedding-0.6` slug doesn't load
   in 1.3.0.

2. **`nomic-embed-text` collapses every title-cased proper-noun-shaped query to
   `Mercury` as top-1.** "Inner Planets" → Mercury. "Ice Giants" → Mercury.
   "Atmosphere" → Mercury. "Moons" → Mercury. 5/8 queries differ between
   lowercase and title-case, and *all* of the title-cased variants converge to
   the same single note. Hypothesis: in nomic's training corpus, "Mercury" is
   the most token-prominent capitalized solar-system word, so title-casing a
   short query pushes the embedding into Mercury's neighborhood regardless of
   the actual word. **This confirms the title-casing workaround in
   `retrieval_service.dart` is fighting a real, model-agnostic phenomenon, not
   a Qwen quirk.** Modern dedicated embedders inherit case-sensitivity from
   their training data the same way chat models do.

3. **`mxbai-embed-large` is the only fully case-stable embedder tested (8/8).**
   But it pays for that stability with worse semantic retrieval on conceptual
   queries: "inner planets" returns Jupiter/Neptune/Saturn (0/3); "the Sun"
   doesn't put The Sun in the top 3. Case-stability without semantic recall is
   not a win — the on-device title-casing already eats the case problem cheaply.

**The deeper finding for the writeup.** Our pipeline currently uses the
chat-tuned 0.6B model's embedding head, which carries *chat-distribution*
world semantics — concepts like "inner planets" embed in a space where Mercury,
Venus, Earth, and Mars are nearby because those terms co-occur in chat data.
Purpose-built embedders are trained on (query, passage) retrieval pairs where
the relationship is "passage relevant to query," not "concept related to
concept." For a corpus of *named-entity-dense study notes* against
*abstract-concept queries* ("inner planets," "gas giants"), the chat-tuned head
is at a real semantic advantage. A retrieval-trained specialist would only
match it if its training pairs included the same conceptual abstractions.

This is *another specialists-vs-generalists* angle, but the conclusion flips
from T1: for the embedder, the *generalist's* training distribution carries
the world-knowledge our task needs. **A flashcard-domain retrieval specialist
would need to be trained on (concept-name, study-note-body) pairs — not the
standard (search-query, web-passage) pairs that drive nomic and mxbai.**

### T2-Cactus — same gold set, Cactus runtime, three new models

After T2's ollama pass, we added the Cactus CLI (`brew install
cactus-compute/cactus/cactus`) and re-ran the gold-set evaluation against
three embedders the ollama harness couldn't reach. Harness:
[`tools/ollama_eval/t2_cactus.py`](../../tools/ollama_eval/t2_cactus.py).
Raw outputs: [`t2-cactus-results.md`](t2-cactus-results.md).

| Model | Dim | Mean R@3 | Mean MRR | Case-stable / 8 |
| --- | --- | --- | --- | --- |
| `qwen3-0.6` (chat-tuned, INT4) — incumbent | 1024 | 0.38 | 0.30 | **0/8** |
| `qwen3-embedding-0.6` (dedicated, INT4) | 1024 | 0.75 | 0.47 | 6/8 |
| `nomic2-embed-300m` (v2-moe, INT4) | 768 | 0.62 | 0.34 | 1/8 |
| *(reference)* `nomic-embed-text` v1 via ollama | 768 | 1.25 | 0.59 | 3/8 |
| *(reference)* `mxbai-embed-large` via ollama | 1024 | 1.13 | 0.54 | 8/8 |

#### Three new findings

1. **The dedicated `qwen3-embedding-0.6` slug loads fine via Cactus CLI.** This
   contradicts [cactus-sdk-quirks.md](cactus-sdk-quirks.md)'s claim that the
   slug "doesn't load" — that note is stale or Flutter-SDK-1.3.0-specific.
   The C++ engine + Python bindings handle the slug without issue. Worth
   verifying whether the Flutter SDK bug is still real on 1.3.x; this might
   unlock a real swap for the demo.

2. **The chat-tuned `qwen3-0.6` produces *bizarre* embeddings at INT4.**
   *Every* lowercase query converges its top-1 to "Pluto." *Every*
   title-cased query converges to "Mars." All 8 queries case-unstable.
   Mean R@3 = 0.38. This is the *incumbent embedder* in the demo — and at
   INT4 on Mac it's barely functional.

3. **All three Cactus embedders underperform ollama's nomic-embed-text v1.**
   The best Cactus result (dedicated Qwen embedder at R@3=0.75) loses to
   ollama's nomic at R@3=1.25.

#### The INT4 caveat (load-bearing)

**Default precision matters here.** Cactus CLI defaults to `--precision INT4`;
the Flutter SDK catalog reports `quantization=8` for every model (INT8 on
device). Our Cactus eval runs at INT4 — *not* what the demo runs. We
attempted to reconvert at INT8 / FP16 to close the gap and hit a hard
blocker: the local transformers can't import `Qwen3ForCausalLM`, so the
CLI's conversion path failed for both higher-precision variants. INT4 is
the only locally-reproducible precision today.

**This invalidates direct A/B comparison between T2-ollama (full-precision
inference) and T2-Cactus (INT4).** The story is *probably*:

- The demo's on-device Qwen3-0.6 embedder runs at INT8 and produces
  reasonable embeddings — explains why the live demo's retrieval works
  despite our INT4 Mac numbers looking broken.
- The "Pluto / Mars" convergence at INT4 is a quantization-collapse signal,
  not a model-design signal.
- We can't draw conclusions about *which* embedder is best for the demo
  without running INT8 weights, which we can't currently produce locally.

#### What the eval still establishes

- The incumbent assumption — that the Flutter SDK *must* use chat-tuned
  Qwen3-0.6 because the dedicated embedder doesn't load — is wrong. **The
  dedicated slug works on the engine layer.** This is the actionable finding
  worth carrying into the demo.
- The "title-casing fixes case-sensitivity" workaround in
  `retrieval_service.dart` was empirically grounded across multiple model
  families and quantization precisions. It's not over-engineered.
- Precision-dependent retrieval quality is a real seam in the on-device
  claim. The writeup should note that *the demo's retrieval is INT8;
  reproducibility on a Mac with the CLI gets INT4 and worse numbers* —
  another instance of the "on-device specifics matter" thread.

### T1-Cactus — same prompt, Cactus runtime, five catalog completion models

Harness: [`tools/ollama_eval/t1_cactus.py`](../../tools/ollama_eval/t1_cactus.py).
Raw outputs: [`t1-cactus-results.md`](t1-cactus-results.md). **Same INT4
caveat as T2-Cactus** — not directly comparable to ollama T1.

| Model | Off-corpus pass? | Well-formed inner/outer/Sun | Notes |
| --- | --- | --- | --- |
| `qwen3-1.7` (incumbent at INT4) | **✗ 3 cards** | 1/3 / 3/3 / 3/3 | Best format compliance among candidates. **At INT4 it fabricates** on off-corpus ("Constantine the Great reigned 146–149 AD" — wrong) — *worse than at full precision via ollama*. |
| `qwen3-0.6` | ✗ 4 cards | 0/3 / 3/3 / 0/3 | Format collapse on inner planets (just repeats `**Inner Planets**` indefinitely). |
| `lfm2-700m` | **✓ 0 cards** | 0/3 / 0/3 / 0/3 | *Only model passing off-corpus grounding at INT4.* But never emits SOURCE: line — well-formed parses to 0. On off-corpus, emits a meta-comment with the Mars UUID and "no flashcard will be created" — passes by accident but reveals the model knows what to do. |
| `lfm2.5-1.2b` | ✗ 3 cards | 1/3 / 0/3 / 0/3 | Prompt-leakage failure: literally pastes `SOURCE: format, each about "inner planets"` — the model copied user-message text into the SOURCE field. |
| `gemma3-1b` | ✗ 21 cards | 4/10 / 0/3 / 0/4 | **Bilingual drift** — `<end_of_turn>最后一个用户` (Chinese for "last user") leaks through. Same quirk family as Qwen 2.5's CJK drift, across a different vendor. Worst off-corpus runaway (21 cards). |

#### T1-Cactus verdict (with caveats)

**At INT4, no catalog model cleanly beats the incumbent on the same dimensions
that mattered in T1-ollama.** Qwen3-1.7B at INT4 has the best format
compliance but loses the off-corpus grounding test it won at full precision.
LFM2-700M passes off-corpus by routinely failing to emit SOURCE (a different
kind of failure that happens to score 0).

**The precision dimension is now the writeup's headline.** Three independent
signals point at it:

1. T2-Cactus's chat-tuned qwen3-0.6 collapses to Pluto/Mars at INT4 — the
   demo's incumbent embedder *would not work* if the demo ran at this
   precision.
2. T1-Cactus's qwen3-1.7 fabricates on off-corpus at INT4 — the demo's
   incumbent completer *would fail the grounding claim* if the demo ran at
   this precision.
3. Gemma 3 1B at INT4 shows Chinese-language drift (`最后一个用户`) — the same
   training-distribution-leak quirk that Qwen 2.5 shows at the smaller
   `<think>` stages, but in the *generation* output for Gemma. Generalists
   leak their training distribution under quantization stress, regardless
   of vendor.

**Specialists thread carry-over.** Three of the five catalog candidates failed
in a *specifically format-related* way (LFM2's missing SOURCE, LFM2.5's
prompt-leak into SOURCE, Gemma3's `<end_of_turn>` token spam). All would be
solved by a specialist trained to emit `Q:/A:/SOURCE:` triples as its
*native* output format rather than as one of many possible structures it
was told to produce.

**Practical recommendation for the demo:** keep Qwen3-1.7B + Qwen3-0.6 as
the defaults — the on-device INT8 path produces good behavior empirically.
But surface the precision dependence in the writeup: *the demo's quality is
not a property of the model choice alone; it's a property of (model choice,
precision, runtime path).*

### T3 — Needle qualitative (no host harness)

Originally scoped as "run Needle locally on a study-session tool schema." After
reading `_inspiration/cactus-compute/needle/docs/simple_attention_networks.md` it
turns out the architectural argument is the writeup-load-bearing part, not a
playground transcript. T3 collapses to: **the observation paragraph below**, plus a
note in the writeup. The harness install was denied on principle (external repo
auto-setup); not regrettable — the observation lands either way.

#### Observation (specialists thread)

> **Needle's thesis, in one line from its architecture doc:** *"MLPs can be completely
> dropped from transformer networks, as long as the model relies on external knowledge
> source."* The 26M result is what falls out when you take that seriously for
> function-calling — a task whose entire surface is `(query, tools) → JSON`, where the
> tools list *is* the external knowledge. About two-thirds of a standard
> transformer's parameters live in the FFN, doing per-position feature
> transformation; Needle deletes them and replaces that capacity with deep encoder
> cross-attention. The result runs on Cactus at 6000 tok/s prefill and 1200 tok/s
> decode — roughly an order of magnitude above Qwen3-1.7B's on-device numbers.
>
> **Where the analogy with our pipeline almost holds.** Needle frames function-calling
> as "retrieval-and-assembly": match query to tool, extract argument values, assemble
> JSON. Our flashcard pipeline has the same three-step skeleton — match query to note
> (cosine), extract Q/A grounded in retrieved content, assemble `Q: / A: / SOURCE:`
> triples. Same architecture shape: bidirectional encoder over external knowledge,
> decoder emits structured output via cross-attention.
>
> **Where it breaks.** Needle's assembly step is *value-copying* — pull
> `"San Francisco"` out of `"What's the weather in San Francisco?"` and slot it into
> JSON. Our assembly step is *paraphrasing* — turn a note about Mars's polar ice caps
> into a question that doesn't quote it verbatim, and an answer that does. Paraphrasing
> is per-position feature transformation: the same content, rewritten in a different
> token sequence. That's exactly what FFN provides and attention does not. And every
> failure mode catalogued in [model-quirks.md](model-quirks.md) — bilingual CoT drift,
> `\boxed{}` math-mode, off-topic padding, format-collapse-to-prose at n≥3 — is a
> paraphrasing-stage failure, not a retrieval-stage failure. Delete the FFN and you
> delete the failure modes *and the capability they're side-effects of.*
>
> **What a mesh-RAG flashcard specialist would actually look like.** Same skeleton as
> Needle. Bidirectional encoder over the merged CRDT corpus chunks — gives a fixed-size
> representation independent of mesh size, which matters for the offline argument.
> Decoder generates `Q: / A: / SOURCE:` triples via cross-attention. English-study-note
> vocab (Needle's 8192 BPE is probably too small for free-form text; 16k–32k more
> likely). Distill from a teacher generalist over a curated flashcard-pair dataset —
> same recipe as Needle's 2B-token function-call post-training, but flashcards.
> Token-loss weighting *flipped*: Needle weights argument values 4.0x because that's
> where slot-filling fails; we'd weight the **answer** field highest because that's
> where hallucination strikes. **The open question Needle's docs don't answer:** can
> paraphrasing survive full FFN deletion if the encoder is rich enough, or does the
> assembly step need a small FFN budget (say, 4–8M params) that brings the model back
> to ~50M total? Needle's task never tests this because its assembly step doesn't
> paraphrase.
>
> **Bonus thread (preference-aware merge).** Needle's contrastive tool-selection head
> shares the encoder with generation. Our pipeline keeps these separate (Qwen3-0.6 for
> embed, Qwen3-1.7 for complete), so a peer can have great-cosine notes that still
> trip the larger model's paraphrasing quirks. A unified-encoder specialist would
> couple retrieval quality to generation quality directly: rank peers by the same
> encoder that's about to read their notes. The merge math gets simpler — there's
> only one embedding space, not two — and the *preference-aware merge* thread of the
> writeup gets a cleaner abstraction to point at.

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

- [x] Candidate ollama models pulled — completion: `qwen3:1.7b`, `qwen2.5:1.5b`,
      `qwen2.5:0.5b`, `gemma3:1b`, `llama3.2:1b`; embedding: `qwen3:0.6b`,
      `nomic-embed-text`, `mxbai-embed-large`
- [x] Cactus CLI installed via `brew tap cactus-compute/cactus && brew install …/cactus`;
      packaging fix: symlinked `/opt/homebrew/lib/libcactus.dylib` →
      `/opt/homebrew/lib/cactus/build/libcactus.dylib` (where the bundled
      Python module expects it).
- [x] Cactus weights downloaded for the catalog eval (`/opt/homebrew/Cellar/cactus/.../weights/`):
      `qwen3-0.6b`, `qwen3-1.7b`, `qwen3-embedding-0.6b`, `nomic-embed-text-v2-moe`,
      `lfm2-700m`, `lfm2.5-1.2b-instruct`, `gemma-3-1b-it`. All INT4.
- [x] Needle cloned into `_inspiration/cactus-compute/needle/` (gitignored)
- [x] T3 — Needle observation drafted
- [x] T1 — flashcard fidelity harness + ollama run + verdict
- [x] T2 — retrieval quality harness + ollama run + verdict
- [x] T2-Cactus — Cactus-runtime embedding eval + verdict (dedicated slug
      loads; INT4 precision degrades all three)
- [x] T1-Cactus — Cactus-runtime completion eval + verdict (Qwen3-1.7 at INT4
      fabricates on off-corpus; Gemma 3 1B drifts bilingual; LFM2-700M passes
      off-corpus by accident)
- [ ] **TinyLlama / TinyDolphin via C++ route** — deferred. Recognized at the
      engine level (`engine_model.cpp:548` maps `tinyllama` to
      `ModelType::GEMMA4`) but not in the SDK catalog. Requires bypassing
      `cactus download` and pointing the engine at a custom GGUF directly.
- [ ] CLAUDE.md model-default decision — pending, see T1-Cactus verdict;
      *no change to demo defaults; surface precision dependence in the
      writeup instead.*
