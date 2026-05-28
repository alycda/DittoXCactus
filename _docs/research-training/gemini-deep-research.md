# **Post-Training and Specialization of Small-Scale Language Models for Decentralized Mesh RAG**

Decentralized mesh architectures represent a significant paradigm shift in peer-to-peer data processing. By maintaining localized, conflict-free replicated data type (CRDT) vector indices across mobile devices, document retrieval and search operations remain highly available without relying on central cloud systems.1 However, deploying generalized foundation models on low-resource devices presents severe limitations in output stability, formatting fidelity, and factual grounding.2 This report outlines the engineering design, technical trade-offs, and operational recipes required to train a localized, highly specialized language model under 2.0 billion parameters. The target model executes high-fidelity study-note merging, deduplication, and structured flashcard generation within the strict constraints of on-device runtimes.

## **Top 10 Must-Read Sources**

### **1\. Cactus Compute Core Repository and Documentation**

* **URL:** https://github.com/cactus-compute/cactus 1  
* **Annotation:** This framework serves as the core local execution substrate on mobile devices. It provides native wrappers around llama.cpp for iOS and Android platforms, optimizing for zero-copy memory mapping and ARM CPU/NPU acceleration.1 Its compilation scripts, environment configurations, and Foreign Function Interface (FFI) bindings represent the primary execution path for on-device inference.4

### **2\. Edward J. Hu et al., "LoRA: Low-Rank Adaptation of Large Language Models"**

* **URL:** https://arxiv.org/abs/2106.09685 6  
* **Annotation:** This foundational paper establishes the parameter-efficient adaptation paradigm. It details the mathematics of low-rank matrix decomposition, proving that fine-tuning can be restricted to auxiliary matrices to reduce trainable weights by 10,000x while maintaining zero additional inference latency after merging weights.6

### **3\. Unsloth Optimization Framework**

* **URL:** https://github.com/unslothai/unsloth 8  
* **Annotation:** A highly optimized Python training framework that utilizes custom Triton and mathematical kernels. It delivers 2-5x faster training speeds and up to 70% VRAM reduction on single-GPU hardware, defining the modern standard for cost-efficient model customization.8

### **4\. Magpie: Alignment Data Synthesis from Scratch**

* **URL:** https://github.com/magpie-align/magpie 10  
* **Annotation:** Establishes a zero-prompt synthetic dataset engineering framework. By leveraging the auto-regressive nature of aligned instruction models when prompted only with their pre-query chat templates, it generates highly diverse, instruction-following datasets without prompt engineering bias.10

### **5\. DeepSeek-R1 Technical Report & Model Card**

* **URL:** https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-1.5B 12  
* **Annotation:** Demonstrates that complex logical reasoning patterns and strict formatting capabilities can be distilled from frontier mixture-of-experts (MoE) architectures into compact, highly efficient student models (such as the 1.5B Qwen-based variant) using curated reasoning-trace datasets.13

### **6\. Llama-cpp-capacitor Plugin Core**

* **URL:** https://github.com/arusatech/llama-cpp 15  
* **Annotation:** A production reference for embedding offline inference runtimes within cross-platform mobile environments. It validates execution parameters, context allocation strategy, multi-threaded CPU pinning, and speculative decoding setups on iOS and Android devices.15

### **7\. Tim Dettmers et al., "QLoRA: Efficient Finetuning of Quantized LLMs"**

* **URL:** https://arxiv.org/abs/2305.14314 16  
* **Annotation:** Introduces 4-bit NormalFloat (NF4) quantization, double quantization, and paged optimizers to reduce training memory footprint. This allows the post-training of multi-billion parameter models on single consumer-grade GPUs with zero performance degradation compared to standard 16-bit LoRA.16

### **8\. Rafael Rafailov et al., "Direct Preference Optimization: Your Language Model is Secretly a Reward Model"**

* **URL:** https://arxiv.org/abs/2305.18290 18  
* **Annotation:** Defines a stable, reinforcement-learning-free alignment protocol. By optimizing parameters directly on pairwise preference data using a simple classification-like loss function, it bypasses the massive compute footprint and architectural complexity of traditional reward-modeling pipelines.3

### **9\. DeepEval Automated LLM Testing Framework**

* **URL:** https://deepeval.com/docs/introduction 19  
* **Annotation:** Establishes a localized, unit-testing architecture designed for continuous integration. It enables programmatic evaluation of retrieval relevance, factual faithfulness, and schema compliance, replacing subjective evaluation with deterministic test metrics.19

### **10\. llama.cpp Main Repository**

* **URL:** https://github.com/ggml-org/llama.cpp 21  
* **Annotation:** The core open-source implementation for running high-performance local inference on commodity hardware. It optimizes tensor operations across diverse backends (CPU, Apple Metal, Android NPU) and serves as the direct technical substrate for the Cactus engine.22

## **Per-Topic Findings**

### **T1. Oxen.ai's Surface Area and Training Pipeline**

* **Primary Sources:**  
  * https://docs.oxen.ai/fine-tuning-api/overview (Oxen-AI, 2026\) 24  
  * https://github.com/Oxen-AI/Ollamox (Oxen-AI, 2025\) 25  
  * https://ghost.oxen.ai/how-to-train-a-ltx-2-character-lora-with-oxen-ai/ (Oxen-AI, 2025\) 26  
  * https://ghost.oxen.ai/writing-a-fine-tuning-and-deployment-pipeline-isnt-as-easy-as-it-looks-gemma-4-version/ (Oxen-AI, 2026\) 27  
* **What it gives us:** Oxen.ai functions as a version-controlled repository structure optimized for model weights and dataset assets, combining data versioning with a managed, cloud-hosted API training runner.24 Fine-tuning is structured through a standardized JSON payload detailing raw text columns mapped directly to task inputs (e.g., question/answer columns), returning a tiny safetensors adapter file.24  
* **Gap:** Oxen.ai simplifies dataset-to-adapter workflows, but it does not natively execute weight merging or GGUF quantization. Developers must manually write scripts to download the adapters, merge them with original base weights, and convert the resulting files via local llama.cpp compilation loops.25

Oxen.ai acts as an integrated Git-like data lake and training orchestrator, separating itself from platforms that decouple dataset storage from the compute layer.24 Contrastive architectural analysis highlights the distinct boundaries between platforms:

| Platform | Core Functional Focus | Strengths | Operational Gaps |
| :---- | :---- | :---- | :---- |
| **Oxen.ai** | Versioned data hosting with managed API training 24 | Single-click training loops; combined tracking of data and adapters 24 | No direct GGUF conversion pipeline in the cloud interface 25 |
| **Modal** | Serverless GPU compute containers 9 | High developer flexibility; per-second billing 9 | Requires manual dockerization, scripting, and pipeline setup |
| **Replicate** | Serverless model execution API | Fast API deployments; zero-config inference | High compute-egress costs; disconnected from data versioning |
| **Together AI** | Managed serverless fine-tuning API | Highly scalable; simple token-based pricing | No data versioning features; relies on standard HF templates |
| **OpenPipe** | API-driven data collection and distillation | Streamlined data filtering and logging | High premium cost; locked into proprietary data pipelines |
| **Unsloth** | Ultra-fast single-GPU local framework 8 | 2-5x speedup; custom Triton kernels 8 | Restricted to single-GPU workstations; no native hosting |
| **Axolotl** | Configuration-driven multi-GPU fine-tuning 9 | Granular PEFT controls; reproducible YAML setups | High learning curve; manual infrastructure provisioning |
| **HF AutoTrain** | No-code managed training GUI | Simple web interface; direct HF Hub integrations | Limited hyperparameter adjustments; higher compute premiums |

Practical case studies of models trained via Oxen.ai show the platform's utility on narrow, resource-constrained tasks. For example, a character training workflow using the LTX-2 model cost approximately $10 in total GPU compute.26 For text generation, the Ollamox project demonstrates downloading custom safetensors adapters (such as adapter\_model.safetensors and adapter\_config.json) trained on Oxen.ai, and merging them with standard bases before compiling the outputs.25

### **T2. PEFT for Small Base Models: LoRA, QLoRA, DPO, SFT**

* **Primary Sources:**  
  * https://arxiv.org/abs/2106.09685 (Hu et al., 2021\) 6  
  * https://arxiv.org/abs/2305.14314 (Dettmers et al., 2023\) 16  
  * https://app.readytensor.ai/publications/fine-tuning-qwen25-15b-for-text-to-sql-generation-kaa6DwgRemd5 (ReadyTensor, 2025\) 17  
  * https://medium.com/@resta.alessandro.3ai/fine-tuning-a-mini-giant-teaching-qwen2-5-1-5b-to-speak-sql-62e960b7e907 (Resta, 2025\) 28  
  * https://pmc.ncbi.nlm.nih.gov/articles/PMC12457693/ (PMC, 2025\) 29  
* **What it gives us:** Low-Rank Adaptation (LoRA) freezes original model weights ![][image1] and injects small, trainable rank-decomposition matrices ![][image2] and ![][image3].6 This reduces parameter updates by several orders of magnitude.7 Standard configurations targeting all linear projections in a 1.5B model yield small adapter sizes (\~65MB) with only \~16M trainable parameters (1.18% of base weights).17  
* **Gap:** Fine-tuning on strict structured tasks (like note merging or JSON formatting) teaches the model to rely on extreme weight values.2 Merging these weights back into the base model and immediately quantizing them down to GGUF Q4\_K\_M can clip these extreme values, causing the quantized model to output garbled text.2

LoRA restricts the forward pass representation of a modified layer to:  
![][image4]  
where ![][image5] is the intrinsic rank (typically ![][image6]) and ![][image7] is a scaling factor.6 To prevent initial model degradation, matrix ![][image8] is initialized to zero while ![][image9] is initialized with a random Gaussian distribution, ensuring ![][image10] at step zero.6 QLoRA improves on this by loading base weights in 4-bit NormalFloat (NF4) representation, allowing a consumer GPU with only 12GB of VRAM to comfortably fine-tune an 8B parameter model through quantized layers.16  
When evaluating alignment strategies, Supervised Fine-Tuning (SFT) is highly effective for teaching the model a specific structured formatting schema.29 However, Direct Preference Optimization (DPO) significantly outperforms SFT on subjective reasoning, multi-document summarization, and task-specific instruction following.18 DPO forces the model to learn from positive and negative preference pairs, adjusting the weights to actively suppress dispreferred behaviors (such as bilingual language drift or verbose prose).29

SFT Loss: Updates parameters based on flat target text matching.  
DPO Loss: Directly adjusts parameters to increase the probability ratio of preferred over dispreferred responses without a reward model.

Empirically, DPO post-training demands approximately 2 to 3 times more compute resources than standard SFT alone 29, making SFT the preferred strategy for initial proof-of-concept setups under tight compute limits.33  
Modern optimization workflows targeting 1.5B models are highly cost-efficient:

* **Hardware Costs:** An RTX 4090 ($0.44/hr on RunPod, or $0.22/hr on spot instances) fine-tunes a 1.5B model on 1,000 samples in roughly 30 minutes, using only \~4GB of VRAM and costing less than one dollar in total compute.9  
* **Hyperparameter Configuration:** A standardized training script uses an 8-bit AdamW optimizer (paged\_adamw\_32bit), a learning rate of ![][image11] with a cosine scheduler, a batch size of 2 to 4 samples, and targeting all linear layers (![][image12]) to capture both semantic content and strict formatting layouts.4

Once trained, the developer must choose between deploying a separate adapter or a merged model. Storing a frozen base model and loading a small adapter dynamically (e.g., via S-LoRA) reduces server storage footprint in multi-tenant environments.30 However, on resource-constrained mobile hardware, running separate adapter calculations introduces a significant latency overhead.7 Per-token soft routing of multiple adapters can slow down text decoding by up to 2.5x unless hardware-specific kernels are compiled.35  
Merging the learned low-rank updates directly back into the base weights (![][image13]) and exporting the model as a unified GGUF file is the only viable path for mobile devices, introducing zero additional inference latency.6

### **T3. Distillation from Larger Teachers to ≤2B Students**

* **Primary Sources:**  
  * https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-1.5B (DeepSeek-AI, 2025\) 12  
  * https://openrouter.ai/deepseek/deepseek-r1-distill-qwen-1.5b (OpenRouter, 2025\) 13  
  * https://www.bentoml.com/blog/the-complete-guide-to-deepseek-models-from-v3-to-r1-and-beyond (BentoML, 2025\) 14  
  * https://arxiv.org/html/2509.16965v1 (Arxiv, 2025\) 37  
  * https://privacy.claude.com/en/articles/7996868-is-my-data-used-for-model-training (Anthropic, 2026\) 38  
* **What it gives us:** Knowledge distillation transfers capabilities from highly parameterized, state-of-the-art teacher models (such as DeepSeek-V3 or Claude 3.5 Sonnet) into compact student models under 2.0 billion parameters.3 The distilled student inherits complex logical reasoning patterns and strict formatting capabilities that reinforcement learning on small models alone struggles to find.3  
* **Gap:** Reasoning-trace distillation (CoT) drastically inflates prompt length and inference latency.14 A distilled model that outputs thousands of "thinking" tokens before providing a final answer can quickly exhaust mobile CPU processing budgets.14

Knowledge distillation pipelines are structured around several core paradigms:

* **Soft-Label Distillation:** Minimizes the Kullback-Leibler (KL) divergence between the output probability distributions of the student and teacher models across both preferred and dispreferred tokens, providing a much denser supervision signal than standard text targets.37  
* **Offline Distillation (Hard-Label):** Involves prompting the teacher model to generate idealized responses for a domain-specific dataset, and subsequently training the student model on those generated outputs using standard SFT cross-entropy loss.37  
* **Reasoning-Trace (CoT) Distillation:** Exemplified by the DeepSeek-R1-Distill family.12 Rather than training the student to mimic flat answers, it is fine-tuned on the intermediate "thinking" tokens generated by a massive reasoning model.12 For example, DeepSeek-R1-Distill-Qwen-1.5B was trained on 800,000 reasoning traces, allowing a highly compact 1.5B student model to significantly outperform equivalent generalists on mathematics and complex reasoning benchmarks.13

When building synthetic teacher pipelines, developers frequently use commercial API endpoints to generate custom training pairs.33 However, this strategy introduces major licensing and Terms of Service (TOS) liabilities.38 The terms of service of OpenAI, Anthropic, and Google explicitly forbid using their model outputs to train competitive machine learning models.38  
While highly difficult to enforce on localized, private applications, distributing a fine-tuned model trained on these datasets in a public repository represents a substantial intellectual property risk.38  
To bypass this constraint, developers should use open-weight frontier models (such as Qwen-2.5-72B-Instruct or Llama-3-70B-Instruct) as synthetic teachers.39 The licenses of these open models explicitly permit utilizing their generation outputs for distillation and student model post-training.39  
On specialized, narrow tasks, direct comparisons demonstrate that distilling structured reasoning data outperforms standard task-specific fine-tuning on identical dataset sizes.41 Empirically, student models fine-tuned on Chain-of-Thought (CoT) synthetic data show a 10% to 15% increase in accuracy on logical task benchmarks compared to standard SFT baselines.41

### **T4. Synthetic-Data Generation for Narrow-Domain Corpora**

* **Primary Sources:**  
  * https://github.com/magpie-align/magpie (ICLR, 2025\) 10  
  * http://distilabel.argilla.io/0.6.0/tutorials/create-evol-instruct-dataset/ (Argilla, 2025\) 42  
  * https://openreview.net/forum?id=nPEWyL8kxO (OpenReview, 2025\) 41  
  * https://www.evidentlyai.com/llm-guide/llm-test-dataset-synthetic-data (EvidentlyAI, 2025\) 43  
* **What it gives us:** Synthesizing custom datasets provides a scalable path for generating training data.43 The Magpie pipeline leverages the auto-regressive pre-training of instruction-tuned models, prompting them with empty formatting templates to generate diverse, instruction-following datasets without prompt engineering bias or seed constraints.10  
* **Gap:** Synthetic data naturally decays in semantic diversity over successive generations.45 This requires secondary verification models to filter out bad formatting or semantic hallucinations before training starts.42

Modern synthetic data pipelines utilize three main paradigms:

* **Self-Instruct:** Starts with a minimal human-written bootstrap pool of 5-10 seed examples.44 The teacher model is then prompted to generate novel instruction variants and corresponding answers, expanding the diversity of the training set from a small seed.44  
* **Evol-Instruct:** Takes existing simple instructions and uses an LLM to progressively complicate them.42 The model adds environmental constraints, increases reasoning depth, concretizes abstract ideas, or mutates the core topic.42 This forces the student model to learn to navigate highly complex instruction formats.44  
* **CoT-Self-Instruct:** Combines instruction generation with planning.41 It instructs the model to generate a plan and intermediate reasoning steps before generating the final answer.41 It then applies self-consistency checks to filter out generations where the generated reasoning path diverges from the final answer.41

To build a robust training set for study-note consolidation, developers must generate a corpus of approximately 1,500 highly curated samples.17 Each sample should contain multiple disjoint, raw study notes (simulating inputs from two syncing devices) mapped to a consolidated, deduplicated Markdown-formatted summary.43  
To protect against evaluation contamination, developers must enforce a strict physical holdout discipline.47 If both the training and evaluation sets are synthetically generated by the same teacher model, the student model may simply memorize the stylistic quirks of the teacher.47  
This is mitigated by slicing the source knowledge base into physically separated partitions prior to dataset generation.43 Training samples must be generated exclusively from Slice A, while evaluation test cases are generated from Slice B, ensuring the test set evaluates real semantic generalization rather than memorized patterns.43  
Furthermore, raw synthetic outputs must undergo a rigorous, multi-stage filtering protocol before training 10:

* **Statistical Similarity:** Compare marginal distributions of synthetic features against real text using statistical tests (e.g., KS Test or KL Divergence) to ensure semantic alignment.49  
* **Exact Match Scores:** Measure string similarities between synthetic records and the raw source knowledge base to ensure the generation process has not reproduced copyrighted texts verbatim.49  
* **Heuristic Filtering:** Scrub out any generations containing typical model refusal strings ("sorry", "as an AI"), structural markup errors, or excessive text repetitions.10

### **T5. On-Device Adapter Loading and the Cactus Seam**

* **Primary Sources:**  
  * https://github.com/cactus-compute/cactus/blob/main/docs/finetuning.md (Cactus, 2026\) 4  
  * https://github.com/cactus-compute/cactus/blob/main/docs/cactus\_engine.md (Cactus, 2026\) 50  
  * https://github.com/cactus-compute/cactus/issues/503 (Cactus, 2026\) 2  
  * https://github.com/arusatech/llama-cpp (Arusa Tech, 2026\) 15  
  * https://github.com/mlc-ai/mlc-llm/issues/3446 (MLC-AI, 2025\) 51  
* **What it gives us:** The Cactus command-line utility provides the command cactus convert \[model\] \--lora \[path\] to compile and bake adapters directly into unquantized models before exporting as a unified GGUF.4 This static merging ensures maximum on-device execution speed.6  
* **Gap:** Cactus FFI headers (cactus\_init, cactus\_complete) lack any APIs for loading runtime adapter files, forcing developers to compile and distribute separate, multi-gigabyte merged models for every downstream task.36

Cactus operates by wrapping local llama.cpp builds to compile a highly optimized, cross-platform engine designed for ARM mobile processors.1 The core API utilizes opaque pointers to manage loaded models and vector indices directly on-device.50  
Standard mobile conversion pipelines convert PyTorch safetensors into GGUF using standard scripts, applying integer quantization to minimize mobile RAM footprint.53 The standard quantization of choice is **Q4\_K\_M** GGUF format.22 This method quantizes the attention and MLP layers using a mix of 4-bit and 6-bit quantization blocks, providing a 50% memory reduction with negligible perplexity loss compared to the unquantized 16-bit baseline.4  
However, quantizing fine-tuned models can introduce severe activation peak overflows.2 Fine-tuning small models on strict structured tasks (like note merging or JSON formatting) teaches the model to rely on extreme learned weight values to override its base generalist tendencies.2  
These extreme weights produce sharp, high-magnitude activation spikes in the residual stream and post-normalization layers.2 While standard PyTorch training uses 32-bit accumulation to handle these spikes, quantizing the model down to 4-bit or executing on a float16 mobile engine often clips these spikes, causing the model to output garbled text or crash entirely.2  
These activation spikes specifically impact architectures (like Gemma 3\) that utilize massive RMSnorm scales.2 This is mitigated by restricting adapter ranks (![][image14]), using conservative learning rates, and validating the merged GGUF against standard perplexity test suites before mobile compilation.17  
When compiling for Android architectures, performance is heavily bound by CPU execution and thread allocations.22 Advanced Snapdragon 8 Elite setups utilize specialized cDSP backends (e.g., Qualcomm Hexagon via ggml-hexagon) to accelerate matrix calculations, achieving fast token throughput even on 1.8B models.23  
Furthermore, cross-platform float16 calculations can introduce mathematical divergence between iOS and Android.2 High-variance weight adapters amplify floating-point drift across hardware platforms, requiring strict temperature scaling and deterministic decoding parameters during deployment.22  
Other frameworks handle adapters differently. For example, MLC LLM supports dynamic multi-adapter execution via custom CUDA and Metal kernels (using Punica-style Segmented Gather Matrix-Vector Multiplication, or SGMV).30 S-LoRA and Punica manage memory pressure by storing all adapters in main RAM and dynamically paging them onto the GPU only when active batches request them.34 This provides dynamic model-swapping capabilities but requires a highly complex native runtime stack compared to standard llama.cpp static merging.30

### **T6. Evaluation Methodology for Narrow-Domain Small-Model Quality**

* **Primary Sources:**  
  * https://arxiv.org/html/2602.07673v1 (Arxiv, 2026\) 57  
  * https://arxiv.org/html/2604.16790v1 (Arxiv, 2026\) 58  
  * https://openreview.net/forum?id=3GTtZFiajM (OpenReview, 2025\) 59  
  * https://deepeval.com/docs/introduction (DeepEval, 2026\) 19  
  * https://galtea.ai/blog/golden-datasets-for-regulated-ai-six-q-a-frameworks-tested (Galtea, 2026\) 60  
* **What it gives us:** Programmatic evaluation suites replace subjective manual testing.61 DeepEval functions like pytest, running locally to assert pass/fail criteria across key metrics (such as JSON validation, Markdown heading checks, and length caps) before invoking expensive LLM judges.20  
* **Gap:** Relying on LLM judges introduces systematic biases.57 Judges systematically overscore verbose outputs (length bias) and outputs generated by models of their own architectural family (self-preference bias).46

To build a robust localized evaluation pipeline, developers should combine three distinct evaluation layers 46:

* **Deterministic Assertions:** Cheap, fast programmatic checks.61 If the model fails a JSON schema validation, a required Markdown heading regex, or a length threshold, the test fails immediately without invoking an expensive LLM judge.46  
* **Factual Faithfulness (Grounding):** Measures if the generated output contains external hallucinations unsupported by the input study notes.43 DeepEval calculates this using an LLM-as-a-Judge prompt, extracting the output claims and verifying them directly against the retrieved source texts.19  
* **Semantic Relevance:** Evaluates if the output successfully consolidates the input claims.43 This is measured via embedding cosine similarity between the generated summary and the ground-truth test cases.43

Using an LLM as a judge introduces three major systemic biases that developers must actively mitigate 46:

* **Self-Preference Bias:** Judge models systematically favor outputs generated by models of their own architectural family (e.g., a Qwen-based judge will over-score Qwen-student outputs by 10% to 25%).46 Mitigate this by utilizing neutral, third-party judge models (such as Claude 3.5 Sonnet or GPT-4o).46  
* **Position Bias:** In pairwise evaluations, the judge’s score is highly sensitive to the order in which responses are presented, shifting results by 10% to 15%.46 Mitigate this by running bidirectional evaluations (swapping candidate presentation orders) and calculating the geometric mean of the scores.46  
* **Length Bias:** Judges systematically favor wordier, highly verbose outputs even if they contain factual errors.57 Mitigate this by enforcing a strict length-normalized scoring rubric or applying length-penalized metrics like SimPO during evaluation.18

To ensure evaluation integrity, developers must maintain strict dataset holdout discipline.47 If both training and evaluation datasets are synthetically generated from the same teacher model, the evaluation set must be generated from separate source documents (e.g., a physically separated partition of the study-note corpus).43  
Furthermore, raw generation templates like those in RAGAS can generate noisy, malformed questions that lower evaluation quality.60 Without filtering out these malformed questions during synthetic generation, the downstream evaluation results will reflect test-data noise rather than actual model capability.60

### **T7. Licensing Landmines for Fine-Tuned Weight Redistribution**

* **Primary Sources:**  
  * https://ollama.com/library/deepseek-r1:1.5b-qwen-distill-q4\_K\_M (Ollama, 2025\) 39  
  * https://www.reddit.com/r/LocalLLM/comments/1saktik/gemma4\_someone\_at\_google\_just\_merged\_a\_pr\_titled/ (Reddit, 2026\) 64  
  * https://privacy.claude.com/en/articles/7996868-is-my-data-used-for-model-training (Anthropic, 2026\) 38  
* **What it gives us:** Using base models licensed under permissive terms (such as Apache 2.0) guarantees that the final fine-tuned GGUF file can be redistributed publicly in a hackathon repository without complex legal restrictions.39  
* **Gap:** Deploying models derived from commercial bases like Llama 3.2 triggers strict branding restrictions, while utilizing synthetic outputs from proprietary commercial APIs (such as OpenAI or Anthropic) technically violates their terms of service.38

Licensing risks are directly tied to the selection of both base model weights and synthetic training data:

* **Apache 2.0 (Qwen 3, SmolLM2, Gemma 4, Phi-3):** Permits unrestricted commercial and non-commercial redistribution, modification, and deployment.39 The only compliance requirement is providing a copy of the Apache 2.0 license and attributing the original creators in any derivatives.39 Historically, Gemma models carried custom commercial restrictions; however, Gemma 4 models have shifted entirely to the Apache 2.0 license, making them highly attractive for open-source distributions.64  
* **Llama Community License (Llama 3.2 1B/3B):** Imposes significant branding and operational taxes.39 Any derivative work must prominently display "Built with Llama" in its documentation and include the prefix "Llama" in the fine-tuned model name.39 It also restricts use if the deploying organization exceeds 700 million monthly active users.39  
* **Commercial API Data Restrictions:** As detailed in the distillation analysis, using synthetic data generated from commercial models like Claude or GPT-4o violates their commercial terms of service.38 If a developer open-sources a student model trained on these datasets, the parent provider has legal grounds to demand its removal.38 To maintain complete compliance, developers should generate synthetic datasets using open-weight models like Qwen-2.5-72B-Instruct, which explicitly permit utilizing outputs for distillation and training.39

## **Recommended Specialist-Build Recipe**

### **Primary Recommendation: Static Quantized Qwen3-1.7B Pipeline**

To meet the strict performance, licensing, and latency constraints of localized mobile mesh networks, the recommended post-training architecture leverages a static weight merging and high-fidelity quantization pipeline.

* **Base Model:** **Qwen3-1.7B-Instruct**.39 It provides a highly optimized parameter-to-performance ratio for mobile architectures, has native multilingual support, and operates under the permissive Apache-2.0 license.39  
* **Training Method:** **QLoRA (4-bit base loading)**.16 Train for 3 epochs with a rank of ![][image6], a scaling factor of ![][image15], and a learning rate of ![][image11] using a cosine scheduler and an 8-bit AdamW optimizer.17 Target all linear projection and MLP layers (![][image12]) to capture both semantic content and strict formatting layouts.4  
* **Data Source & Size:** **1,500 highly filtered, synthetic note-merging samples** generated via the Magpie pipeline using the open-weight Qwen-2.5-72B-Instruct as the synthetic teacher.10  
* **Training Platform:** **Unsloth (local/cloud workstation)**.8 Utilizing Unsloth’s custom Triton kernels allows the entire training run to complete on a single, affordable GPU.8  
* **GPU Budget & Wall-Clock Estimate:** A single **NVIDIA RTX 4090 GPU hosted on RunPod** ($0.44/hr).9 The training run will complete in approximately 15 to 30 minutes, costing under $1.00 in total compute.9  
* **Evaluation Shape:** **DeepEval programmatic suite** executing three core assertions: context faithfulness (via G-Eval model-as-a-judge), a deterministic Markdown heading regex check, and a length cap.20 Mitigate contamination using a strict physical holdout of source study notes.43  
* **Deployment Path:** **Statically merged weights converted to GGUF and quantized to Q4\_K\_M**.4 This is converted using the cactus convert \--lora CLI utility 4, delivering zero-latency overhead and smooth execution within Cactus.6  
* **License Posture:** **Apache-2.0**.39 Derived cleanly from the base model and open-weights synthetic generation data, completely permitting unrestricted public redistribution and commercial/hackathon use.39

### **Backup Recommendation: Runtime LoRA Swapping with Gemma 4**

If the primary pipeline encounters severe activation peak overflows or quantization corruption post-merge, the backup technical architecture pivots to dynamic runtime adapter swapping on a highly stable edge base.

* **Base Model:** **Gemma 4 2B Dense** (Apache-2.0, highly stable edge architecture with deep residual streams designed to minimize FP16 overflows).2  
* **Training Method:** **SFT with full-precision (bf16) LoRA (![][image16])** on a single NVIDIA A100 (80GB) GPU to eliminate quantization-induced artifacts during the training loop.17  
* **Data Source & Size:** Same as the primary (1,500 synthetic multi-document summarization samples generated via open-weights teachers).10  
* **Training Platform:** **Modal serverless containers** to allow scaling to high-capacity GPUs while maintaining a clean, versioned setup.9  
* **GPU Budget & Wall-Clock Estimate:** A single **NVIDIA A100 (80GB) GPU on Modal** ($1.38/hr).9 The training run will complete in approximately 30 to 45 minutes, costing under $2.00.9  
* **Evaluation Shape:** Same as the primary (DeepEval programmatic assertions with strict physical holdout of source study notes to guarantee evaluation integrity).20  
* **Deployment Path:** Bypass the Cactus engine's limitations by compiling a custom build of llama.cpp natively inside the mobile applications using the **llama-cpp-capacitor plugin**.15 This native integration allows developers to load a single, shared GGUF base model into memory while hot-swapping separate 35MB .safetensors LoRA adapters on the fly.15 This preserves mobile storage by avoiding shipping separate multi-gigabyte models for different tasks.25  
* **License Posture:** **Apache-2.0**.64 Completely clean path allowing unrestricted public redistribution and commercial deployment of both the base model and the trained adapters.39

## **Reference Implementations**

### **Ollamox GGUF Pipeline**

* **Target Files/Directories:** https://github.com/Oxen-AI/Ollamox 25  
* **Analogous Feature:** This repository serves as a complete reference showing how to download trained safetensors adapters from Oxen.ai, merge them into an unquantized base model, convert the resulting weights to GGUF format, apply integer quantization, and run the final outputs locally.25 This mirrors the exact data-to-GGUF loop required for study-note RAG customization.25

### **baremetallama**

* **Target Files/Directories:** https://github.com/RedLordezh7Venom/baremetallama 67  
* **Analogous Feature:** A specialized model customization project that fine-tunes a DeepSeek model into an ISO-compliant standards expert.67 It features a highly optimized QLoRA pipeline, custom GGUF conversion scripts, and programmatic evaluation loops designed to ensure strict formatting compliance, providing a structural match for task-specific edge training.67

### **Phi-3 Procurement Fine-Tune**

* **Target Files/Directories:** https://github.com/topics/gguf?o=asc\&s=stars 67 (Phi-3 Procurement Fine-Tune)  
* **Analogous Feature:** Outlines a reproducible QLoRA training and GGUF deployment pipeline for Phi-3-Mini on specialized contract data.67 It provides a clean template for converting PyTorch adapters, applying integer quantization, and managing prompt formatting inside local runtimes.67

## **Open Research Questions**

### **Cactus \+ LoRA-runtime verdict: NO**

A detailed analysis of the Cactus compute engine codebase reveals that **Cactus does not support the dynamic, runtime loading of raw LoRA adapter files**.4 The Cactus FFI API exposes only opaque pointers to fully initialized model paths via the cactus\_init function.50  
Instead, Cactus handles LoRA adapters exclusively by merging them with the base model weights *at compile time*.4 This static merging prevents developers from running multi-tenant or multi-specialist architectures over a single shared base model on-device.25

### **Quantization-Induced Activation Clipping**

During strict formatting optimization, the post-training process forces learned adapter weights to adopt extreme values.2 While training in 16-bit or 32-bit floating-point precision preserves these high-variance mathematical gradients, quantizing the merged weights to 4-bit integer values (Q4\_K\_M) introduces substantial mathematical clipping.2  
This clipping of activation peaks in the residual stream often ruins the fine-tuned capabilities, causing the model to output garbled text or fail formatting schemas.2 Finding optimal quantization boundaries that preserve extreme weights for structured extraction models remains an open engineering challenge.

### **Cross-Platform Floating-Point Divergence**

Running local inference across heterogeneous hardware platforms (such as the Apple Neural Engine/GPU vs Snapdragon Hexagon cDSP/Adreno GPU) introduces minor differences in floating-point calculations.2 High-variance weight adapters amplify this floating-point drift across hardware platforms, potentially causing a model to output perfectly formatted JSON on iOS but fail parsing checks on Android.2  
Developing compilation-level safeguards to guarantee strict, token-by-token cross-platform parity on quantized mobile runtimes remains an open area of research.

## **Specialist-vs-Generalist Evidence**

### **The Case for Specialized Edge Architectures**

Generalist models under 2.0 billion parameters are highly fragile when executing complex, structured tasks.3 Because their parameters must store broad world knowledge, historical facts, and multiple languages, they lack the focused capacity required for strict procedural instruction following.3 This leads to high failure rates, where the model outputs verbose conversational filler ("Sure, here are your flashcards:") or drifts into alternative languages under bilingual pre-training leakages.14  
Post-training a small model on a highly specialized, synthetically engineered task dataset completely resolves these formatting issues.17 In real-world deployment benchmarks, fine-tuning small models on narrow tasks improves domain accuracy to **94%**, compared to just **71%** for a prompt-engineered GPT-4 generalist baseline.68  
Furthermore, specialized models exhibit a highly consistent, deterministic output format.17 By teaching the model to output *only* raw Markdown or structured JSON arrays, application developers can bypass complex regex filters and parsing gates at the service layer.17

### **The Counter-Case: Specialization Failures and Risks**

However, aggressive specialization introduces severe operational risks:

* **Catastrophic Forgetting:** Fine-tuning a model on a narrow formatting task dramatically erodes its general linguistic understanding, reading comprehension, and logical reasoning capabilities.16 The model becomes a single-purpose pipeline, unable to adapt to alternative tasks.16  
* **Extreme Alignment Tax:** The model can become highly brittle when presented with out-of-distribution inputs.69 If a user’s raw study notes deviate slightly from the precise synthetic layout used during training, the model's structural formatting can collapse completely, leading to unpredictable failure modes.  
* **Quantization Vulnerability:** Specialization often forces learned weight matrices to adopt sharp, high-variance peaks to override base model tendencies.2 When these optimized weights are quantized down to 4-bit integer formats for mobile deployment, the mathematical clipping often ruins the fine-tuned capabilities, rendering the specialist model *worse* than the un-tuned base generalist.2

## **Source Ledger**

https://github.com/cactus-compute/cactus  
https://github.com/cactus-compute/cactus/issues/503  
https://github.com/cactus-compute/cactus/blob/main/docs/finetuning.md  
https://github.com/cactus-compute/cactus/blob/main/docs/cactus\_engine.md  
https://github.com/cactus-compute/cactus/discussions/204  
https://pub.dev/packages/cactus  
https://docs.cactuscompute.com/v1.14/docs/cactus\_engine/  
https://docs.cactuscompute.com/v1.8/  
https://docs.cactuscompute.com/v1.9/  
https://github.com/Oxen-AI/Ollamox  
https://ghost.oxen.ai/how-to-train-a-ltx-2-character-lora-with-oxen-ai/  
https://docs.oxen.ai/fine-tuning-api/overview  
https://ghost.oxen.ai/writing-a-fine-tuning-and-deployment-pipeline-isnt-as-easy-as-it-looks-gemma-4-version/  
https://ghost.oxen.ai/arxiv-dives-how-lora-fine-tuning-works/  
https://github.com/ggml-org/llama.cpp  
https://www.clarifai.com/blog/ilama.cpp  
https://colab.research.google.com/drive/1TT6NED5iFUGratZj4aHe13iOJkDTUUVT?usp=sharing  
https://github.com/ggml-org/llama.cpp/discussions/14356  
https://openrouter.ai/deepseek/deepseek-r1-distill-qwen-1.5b  
https://www.bentoml.com/blog/the-complete-guide-to-deepseek-models-from-v3-to-r1-and-beyond  
https://ollama.com/library/deepseek-r1:1.5b-qwen-distill-q4\_K\_M  
https://llmbase.ai/compare/deepseek-r1-distill-qwen-1-5b,deepseek-v4-flash-non-reasoning/  
https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-1.5B  
https://arxiv.org/html/2507.01438v1  
https://www.reddit.com/r/LocalLLaMA/comments/1q2xbjc/experimental\_temporal\_lora\_a\_dynamic\_adapter/  
https://contracollective.com/blog/llama-cpp-vs-mlx-ollama-vllm-apple-silicon-2026  
https://www.truefoundry.com/blog/lora-fine-tuning  
https://atalupadhyay.wordpress.wordpress.com/2026/04/01/running-local-ai-mastering-llama-cpp-from-zero-to-production/  
https://fireworks.ai/blog/fine-tuning-bottlenecks  
https://www.clarifai.com/blog/dpo-vs-ppo  
https://bool.dev/blog/detail/llm-model-training  
https://pmc.ncbi.nlm.nih.gov/articles/PMC12457693/  
https://arxiv.org/html/2509.16965v1  
https://huggingface.co/bharati2324/Qwen2.5-1.5B-Instruct-Code-LoRA-r16v2  
https://app.readytensor.ai/publications/fine-tuning-qwen25-15b-for-text-to-sql-generation-kaa6DwgRemd5  
https://medium.com/@resta.alessandro.3ai/fine-tuning-a-mini-giant-teaching-qwen2-5-1-5b-to-speak-sql-62e960b7e907  
https://arxiv.org/html/2605.07111v2  
https://www.reddit.com/r/LocalLLaMA/comments/1lvek0j/difficulty\_in\_fine\_tuning\_llora/  
https://privacy.claude.com/en/articles/7996868-is-my-data-used-for-model-training  
https://www.reddit.com/r/LocalLLaMA/comments/1snjafe/anthropic\_admitted\_they\_used\_other\_models\_data/  
https://www.anthropic.com/news/claude-new-constitution  
https://privacy.claude.com/en/articles/10023580-is-my-data-used-for-model-training  
https://www.anthropic.com/transparency  
https://arxiv.org/html/2602.07673v1  
https://arxiv.org/html/2604.16790v1  
https://arxiv.org/html/2602.09383v1  
https://openreview.net/forum?id=3GTtZFiajM  
https://futureagi.com/blog/best-llm-as-judge-platforms-2026/  
https://www.evidentlyai.com/llm-guide/llm-test-dataset-synthetic-data  
https://pmc.ncbi.nlm.nih.gov/articles/PMC8276128/  
https://arxiv.org/html/2502.14425v2  
https://aclanthology.org/2025.findings-naacl.291.pdf  
https://sulbhajain.medium.com/evaluating-the-quality-of-synthetic-data-efe4ad11f8d7  
https://qwen.ai/blog?id=qwen3.6  
https://www.clarifai.com/blog/how-to-choose-the-right-open-source-llm-for-production  
https://www.reddit.com/r/LocalLLM/comments/1saktik/gemma4\_someone\_at\_google\_just\_merged\_a\_pr\_titled/  
https://paddo.dev/blog/ai-roundup-april-2026/  
https://kilo.ai/open-source-models  
https://pub.towardsai.net/the-architectural-paradigm-of-multi-adapter-inference-a-technical-analysis-of-lorax-567c2f4851f0  
https://medium.com/@mukulranjan/serving-thousands-of-concurrent-lora-adapters-6b407e8df516  
https://github.com/mlc-ai/mlc-llm/issues/3446  
https://developer.nvidia.com/blog/seamlessly-deploying-a-swarm-of-lora-adapters-with-nvidia-nim/  
https://arxiv.org/html/2508.08343v2  
https://github.com/magpie-align/magpie  
https://magpie-align.github.io/  
https://arxiv.org/html/2406.08464v1  
https://arxiv.org/html/2406.08464v2  
http://distilabel.argilla.io/0.6.0/tutorials/create-evol-instruct-dataset/  
https://docs.lm-kit.com/lm-kit-net/guides/glossary/synthetic-data-generation.html  
https://openreview.net/forum?id=nPEWyL8kxO  
https://inference.net/content/llm-evaluation-tools-comparison/  
https://pub.towardsai.net/llm-eval-workflow-how-to-build-reliable-ai-quality-gates-without-vibes-16da6c4be942  
https://deepeval.com/docs/introduction  
https://galtea.ai/blog/golden-datasets-for-regulated-ai-six-q-a-frameworks-tested  
https://techsy.io/en/blog/best-llm-fine-tuning-tools  
https://julsimon.medium.com/what-to-buy-for-local-llms-april-2026-a4946a381a6a  
https://aclanthology.org/2025.justnlp-main.11.pdf  
https://www.spheron.network/blog/dpo-fine-tuning-gpu-cloud/  
https://machinelearningplus.com/gen-ai/unsloth-fine-tuning/  
https://github.com/ggml-org/ggml/blob/master/docs/gguf.md  
https://github.com/topics/gguf?o=asc\&s=stars  
https://www.reddit.com/r/LocalLLM/comments/1tl67iq/visual\_finetuning\_to\_gguf\_ondevice\_deployment/  
https://github.com/ggml-org/llama.cpp/discussions/2948  
https://github.com/arusatech/llama-cpp  
https://mobile-artificial-intelligence.com/maid/guides/llama-cpp  
https://github.com/unslothai/unsloth?locale=en-US  
https://github.com/unslothai/unsloth/issues/976

#### **Works cited**

1. GitHub \- cactus-compute/cactus: Low-latency AI engine for mobile devices & wearables, accessed May 28, 2026, [https://github.com/cactus-compute/cactus](https://github.com/cactus-compute/cactus)  
2. FunctionGemma FP16 issues \#503 \- cactus-compute/cactus \- GitHub, accessed May 28, 2026, [https://github.com/cactus-compute/cactus/issues/503](https://github.com/cactus-compute/cactus/issues/503)  
3. How Modern LLMs Are Actually Trained: SFT, RLHF, DPO, Instruction Tuning, and Distillation \- Bool.dev, accessed May 28, 2026, [https://bool.dev/blog/detail/llm-model-training](https://bool.dev/blog/detail/llm-model-training)  
4. cactus/docs/finetuning.md at main · cactus-compute/cactus · GitHub, accessed May 28, 2026, [https://github.com/cactus-compute/cactus/blob/main/docs/finetuning.md](https://github.com/cactus-compute/cactus/blob/main/docs/finetuning.md)  
5. Cactus Engine FFI API Reference \- Cactus Docs, accessed May 28, 2026, [https://docs.cactuscompute.com/v1.14/docs/cactus\_engine/](https://docs.cactuscompute.com/v1.14/docs/cactus_engine/)  
6. Arxiv Dives \- How LoRA fine-tuning works \- Oxen.ai, accessed May 28, 2026, [https://ghost.oxen.ai/arxiv-dives-how-lora-fine-tuning-works/](https://ghost.oxen.ai/arxiv-dives-how-lora-fine-tuning-works/)  
7. EdgeLoRA: An Efficient Multi-Tenant LLM Serving System on Edge Devices \- arXiv, accessed May 28, 2026, [https://arxiv.org/html/2507.01438v1](https://arxiv.org/html/2507.01438v1)  
8. Unsloth Studio is a web UI for training and running open models like Gemma 4, Qwen3.6, DeepSeek, gpt-oss locally. · GitHub, accessed May 28, 2026, [https://github.com/unslothai/unsloth?locale=en-US](https://github.com/unslothai/unsloth?locale=en-US)  
9. Fine-Tune Any LLM 2026: 10 Tools Tested, Cheapest Wins \- TECHSY, accessed May 28, 2026, [https://techsy.io/en/blog/best-llm-fine-tuning-tools](https://techsy.io/en/blog/best-llm-fine-tuning-tools)  
10. GitHub \- magpie-align/magpie: \[ICLR 2025\] Alignment Data Synthesis from Scratch by Prompting Aligned LLMs with Nothing. Your efficient and high-quality synthetic data generation pipeline\!, accessed May 28, 2026, [https://github.com/magpie-align/magpie](https://github.com/magpie-align/magpie)  
11. Magpie: Alignment Data Synthesis from Scratch by Prompting Aligned LLMs with Nothing, accessed May 28, 2026, [https://openreview.net/forum?id=Pnk7vMbznK](https://openreview.net/forum?id=Pnk7vMbznK)  
12. deepseek-ai/DeepSeek-R1-Distill-Qwen-1.5B \- Hugging Face, accessed May 28, 2026, [https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-1.5B](https://huggingface.co/deepseek-ai/DeepSeek-R1-Distill-Qwen-1.5B)  
13. R1 Distill Qwen 1.5B \- API Pricing & Benchmarks | OpenRouter, accessed May 28, 2026, [https://openrouter.ai/deepseek/deepseek-r1-distill-qwen-1.5b](https://openrouter.ai/deepseek/deepseek-r1-distill-qwen-1.5b)  
14. The Complete Guide to DeepSeek Models: V3, R1, V4 and Beyond \- BentoML, accessed May 28, 2026, [https://www.bentoml.com/blog/the-complete-guide-to-deepseek-models-from-v3-to-r1-and-beyond](https://www.bentoml.com/blog/the-complete-guide-to-deepseek-models-from-v3-to-r1-and-beyond)  
15. arusatech/annadata-llama-cpp: Llama cpp \+ CapacitorJS support \- GitHub, accessed May 28, 2026, [https://github.com/arusatech/llama-cpp](https://github.com/arusatech/llama-cpp)  
16. What is Lora Fine Tuning? The Definitive Guide \- Truefoundry, accessed May 28, 2026, [https://www.truefoundry.com/blog/lora-fine-tuning](https://www.truefoundry.com/blog/lora-fine-tuning)  
17. Fine-Tuning Qwen2.5-1.5B for Text-to-SQL Generation \- Ready Tensor, accessed May 28, 2026, [https://app.readytensor.ai/publications/fine-tuning-qwen25-15b-for-text-to-sql-generation-kaa6DwgRemd5](https://app.readytensor.ai/publications/fine-tuning-qwen25-15b-for-text-to-sql-generation-kaa6DwgRemd5)  
18. DPO vs PPO for LLMs: Key Differences & Use Cases \- Clarifai, accessed May 28, 2026, [https://www.clarifai.com/blog/dpo-vs-ppo](https://www.clarifai.com/blog/dpo-vs-ppo)  
19. Introduction to DeepEval | DeepEval \- The LLM Evaluation Framework, accessed May 28, 2026, [https://deepeval.com/docs/introduction](https://deepeval.com/docs/introduction)  
20. LLM Evaluation Tools: The Complete Comparison Guide (2026), accessed May 28, 2026, [https://inference.net/content/llm-evaluation-tools-comparison/](https://inference.net/content/llm-evaluation-tools-comparison/)  
21. ggml-org/llama.cpp: LLM inference in C/C++ \- GitHub, accessed May 28, 2026, [https://github.com/ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp)  
22. llama.cpp: Fast Local LLM Inference, Hardware Choices & Tuning \- Clarifai, accessed May 28, 2026, [https://www.clarifai.com/blog/ilama.cpp](https://www.clarifai.com/blog/ilama.cpp)  
23. Performance of llama.cpp on Android device \#14356 \- GitHub, accessed May 28, 2026, [https://github.com/ggml-org/llama.cpp/discussions/14356](https://github.com/ggml-org/llama.cpp/discussions/14356)  
24. Fine-Tuning Overview \- Oxen.ai, accessed May 28, 2026, [https://docs.oxen.ai/fine-tuning-api/overview](https://docs.oxen.ai/fine-tuning-api/overview)  
25. Oxen-AI/Ollamox: A repository to convert fine-tuned models on Oxen.ai to local models that can run in Ollama \- GitHub, accessed May 28, 2026, [https://github.com/Oxen-AI/Ollamox](https://github.com/Oxen-AI/Ollamox)  
26. How to Train a LTX-2 Character LoRA with Oxen.ai, accessed May 28, 2026, [https://ghost.oxen.ai/how-to-train-a-ltx-2-character-lora-with-oxen-ai/](https://ghost.oxen.ai/how-to-train-a-ltx-2-character-lora-with-oxen-ai/)  
27. Writing a fine-tuning and deployment pipeline isn't as easy as it looks (Gemma 4 Version), accessed May 28, 2026, [https://ghost.oxen.ai/writing-a-fine-tuning-and-deployment-pipeline-isnt-as-easy-as-it-looks-gemma-4-version/](https://ghost.oxen.ai/writing-a-fine-tuning-and-deployment-pipeline-isnt-as-easy-as-it-looks-gemma-4-version/)  
28. Fine-Tuning a Mini-Giant: Teaching Qwen2.5–1.5B to Speak SQL | by Alessandro Resta, accessed May 28, 2026, [https://medium.com/@resta.alessandro.3ai/fine-tuning-a-mini-giant-teaching-qwen2-5-1-5b-to-speak-sql-62e960b7e907](https://medium.com/@resta.alessandro.3ai/fine-tuning-a-mini-giant-teaching-qwen2-5-1-5b-to-speak-sql-62e960b7e907)  
29. Fine-Tuning Methods for Large Language Models in Clinical Medicine by Supervised Fine-Tuning and Direct Preference Optimization: Comparative Evaluation \- PMC, accessed May 28, 2026, [https://pmc.ncbi.nlm.nih.gov/articles/PMC12457693/](https://pmc.ncbi.nlm.nih.gov/articles/PMC12457693/)  
30. The Architectural Paradigm of Multi-Adapter Inference: A Technical Analysis of LoRAX | by Neel Shah | Towards AI, accessed May 28, 2026, [https://pub.towardsai.net/the-architectural-paradigm-of-multi-adapter-inference-a-technical-analysis-of-lorax-567c2f4851f0](https://pub.towardsai.net/the-architectural-paradigm-of-multi-adapter-inference-a-technical-analysis-of-lorax-567c2f4851f0)  
31. Performance of the finetuned model in unsloth notebook and Ollama/GGUF differ significantly · Issue \#976 \- GitHub, accessed May 28, 2026, [https://github.com/unslothai/unsloth/issues/976](https://github.com/unslothai/unsloth/issues/976)  
32. Unsloth Fine-Tuning — Train LLMs 2x Faster with 70% Less Memory \- machinelearningplus, accessed May 28, 2026, [https://machinelearningplus.com/gen-ai/unsloth-fine-tuning/](https://machinelearningplus.com/gen-ai/unsloth-fine-tuning/)  
33. The Fine-Tuning Bottleneck Isn't the Algorithm \- Fireworks AI, accessed May 28, 2026, [https://fireworks.ai/blog/fine-tuning-bottlenecks](https://fireworks.ai/blog/fine-tuning-bottlenecks)  
34. Serving Thousands of Concurrent LoRA Adapters | by Mukul Ranjan \- Medium, accessed May 28, 2026, [https://medium.com/@mukulranjan/serving-thousands-of-concurrent-lora-adapters-6b407e8df516](https://medium.com/@mukulranjan/serving-thousands-of-concurrent-lora-adapters-6b407e8df516)  
35. \[Experimental\] "Temporal LoRA": A dynamic adapter router that switches context (Code vs. Lit) with 100% accuracy. Proof of concept on GPT-2. : r/LocalLLaMA \- Reddit, accessed May 28, 2026, [https://www.reddit.com/r/LocalLLaMA/comments/1q2xbjc/experimental\_temporal\_lora\_a\_dynamic\_adapter/](https://www.reddit.com/r/LocalLLaMA/comments/1q2xbjc/experimental_temporal_lora_a_dynamic_adapter/)  
36. Seamlessly Deploying a Swarm of LoRA Adapters with NVIDIA NIM, accessed May 28, 2026, [https://developer.nvidia.com/blog/seamlessly-deploying-a-swarm-of-lora-adapters-with-nvidia-nim/](https://developer.nvidia.com/blog/seamlessly-deploying-a-swarm-of-lora-adapters-with-nvidia-nim/)  
37. Preference Distillation via Value based Reinforcement Learning \- arXiv, accessed May 28, 2026, [https://arxiv.org/html/2509.16965v1](https://arxiv.org/html/2509.16965v1)  
38. Is my data used for model training? \- Anthropic Privacy Center, accessed May 28, 2026, [https://privacy.claude.com/en/articles/7996868-is-my-data-used-for-model-training](https://privacy.claude.com/en/articles/7996868-is-my-data-used-for-model-training)  
39. deepseek-r1:1.5b-qwen-distill-q4\_K\_M \- Ollama, accessed May 28, 2026, [https://ollama.com/library/deepseek-r1:1.5b-qwen-distill-q4\_K\_M](https://ollama.com/library/deepseek-r1:1.5b-qwen-distill-q4_K_M)  
40. Anthropic admitted they used other models data? : r/LocalLLaMA \- Reddit, accessed May 28, 2026, [https://www.reddit.com/r/LocalLLaMA/comments/1snjafe/anthropic\_admitted\_they\_used\_other\_models\_data/](https://www.reddit.com/r/LocalLLaMA/comments/1snjafe/anthropic_admitted_they_used_other_models_data/)  
41. CoT-Self-Instruct: Building high-quality synthetic prompts data for reasoning and non-reasoning tasks | OpenReview, accessed May 28, 2026, [https://openreview.net/forum?id=nPEWyL8kxO](https://openreview.net/forum?id=nPEWyL8kxO)  
42. 🧙 Create an evol-instruct dataset \- distilabel, accessed May 28, 2026, [http://distilabel.argilla.io/0.6.0/tutorials/create-evol-instruct-dataset/](http://distilabel.argilla.io/0.6.0/tutorials/create-evol-instruct-dataset/)  
43. How to create LLM test datasets with synthetic data \- Evidently AI, accessed May 28, 2026, [https://www.evidentlyai.com/llm-guide/llm-test-dataset-synthetic-data](https://www.evidentlyai.com/llm-guide/llm-test-dataset-synthetic-data)  
44. LM-Kit.NET Synthetic Data Generation: Create AI Training Data in C\# .NET, accessed May 28, 2026, [https://docs.lm-kit.com/lm-kit-net/guides/glossary/synthetic-data-generation.html](https://docs.lm-kit.com/lm-kit-net/guides/glossary/synthetic-data-generation.html)  
45. Magpie: Alignment Data Synthesis from Scratch by Prompting Aligned LLMs with Nothing \- arXiv, accessed May 28, 2026, [https://arxiv.org/html/2406.08464v2](https://arxiv.org/html/2406.08464v2)  
46. Best LLM-as-Judge Platforms 2026: 6 Compared \- Future AGI, accessed May 28, 2026, [https://futureagi.com/blog/best-llm-as-judge-platforms-2026/](https://futureagi.com/blog/best-llm-as-judge-platforms-2026/)  
47. A Survey on Data Contamination for Large Language Models \- arXiv, accessed May 28, 2026, [https://arxiv.org/html/2502.14425v2](https://arxiv.org/html/2502.14425v2)  
48. Holdout-Based Empirical Assessment of Mixed-Type Synthetic Data \- PMC \- NIH, accessed May 28, 2026, [https://pmc.ncbi.nlm.nih.gov/articles/PMC8276128/](https://pmc.ncbi.nlm.nih.gov/articles/PMC8276128/)  
49. Evaluating the Quality of Synthetic Data | by Sulbha Jain \- Medium, accessed May 28, 2026, [https://sulbhajain.medium.com/evaluating-the-quality-of-synthetic-data-efe4ad11f8d7](https://sulbhajain.medium.com/evaluating-the-quality-of-synthetic-data-efe4ad11f8d7)  
50. cactus/docs/cactus\_engine.md at main \- GitHub, accessed May 28, 2026, [https://github.com/cactus-compute/cactus/blob/main/docs/cactus\_engine.md](https://github.com/cactus-compute/cactus/blob/main/docs/cactus_engine.md)  
51. \[Tracking\] Multi-LoRA Serving · Issue \#3446 · mlc-ai/mlc-llm \- GitHub, accessed May 28, 2026, [https://github.com/mlc-ai/mlc-llm/issues/3446](https://github.com/mlc-ai/mlc-llm/issues/3446)  
52. Home \- Cactus \- Cactus Docs, accessed May 28, 2026, [https://docs.cactuscompute.com/v1.8/](https://docs.cactuscompute.com/v1.8/)  
53. Tutorial: How to convert HuggingFace model to GGUF format · ggml-org llama.cpp · Discussion \#2948 \- GitHub, accessed May 28, 2026, [https://github.com/ggml-org/llama.cpp/discussions/2948](https://github.com/ggml-org/llama.cpp/discussions/2948)  
54. Run AI Locally on Android with llama.cpp — Maid Guide \- Mobile Artificial Intelligence, accessed May 28, 2026, [https://mobile-artificial-intelligence.com/maid/guides/llama-cpp](https://mobile-artificial-intelligence.com/maid/guides/llama-cpp)  
55. Running Local AI: Mastering Llama.cpp from Zero to Production | atal upadhyay, accessed May 28, 2026, [https://atalupadhyay.wordpress.com/2026/04/01/running-local-ai-mastering-llama-cpp-from-zero-to-production/](https://atalupadhyay.wordpress.com/2026/04/01/running-local-ai-mastering-llama-cpp-from-zero-to-production/)  
56. GGUF LoRA with llama.cpp \- Colab, accessed May 28, 2026, [https://colab.research.google.com/drive/1TT6NED5iFUGratZj4aHe13iOJkDTUUVT?usp=sharing](https://colab.research.google.com/drive/1TT6NED5iFUGratZj4aHe13iOJkDTUUVT?usp=sharing)  
57. Blind to the Human Touch: Overlap Bias in LLM-Based Summary Evaluation \- arXiv, accessed May 28, 2026, [https://arxiv.org/html/2602.07673v1](https://arxiv.org/html/2602.07673v1)  
58. Bias in the Loop: Auditing LLM-as-a-Judge for Software Engineering \- arXiv, accessed May 28, 2026, [https://arxiv.org/html/2604.16790v1](https://arxiv.org/html/2604.16790v1)  
59. Justice or Prejudice? Quantifying Biases in LLM-as-a-Judge | OpenReview, accessed May 28, 2026, [https://openreview.net/forum?id=3GTtZFiajM](https://openreview.net/forum?id=3GTtZFiajM)  
60. Golden datasets for regulated AI: six Q\&A frameworks tested | Galtea Blog, accessed May 28, 2026, [https://galtea.ai/blog/golden-datasets-for-regulated-ai-six-q-a-frameworks-tested](https://galtea.ai/blog/golden-datasets-for-regulated-ai-six-q-a-frameworks-tested)  
61. LLM Eval Workflow: How to Build Reliable AI Quality Gates Without Vibes | by Anna Jey, accessed May 28, 2026, [https://pub.towardsai.net/llm-eval-workflow-how-to-build-reliable-ai-quality-gates-without-vibes-16da6c4be942](https://pub.towardsai.net/llm-eval-workflow-how-to-build-reliable-ai-quality-gates-without-vibes-16da6c4be942)  
62. cactus | Flutter package \- Pub.dev, accessed May 28, 2026, [https://pub.dev/packages/cactus](https://pub.dev/packages/cactus)  
63. BiasScope: Towards Automated Detection of Bias in LLM-as-a-Judge Evaluation \- arXiv, accessed May 28, 2026, [https://arxiv.org/html/2602.09383v1](https://arxiv.org/html/2602.09383v1)  
64. Gemma4 \- Someone at Google just merged a PR titled "casually dropping the most capable open weights on the planet" : r/LocalLLM \- Reddit, accessed May 28, 2026, [https://www.reddit.com/r/LocalLLM/comments/1saktik/gemma4\_someone\_at\_google\_just\_merged\_a\_pr\_titled/](https://www.reddit.com/r/LocalLLM/comments/1saktik/gemma4_someone_at_google_just_merged_a_pr_titled/)  
65. April's First 72 Hours: Cursor 3, Gemma 4, Free Qwen 3.6, and the Agent Push, accessed May 28, 2026, [https://paddo.dev/blog/ai-roundup-april-2026/](https://paddo.dev/blog/ai-roundup-april-2026/)  
66. DPO Fine-Tuning on GPU Cloud: Direct Preference Optimization Training Guide (2026), accessed May 28, 2026, [https://www.spheron.network/blog/dpo-fine-tuning-gpu-cloud/](https://www.spheron.network/blog/dpo-fine-tuning-gpu-cloud/)  
67. gguf · GitHub Topics, accessed May 28, 2026, [https://github.com/topics/gguf?o=asc\&s=stars](https://github.com/topics/gguf?o=asc&s=stars)  
68. Visual fine-tuning to GGUF \+ on-device deployment. Benchmarks, limits, and AMA \- Reddit, accessed May 28, 2026, [https://www.reddit.com/r/LocalLLM/comments/1tl67iq/visual\_finetuning\_to\_gguf\_ondevice\_deployment/](https://www.reddit.com/r/LocalLLM/comments/1tl67iq/visual_finetuning_to_gguf_ondevice_deployment/)  
69. Magpie: Alignment Data Synthesis from Scratch by Prompting Aligned LLMs with Nothing, accessed May 28, 2026, [https://arxiv.org/html/2406.08464v1](https://arxiv.org/html/2406.08464v1)

[image1]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAF8AAAAaCAYAAADR2YAqAAAEHklEQVR4Xu2ZWahNURjHv226FIpkfrgpwwtPigdDhkwZE8mDq3i4yiwP5nlMZnK9XRESLwop7gtPUkKUB7NQCCGZru9/1lpnf2vdvc9Z+5zDOZfzq7+zvu/ba+21vzXstS8iSWBZjZjiPEhx7lrixCalYaAT6ybrkxtQOBVCczTrPetA2lMmJ06yVrvObPA4/CIMXsMBLZOAelaFyGGHsJhmiusgVS8xTVkfSFU2eqNjfVifndgDHcMgP3diM02sCCxlfWctYi0k1Z8trFO6/IO1In21TQ0/zHH+vUMNk7iV1VXYc1m9hA06UlivhnWG0puS31L4Qg1vbDDJjaKatUwVPW7kcUlOqHb3Cc9pUW7JWsBqx3oq/OAGa7Eujwoo+CqDmh18AwwAEo8J6XKIdZRVp23OVdAkycPeosgEpxrIlHzMtkIzldSgztMaZodj2SvKJ0QZYJWCKlYbXcbD1YsUYfavD02LK6wxrlNj8jNQmf5JN2CpoIEujn8WqZdJVPIPstq7ThvvjjRn/WSdI/UQPUgtd+y5rTxb2SXKtaIMTP9xoumny5OFH6CMVeKClYEZjxdxNycGTBvXWGtkwJdtpBoZ7PixDK/rWDMnds+xc6WS9cx15sB2Ua51BuyhtvfjH11uAb+Ot6YwiUv0L8B21VvYq8ieoNjKTL09rHWsSWHYjzmkGpktfFi6WKJYjojJTtwVZQfPeRqCl6FD4jaYABPIIGf+NNYg1hGyBwjUUWpyBdWBeuHinC+pdGyArdCAl7uZ7Zicr1gbwrAfQ0kleLPwpToSqMYQG6f9GG1sOVmJSqHjG0G+e3pUYzYy+eivEbazTeTTQgbyqpwF7GXoqDklPBGxKh3DKINvIibBl94L1ltWhROLAzO0fxZ1T1+dGXfmY5/GEZRPHumTSEbySrBb2bWzgARjtncme3liySKGo9xIit7T2rLuCxvX+3CVNTGL+qavzsxOUUbywW39i/O/ez4vGmpc7NFBwj6SWqYSvGAQO2/HrMoYNLw3DLi+UthxzGANcJ05sluUTfLBO/1r/c0m4cT8g6iemD0Ss9vFxHBUiwKxCcLG1rNc2CliHjhuG0uK/shK3eWY8ON5zJ8E8EIsODHPlQ2rGhIYmYhAxR65fgHiY4X9mtTpwoeelPH05I1M+GVRRv9f6iK+Hy7JWCyp1OSYVosMbYgQEoiTTBTZ9nDExwsbM3+lsC0iuoOPNbRxmNSRFkfciMtiwZe2WZ1G7hEWtok9tkONG/zNRO75+CoeLmxf8KU7n7WWtZHUEXG6dUVRSTIf/h5DWBeE7ayU0uz0v8RZ1kVS/6uD42kJkXTw466P83uQR9U8KM5dc6aRdbdMmdIkwUJKcGkmCtSMocDN/T+URuJKoxfFJ9885Fu/BMAj/AY/WsxmPzWxYgAAAABJRU5ErkJggg==>

[image2]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAFMAAAAaCAYAAADL5WCkAAADJElEQVR4Xu2YS+gNURzHf9crYuEVkmysWSBsFKVsxEI21iykiIWN5LVjQXmUR/xTyiuPIhulvB9hI1lbIK8kpDx/3/mdM3POb87MvXPn3jH///9+6ntnzu+cOfd3fuc5Q1R3GtpQNQUcyCual9c1Kv3TzD9byvrMOqAzSpL5hwXoRB2V84c1uRuuo6deaGM/ZDxrqDYyW7SB+asNnQIVd63yDBayDrLusjawTrAesPawvrC+kkzFkfYBw1rWM9Zc1hPWaz+bbrCGJ8nGSf4ZnaQjJlHS3iOs86SnV5sj9jR1LZgteXTPXC94VqJ35nqLNc2xX2RtYr0y6ZDfN0kC2sca42dFHGIdJSkHUMeQJLs9UAFGQevBDMdnFGsNa12scLkQj8z1kmcl2ujcf3PuwRvWfGXTfGJN1EaDbe8CnVGGDxydYVQkmD6rSZ5DAGeyprOmsCa4hZpgg3k5tkhHLGKNNRbtm05rMG0xIq+RN+Vj7PN3WNvcjILEQwaNP2fuf1FzBzVPWeu1sQ3SwRSwjlqeJ7eR/3m+niV/jbxKfkDHUfL8PtZ21ookuw0avkPYyfMcjHBm7hzWriRZgPT0t8G84lnl6IIO/63sS1j75TZVGTYWvWEBUz4CnWRHI2blW9bOJLs4u1nLnDRGBYKZtcZofmpDCdxg2uUGayQaOc8WqjM/VHovSSMWW0Oqz30QTBxN8tQqEsxGPDKtb7cja815SbKDx2KPv5ME012n8kAwlzdRq+hpjvUNZ0Wgd/FaMZXkYBxjun4WSTCPu3lp4oGi17EyPDRXd83ExoBTwQySJanDdGbAZ20yI0jyHuuMDFayNmtjm9w3V70BWV/PkAyCyskKOXY4HHQxnUNg44HzGRtLsFoEvtyRQrhurqc8qxxhjpn79xTepSvnMMk77keSYOKd1wVT1uZjDcWZM/h2kQppg7aSbBirCF9gijUYr484/tgdHELaTnvQp/JCHzEGHLNJvszsIDl/Yp3zY5/qiR6VM+D6wDaoaMOKlu+nhJoZsv1naujSICEc+bC1ztTJ45K+lHy8R3N6IW6TQRm46hv9D4pJncGULUbvAAAAAElFTkSuQmCC>

[image3]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAFMAAAAaCAYAAADL5WCkAAADMklEQVR4Xu2XW8gNURTH10GUoiTlUsglnlxyyaNyKw94ohRFEqXP7UWK5BJvlFK8yZMX9REphVLe5EkoUh5cc4uSu7Vm7X1m7TV79syZmXO+OZxf/c/MXmtf19579j4A/zMNbfgnaPeoGkfx5w9qkfZ0Ae0OTiEomD0qQgZzk3iXbNWGMtB2+ATcMOkr6gPqI+oXrjiyvYiz58G/Sv3WBFNQx1GvUH2o/ahnwP18jvqJ+oEaZwsIqImXqGuo86hbrhveqfRrlaYyZJuMuoN673hbwAZTMx7Y/kU7qsMbZtuXHY4V4Ip5nkItkw5w+/8dtVikLbRQiDeOlenDnvTj8xJqLPjjkQsqeFkbDWmB9iJCMwi1GbVdaETsDhK1h3XtVPbZqGnmXfbpAuqJSIf6m+Uboo2tsAq4kjnagYyCePvnZR5wmYPAdU4CnunRkLIMPdgB73KsPEFr+LXxUNgp/wZReVrA7NbVW96SVi439yC9ErsqaRB5OI06q40FaAZTRX8WaqJ5p++n5YawnwH+5q2L3UDTqAP4VqWnoz4rm5fQirABm2o0E3XS2C5ShlBhwUjUTW0Mkl6xDeZux8oHE61yOiCHCftgiA7M6Fs4HPiQOif8uh7LPvFOh9xakc6HGgN1nIKwFLXEPDca+1WRL4VmbbQaqkIG0072N+CArbSZ6ob9Xs7VDuCZJ99T7UiB8s6P1DDPpPJ+LpyVidP12KSPocaYd0H6Eu8k9yHuuA+7KvJA+WhyQhoa5cweu2+b23shbeFakhWsLL/kkTaUwBfM1agVwBNyW9iTZE9WW6BOX9dGg/1nZE/JLOhfSX/xgciC0T8vQh8c9kTehlpOL4WaK1QozB7gYC1Q9hnAH3vyLWRT7tbpanRAG0PENTtt2HstXfrlqU08MM+7wHfYAeUE8N+t3xBvYxKl6e5GB876Zu7WoUs11UerZwLwVSWDZiBpJdKJrfsl739blM/3Z6Macq8hRdFyAejzsBd1CHUYdQS8J3GPUrgT14ZpDNHh5gaW0GBDvlK0reIKqUMf69AHh9p1qBzOcDo7tgpbS1SVMHQpJcZRomjn6arO9uhRBX8BBJ+suEG6J8UAAAAASUVORK5CYII=>

[image4]: <data:image/png;base64,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>

[image5]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAoAAAAaCAYAAACO5M0mAAAAwElEQVR4XqVQsQ0CMQy0CxAzIIZgA5agoP6OIeipqNgHJEago2ANGqTn/AmBnB3pESdd3r47v6OINKAs/IA/ZseNjksxRk01Qg3ZYQkewIk1KtphcF9HRKbgBVyDPWIPfOdgh7r/3nSyA8I2BWWRdQvdSkpUd7m4mzlcNv1mVjKD/Slt7TnQHWztikUe2NjFSfMpKFdJq61mr+qe4NFlHHKglWvpEltvLfIYLlOG2aGe7QD8PNw7M1LiroK3NBITXmoXFKc9t1tsAAAAAElFTkSuQmCC>

[image6]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADoAAAAaCAYAAADmF08eAAACEUlEQVR4Xu2Wu0sDQRDG5wQff4OIoJUgiJWtFopgLWhtJ1jbiIVgIRaCYKcSMYWoKNrZKYiItZ2FjQ8EtRIUfMVvbjfc3WQ3d5dsHqI/+LjsNzuzM5fHhegv40mjIlTnFDfnuKghsJW0+UyxWCLKLuCQeuqlkPK7G0GNbWkKZqAvrWERq2umoRcop7VT5H59QKv6dTP0DbUE4d+DP6g0Nc/QY2i9TGp/X8izYL111kB6/FKJ69kG7SAVaxd+j1gH6CN7oSWoUdsT0IJ+bSVxu6VjG/ScVIxpgoZCMSu88RQaJZX8BrWSGjZfLBUl3QBzkm3Q/Pd3CxqAuvWaP75WjvV1kvzNXpu/8vzEq/ymCEFTY1AWyyxfhTahDSiDhHVc1yimEQPcw640KRh0LuR1ak/1b2BWX68p+g7Ww68X97MnTQoGlbB3L00JbzqRpnvMn1EL3NO+NKn4oCY/Am/ojzjxPQ1Ciyk0r9IU8eX9ng6ilp91oWOS2EHHKWaDexKMqXo6lCboInO/7GWkGeDRJZkTawk/DbinMxnQvEJHoTX/FSycQdzPT2gl4qR7sJdH9Jgp6AnmHa430C30QOqxJ+F4DvnvpP7+NbDptGunxSzkz6jGWaXjqjtTHZNXEbwqnvVPLanR25z82OQ7K0zdNJKecOvVGsPxOY7LlfswMaQZLEVhoNBJgzU7ErDuckBQ+wcjLWk1MNOWkwAAAABJRU5ErkJggg==>

[image7]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA0AAAAaCAYAAABsONZfAAAA/UlEQVR4Xq2Tuw0CMQyGnRXoGICSDon2GsQQFGzAAFRMQInYASGxCg0lSFQswcM+23k5OSkSn+S75P9tJ5e7AxCcGeRUjTpUomGMJtIC54XmRow24PKBJpUEFVy0FY/LBdJyIaJvMkDFdQu8XDA2xikMZxhfnHYy38pcOdAlXmkKlAAwijSCik4yficOcMErF5EPsDfHWJGgK3ViLMPafvAUjyKBlmexz03O5ybeWAVN2YnBs/RMr8GzkDHJ3sEd4ywesfcd5UanRqfT7x+1oyRSwkP0td2IUlb/TWmVkhYofapBsV79CWs4+X2iqrYGEa2FJt8Lxonwv3t+Z34Y8SL0/NhuLwAAAABJRU5ErkJggg==>

[image8]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABEAAAAZCAYAAADXPsWXAAABKElEQVR4Xp2Tvw4BQRDG9zRqrVajxCtQewSVd/ACel5DK1GSKBQK0Wq0WoREIcLMzezt7uyfwy+ZbO77vt0Zt06pP8mkEAZjflQrjuPHCNKzhB9zHMKhsOoyhtQV1jfXA+oMdYF6sXYy8RCmjT6EZKPXIYP6vVBywvNhcC5FxmkQo68o1JIGdKwp8zOT7HhkxhlVT1GxRUG+QQcbXE2oCWszE7NWnwzDK6geVBeCuA4yOmThRCPo99GWBlBV5B2lIdnzJP6o+XPuld4MBm5SZIaK/E2hyEYK/0gUGjkqBTvsPR3POqULtVXmVg5Qa7CXuFr6tNhRxpdfp0Uw7x8jnzX0rqVait+AYTniJvllz/dZTKbSyYGDqhaDZhmRTdY1eIlC+LGxjH0An/I5ZsuJqF8AAAAASUVORK5CYII=>

[image9]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA8AAAAbCAYAAACjkdXHAAABD0lEQVR4Xq1Suw4BQRS924ioVcQPKLT+wC/4BRV/oxK/otAIhVZCTyQSWa8CWWfm7mTntZsdnOSYmXPuubO7F1EAIltQim64RYWISoXz9DKoyd8vOmzBi9wFhptgkrIgLA3HVcHEcRScHO8H4Ig8NxuNsoPx5TmghyXM6RhIjRnYSqUjGWEF53klxFh2mj4nDjuFPjys8xQ5EW5bOkNr2cP+hnUNdYl1BR6Ib+5nZX5sEI7RLSaxMu/E4aFRaaEBLmwR6BCHJ3z0D8rzRUnYFWJPvIKDKrgnfjwf6sThp22M0fqM9UQcvlrzeIPKF+//ArtcU2pyZRDQKKD0D9D/ydrNrhKOn8LB+O9t+d1s5wMXQzTKmNb37gAAAABJRU5ErkJggg==>

[image10]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEYAAAAaCAYAAAAKYioIAAACqUlEQVR4Xu2Xv2sVQRDH5wWCSCoVGwULE9AqqBBFEButA0piYYx2IlZiqU0IFmIjWGihGDSFpLARlCSF/4CGNLZ2YiP+/i0xycyb2bt9k739ce9yeQn5wLx3953Zmdm9zd4LwLqk4bmribaLWglScqXEphGTOSYmgqQ0CcEJoRVTR2WusaTUktTRMFhlzEUDbuDnV+CJkP1G+4z2Be2/aO8lOpYZSFyYVZp+D9oscC+voGQZszCaXWhLmPGHduS01NsCBblKdVWe3cA9bJX7HXLflUVEQoOeaVFwTrSAn2gTwPF7a14MG+pjqnlFTXAjr9H+ZBEtuDsdBJ7IAe1AtkH+JxbiONo9tEvAYyhvNO7WSkP1zyjtmugO3NXn0FEwINstMVvQ5KAFouvrlq9OTP1jSr8g+nalF0JnCA3oFduPdpt0MNsxzF3IG9kJPPZJ7q4W9/PNuAJc/5DSh0U/kimBRBT8Eu0k2gn5Pi/6cyvOx7f8slmNxr7JNS+TBfYY7RHwmfUQ7QHafRnjYxy4fr/ST4k+onQn5nw5qB2Qv2HeaofiHVq30mgcve49qMcVeHpNrBhP+EXg+vrMHBKdHn6QeeDgIsjn8/cBn/S0Y2wLjWsbz8KYM+ao0kdFp1d5kNAECv3SmNMHnnEObvmt0XLvWRCD2ekJb6WVUOC0FgXzi3iPdghjaOe0KCQsTMRU06Had5T2QnQI1bwKHDig9H1of8V3WPkMlzE3+fXZYjAL4+/AEBeVgmt30P1ppVk04CZ+/kNbhHwCZHS/AHzYns3iV/IL7SPad+B4m6eifwL+f4vOnw8tEfVBPxfoBUDfND96jXceZlNUvzlKEGwiGFAHHdHEWlDdxKvLZLM6WdeADTORTmZzkTcx8F6oaUe0X6b9DBueTluiZf9soKaP5vxKAAAAAElFTkSuQmCC>

[image11]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEsAAAAZCAYAAAB5CNMWAAACdklEQVR4Xu2XTUscQRCGawQJKJEkrGgwOSS3XLzmYC75B579BR4lV49evAuSe8gvCCS3nBLIUUXBSxASCApKItH1E7Vqa5rpqa6e7p7d9Yt5oHZ33v6o6nd2e3oBboAsKDR0R4KhCV1tLqXQPTUrueWsgGJWZ6k3sd6e5gxMFmiWTGI8BcUsD53p32DsAg/6gTFg97hmHoEsvuzAW4xN4D4fSy0guwb5kr/HmgVLGMvWdRt48EtLiyex2pxRjF/AeU1ovMO4sK5nwd83xHer2Og5qONrRbMmqOdANd45PWZ1+pP+SjSQtmhdHwWCeJGHQcnnMgyiuHwJnoItuOOMUCWDGA+lGIBzu15Od3SXE9B1Lxn/mr7m8Q14PH0OkS3gy5QQw2YxYxj7UsyhG3EqxQh8uWkxmr4Fuh5LcIN371sZGmzvDV5womf4diBkMupMaLG4ZnG1/xyd2QBdj+E9xl+MPYz/oi2KNeDkQ7KhgucYh/lnMurcamNCt6fANYvx6aug64nEF2igjZ4S09MpFWNYYVR6fsJnyh/Q9XXQ9Xhq1PkYOOkD2aDiJngC/NMzTxytTww+s3x71k/Q9b5Bh1CZ8IO4rsIYRQa18LVd6VNlo9esedD15KdhGm6x2mauaRr0jZSbORlm9rBEMp9ZBOl0Y6T2yVy4SyN0tQ70eKdzjSnSjhAjGMclpaiLDJNPyRis3M4it4GPCoZx4L50nus7E+AaZKLYe/zMSUFAB9KWs2SFjI8GtIn/zoM+kyah/7A7GJ+B6yz9LYvJ1eDjXrl3rxZzx2i8d4izJK6XRsXIoqmiU0NDF2Rdfbdqja01qKEH9M/5K5UInITGaPkQAAAAAElFTkSuQmCC>

[image12]: <data:image/png;base64,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>

[image13]: <data:image/png;base64,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>

[image14]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADoAAAAaCAYAAADmF08eAAACZ0lEQVR4Xu2WP2gUQRTG36nxT6HpLEQkWgmCpDJl0oigbYrUdoHUaSSCnZUgWIgWKcWEhKiFYpOABAkhjcHGQgyaoKggCAqJ5vzezbvbmbczuzt7u2dzP/jYne+9mXlvd2/3iGwazshDboKfktP61E0dN6bUmqlJKUMI+XVQwV5FlzB5RbML4y5Y+fKGq9BjbfJe1n43oL+iK4kdpKZSDS+hH9BBHfAwDf2EmqI5N+ywBz2U8yPQPnQ0CRelZO8y7RD0FtqCjlnhGLIa/Q59tcZ3yeRfsrxaGYS+QOskPRe6Xv6kUKNnycTOKP+iGqcYhu5AAzK+jp1vW3HBX40wBP2Gnio/CrVDqNHXZGLMYeiyFQvCia+gcezCk7nYU8TNmnEe/KjsI/e+DmgyL5OfJib5Gm3/fh9BY9AFGfPja+HuuCzHSTLJp2XM5+/kPAt+cTzTZkU0Ueq8Nilp9JblnROvXX+KGTm+p+RxYGLeXsehHRS1geMBHewCrmdBm5Q02kHuHXs7+k5qOGmlPchODcKfjzfQByr/prVBTY1FTzFWo04wdQF8cMKoNrvgOZlv50kdiIBrWtImWCN/Q7mNTlBOQhbta5q+8C0eQLtkfkOxcE1PtAnOk67XbM7erOMrNklPzCHQVEaAbkIntJkBfw24plVnzeT8F/QiCbT+Cub28Ae6p83e0ulgCvoGbUMfoU/QZzKfPQ3HuTl+YvjvX5Uvwl4TfkR6zbUI1Vu3XluPE8KRDEb8ajjjhjkGKbVziFKLxUyS3JgpPrqdXw2lqwhNDPkuxbL6/D+i7lBUcp9eUM0t6WaVf3/WcjIrDbraAAAAAElFTkSuQmCC>

[image15]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAD0AAAAaCAYAAAAEy1RnAAACM0lEQVR4XuWXuy9EQRTGz+01REEtEhI6iUSl8IhGo1CQ6JR6qk2oFEQkoiCESkSo/AsKlYZoSIh3iEeh8jjHmbtmzs7O7uyd3evxS072zvedM/fM7Ny7WQBPIimUGf1+5r2/R5XuKQdbAzYtGD6T++RWFNlYJIUguCd1u544JnNYRRF2b4JOlogmjBspCjownjE+MGaFV0bCbnkPxh3wIihuTdtgD8xNOcIY58ugPSWlcDNahmvRk8B+TK0a72paYAr37sZZnzVdiyZvmS+z+fQ42KEUcc9ujB3Uxkw5dfItuhfYG1Djfs0rSBtwcacaT6hxzIJ2nRznt2uFF51btwHsDWNkMKoxzjGutBwrrcCFNUInbVNdv+mGhUGMdTOi+HoNYxVjBegYRrCEn3OqrlioF3qpSY6BvQehkzafHeVu1lfCtcV5V147xpDwLOm+eE1AfdxLEdkH9kaFTpp+Ug06gU16NiRnIIu9+rRQer3t2yTo9JDXIHTnoun45jMPgb16aVjowpj2iCkuKxrq41GKSB+w1yx056IzkNeMDiCvR5T+tZUA9fEkRQV59CKTGj2eJlrLlND4PfziBGNLecRM0CX6T0Z9vEpRQS9K/UVbBZxfp2k50FubiuIjsah5p0ob0bRK0QL8HF8A/wzFP0UvepJiG7jPS/VJtf8F/yP080h7DaXdX1bJccqE/Vf4h7Hvk11NF5+efHIrQtKGktYXotzzu0jz3r8HY5d+4JYlbOkTDVl6FwWACysAAAAASUVORK5CYII=>

[image16]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAIAAAAAaCAYAAAB/w1TuAAADqklEQVR4Xu2YW6gNURjHv+3k8iBRlHRSeCFyefHghQf3By+U8+CFB6V4VUIRD1JuIQ8ux6UIub3gjZIkL4oSidzJJXe5Ht9/f2ufWfPNrJnZZ2aftR3zq/+ZWf9vzZq11nwzZ+1F9A9T0UZJSUlPpiGvfEMazU2RvSqyrR5L6iTZFVIrlxTFXNZxbSpWs34bzVKxTvQz0+XGUM9ddN1QeSCrI1onxBTWR6rWo20q1l0kdpDS46Cykv98IhkIdCIcD/GTtdec92X9YfULws1IljmoMoT1mIJ5gFxc43ZfWW3fYa2y4nWQuX9ZydVgUgK8Zb22yjtI6k+2PC/kGbHj2qQE2EDh2GBTPm95/yyuBBhBEhuu/PGq3KQ4HrObjoo7AeDvV95oVU5lImsrq7cpL2FtCsLecCUAf/I6J6QPa4YV6ypoZztrN2uYinXhmRWK6wuANQ/8+aY8z4plBgO/wlpA0tg3kglAEsTdtEHEzrArAWRCKnSMj9NYY42HfwNd4T7rNgUvANrCp7WG75fBlQBYIMNfxFrHGsR6wnph1UnlkjkuI2ms1TwMnN/DSeyjERayjjh0mHWQ1U7yidpH9T8g9OGkNimYkPWWN9J4rZaXCo/tKx8eKruNI7UJX0GRNiMzosdu6xDJPBwgmQcsWrFgTSe4jSsB7pL475QPb6fynKw1xwcUvknyajoyBw0B/Tklp6EbuiYE3nNtJrCF5Jpeym8x/jhz9EN6Atwg8Zcq31U/EVxwWZv5yZUp6NNpOVUJUIkdYL0DT6oP/yhrpg54wNXPdhJ/lPJd9RPBBVO1mcJ01uY6tFEuywz6dFabzHWKH6Bj4M4kRN2b2jQg9kGbDvQ40zRALnOjeuwYF80h8cco31XfSZvjjfJD+NN3LgiAahA/c+L6C6/dKqPyGqusQf3aRpIGseXa9ETSA4WPRaD2sCmWQjDRt8h9A1/g1wn6dFUHDFi8XbTK2BLWY8BmETzsLkZeK5LNku/Km03BTiQWbS18HbZZfZKUAFhsYxu8Rn+SukMtL5VfrF3a9ATeujesZyQ/aZ6yXpL8PNUgjsH+IMl4vZibQJIEj5RvqGbEHgom+DPJwg9MMt4XU85ENMdy8Z5kUYtxQjiHpzlD0lfEcayNocRwQRsl3U7B70Z2FlPkd3zJ/wT+fcTgLSH9YIbblKMuplPFtFKSSPGTXHyLeWiu3pQoysdTJKmzmVqhpChyTHWOS4XcDXQnPjvr894lJUWh8/gv6QzpBj+1waIAAAAASUVORK5CYII=>