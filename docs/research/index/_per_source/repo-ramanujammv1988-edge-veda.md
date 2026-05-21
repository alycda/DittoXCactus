# Edge-Veda

- **Source ID:** repo-ramanujammv1988-edge-veda
- **Kind:** repo
- **Path:** inspiration/repos/ramanujammv1988__edge-veda
- **Density:** 4

## Elevator summary

A managed on-device AI runtime for Flutter (iOS-first; Android roadmap) with text, vision, speech-to-text, and RAG capabilities. Edge-Veda wraps llama.cpp, whisper.cpp, and stable-diffusion.cpp via a persistent worker isolate architecture with thermal/memory/battery supervision. This is the closest published reference architecture for Mesh RAG: supervised on-device inference, long-session stability (28+ min without model reload), observable performance tracing, and RAG pipeline end-to-end (embed → search → generate). Key difference: Edge-Veda assumes a local knowledge base; Mesh RAG distributes it via Ditto. The architecture, observability, and source-attribution UX patterns are directly reusable.

## Tags

`on-device-inference`, `flutter`, `mobile-ai`, `rag`, `speech-to-text`, `text-to-speech`, `supervised-runtime`, `thermal-management`

## Topics covered

1. Persistent worker isolates for model lifecycle management
2. Streaming token generation and chat session management
3. Speech recognition and synthesis on-device
4. Structured output and function calling
5. Embeddings, vector search (HNSW), and RAG pipeline
6. Thermal, memory, and battery-aware runtime policies
7. Performance tracing and observability

## What we'd take from this

- Keeping models alive across long sessions requires process isolation (Dart isolates) + persistent state; copying this pattern directly gives us non-blocking UI and predictable memory growth.
- HNSW vector search works in practice on phones; Edge-Veda's experience with index size / latency trade-offs is valuable for Stage 1+.
- Document Q&A with source attribution (the "which tuple gave this answer" visualization) is the exact "moment of magic" we need for the Mesh RAG demo — Edge-Veda has it; copy the UX.
- Runtime supervision (backpressure, adaptive budgets, auto-eviction) is load-bearing for sessions >60 seconds; the telemetry patterns are worth porting.

## Cross-references (optional)

- paper-2403.12844 (MELTing Point: mobile LLM benchmarks)
- repo-deepsense-ai-edge-slm (Android reference for comparable on-device RAG)
- paper-2507.01079 (MobileRAG; similar architecture, complementary impl choices)
