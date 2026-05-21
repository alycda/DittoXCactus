# DistilBERT, a distilled version of BERT: smaller, faster, cheaper and lighter

- **Source ID:** paper-1910.01108
- **Kind:** paper
- **Path:** inspiration/papers/1910.01108.pdf
- **Density:** 4

## Elevator summary

DistilBERT demonstrates knowledge distillation as a practical method to compress transformer models to 40% of original size while retaining 97% of performance. This is the canonical reference for model compression trade-offs relevant to fitting embedders and small LLMs on mobile devices. The techniques here directly inform whether we can run efficient embeddings like EmbeddingGemma or Nomic on constrained phones without sacrificing cosine parity.

## Tags

`model-distillation`, `transformer-compression`, `knowledge-transfer`, `mobile-llm`, `parameter-efficiency`, `fine-tuning`

## Topics covered

1. Knowledge distillation methods for BERT compression
2. Trade-offs between model size, speed, and accuracy
3. Fine-tuning compressed models for downstream tasks
4. Memory and latency improvements from reduced parameters

## What we'd take from this

- The distillation recipe for why smaller models (1.5B-3B) are achievable without catastrophic quality loss at narrow tasks like ingredient-list merging.
- The empirical evidence that 40-50% parameter reduction is feasible for our embedding and LLM tiers.
- Justification for the specialist-model future-work angle: if distilled BERT preserves downstream task performance, a distilled recipe-domain LLM should too.

## Cross-references

- paper-2402.00841 (Tiny Titans — related: specialist finetuning of small models)
- paper-2405.00732 (LoRA Land — related: parameter-efficient adaptation)
