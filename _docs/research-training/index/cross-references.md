# Source → source citation graph

Where source A explicitly references source B in the worker outputs, the edge is captured here as `A → B (<one-line context>)`. Built by reading the worker outputs for paper-to-paper, repo-to-paper, and blog-to-paper citations. Not invented.

The graph is sparse — the workers cite primary sources but rarely surface secondary cross-references between them. Most of the structure is hub-and-spoke around a few well-known anchors (LoRA, DeepSeek-R1, Cactus docs).

---

## Hubs (sources that everything else cites)

### LoRA paper (`arxiv.org/abs/2106.09685`)
- ← QLoRA (`arxiv.org/abs/2305.14314`) builds on it (4-bit base + LoRA on top)
- ← DoRA (`arxiv.org/abs/2402.09353`) refines it (magnitude/direction decomposition)
- ← LoRA-FA (`arxiv.org/abs/2308.03303`) refines memory profile (freeze A, train B)
- ← LoRA Learns Less and Forgets Less (`arxiv.org/abs/2405.09673`) tests the original claim empirically
- ← LoRA Land (`arxiv.org/abs/2405.00732`) applies it at production scale
- ← Apple tech report 2025 (`arxiv.org/abs/2507.13575`) ships it at consumer scale (rank-{8,16,32} adapters)
- ← Cactus finetuning.md uses it via Unsloth as the supported PEFT recipe
- ← S-LoRA (`arxiv.org/abs/2311.03285`) extends it to server-side multi-tenant adapter serving

### DeepSeek-R1 (`arxiv.org/abs/2501.12948` + model card)
- → Qwen 2.5-Math-1.5B base (the model the 1.5B distill was built on; Apache-2.0)
- → Orca-style reasoning-trace distillation (`arxiv.org/abs/2306.02707`) — same methodology family
- ← Used as a cited reference by all 6 workers; the 4/6-worker consensus pick

### Cactus finetuning.md
- → Unsloth (`github.com/unslothai/unsloth`) — explicitly recommended as the upstream trainer
- → LoRA paper (`arxiv.org/abs/2106.09685`) — implicitly: the `--lora` flag implements the technique
- → Qwen 3 / Qwen 3.5 / Gemma 3 / LFM2 / LFM2.5 base families (listed as supported)
- ← Cited by all 6 workers as the verdict source for T5

### Cactus engine docs (`docs/cactus_engine.md`)
- → cactus_init / cactus_complete FFI surface
- ← Cited by 3/6 workers to confirm "no adapter slot"

---

## Citation chains

### Magpie chain
- Magpie (`arxiv.org/abs/2406.08464`)
  - → Self-Instruct (`arxiv.org/abs/2212.10560`) — predecessor synthetic-data recipe
  - → Evol-Instruct (`arxiv.org/abs/2304.12244`) — adjacent synthetic-data recipe
  - → Llama-3-Instruct (`huggingface.co/meta-llama/Llama-3-8B-Instruct`) — the source aligned model the technique exploits
  - → Magpie-Air-300K-Filtered + Magpie-Pro-300K-Filtered datasets (HF) — Magpie's own published outputs
- ← distilabel (`github.com/argilla-io/distilabel`) — implements Magpie as a pipeline component
- ← Augmentoolkit — Augmentoolkit's roleplay/factual-Q&A pipelines reference Magpie-style techniques

### Predibase LoRA Land chain
- LoRA Land paper (`arxiv.org/abs/2405.00732`)
  - → LoRAX (`predibase.com/blog/lora-exchange-lorax-serve-100s-of-fine-tuned-llms-for-the-cost-of-one`) — the inference architecture that serves the 25 LoRAs
  - → S-LoRA (`arxiv.org/abs/2311.03285`) — academic ancestor of LoRAX (dynamic-adapter serving)
  - → Mistral-7B base (the model fine-tuned across 25 tasks)
- ← Convirza multi-LoRA production case (`zenml.io/llmops-database/multi-lora-serving-for-agent-performance-analysis-at-scale`) — applies the LoRAX architecture at 60-adapter production scale

### Apple Foundation Models chain
- Apple intro post (June 2024) `machinelearning.apple.com/research/introducing-apple-foundation-models`
  - → Apple developer adapter training docs (WWDC25) `developer.apple.com/apple-intelligence/foundation-models-adapter/`
  - → Apple Foundation Models tech report 2025 (`arxiv.org/abs/2507.13575`)
- ← cited by industry worker as the gold-standard contrast against Cactus's merge-only path

### MediaPipe / Pixel Recorder chain
- Pixel Recorder Gemini Nano blog (`android-developers.googleblog.com/...`)
  - → Chrome Gemini Nano LoRA blog (`developer.chrome.com/blog/improved-summaries-gemini-nano`) — companion blog with browser-side detail
  - → MediaPipe LLM Inference Android docs (`ai.google.dev/edge/mediapipe/solutions/genai/llm_inference/android`) — the developer-accessible API
- ← Sasha Denisov's Gemma + LoRA cross-platform inference Medium post (`medium.com/google-developer-experts/...`) — applies the MediaPipe pattern to Gemma-2B

### Oxen Qwen3 SQL → Oxen ecosystem
- Ghost Oxen Qwen3 SQL post
  - → Oxen.ai pricing page (cost reference)
  - → Marimo notebooks (training surface)
  - → Baseten partnership case study (`baseten.co/resources/customers/from-datasets-to-deployed-models-how-oxen-ai-builds-on-baseten/`) — the compute layer
  - → Gemini-as-judge eval (200-example val set)
  - → Qwen3-0.6B / 1.7B base (`huggingface.co/Qwen/Qwen3-1.7B`)
- ← cited by industry + tooling + chatgpt-DR + claude-DR as *the* recipe shape to clone

### Judge-LLM literature
- MT-Bench (`arxiv.org/abs/2306.05685`) — canonical judge-LLM paper
  - ← Hamel Husain LLM-as-Judge guide (`hamel.dev/blog/posts/llm-judge/`) — practitioner overlay; cites ALIGN Eval tool
  - ← Preference Leakage (`arxiv.org/abs/2502.01534`) — extends to generator/judge contamination
  - ← Galileo AI judge-vs-human, mbrenndoerfer position-bias piece, W&B exploring-judge — all practitioner pieces that reference MT-Bench's three biases
- → Vicuna-style pairwise evaluation methodology

### QVAC Fabric chain
- QVAC Fabric HF blog (Tether, Dec 2025)
  - → QVAC Fabric repo (`github.com/tetherto/qvac-fabric-llm.cpp`) — Apache-2.0 llama.cpp fork
  - → QVAC Fabric BitNet variant (`huggingface.co/blog/qvac/fabric-llm-finetune-bitnet`) — BitNet on-device variant
  - → llama.cpp (`github.com/ggml-org/llama.cpp`) — the upstream Fabric forks from

### Distillation lineage
- Orca (`arxiv.org/abs/2306.02707`) → established "imitate reasoning, not answer"
- → Distilling Step-by-Step (`arxiv.org/abs/2305.02301`) — multi-task SFT with rationales as aux loss
- → MiniLLM (`arxiv.org/abs/2306.08543`) — reverse-KL for white-box KD
- → GKD (`arxiv.org/abs/2306.13649`) — on-policy distillation
- → DistiLLM (`arxiv.org/abs/2402.03898`) — skew-KL + adaptive on-policy scheduler
- → DeepSeek-R1-Distill family (`arxiv.org/abs/2501.12948`) — production application at 1.5B–7B
- ← Small Model Learnability Gap (`arxiv.org/abs/2502.12143`) — the counter-case warning

### License lineage
- Apache-2.0 — referenced by Qwen 3 license, SmolLM2 license, Phi-3 license, Gemma 4 license flip
- Llama Community License — referenced as the comparison point (clauses: "Built with Llama" + naming prefix + 700M MAU)
- Gemma Terms of Use — referenced as the Gemma ≤3 cautionary tale → Gemma 4 flipped to Apache-2.0
- OpenAI TOS competitive-model clause → DeepSeek-OpenAI controversy (`law.asia/openai-deepseek-ai-distillation/`)
- Anthropic AUP → Bedrock distillation permitted-exception path (`anthropic.com/news/trainium2-and-distillation`)

---

## Edges between worker outputs

The six worker files cross-cite each other within the index by perspective handoff:

- **theory.md → tooling.md** for T1 (Oxen.ai) and T5 (Cactus engine) — theory worker explicitly defers these to the engineering-shaped workers
- **theory.md → industry.md** for T7 license interpretation
- **industry.md → tooling.md** (header preamble) — confirms tooling worker's T5 verdict (no Cactus runtime LoRA) and T1 verdict (Oxen.ai surface area)
- **gemini-deep-research.md → other workers (implicitly)** — gemini-DR is the longest single-file pass and covers all T1–T7 but is less crisp on the v1-Cactus-no-longer-wraps-llama.cpp fact than the tooling worker
- **claude-deep-research.md → chatgpt-deep-research.md** — both share the same SaaS-vs-OSS framing of Oxen.ai but with different emphasis

---

## Notable absences (edges that *should* exist but don't surface in the worker outputs)

These would be valuable cross-references if anyone had written them up, but the workers didn't surface them:

- **Oxen.ai → Cactus** — no public bridge writeup. Ollamox (`github.com/Oxen-AI/Ollamox`) is the closest; it does Oxen → GGUF → Ollama, not Oxen → `.cact` → Cactus. (Listed as open question 7.)
- **distilabel → Magpie pipeline** — distilabel ships a Magpie task, but no worker links the two with a specific code example.
- **Apple Foundation Models adapter framework → MediaPipe LLM Inference** — both ship runtime LoRA on phones today, but no public comparison piece across them. The industry worker's table is the closest synthesis but it's de novo, not citing an existing comparison source.
- **DeepSeek-R1-Distill-Qwen-1.5B → Cactus deployment** — no public writeup of running an R1-distilled small model in Cactus specifically. Cactus's supported-base list includes Qwen 3 / 3.5, so technically supported; nobody has documented the end-to-end run.
- **Cactus + R2 cross-platform determinism harness on fine-tuned weights** — internal to this project; no public reference (this is the project's own gap, listed as open question 5).
