# SEED-A Pivot Research — Flashcards from Study Notes

> Opus-only, hand-research pass on the SEED-A pivot (recipes → study notes / flashcards). Done by Opus directly via WebSearch + WebFetch on 2026-05-21. Companion to [SEED-A.md](../../SEED-A.md).
>
> The pivot trades a high-cognition LLM task (multi-step recipe synthesis) for a low-cognition task (extractive Q/A from a passage) without changing the Ditto + Cactus + flat-cosine stack. This research validates the load-bearing claims in SEED-A and surfaces where the novelty actually lives.

---

## 1. Load-bearing claims in SEED-A — validated?

### Claim: "Anki has been doing exactly this with cloud LLMs for two years"

**Verdict: confirmed, with an important nuance.** There's a healthy ecosystem of LLM → Anki tooling, all currently single-user + cloud-first:

- **[anki-llm](https://github.com/raine/anki-llm)** — CLI/TUI bulk-generates Anki cards via any OpenAI-compatible LLM endpoint. Supports cloud (Gemini Flash Lite, DeepSeek, GPT-4o-mini, Groq) AND local (Ollama, llama.cpp, vLLM). Documentation emphasizes cost efficiency (~$0.35/1000 cards on Gemini Flash Lite) rather than quality benchmarks across small local models — that gap is real and SEED-A could fill it.
- **[doc-to-anki-with-llm](https://github.com/elpadev/doc-to-anki-with-llm)** — PDF → Anki deck pipeline.
- **[boldfish](https://github.com/ozieblo-michal/boldfish)** — LLM + Bionic Reading for Anki creation.
- **[LLM-Chit-Chat-Flashcards](https://github.com/Ganryuu/LLM-Chit-Chat-Flashcards)** — conversational generator.
- Practitioner writeups: [Anthony Robertson](https://www.anthonywritescode.com/llm-powered-anki-card-generation/), [Alexej Gossmann's GPT-4 vs 3.5 vs local LLM comparison](https://www.alexejgossmann.com/LLMs-for-spaced-repetition/).

**The novelty SEED-A retains:** every tool above is **single-user, single-corpus**. None do mesh sync. None have the "phone B's notes contributed N of these 5 cards" provenance line. None invoke the LLM as the *synthesis agent across a group of contributors*. That is the SEED-A slot.

### Claim: "1.5B model has enough capacity" / "Anki's flashcard-from-passage prompts run on gemma 270M acceptably"

**Verdict: directionally confirmed by independent sources.**

- **Phi-2 (2.7B parameter SLM)** is specifically called out as suitable for educational tasks including question generation in [Generate-Then-Validate (arXiv 2512.10110)](https://arxiv.org/abs/2512.10110), trained on textbook-like data.
- Benchmark roundups (e.g., [AscentCore's Small LLM Performance Benchmark](https://ascentcore.com/2026/04/01/small-llm-performance-benchmark/)) show **the 1B → 3B step is meaningful for accuracy, with diminishing returns past 4–5B** on focused tasks: description generation, classification, summarization, structured data extraction. Q/A generation falls squarely in this class.
- Q/A pair generation from a passage is **extractive-flavored** — the answer must live in the source. This is a far easier task class than the open-ended recipe synthesis Stage 0 failed on. SQuAD-style extractive QA is well within the 1.5B parameter envelope.

**Conclusion:** Qwen 2.5 1.5B at Q4_K_M is well-positioned. SmolLM2 1.7B and Gemma 3 1B IT are realistic fallbacks. If quality on the slowest demo device sags, the smaller-still options (Gemma's smallest, Phi-3-mini) are likely still acceptable for Q/A — much more headroom than recipe synthesis had.

### Claim: "Two students' notes have complementary coverage; the union is more complete than any individual's"

**Verdict: load-bearing claim, and the educational-psychology literature backs it explicitly.** This is the **Jigsaw classroom** model.

- **[Effects of the Jigsaw method on student educational outcomes: systematic review and meta-analyses](https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2023.1216437/full) (Frontiers in Psychology, 2023; [PMC10436097](https://pmc.ncbi.nlm.nih.gov/articles/PMC10436097/))** — meta-analysis of 69 Jigsaw studies. Outcomes measured: achievement, motivation, social relations, self-esteem. **The core mechanism in Jigsaw is resource interdependence: "students must work in small groups on complementary pieces of information."** That's the same shape as SEED-A's mesh corpus.
- The Jigsaw method itself (Aronson 1971) is one of the most-studied cooperative-learning techniques in the 50-year educational-psychology literature.
- **One important caveat from the literature:** "informational dependence may be problematic for learning if the information is of poor quality." Translation for SEED-A: if any student's notes are wrong/misleading, the LLM-merged flashcards may inherit and propagate the error to other students. This is a real failure mode the demo should at least acknowledge.

**The thesis the writeup can land on:** the Jigsaw classroom is a 50-year-old pedagogical pattern. SEED-A is the LLM-mediated, mesh-synced realization of it — the AI does the synthesis work that the original Jigsaw method asks students to do verbally over an hour at the library. *"The mesh isn't a sync mechanism. It's a study aid."* now has empirical educational-psychology grounding, not just a vibe.

---

## 2. Quality evaluation framework — borrow EQGBench

**[EQGBench: Educational Question Generation Benchmark (arXiv 2508.10005)](https://arxiv.org/abs/2508.10005)** is the directly-relevant prior art for the question "is this flashcard good?"

- Five-dimensional evaluation framework
- 900 evaluation samples
- Three disciplines (math, physics, chemistry — middle school level)
- 46 models systematically evaluated
- Designed for LLMs generating *pedagogically valuable* questions, not just syntactically valid ones

**For SEED-A's adaptation:** the EQGBench rubric dimensions are usable nearly verbatim as a flashcard-quality eval (which replaces Stage 0's recipe-merge eval U3). Specifically: pedagogical value, knowledge-point coverage, difficulty calibration, answer-from-source verifiability. The flashcard eval — call it U3' — should:

1. Curate ~10 fixture passages (1–3 paragraphs each) on a topic the team knows well.
2. Generate 5 cards from each passage with Qwen 2.5 1.5B + SmolLM2 1.7B (+ optionally Phi-3-mini).
3. Score each card on a 1–5 rubric: (a) answer-from-source (no hallucinated content), (b) question is meaningful (not "what does the passage say"), (c) discriminative difficulty, (d) coverage of the passage's key concept, (e) no near-duplicates with other generated cards.
4. **Pass threshold: 4 of 5 cards per passage clear ≥ 3.0 average across the rubric on the slowest device.**

This is meaningfully easier than the recipe-merge 8/10 threshold, which is the whole point of the pivot.

Companion source for Q/A eval methodology: **[Automatic Question & Answer Generation Using Generative LLM (arXiv 2508.19475)](https://arxiv.org/abs/2508.19475)** — broader survey of automated Q/A gen evaluation.

---

## 3. What changes vs Stage 0's plan — by U-ID

The composite plan ([docs/plans/2026-05-21-002-...](../plans/2026-05-21-002-feat-mesh-rag-stage-0-composite-plan.md)) has 11 units (U1–U10 + U1.5). Most carry over verbatim. The pivot's diff:

| Unit | Stage 0 (recipes) | SEED-A (flashcards) |
|---|---|---|
| **U2 — Determinism spike** | Unchanged. Same Qwen3-Embedding-0.6B, same Q4_K_M, same 20-fixture parity check. Embedding parity is corpus-agnostic. |
| **U3 — LLM eval** | Recipe-merge: 5 dishes × 3 variants, adversarial fixtures, 8/10 pass threshold. | **Flashcard generation: 10 fixture passages, 5 cards each, EQGBench-derived 5-dim rubric, 4-of-5 cards ≥ 3.0 pass threshold.** |
| **U4 — Ditto schema** | `RecipeTuple`: `{id, dish, contributor, ingredients[], steps[], embedding[], metadata}`. | **`StudyNote`: `{id, topic, contributor, body, tags[], embedding[], metadata}`.** Deterministic IDs unchanged. Source-device metadata unchanged. |
| **U5 — Retrieval** | Top-k tuples for query. | **Top-k notes for a topic.** Identical brute-force cosine, L2-normalize at insertion, tie-break by `_id`. |
| **U6 — Synthesis** | `complete(prompt + top-k tuples)` → streaming answer. Recipe-merge prompt. | **`generateFlashcards(topic, n) → List<Flashcard>`. Prompt: "Given these notes, produce N flashcards as JSON. Each card must be answerable from the provided notes alone."** Cards returned in one streamed call; max-tokens budget ~1280 (256 × 5 cards). **The runtime `Flashcard {question, answer, sourceNoteIds}` shape is not synced** — cards regenerate per query. |
| **U7 — Mesh sync verification** | Unchanged. |
| **U8 — Demo UI** | Streaming answer pane + tuple cards. | **Flashcard stack with flip-on-tap. Attribution footer: "drew on N notes (M from peers)."** Mesh-state pill unchanged. Debug menu unchanged. |
| **U9 — Rehearsal** | Unchanged shape; corpus is hand-curated study-notes-on-a-topic instead of recipes. |
| **U10 — Deck** | Same arc; "the mesh is a study aid" lands harder than "the mesh is a CRDT." |

**Net file-count change: ~6 files** (rename `recipe_tuple.dart` → `study_note.dart`, prompts, retrieval method, seed assets, UI widget, DQL collection). Architecturally identical — the C4 model would change only at description text + one component (no `RecipeMergePrompt`; gains `FlashcardGenerator`). The composite c4 model on `wxy` is largely re-usable.

---

## 4. Why this pivot wins on demo legibility

The recipes demo had a "the answer got *better*" reveal. *Better* is mushy — audiences had to read both phones' notes and trust the operator that the merged recipe was actually composed.

The flashcards demo has a **"a card appeared that couldn't have existed before sync"** reveal. That's binary and intuitive:

1. Phone A alone: "give me 5 flashcards." Card #3 covers concept X. **No card about concept Y** — because phone A's notes never mentioned Y.
2. Phone B joins. "Give me 5 flashcards" again. **Now there's a card about concept Y**, and the attribution says "drew on 2 notes from peers."
3. Audience can verify off-camera: phone B's notes have the only mention of concept Y in the union.

The Jigsaw-method literature reinforces this intuitively: students *expect* each contributor to hold complementary pieces. The demo confirms that intuition on phones, in front of them, in airplane mode.

---

## 5. Adversarial / where SEED-A could still fail

The pivot fixes the recipe-merge weakness but introduces new failure modes the planning should pre-mortem:

- **Bad input ⇒ bad cards.** Jigsaw-method caveat applies: if phone B's notes are inaccurate, the LLM will faithfully generate flashcards that are *also* inaccurate. The mesh provenance line ("drew on 2 notes from peers") is now propagating misinformation with a confident UI. **Mitigation:** at demo time, the contributors curate their own notes; the audience can verify off-camera; this is a hackathon demo not a production app. For Stage 1+ would need a trust/quality layer (which folds into the future-work *adversarial filtering* thread from the original arc — same problem, different corpus).

- **All notes on the same topic but contradictory framings.** Two students with different teachers may write notes that contradict each other on the same concept. The LLM has to pick one or both. Card quality may degrade. **Mitigation:** the demo topic is hand-picked; this is a Stage-1 problem.

- **Five cards is small enough that "added-from-peer" can fail to land.** If the top-5 cards happen to all come from phone A's notes (because phone A's notes had stronger top-k matches), the post-sync demo looks identical to pre-sync. **Mitigation:** *engineer the demo*. Pre-author both phones' notes such that 1–2 cards' top-k tuples necessarily come from phone B. This is rehearsal work, not implementation work.

- **EQGBench's 46-model survey found "significant room for development" even at 7B+ scale.** Educational question generation is harder than it looks. **Mitigation:** SEED-A's threshold is "4 of 5 cards clear ≥ 3.0 / 5 rubric" — that's a deliberately forgiving bar for a demo, not a publication-grade claim. The eval rubric should explicitly say "demo quality, not pedagogical research quality."

- **JSON-structured output reliability on 1.5B.** The prompt asks for cards "as JSON." Small LLMs sometimes drift from strict JSON. **Mitigation:** use Cactus's grammar-constrained output if it exposes one, OR add a post-process repair step. [Schema-aware extraction on small LLMs (arXiv 2505.14992)](https://arxiv.org/abs/2505.14992) is the relevant prior art — it shows the regime works.

---

## 6. Suggested writeup framing (revised from original four-thread arc)

The original writeup arc was *specialists → preference-aware merge → adversarial filtering → generational evolution*. SEED-A doesn't kill that arc but it does **reorder the punchline**:

- **Stage 0 (recipes)** was supposed to lead the writeup with "your knowledge base wants to be a CRDT" — abstract, structural.
- **Stage 0.5 / SEED-A (flashcards)** opens with **"the mesh is a study aid"** — concrete, immediate. Then expands to the broader CRDT thesis.
- The four-thread future-work arc still applies (specialists, preference-aware, adversarial, generational) but is now anchored to a more relatable Stage-0 demo.
- The Jigsaw-method 50-year literature is *new ammunition* the writeup can lean on — the AI-mediated Jigsaw classroom is a richer framing than the recipes-as-CRDT framing. The flashcard outcome is *measurable in classroom-research terms* (achievement, retention, motivation), which is something the recipe pivot couldn't credibly claim.

---

## 7. Suggested additions to `downloads.yaml`

If you want these archived alongside the existing 178-entry manifest, the high-value adds:

| URL | kind | Why |
|---|---|---|
| <https://arxiv.org/abs/2508.10005> | paper | EQGBench — direct quality-eval framework |
| <https://arxiv.org/abs/2512.10110> | paper | Generate-Then-Validate — small-LM question gen architecture |
| <https://arxiv.org/abs/2508.19475> | paper | Automatic Q/A generation survey |
| <https://arxiv.org/abs/2505.14992> | paper | Schema-aware extraction on on-device LLMs (already in manifest from Step 4.5 — verify) |
| <https://www.frontiersin.org/journals/psychology/articles/10.3389/fpsyg.2023.1216437/full> | paper | Jigsaw method meta-analysis (Frontiers 2023) |
| <https://pmc.ncbi.nlm.nih.gov/articles/PMC10436097/> | paper | Same paper, PMC mirror |
| <https://github.com/raine/anki-llm> | repo | Closest existing tool; single-user cloud baseline |
| <https://github.com/elpadev/doc-to-anki-with-llm> | repo | PDF → Anki via LLM |
| <https://www.alexejgossmann.com/LLMs-for-spaced-repetition/> | article | Practitioner comparison of cloud + local LLMs for flashcards |
| <https://www.anthonywritescode.com/llm-powered-anki-card-generation/> | article | Practitioner writeup |

Wired in with `step: seed-a` in the `cited_in` field for traceability.

---

## 8. Bottom line

SEED-A is a real strict-improvement over the recipes corpus on four axes:

1. **LLM task feasibility** — extractive Q/A from passages is well within the 1.5B parameter envelope; recipe synthesis isn't.
2. **Demo legibility** — "a card appeared that couldn't have existed before" is binary; "this recipe is better" is mushy.
3. **Writeup framing** — the AI-mediated Jigsaw classroom has 50 years of educational-psychology literature backing it; recipes-as-CRDT was a vibe.
4. **Architectural cost** — ~6 file changes. The composite plan ([docs/plans/2026-05-21-002-...](../plans/2026-05-21-002-feat-mesh-rag-stage-0-composite-plan.md)) carries over almost verbatim with U3 + U6 + U8 substitutions and the `RecipeTuple` → `StudyNote` rename.

Recommended next move: skip `/ce-plan` (the seed is concrete enough); jump to `/ce-work` against the SEED-A pivot directly. If you want a formal plan first, a 30-minute pass would U3/U6/U8 the composite plan into a "SEED-A composite plan" — but the seed itself already does most of that work.

The one real open question SEED-A surfaces but doesn't resolve: **which demo topic.** You flagged this — "obviously one student will have crucial notes the others missed." When you pick the topic, the U9 rehearsal step has to engineer phone A's notes and phone B's notes so the audience can read both and immediately see the gap. That's content design, not engineering. Candidate topics from the seed itself: *CRDT internals, RAG architecture, Bluetooth mesh* — any of those works because the hackathon audience can verify the cards. (And the recursive humor of using *this project's own internals* as the demo topic is not nothing.)
