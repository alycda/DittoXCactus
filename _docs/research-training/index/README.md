# Semantic index — Mesh RAG specialists-thread research

This directory is the Reduce-phase synthesis of six worker outputs that researched the brief at [`_docs/RESEARCH-BRIEF-training.md`](../../RESEARCH-BRIEF-training.md). The brief scopes thread (1) of the writeup's closing arc: *what would it take to ship a fine-tuned specialist small model (≤2B params) into Cactus on two phones, on a hackathon budget.*

This is not the demo's prior-art index — that lives at [`_docs/research/index/`](../../research/index/) and covers Stage 0/1 (CRDT vector sync, retrieval, streaming generation). This index covers the specialists future-work thread only.

## What's in this index

- `README.md` (this file) — entry point
- `top-N.md` — 17 ranked must-read sources for a writeup + an engineer building the recipe
- `clusters.md` — thematic clusters mapped to brief tasks T1–T7
- `by-topic.md` — flat topic → sources lookup
- `open-questions.md` — named verdicts and prior-art gaps
- `cross-references.md` — source → source citation graph
- `recipe.md` — *parent directory, not in `index/`* — the opinionated build recommendation. See [`../recipe.md`](../recipe.md).

## The five things to know before reading anything else

1. **Cactus does NOT support runtime LoRA adapter loading.** The only supported path is `cactus convert <base> <out> --lora <adapter>`, which merges the adapter into a single `.cact` blob at convert time. There is no `set_lora`-style API, no `--lora` runtime flag, and no public roadmap item. This is the load-bearing engineering verdict; the whole recipe shape follows from it. (Cactus moved off GGUF / off llama.cpp at v1 in Dec 2025 — it now runs proprietary ARM-SIMD kernels on a `.cact` format and cannot inherit upstream llama.cpp adapter work.)

2. **Apple Foundation Models and MediaPipe LLM Inference DO support runtime LoRA loading.** Apple ships rank-16 `.fmadapter` packages (~160 MB each), dynamically loaded + cached + swapped. MediaPipe supports runtime LoRA on GPU backend for Gemma/Phi-2. This is the cleanest framing for the writeup — Cactus is structurally behind on the multi-specialist-per-device thesis, but the runtime architecture has been proven at production scale on competing stacks.

3. **The Oxen.ai Qwen3-1.7B text-to-SQL case study is the closest published recipe to what we'd build.** SFT on ~5,000 examples, single A10G GPU, 10–12 min wall-clock, Gemini-as-judge eval on 200 examples. Qwen3-1.7B hit 57% vs GPT-4o's 45%. End-to-end on Oxen's Marimo notebooks. **Caveat:** Oxen does NOT do GGUF / `.cact` export as a first-class output — you take the safetensors and convert yourself.

4. **The license-clean recipe is Apache-2.0 end-to-end: Qwen 3 base + open-weight teacher (Qwen-72B / Llama-3-70B / DeepSeek-R1) for synthetic data + Unsloth trainer + merged `.cact`.** Avoid OpenAI / Anthropic / Google API outputs as training data — their TOS prohibits training competing models, and the DeepSeek controversy is the public test case. Cactus itself is source-available with a $2M revenue gate, which is fine for the hackathon repo but worth disclosing to the writeup audience.

5. **Tether's QVAC Fabric proved on-device LoRA *training* on Adreno 830 / Mali-G715 / Apple Silicon in Dec 2025** (Apache 2.0, llama.cpp fork). 13 hr wall-clock for 8 epochs of Qwen3-1.7B Q8 on a Pixel-class phone. Not a Cactus integration, but the existence proof that the writeup's "specialists evolve on-device" future-work thread is now operationally credible at the edge.

## A note on the absence of `_per_source/`

The original demo research had 281 per-source files because the workers ran a Map phase that produced shallow catalog entries plus six longer worker outputs that did the actual analysis. This brief is shorter and the **six source files at the parent directory level *are* the per-source analysis** — they read each citation at brief-execution time, not at index-build time. There is no Map phase to summarize.

Read the workers directly when you need primary-source depth:

- [`../theory.md`](../theory.md) — academic papers (PEFT lineage, distillation methods, judge-LLM bias literature)
- [`../tooling.md`](../tooling.md) — framework docs (Cactus, Unsloth, PEFT, distilabel, llama.cpp, MLC, Oxen core)
- [`../industry.md`](../industry.md) — case studies (Apple Intelligence, Pixel Recorder, LoRA Land, OpenPipe, QVAC Fabric)
- [`../claude-deep-research.md`](../claude-deep-research.md) — Claude.ai hosted DR pass
- [`../chatgpt-deep-research.md`](../chatgpt-deep-research.md) — ChatGPT hosted DR pass
- [`../gemini-deep-research.md`](../gemini-deep-research.md) — Gemini hosted DR pass (longest; covers training math + quantization-clipping risk in depth)

## What's downloaded under `_inspiration/`

The downloads manifest at [`../downloads.yaml`](../downloads.yaml) lists 258 URLs across all six worker outputs, tagged with `cited_in` so cross-cutting picks are recoverable. 28 sources are cited by ≥2 workers — those are the consensus picks ranked in [`top-N.md`](top-N.md). Materials are downloaded under `_inspiration/` (gitignored per repo convention; only `.gitignore` is tracked).
