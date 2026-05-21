# GGUF: Quantized Model Format and Inference Runtime

- **Source ID:** repo-ggml-org-ggml
- **Kind:** repo
- **Path:** inspiration/repos/ggml-org__ggml
- **Density:** 5

## Elevator summary

GGUF is a binary format and runtime for quantized LLM inference on CPU. It provides efficient loading via mmap, extensible metadata, and multi-platform support. GGUF is the standard format for distributing quantized models in peer-to-peer RAG systems because it's single-file, deterministic, and compatible with offline serialization. The gguf.md spec defines versioning and naming conventions that prevent model confusion across peers.

## Tags

`gguf`, `quantized-inference`, `model-format`, `llm-runtime`, `mmap`, `cpu-inference`, `multi-platform`

## Topics covered

1. GGUF file structure and specification (header, metadata, tensors)
2. Quantization type enumeration (Q4_0 through Q8_K, IQ variants)
3. Metadata key-value structure for extensibility (e.g., model name, context length)
4. GGUF naming convention ([sidecar]-BaseName-SizeLabel-FineTune-Version-Encoding-Type-Shard.gguf)
5. Endianness handling (little-endian default, big-endian support)
6. mmap compatibility for on-disk serving without RAM load

## What we'd take from this

- Single-file design: entire quantized model is one GGUF blob, easy to version and sync between peers
- Content-addressed names: following the GGUF convention ensures peers using different model revisions can detect version mismatches
- Metadata extensibility: peers can embed additional hints (e.g., embedding_dimension, context_window) for validation
- mmap enables serving large models from disk without memory overhead — critical for mobile peers with limited RAM

## Cross-references (optional)

- repo-deepsense-ai-edge-slm (uses GGUF models for inference)
