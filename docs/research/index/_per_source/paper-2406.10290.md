# MobileAIBench: Benchmarking LLMs and LMMs for On-Device Use Cases

- **Source ID:** paper-2406.10290
- **Kind:** paper
- **Path:** inspiration/papers/2406.10290.pdf
- **Density:** 4

## Elevator summary

Murthy et al. (Salesforce AI Research, Jun 2024) introduce MobileAIBench, a benchmarking framework that evaluates mobile-optimized LLMs (and LMMs) on real iOS devices, measuring latency, resource consumption, and the impact of quantization on task quality, trust, and safety. The framework ships as a two-part open source release: a desktop library plus an iOS app for on-device measurement. Directly informs Mesh RAG model selection — it's one of two complementary mobile-LLM benchmarks (with MELT, arXiv 2403.12844) that grounds latency expectations for our small-LLM choice on actual iPhone hardware.

## Tags

`on-device-llm`, `mobile-benchmark`, `quantization-impact`, `latency-measurement`, `ios-evaluation`, `lmm`

## Topics covered

1. Methodology for benchmarking LLMs/LMMs on mobile hardware
2. Quantization × task-performance × trust-and-safety trade-offs
3. iOS-side on-device latency and hardware-utilization measurement
4. Open-source framework for reproducible mobile-AI benchmarking

## What we'd take from this

- A documented iOS measurement harness shape we can mimic when measuring our own Cactus end-to-end RAG latency on the demo device.
- Empirical baselines for the latency/quantization trade-off — useful when we have to defend "we picked Qwen 2.5 1.5B at Q4 because measured TTFT was Xms on the demo iPhone."
- The MobileAIBench iOS app's instrumentation approach is the closest existing pattern for the kind of measurement we'll need to do for the determinism + latency holdouts.

## Cross-references

- paper-2403.12844 (MELTing Point — complementary mobile-LLM benchmark; covers Android in more depth where MobileAIBench focuses on iOS)
- paper-2409.00088 (On-Device Language Models survey — frames where MobileAIBench fits in the broader landscape)

## Caveat

This summary is based on the arxiv abstract (fetched May 2026), not a direct read of the PDF (poppler-utils not installed in the indexing environment).
