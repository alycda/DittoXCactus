# Batch Invariant Ops: Defeating Nondeterminism in LLM Inference

- **Source ID:** repo-thinking-machines-lab-batch-invariant-ops
- **Kind:** repo
- **Path:** inspiration/repos/thinking-machines-lab__batch_invariant_ops
- **Density:** 3

## Elevator summary

Batch Invariant Ops provides PyTorch kernel substitutions that ensure identical outputs regardless of batch size, enabling deterministic multi-GPU inference. The library demonstrates that vLLM can be made fully deterministic with minimal upstream changes, reducing output variance from 18 unique samples to 1 in 1000 completions. For Mesh RAG with embedded determinism requirements, it validates that deterministic inference is achievable without substantial latency overhead.

## Tags

`embedding-determinism`, `batch-invariance`, `deterministic-inference`, `pytorch-kernels`, `llm-reproducibility`, `gpu-optimization`

## Topics covered

1. Batch-size dependency in floating-point operations
2. Kernel substitution via torch.Library for transparent replacement
3. Matrix operations: mm(), addmm() with deterministic semantics
4. Activation functions: log_softmax() determinism
5. Reduction operations: mean() batch-invariant computation
6. Proof of concept: deterministic vLLM inference validation

## What we'd take from this

- The torch.Library pattern: non-intrusive kernel substitution for determinism without model code changes
- The test methodology in deterministic_vllm_inference.py: validating that inference produces identical outputs
- The supported operations (Section Supported Operations): which critical LLM ops can be made deterministic
- The quantitative validation: from 18 unique samples to 1, demonstrating practical feasibility
- The insight that batch-invariance requires careful handling of reduction operations (sum, mean, softmax)

## Cross-references (optional)

- paper-2403.12844 (mobile LLM profiling requires deterministic baselines)
- paper-2106.09685 (adapter inference must also be deterministic)
