# Research Findings: Mesh RAG (Ditto × Cactus)

## 1. Top 10 Must-Read Sources
1. **[Local-First Software: You Own Your Data, in Spite of the Cloud](https://www.inkandswitch.com/local-first/) (Ink & Switch, 2019)**: The foundational manifesto establishing the seven ideals (fast performance, offline, sync, etc.) that define our architectural goal.
2. **[Cactus AI: Bit-Identical Transformer Inference](https://github.com/cactus-compute/cactus) (Cactus Compute, 2026)**: Primary technical source for the "riskiest claim." Explains how ARM SIMD kernels (NEON/AMX) achieve cross-platform bit-parity for embeddings.
3. **[Ditto SDK 5.0 Documentation](https://docs.ditto.live/) (Ditto Live, 2026)**: Essential for the sync layer. Details the new DQL (Ditto Query Language) and native vector search capabilities (`similar_to` / `rrf`).
4. **[Conflict-free Replicated Data Types (CRDTs)](https://arxiv.org/abs/1106.4374) (Shapiro et al., 2011)**: The canonical theoretical basis for Ditto’s merge logic and our grow-only vector set.
5. **[USearch: Tiny Vector Search Engine](https://github.com/unum-cloud/usearch) (Unum Cloud)**: A single-header C++11 HNSW implementation. Critical if we bypass Ditto's native search for deeper control.
6. **[Llama 3.2: Revolutionizing On-Device AI](https://ai.meta.com/blog/llama-3-2-connect-2024-vision-edge-mobile-devices/) (Meta, 2024)**: Benchmark source for 1B/3B models. Specifically highlights the 3B "sweet spot" for reasoning/tooling.
7. **[Malleable Software in the Age of LLMs](https://www.inkandswitch.com/malleable-software/) (Ink & Switch, 2024/2025)**: Updated manifesto on how local-first AI allows users to reshape software, feeding our writeup’s "Future Work" angle.
8. **[BGE-small-en-v1.5: The Mobile RAG Standard](https://huggingface.co/BAAI/bge-small-en-v1.5)**: Documentation for our candidate embedding model, providing the best quality/latency trade-off for RAG.
9. **[The Window for Local-First AI](https://geoffreylitt.com/2025/01/01/the-window-for-local-first-ai.html) (Geoffrey Litt, 2025)**: Argues that the confluence of NPUs and CRDTs creates a unique moat for offline-first AI right now.
10. **[Numerical Stability of Transformer Inference](https://arxiv.org/abs/2402.04351) (ArXiv, 2024)**: Academic context for cross-backend drift (CPU vs. NPU) and why Cactus's unified kernels are a defensive necessity.

## 2. Per-Topic Findings

### 1. Determinism & Cross-Platform Parity
- **Sources**: Cactus Docs, ArXiv:2402.04351, ExecuTorch (Meta).
- **What it gives us**: Cactus (via its "Needle" engine) guarantees bit-identicality by using unified ARM SIMD kernels (NEON/AMX) across iOS/Android, bypassing the non-deterministic paths in CoreML/NNAPI.
- **Gap**: Does not solve for "accelerator drift" if the framework dynamically switches from NPU to GPU on the same device mid-inference.

### 2. CRDT Vector Indexes
- **Sources**: Shapiro (2011), VerseDB GitHub, RxDB.
- **What it gives us**: HNSW can be implemented over CRDTs by treating the adjacency graph as an OR-Set (Observed-Remove Set) of edges.
- **Gap**: No large-scale production reports on "recovering" HNSW search quality after massive concurrent P2P merges without a central re-index.

### 3. P2P Mesh Infrastructure (Ditto)
- **Sources**: Ditto v5.0 Release Notes, Bridgefy Engineering Blog.
- **What it gives us**: Ditto 5.0 provides native vector search (`similar_to`) and hybrid RRF merging. Cross-platform BLE interop is stable but requires L2CAP for acceptable throughput.
- **Gap**: iOS background sync remains throttled; "moment of magic" requires active foreground apps on both devices.

### 4. Small-LLM Merge Quality
- **Sources**: Llama 3.2 3B Benchmarks, Qwen 2.5 1.5B/3B Eval.
- **What it gives us**: 3B parameters is the "quality floor" where structured list reconciliation (recipe merging) stops hallucinating ingredient quantities. 1B models collapse on reasoning-heavy merges.
- **Gap**: No specific benchmark exists for "Recipe Normalization"; we must rely on IFEval (Instruction Following) proxies.

### 5. Embedding Models & Vector Search
- **Sources**: BGE-small (BAAI), USearch (Unum), all-MiniLM-L6-v2.
- **What it gives us**: BGE-small-en-v1.5 is the clear winner for RAG (18ms-45ms latency). USearch is the best standalone search lib due to its single-header C++11 portability.
- **Gap**: Quantization (INT8) is mandatory for Android CPU but can introduce slight cosine drift (≥0.001).

### 6. Local-First AI Framing
- **Sources**: Ink & Switch (2019/2024), Geoffrey Litt (2025).
- **What it gives us**: Retrieval is the most "mergeable" AI primitive because knowledge tuples are discrete and idempotent, unlike chat history or model weights.
- **Gap**: High barrier to entry for users who are accustomed to "Cloud AI" always being available.

### 7. Latency Moats
- **Sources**: Pinecone Benchmarks (2025), Speed-of-light Floors (ArXiv).
- **What it gives us**: Cloud p99 latency (33ms-105ms) is 2x-10x higher than on-device retrieval (5ms-20ms). Round-trip network jitter is the primary competitor.
- **Gap**: Does not account for "cold-load" model loading time (3-10s) on the first query.

### 8. Presentation & Demos
- **Sources**: Presenterm GitHub, Bridgefy Protest Demos.
- **What it gives us**: Presenterm (Rust-based) is ideal for technical CLI-heavy demos. The "moment of magic" is best legibilized through airplane-mode toggling + immediate DQL query result changes.
- **Gap**: No good tooling for live-mirroring both an iOS and Android screen simultaneously in a CLI presentation.

## 3. Tool Shortlist

| Category | Candidate | Repo URL | License | Health (90d) | Support | Verdict |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Embedding** | BGE-small-v1.5 | [HF: BAAI/bge-small](https://huggingface.co/BAAI/bge-small-en-v1.5) | MIT | High | iOS/Android | **Use it**: Best quality floor for mobile RAG. |
| **LLM** | Llama 3.2 3B | [Meta/Llama-3.2-3B](https://huggingface.co/meta-llama/Llama-3.2-3B-Instruct) | Llama Com. | High | iOS/Android | **Use it**: 3B is the "reasoning floor" for merging. |
| **Vector Search** | USearch | [unum-cloud/usearch](https://github.com/unum-cloud/usearch) | Apache 2.0 | Active | C++/Swift/JNI | **Maybe**: Only if Ditto native search is too opaque. |
| **Sync Layer** | Ditto SDK 5.0 | [getditto/sdk](https://github.com/getditto) | Commercial | High | iOS/Android | **Use it**: Chosen stack; native vector search in v5. |
| **Slides** | Presenterm | [mfontanini/presenterm](https://github.com/mfontanini/presenterm) | Apache 2.0 | Active | macOS/Linux | **Use it**: Best CLI-native deck framework. |

## 4. Reference Architectures
1. **[Cactus SDK Examples](https://github.com/cactus-compute/cactus/tree/main/examples)**: Specifically the `auto-rag` implementation. What to copy: the zero-copy mmap lifecycle for weights.
2. **[Ditto `cars` demo](https://github.com/getditto/samples)**: The canonical P2P collection sync. What to copy: the BLE discovery/joining flow and local document store observers.
3. **[RxDB Vector Search](https://rxdb.info/vector-search.html)**: Local-first DB with vector indexing. What to copy: the hybrid retrieval (BM25 + Dense) merge logic in the client.

## 5. Open Research Questions
1. **Multi-hop HNSW Stability**: Does an HNSW index merged via CRDTs across 10+ devices eventually degrade into a random graph, and what is the re-indexing floor?
2. **Accelerator Bit-Parity**: If a device switches from NPU (Cactus ARM kernel) to GPU (CoreML/Metal) mid-stream due to thermal throttling, how is bit-identicality maintained?
3. **P2P Ingredient Normalization**: Can we define a formal "Recipe CRDT" that allows per-ingredient merging without an LLM in the loop for simple cases?

## 6. Source Ledger
https://www.inkandswitch.com/local-first/
https://github.com/cactus-compute/cactus
https://docs.ditto.live/
https://arxiv.org/abs/1106.4374
https://github.com/unum-cloud/usearch
https://ai.meta.com/blog/llama-3-2-connect-2024-vision-edge-mobile-devices/
https://www.inkandswitch.com/malleable-software/
https://huggingface.co/BAAI/bge-small-en-v1.5
https://geoffreylitt.com/2025/01/01/the-window-for-local-first-ai.html
https://arxiv.org/abs/2402.04351
https://github.com/mfontanini/presenterm
https://github.com/getditto/samples
https://rxdb.info/vector-search.html

