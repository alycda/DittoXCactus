# Why Gemma 4 (and the Gemma family) didn't land in this project

The Gemma family was seriously evaluated across three independent roles —
embedding model (EmbeddingGemma 300M), completion model (Gemma 3 1B IT /
Gemma 2 2B IT), and as a potential Gemma 4 upgrade path. It was passed over
for Qwen in every slot. The reasons fall into four categories.

---

## 1. Structured output quality collapse at <2B parameters

The StructEval benchmark data (cited in
[gemini-deep-research.md](../research/gemini-deep-research.md), source 10)
is the most damning finding. At parameter scales below 2B — which includes
Gemma-3-1B-it — models "frequently fail to output valid JSON or adhere
strictly to structured list formats unless guided by strict system prompts
or constrained decoding mechanisms." Qwen3-4B scores 67.04% on structured
output and Phi-4-mini hits 56.97%; Gemma-3-1B sits in the struggling tier.

This project needs reliable `Q:/A:/SOURCE:` formatted flashcard output from
the on-device model, and format-collapse was already the single biggest
quality problem with Qwen 2.5 1.7B (documented exhaustively in
[model-quirks.md](../notes/model-quirks.md) — format-collapse-to-prose at
n≥3, LaTeX `\boxed{}` drift, verbose-answer budget exhaustion). A model
that's *worse* at structural adherence was a non-starter.

---

## 2. Cactus SDK couldn't serve EmbeddingGemma

EmbeddingGemma 300M was the **original first-choice** embedding model — top
open <500M model on MTEB, <200MB RAM with quantization, sub-22ms on
EdgeTPU, Matryoshka dimensionality (128–768). The
[implementation plan](../plans/001-feat-mesh-rag-demo.md) (line 100) states:

> EmbeddingGemma 300M was attempted; the Cactus Flutter 1.3.0 catalog
> cannot fetch `qwen3-embedding-0.6` (download fails with "Failed to get
> model qwen3-embedding-0.6") and the dedicated embedding slugs the engine
> docs list are not yet resolvable by the Flutter SDK.

Three upstream issues document the SDK integration failures:

- [#33](https://github.com/cactus-compute/cactus-flutter/issues/33) —
  `isTelemetryEnabled` ignored by `getModel`/`fetchModels`/`fetchVoiceModels`
- [#34](https://github.com/cactus-compute/cactus-flutter/issues/34) —
  chat-tuned slugs accept `embed()` but fail at runtime with cryptic code
  `-2` instead of refusing at registration
- [#35](https://github.com/cactus-compute/cactus-flutter/issues/35) —
  purpose-built `qwen3-embedding-0.6` slug can't be resolved by the Flutter
  SDK 1.3.0 catalog despite being in the engine README

Even if Gemma's embedding quality was superior, there was no SDK path to
actually use it. The project fell back to `qwen3-0.6` as a chat-tuned model
that happens to expose an embedding head.

---

## 3. Licensing friction for a public hackathon repo

Pre-Gemma 4 models carry the **Gemma Terms of Use**, which prohibits using
model outputs to train competing language models and requires
redistribution notices. The [research](../research/claude.md) (line 226)
called this "annoying but permissive enough for a hackathon repo" — but
compared to Qwen's clean Apache-2.0, it was strictly worse for a public
hackathon demo.

Gemma 4's Apache-2.0 shift would have fixed this, but by the time it was
available, the Cactus SDK integration path was already blocked (§2 above),
and the project had already validated Qwen through the determinism harness
(U1/U13 — [baselines](../../tools/determinism_harness/baselines/latest/README.md)).

---

## 4. Gemma 4 wasn't available in Cactus's catalog at build time

The U16 alternate-model evaluation gate
([plan](../plans/001-feat-mesh-rag-demo.md), line 859) planned a systematic
5-model comparison including `gemma2:2b` via Ollama. But U16 was designed as
a **cuttable** unit — "sits between SEED cut-order items 4 and 5 — cut U16
before cutting R6a itself."

The project shipped with Qwen 2.5 1.7B and documented its quirks as
evidence for the writeup's specialists-thread future-work arc, rather than
spending time on a model swap that would need to clear:

- The **cosine-parity gate** (R2) — embedding determinism across iOS↔Android
- The **on-device quirks-portable check** — host-harness winners must also
  work on-device
- Re-tuning of `defaultMinScore=0.3`, `_kThinkBudget=512`, reasoning-leak
  markers, and stop sequences — all calibrated specifically for Qwen's
  behavior

---

## Summary

| Slot | Gemma candidate | Why it lost |
|------|----------------|-------------|
| **Embeddings** | EmbeddingGemma 300M | Cactus Flutter SDK can't resolve the slug (upstream #35); chat-tuned embed path crashes (upstream #34) |
| **Completion** | Gemma 3 1B IT | StructEval shows <2B models collapse on structured output; worse than Qwen 1.7B at the project's core task |
| **Completion** | Gemma 2 2B IT | Gemma Terms licensing friction vs. Apache-2.0; U16 eval gate was cut for time |
| **Upgrade path** | Gemma 4 | Apache-2.0 license fixed the legal issue, but SDK integration was still blocked; all pipeline tuning was already calibrated for Qwen |

---

## Thesis connection

The project's thesis arc actually *uses* these limitations as evidence.
[model-quirks.md](../notes/model-quirks.md) (line 269) states:
"format-collapse-under-load is the generalist tax." The writeup argues that
a **specialist** flashcard-generation model would have no "summary article"
mode in its training distribution, and Gemma's struggles at small scale are
one more data point supporting the specialists-vs-generalists thread.

---

## Sources (all committed artifacts)

- `_docs/research/gemini-deep-research.md` — StructEval benchmark data (source 10)
- `_docs/research/claude.md` — tool shortlist evaluation, licensing analysis
- `_docs/research/chatgpt-deep-research.md` — model comparison table
- `_docs/plans/001-feat-mesh-rag-demo.md` — Key Technical Decisions (embedding/LLM slug rationale), U16 evaluation gate
- `_docs/notes/model-quirks.md` — Qwen 2.5 1.7B on-device behavior catalog
- `_docs/notes/cactus-sdk-quirks.md` — SDK integration failures, upstream issues #33/#34/#35
- `lib/services/cactus_service.dart` — slug rationale comment (lines 1–21)
- `tools/determinism_harness/baselines/latest/README.md` — Qwen-pinned cosine-parity baselines
- GitHub Discussion #7 (referenced in cactus-sdk-quirks.md) — two-model architecture forced by embed() failure
