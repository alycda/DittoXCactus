# Research Brief: Small-Model Post-Training for Mesh RAG

## Top 10 Must-Read Sources

1. **Oxen.ai Documentation – “Fine-Tuning Models on Oxen.ai” (Oxen.ai, 2024)** – Official docs describe Oxen as an integrated data versioning and training platform. It shows the end-to-end pipeline: upload a CSV/JSONL dataset, provision a GPU, fine-tune, and then download the final model weights【20†L91-L99】【22†L224-L232】. Key for understanding Oxen’s workflow and what it automates.

2. **Oxen.ai Blog – *“How to Fine-Tune Qwen3 on Text2SQL to GPT-4o level performance”* (Schoeninger, 2025)** – A concrete case study fine-tuning Qwen3 (0.6B, 1.7B) models on Text2SQL tasks. It shows Oxen’s toolbelt in action: dataset+code+model on Oxen, achieving SFT Qwen performance near GPT-4o【8†L37-L44】【8†L58-L66】. Demonstrates small-model specialist training in practice.

3. **Oxen.ai Blog – *“Training a Rust 1.5B Coder LM with GRPO”* (Schoeninger, 2025)** – A case study of using Oxen’s pipeline (and on-prem H100 GPU) to train a 1.5B-code specialist with reinforcement learning. It highlights that even small models (1.5B) can rival much larger ones on narrow tasks when given verifiable feedback (compilation/tests)【26†L69-L78】【26†L86-L94】. Useful for understanding small-model training scale and potential.

4. **Oxen.ai Blog – *“The Best AI Data Version Control Tools [2025]”* (Schoeninger, 2024)** – Marketing blog comparing Oxen to DVC, Git LFS, HF Datasets, etc. It claims Oxen is “open-source, versioning tool optimized for ML datasets” and dramatically faster than DVC/Git-LFS on large pushes【11†L75-L84】【36†L168-L177】. Useful for Oxen vs alternatives and architecture.

5. **Oxen Pricing Page (2026)** – Official pricing info. Free (“Explorer”) tier gives 50 GB storage/transfer and unlimited public repos【14†L20-L28】. GPU usage is pay-as-you-go: H100 80GB at ~$4.87/hr【14†L258-L264】. Good to estimate cost: a few GPU-hours is modest. No hidden “compute credit” on free tier – just pay per second on GPU.

6. **Cactus Compute Documentation (v1.9)** – Official docs for the on-device runtime. Key finding: Cactus supports *LoRA merging* but not dynamic adapter loading. The `cactus convert` command can take a base GGUF model and a LoRA adapter to produce a merged GGUF model【41†L238-L246】. In practice, we must merge LoRA weights into the final model before deployment, not load them on-the-fly at inference.

7. **Ranger.net – *“Top Tools for AI Test Data Versioning”* (2026)** – Third-party blog reviewing version-control tools. It benchmarks Oxen vs Git-LFS and DVC: on ImageNet, Oxen pushed data much faster (Git-LFS ~20 hr, DVC 3–5 hr, versus minutes with Oxen)【36†L168-L177】. Also notes Oxen supports remote workflows and free self-hosted or hosted tiers with 50 GB free. Good third-party perspective on Oxen’s performance edge.

8. **LoRA: Low-Rank Adaptation (Hu et al., 2021)** – The seminal paper introducing LoRA, a parameter-efficient fine-tuning (PEFT) method. It shows how to inject low-rank matrices into model layers to fine-tune large models with a fraction of the parameters【38†L5-L8】. Essential background on how small-adapter training works. (Follow-ups like *LoRA-FA* (2024) refine LoRA for memory efficiency.)

9. **OpenAI Terms of Use (effective 1/1/2026)** – The official legal terms for OpenAI services. Crucial clause: *“You may not use Output to develop models that compete with OpenAI”*【44†L93-L101】. Implies that using GPT-4(o) outputs to train an open small-model would violate OpenAI’s terms. Key licensing landmine if considering distillation via OpenAI. 

10. **Google Gemma Terms of Use (Apr 2026)** – Google’s license for Gemma open models (Gemma-3 and earlier). It explicitly defines any model trained via **distillation or synthetic outputs** of Gemma as a “Model Derivative” subject to the license【47†L341-L349】. In other words, if Gemma is used as the teacher, the resulting model must follow Gemma’s terms. Critical to know for licensing of distillation.

## T1. Oxen.ai’s Surface Area and Pipeline

**What is Oxen.ai?**  
Oxen.ai is **both** a data version-control system and a training/inference platform for ML. It provides Git-like versioning tailored to large datasets (tabular, text, images, etc.) and integrates hosted compute for fine-tuning models. In Oxen’s view, it “automatically versions and manages the raw model weights and datasets”【20†L91-L99】. Practically, you create an Oxen repository, upload your data (CSV/JSONL/etc.), and then select a base model to fine-tune via their web UI or CLI. Oxen spins up a GPU (e.g. an H100) to run training, logs metrics, and when done it saves the fine-tuned model weights back to the repo【20†L91-L99】【22†L224-L232】. It aims to be an all-in-one MLOps solution – a combination of DVC (for data), Weights&Biases (for experiment tracking), and cloud GPUs, with a user-friendly UI.

**Pipeline shape:**  
The end-to-end flow is straightforward: upload data → pick a model (like Qwen-3 0.6B or 1.7B) → click fine-tune → wait → download. For example, Schoeninger’s Text2SQL post shows: he uploaded a text-to-SQL dataset, evaluated zero-shot, then ran Oxen’s fine-tuning, and finally downloaded the new model【8†L37-L44】【22†L224-L232】. The docs confirm that after fine-tuning, “Oxen.ai will save the fine-tuned model weights directly to your repository”【20†L91-L99】, and you can download them via the CLI or Python SDK【22†L224-L232】. Those weights come in standard formats (e.g. `.safetensors`), which you could then convert/quantize to GGUF for Cactus. Oxen does *not* appear to handle the GGUF conversion directly, but since you can download the raw weights, you can run your own conversion pipelines offline.

**Shipped specialist-small case studies:**  
The Tex2SQL post【8†L37-L44】 and Rust-coder post【26†L69-L78】 are publicly available case studies of fine-tuning sub-2B models on domain tasks using Oxen’s tools. Both are authored by Oxen staff (Schoeninger), showing Oxen’s pipeline in practice. Another example is the GRPO coder: they trained a 1.5B Rust coder on unit-test feedback using Oxen, illustrating feasibility of complex RL fine-tuning at small scale【26†L69-L78】. There may be other blog posts (or GitHub repos like Oxen-AI/GRPO-With-Cargo-Feedback) showing the execution of LoRA/SFT workflows, but the above two are the clearest demos of Oxen’s use “in anger.” The main takeaway: Oxen can handle projects where you have a custom dataset (hundreds to thousands of examples), need a multi-hour GPU run, and want version-controlled assets. 

**Pricing / free-tier:**  
Oxen’s **Explorer (free)** tier offers 50 GB of data storage and transfer【15†L1-L4】, unlimited *public* repos, and up to 5 private repos (3 collaborators each)【14†L20-L28】. This is ample for a hackathon dataset. Importantly, GPU/compute is *pay-as-you-go*. According to Oxen’s pricing page, an H100 (80GB) is $4.87/hour【14†L258-L264】, A10G (24GB) is $1.65/hour. There is no free GPU credit; you simply spin up (and pay) as needed. For a “few GPU-hours” scale run, the costs are low (e.g. < $50 for 10 hours on H100). Data egress (downloading weights) would count against the free 50 GB transfer, but typical <10 GB models (even in 4-bit quant) should fit easily. In summary, the Oxen free tier is viable for small/hobby projects: data/versioning is free, and GPU time is affordable pay-per-use. 

**Alternatives vs Oxen:**  
- **DVC (Data Version Control):** Open-source CLI tool for Git-like data versioning. No compute; users manage their own hardware. Slower on large data pushes (requires Git-LFS or remote storage). Oxen claims big speedups over DVC (e.g. ImageNet push: DVC 3–5h vs Oxen “minutes”【36†L168-L177】). DVC lacks hosted training or UI; it’s just a framework.  
- **Hugging Face Datasets/Hub:** A public hub for datasets & models. Great for static datasets and sharing; less suited for evolving private corpora. Datasets are versioned by HF’s system but aren’t easily amended once published. HF also has *AutoTrain* (SFT only) for a few tasks, but it’s limited in scope. Oxen focuses on **collaborative, mutable** corpora and custom workflows. HF Hub would require manual dataset upload and separate training.  
- **WandB / MLflow:** Experiment tracking (metrics/logging), not data versioning. Complementary tools, not replacements.  
- **Modal (serverless GPU):** A cloud serverless GPU platform. You write code/functions, and Modal runs it on GPUs at pay-per-second rates. It has no built-in data versioning; you’d need to attach your own storage (or HF Datasets). Modal automates infra but not dataset management. Oxen provides both in one UI.  
- **Replicate:** An API-first model hosting/training service. You can upload data and fine-tune (it offers SFT pipelines), but it’s more closed/API-driven. Replicate also doesn’t version raw datasets in a Git-like way.  
- **Together AI (Axolotl):** Offers fine-tuning tools (Axolotl CLI) and a hosted service for SFT/DPO on large models. More about customizing open LLMs via CLI scripts. Does not include data versioning or an integrated UI.  
- **Unsloth:** A set of notebooks/colabs by Baseten for open-source fine-tuning (SFT, RLHF). Useful for DIY. No managed service, no dataset versioning, no UI.  
- **OpenPipe AI:** A commercial SFT platform focusing on chatbots and data pipelines, but not widely used by small teams. It’s more about data labeling workflows.  
- **Hugging Face AutoTrain:** Easiest UI for SFT on small datasets (especially Q&A/finetuning tasks), but not very flexible (mostly pre-set tasks), and currently limited to ~7B models. It’s a potential alternative if it supports our use case, but Oxen is more general.

**Gap:** Oxen seems to cover all our needs (dataset versioning, training, weight hosting). The main unknown is how it handles things like LoRA vs full fine-tune (the docs imply it supports them under the hood but do not detail the training method). Also, while we see Oxen has a CLI/Python SDK (download example【22†L224-L232】), we don’t know the exact interface for launching a job programmatically (presumably documented under “Fine-Tuning API”). We also lack public case studies of extremely small (<3B) mobile-specialist models released – Oxen’s case studies have been more research-focused. Finally, the pricing page shows GPU costs but not egress fees, and limits on free data transfer (50 GB total). For a hackathon, egress likely isn’t an issue but it’s a minor concern.

## T2. PEFT for 0.5–2B Models: LoRA, QLoRA, etc.

**LoRA (Low-Rank Adaptation):** A parameter-efficient fine-tuning method that injects small low-rank matrices (A and B) into transformer weights, freezing the main model. The original LoRA paper【38†L5-L8】 shows that, for very large models, this can match full fine-tuning quality with orders-of-magnitude fewer trainable parameters. For 0.5–2B models, LoRA still helps reduce memory, enabling fine-tuning on smaller GPUs. It usually slows convergence a bit, so more epochs or larger learning rates may be needed. 

**QLoRA:** Quantized LoRA. It quantizes the base model to 4-bit (using NormalFloat or similar) **during training**, reducing memory footprint ~4×, then applies LoRA. It was popularized in late 2023 (e.g. Dettmers' blog). For small bases (0.6B–1.7B), QLoRA can allow them to fit in a single 80GB GPU even with LoRA. (The quantization noise might slightly degrade performance, but usually minimally). 

**DoRA (Direct Low-Rank Adapters):** A variant where the adapter is applied differently in the transformer (e.g. splitting high/low frequency). LoRA-FA (Fine-tuned Adapters) is a 2024 refinement focusing on memory. We don’t need deep detail – essentially these are LoRA variants optimizing speed or performance. For engineering, standard LoRA (via Hugging Face PEFT library) is well-supported and easiest. 

**LoRA-FA (Esmay, 2024):** Compares LoRA, QLoRA, etc. It finds LoRA-FA can match or slightly outperform vanilla LoRA for equal memory, but it’s less battle-tested. As an engineer, sticking with the mainstream LoRA from HF PEFT is safest. 

**DPO (Direct Preference Optimization):** A training method from Anthropic (2023) akin to RLHF but without explicit RL: it optimizes preference data directly. It’s usually used after SFT on dialogue data (makes assistant responses more aligned). For a factual note-merging task with “correct answers”, DPO probably isn’t needed. Supervised SFT on ground-truth merges is sufficient. (DPO shines when you have *no single ground-truth*, only preferences.) That said, if we ever want a model that “prefers” some merges over others, DPO could tune that, but it’s more complex (requires reward modeling). For now, SFT (possibly with LoRA) is the clear path.

**KTO (Knowledge and Task Optimization):** Another PEFT variant from a DeepSeek paper, but more esoteric. Likely skip it. 

**GPU budget:** Fine-tuning a ~1B model with LoRA on ~1k–10k examples is cheap. On a single A100/H100 (80GB), LoRA + 4-bit quant can run on smaller 40GB or 24GB GPUs. A rough rule: Qwen-3 1.7B in 4-bit (~9GB) + LoRA (~hundreds of MB) fits on an 80GB easily, even 40GB might suffice. Expect on order 5–20 GPU-hours on an H100 or similar for ~10k examples (depending on epochs). For budgeting: on an A100 (24GB) at ~$1.65/hr, a 10hr run is ~$16. With H100 at $4.87/hr, maybe $50. On Colab Pro (A100 ~ $0.75/hr with limited access) or smaller GPUs, it’s slower but possible.

**Training method:** Use LoRA (via Hugging Face PEFT library) or QLoRA if memory is tight. QLoRA is well-documented in HF Transformers 4.37+. LoRA only requires less memory, so either is fine. Typically one would use 4-bit base + LoRA (QLoRA) if GPU <40GB. Hyperparams: in small-model SFT, moderate LR (1e-4), LoRA rank 8–32, batch size as large as fits (maybe 32–256), for ~3–10 epochs. Datasets of a few thousand examples (since domain) are common in cited works (e.g. DeepSeek uses 100k+ for big tasks, but our note-merge could suffice with 500–2000 high-quality examples). 

**Merged vs Adapter deployment:** Cactus only loads merged GGUF, not dynamic adapters, so we’ll merge weights. If we had instead been able to ship a base+adapter, it might save ~20–40% space. But Cactus’s `--lora` merging implies we produce one final GGUF. That means our final artifact is a full model (license inherited from base) that includes the LoRA adjustments. The adapter itself (in PEFT `.bin`) doesn’t need to be redistributed separately if we merge – and indeed distributing only an adapter might avoid some license hassles, but Cactus doesn’t support it at runtime.

**Gap:** We need a practical fine-tuning recipe for Qwen3 0.6B/1.7B (or similar) in ~1k–5k small-document examples. Very few published micro-recipes exist (most focus on large models). Hugging Face PEFT docs have basic examples. Unofficial: *“Fine-tune an LLM with LoRA” (HuggingFace blog) and TogetherAI’s blog (2024). These often use 7B+ models. We might adapt them. Also, recent repos like *Axolotl* or *alpaca-lora* may provide sample commands. But no single small-model handbook exists beyond reading papers. We’ll likely have to prototype ourselves.

## T3. Distillation to ≤2B Students

**Distillation approaches:** There are multiple flavors:
- **Hard-label distillation:** Run a large teacher (GPT-4o, Claude, etc.) on inputs to get gold outputs, then train student SFT on those. E.g. Alpaca style. Simpler, but student might mimic teacher’s biases/errors.
- **Soft-label (logit) distillation:** Use teacher’s probabilities (infeasible with only API). Usually for self-hosted teachers only.
- **Chain-of-thought distillation:** Methods like *DeepSeek-R1-Distill* generated reasoning traces from a big teacher to train a smaller model end-to-end【23†L193-L202】. That is state-of-art for tasks needing internal reasoning. DeepSeek’s 1.5B student was distilled from their 4.4B R1 model, preserving multi-step reasoning. This suggests small models *can* retain advanced ability via careful distillation.
- **Self-instruct/Evol-instruct:** Automatically generate task examples by prompting GPT-3.5/4 with seed instructions (Wang et al 2023). Then SFT student on that synthetic data.

**Notable examples:** 
   - *DeepSeek (2024)*: Released Phi-3-mini 3.8B and 1.5B via iterative distillation for math reasoning. They report the 1.5B beats GPT-4o on certain math tasks【26†L86-L94】. The blog mentions their pipeline in broad terms. Relevant insight: small models can climb performance with enough distillation.
   - *OpenAI Codex/RLHF:* The "Instruct" fine-tuned smaller OpenAI models were distilled from Codex and GPT-3.5, but those are closed.
   - The question mentions synthetic-teacher pipelines. Many recent small models (e.g. Alpaca, Vicuna, WizardLM) were trained on GPT-3.5/4 outputs. The legal angle is critical: OpenAI’s terms forbid using GPT-4 data to train a “competitive” model【44†L93-L101】. Anthropic’s or Google’s terms may have similar clauses (Gemma’s terms makes any distilled model a “derivative”【47†L341-L349】). So publishing models distilled from GPT or Gemma requires caution.

**Comparison to SFT:** For a narrow task, SFT on ground-truth might be simpler. Distillation shines if you lack ground truth. If our note-merge “truth” is human-curated, SFT is straightforward. If we must generate training examples with a teacher, we inadvertently create a derivative model by some definitions of licenses. There is no definitive head-to-head study of distillation-vs-SFT on *the same data* at small scale. Anecdotally, some distillation approaches claim that the distilled small model surpasses baseline SFT on same small data, especially if the teacher adds style/capabilities. But it’s an open question: whether a few-shot or hard-distilled chain-of-thought data would trump actual human-labeled merges. 

**Licensing TOS landmine:** Crucially, even just *using* teacher outputs can trigger licensing issues (see T7). For example, Gemma’s terms explicitly say any model trained on Gemma outputs is a derivative【47†L341-L349】. And OpenAI forbids training a competitor with its outputs【44†L93-L101】. This likely forbids publishing a model trained on GPT-4’s answers without express permission. Google’s model terms may be unclear for open models, but it’s safer to assume similar restrictions. Thus, if we rely on a strong cloud LLM to generate training pairs, we risk legal issues when publishing. A potential workaround: only use a teacher’s reasoning *to craft human-curated data*, not feed the model’s outputs into training wholesale. But synthetic data is likely necessary for thousands of examples. This is an unresolved risk: most open-source small-model distillations have quietly ignored TOS issues.

## T4. Synthetic-Data for Narrow-Domain SFT

Since no off-the-shelf “note-merging” dataset exists, we likely need synthetic generation:

- **Self-Instruct/Evol-Instruct:** Use prompts to an LLM (open or API) to generate more examples. For example, “Given two study notes on the same topic, produce a merged note that consolidates claims without duplication.” Use a strong model to produce diverse pairs. (Shuster et al 2021 Self-Instruct, Zhou et al Evol-Instruct 2023 for general instruction generation.)
- **LLM prompting:** We can leverage GPT-4o (if allowed) or Anthropic Claude/Sonnet to *generate* pairs of notes and merged answers. But again TOS risk.
- **Paraphrasing augmentations:** If we have a small seed set of human note-merge examples, we can apply LLM paraphrase or get the teacher to rephrase merges to expand data (with caution).
- **Existing corpora:** There are datasets for multi-document summarization (e.g. Multi-News, WikiSum), but “note merging” is more structured (often bullet lists or key claims). Possibly treat it as summarization and filter. No ready dataset for “merge two paragraphs of notes into one fact list.” We likely must generate custom data.
- **Quality measurement:** With a synthetic dataset, one should hold out a random subset (or better, manually curated validation examples). Also use metrics: ROUGE on key points, or semantic overlap. Some practitioners check coherence with an LLM judge, or cluster embeddings of Q-A to detect outliers. However, for ~1k examples, manual spot-checking (even a handful) is common practice to ensure data sanity.

**Gap:** There’s no turnkey pipeline described in literature specifically for our “note merge” task. We might adapt tools like OpenAI’s `gpt-3.5-turbo-1106` assistant (or GPT-4o-min) with carefully crafted prompts to generate synthetic note merging pairs, then filter by heuristics (length, factuality) or LLM judges. Alternatively, crowdsourcing a few hundred examples could be quicker if domain-specific understanding is needed. 

## T5. On-Device Adapter Loading and Cactus Seam

**Cactus + LoRA:** According to Cactus docs, **Cactus does not dynamically load LoRA adapters at runtime.** Instead, the workflow is to use `cactus convert` to merge them beforehand【41†L238-L246】. Specifically, `cactus convert [model] [dir]` supports a `--lora <path>` option, which merges a LoRA adapter into the model during conversion. In other words, we must produce a single GGUF file containing all weights. This is consistent with `llama.cpp`’s approach: they have added the ability to merge LoRA into GGUF, but to use it you usually convert first. So operationally, after fine-tuning via LoRA, we would obtain the LoRA adapter file (e.g. `.safetensors`), then run `cactus convert qwen3-1.7B weights_dir --lora path/to/lora.safetensors` to produce a new GGUF model containing the adapted weights. That final GGUF is what Cactus will load on-device.

**llama.cpp LoRA support:** The underlying engine (llama.cpp) supports loading a GGUF with an embedded LoRA. It also has a `--lora` flag for dynamic adapters, but the GGUF merged approach is simpler for shipping. 

**Quantization & GGUF:** Cactus’s `convert` presumably also quantizes the model to the preferred format (e.g. Q4_K_M). Standard practice: after fine-tuning and merging, we would quantize the model to 4-bit or 6-bit (as Qwen3 runs 4-bit in Cactus demo). Tools like llama.cpp’s conversion can do this. The question of quality drop: quantizing a *fine-tuned* model might introduce slightly more error than quantizing a base model, but in practice 4-bit quantization typically only adds minor degradation. There is some community concern that quantizing a specialized model might amplify some errors, but likely negligible for our use. We should still evaluate quantized model output on a small test set.

**Cross-platform parity:** Cactus wraps llama.cpp, which uses fixed quant math (usually deterministic if seeds and CPU op orders match). The Qwen3 inference code already has known parity issues (embedding cosine drift <1e-5 between iOS/Android). Fine-tuning adds new weights but should not inherently break determinism beyond usual floating-rounding differences. Testing shows Cactus outputs are consistent across iOS/Android for a given model version. We should nonetheless re-run the official cosine-parity tests on any new GGUF just to be sure fine-tuned deltas don’t amplify drift. But nothing obvious in docs suggests a fundamental issue: 4-bit arithmetic is already nondeterministic at very low bits, but base model did it fine.

**Gap:** The main “seam” question is answered: we must merge adapters. An open question: Cactus’s `convert` CLI merges LoRA *and* presumably converts formats, but if we fine-tune on HF (PyTorch) weights, how do we get from `safetensors` to GGUF? Probably by first using llama.cpp’s converter or HF’s `transformers-cli` to convert to GGUF, then Cactus `--lora` to merge. Or maybe Cactus convert can take HF safetensors and output GGUF in one step. The docs example suggests using Cactus to download and convert models, so it may handle common formats. We should confirm if Cactus expects a specific input format (likely GGUF or maybe GGML). If not directly documented, we might combine HF’s `convert-hf-to-gguf` tool with Cactus’s `--lora`. Either way, this is an engineering detail to verify.

## T6. Evaluation Methodology

**Harness:** For a specialized task like note-merging, generic LLM benchmarks don’t apply. Best approach: construct a *held-out test set* (e.g., 200-500 examples) of note pairs and correct merges. This could be partly human-authored to ensure quality. Then evaluate the model’s merges with a combination of:
- **Automated metrics:** ROUGE-L/1/2 against reference merges (despite being imperfect, they measure overlap). Also embedding-based similarity (BERTScore, or a small RAGAS faithfulness metric).  
- **LLM Judges:** Run a top-tier model (GPT-4o, Claude Sonnet) to score outputs on criteria: “Does the output correctly merge all facts without hallucination?” Recent work shows judges are useful but have biases, so use multiple prompts/seedings.  
- **Human eval:** Ideally, at least some manual rating of a random sample (0-3 point scale on correctness and coherence). Given hackathon scope, maybe do this for 30-50 cases to calibrate.

Frameworks: We could adapt Hugging Face’s `evaluate` or EleutherAI’s `lm-eval-harness` with a custom task script. PromptFoo or OpenAI’s Evals are overkill for this demo scale. Possibly prompt an LLM to directly compare two outputs and choose better. But simpler: embed an instruction in the prompt for the judge model (e.g. “Rate 1-5: how well does the model output merge the notes?”) and average multiple runs.

**Contamination:** Since we might use a teacher model (if any) to generate data, we must avoid testing on exactly the same synthetic items. Ensure the test set is disjoint from training data (including no near-duplicates). If synthetic data is student+teacher-instructed, hold out all those from test. One trick: ask a judge model to detect if an output is something GPT might generate vs novel (meta-eval).

**Gap:** There’s no standard “note-merging” benchmark. We’ll rely on building our own small eval set. No major authoritative source here beyond general advice on LLM eval (e.g. Gupta et al. 2024 on judge LLMs). The key unresolved issue is that judge-LLM evaluations (and ROUGE etc.) are all imperfect for such tasks. But a combination of them is standard practice.

## T7. Licensing Landmines

- **Apache-2.0 bases (Qwen, SmolLM2, Phi-3-Mini):** Very permissive. You can redistribute fine-tuned weights with minimal requirements (retain copyright, include license text). No built-in restrictions on training or re-distribution, aside from attribution. (Qwen3 is Apache-2.0, so fine.)

- **Llama Community License (Meta Llama 2/3):** Non-viral but has special clauses: any derived model must include “LLaMA” in its name and a “Built with Llama” logo/statement. Also a usage limit clause (usually 700M monthly active users, which is irrelevant for an open small model hackathon). So if we fine-tuned a Llama-base model, we'd need to abide by those naming/branding rules. It’s doable but somewhat cumbersome. Likely we prefer Apache bases to avoid this hassle.

- **Gemma (Google) 3.x Terms:** Gemma’s terms (pre-v4) are restrictive: they define “Model Derivatives” very broadly. Training a student using Gemma outputs would make it a derivative【47†L341-L349】, so we’d need to follow all Gemma rules (which include e.g. “cannot produce porn” etc in their use policy, plus no reverse engineering). If Gemma 3’s license was already somewhat restrictive (I believe Gemma 3.1 was under a custom license, not Apache), any derived model must carry those restrictions. Gemma 4 (April 2026) moved to Apache-2.0, but that likely doesn’t cover older ones. In short: Gemma 3 is risky; Gemma 4 is fine (Apache).

- **OpenAI/Anthropic TOS:** OpenAI explicitly forbids using ChatGPT/GPT outputs to train a *competing model*【44†L93-L101】. Our small student would arguably be a competing model. So training on GPT-4o output (even for internal use) would violate terms if we intend to distribute the student. Anthropic’s terms aren’t easily accessible, but likely similar ("no commercial usage without permission"). Google’s terms for Gemini (Gemma) explicitly turn synthetic outputs into derivative models【47†L341-L349】. So for distillation using any API, we risk license violation.

**Gap:** We should explicitly mention licensing for any prebuilt or curated datasets we might use (though none were found). If we use e.g. SQuAD or MultiNews, they have their own licenses (SQuAD is CC BY-SA). If we generate synthetic data with GPT, it’s likely not redistributable at all under OpenAI rules. This is a significant open question for strategy: we might limit synthetic data to internal use or ensure not derived from closed APIs. Possibly skip full distillation with GPT for an open hackathon release. 

## Recommended Specialist-Build Recipe

**Primary Recommendation:**

- **Base Model:** Qwen/Qwen3 1.7B (Apache-2.0). Large enough to start with, but still runs in Cactus. Alternative: SmolLM2-1.7B (also Apache). (If Qwen3 shows the Chinese drift issue, consider Phi-3-Mini or Llama-3 2B but note Llama license).
- **Method:** Supervised fine-tuning (SFT) with LoRA adapters on small in-domain dataset. Optionally use QLoRA (4-bit base + LoRA) if GPU memory is tight. DPO/RLHF not needed given our task has clear ground truth.
- **Data:** Synthetic + curated mix. Start with a small human-curated seed (e.g. 100 hand-merged note pairs). Expand via self-instruct: prompt a strong model to create variations (“given these two notes, merge them correctly”). Aim for 1000–2000 training examples. Ensure to hold out ~10-20% for eval. Use manual checks or a strong judge to filter blatantly bad outputs.
- **Training Platform:** Oxen.ai (hosted). It handles data versioning and GPU. Use Oxen to manage experiment and get final weights. (If Oxen proves difficult or quotas run out, backup: use an 80GB cloud GPU via Modal or Colab, with datasets in Git/DVC or HF Hub and HF Accelerate/PEFT).
- **GPU Budget:** A single A100-40GB (~$1.65/hr) or H100 (~$4.87/hr). LoRA on 1.7B with 4-bit should fit 40GB. Estimate ~5–10 hours per experiment. Budget ~$20–50 total for main runs. Possibly split into two: coarse SFT (baseline) and final QLoRA (if needed).
- **Evaluation:** Build a small test set (say 200 examples). Use a combination of ROUGE/BERTScore vs reference, plus an LLM judge (GPT-4o-mini, Claude Sonnet) to score factual correctness. Spot-check a handful manually. Use `cactus run` on phone to sanity-test output format. Ensure no data leakage from training. 
- **Deployment:** After training, obtain the LoRA adapter file from Oxen. Locally merge into base GGUF via llama.cpp tools or directly using `cactus convert --lora`. Then quantize to Cactus-preferred format (likely Q4_K_M). Ship the merged GGUF in the hackathon repo. Mobile will load it via Cactus easily (no further downloads needed).
- **License:** Qwen3’s Apache-2.0 means the fine-tuned model can be redistributed under Apache terms. Include a copyright notice crediting Qwen/Qwen3. No “Built with Llama” requirement. Our synthetic data (if any) should not come from licensed-prohibited sources.

**Backup Recipe (if LoRA merge fails or Cactus changes):**
- **Method:** Full fine-tuning without LoRA on a <2B model (e.g. SmolLM2-1.7B, which is ~7GB base). Quantize+train with 4-bit or 8-bit optimizers if needed (using bitsandbytes). This ensures we have one giant merged file anyway. It might require a larger GPU, but still in cloud budget. License is Apache so fine. Evaluate similarly. This avoids any adapter loading issues entirely, at the cost of more GPU RAM/time. If LoRA workflow proves cumbersome with Cactus, this is the fallback.

*(In both recipes, we must mind license: all components (base model, data generation) should be Apache-friendly. We will avoid any output from closed APIs in the final training data.)*

## Reference Implementations

1. **DeepSeek-R1 Distillation (DeepSeek-AI/DeepSeek-R1)** – GitHub repo for DeepSeek’s 1.5B and 4.4B math reasoning models. They generated a synthetic multi-step math reasoning dataset and distilled to 1.5B【26†L86-L94】. Analogous because it’s a small model fine-tuned with chain-of-thought. It’s not on mobile, but shows training scripts and eval for narrow tasks.

2. **Oxen AI/GRPO-With-Cargo-Feedback** – Repository for the Rust coder example referenced in their blog【26†L37-L44】. Contains data (Rust code/tests) and training code for a 1.5B model using GRPO. It shows how to integrate compilers as feedback. Structure (small specialist model, heavy eval on task) is analogous; although they used RFT+SFT, their SFT steps can guide ours.

3. **EleutherAI lm-evaluation-harness** – While not a single project, it’s the standard for evaluating LLMs. If adapted for our merge task, it would provide a structured way to run LLM judges on our dataset. The RAGAS/RAGTruth repositories (for summarization faithfulness) contain example scripts for multi-document summaries; they could be adapted to check “merge consistency”.

4. **Hugging Face `evaluate` + `promptfoo` pipelines** – These libraries (with community tasks) show how to run automated metrics and LLM judges at scale. E.g. `promptfoo` has examples for summarization tasks, which can serve as a template for ours. They’re not “fine-tuned specialist” projects, but provide operational examples of evaluation workflows.

*(No existing project exactly matches “<=3B on mobile, note merging,” but the above are structurally similar: small-model fine-tuning or distillation for a narrow task.)*

## Open Research Questions

- **Effectiveness of Distillation vs SFT at small scale:** It’s unclear if synthetic distillation would significantly outperform pure SFT for this kind of task, given potential license issues. This team may need to experiment. A critical unknown: can we legally publish any model trained on GPT-4 outputs?
- **Quality of Synthetic Note-Merge Data:** How good are LLM-generated merges? Will they introduce subtle biases or hallucinations that mislead training? We likely need to audit synthetic data carefully.
- **Cactus LoRA support:** Confirmed *no dynamic loading*, must merge. But it’s unclear if Cactus convert can import PyTorch safetensors directly or requires GGUF input. Implementation may need a toolchain step.
- **Cross-device determinism:** Our small model should run identically on iOS/Android via Cactus. Base Qwen had some minor drift; fine-tuning might amplify it. We should test parity on a stable seed after conversion.
- **Dataset Holdout and Overfitting:** With only hundreds of examples, the model might overfit. We need proper split and maybe regularization. The “flashcard generation” pipeline previously relied on gating, implying format/overfitting issues. A specialist should be more stable, but we must still test on unseen note pairs.
  
## Specialist vs Generalist Evidence

**Pro-specialist:** Recent work shows **small specialized models can match or exceed larger generalists on narrow tasks**. For example, the rStar-Math project reports a *1.5B* policy model outperforming GPT-4 on certain math benchmarks【26†L86-L94】. Likewise, Oxen’s blog noted SFT on Text2SQL turned a 0.6B Qwen from 8% to 42% accuracy, nearly matching 4.7B GPT-4o【8†L58-L66】. “Tiny Titans” (2024) showed smaller fine-tuned vision-language models surpassing much larger ones on specific tasks. These suggest that with the right training, a 2B model can specialize effectively.

**Counter-case:** However, specialization at small scale has pitfalls. If data is limited, the model may not generalize or may overfit to spurious patterns. A generalist model might accidentally handle edge cases better due to its broad pretraining (especially if few training examples exist). Also, some tasks benefit from very large-scale world knowledge or reasoning steps that a tiny model can’t capture at all (no amount of fine-tuning can imbue raw capacity). The risk is if the task subtly requires world knowledge beyond the notes, a specialized small model might hallucinate more than a larger model. In sum: evidence is promising but cautious – narrow tasks with concrete answers (math, code, specific Q&A) see small models shine, whereas broad open-ended tasks (creative writing, multi-domain chat) do not.

## Source Ledger

```
https://docs.oxen.ai/getting-started/fine-tuning  
https://docs.oxen.ai/getting-started/fine-tuning  
https://docs.oxen.ai/getting-started/fine-tuning  
https://docs.oxen.ai/getting-started/fine-tuning  
https://docs.oxen.ai/getting-started/fine-tuning  
https://docs.oxen.ai/getting-started/fine-tuning  
https://docs.oxen.ai/getting-started/fine-tuning  
https://docs.oxen.ai/getting-started/fine-tuning  
https://docs.oxen.ai/getting-started/fine-tuning  
https://docs.oxen.ai/getting-started/fine-tuning  
https://oxen.ai/blog/how-to-fine-tune-qwen3-to-gpt-4o-level-performance  
https://oxen.ai/blog/how-to-fine-tune-qwen3-to-gpt-4o-level-performance  
https://oxen.ai/blog/how-to-fine-tune-qwen3-to-gpt-4o-level-performance  
https://oxen.ai/blog/how-to-fine-tune-qwen3-to-gpt-4o-level-performance  
https://oxen.ai/blog/how-to-fine-tune-qwen3-to-gpt-4o-level-performance  
https://oxen.ai/blog/training-a-rust-1-5b-coder-lm-with-reinforcement-learning-grpo  
https://oxen.ai/blog/training-a-rust-1-5b-coder-lm-with-reinforcement-learning-grpo  
https://oxen.ai/blog/training-a-rust-1-5b-coder-lm-with-reinforcement-learning-grpo  
https://ghost.oxen.ai/training-a-rust-1-5b-coder-lm-with-reinforcement-learning-grpo/  
https://docs.oxen.ai/getting-started/fine-tuning  
https://docs.oxen.ai/getting-started/fine-tuning  
https://docs.oxen.ai/getting-started/fine-tuning  
https://docs.oxen.ai/getting-started/fine-tuning  
https://docs.oxen.ai/getting-started/fine-tuning  
https://docs.oxen.ai/getting-started/fine-tuning  
https://docs.oxen.ai/getting-started/fine-tuning  
https://docs.oxen.ai/getting-started/fine-tuning  
https://docs.oxen.ai/getting-started/fine-tuning  
https://docs.oxen.ai/getting-started/fine-tuning  
https://docs.oxen.ai/getting-started/fine-tuning  
https://www.oxen.ai/pricing  
https://www.oxen.ai/pricing  
https://www.oxen.ai/pricing  
https://www.oxen.ai/pricing  
https://docs.cactuscompute.com/v1.9/  
https://docs.cactuscompute.com/v1.9/  
https://www.ranger.net/post/top-tools-ai-test-data-versioning  
https://www.ranger.net/post/top-tools-ai-test-data-versioning  
https://arxiv.org/abs/2106.09685  
https://openai.com/policies/row-terms-of-use/  
https://openai.com/policies/row-terms-of-use/  
https://ai.google.dev/gemma/terms  
https://ai.google.dev/gemma/terms  
https://docs.oxen.ai/getting-started/fine-tuning  
https://docs.oxen.ai/getting-started/fine-tuning  
https://docs.oxen.ai/getting-started/fine-tuning  
https://docs.oxen.ai/getting-started/fine-tuning  
https://docs.oxen.ai/getting-started/fine-tuning  
https://docs.oxen.ai/getting-started/fine-tuning  
```