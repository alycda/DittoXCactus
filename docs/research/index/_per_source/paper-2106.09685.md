# LoRA: Low-Rank Adaptation of Large Language Models

- **Source ID:** paper-2106.09685
- **Kind:** paper
- **Path:** inspiration/papers/2106.09685.pdf
- **Density:** 2

## Elevator summary

LoRA proposes parameter-efficient fine-tuning by injecting trainable low-rank decomposition matrices into Transformer layers while freezing pre-trained weights. The method achieves comparable downstream task performance with 10,000x fewer trainable parameters, making it relevant for resource-constrained on-device inference where model adaptation is needed. For Mesh RAG, it demonstrates patterns for efficient model adaptation in decentralized settings.

## Tags

`parameter-efficient-finetuning`, `low-rank-adaptation`, `transformer-optimization`, `on-device-inference`, `model-compression`

## Topics covered

1. Low-rank decomposition of weight updates in neural networks
2. Reduction of trainable parameters and GPU memory requirements
3. Application to instruction-following task adaptation
4. Comparison with full fine-tuning and other adapter methods

## What we'd take from this

- The LoRA adapter pattern (Eq. 1-2): how to reduce parameters in Transformers via intrinsic dimensionality of task-specific updates
- The practical validation that models retain generalization even when fine-tuned with 0.01% of parameters
- The inference-time composition strategy: adapters stack without increasing latency for multi-task scenarios

## Cross-references (optional)

- repo-thinking-machines-lab-batch-invariant-ops (deterministic inference requirements)
