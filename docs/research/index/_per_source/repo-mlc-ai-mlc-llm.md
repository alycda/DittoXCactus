# MLC LLM: Universal LLM Deployment Engine with ML Compilation

- **Source ID:** repo-mlc-ai-mlc-llm
- **Kind:** repo
- **Path:** inspiration/repos/mlc-ai__mlc-llm
- **Density:** 3

## Elevator summary

MLC LLM is a multi-platform compiler for efficient LLM inference, supporting iOS/Android/web with unified kernels across Metal (Apple) and OpenCL (Qualcomm/Mali). While we anchor on Cactus for the demo, MLC LLM is the reference implementation for how cross-device inference determinism is *possible* through compiler-level kernel control, and it's relevant if we need a fallback or validation path.

## Tags

`ml-compiler`, `cross-platform-inference`, `mobile-llm`, `kernel-optimization`, `mlc-engine`, `determinism`

## Topics covered

1. Machine learning compilation for efficient inference
2. Platform-specific kernel backends (Metal, OpenCL, Vulkan, CUDA)
3. Quantization and model optimization
4. OpenAI-compatible REST API
5. Multi-platform deployment (iOS, Android, web)

## What we'd take from this

- The architecture pattern: unified inference engine with swappable platform backends.
- Evidence that deterministic cross-platform inference *is* achievable through careful kernel selection (Metal on iOS, OpenCL on Android).
- If Cactus is unavailable or doesn't expose embedding APIs cleanly, MLC LLM is the proven escape hatch.
- Benchmark numbers from their mobile tests showing realistic decode speeds on modern phones (1B–3B parameter tier).

## Cross-references

- paper-2403.12844 (MELT — benchmark suite that measures MLC-LLM performance)
- paper-2507.01079 (MobileRAG — deployed using MLC backend)
