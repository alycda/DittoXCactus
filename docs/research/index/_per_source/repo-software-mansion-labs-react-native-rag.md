# React Native RAG

- **Source ID:** repo-software-mansion-labs-react-native-rag
- **Kind:** repo
- **Path:** inspiration/repos/software-mansion-labs__react-native-rag
- **Density:** 4

## Elevator summary

Production React Native framework for on-device RAG with modular LLM, embeddings, and vector store components. Powers Private Mind (production mobile RAG app). Demonstrates patterns for integrating ExecuTorch on-device models with SQLite vector persistence. Core reference for mobile Mesh RAG implementation.

## Tags

`react-native`, `on-device-llm`, `embeddings`, `vector-store`, `rag-framework`, `executorch`, `sqlite`, `mobile-rag`

## Topics covered

1. RAG hook API (`useRAG`) for rapid integration
2. Class-based RAG for advanced control
3. Component-level APIs for semantic search
4. LLM interface for custom model integration
5. Embeddings models using ExecuTorch
6. VectorStore persistence with SQLite
7. Text splitting and chunking strategies
8. Memory-based in-process vector stores

## What we'd take from this

- The modular RAG component architecture (LLM, Embeddings, VectorStore interfaces) for Mesh RAG design
- SQLite-backed vector persistence pattern suitable for on-device storage and sync
- ExecuTorch integration for deterministic on-device inference across heterogeneous hardware
- Hook and class-based APIs patterns for flexibility in consumer integration

## Cross-references

- repo-ukplab-sentence-transformers (embeddings models used by React Native RAG)
- paper-1908.10084 (foundation for embedding models in the framework)
