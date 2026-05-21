# LoRA Land: 310 Fine-Tuned Large Language Models

- **Source ID:** paper-2405.00732
- **Kind:** paper
- **Path:** inspiration/papers/2405.00732.pdf
- **Density:** 4

## Elevator summary

LoRA Land presents 310 fine-tuned 7B-scale LoRAs that consistently rival GPT-4 performance across narrow, specialized tasks without increasing base model size. This directly supports the "small specialist models beat large generalists" thesis central to Mesh RAG's Stage-1 vision of domain-specific on-device LLMs that fit within mobile memory budgets while maintaining quality on constrained domains like recipe merging.

## Tags

`parameter-efficiency`, `fine-tuning`, `lora`, `specialist-models`, `7b-scale`, `task-specific-adaptation`

## Topics covered

1. Parameter-efficient fine-tuning at scale: 310 independent LoRA adaptations of a single 7B base
2. Task-specific performance parity with GPT-4 on instruction-following benchmarks
3. Transfer learning and generalization across narrow domains
4. Memory and storage efficiency of adapter-based approaches

## What we'd take from this

- Evidence that 7B models, when fine-tuned, can outperform much larger models on domain-specific tasks — directly applicable to ingredient-list merging and recipe reconciliation at demo time
- Methodology for evaluating task-specific adaptation quality on fixed instruction-following metrics
- LoRA as a memory-efficient path to model customization on mobile (full fine-tuning would not fit; LoRA adapters can be kept separate)

## Cross-references (optional)

- paper-2402.00841 (Tiny Titans — analogous specialist-vs-generalist evidence in summarization domain)
