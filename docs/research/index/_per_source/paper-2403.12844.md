# MELTing point: Mobile Evaluation of Language Transformers

- **Source ID:** paper-2403.12844
- **Kind:** paper
- **Path:** inspiration/papers/2403.12844.pdf
- **Density:** 4

## Elevator summary

MELTing point presents MELT, an automated benchmarking framework for evaluating large language models on mobile devices (iOS, Android, Nvidia Jetson) with granular measurement of end-to-end performance, memory, and energy consumption. It directly addresses the challenge of deploying LLMs on personal devices for private on-device RAG, establishing baseline metrics for Mesh RAG implementations. The infrastructure design patterns and energy-profiling methodology are critical for understanding mobile constraints.

## Tags

`mobile-llm-deployment`, `on-device-inference`, `energy-profiling`, `cross-platform-benchmarking`, `privacy-preserving-ai`, `embedded-systems`

## Topics covered

1. Automation infrastructure for headless LLM execution across platforms
2. Memory and energy profiling on heterogeneous mobile devices
3. End-to-end latency measurement under varied hardware configurations
4. Comparative analysis of popular instruction-fine-tuned models on-device

## What we'd take from this

- The MELT automation framework: headless model loading, inference execution, and telemetry collection patterns for iOS/Android
- The device-specific profiling methodology in Section 3 (granular energy and memory measurement)
- Empirical data on LLM runtime requirements for common models: which models fit within typical mobile memory budgets
- The framework's extensibility design for new models and frameworks

## Cross-references (optional)

- paper-2106.09685 (parameter efficiency for mobile adaptation)
- repo-thinking-machines-lab-batch-invariant-ops (deterministic evaluation requirements)
