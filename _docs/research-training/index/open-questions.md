# Open questions and named verdicts

Where the workers reached a definitive answer, the entry leads with **VERDICT:**. Where prior art doesn't yet answer, the entry leads with **GAP:** and proposes the next action.

---

## 1. VERDICT: Cactus + LoRA at runtime — **NO. No public roadmap.**

Confirmed independently by tooling, industry, claude-DR, chatgpt-DR, and gemini-DR (5/6 workers; theory worker flagged it as out of academic scope but didn't contradict).

**Primary evidence:**
- `docs/finetuning.md` shows the supported path is `cactus convert <base> <out> --lora <adapter>` — merge-at-convert-time only.
- `docs/cactus_engine.md` confirms `cactus_init(model_path, corpus_dir, cache_index)` has no adapter slot. No `set_lora`-style API exists.
- Cactus v1 (Dec 2025) moved off GGUF to a proprietary `.cact` format and is no longer a llama.cpp wrapper — so Cactus cannot inherit upstream llama.cpp adapter work (`--lora` flag, `/lora-adapters` hot-swap, `convert_lora_to_gguf.py`).
- Cactus GitHub issue tracker (12 open issues as of 2026-05-28) has **no open issue, PR, or roadmap item for LoRA runtime loading or multi-adapter support**.
- Roman Shemet's HF post and the Cactus team's HN Launch and Show-HN posts position Cactus as latency/privacy/cost; LoRA, adapters, fine-tuning, multi-model swap are not mentioned anywhere.

**Operational implication:** one specialist per `.cact` blob. Multi-specialist = multiple full `.cact` files + model-switch at the app layer (cold load, ~seconds, not LoRA hot-swap ~ms). Or migrate the demo's runtime to MLC LLM / llama.cpp / MediaPipe — each with non-trivial integration cost.

**Writeup phrasing recommendation:** "Today, one specialist per `.cact` blob. Multi-specialist-per-device is a future-work item that depends on either Cactus shipping runtime LoRA or a runtime migration."

---

## 2. VERDICT: Distilabel staleness — **YES, ~16 months stale. Fallback to Augmentoolkit or Magpie reference repo.**

distilabel v1.5.3 last released January 2025. As of brief execution (2026-05-28), no v1.6.x. Tooling worker flags this as a yellow flag; industry worker independently confirms.

**Recommended replacements:**
- **Augmentoolkit** (`github.com/e-p-armstrong/augmentoolkit`) — MIT, v3.0 June 2025, document-in/dataset-out, runs local. Preferred if keeping seed corpus off cloud APIs matters.
- **Magpie reference repo** (`github.com/magpie-align/magpie`) — for the synthesis recipe itself; no pipeline harness but the technique is the canonical implementation.

**Next action:** verify distilabel project health (commits since v1.5.3) on the repo's commits page before committing the recipe to it. If commit cadence has resumed, distilabel is still preferable; otherwise default to Augmentoolkit.

---

## 3. GAP: Note-merging eval — **no benchmark exists. We'd be inventing.**

All workers confirm: there is no off-the-shelf "two short study notes about the same entity, merge without claim loss or duplication" benchmark.

**Adjacent eval anchors that could partly substitute:**
- **MultiNews** (`arxiv.org/abs/1906.01749`) — multi-document news summarization; long-summary format mismatch.
- **WikiSum** (`huggingface.co/datasets/d0rj/wikisum`) — article summarization from references.
- **RAGTruth** (`arxiv.org/abs/2401.00396`) — 18k word-level hallucination corpus; eval anchor for faithfulness, not training data.
- **SummEval** (`arxiv.org/abs/2007.12626`) — re-evaluates summarization metrics against human judgments.
- **RAGAS** (`arxiv.org/abs/2309.15217`) — faithfulness + answer relevance + context precision/recall.

**Recommendation:** build our own. Shape — ~100 hand-curated (note-A, note-B, ground-truth-merged-note) triples + cross-family LM judge + IFEval-style verifiable constraints (length budget, claim count, citation presence). The 100-pair hand-curated set is the load-bearing artifact; the synthetic eval is the surface metric. The benchmark + writeup of the benchmark could itself be a standalone contribution from this hackathon.

---

## 4. GAP: ≤2B SFT-vs-DPO-vs-ORPO-vs-KTO bake-off — **absent from the literature.**

ORPO's own ablation is at 2.7B+; KTO scales to 30B but doesn't isolate the ≤2B regime. No paper does a clean bake-off at our exact scale on a single narrow task. We'd be inventing the recipe.

**Defensible default:** SFT-only on note-merging (single correct output, not preference-style). Reach for ORPO only if eval shows a style/format gap. Don't reach for full DPO unless the preference signal is rich and ORPO's single-pass framing fails.

**Mild worker disagreement to flag:** Gemini DR claims "DPO significantly outperforms SFT on subjective reasoning, multi-document summarization, and task-specific instruction following." This appears to overgeneralize from preference-method literature on chat-style tasks. Note-merging has correct outputs, not preference structure. Trust theory + claude-DR + industry on this point.

---

## 5. GAP: Fine-tuned-weight cross-platform parity — **unaddressed in the literature. Bears on R2 holdout.**

The Thinking Machines determinism work and the project's existing R2 cross-platform parity harness cover *base-model* determinism. **No published study on whether LoRA deltas — particularly at high alpha — amplify floating-point divergence across iOS / Android kernel paths.**

**Why this matters:** the demo's R2 holdout requires cosine parity across platforms for the embedder. The post-fine-tune embedding path is the same as the base; but the completion path is the new specialist. If LoRA-rank-16 perturbations at machine-epsilon magnitudes land on cross-platform-divergent kernel paths under Cactus's ARM-SIMD stack, the parity invariant could fail post-fine-tune.

**Next action (trivial to test):** re-run the existing determinism harness against any candidate merged `.cact` model before committing to a release. If parity holds at base + holds at fine-tune, ship. If parity holds at base + fails at fine-tune, the writeup gets a paragraph: "we hit cross-platform divergence on the specialist's completion path; here's the fix" — that's a writeup-worthy artifact in itself.

---

## 6. GAP: Multi-adapter-per-`.cact`-blob — **Cactus roadmap UNKNOWN.**

The Cactus v1 InfoQ feature mentions a Flutter-SDK-only "RAG fine-tuning" capability that is undocumented in the engine docs. Could be a different surface than the LoRA-merge path. Could be a user-data continual-personalization mode. Could be unrelated.

**Next action:** direct maintainer outreach (Discord or GitHub Discussions) if this becomes blocking. Not surfaceable from primary docs.

---

## 7. GAP: Oxen.ai → Cactus end-to-end — **no public writeup exists.**

Both halves work; nobody has written the bridge.

The bridge is short: `oxen pull` the safetensors adapter from a branch → `cactus convert <base> <out> --lora <adapter>`. Two commands. Writing it up — as a small standalone artifact from this hackathon — could fill a hole in the prior-art literature. Suggested deliverable: a `tools/oxen-to-cactus/` directory with a runnable script + a 1-page blog post.

The closest existing reference is **Ollamox** (`github.com/Oxen-AI/Ollamox`) — which does Oxen → safetensors merge → GGUF, but stops at llama.cpp / Ollama. Our extension is the `cactus convert` step.

---

## 8. GAP: Quantization-induced activation clipping on fine-tuned models — **practitioner-known, unmeasured.**

Gemini DR raises this with specific concern about Cactus's `.cact` Q4_K_M-equivalent quantization: fine-tuning on strict structured tasks teaches the model to rely on extreme weight values. Standard PyTorch training uses 32-bit accumulation to handle the resulting activation spikes; quantizing to 4-bit can clip the spikes, causing garbled output. This is empirically observed (cited issue: `github.com/cactus-compute/cactus/issues/503` "FunctionGemma FP16 issues") but not systematically measured.

**Next action:** validate the merged `.cact` model against a held-out perplexity test before mobile compilation. If quality degrades >5 points vs the unquantized merged checkpoint, lower the adapter rank (try r=8) and/or apply conservative training learning rates and/or quantize to INT8 instead of INT4. Gemma 3 specifically is named as problematic due to its RMSNorm scale — Qwen 3 may behave better.

---

## 9. VERDICT: Apple Foundation Models + MediaPipe DO support runtime LoRA — **the cleanest counter-case for the writeup.**

This is the comparison that frames the writeup's specialists thread:

| Property | Cactus v1 | Apple Foundation Models | MediaPipe LLM Inference | llama.cpp |
|---|---|---|---|---|
| Base format | `.cact` | system on-device LLM | `.tflite` flatbuffer | GGUF |
| Adapter format | merged into `.cact` | `.fmadapter` (~160 MB) | LoRA → flatbuffer | GGUF LoRA |
| Runtime adapter loading | **no** | **yes** (dynamically loaded + cached + swapped) | **yes** on GPU backend | **yes**, `/lora-adapters` |
| Multi-specialist on one device | one `.cact` per specialist | many adapters, one base | multiple adapters, one base | many adapters, one base |

**The contrast worth naming:** Apple Intelligence ships runtime-adapter swap at billion-user scale today. MediaPipe ships it for Gemma/Phi-2 on Android GPU. Cactus is structurally behind on this dimension. The writeup's specialists thread should explicitly cite Apple as proof that the architecture works; that lets the future-work paragraph be "Cactus needs to catch up or we migrate."

---

## 10. GAP: Cactus license clarity for the writeup audience — **not a research gap; a disclosure question.**

Cactus is source-available with a $2M revenue gate, not Apache. Fine for a hackathon repo. The writeup audience includes people at larger orgs who will read this and assume Apache-like terms. **Recommendation:** one explicit sentence in the writeup — "Cactus is source-available, not Apache; check the threshold for commercial use."

---

## 11. GAP: Specialist-vs-generalist evidence at small scale is brittle — **named in the writeup, not researched away.**

The case-for is strong (LoRA Land, DeepSeek-R1-Distill-1.5B, Apple Intelligence, Pixel Recorder). The case-against is also real:

- **Small Model Learnability Gap** (`arxiv.org/abs/2502.12143`) — ≤3B students don't consistently benefit from large-teacher long-CoT distillation.
- **Tiny Titans** (`arxiv.org/abs/2402.00841`) — most compact models, even after fine-tuning, fail to outperform larger zero-shot models on meeting summarization. (FLAN-T5-Large 770M is the exception.)
- **OpenMedLM** — prompt-engineering beat fine-tuned medical specialists on USMLE-style benchmarks.
- **OpenPipe HN postmortem methodological pushback** — when comparisons are fair (matched temperature, fresh eval set), the specialist premium is consistently weaker than blog headlines suggest.
- **Catastrophic forgetting** — narrow fine-tuning erodes base general competence; LoRA's "forgets less" property is the saving grace (Biderman 2024) but doesn't eliminate it.

The writeup must name both sides. Synthesis for the writeup: specialization wins when (a) task has clear correct outputs (extraction, structured generation, summarization with rubric), (b) the specialist is LoRA not full-FT, (c) eval is fair (matched temperature, fresh eval set, cross-family judge calibration). All three hold for note-merging framed narrowly. The case is weakest when the task drifts toward open-ended composition.

---

## 12. GAP: On-device specialist evolution / continual personalization — **gestured at by QVAC Fabric, not productionized anywhere.**

QVAC Fabric proves on-device LoRA training is feasible (13 hr for 8 epochs on a Pixel-class phone). No production app does it. This would underwrite the writeup's "generational evolution" future-work thread but is well beyond the demo's scope. Worth a citation in the writeup, not a build action.
