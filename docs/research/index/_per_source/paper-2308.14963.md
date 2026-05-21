# Vector Search with OpenAI Embeddings: Lucene Is All You Need

- **Source ID:** paper-2308.14963
- **Kind:** paper
- **Path:** inspiration/papers/2308.14963.pdf
- **Density:** 2

## Elevator summary

Lin, Pradeep, Teofili, and Xian (Aug 2023) argue that Lucene's HNSW index is sufficient for OpenAI-embedding vector search on MS MARCO, challenging the "you need a dedicated vector store" narrative. The paper is a cost-benefit argument against deploying separate vector infrastructure, not a contribution to on-device or mesh-based retrieval. Tangentially relevant to Mesh RAG only as a counterweight to "you must use Pinecone/Qdrant" framing — we already have a similar but stronger argument via on-device + Ditto.

## Tags

`vector-search`, `hnsw`, `lucene`, `cost-benefit-argument`, `bi-encoder`

## Topics covered

1. Bi-encoder retrieval architecture with OpenAI embeddings
2. HNSW indexing in Lucene
3. MS MARCO passage ranking benchmark
4. The "do we actually need a dedicated vector store" question

## What we'd take from this

- Rhetorical ammunition for the writeup: even *centralized* vector search doesn't strictly need a dedicated vector DB. Strengthens the broader "you don't need the standard stack" framing without being load-bearing for our claims.

## Cross-references

- (none directly cited; thematic neighbor only)

## Caveat

This summary is based on the arxiv abstract (fetched May 2026), not a direct read of the PDF (poppler-utils not installed in the indexing environment).
