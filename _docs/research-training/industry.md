---
internal_only: false
perspective: industry
brief: _docs/RESEARCH-BRIEF-training.md
authored: 2026-05-28
audience: LoRA-curious, not LoRA-fluent
sibling_files: theory.md, tooling.md
---

# Industry perspective — Small-Model Post-Training for Mesh RAG

This file is the **industry** slice of a multi-perspective research pass on `RESEARCH-BRIEF-training.md`. Scope: engineering blog posts, conference talks, postmortems, shipped-product case studies, vendor announcements, license interpretation in the wild, practitioner gotchas. Arxiv papers go to `theory.md`; framework docs and repo internals go to `tooling.md`. This file restricts itself to "what have teams who actually shipped a fine-tuned small model on mobile/edge said about doing it."

This research **builds on** two sibling-worker verdicts that already resolved load-bearing engineering questions:

- **Cactus does NOT support runtime LoRA adapters** (tooling worker). The supported path is `cactus convert <base> --lora <adapter>` to produce a merged `.cact` blob. Multi-specialist = multi-blob, not multi-adapter. Confirmed independently below via the Cactus fine-tuning doc and the engine README.
- **Oxen.ai = OSS data-versioning core + hosted SaaS** with Marimo notebooks + serverless GPU; H100 ~$4.87/hr; full Qwen3-1.7B SFT-to-deployable runs in 10–12 min on a single A10G (tooling worker). GGUF / `.cact` export is bring-your-own.

Industry signal mostly *contrasts* Cactus's merge-only stance against Apple Intelligence's runtime-swappable adapter framework and Google's MediaPipe LLM Inference API GPU runtime LoRA — that contrast is the single most useful framing the industry layer adds to the writeup. Sections below pin it concretely.

---

## 1. Top must-read industry sources

Ranked by load-bearing-ness for an engineer planning to ship a specialist 0.5B–2B model on mobile.

1. **Apple Machine Learning Research — *Introducing Apple's On-Device and Server Foundation Models*** (June 2024) ([machinelearning.apple.com/research/introducing-apple-foundation-models](https://machinelearning.apple.com/research/introducing-apple-foundation-models)). The reference design for "ship a 3B base + many task-specific LoRA adapters that swap at runtime." Rank-16 adapters, 10s of MB each, "dynamically loaded, temporarily cached in memory, and swapped — giving the foundation model the ability to specialize itself on-the-fly for the task at hand." This is the architecture Cactus *doesn't* do and the writeup's specialists thread should explicitly cite as the production proof-of-life that runtime-adapter swap is operationally sound on phones.

2. **Apple Developer — *Foundation Models adapter training*** (WWDC25, [developer.apple.com/apple-intelligence/foundation-models-adapter/](https://developer.apple.com/apple-intelligence/foundation-models-adapter/)). The how-to companion. Concrete recipe: Python 3.11+, Jupyter + CLI, JSONL `{"role","content"}` chat-format data, **100–1,000 samples for basic tasks / 5,000+ for complex**, 5 epochs at 1e-3 LR, batch 4. Output: a `.fmadapter` package ~160 MB; not bundled in the app — hosted on a server and downloaded via Background Assets framework. Critical pin: **each adapter is compatible with one specific OS version** — adapter-training is on the OS-update treadmill. Hardware: Apple-silicon Mac with ≥32 GB RAM or Linux GPU.

3. **Apple Intelligence Foundation Language Models Tech Report 2025** ([arxiv 2507.13575](https://arxiv.org/abs/2507.13575), [machinelearning.apple.com/research/apple-foundation-models-tech-report-2025](https://machinelearning.apple.com/research/apple-foundation-models-tech-report-2025)). 3B on-device base + server-side PT-MoE. The 3B uses 2-bit quantization-aware training + KV-cache sharing for a 37.5% memory reduction. Rank-16 LoRA "accuracy-recovery adapters" trained to claw back ~4.6% MGSM / +1.5% MMLU after compression. Names the adapter ranks they ship in dev tooling: **{8, 16, 32}** — useful when picking rank for a hackathon recipe (16 is the documented sweet spot for inference latency vs quality).

4. **Android Developers Blog — *The Recorder app on Pixel sees a 24% boost in engagement with Gemini Nano-powered feature*** (August 2024, [android-developers.googleblog.com/2024/08/recorder-app-on-pixel-sees-boost-in-engagement-with-gemini-nano.html](https://android-developers.googleblog.com/2024/08/recorder-app-on-pixel-sees-boost-in-engagement-with-gemini-nano.html)). The Pixel Recorder case study: Google fine-tuned Gemini Nano with a custom LoRA adapter to produce three-bullet summaries with speaker names, key takeaways, and themes. After release, **2–5 daily uses per user** and **+24% saved recordings**. The clearest production proof that "adapter-specialized base for a narrow task" wins user engagement, not just benchmark numbers. The user-facing summarization is structurally adjacent to our note-merging task.

5. **Chrome for Developers — *Enhancing Gemini Nano: delivering higher quality summaries with LoRA*** ([developer.chrome.com/blog/improved-summaries-gemini-nano](https://developer.chrome.com/blog/improved-summaries-gemini-nano)). Google's own blog on the Gemini Nano summarization LoRA. Companion to the Pixel Recorder post but with browser-side detail; useful as a second data point that LoRA-on-base is Google's standard playbook for shipping Gemini Nano features.

6. **MediaPipe LLM Inference Guide — Android with LoRA** ([ai.google.dev/edge/mediapipe/solutions/genai/llm_inference/android](https://ai.google.dev/edge/mediapipe/solutions/genai/llm_inference/android)). The publicly-available developer surface that backs the Pixel Recorder story for non-Google apps. Supports LoRA at runtime on the **GPU backend** for Gemma-2 2B / Gemma 2B / Phi-2; LoRA must target only attention layers (`q_proj`, `v_proj`, `k_proj`, `o_proj`). Base model in safetensors, then convert to Flatbuffer. **This is the most direct industrial counterpoint to Cactus's merge-only constraint** — there is a competing on-device runtime that does runtime LoRA today.

7. **Predibase — *LoRA Land: Open-Source LLMs That Beat GPT-4*** (Feb 2024, [predibase.com/blog/lora-land-fine-tuned-open-source-llms-that-outperform-gpt-4](https://predibase.com/blog/lora-land-fine-tuned-open-source-llms-that-outperform-gpt-4)). 25 task-specialized Mistral-7B LoRAs, **~$8 per fine-tune average, served from one A100 via LoRAX**, beat GPT-4 by 4–15% on their narrow tasks. The single clearest data point for the writeup's specialists thread. Sibling theory worker cites the arxiv version; this blog post is the operationally-detailed one and is the right link for the writeup.

8. **OpenPipe — *Fine-tuning Best Practices*** series ([openpipe.ai/blog](https://openpipe.ai/blog)). Practitioner-grade postmortem of "replace this GPT-4 prompt with a fine-tuned small model" patterns. OpenPipe's framing: drop-in OpenAI SDK wrapper → captures prompt/response pairs in production → fine-tunes a per-prompt model. **Fine-tuned 7B routinely matches GPT-4 on the captured task** per their judge-LLM evals; 50× cost reduction is the canonical number. The "every prompt becomes its own specialist" pattern is structurally close to our note-merging-as-its-own-specialist framing.

9. **Hamel Husain — *Is Fine-Tuning Still Valuable?*** ([hamel.dev/blog/posts/fine_tuning_valuable.html](https://hamel.dev/blog/posts/fine_tuning_valuable.html)) and ***Your AI Product Needs Evals*** ([hamel.dev/blog/posts/evals/](https://hamel.dev/blog/posts/evals/)). Hamel argues fine-tuning excels at **syntax / style / rules**, while RAG handles facts/context. Worked examples: Honeycomb Query Assistant (replaced syntax docs in the prompt with a fine-tune); ReChat's Lucy (idiosyncratic formatting for dynamic-UI rendering). Critical practitioner mistake he names: attempting fine-tuning without an eval system. Maps cleanly to our T6 — eval before training.

10. **HuggingFace blog — *QVAC Fabric: an edge-first LLM LoRA fine-tuning framework*** (Tether Data, Dec 2025, [huggingface.co/blog/qvac/fabric-llm-finetune](https://huggingface.co/blog/qvac/fabric-llm-finetune)). The first public on-device *training* (not just inference) of LoRA adapters on Adreno / Mali / Apple-silicon GPUs via a llama.cpp fork. Wall-clock: Qwen3-1.7B Q8, 8 epochs = 45 min on RTX 4090, 13 hr on Adreno 830. Doesn't run in Cactus, but proves "the phone can fine-tune itself" is feasible enough to be in the writeup's future-work arc (preference-aware merge requires some on-device learning).

11. **Predibase — *Serve 100+ Fine-Tuned LLMs with LoRA Exchange on One GPU*** ([predibase.com/blog/lora-exchange-lorax-serve-100s-of-fine-tuned-llms-for-the-cost-of-one](https://predibase.com/blog/lora-exchange-lorax-serve-100s-of-fine-tuned-llms-for-the-cost-of-one)). The architecture explainer for LoRAX (dynamic adapter loading + tiered caching + continuous multi-adapter batching). Useful as the "server-side template for the on-device adapter swapper Cactus doesn't have yet" — the same shape, just at the device level. Also the foundation for Convirza's 60-adapter production setup ([zenml.io/llmops-database/multi-lora-serving-for-agent-performance-analysis-at-scale](https://www.zenml.io/llmops-database/multi-lora-serving-for-agent-performance-analysis-at-scale)).

12. **Oxen.ai blog — *How to Fine-Tune Qwen3 on Text2SQL to GPT-4o level performance*** ([ghost.oxen.ai/how-to-fine-tune-qwen3-to-gpt-4o-level-performance/](https://ghost.oxen.ai/how-to-fine-tune-qwen3-to-gpt-4o-level-performance/)). The Oxen-shaped recipe, end-to-end: Marimo notebook + serverless A10G, 5,000 filtered SQL examples (wikisql + spider + sql_create_context + nvbench), 10–12 min wall-clock, Gemini-as-judge on 200 examples. Qwen3-1.7B SFT hit 57% vs GPT-4o's 45%. Gap explicitly named: **no GGUF/Cactus conversion step is shown** — Oxen ships the safetensors back to a branch and stops. Bring-your-own conversion remains the seam.

13. **Cactus team — InfoQ feature** ([infoq.com/news/2025/12/cactus-on-device-inference/](https://www.infoq.com/news/2025/12/cactus-on-device-inference/)) and **Roman Shemet's HuggingFace post** ([huggingface.co/blog/rshemet/cactus-on-device-inference](https://huggingface.co/blog/rshemet/cactus-on-device-inference)). The team's own public framing of Cactus v1. Notable for what they *don't* discuss: no mention of runtime LoRA, dynamic adapters, multi-model swap, or any roadmap item for adapter loading. The .cact migration is justified as "battery efficiency + zero-copy mmap"; the LoRA story is exclusively merge-at-convert-time.

---

## 2. Per-topic findings

### T1. Oxen.ai's surface area and training pipeline (industry view)

The tooling worker already established the platform shape (open-source Rust DVC + hosted Marimo + serverless GPU). What industry adds: **Oxen is positioning itself around the "Fine-Tuning Fridays" small-model bake-off series** ([ghost.oxen.ai/fine-tuning-fridays/](https://ghost.oxen.ai/fine-tuning-fridays/)) — pitting fine-tuned ≤3B open models against frontier closed models on narrow tasks. Documented episodes:

- **Text2SQL (Qwen3-0.6B)** vs GPT-4.1 — Qwen3 won. May 2025.
- **Rust Coder LM** (1.5B, GRPO) — Mar 2025. RL-tuned for Rust code generation.
- **FLUX.1-dev LoRA** — image gen, June 2025 (not relevant to us; flagged for completeness).
- **PixArt Character Consistency** — diffusion, June 2025 (not relevant).
- **Qwen3-VL $1 fine-tune beat Gemini 3** ([ghost.oxen.ai/how-a-1-qwen3-vl-fine-tune-beat-gemini-3/](https://ghost.oxen.ai/how-a-1-qwen3-vl-fine-tune-beat-gemini-3/)) — single-dollar cost claim, vision task.

The pattern across these is consistent: a 1B–4B Qwen base + SFT on 1k–5k curated examples + judge-LLM eval on a few hundred → beat the closed-source generalist on the narrow task. **For our note-merging specialist, this is the closest published recipe shape.** Customer success framing on Baseten ([baseten.co/resources/customers/from-datasets-to-deployed-models-how-oxen-ai-builds-on-baseten/](https://www.baseten.co/resources/customers/from-datasets-to-deployed-models-how-oxen-ai-builds-on-baseten/)) confirms Oxen partners with Baseten for the training-compute layer — Oxen owns the dataset/version-control + UI; Baseten owns the GPU.

**Gap:** the Fine-Tuning Fridays archive doesn't include a summarization, note-merging, or RAG-grounded-generation episode, and no public Oxen.ai → GGUF → mobile pipeline writeup exists. We'd be wiring the conversion step ourselves.

### T2 / T3. Shipped specialist fine-tunes (the case studies)

**The most-cited example: Predibase LoRA Land.** ([predibase.com/blog/lora-land-fine-tuned-open-source-llms-that-outperform-gpt-4](https://predibase.com/blog/lora-land-fine-tuned-open-source-llms-that-outperform-gpt-4) — 25 Mistral-7B LoRAs at $8 average, beat GPT-4 by 4–15%, all served from one A100 via LoRAX. The expanded 310-LoRA bake-off blog ([predibase.com/fine-tuning-index](https://predibase.com/fine-tuning-index)) sweeps base size × task; the headline is **LoRA at small scale is consistently competitive with closed frontier models on narrow tasks**.

**OpenPipe HN postmortem** ([news.ycombinator.com/item?id=40843848](https://news.ycombinator.com/item?id=40843848)). A developer fine-tuned Llama-3 8B / Mistral-7B / Solar-10.7B / GPT-3.5 on structured-data extraction from ISAF press releases. Fine-tuned 7B outperformed GPT-4 on the task. **The HN counter-arguments are useful**: (a) GPT-4 was tested at temperature=1 not 0, biasing the comparison; (b) reviewers found labeling inconsistencies that may indicate eval-set contamination; (c) the OpenPipe founder himself acknowledged "data extraction is a use case that fine-tuned models are fantastic at" — i.e., specialization wins predictably on extraction-shaped tasks, less obviously on others.

**Llama 3.2 1B for query routing** ([towardsdatascience.com/i-fine-tuned-the-tiny-llama-3-2-1b-to-replace-gpt-4o-7ce1e5619f3d/](https://towardsdatascience.com/i-fine-tuned-the-tiny-llama-3-2-1b-to-replace-gpt-4o-7ce1e5619f3d/)). Free Colab + Unsloth → 1B model trained on "a few million tokens" of insurance routing queries. Accuracy 79% vs GPT-4o's 75% (few-shot). $0 training cost. **Scale-matches our target** (Qwen3-1.7B is one notch up); confirms LoRA on a 1B Llama can match GPT-4o-class on a narrow classification task.

**Together AI fine-tune-and-deploy Llama-3** ([together.ai/blog/finetuning](https://www.together.ai/blog/finetuning)). Fine-tuned Llama-3 8B matched 90% of GPT-4 performance on a math task; specific number was 65% on a math benchmark beating Llama-3-70B's 64% and approaching GPT-4o's 71%. Production case study with cost framing.

**DeepSeek-R1-Distill-Qwen-1.5B** ([huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-1.5B](https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-1.5B)). The reasoning-distillation existence proof at our target size. 800K trajectories from R1 → SFT a Qwen-2.5-Math-1.5B base → MATH-500: 83.9%, AIME 2024: 52.7%. **Same base size as the lower bound of our specialist range; same arch (Qwen) we're already shipping.**

**Counter-evidence — where specialists at small scale stumble:**

- **"Small Models Struggle to Learn from Strong Reasoners"** ([small-model-gap.github.io](https://small-model-gap.github.io/), [arxiv 2502.12143](https://arxiv.org/abs/2502.12143)). Empirical result: ≤3B students do **not** consistently benefit from distilling long-CoT traces from large teachers. Better results come from **shorter CoT traces or smaller teachers**. Practical implication for our recipe: don't use GPT-4o or Claude Sonnet's full reasoning traces as student-teacher signal — use a mid-size teacher (Qwen-7B / Qwen-14B class) or compress the traces.
- **OpenMedLM** ([pmc.ncbi.nlm.nih.gov/articles/PMC11187169/](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11187169/)). Prompt-engineering on open base models beat fine-tuned medical specialists on medical-QA benchmarks. Counter-data point to MedAlpaca / Meditron etc. — the specialization premium isn't free, and a well-engineered prompt can erase it on some domains.
- **Honeycomb / ReChat anecdotes** (Hamel Husain). Fine-tuning excels on syntax/style/rules tasks but **plateaus on tasks requiring up-to-date facts** — context is the right tool there, not training. Validates our existing two-stage design (Stage 0 RAG + Stage 1 specialist generation) but warns that the specialist should not be expected to memorize the corpus.

### T4. Synthetic data generation (industry signal)

Industry mostly nods at the same recipes the theory worker covered (Magpie, Self-Instruct, Evol-Instruct); the practitioner addition is **distilabel is 16 months stale and Augmentoolkit / the Magpie reference repo are now the preferred tools** (per tooling worker). Vendor blogs add little beyond the academic story; the most-cited PremAI guide ([blog.premai.io/how-to-generate-synthetic-training-data-for-llm-fine-tuning-2026-guide/](https://blog.premai.io/how-to-generate-synthetic-training-data-for-llm-fine-tuning-2026-guide/)) is a competent walk-through but doesn't add a new recipe.

Real signal: **the OpenPipe "capture from production" pattern** ([openpipe.ai/blog](https://openpipe.ai/blog)) is the *operationally* easiest synthetic-data path for an app where you can log prompt/response pairs. Doesn't apply pre-launch (our case), but worth naming as the post-launch evolution: ship the demo with synthetic data, then upgrade with captured pairs from real audience-submitted notes.

### T5. The Cactus seam (industry signal — confirming the tooling verdict)

**Industry confirms the tooling worker's `no-runtime-LoRA` verdict** and contextualizes it:

- The Cactus fine-tuning doc ([github.com/cactus-compute/cactus/blob/main/docs/finetuning.md](https://github.com/cactus-compute/cactus/blob/main/docs/finetuning.md)) lists six steps: Unsloth-train → `cactus convert --lora` → `cactus build --apple/--android` → link XCFramework / `.so` → ship. **No guidance on running multiple specialists on one device. No discussion of why merge-only. No roadmap mention of runtime adapters.**
- Roman Shemet's own HuggingFace post ([huggingface.co/blog/rshemet/cactus-on-device-inference](https://huggingface.co/blog/rshemet/cactus-on-device-inference)) frames Cactus's pillars as latency / privacy / cost — **does not mention LoRA, adapters, fine-tuning, specialist models, or multi-model swap anywhere**.
- The Cactus team's HN Launch post ([news.ycombinator.com/item?id=45291024](https://news.ycombinator.com/item?id=45291024)) and Show HN ([news.ycombinator.com/item?id=44524544](https://news.ycombinator.com/item?id=44524544)) likewise position Cactus as "Ollama for smartphones" — the conversation is about cross-platform inference performance, not adapter management.

**The contrast worth naming in the writeup:**

| Property | Cactus v1 | Apple Foundation Models | MediaPipe LLM Inference | llama.cpp server |
|---|---|---|---|---|
| Base format | proprietary `.cact` | system on-device LLM | `.tflite` flatbuffer | GGUF |
| Adapter format | merged into `.cact` only | `.fmadapter` (~160 MB) | LoRA on safetensors → flatbuffer | GGUF LoRA |
| Runtime adapter loading | **no** | **yes**, dynamically loaded + cached + swapped | **yes** on GPU backend | **yes**, `/lora-adapters` hot-swap |
| Adapter target modules | n/a (merged) | undocumented (LoRA on attention assumed) | attention only (`q,k,v,o`) | configurable |
| Multi-specialist on one device | one `.cact` per specialist | many adapters, one base | multiple adapters, one base | many adapters, one base (`{"id":0,"scale":0.5},...`) |

Sources for the comparison: Apple ([developer.apple.com/apple-intelligence/foundation-models-adapter/](https://developer.apple.com/apple-intelligence/foundation-models-adapter/)), MediaPipe ([ai.google.dev/edge/mediapipe/solutions/genai/llm_inference/android](https://ai.google.dev/edge/mediapipe/solutions/genai/llm_inference/android)), llama.cpp ([github.com/ggml-org/llama.cpp/issues/10377](https://github.com/ggml-org/llama.cpp/issues/10377), [github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md)).

**Operational impact for a hackathon-shaped project:**

- **One specialist.** Merge it into base, ship one `.cact` blob (~1.0–1.5 GB at Q4 for Qwen3-1.7B). Same as shipping the generalist today; license posture unchanged. This is the recommended hackathon path.
- **Two or three specialists** (e.g., "note merger" + "claim normalizer" + "deduplicator"). Multi-`.cact` per device. Storage cost: 3× the base. Switching cost: cold model load (≈seconds), not LoRA swap (≈ms). Painful but feasible if the demo can prepare-and-stage each specialist before the relevant UI affordance.
- **>3 specialists.** Cactus is the wrong runtime today; either route to llama.cpp directly (loses Cactus's battery + LP-RAM optimizations) or to MediaPipe (Android-side, GPU-only) and accept the constraint. **For our writeup, this is the named gap that motivates the future-work specialists thread.**

No public community workaround exists for runtime-LoRA in Cactus. The team's Discord is referenced from the docs but is not searchable from outside; no GitHub Discussions thread on the topic surfaces from search. **The closest public asks** are llama.cpp-side discussions ([github.com/ggml-org/llama.cpp/discussions/8849](https://github.com/ggml-org/llama.cpp/discussions/8849), [github.com/ggml-org/llama.cpp/discussions/7850](https://github.com/ggml-org/llama.cpp/discussions/7850), [github.com/ollama/ollama/issues/9548](https://github.com/ollama/ollama/issues/9548)) which were resolved upstream — but Cactus moved off llama.cpp at v1 so doesn't inherit that work.

### T6. Evaluation methodology (industry gotchas)

The strongest practitioner-side warnings on judge-LLM-as-eval:

- **Hamel Husain — *Using LLM-as-a-Judge For Evaluation: A Complete Guide*** ([hamel.dev/blog/posts/llm-judge/](https://hamel.dev/blog/posts/llm-judge/)). Practical recipe: bring a small labeled calibration set (100–500 examples), validate the judge against humans on it, then trust the judge only insofar as it tracks the calibration set. Names Eugene Yan's ALIGN Eval tool as the simplest interface — upload data, label binary good/bad, evaluate the judge against humans.
- **Weights & Biases — *Exploring LLM-as-a-Judge*** ([wandb.ai/site/articles/exploring-llm-as-a-judge/](https://wandb.ai/site/articles/exploring-llm-as-a-judge/)) and Vadim's blog ([vadim.blog/llm-as-judge](https://vadim.blog/llm-as-judge)) and Michael Brenndoerfer's interactive piece ([mbrenndoerfer.com/writing/position-bias-in-llm-judges](https://mbrenndoerfer.com/writing/position-bias-in-llm-judges)). All converge on the same checklist: randomize positions; evaluate both orderings; penalize verbosity explicitly in the rubric; calibrate against humans on 100–500 examples. Position bias is large enough to flip outcomes when uncontrolled.
- **Galileo AI — *LLM-as-a-Judge vs Human Evaluation*** ([galileo.ai/blog/llm-as-a-judge-vs-human-evaluation](https://galileo.ai/blog/llm-as-a-judge-vs-human-evaluation)) and Cameron Wolfe's substack ([cameronrwolfe.substack.com/p/llm-as-a-judge](https://cameronrwolfe.substack.com/p/llm-as-a-judge)). Frame the failure modes: self-enhancement (judge prefers its own family — so don't grade Qwen with a Qwen judge), verbosity bias (judge prefers longer answers — explicitly penalize), refusal-asymmetry (judge over-grades safety-aligned outputs).

**On eval-contamination for synthetic data** (our T6 holdout-discipline question):

- The contamination literature ([arxiv 2501.18771](https://arxiv.org/abs/2501.18771), [arxiv 2402.15938](https://arxiv.org/abs/2402.15938), [arxiv 2310.18018](https://arxiv.org/abs/2310.18018)) shows up to 30 BLEU points of inflation when source+target are leaked. **Larger-model inflation is proportionally bigger than small-model inflation** (8B inflates 2.5× more than 1B in the controlled study). At our 1.7B scale, contamination matters but is bounded. The operational rule: **eval examples must come from a different teacher seed and a different prompt template than training examples**, even if both are generated by the same teacher model — otherwise the student is being graded on its ability to memorize what the teacher said on that prompt template.

**Gap:** no industry blog has published a specifically-note-merging eval; we'd be inventing the rubric. The closest published rubric shape is SummEval / RAGAS-faithfulness (covered in theory worker); the industry-side practitioner contribution is the calibration-set discipline above.

### T7. License-clause practical interpretation

The four base-model license families a hackathon-shaped specialist could inherit:

1. **Apache-2.0 (Qwen 3, SmolLM2, Phi-3, Gemma 4)** — clean. Fine-tune, merge, redistribute weights publicly with attribution. No naming prefix required, no MAU clause. For Phi-3, the model card uses the MIT license. **This is the recommended path for our public repo.**

2. **Llama Community License** (Llama 3.x, Llama 4) — adds requirements ([llama.com/llama4/license/](https://www.llama.com/llama4/license/), [llama.com/faq/](https://www.llama.com/faq/)):
   - Any redistributed derivative must have **"Llama" as a prefix in the model name**.
   - Must **prominently display "Built with Llama"** on website/UI/blog/docs.
   - Must include a copy of the Agreement.
   - Must include the Notice text file.
   - 700M MAU clause is still in force (requires Meta approval at that scale — irrelevant to a hackathon, named for completeness).
3. **Gemma Terms of Use** (Gemma 1–3) — Gemma-specific terms apply to derivatives; redistribution requires including the Terms or a reference. ([wcr.legal/google-gemma-license-risks/](https://wcr.legal/google-gemma-license-risks/)). **Gemma 4 (2026) flipped to Apache-2.0** ([venturebeat.com/technology/google-releases-gemma-4-under-apache-2-0-and-that-license-change-may-matter](https://venturebeat.com/technology/google-releases-gemma-4-under-apache-2-0-and-that-license-change-may-matter), [mindstudio.ai/blog/gemma-4-apache-2-license-commercial-use](https://www.mindstudio.ai/blog/gemma-4-apache-2-license-commercial-use)) — if a Gemma-class base is preferred, **use Gemma 4, not Gemma 3**, to avoid the Terms-of-Use redistribution friction.

4. **Synthetic-data-from-frontier-API outputs** — OpenAI's TOS ([openai.com/policies/services-agreement/](https://openai.com/policies/services-agreement/)) prohibits using outputs to develop AI models that *compete with* OpenAI's services. The DeepSeek controversy ([law.asia/openai-deepseek-ai-distillation/](https://law.asia/openai-deepseek-ai-distillation/)) is the public test case of this clause. Anthropic and Mistral and xAI have analogous clauses. **Anthropic's official-Claude-Haiku distillation in Bedrock** ([anthropic.com/news/trainium2-and-distillation](https://www.anthropic.com/news/trainium2-and-distillation)) is a permitted exception path — but only inside Bedrock, not for free model redistribution. **For our public-repo hackathon: distill from an Apache-2.0 / open-weight teacher (Qwen-7B/14B, Llama-3-70B with attribution, or DeepSeek-R1) rather than from GPT-4o / Claude / Gemini outputs.** This sidesteps the entire TOS competition-clause question.

**Practical recommendation for our license posture:**

- Base: Qwen 3 1.7B (Apache-2.0). No naming prefix, no Built-With banner, no extra clauses.
- Teacher (if distilling): Qwen 3 14B or DeepSeek-R1 (both Apache-2.0 / MIT-class). Never an OpenAI / Anthropic / Google frontier API.
- Adapter: merged into the base before redistribution. Repo ships one Apache-2.0 GGUF / `.cact`.

---

## 3. Reference implementations (industry — paired with writeups)

These are public projects with **writeups** (blog post / postmortem) about shipping a small specialist on mobile/edge. Pair the repo with the writeup.

1. **Sasha Denisov — Fine-Tuning Gemma with LoRA for On-Device Inference (Android, iOS, Web) with Separate LoRA Weights** ([medium.com/google-developer-experts/...](https://medium.com/google-developer-experts/fine-tuning-gemma-with-lora-for-on-device-inference-android-ios-web-with-separate-lora-weights-f05d1db30d86)). Gemma-2B base + LoRA rank 8 on Colab T4/A100, then `converter.convert_checkpoint()` to LiteRT, with the LoRA kept as a **separate `.bin`** file (not merged into base). Inference loading via MediaPipe LLM Inference API with the GPU backend. **Structurally analogous: a developer fine-tuning a 2B model and shipping it cross-platform with adapter weights kept separate** — the path Cactus does not enable but MediaPipe does.

2. **Predibase LoRA Land bake-off repo** ([github.com/predibase/lora_bakeoff](https://github.com/predibase/lora_bakeoff)) + blog ([predibase.com/blog/lora-land-fine-tuned-open-source-llms-that-outperform-gpt-4](https://predibase.com/blog/lora-land-fine-tuned-open-source-llms-that-outperform-gpt-4)). 25 Mistral-7B LoRAs at $8 each, full reproducible repo. **Structurally analogous: the "swap a specialist per task" architecture** — what we'd do on-device if Cactus supported it.

3. **Tether QVAC Fabric LLM** ([github.com/tetherto/qvac-fabric-llm.cpp](https://github.com/tetherto/qvac-fabric-llm.cpp)) + blog ([huggingface.co/blog/qvac/fabric-llm-finetune](https://huggingface.co/blog/qvac/fabric-llm-finetune)) + the BitNet variant ([huggingface.co/blog/qvac/fabric-llm-finetune-bitnet](https://huggingface.co/blog/qvac/fabric-llm-finetune-bitnet)). On-device LoRA *training* — not just inference — on Adreno/Mali/Apple Silicon. **Structurally analogous: the future-work direction for the writeup's "specialists evolve on-device" arc.** Wall-clock numbers above; Apache-2.0; llama.cpp-fork base.

4. **OpenPipe production patterns** ([openpipe.ai/blog](https://openpipe.ai/blog)) — drop-in-OpenAI-SDK → capture → fine-tune. **Structurally analogous: how the post-hackathon evolution of our specialist would look** — capture real audience-submitted notes, fine-tune a per-domain specialist incrementally. The OpenPipe HN thread is the postmortem ([news.ycombinator.com/item?id=40843848](https://news.ycombinator.com/item?id=40843848)).

5. **Oxen.ai Qwen3 Text2SQL recipe** ([ghost.oxen.ai/how-to-fine-tune-qwen3-to-gpt-4o-level-performance/](https://ghost.oxen.ai/how-to-fine-tune-qwen3-to-gpt-4o-level-performance/)) and *How a $1 Qwen3-VL Fine-Tune Beat Gemini 3* ([ghost.oxen.ai/how-a-1-qwen3-vl-fine-tune-beat-gemini-3/](https://ghost.oxen.ai/how-a-1-qwen3-vl-fine-tune-beat-gemini-3/)). **Structurally analogous: same base family (Qwen3), same scale (0.6B–1.7B), same SFT-with-judge-LLM-eval pattern.** Closest published shape to what we'd run; needs only the GGUF/`.cact` conversion bolted on.

---

## 4. Specialist-vs-generalist evidence — both sides

**Case for specialists at ≤2B (strongest published evidence):**

- **Predibase LoRA Land**: 25/25 Mistral-7B LoRAs beat their base; many beat GPT-4 by 4–15% on narrow tasks; cost $8 each ([predibase.com/blog/lora-land-fine-tuned-open-source-llms-that-outperform-gpt-4](https://predibase.com/blog/lora-land-fine-tuned-open-source-llms-that-outperform-gpt-4)). Strongest aggregate evidence.
- **Apple Intelligence shipping production**: rank-16 adapters on a 3B base for Writing Tools / Smart Reply / summarization / content tagging — running on every recent iPhone today ([machinelearning.apple.com/research/introducing-apple-foundation-models](https://machinelearning.apple.com/research/introducing-apple-foundation-models)). Strongest *deployed-at-billion-user-scale* evidence.
- **Gemini Nano on Pixel Recorder**: +24% engagement, 2–5 daily uses per user from a single LoRA fine-tune on summarization ([android-developers.googleblog.com/2024/08/recorder-app-on-pixel-sees-boost-in-engagement-with-gemini-nano.html](https://android-developers.googleblog.com/2024/08/recorder-app-on-pixel-sees-boost-in-engagement-with-gemini-nano.html)). Strongest *user-engagement-moved* evidence.
- **DeepSeek-R1-Distill-Qwen-1.5B**: 83.9% MATH-500 at 1.5B — beats GPT-4o on the same benchmark ([huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-1.5B](https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-1.5B)). Strongest *small-student-beats-big-generalist* evidence.
- **Convirza Llama-3-8B + multi-LoRA**: 10× cost vs OpenAI, +8% F1, +80% throughput, 60 active adapters in production ([zenml.io/llmops-database/multi-lora-serving-for-agent-performance-analysis-at-scale](https://www.zenml.io/llmops-database/multi-lora-serving-for-agent-performance-analysis-at-scale)). Strongest *enterprise-scaled* evidence.
- **Phi-3 + ITC Krishi Mitra** ([azure.microsoft.com/en-us/blog/announcing-phi-3-fine-tuning-new-generative-ai-models-and-other-azure-ai-updates-to-empower-organizations-to-customize-and-scale-ai-applications/](https://azure.microsoft.com/en-us/blog/announcing-phi-3-fine-tuning-new-generative-ai-models-and-other-azure-ai-updates-to-empower-organizations-to-customize-and-scale-ai-applications/)): 1M-farmer-facing fine-tuned Phi-3 deployment. Strongest *small-model-deployed-in-developing-market* evidence.

**Counter-evidence (where specialization at small scale fails):**

- **Small Model Learnability Gap** ([small-model-gap.github.io](https://small-model-gap.github.io/), [arxiv 2502.12143](https://arxiv.org/abs/2502.12143)). ≤3B students do **not** benefit consistently from large-teacher long-CoT distillation. Practical implication: don't naively pour GPT-4-class reasoning traces into a 1.5B and expect improvement.
- **OpenMedLM** ([pmc.ncbi.nlm.nih.gov/articles/PMC11187169/](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11187169/)). Prompt-engineering on open base models beat MedAlpaca / fine-tuned medical specialists on USMLE-style benchmarks. **Specialization is not free** — a careful prompt at inference can erase the SFT premium on some domains.
- **OpenPipe HN thread methodological pushback** ([news.ycombinator.com/item?id=40843848](https://news.ycombinator.com/item?id=40843848)). When the comparison is fair (matched temperature, fresh eval set), the specialist-beats-generalist claim is consistently weaker than the headline. **The specialist premium is real but oversold in blog posts.**
- **HOSPITAL / MedAlpaca / Meditron mid-scale comparison** ([pmc.ncbi.nlm.nih.gov/articles/PMC11339514/](https://pmc.ncbi.nlm.nih.gov/articles/PMC11339514/)). PMC-LLaMA-13B 49.2% / MedAlpaca-13B 45.6% / Meditron-7B 52% on MedQA-USMLE. **None of them clear 60%**, and on TRIDENT-Bench ([arxiv 2507.21134](https://arxiv.org/abs/2507.21134)) domain-specialized models *struggle more with ethical-nuance prompts than generalists do* — i.e., specialization narrows competence in unintended ways too.
- **Catastrophic forgetting from over-specialization**. Sequential fine-tuning on narrow tasks reliably loses base instruction-following capability; mitigations exist but cost training-recipe complexity (see catastrophic-forgetting literature: [medium.com/@baicenxiao/...](https://medium.com/@baicenxiao/avoiding-amnesia-some-practical-guides-to-mitigate-catastrophic-forgetting-in-llms-post-training-6a23e4f064cb)). The Biderman 2024 "LoRA Learns Less and Forgets Less" result (cited in theory worker) is the saving grace: **LoRA-based specialization forgets meaningfully less than full-FT**, which is one more reason to use LoRA, not full-FT, for our recipe.

**Synthesis for the writeup's specialists thread:** the case is strongest when (a) the task has a clearly-defined correct output (extraction, structured generation, summarization with rubric), (b) the specialist is LoRA not full-FT (forgetting argument), (c) the eval is fair (matched temperature, fresh eval set, judge calibration). All three hold for our note-merging task framed as "merge these two notes into one consolidated note preserving every claim." The case is weakest when the task drifts toward open-ended composition, where the generalist's broader competence helps and the small-specialist's narrower competence hurts.

---

## 5. Open research questions (industry gaps)

The named gaps where no industry team has shipped a public solution yet:

1. **Cactus + runtime LoRA: NO** (confirmed). The team's public surface has no roadmap mention; no community workaround exists. Workarounds via llama.cpp-direct or MediaPipe lose Cactus's battery/LP-RAM optimizations. **This is the single load-bearing engineering gap for our specialists thread.**

2. **Multi-specialist on one phone via Cactus**: undocumented. The merge-only path forces one base + one LoRA → one `.cact`. Multiple specialists = multiple full-base blobs. **No published guidance on memory footprint, cold-load cost, or storage tax for the multi-`.cact` configuration on a Pixel-7-class device.**

3. **Note-merging-shaped eval**: no industry-published rubric. Closest adjacent rubrics (SummEval, RAGAS-faithfulness, RAGTruth) are summarization-shaped, not merge-shaped. We'd be inventing.

4. **Apple-style runtime-adapter swap on cross-platform mobile**: Apple does it inside the Apple Foundation Models framework (closed); MediaPipe does it for Gemma/Phi-2 on Android GPU only. **No open-source runtime currently spans iOS + Android with runtime LoRA swap.** Tether QVAC Fabric is the closest (cross-platform mobile LoRA, but for training, and not yet productionized as an inference runtime).

5. **End-to-end Oxen.ai → mobile pipeline**: documented through "fine-tune complete on Oxen branch"; the GGUF/`.cact` step is bring-your-own. **No public Oxen.ai + Cactus blog post**, and no public Oxen.ai + MediaPipe blog post.

6. **Specialist-evolution-on-device**: gestured at by QVAC Fabric but no production app does it. Would underwrite the writeup's "generational evolution" thread.

---

## 6. Source ledger

URLs in order of first appearance, deduplicated.

https://machinelearning.apple.com/research/introducing-apple-foundation-models
https://developer.apple.com/apple-intelligence/foundation-models-adapter/
https://arxiv.org/abs/2507.13575
https://machinelearning.apple.com/research/apple-foundation-models-tech-report-2025
https://android-developers.googleblog.com/2024/08/recorder-app-on-pixel-sees-boost-in-engagement-with-gemini-nano.html
https://developer.chrome.com/blog/improved-summaries-gemini-nano
https://ai.google.dev/edge/mediapipe/solutions/genai/llm_inference/android
https://predibase.com/blog/lora-land-fine-tuned-open-source-llms-that-outperform-gpt-4
https://openpipe.ai/blog
https://hamel.dev/blog/posts/fine_tuning_valuable.html
https://hamel.dev/blog/posts/evals/
https://huggingface.co/blog/qvac/fabric-llm-finetune
https://predibase.com/blog/lora-exchange-lorax-serve-100s-of-fine-tuned-llms-for-the-cost-of-one
https://www.zenml.io/llmops-database/multi-lora-serving-for-agent-performance-analysis-at-scale
https://ghost.oxen.ai/how-to-fine-tune-qwen3-to-gpt-4o-level-performance/
https://www.infoq.com/news/2025/12/cactus-on-device-inference/
https://huggingface.co/blog/rshemet/cactus-on-device-inference
https://ghost.oxen.ai/fine-tuning-fridays/
https://ghost.oxen.ai/how-a-1-qwen3-vl-fine-tune-beat-gemini-3/
https://www.baseten.co/resources/customers/from-datasets-to-deployed-models-how-oxen-ai-builds-on-baseten/
https://predibase.com/fine-tuning-index
https://news.ycombinator.com/item?id=40843848
https://towardsdatascience.com/i-fine-tuned-the-tiny-llama-3-2-1b-to-replace-gpt-4o-7ce1e5619f3d/
https://www.together.ai/blog/finetuning
https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-1.5B
https://small-model-gap.github.io/
https://arxiv.org/abs/2502.12143
https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11187169/
https://blog.premai.io/how-to-generate-synthetic-training-data-for-llm-fine-tuning-2026-guide/
https://github.com/cactus-compute/cactus/blob/main/docs/finetuning.md
https://news.ycombinator.com/item?id=45291024
https://news.ycombinator.com/item?id=44524544
https://github.com/ggml-org/llama.cpp/issues/10377
https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md
https://github.com/ggml-org/llama.cpp/discussions/8849
https://github.com/ggml-org/llama.cpp/discussions/7850
https://github.com/ollama/ollama/issues/9548
https://hamel.dev/blog/posts/llm-judge/
https://wandb.ai/site/articles/exploring-llm-as-a-judge/
https://vadim.blog/llm-as-judge
https://mbrenndoerfer.com/writing/position-bias-in-llm-judges
https://galileo.ai/blog/llm-as-a-judge-vs-human-evaluation
https://cameronrwolfe.substack.com/p/llm-as-a-judge
https://arxiv.org/abs/2501.18771
https://arxiv.org/abs/2402.15938
https://arxiv.org/abs/2310.18018
https://www.llama.com/llama4/license/
https://www.llama.com/faq/
https://wcr.legal/google-gemma-license-risks/
https://venturebeat.com/technology/google-releases-gemma-4-under-apache-2-0-and-that-license-change-may-matter
https://www.mindstudio.ai/blog/gemma-4-apache-2-license-commercial-use
https://openai.com/policies/services-agreement/
https://law.asia/openai-deepseek-ai-distillation/
https://www.anthropic.com/news/trainium2-and-distillation
https://medium.com/google-developer-experts/fine-tuning-gemma-with-lora-for-on-device-inference-android-ios-web-with-separate-lora-weights-f05d1db30d86
https://github.com/predibase/lora_bakeoff
https://github.com/tetherto/qvac-fabric-llm.cpp
https://huggingface.co/blog/qvac/fabric-llm-finetune-bitnet
https://azure.microsoft.com/en-us/blog/announcing-phi-3-fine-tuning-new-generative-ai-models-and-other-azure-ai-updates-to-empower-organizations-to-customize-and-scale-ai-applications/
https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11339514/
https://arxiv.org/abs/2507.21134
https://medium.com/@baicenxiao/avoiding-amnesia-some-practical-guides-to-mitigate-catastrophic-forgetting-in-llms-post-training-6a23e4f064cb
