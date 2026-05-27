<!--
DRAFT — GitHub Discussion, category: Show and tell
Repo: alycda/DittoXCactus
Author: Alyssa
Date drafted: 2026-05-26

To post:
  gh discussion create --repo alycda/DittoXCactus \
    --category "Show and tell" \
    --title "Small-LLM eval for the mesh-RAG demo — and the precision dependence I didn't expect" \
    --body-file _docs/discussions/2026-05-26-small-llm-eval-precision-dependence.md

Or paste into the web UI after deleting this HTML comment block.

Pre-post checklist:
- [ ] Push the eval commits (bookmark `experiment/ollama-needle-eval`) so the
      file links resolve on github.com
- [ ] Sanity-check that links open the right files on the merged branch
- [ ] Add a screenshot of the t1-results.md table (optional, helps engagement)
- [ ] If posting to a private repo, decide whether to redact the supabase
      anon key (it's already in cactus-flutter's source, so probably fine)
-->

# Small-LLM eval for the mesh-RAG demo — and the precision dependence I didn't expect

This started as a side quest. The demo (the DittoXCactus mesh-RAG flashcard
thing — two phones, BLE/Wi-Fi, CRDT vector sync, on-device LLM generation,
no WAN) ships with two models pinned: Qwen3-1.7B for completion and a
chat-tuned Qwen3-0.6B for the embedding head. Both picks were made early,
under deadline pressure, and stuck. Before the writeup I wanted to *know*
whether they actually held up — not just on the demo's golden path, but
against the obvious alternatives. So: ollama harness for everything that
loads from there, Cactus CLI for the catalog, the same prompt as the
on-device pipeline, a small hand-labelled gold set, and Needle
(`cactus-compute/needle`, 26M tool-call specialist) as a qualitative
reference point for the writeup's specialists thread.

What I expected: maybe one small candidate would beat Qwen3-1.7B on grounding,
maybe nomic-embed-text would beat the chat-tuned head, maybe Needle would
look totally inapplicable, file the work, move on.

What I actually got: **the model choice barely matters compared to the
precision the model runs at, and the failure modes are different at different
quantization levels in ways that flip the verdict.** Writing this up because
two of the surprises are corrections to docs I shipped two days ago, and one
of them is the headline argument for the writeup's specialists thread.

## What the eval looks like

Four passes, same gold set:

- **T1 (ollama, completion).** Drives the *exact* prompt at
  `lib/prompts/flashcard_gen.dart` against 5 ollama-reachable candidates
  (`qwen3:1.7b` baseline, `qwen2.5:1.5b`, `qwen2.5:0.5b`, `gemma3:1b`,
  `llama3.2:1b`). 4 queries: 3 on-corpus + 1 off-corpus grounding test
  (empty retrieved → must output nothing per the in-prompt rule). Grades
  on format compliance, on-topic, off-source citations, and a quirk
  inventory drawn from
  [`model-quirks.md`](../notes/model-quirks.md).
- **T2 (ollama, embedding).** Same gold set, embedded via ollama's
  `/api/embed` against `nomic-embed-text`, `mxbai-embed-large`, and an
  attempted but-failed `qwen3:0.6b`. Recall@3, MRR, case-stability.
- **T1-Cactus.** Catalog completion models via Cactus CLI's Python bindings
  (after a `brew install cactus-compute/cactus/cactus` + one symlink to fix
  a packaging bug — see below): `qwen3-1.7`, `qwen3-0.6`, `lfm2-700m`,
  `lfm2.5-1.2b-instruct`, `gemma-3-1b-it`. Same prompt, same harness logic.
- **T2-Cactus.** Catalog embedders: chat-tuned `qwen3-0.6` (the demo's
  incumbent), `qwen3-embedding-0.6` (the dedicated slug), `nomic-embed-text-v2-moe`.

Full plan + verdicts: [`_docs/notes/ollama-eval-plan.md`](../notes/ollama-eval-plan.md).
Harnesses at [`tools/ollama_eval/`](../../tools/ollama_eval/). All ~200 lines
of Python, no dependencies beyond stdlib + the Cactus Python bindings the
brew formula installs.

## Surprise #1: a doc I shipped two days ago was already wrong

[`cactus-sdk-quirks.md`](../notes/cactus-sdk-quirks.md) claimed the dedicated
`qwen3-embedding-0.6` slug "doesn't load." That's why the demo uses the
*chat-tuned* `qwen3-0.6` and repurposes its embedding head — a workaround
for what I thought was a missing model.

T2-Cactus contradicted that on the first run:

```
[qwen3-embedding-0.6] init...
  init=0.1s, corpus embedded in 0.8s, dim=1024
  'inner planets': R@3=1/3 MRR=0.333 ...
```

It loads. It returns 1024-dim embeddings. It's the *best* of the three
Cactus embedders by mean R@3 (0.75 vs. 0.62 for nomic v2-moe and 0.38 for
the chat-tuned head). The "doesn't load" claim is either Flutter SDK
1.3.0-specific or has been fixed upstream since I wrote it. **If you're
running the Flutter SDK 1.3.x and the slug still fails, please drop a
comment — I'd love to know if the bug is real on your side too.**

## Surprise #2: the demo's incumbent embedder is bizarre at INT4

Same Python run, chat-tuned `qwen3-0.6` against the same 8 queries:

```
'inner planets':  top_lc=['Pluto', 'Neptune', 'Uranus']  case=DIFFERS (lc→Pluto / tc→Mars)
'outer planets':  top_lc=['Pluto', 'Neptune', 'Mercury']  case=DIFFERS (lc→Pluto / tc→Mars)
'the Sun':        top_lc=['Pluto', 'Uranus', 'Mercury']  case=DIFFERS (lc→Pluto / tc→Mars)
'gas giants':     top_lc=['Pluto', 'Neptune', 'Uranus']  case=DIFFERS (lc→Pluto / tc→Mars)
...
```

**Every** lowercase query has Pluto as top-1. **Every** title-cased query
has Mars as top-1. All 8 queries case-unstable. Mean R@3 = 0.38.

This is the model the on-device demo uses for retrieval. If the on-device
runtime behaved this way, the retrieval claim ("phone A asks about inner
planets, gets phone B's notes after merge") wouldn't survive a single demo
slide. So why does it work? Two reasons I can guess at but can't yet
verify:

1. **Quantization.** Cactus CLI defaults to `--precision INT4`. The Flutter
   SDK catalog reports `"quantization": 8` for every model (INT8 on-device).
   I tried to reconvert to INT8/FP16 to close the gap and hit a wall:
   `cactus download --precision INT8` fails with
   `Could not import module 'Qwen3ForCausalLM'` — the bundled transformers
   in the brew formula can't recognize Qwen 3's architecture. INT4 is the
   only locally-reproducible precision today.
2. **`retrieval_service.dart`'s title-casing workaround.** The on-device
   pipeline title-cases the query before embedding, on the explicit theory
   that the embedder is case-sensitive. T2-ollama with `nomic-embed-text`
   v1 shows this isn't a Qwen quirk — *5 of 8* queries change top-1 between
   lowercase and title-case, and the title-cased variants converge on
   `Mercury` as top-1 in nomic's space. So the workaround is empirically
   grounded across multiple model families and quantization levels.

The takeaway: **what looked like "Qwen is case-sensitive" might actually be
"small embedders trained on retrieval-style data are case-sensitive in
ways that interact non-trivially with quantization."** Not a quirk to
suppress; a property to design around.

## Surprise #3: at INT4, the incumbent completer fabricates on the
grounding test it passes at full precision

T1-ollama, Qwen3-1.7B at full precision, off-corpus query "Roman emperors":

```
[qwen3:1.7b] 'Roman emperors' (retrieved=0, tag=off-corpus) ...
  0.8s | cards=0  ✓ outputs nothing
```

T1-Cactus, the same Qwen3-1.7B at INT4, same query:

```
[qwen3-1.7] 'Roman emperors': 5.0s | cards=3 ...
> Q: What was the title of the emperor who reigned from 146 AD to 149 AD?
> A: Emperor Constantine the Great
> SOURCE: <id>
```

Constantine was emperor in the 4th century, not the 2nd. `SOURCE: <id>` is
literal placeholder text from the prompt. The model is hallucinating — not
just facts, but the *format* of its own citation field.

This was the most uncomfortable result. The demo's grounding claim ("no
fabrication on off-corpus") is precision-dependent, and the precision
dependence is *not flagged* anywhere in the demo. The on-device INT8 path
hasn't shown this failure in practice, but I couldn't reproduce that
behaviour on a Mac.

## Surprise #4: bilingual training-distribution leak shows up across vendors

We already had Qwen 2.5's CJK drift documented — Chinese characters
appearing inside `<think>` blocks because Qwen's reasoning training
distribution is bilingual. I'd assumed this was Qwen-specific. T1-Cactus,
Gemma 3 1B at INT4 on "outer planets":

```
Q: Neptune's distance from the Sun is?
A: 30 astronomical units.
...
<end_of_turn>最后一个用户
<end_of_turn>最后一个用户
<end_of_turn><end_of_turn><end_of_turn>
```

`最后一个用户` is Chinese for "last user." Gemma 3 1B at INT4 leaks
Chinese-language chat-template tokens after generation completes. *Same
training-distribution leak, different vendor.* Quantization stress seems
to surface it where full precision suppresses it. Probably the most
photogenic single result for the writeup's specialists thread — it's a
clean demonstration that generalists smuggle their training distribution
into outputs whenever the inference pressure increases.

## What the eval verdict turned out to be

**The model choice does not change.** Qwen3-1.7B + Qwen3-0.6 stay as the
demo defaults. Not because nothing else was tested — eight ollama
candidates and seven Cactus candidates were — but because:

- At full precision (ollama), none of the smaller candidates passed the
  off-corpus grounding test. Qwen3-1.7B and Qwen2.5-1.5B were the only
  models that obeyed the "output nothing" rule.
- At INT4 (Cactus CLI), the picture flipped in ways that *no model passed
  cleanly*: Qwen3-1.7B fabricated, LFM2-700M passed off-corpus by accident
  (never emitting a `SOURCE:` line), and Gemma 3 1B leaked Chinese tokens.
- The dedicated `qwen3-embedding-0.6` slug *does* load via Cactus and
  outperforms the chat-tuned head at INT4 (R@3 0.75 vs. 0.38), but still
  loses to ollama's nomic-embed-text v1 at full precision. Whether it
  beats the incumbent at INT8 on-device is the unanswered question — I
  can't currently produce INT8 locally.

So the *headline* finding for the writeup is the one I didn't expect:
**precision is a thesis-relevant axis.** "The demo runs on-device" implies
"the demo runs at INT8," and that's a load-bearing detail the eval makes
visible. The writeup's specialists thread now has a concrete sub-argument:
*small generalists' failure modes depend on quantization, and you can't
read off "small + on-device + reliable" from any one of those properties
alone.*

## What I want comments on

- **Cactus folks:** the Flutter SDK 1.3.x dedicated-embedder bug — still
  real? The CLI 1.14 loads it fine. If it's fixed in flutter 1.4 I'd love
  to know.
- **Cactus folks again:** the `Could not import module 'Qwen3ForCausalLM'`
  error on `cactus download --precision INT8` is the only path I found to
  produce non-INT4 weights locally. Is there a recommended workaround for
  Mac users who want to reproduce eval results closer to on-device
  precision?
- **Anyone running small LLMs on edge:** is the "bilingual training-leak
  surfaces under quantization stress" pattern something you've also seen
  across vendors? Curious whether this is a real cross-cutting phenomenon
  or just an artifact of the two models I happened to test.
- **Anyone with stronger ground-truth retrieval golds for solar-system
  notes:** the eval's gold set is 8 queries hand-labelled from 10 seed
  notes. Small N, noisy. If anyone wants to throw a richer gold set at
  the same harness, I'd publish the diff.

## Where to look

- Eval plan + verdicts: [`_docs/notes/ollama-eval-plan.md`](../notes/ollama-eval-plan.md)
- Harnesses: [`tools/ollama_eval/`](../../tools/ollama_eval/) (4 files,
  each ~200–400 lines of stdlib Python)
- Raw outputs: [`t1-results.md`](../notes/t1-results.md),
  [`t2-results.md`](../notes/t2-results.md),
  [`t1-cactus-results.md`](../notes/t1-cactus-results.md),
  [`t2-cactus-results.md`](../notes/t2-cactus-results.md)
- Existing model-quirk catalogue this eval extended:
  [`model-quirks.md`](../notes/model-quirks.md),
  [`cactus-sdk-quirks.md`](../notes/cactus-sdk-quirks.md)
- The thing that inspired the whole detour: [Needle](https://github.com/cactus-compute/needle)
  (cactus-compute, 26M function-call specialist distilled from Gemini 3.1)

Deferred: **TinyLlama / TinyDolphin via the C++ route.** Cactus's engine
recognizes `tinyllama` at the model_type level
(`engine_model.cpp:548` maps it to `ModelType::GEMMA4`), but it's not in
the catalog. Loading custom GGUF would bypass `cactus download` entirely.
Planned as a follow-up.
