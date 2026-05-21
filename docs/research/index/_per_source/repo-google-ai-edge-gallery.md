# Google AI Edge Gallery: On-Device LLM Sandbox

- **Source ID:** repo-google-ai-edge-gallery
- **Kind:** repo
- **Path:** inspiration/repos/google-ai-edge__gallery
- **Density:** 3

## Elevator summary

AI Edge Gallery is a production Android + iOS application from Google demonstrating on-device LLM inference (Gemma, LiteRT) with agent skills, multimodal input, and prompt labs, serving as a reference implementation of mobile LLM UI/UX patterns and LiteRT deployment infrastructure. It is relevant as a concrete on-device inference baseline and UI ergonomics reference, though it is not mesh-networked and does not demonstrate RAG or CRDT sync.

## Tags

`on-device-llm`, `litert`, `gemma`, `android-ios`, `ui-ux-reference`, `google-ai-edge`, `agent-skills`

## Topics covered

1. LiteRT backend selection and model management (Gemma 4 / Gemma 2 families)
2. Multi-turn conversation UI with thinking mode (reasoning transparency)
3. Multimodal input: image analysis via camera / photo gallery
4. Prompt lab: parameterized inference with temperature and top-k control
5. Agent skills: tool-calling and augmentation pattern

## What we'd take from this

- Mobile on-device LLM UI patterns: conversation history, streaming token rendering, error handling
- Agent skills architecture: how to extend LLM capability with external tools (relevant if we want retrieval as a tool, not just context injection)
- LiteRT integration example: Kotlin and Swift code for model loading, inference, and cancellation
- Benchmark infrastructure: how Gallery measures latency/memory/quality on target devices (applicable to our Cactus + Ditto integration)

## Cross-references (optional)

- repo-software-mansion-labs-react-native-rag (React Native alternative with more explicit RAG patterns)
