# ⭐ Retrieval: Cactus top-k cosine + lazy embeddings

The RAG retrieval core. Marked ⭐ because:
- Cactus's flat-array cosine top-k was the deliberate technical choice
  (vs. heavier vector DBs) to keep the demo light enough to run on-device.
- Lazy embedding generation (compute on first read, cache via Cactus) was
  the workaround for DQL's lack of vector indexing in Stage-0.
- Fix(u4) folded in here: dropping invalid DQL filters and filtering
  embeddings in Dart instead — same retrieval semantics, fixed bug.

Original commits:
- kkrypvyt (feat(u5): Cactus retrieval — flat-array cosine top-k + lazy embeddings)
- tyxryyys (fix(u4): drop invalid DQL filters; filter embeddings in Dart)
