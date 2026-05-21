# Codex Research Findings: Mesh RAG with Ditto and Cactus

Research date: 2026-05-21. This pass used primary documentation, repos, arXiv papers, and official model pages. A browser call cap was reached after the final batch, so exact GitHub release dates and issue time-series are marked "not observable" where the public page snapshot did not expose them; no topic was dropped for that reason.

## Top 10 must-read sources

1. **Cactus repo and RAG docs**  
   Sources: https://github.com/cactus-compute/cactus and https://cactuscompute.com/docs/v1.7/rag. These are the stack-critical sources: they define the available SDKs, CactusIndex, on-device embedding APIs, auto-RAG path, benchmark claims, model catalog, quantization story, and the fact that supported weights are preconverted. The important engineering takeaway is positive but incomplete: Cactus gives a plausible single runtime across iOS and Android, but the docs do not publish a deterministic cross-platform embedding parity guarantee, so cosine-parity tests must become a holdout.

2. **Ditto key concepts: about, syncing data, and mesh networking**  
   Sources: https://docs.ditto.live/home/about-ditto, https://docs.ditto.live/key-concepts/syncing-data, and https://docs.ditto.live/key-concepts/mesh-networking. These are the best sources for defending the architecture: Ditto is explicitly a local embedded database with P2P mesh sync, CRDT conflict resolution, query-based subscriptions, delta sync, BLE, LAN, and peer-to-peer Wi-Fi transports. The key implication is that our grow-only recipe tuple set maps cleanly onto Ditto's strongest path, while the vector index itself should stay a local derived view.

3. **PyTorch reproducibility and numerical accuracy notes**  
   Sources: https://docs.pytorch.org/docs/2.12/notes/randomness.html and https://docs.pytorch.org/docs/2.12/notes/numerical_accuracy.html. These are not mobile docs, but they are the clearest official statement of the general numerical risk: bitwise identical floating-point outputs are not guaranteed across platforms or CPU/GPU backends, even when randomness is controlled. They are the strongest evidence for framing our determinism target as empirical cosine parity, not a guarantee inherited from any ML runtime.

4. **Google LiteRT delegate accuracy docs**  
   Source: https://ai.google.dev/edge/litert/performance/delegates. LiteRT's delegate documentation is unusually direct about CPU-vs-accelerator precision differences and provides an "Inference Diff" approach for measuring output deviation. This gives us a model for our own holdout: run a reference CPU path and compare embedding vectors on each target device before trusting synced vectors.

5. **ONNX Runtime Mobile and NNAPI Execution Provider docs**  
   Sources: https://onnxruntime.ai/docs/tutorials/mobile/ and https://onnxruntime.ai/docs/execution-providers/NNAPI-ExecutionProvider.html. ONNX Runtime's mobile guidance says to start with CPU/XNNPACK for the most consistent behavior, then try NNAPI/CoreML when performance requires it; the NNAPI page explicitly calls out FP16 relaxation as faster but potentially less accurate. This is useful comparison evidence for why Cactus must be validated per backend and why accelerator use should be opt-in for embeddings until parity is proven.

6. **Qwen3 Embedding technical report and model card**  
   Sources: https://arxiv.org/abs/2506.05176 and https://huggingface.co/Qwen/Qwen3-Embedding-0.6B. Qwen3-Embedding-0.6B is Apache-2.0, Cactus lists it as an embedding-capable model, and the paper positions the 0.6B variant as the efficient member of the family. It is the strongest quality-oriented embedding candidate already near the Cactus model catalog, but it may be heavy for cold-load and should be benchmarked against a smaller 384-dim model.

7. **Qwen3 technical report**  
   Source: https://arxiv.org/abs/2505.09388. Qwen3 is the best licensing and ecosystem fit among the small generalist LLM candidates because the report states the models are publicly available under Apache-2.0, and Cactus lists Qwen3-0.6B and Qwen3-1.7B. It does not answer whether a 1.7B model can reliably merge audience-submitted recipe variants, so it should be treated as the Stage-0 candidate pending corpus-specific eval.

8. **llama.cpp repo and GGUF docs**  
   Sources: https://github.com/ggml-org/llama.cpp and https://github.com/ggml-org/ggml/blob/master/docs/gguf.md. llama.cpp is the comparison baseline for GGUF, quantization formats, broad hardware support, and mobile wrappers. It helps defend Cactus by showing the underlying ecosystem is mature, but it also reinforces that support breadth is not the same as a cross-device numerical parity guarantee.

9. **OrbitDB and local-first CRDT systems**  
   Sources: https://github.com/orbitdb/orbitdb, https://automerge.org/, https://github.com/yjs/yjs, and https://www.loro.dev/. These are the strongest adjacent sources for "mergeable knowledge stores": they show mature CRDT/local-first data replication patterns, including append-only logs and offline convergence. None of them is a vector index CRDT; the useful pattern is to sync facts/tuples and derive indexes locally.

10. **Qdrant benchmark page plus latency-floor sources**  
    Sources: https://qdrant.tech/benchmarks/, https://www.fcc.gov/reports-research/reports/measuring-broadband-america/measuring-broadband-america-mobile-data, and https://www.stuartcheshire.org/rants/Latency.html. Qdrant's benchmark page gives concrete single-digit to tail-latency numbers for vector search engines under controlled conditions, while the FCC and latency essay anchor the network round-trip argument. The writeup should contrast local retrieval latency against unavoidable mobile RTT and geography, not against cloud service compute alone.

## Per-topic findings

### 1. On-device embedding determinism and cross-platform reproducibility

**Sources**

- Cactus Team, 2025-2026: https://github.com/cactus-compute/cactus
- Cactus Team, docs v1.7: https://cactuscompute.com/docs/v1.7/rag
- PyTorch, last updated 2025-10-03 and 2026-01-29: https://docs.pytorch.org/docs/2.12/notes/randomness.html and https://docs.pytorch.org/docs/2.12/notes/numerical_accuracy.html
- Google AI Edge / LiteRT, last updated 2025-12-05: https://ai.google.dev/edge/litert/performance/delegates
- ONNX Runtime, current mobile and NNAPI docs: https://onnxruntime.ai/docs/tutorials/mobile/ and https://onnxruntime.ai/docs/execution-providers/NNAPI-ExecutionProvider.html
- Apple Core ML, current docs: https://developer.apple.com/documentation/coreml/mlcomputeunits
- Qualcomm AI Hub and MediaTek NeuroPilot, current docs: https://app.aihub.qualcomm.com/docs/hub/quantize_examples.html and https://neuropilot.mediatek.com/
- ggml / GGUF docs: https://github.com/ggml-org/ggml/blob/master/docs/gguf.md

**What it gives us**  
Cactus is the best place to concentrate parity work because it exposes embeddings, vector index APIs, and the same preconverted model catalog across mobile SDKs. The adjacent runtime docs are clear that accelerator delegates and mixed precision routinely change numeric results; the safest embedding path is a pinned model, pinned quantization, pinned tokenizer/prompt, and an empirical parity harness that compares iOS and Android vectors against a CPU reference.

**Gap**  
No primary source found a Cactus guarantee of bit-identical or cosine-bounded embedding outputs across iOS and Android. No source showed a general proof that GGUF int4/int8 or NPU-accelerated transformer inference preserves embedding parity across Apple Neural Engine, Qualcomm Hexagon, MediaTek APU, CPU, GPU, and NNAPI/CoreML delegates.

**Operational notes**

- Treat cosine >= 0.999 as an empirical holdout, not a property implied by Cactus, GGUF, or quantization.
- Run embedding determinism in two modes: single-thread CPU-only/reference mode first, then the intended accelerated Cactus configuration.
- Persist `model_id`, weight checksum, tokenizer checksum, quantization mode, Cactus version, and backend flags in tuple metadata so mismatches are observable.
- Avoid storing generated vectors from heterogeneous model versions in the same CRDT set unless the query path filters by embedding schema.

### 2. CRDT vector indexes and mergeable knowledge stores

**Sources**

- OrbitDB maintainers, current repo: https://github.com/orbitdb/orbitdb
- Automerge, Yjs, and Loro maintainers, current docs/repos: https://automerge.org/, https://github.com/yjs/yjs, and https://www.loro.dev/
- Zhang et al., 2026; Liu, Fang, Qian, 2025; Widmoser, Kocher, Augsten, 2025: https://arxiv.org/abs/2602.17099, https://arxiv.org/abs/2505.11783, and https://arxiv.org/abs/2507.17647
- Lin and Ma, 2023: https://arxiv.org/abs/2308.14963
- vstash authors, 2026: https://arxiv.org/abs/2604.15484

**What it gives us**  
The strongest prior art says "CRDT the records, not the ANN graph." OrbitDB, Automerge, Yjs, and Loro establish convergent local-first data structures; HNSW merge papers show that merging ANN graph indexes is an active research problem even in coordinated database settings; local-first RAG work validates the value of hybrid local retrieval but does not solve mobile mesh sync.

**Gap**  
I found no direct primary prior art for an embedding tuple store whose replicated state is explicitly a CRDT and whose mobile peers query the converged union offline. I also found no credible mobile prior art for concurrent HNSW insertion across independent replicas followed by conflict-free graph convergence.

**Implication for the demo**

- Use Ditto as the source of truth for `RecipeTuple` documents.
- Treat the vector index as a disposable local materialized view rebuilt from the converged tuple set.
- At <= 5,000 tuples, brute-force cosine or a simple in-memory index is easier to reason about than HNSW merge semantics and will likely stay below the latency budget.

### 3. Peer-to-peer / mesh sync infrastructure on mobile

**Sources**

- Ditto, current docs: https://docs.ditto.live/home/about-ditto
- Ditto, current sync and mesh docs: https://docs.ditto.live/key-concepts/syncing-data and https://docs.ditto.live/key-concepts/mesh-networking
- Ditto demo apps page and repos, 2026: https://www.ditto.com/demo-apps, https://github.com/getditto/demoapp-inventory, https://github.com/getditto/demoapp-pos-kds, and https://github.com/getditto/demoapp-chat
- Apple and Google mobile proximity APIs, current docs: https://developer.apple.com/documentation/multipeerconnectivity and https://developers.google.com/nearby/connections/overview
- libp2p, Iroh, and Earthstar repos, current snapshots: https://github.com/libp2p/go-libp2p, https://github.com/n0-computer/iroh, and https://github.com/earthstar-project/earthstar

**What it gives us**  
Ditto is unusually well matched to the demo because it combines embedded local storage, query-based sync, CRDT conflict handling, and cross-platform mobile transports in one SDK. The public demo apps prove iOS and Android cross-device sync is a first-class Ditto story; alternatives usually provide either transport discovery or a CRDT library, not the full mobile database plus mesh sync layer.

**Gap**  
No public Ditto RAG-shaped demo was found. I also did not find a public, reproducible report measuring iOS-to-Android Ditto BLE throughput for JSON documents containing float arrays of embedding size under airplane-mode demo conditions.

**Implication for the demo**

- Configure the demo as a local small-peer mesh and avoid cloud/WebSocket paths during the filmed run.
- Subscribe broadly to the recipe collection, e.g. `SELECT * FROM recipes`, because the demo corpus is small and the desired merge is the union of observed inserts.
- Make the sync state visible: peer count, tuple count, last synced contributor, and "embedding schema" should be in the debug UI even if not in the presentation UI.

### 4. On-device LLM inference frameworks and small-LLM ecosystem

**Sources**

- Cactus repo and catalog: https://github.com/cactus-compute/cactus
- llama.cpp repo: https://github.com/ggml-org/llama.cpp
- MLC LLM repo and mobile docs: https://github.com/mlc-ai/mlc-llm, https://llm.mlc.ai/docs/deploy/ios.html, and https://llm.mlc.ai/docs/deploy/android.html
- ExecuTorch, MediaPipe LLM Inference, and ONNX Runtime GenAI, current docs/repos: https://github.com/pytorch/executorch, https://ai.google.dev/edge/mediapipe/solutions/genai/llm_inference, and https://github.com/microsoft/onnxruntime-genai
- Qwen Team, 2025: https://arxiv.org/abs/2505.09388
- Hu et al., 2021 and Dettmers et al., 2023: https://arxiv.org/abs/2106.09685 and https://arxiv.org/abs/2305.14314
- Zhang et al., 2024: https://arxiv.org/abs/2401.02385
- Meta Llama 3.2 license and Google Gemma terms: https://www.llama.com/llama3_2/license/ and https://ai.google.dev/gemma/terms

**What it gives us**  
The viable Stage-0 path is Cactus plus a small Apache-licensed generalist that is already in the Cactus catalog, with Qwen3-1.7B the cleanest licensing candidate and LFM2/LFM2.5 worth testing because Cactus benchmarks it heavily. Adjacent frameworks validate that mobile LLM inference is now mainstream, but they do not give a reason to swap away from Cactus for this project.

**Gap**  
I found no strong benchmark specifically for <= 3B models doing structured-list reconciliation of recipes: ingredient deduplication, quantity normalization, and step synthesis from multiple audience variants. The literature supports small specialist/fine-tuned models via LoRA/QLoRA and small-model training, but it does not tell us the minimum generalist parameter count where recipe merging stops being embarrassing.

**Model-quality implication**

- Run a tiny recipe merge eval before committing the corpus: 20 pairs of variant recipes, hand-labeled expected merged ingredients, duplicate handling, and unacceptable hallucination checks.
- If Qwen3-1.7B fails, cars are still a lower-risk fallback because item aggregation is less semantically demanding than ingredient/quantity reconciliation.
- Future-work angle should be specialist models: a tiny sous-chef model fine-tuned for ingredient normalization is more aligned with the thesis than "bigger generalist on device."

**Licensing notes**

- Prefer Apache-2.0 Qwen-family candidates for a public hackathon repo.
- Treat Llama community license and Gemma terms as landmines for redistribution and demos unless the repo avoids bundling weights and documents user-side download/acceptance.
- Verify LiquidAI LFM model license before redistributing any weights; Cactus support alone is not a redistribution grant.

### 5. On-device embedding models and vector search

**Sources**

- Qwen3 Embedding paper: https://arxiv.org/abs/2506.05176
- Qwen3-Embedding-0.6B model card: https://huggingface.co/Qwen/Qwen3-Embedding-0.6B
- Sentence-BERT and all-MiniLM sources: https://arxiv.org/abs/1908.10084 and https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2
- BGE-small and FlagEmbedding sources: https://huggingface.co/BAAI/bge-small-en-v1.5 and https://github.com/FlagOpen/FlagEmbedding
- Nomic Embed sources: https://arxiv.org/abs/2402.01613 and https://huggingface.co/nomic-ai/nomic-embed-text-v1.5
- Cactus RAG docs: https://cactuscompute.com/docs/v1.7/rag
- On-device vector libraries: https://github.com/unum-cloud/usearch, https://github.com/asg017/sqlite-vec, https://github.com/facebookresearch/faiss, and https://github.com/spotify/annoy
- Lucene vector search and vstash hybrid retrieval papers: https://arxiv.org/abs/2308.14963 and https://arxiv.org/abs/2604.15484

**What it gives us**  
For the demo scale, model choice and determinism matter more than ANN sophistication. Qwen3-Embedding-0.6B is quality-forward and Cactus-listed; BGE-small and all-MiniLM are smaller baselines; raw cosine over 50-5,000 normalized vectors is likely enough, with hybrid BM25 plus dense retrieval worth adding if tiny-corpus dense retrieval misses lexical cues like "tortilla" or "thighs."

**Gap**  
I found no mobile benchmark that measures these embedding models inside Cactus on the same mid-range iPhone and Android target. I also found no evidence that any off-the-shelf vector library improves demo outcome at the planned corpus size versus a simple deterministic cosine scan.

**Retrieval implication**

- Store normalized embeddings, but keep original recipe fields searchable for lexical fallback.
- Implement deterministic top-k tie-breaking by tuple id or created_at so synced peers explain ranking changes consistently.
- Prefer CactusIndex or raw cosine first; use USearch/sqlite-vec only after measuring a real bottleneck.

### 6. Local-first AI and offline-first AI prior art

**Sources**

- Ink & Switch local-first essay: https://www.inkandswitch.com/local-first/
- Automerge, Yjs, and Loro local-first/CRDT projects: https://automerge.org/, https://github.com/yjs/yjs, and https://www.loro.dev/
- Anytype repo: https://github.com/anyproto/anytype-ts
- Obsidian Smart Connections and Khoj repos: https://github.com/brianpetro/obsidian-smart-connections and https://github.com/khoj-ai/khoj
- Google AI Edge / MediaPipe LLM Inference: https://ai.google.dev/edge/mediapipe/solutions/genai/llm_inference
- Apple Foundation Models docs: https://developer.apple.com/documentation/foundationmodels

**What it gives us**  
The local-first sources give the writeup language for ownership, offline operation, and convergence; the local-AI projects show a broad pattern of personal knowledge bases and local retrieval/generation. The novelty remains the composition: synced retrieved facts over a P2P mesh, with on-device embedding and generation on both sides.

**Gap**  
Most local-first AI products either keep AI state local to one device, rely on cloud sync, or sync notes/files rather than embedding tuples. I did not find strong prior art for audience-submitted knowledge variants merging across nearby phones with no server.

**Writeup framing**

- Claim durable wins on latency and offline operation, not cost.
- Contrast with chat-history sync and weight sync only briefly; keep retrieval as the natural P2P primitive because facts are small, append-only, and useful immediately after sync.
- Future work should emphasize specialist small models per domain, not a race to run frontier generalists locally.

### 7. Latency floors and "the network round-trip is the moat"

**Sources**

- Cactus repo benchmarks: https://github.com/cactus-compute/cactus
- Qdrant benchmark page: https://qdrant.tech/benchmarks/
- Pinecone product page: https://www.pinecone.io/product/
- FCC mobile broadband measurement program: https://www.fcc.gov/reports-research/reports/measuring-broadband-america/measuring-broadband-america-mobile-data
- Stuart Cheshire, latency essay: https://www.stuartcheshire.org/rants/Latency.html
- Cloudflare speed-of-light discussion: https://blog.cloudflare.com/the-speed-of-light-on-the-internet/
- ONNX Runtime mobile docs: https://onnxruntime.ai/docs/tutorials/mobile/

**What it gives us**  
The argument should distinguish three latencies: local vector scan, local LLM prefill/decode, and remote network round trip. Cloud vector search can be fast inside its own region, but mobile users pay radio, routing, TLS/API, queueing, and geographic delay before cloud retrieval or generation begins; a local mesh query has no WAN lower bound after the corpus has synced.

**Gap**  
I did not find a primary end-to-end benchmark comparing mobile on-device RAG against cloud RAG with identical prompts, corpora, phones, and network conditions. Vendor vector DB latency numbers are useful but are not the same as full mobile RAG latency.

**Writeup implication**

- Do not overclaim that every local LLM answer beats every cloud answer; local generation can be slower than frontier APIs for long outputs.
- The robust claim is that retrieval over already-local synced tuples avoids WAN round trips entirely, and the post-sync answer can change while fully offline.
- Film the demo with visible airplane-mode/network state and a small timestamped latency readout for embed, top-k, generation, and sync-observed events.

### 8. Hackathon demo aesthetics and presentation tooling

**Sources**

- Presenterm repo: https://github.com/mfontanini/presenterm
- Sli.dev repo: https://github.com/slidevjs/slidev
- reveal.js repo: https://github.com/hakimel/reveal.js
- Ditto demo apps: https://www.ditto.com/demo-apps
- Ditto inventory demo repo: https://github.com/getditto/demoapp-inventory
- Ditto POS/KDS demo repo: https://github.com/getditto/demoapp-pos-kds
- Bridgefy SDK page: https://bridgefy.me/sdk/
- Apple AirDrop support page: https://support.apple.com/en-us/102647

**What it gives us**  
The demo should make state composition legible before explaining RAG: show phone A's answer, bring phone B into range, show tuple count/peer state change, then ask the same query and show the merged recipe. Presenterm is adequate for a technical terminal-native deck, while Sli.dev/reveal.js are better if the deck needs animation, screenshots, or browser-native assets.

**Gap**  
I found no canonical hackathon deck for "devices meet, knowledge composes, no server" that maps directly onto this demo. Public P2P demos usually emphasize chat, payments, or file transfer rather than on-device retrieval and synthesis.

**Presentation implication**

- Keep the deck secondary to the live two-device moment.
- Use one slide for the CRDT tuple shape, one for the before/after query, and one for latency/offline thesis.
- Avoid abstract diagrams until after the audience has seen the result change.

## Tool shortlist

### On-device embedding model

| Candidate | Repo / model URL | Last release date | License | Maintenance health | Mobile support matrix | Verdict |
|---|---|---:|---|---|---|---|
| Qwen3-Embedding-0.6B | https://huggingface.co/Qwen/Qwen3-Embedding-0.6B; https://github.com/QwenLM/Qwen3-Embedding | 2025-06-05 paper/model family; HF collection observed updated 2025-12-31 | Apache-2.0 | Upstream Qwen family active; exact commits/open-issue trend not observable after browser cap; HF card showed high recent download volume | Cactus catalog lists `Qwen/Qwen3-Embedding-0.6B` as embed-capable; iOS/Android via Cactus if packaged weights work; desktop via Transformers/TEI | **Maybe/use if it cold-loads**: best quality/license fit, but 0.6B may be too heavy for sub-10s cold load on the slowest Android. |
| BAAI bge-small-en-v1.5 | https://huggingface.co/BAAI/bge-small-en-v1.5; https://github.com/FlagOpen/FlagEmbedding | 2023 model family; exact latest model update not captured | MIT according to model/repo family, verify in final due diligence | FlagEmbedding appears active; exact 90-day commit and issue trend not observable | ONNX/LiteRT/ORT conversion path for iOS/Android; Cactus prepackaging not observed | **Maybe fallback**: smaller 384-dim baseline that should be fast; less aligned with Cactus catalog unless conversion is smooth. |
| all-MiniLM-L6-v2 | https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2; https://github.com/UKPLab/sentence-transformers | 2021-era model card; exact latest update not captured | Apache-2.0 | SentenceTransformers is mature/active; exact 90-day issue trend not captured | Very easy ONNX/TFLite/ORT path; likely fastest option; not Cactus-listed in observed catalog | **Use only as baseline**: excellent for determinism/perf smoke tests, but retrieval quality is likely behind modern BGE/Qwen candidates. |

### On-device LLM

| Candidate | Repo / model URL | Last release date | License | Maintenance health | Mobile support matrix | Verdict |
|---|---|---:|---|---|---|---|
| Cactus + Qwen3-1.7B | https://github.com/cactus-compute/cactus; https://huggingface.co/Qwen/Qwen3-1.7B; https://arxiv.org/abs/2505.09388 | Qwen3 report 2025; Cactus docs v1.7 observed 2026 | Qwen3 Apache-2.0; verify Cactus repo license before redistribution | Cactus repo observed updated 2026-04-18 with active issues/PRs; exact issue trend not observable | Cactus supports Swift, Kotlin, Flutter, React Native, C/C++; iOS and Android are first-class | **Use first**: clean model license and catalog fit; recipe merge quality still needs an eval. |
| Cactus + LiquidAI LFM2/LFM2.5 small model | https://github.com/cactus-compute/cactus; https://huggingface.co/LiquidAI | Cactus benchmark/model catalog observed 2026; exact model release not captured | Not verified in this pass | Cactus benchmarks emphasize LFM; exact upstream issue trend not captured | Cactus benchmark table covers iPhone, Pixel, Galaxy-class devices | **Maybe**: strongest Cactus performance story, but license and recipe-merge quality need verification. |
| Cactus + Gemma 3 1B | https://github.com/cactus-compute/cactus; https://ai.google.dev/gemma/terms | Gemma 3 era, exact model update not captured | Gemma terms, gated for some weights | Google-maintained; exact issue trend not applicable | Cactus catalog lists Gemma variants; also supported by MediaPipe/AI Edge paths | **Don't bundle by default**: useful comparison, but public-demo redistribution and gated access are avoidable friction. |

### On-device vector search library

| Candidate | Repo / model URL | Last release date | License | Maintenance health | Mobile support matrix | Verdict |
|---|---|---:|---|---|---|---|
| CactusIndex / raw cosine materialized view | https://github.com/cactus-compute/cactus; https://cactuscompute.com/docs/v1.7/rag | Cactus docs v1.7 observed 2026 | Cactus repo license must be verified; docs are public | Repo observed active in 2026; exact commits in last 90 days not observable | Cactus docs show React Native, Flutter, Kotlin examples; iOS/Android via SDKs | **Use**: at <=5,000 tuples, deterministic brute-force cosine is simpler than ANN and matches the stack. |
| sqlite-vec | https://github.com/asg017/sqlite-vec | Exact latest release not captured | License not captured; verify before use | Active-looking repo snapshot, exact commit/issue trend not observable | SQLite extension can target iOS/Android with native build work; good if we already use SQLite | **Maybe later**: strong embedded option, but extra native packaging is not needed for Stage 0. |
| USearch | https://github.com/unum-cloud/usearch | Exact latest release not captured | Apache-2.0 expected for project, verify | Repo snapshot shows broad bindings; exact 90-day issue trend not observable | C++, C, Python, JavaScript, Rust, Java, Objective-C, Swift, C#, Go bindings; mobile plausible via C++/Swift | **Maybe if scale grows**: excellent compact ANN library, but HNSW-style indexes add complexity before we need it. |

### Mesh-sync config (Ditto)

| Candidate | Repo / model URL | Last release date | License | Maintenance health | Mobile support matrix | Verdict |
|---|---|---:|---|---|---|---|
| Ditto small-peer local mesh, recipe collection subscription | https://docs.ditto.live/home/about-ditto; https://docs.ditto.live/key-concepts/mesh-networking | Latest docs observed 2026 | Ditto SDK is commercial/proprietary; demo repos MIT | Ditto docs/current demos active; exact SDK release cadence requires account/package check | iOS and Android small peers; mobile transports include BLE, LAN, P2P Wi-Fi, WebSockets; use local transports only for demo | **Use**: this is the chosen stack and the best fit for airplane-mode P2P sync. |
| Ditto inventory/POS demo app patterns | https://github.com/getditto/demoapp-inventory; https://github.com/getditto/demoapp-pos-kds | No releases published for inventory in observed page; repos active enough for demos | MIT for demo repos | Inventory page showed 116 commits and no releases; POS showed 216 commits; issue trend not observable | Separate iOS and Android folders, cross-platform sync | **Use as reference, not dependency**: copy env/config and presence/debug patterns. |

### Slide-deck framework

| Candidate | Repo / model URL | Last release date | License | Maintenance health | Mobile support matrix | Verdict |
|---|---|---:|---|---|---|---|
| Presenterm | https://github.com/mfontanini/presenterm | Exact latest release not captured | License not captured in final browser snapshot; verify before publishing deck tooling docs | Repo snapshot opened; exact 90-day commits/issue trend not observable | Runs in terminal on presenter machine; not mobile-facing | **Use**: matches the brief and keeps the deck lightweight for a live coding/demo flow. |
| Sli.dev | https://github.com/slidevjs/slidev | Exact latest release not captured | MIT | Active project; exact 90-day trend not observable | Browser deck; works well with screenshots/video; not mobile app runtime | **Maybe**: use if the final deck needs polished visuals or animations beyond Presenterm. |
| reveal.js | https://github.com/hakimel/reveal.js | Exact latest release not captured | MIT | Mature/active; exact trend not observable | Browser deck; broadly portable | **Maybe**: stable fallback, less aligned with the Presenterm requirement. |

## Reference architectures

1. **Cactus React Native example app**  
   Files/dirs: https://github.com/cactus-compute/cactus-react-native/tree/main/example and Cactus RAG docs at https://cactuscompute.com/docs/v1.7/rag. Copy the lifecycle shape: initialize model once, expose embedding/completion calls through a narrow app service, and keep the vector index API explicit rather than hiding retrieval inside prompt construction. Also copy the idea of a small debug surface for timing and model status.

2. **Ditto inventory demo**  
   Files/dirs: https://github.com/getditto/demoapp-inventory/tree/main/iOS and https://github.com/getditto/demoapp-inventory/tree/main/Android. Copy the cross-platform repo layout and the presence/debug patterns: a simple domain object, a visible count/state change, and a two-device sync story that does not need elaborate UI. This is closest to our "tuple count changes, answer changes" demo.

3. **Ditto POS/KDS demo**  
   Files/dirs: https://github.com/getditto/demoapp-pos-kds/tree/main/iOS and https://github.com/getditto/demoapp-pos-kds/tree/main/Android. Copy the workflow split: one device produces operational state, another device observes and reacts in real time. Our recipe contributor/query device split can mimic that shape without teaching the audience the internals first.

4. **Google AI Edge Gallery / MediaPipe LLM pattern**  
   Files/dirs: https://github.com/google-ai-edge/gallery and docs at https://ai.google.dev/edge/mediapipe/solutions/genai/llm_inference. Copy the model-loading discipline: explicit model state, capability checks, and user-visible progress while large local models initialize. Do not copy the framework choice; this is a lifecycle reference only.

5. **Presenterm examples and themes**  
   Files/dirs: https://github.com/mfontanini/presenterm/tree/master/examples. Copy the low-friction deck structure: short slides, terminal-friendly diagrams, and code/command snippets that can be edited in repo. Keep the live phones as the main visual asset.

## Open research questions

- Does Cactus produce cosine >= 0.999 embeddings across iOS and Android for the same text, same model, same weights, same quantization, and same tokenizer? This is the top technical gap.
- Which Cactus backend is actually used for embeddings on each target phone, and can we force a deterministic CPU path for embeddings while still using accelerated generation?
- What is the cold-load time for Qwen3-Embedding-0.6B plus Qwen3-1.7B on the slowest Android target? The model catalog is promising, but the demo budget is concrete.
- Are Ditto JSON arrays of float32 values efficient enough over BLE, or should embeddings be stored as binary attachments or quantized arrays with a schema version?
- Does airplane mode on the exact iOS/Android devices preserve the intended BLE/LAN/P2P Wi-Fi behavior after the user toggles Bluetooth/Wi-Fi back on? This needs a filmed-demo rehearsal, not just docs.
- What is the minimum small generalist model size that can merge recipe variants acceptably? I found no strong list-reconciliation benchmark for <=3B LLMs, so we need a small bespoke eval.
- Can a future "tiny sous-chef" specialist model outperform a 1.7B-3B generalist for ingredient normalization and recipe merge while staying small enough for Cactus? LoRA/QLoRA supports the direction, but not this exact result.
- What exact licenses apply to Cactus runtime distribution, LiquidAI LFM weights, Presenterm, and any packaged model artifacts? Some repo license fields were not visible before the browser call cap.

## Source ledger

https://ai.google.dev/edge/litert/performance/delegates
https://ai.google.dev/edge/mediapipe/solutions/genai/llm_inference
https://ai.google.dev/gemma/terms
https://app.aihub.qualcomm.com/docs/hub/quantize_examples.html
https://arxiv.org/abs/1908.10084
https://arxiv.org/abs/2106.09685
https://arxiv.org/abs/2305.14314
https://arxiv.org/abs/2308.14963
https://arxiv.org/abs/2401.02385
https://arxiv.org/abs/2402.01613
https://arxiv.org/abs/2505.09388
https://arxiv.org/abs/2505.11783
https://arxiv.org/abs/2506.05176
https://arxiv.org/abs/2507.17647
https://arxiv.org/abs/2602.17099
https://arxiv.org/abs/2604.15484
https://automerge.org/
https://blog.cloudflare.com/the-speed-of-light-on-the-internet/
https://bridgefy.me/sdk/
https://cactuscompute.com/docs/v1.7
https://cactuscompute.com/docs/v1.7/rag
https://developer.apple.com/documentation/coreml/mlcomputeunits
https://developer.apple.com/documentation/foundationmodels
https://developer.apple.com/documentation/multipeerconnectivity
https://developers.google.com/nearby/connections/overview
https://docs.ditto.live/home/about-ditto
https://docs.ditto.live/key-concepts/mesh-networking
https://docs.ditto.live/key-concepts/syncing-data
https://docs.pytorch.org/docs/2.12/notes/numerical_accuracy.html
https://docs.pytorch.org/docs/2.12/notes/randomness.html
https://github.com/FlagOpen/FlagEmbedding
https://github.com/QwenLM/Qwen3-Embedding
https://github.com/UKPLab/sentence-transformers
https://github.com/anyproto/anytype-ts
https://github.com/asg017/sqlite-vec
https://github.com/brianpetro/obsidian-smart-connections
https://github.com/cactus-compute/cactus
https://github.com/cactus-compute/cactus-react-native/tree/main/example
https://github.com/earthstar-project/earthstar
https://github.com/facebookresearch/faiss
https://github.com/getditto/demoapp-chat
https://github.com/getditto/demoapp-inventory
https://github.com/getditto/demoapp-inventory/tree/main/Android
https://github.com/getditto/demoapp-inventory/tree/main/iOS
https://github.com/getditto/demoapp-pos-kds
https://github.com/getditto/demoapp-pos-kds/tree/main/Android
https://github.com/getditto/demoapp-pos-kds/tree/main/iOS
https://github.com/ggml-org/ggml/blob/master/docs/gguf.md
https://github.com/ggml-org/llama.cpp
https://github.com/google-ai-edge/gallery
https://github.com/hakimel/reveal.js
https://github.com/khoj-ai/khoj
https://github.com/libp2p/go-libp2p
https://github.com/mfontanini/presenterm
https://github.com/mfontanini/presenterm/tree/master/examples
https://github.com/microsoft/onnxruntime-genai
https://github.com/mlc-ai/mlc-llm
https://github.com/n0-computer/iroh
https://github.com/orbitdb/orbitdb
https://github.com/pytorch/executorch
https://github.com/slidevjs/slidev
https://github.com/spotify/annoy
https://github.com/unum-cloud/usearch
https://github.com/yjs/yjs
https://huggingface.co/BAAI/bge-small-en-v1.5
https://huggingface.co/LiquidAI
https://huggingface.co/Qwen/Qwen3-1.7B
https://huggingface.co/Qwen/Qwen3-Embedding-0.6B
https://huggingface.co/nomic-ai/nomic-embed-text-v1.5
https://huggingface.co/sentence-transformers/all-MiniLM-L6-v2
https://llm.mlc.ai/docs/deploy/android.html
https://llm.mlc.ai/docs/deploy/ios.html
https://neuropilot.mediatek.com/
https://onnxruntime.ai/docs/execution-providers/NNAPI-ExecutionProvider.html
https://onnxruntime.ai/docs/tutorials/mobile/
https://qdrant.tech/benchmarks/
https://support.apple.com/en-us/102647
https://www.ditto.com/demo-apps
https://www.fcc.gov/reports-research/reports/measuring-broadband-america/measuring-broadband-america-mobile-data
https://www.inkandswitch.com/local-first/
https://www.llama.com/llama3_2/license/
https://www.loro.dev/
https://www.pinecone.io/product/
https://www.stuartcheshire.org/rants/Latency.html
