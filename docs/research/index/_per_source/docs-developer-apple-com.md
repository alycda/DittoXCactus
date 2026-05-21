# Apple Developer Documentation — Foundation Models

- **Source ID:** docs-developer-apple-com
- **Kind:** docs
- **Path:** inspiration/docs/developer-apple-com
- **Density:** 3

## Elevator summary

Apple's official documentation for on-device Foundation Models (language understanding, structured output, tool calling) integrated with iOS/macOS. As of WWDC 2025, Apple provides first-party on-device LLM APIs for structured tasks. This is a reference implementation for "how Apple positions on-device language models" and for understanding the latency + privacy guarantees available to native iOS apps. For Mesh RAG, it validates that on-device inference is a platform-level capability on iOS, not a third-party hack; the structured-output affordances (JSON constraints, tool calling) align with our ingredient-list-merging schema pattern.

## Tags

`foundation-models`, `on-device-inference`, `ios`, `macos`, `structured-output`, `tool-calling`, `privacy-first`

## Topics covered

1. Foundation Models framework and API surface
2. Task-specific model selection (language understanding, structured output)
3. Prompt engineering for on-device constraints
4. Privacy guarantees of on-device processing
5. Integration with native iOS/macOS apps

## What we'd take from this

- Apple's official stance is that on-device inference is a standard app capability, not exotic. This validates our Stage-0 assumption.
- Structured-output constraints and tool-calling are first-party, not bolt-on; Apple's API design mirrors the grammar-constrained-generation pattern we are adopting.
- The framework is tightly integrated with system resources (neural engine, thermal state, memory pressure). Understanding these constraints informs our Ditto + Cactus composition.

## Cross-references (optional)

- paper-2505.14992 (structured extraction with on-device LLMs)
- repo-ramanujammv1988-edge-veda (third-party on-device RAG for comparison)
