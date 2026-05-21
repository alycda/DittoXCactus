# Retrieval-Augmented Generation for Knowledge-Intensive Tasks

- **Source ID:** paper-2301.07788
- **Kind:** paper
- **Path:** inspiration/papers/2301.07788.pdf
- **Density:** 5

## Elevator summary

This paper explores retrieval-augmented generation (RAG), combining dense passage retrieval with seq2seq models to ground LLM answers in retrieved documents. RAG is a load-bearing architecture for on-device or decentralized RAG systems, where retrieval happens locally and documents are served from peers. This directly informs the Mesh RAG / Ditto × Cactus approach of distributing both retrieval indices and generation across a peer-to-peer network.

## Tags

`rag`, `retrieval-augmented-generation`, `dense-retrieval`, `knowledge-grounding`, `seq2seq`, `information-retrieval`

## Topics covered

1. Retrieval-augmented generation architecture
2. Dense passage retrieval methods
3. Integration of retriever and reader models
4. Knowledge-intensive task evaluation
5. Comparison with retrieval-only and generation-only approaches

## What we'd take from this

- RAG pattern separates retrieval (find relevant docs) from generation (answer based on docs) — a clean split for distributing work across peers
- Dense retrieval enables ranking by semantic similarity without brute-force search
- Grounding generation in retrieved context reduces hallucination and enables fact-checking

## Cross-references (optional)

- repo-unum-cloud-usearch (vector search for retrieval)
- repo-deepsense-ai-edge-slm (on-device generation)
