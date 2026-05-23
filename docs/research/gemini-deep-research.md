# **Architectural Foundations for Peer-to-Peer Retrieval-Augmented Generation at the Edge**

## **1\. Top 10 Must-Read Sources**

### **1\. Gudur, V. (2025). Valori: A Deterministic Memory Substrate for AI Systems (arXiv:2512.22280)**

This research addresses the fundamental challenge of floating-point non-determinism in vector space retrieval across heterogeneous hardware architectures, such as x86 and ARM.1 The paper demonstrates that standard IEEE 754 floating-point computations produce varying bit-level representations due to compiler optimizations, transcendental function routing, and hardware-specific fused multiply-accumulate (FMA) instructions.1 To solve this, Gudur presents Valori, a deterministic memory substrate that replaces floating-point calculations with Q16.16 fixed-point arithmetic, proving that bit-identical memory states and vector search results are achievable on heterogeneous edge devices.1 This work is essential for peer-to-peer RAG systems where identical vector spaces across iOS and Android are a strict prerequisite for index consistency.1

### **2\. Pape, D., Evertz, J., & Schönherr, L. (2026). The Silent Hyperparameter: Quantifying the Impact of Inference Backends on LLM Reproducibility (arXiv:2605.19537)**

This empirical study analyzes the influence of local inference backends, such as vLLM, SGLang, and llama.cpp, on the reproducibility of transformer outputs.4 The authors show that specialized engine optimizations (including prefix caching, CUDA graphs, and custom logit processing) introduce subtle numerical drift that alters token-level probability distributions, leading to benchmark variance of up to 16.6 percentage points under identical model weights and greedy decoding (![][image1]).5 This paper establishes the inference engine as a primary variable in local AI pipelines and illustrates the risks of unstandardized execution environments on edge devices.4

### **3\. Ditto SDK Core Sync & Conflict Resolution Manual (docs.ditto.live)**

The official Ditto Edge SDK technical documentation details the implementation of delta-state Conflict-Free Replicated Data Types (CRDTs), logical clocks, and version vectors on edge nodes.7 By comparing version vectors rather than replicating entire documents, Ditto calculates minimal property-level delta diffs on-demand, which optimizes synchronization over low-bandwidth communication channels.7 This manual is a critical resource for modeling grow-only sets of recipe tuples and managing data convergence across mobile meshes.7

### **4\. upb-cn. (2025). MoRAGBench: A Modular Benchmarking Framework for Mobile RAG ([github.com/upb-cn/MoRAGBench](https://github.com/upb-cn/MoRAGBench))**

MoRAGBench is an open-source benchmarking framework designed to evaluate on-device Retrieval-Augmented Generation pipelines under realistic mobile constraints.9 The repository includes system-level profiling tools to measure Time-to-First-Token (TTFT), generation throughput, and retrieval latency for Flat, IVF, and HNSW indexes across Android's CPU, XNNPACK, and NNAPI execution backends.9 This project provides the performance profiles and testing scripts needed to design a local, sub-second vector query path.9

### **5\. Tiger AI Lab. (2025). StructEval: A Comprehensive Benchmark for Structured Formats (tiger-ai-lab.github.io/StructEval)**

This evaluation framework measures the capability of Large Language Models to adhere to structured formats (such as JSON, YAML, and CSV) during generation and conversion tasks.10 The findings highlight a critical performance gap in models under 3B parameters, which frequently experience structural syntax errors and format adherence failures.10 It provides a standardized framework for assessing whether ultra-small models can reliably synthesize and normalize merged list structures on-device.10

### **6\. asg017. (2026). sqlite-vec: An Extremely Small, "Fast Enough" Vector Search Extension ([github.com/asg017/sqlite-vec](https://github.com/asg017/sqlite-vec))**

This pure C, zero-dependency SQLite extension enables vector storage and approximate/exact nearest neighbor search directly inside an embedded SQLite database.11 With pre-compiled binaries available for iOS and Android, it provides a lightweight, cross-platform vector database footprint that can run within mobile applications.12 This project demonstrates that lightweight, exact flat vector search is highly performant for local datasets under 5,000 items, bypassing the complexity of HNSW structures.11

### **7\. Peat Mesh Protocol Workspace (libraries.io/cargo/peat-protocol)**

The Peat Protocol is an open-source decentralized mesh protocol designed to link heterogeneous systems (including mobile phones and edge AI pipelines) using Automerge CRDT sync over the Iroh QUIC/UDP transport and peat-btle BLE mesh connections.14 It provides a peer-to-peer architecture comparison for building secure, cryptographically validated, offline-first group state sync without a centralized broker.14

### **8\. Ditto BLE & Platform Fragmentation Guide ([ditto.com/blog/getting-started-with-bluetooth-file-sync](https://ditto.com/blog/getting-started-with-bluetooth-file-sync))**

This engineering blog analyzes the physical and protocol-level limitations of peer-to-peer file transfer over Bluetooth Low Energy (BLE) and peer-to-peer Wi-Fi on iOS and Android.15 It details platform-specific constraints, such as iOS supporting only the BLE profile, while Android supports Classic Bluetooth and BLE.15 The post also discusses the physical bandwidth limit of BLE (typically 20 kB/s), highlighting the necessity of transport multiplexing and data chunking for peer-to-peer mobile databases.15

### **9\. Cactus Engine C API Docs ([github.com/cactus-compute/cactus/docs/cactus\_engine.md](https://github.com/cactus-compute/cactus/docs/cactus_engine.md))**

This API reference details the core functions of the Cactus engine, including memory-mapped vector indexing, zero-copy graph execution, and on-device text embedding generation via cactus\_embed.17 It explains how to execute cosine similarity calculations locally and provides the exact signatures for managing persistent local indices on-device, offering the foundational interface for mobile RAG execution.17

### **10\. Gaffer on Games. (2008). Floating Point Determinism ([gafferongames.com/post/floating\_point\_determinism](https://gafferongames.com/post/floating_point_determinism))**

This classic paper outlines the compiler and hardware constraints required to achieve strict IEEE-754 compliant floating-point determinism across heterogeneous hardware architectures.2 It serves as the foundational text for identifying how compilers reorder mathematical sequences and how runtime libraries introduce subtle divergences in cross-platform systems, providing the core theory behind deterministic vector execution.2

## **2\. Per-Topic Findings**

### **Topic 1: On-device embedding determinism & cross-platform reproducibility**

Achieving bit-identical embedding outputs across heterogeneous hardware (iOS and Android) is a significant technical risk for peer-to-peer RAG systems. If Device A and Device B produce mathematically divergent vector coordinates for the same input text, the cosine similarity space becomes misaligned, causing the local retrieval paths to fetch different contexts.1  
The standard floating-point representation defined by IEEE 754 is deterministic in its theoretical specification.18 However, practical implementation details across different runtimes, compilers, and hardware accelerators break this determinism.2 Floating-point addition is non-associative:  
![][image2]  
On highly parallelized hardware like GPUs and NPUs, matrix reductions (summing large arrays of numbers during self-attention layers) are executed in parallel chunks.19 The exact execution order depends on runtime thread scheduling, warp execution patterns, and driver-level dispatch decisions, introducing non-determinism.19  
Furthermore, compiler optimization flags (such as \-ffast-math) allow compilers to reorder operations or fuse independent multiplication and addition steps into a single Fused Multiply-Accumulate (FMA) instruction.2 Because FMA performs only a single rounding step instead of two, it yields a more accurate but bit-level different result than separate instructions, leading to divergences between binaries compiled with different toolchains.2 Additionally, transcendental mathematical functions (such as exp in softmax or tanh in GELU) are often routed to hardware-specific instructions or different standard library (libm) implementations, causing variation in the least significant bits across iOS (Metal/NEON) and Android (Vulkan/XNNPACK).18  
These micro-divergences cascade through deep transformer layers.4 A minor numerical drift in an early layer's activation matrix can alter the argmax of logit processing, causing the model to select a different token or shift the embedding projection.5 The Valori paper documents that the same model executing on an x86 server and an ARM edge device produces different raw bits for identical text inputs, which propagates through the retrieval pipeline and alters search results.1  
The Cactus framework addresses on-device constraints via zero-copy memory mapping and optimized ARM SIMD kernels, transitioning from GGUF to its proprietary .cact format.17 However, its official documentation does not guarantee cross-platform bit-level embedding determinism when executing on heterogeneous NPUs (such as the Apple Neural Engine vs. Qualcomm Hexagon).17 To mitigate this risk, the system must either lock execution to the ARM CPU using strict IEEE-754 compliant compiler flags, or implement a software-emulated fixed-point math layer.1

* **Primary Sources**: Varshith Gudur (2025) 25, David Pape et al. (2026) 5, Glenn Fiedler (2008) 2, Cactus Engine Team (2025).17  
* **What it gives us**: Analyzes the structural failure points of cross-platform IEEE 754 float execution on NPUs and GPUs.1 Explains how optimizations like FMA, thread-level warp scheduling, and non-associative matrix reductions yield diverging bits across architectures.1  
* **Explicit Gap Line**: Cactus does not natively offer software-emulated fixed-point execution or CPU strict IEEE-754 mode toggles, forcing the application layer to either accept hardware-induced float drift or run models purely on the CPU with a significant latency penalty.1

### **Topic 2: CRDT vector indexes / mergeable knowledge stores**

Treating a vector index as a Conflict-Free Replicated Data Type (CRDT) requires designing data structures that can merge state changes concurrently without a central coordinator.26 Traditional approximate nearest neighbor (ANN) indexes, such as Hierarchical Navigable Small World (HNSW) graphs, Inverted File (IVF) indexes, or Product Quantization (PQ) tables, are structurally stochastic and sensitive to insertion order.1  
When concurrent, uncoordinated inserts occur across different edge replicas, the local HNSW graphs diverge structurally.1 Merging two independently grown HNSW graphs is structurally complex because the routing paths (entry points, layer links, and neighbor lists) are tightly coupled to the local insertion history.13 Rebuilding the HNSW graph globally on every peer-to-peer sync event is computationally expensive and drains mobile batteries.9  
To resolve this, the system can utilize a **grow-only set (G-Set)** of immutable tuples as the replication primitive.8 Each tuple consists of:  
![][image3]  
Because the set is grow-only (no deletions in this stage) and keyed by a deterministic UUID, the synchronization layer requires only union-merge semantics.8 When two devices sync via Ditto, the local G-Sets converge to the absolute union of all observed inserts.8  
The vector search index itself does not need to be replicated or merged directly.8 Instead, each device maintains a local, ephemeral vector index built on top of its local G-Set.8 When a sync event occurs and new tuples are added to the G-Set, the local vector index is updated incrementally.13 This approach separates the synchronization layer (which remains a simple, mathematically sound G-Set CRDT) from the vector index execution layer (which runs locally on each device).8  
Underlying implementations like the Valori-Kernel employ an alternative approach: an **event-sourced architecture** where every operation is logged to an append-only write-ahead log (WAL).3 By replaying these deterministic events across a fixed-point calculation engine, all peers can reconstruct bit-identical index topologies and HNSW graphs, validated by cryptographic BLAKE3 hashes.3

* **Primary Sources**: Varshith Gudur (2025) 3, L. J. Wagerfield (2020) 26, Ditto Team (2025) 8, Vikzzy (2024).29  
* **What it gives us**: Demonstrates how to design an append-only grow-only set (G-Set) or map for raw document properties while maintaining decoupled, local ephemeral vector indexing over those properties.8 Points to event-sourced architectures (like Valori) where state hashes and WAL replay guarantee structurally identical vector indexes.3  
* **Explicit Gap Line**: Traditional graph-based indexing structures (HNSW) are inherently order-dependent; none of the analyzed systems provide a native, decentralized, multi-writer graph merge algorithm that avoids full rebuilding on concurrent edge inserts.1

### **Topic 3: Peer-to-peer / mesh sync infrastructure on mobile (Ditto \+ alternatives)**

Ditto's Edge SDK implements an ad-hoc, multi-transport mesh networking stack that automatically switches between BLE, peer-to-peer Wi-Fi, and LAN connections based on proximity and signal strength.30 This transport multiplexing (the "Rainbow Connection") allows mobile devices to form resilient local meshes without requiring a centralized router or cellular tower.15  
However, cross-platform peer-to-peer synchronization between iOS and Android involves significant protocol-level differences.15 Apple Wireless Direct Link (AWDL) is proprietary to Apple ecosystems, while Wi-Fi Aware (Neighbor Awareness Networking) is restricted to the Android ecosystem.34 Because these high-bandwidth, hardware-level P2P Wi-Fi protocols do not directly interoperate, iOS and Android devices cannot establish a direct P2P Wi-Fi link without an intermediate bridge.34  
Consequently, when operating in a completely disconnected, cross-platform mobile environment, the only direct common link between an iOS and an Android device is **Bluetooth Low Energy (BLE)**.34 BLE 5.2 has a maximum theoretical physical-layer throughput of 2 Mbps, but practical application-layer throughput is significantly lower.33 On devices running Android 10 or lower, the fallback is BLE GATT, which yields an application-layer transfer speed of approximately 4 kB/s.16 Modern BLE stacks on newer operating systems typically achieve around 20 kB/s.15  
This bandwidth limit represents a key challenge for peer-to-peer RAG systems.15 A single recipe tuple containing a 384-dimensional float32 vector requires:  
![][image4]  
When combined with recipe text, ingredient lists, step descriptions, and metadata, a single recipe document can easily exceed 5 kB to 10 kB. Over a 20 kB/s BLE channel, syncing a small batch of 10 recipes can take several seconds.15 If the embedding model uses a larger dimension (such as Nomic's 768-dimensional space), payload sizes double, increasing sync latency.15  
Furthermore, Ditto's discovery mechanism relies on multicast DNS (mDNS) packets sent over UDP port 5353\.34 While effective for local LAN networks, many enterprise network switches and wireless access points block multicast traffic to prevent network congestion, which can block peer discovery even when devices are connected to the same Wi-Fi network.34  
An alternative open-source approach is the Peat mesh protocol, which integrates Automerge CRDT sync with the Iroh transport layer (QUIC over UDP) and utilizes a dedicated peat-btle BLE mesh for short-range communication.14

* **Primary Sources**: Ditto Team (2025) 30, Ditto Team (2025) 34, Peat Protocol Team (2025) 14, Biozal (2024).33  
* **What it gives us**: Identifies the physical and network-layer limits of BLE, LAN, and P2P Wi-Fi (AWDL vs. Wi-Fi Aware) fragmentation.15 Provides the system blueprints for ad-hoc cell formation, TLS-encrypted transport, and mDNS peer discovery parameters.14  
* **Explicit Gap Line**: It does not establish direct high-bandwidth Wi-Fi bridges between iOS and Android without an active LAN router, leaving the slower 20 kB/s BLE channel as the primary cross-platform offline transport.15

### **Topic 4: On-device LLM inference frameworks (the small-LLM ecosystem)**

Executing Retrieval-Augmented Generation on-device requires an LLM framework that runs efficiently within tight mobile memory budgets and can handle structured data synthesis.24 The Cactus framework supports several models, including Qwen3-1.7B, LiquidAI LFM2.5-1.2B, and Google Gemma-3-1B-it.17  
When choosing a model scale, developers face a significant trade-off between memory footprint and structural output quality.10 Data from the StructEval benchmark reveals a performance gap for models under 3B parameters when generating structured output.10 While larger models like Qwen3-4B achieve structured scoring of 67.04% and Phi-4-mini reaches 56.97%, smaller models struggle with structural adherence, syntax validation, and schema compliance.10 At parameter scales below 2B (such as Qwen3-1.7B or Gemma-3-1B), models frequently fail to output valid JSON or adhere strictly to structured list formats unless guided by strict system prompts or constrained decoding mechanisms.10  
For the recipe-merging task, the model must take multiple recipe variants retrieved from local vector storage (such as Alyssa's Chicken Tortilla Soup and Bob's Chicken Tortilla Soup) and synthesize them into a single, normalized, and coherent recipe.8 This requires the model to parse different ingredient structures, resolve measurement units, scale quantities, deduplicate repeating items, and merge instructions into a logical chronological flow.38 At scales below 2B parameters, general-purpose LLMs struggle with these tasks, often dropping ingredients, hallucinating quantities, or producing broken JSON outputs.10  
To overcome this, a promising future direction is the use of **domain-specific specialist models**.39 As demonstrated by DataChef-32B, online reinforcement learning with a proxy reward can adapt lightweight base models (like Qwen3-1.7B-Base) to match or exceed the performance of much larger general-purpose models on specific tasks.39 Similarly, evolutionary model merging techniques (such as MERGE) allow developers to merge domain-specific models into optimized hybrid models on a single GPU with minimal compute overhead.40  
Furthermore, distributing model weights in public repositories introduces potential licensing challenges:

| Model Family | License Name | Commercial Restrictions / Limits |
| :---- | :---- | :---- |
| **Llama 3.2** | Llama 3.1 Community License | Restricted if Monthly Active Users (MAU) exceed 700 million |
| **Gemma 3 / 4** | Gemma Terms of Use | Prohibits using model outputs to train competing language models |
| **Qwen 3 / 3.5** | Apache 2.0 / Custom | Permissive; highly viable for commercial use cases |

* **Primary Sources**: Tiger AI Lab (2025) 10, Cactus Engine Team (2025) 17, DataChef-32B Team (2026) 39, MERGE Framework Team (2025).41  
* **What it gives us**: Evaluates the performance boundaries of small-parameter models (under 3B parameters) on structured formatting and synthesis tasks.10 Outlines advanced model-merging and adaptive parameter-routing techniques to squeeze math and structural performance from compressed mobile engines.40  
* **Explicit Gap Line**: Public model-merging and adapter-tuning benchmarks do not evaluate list reconciliation and recipe-merging tasks for models under 1.5B, leaving developers to design and evaluate custom system-prompt formatting filters.10

### **Topic 5: On-device embedding models \+ vector search**

Developing a fast local retrieval path on mobile devices requires pairing a lightweight embedding model with an efficient embedded vector search library.9  
For the text embedding layer, candidate models must balance performance and memory footprint:

* all-MiniLM-L6-v2 offers fast CPU execution (\~14.7 ms per 1K tokens), making it a strong fit for resource-constrained edge devices.35 However, it exhibits a 5% to 8% accuracy deficit compared to heavier dual-encoder models like BGE-Base-v1.5 or Nomic Embed v1.35  
* To bridge this gap, developers can utilize local vector adapters that project smaller embeddings into higher-dimensional vector spaces, recovering up to 93% of larger models' retrieval performance while maintaining local speeds.43

For the database layer, traditional vector databases are designed for cloud servers and are too heavy for mobile deployment.13 Instead, the system can run lightweight vector extensions directly inside SQLite, the default local storage engine for iOS and Android.12  
Two primary libraries enable embedded vector search:

1. **sqlite-vec**: A pure C, zero-dependency SQLite extension that runs anywhere SQLite is supported, storing vectors in virtual tables (vec0).11 Pre-compiled binaries are available for Android and iOS.12  
2. **sqlite-vector**: Part of the SQLite AI stack, this extension stores vectors directly as BLOBs in standard SQLite tables, bypassing the need for virtual tables and enabling instant search with zero preindexing overhead.13

At the scale of this hackathon demo (typically under 5,000 recipe tuples per device), implementing approximate indexing structures like HNSW or IVF is unnecessary.13 Building an HNSW graph locally requires significant processing time and memory.9 Instead, **exact flat vector search** (calculating brute-force cosine similarity over a raw float array) is highly performant.13 For fewer than 5,000 vectors, modern mobile CPUs leveraging ARM NEON SIMD instructions can execute exact similarity calculations in under 10 milliseconds, bypassing index-building overhead and enabling instant data updates.13

* **Primary Sources**: Alex Garcia (2026) 11, SQLite AI Team (2025) 13, Supermemory Team (2024) 35, upb-cn Team (2025).9  
* **What it gives us**: Compares latency, memory profiles, and retrieval accuracy of local embedding models on mobile CPU and accelerator backends.9 Highlights that exact flat vector search inside embedded databases (like SQLite) operates under 10 ms for local sets up to 5,000 items, rendering heavy approximate indexes obsolete at our scale.9  
* **Explicit Gap Line**: There are no out-of-the-box, high-level React Native or Flutter bindings for the pre-compiled C vector search binaries; developers must implement platform-specific FFI wrappers manually.12

### **Topic 6: Local-first AI / offline-first AI prior art (and the writeup framing)**

The local-first AI movement builds on the principles of the 2019 Ink & Switch essay, shifting the data lifecycle and execution path from centralized servers directly to the user's device.27  
In traditional architectures, client applications act as thin views over remote API endpoints.44 This client-server pattern introduces significant failure modes in mobile environments: network disconnections block basic functionality, high-latency channels degrade performance, and server-side conflict resolution requires complex, brittle logic.7  
Local-first systems (such as Subconscious, Notesnook, and Evolu) resolve these challenges by moving the primary database onto the device.45 Evolu, for example, generates its local state by replaying an append-only log of CRDT mutations locally.46  
A key architectural principle of local-first AI is the separation of **synchronization mechanics** from **application-level business logic** 32:

1. **Sync Engine (Mechanical Layer)**: Manages network peer discovery, resolves database-level conflicts, and guarantees eventual consistency.7  
2. **UI/Domain (Semantic Layer)**: Implements business rules, normalizes data schemas, and handles UI state.24 For instance, if two concurrent edits to a recipe introduce conflicting quantities for an ingredient (such as "1 lb chicken" vs. "2 lbs chicken"), Ditto's map type preserves both inputs in an add-wins structure.8 The local application layer then uses the local LLM to resolve these conflicting entries and synthesize a clean, merged recipe.8 This design simplifies the synchronization layer by offloading complex semantic merging to the on-device AI.8  
* **Primary Sources**: Ditto Team (2025) 45, Biozal (2024) 33, Harris Jose (2024) 46, Varshith Gudur (2025).3  
* **What it gives us**: Establishes the core design patterns of offline-first databases, separating the mechanical transport layer from semantic conflict resolution layers.32 Discusses event-sourcing and vector clock state derivations to avoid leader-election bottlenecks.26  
* **Explicit Gap Line**: The prior art focuses almost exclusively on document and text editing databases, providing no architectures that couple CRDT synchronization with vector retrieval pathways on the edge.7

### **Topic 7: Latency floors and "the network round-trip is the moat" argument**

The core thesis of on-device RAG is that local execution wins on latency and reliability, not on hardware cost. In real-world mobile environments, relying on cloud-based APIs introduces significant latency bottlenecks.24  
Cloud-based vector databases (such as Pinecone, Weaviate Cloud, or MongoDB Atlas Vector Search) and LLM APIs (such as OpenAI or Gemini) are bound by speed-of-light propagation delays and mobile network overhead.43 In metropolitan areas, mobile connections frequently transition through coverage gaps, basements, and congested cells, raising cellular round-trip times (RTT) from 40 ms to over 300 ms.33  
A standard cloud-based RAG query requires two sequential internet round-trips:

1. Send the query text to an embedding API and receive the vector.43  
2. Send the retrieved vector context and prompt to a cloud LLM and wait for the response.9

If a cellular connection has an RTT of 150 ms, network transmission alone adds 300 ms of overhead, before accounting for API queuing and model generation times.43 Under these conditions, end-to-end cloud RAG latency often exceeds 1,000 milliseconds.43  
In contrast, an on-device RAG pipeline executes entirely within the device's memory 24:

1. The local embedding model (all-MiniLM-L6-v2) generates the query vector in \~15 ms.35  
2. The embedded search engine (sqlite-vec) executes a flat cosine similarity query in under 2 ms.13  
3. The Cactus engine, leveraging NPU hardware acceleration, achieves a Time-to-First-Token (TTFT) of under 50 ms.17

This on-device pipeline delivers an end-to-end latency of 67 ms to 150 ms.24 By eliminating the network round-trip, on-device architectures run faster and more reliably than cloud-based alternatives, especially in offline or degraded network environments.24

* **Primary Sources**: Ditto Team (2025) 45, upb-cn Team (2025) 9, InfoQ (2025) 24, Supermemory Team (2024).35  
* **What it gives us**: Formulates the speed-of-light physical constraints and cellular/Wi-Fi propagation latency boundaries.33 Provides direct comparative latency profiles showing that on-device RAG loops execute in under 150 ms, while cloud alternatives suffer from double network round-trips and queuing overheads exceeding 1,000 ms.24  
* **Explicit Gap Line**: The latency benchmarks do not capture the impact of high background device thermal throttling, which can degrade mobile CPU performance and raise local generation latency during prolonged runs.9

### **Topic 8: Hackathon demo aesthetics \+ presentation tooling**

Designing a compelling peer-to-peer AI demo requires making the decentralized synchronization and local merge processes visually clear to a live audience.15 The presentation can use Presenterm, a terminal-based slideshow tool written in Rust that supports markdown-driven layouts, code blocks, and inline images. Terminal presentations align well with developer-centric and local-first open-source projects.3  
For the "moment of magic" demo, the presentation should clearly visualize the network state and the resulting output changes 15:

1. **Isolation Stage**: Two devices (one iOS, one Android) are placed in airplane mode with Wi-Fi and Cellular disabled.49 Each device contains a single, unique version of a "Chicken Tortilla Soup" recipe in its local database.8  
2. **Local Query Execution**: The presenter queries Device A: "Generate a recipe for chicken tortilla soup." The local LLM generates an answer based *only* on Device A's unique ingredients and steps.8  
3. **The Sync Event**: The presenter enables Bluetooth on both devices.30 The devices automatically discover each other via BLE, establish a local peer-to-peer mesh connection, and sync their grow-only recipe sets.7 This sync process can be visualized in the UI using a peer graph showing connection states and sync completion.14  
4. **Unified Query Execution**: The presenter runs the same query on Device A.8 The local LLM retrieves the updated, merged recipe set and synthesizes a new output that combines ingredients and steps from both Device A and Device B.8

To make this demo effective for a non-technical audience, the application UI should visually represent the synchronization process. The interface can show a live node graph representing nearby discovered peers, indicators showing database payload transfers in real time, and a side-by-side diff showing how the retrieved vector context expanded after the peer-to-peer sync event.7

* **Primary Sources**: Ditto Team (2025) 15, Peat Protocol Team (2025) 14, Ditto SBIR Team (2023).49  
* **What it gives us**: Outlines design guidelines for clear peer-to-peer visualizations, highlighting the "moment of magic" when disconnected devices connect and sync local state directly over BLE.15 Mentions using interactive state maps and local cell-formation graphs to present real-time offline convergence.14  
* **Explicit Gap Line**: Existing presentation templates and P2P demos are tailored for command-line interfaces or flat text messaging; none provide out-of-the-box UI/UX guidelines for presenting a non-linear RAG output transition.15

## **3\. Tool Shortlist**

The following matrix provides the core technical components selected for the peer-to-peer RAG mobile architecture.

| Tool Class | Candidate(s) | Repository URL | Last Release Date | License | Maintenance Health (90-day commits / issues) | Mobile Platform Support Matrix | Recommendation & Justification |
| :---- | :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| **On-device Embedding Model** | Qwen3-Embedding-0.6B | https://github.com/cactus-compute/cactus 17 | Dec 2025 24 | Apache 2.0 / Custom | High activity within the Cactus engine ecosystem.17 | iOS (Apple NPU/CPU), Android (XNNPACK/NNAPI).17 | **Use it.** It is natively integrated into the Cactus Engine, allowing for fast, zero-copy memory-mapped embedding generation on mobile.17 |
| **On-device LLM** | Qwen/Qwen3-1.7B-Instruct | https://github.com/cactus-compute/cactus 17 | Dec 2025 24 | Apache 2.0 / Custom | High activity; actively updated in the Cactus model catalog.17 | iOS (ARM CPU/GPU), Android (ARM CPU/GPU).23 | **Use it.** It balances a small memory footprint (\< 1.2 GB RAM in INT4) with strong instruction-following capabilities, making it a reliable option for local list synthesis.17 |
| **On-device Vector Search Lib** | sqlite-vec | https://github.com/asg017/sqlite-vec 11 | Mar 2026 12 | MIT 11 | Active; regular bug-fix releases (such as v0.1.9) and low open issues.11 | Android (aarch64, armv7a), iOS (xcframework).12 | **Use it.** It is a pure C, zero-dependency extension that integrates directly into SQLite, providing a lightweight, reliable vector database option.11 |
| **Mesh-Sync Layer** | Ditto Edge SDK | https://www.ditto.com/products/edge-sdk 30 | Jan 2026 50 | Proprietary (Free Developer Tier) 16 | High; production-grade maintenance with structured release cycles.50 | iOS (Swift), Android (Kotlin), Flutter, React Native.30 | **Use it.** It provides a mature, production-grade BLE, LAN, and P2P Wi-Fi mesh synchronization stack with built-in CRDT conflict resolution.7 |
| **Slide-Deck Framework** | Presenterm | https://github.com/mfontanini/presenterm | Apr 2026 | MIT | Active; community-driven maintenance with regular updates. | Terminal-based; runs on macOS, Linux, and Windows. | **Use it.** It is an excellent, markdown-driven presentation tool for developer-centric demos and technical walkthroughs. |

### **Recommendation Rationale**

* Qwen3-Embedding-0.6B: Generation is bound to the local Cactus runtime, matching the on-device execution constraints of the LLM pipeline and guaranteeing zero-copy memory layouts on mobile hardware.17  
* Qwen/Qwen3-1.7B-Instruct: Selected over the 3B parameters threshold because of strict memory consumption boundaries (\< 1.2 GB RAM in quantized state), which is critical for supporting concurrent execution alongside background database synchronization on mid-range target devices.17  
* sqlite-vec: Chosen because of its simple integration within the native SQLite storage backend used by mobile SDKs, bypassing the compilation complexity of heavier C++ vector indexes.11  
* Ditto Edge SDK: Selected as the only commercially validated mesh networking engine for cross-platform P2P mobile databases, reducing the risks of low-level BLE socket programming.15  
* Presenterm: Ensures the presentation can execute directly from the terminal during the demo run, presenting code snippets and architecture diagrams without requiring standard presentation software.

## **4\. Reference Architectures**

The following reference architectures provide validated code structures and design patterns relevant to the peer-to-peer RAG implementation.

### **1\. MoRAGBench: Mobile RAG Orchestration Pipeline**

* **Repository**: https://github.com/upb-cn/MoRAGBench 9  
* **Target Files/Directories**: ./client/main.py, ./android/app/src/main/ 9  
* **What to copy**: Copy the modular design of the on-device RAG pipeline.9 Specifically, study how the Android application structures background text chunking, query vector generation, and local database storage, and how the client scripts manage automated test execution over ADB.9

### **2\. Valori-Kernel: Event-Sourced Replication and Fixed-Point Math**

* **Repository**: https://github.com/varshith-Git/Valori-Kernel 3  
* **Target Files/Directories**: ./src/, ./ffi/, ./architecture.md 3  
* **What to copy**: Copy the event-sourced database replication model and study the implementation of Q16.16 fixed-point arithmetic.3 This architecture illustrates how to achieve bit-identical vector states across different CPU platforms (x86 and ARM) by replacing floating-point operations.1

### **3\. sqlite-vec: Loading Embedded Vector Extensions**

* **Repository**: https://github.com/asg017/sqlite-vec 11  
* **Target Files/Directories**: ./sqlite-vec.h, ./android-ios.html, ./releases/ 11  
* **What to copy**: Copy the build configurations and loadable extension packaging patterns for mobile platforms.12 Look at how the pre-compiled C libraries are integrated into host mobile processes (Xcode and Android Studio) and loaded into the local SQLite connection.12

## **5\. Open Research Questions**

### **1\. Multi-Platform Bit-Level Determinism on Hardware-Accelerated NPUs**

The analysis of on-device execution indicates a lack of proven techniques for ensuring bit-identical transformer execution across proprietary NPUs, such as Apple’s ANE and Qualcomm’s Hexagon.1 Because vendor-controlled chip drivers use closed-source, hardware-specific matrix reduction paths, FMA optimizations, and tensor partitioning, minor numerical variances are inevitable.1 Current systems must choose between performance (using hardware acceleration with potential divergence) or determinism (using CPU execution with a performance penalty).1 Developing a lightweight, cross-platform hardware acceleration abstraction that guarantees bit-level parity remains an open challenge.

### **2\. Decentralized Graph-Based Indexing Over Churn-Prone Edge Meshes**

While flat vector search is highly performant for local datasets under 5,000 items, larger datasets require approximate indexing structures like HNSW.13 However, HNSW graph structures are sensitive to insertion order, meaning concurrent, uncoordinated inserts on separate edge devices can lead to divergent index topologies.1 There is currently no proven, decentralized merge algorithm for HNSW graphs that avoids full rebuilds on sync events, leaving a gap in our understanding of how to scale decentralized vector search past small local sets.13

### **3\. Schema-Constrained Synthesis at the 1B Parameter Scale**

While models under 3B parameters struggle with structured composition and schema compliance, combining small models with constrained decoding engines (such as context-free grammar constraints) may allow them to match the reliability of larger models on synthesis tasks.10 Defining the boundaries of these grammar rules, prompt structures, and model constraints is a key area for further exploration.

## **6\. Conclusions and Strategic Recommendations**

The analysis of on-device execution indicates that the proposed peer-to-peer RAG architecture is technically viable, provided key execution boundaries are carefully managed.  
To achieve a reliable two-device demo and address the identified technical risks, the following strategic actions are recommended:

1. **Isolate the Sync and Search Layers**: Do not attempt to synchronize or merge vector indexes directly across devices.8 Instead, use Ditto to synchronize the grow-only set (G-Set) of immutable recipe tuples.8 Let each device update its local vector index incrementally using sqlite-vec as new tuples are synced.11 This approach keeps the synchronization layer simple and robust.8  
2. **Mitigate Embedding Divergence via Fixed-Point Abstractions or CPU Fallbacks**: To prevent vector-space drift between iOS and Android, compile the embedding model execution pathway to run on the ARM CPU using strict IEEE-754 compiler settings, or implement a software-emulated fixed-point math layer.1 While hardware-accelerated NPUs offer higher speeds, they introduce minor numerical variances that can misalign the shared retrieval space.1  
3. **Optimize Payloads for BLE Bandwidth Constraints**: Because cross-platform offline sync falls back to BLE, application-layer throughput is limited to approximately 20 kB/s.15 Keep payload sizes lean by using compressed, lower-dimensional embedding spaces (such as 384 dimensions) and storing only business-critical fields in synchronized documents.15  
4. **Enforce Schema Compliance via Constrained Decoding**: At scales below 2B parameters, models frequently experience syntax errors and format adherence failures.10 To ensure the local LLM reliably synthesizes and normalizes merged list structures, implement strict system prompts and leverage grammar-constrained decoding engines within the Cactus framework.10

By executing these recommendations, developers can build a robust, high-performance edge AI system that delivers sub-second retrieval latency and reliable offline-first convergence.24

## **7\. What the CLI Agents Would Have Missed**

1. **Varshith Gudur (2025) \- Valori Paper (arXiv:2512.22280)**: This niche paper directly addresses floating-point non-determinism across x86 and ARM architectures in vector indexing, proposing a Q16.16 fixed-point mathematical execution layer.1 Standard CLI search scripts often overlook this paper, assuming floats are sufficient for local mobile execution.  
2. **David Pape et al. (2026) \- "The Silent Hyperparameter" (arXiv:2605.19537)**: Published in early 2026, this study documents how different optimization runtimes (llama.cpp, SGLang, Ollama) introduce enough numerical drift to alter token-level decision boundaries and shift accuracy scores by up to 16 percentage points.4  
3. **The iOS-Android P2P Wi-Fi Interoperability Barrier (Ditto Docs)**: Standard search tools often simplify "P2P mesh" capabilities without noting that iOS's AWDL and Android's Wi-Fi Aware do not directly interoperate without a LAN bridge.34 This physical platform fragmentation forces a fallback to BLE, which caps application bandwidth at 20 kB/s.16  
4. **StructEval Structural Compliance Performance Gap (Tiger AI Lab)**: This source provides detailed benchmark data showing a performance gap for models under 3B parameters when generating structured output.10 This runs contrary to general assumptions that small models are immediately ready for complex mobile RAG serialization tasks without constrained decoding layers.10  
5. **DataChef-32B (arXiv:2403.13187 / arXiv:2602.11089)**: This recent research outlines reinforcement learning frameworks with proxy rewards to adapt small models to domain-specific math tasks, bypassing the need for heavy parameter footprints on edge devices.39

## **8\. Source Ledger**

https://github.com/cactus-compute/cactus  
https://cactuscompute.com/  
https://cactuscompute.com/docs/v1.7  
https://www.infoq.com/news/2025/12/cactus-on-device-inference/  
https://www.reddit.com/r/deeplearning/comments/1kbucat/cactus\_framework\_for\_ondevice\_ai/  
https://github.com/cactus-compute/cactus/blob/main/docs/cactus\_engine.md  
https://www.ditto.com/products/edge-sdk  
https://powersync.com/blog/ditto-vs-powersync  
https://resources.ditto.live/developers  
https://www.ditto.com/platform/edge-sync  
https://sy6xxuj5rs5nwwun.public.blob.vercel-storage.com/images/MongoDB\_\_Ditto\_Reference\_Architecture\_Guide-pCdhhPzWyWDFEZjnPFB5LxrqRq0BVu.pdf  
https://www.ditto.com/solutions/conflict-resolution-powered-by-crdts  
https://businessmodelcanvastemplate.com/blogs/how-it-works/ditto-how-it-works  
https://docs.ditto.live/key-concepts/syncing-data  
https://www.ditto.com/blog/how-to-build-robust-offline-first-apps-a-technical-guide-to-conflict-resolution-with-crdts-and-ditto  
https://www.sbir.gov/portfolio/1629457  
https://www.ditto.com/blog/getting-started-with-bluetooth-file-sync  
https://docs.ditto.live/sdk/latest/deployment/network-deployment  
https://www.ditto.com/solutions/offline-first-architecture  
https://dev.to/biozal/transport-multiplexing-in-mobile-sync-why-multi-transport-beats-single-transport-systems-l37  
https://arxiv.org/abs/2605.19537  
https://arxiv.org/abs/2512.22280  
https://github.com/varshith-Git/Valori-Kernel  
https://github.com/upb-cn/MoRAGBench  
https://tiger-ai-lab.github.io/StructEval/  
https://direct.mit.edu/tacl/article/doi/10.1162/TACL.a.638/136339/Cooking-Up-Creativity-Enhancing-LLM-Creativity  
https://github.com/asg017/sqlite-vec  
https://github.com/sqliteai/sqlite-vector  
https://libraries.io/cargo/peat-protocol  
https://gafferongames.com/post/floating\_point\_determinism/  
https://github.com/asg017/sqlite-vec/releases

#### **Works cited**

1. Valori: A Deterministic Memory Substrate for AI Systems \- arXiv, accessed May 21, 2026, [https://arxiv.org/html/2512.22280v1](https://arxiv.org/html/2512.22280v1)  
2. Floating Point Determinism | Gaffer On Games, accessed May 21, 2026, [https://gafferongames.com/post/floating\_point\_determinism/](https://gafferongames.com/post/floating_point_determinism/)  
3. varshith-Git/Valori-Kernel: Valori is a Deterministic Memory ... \- GitHub, accessed May 21, 2026, [https://github.com/varshith-Git/Valori-Kernel](https://github.com/varshith-Git/Valori-Kernel)  
4. The Silent Hyperparameter: Quantifying the Impact of Inference Backends on LLM Reproducibility \- arXiv, accessed May 21, 2026, [https://arxiv.org/html/2605.19537v2](https://arxiv.org/html/2605.19537v2)  
5. The Silent Hyperparameter: Quantifying the Impact of Inference Backends on LLM Reproducibility \- The Journal Club, accessed May 21, 2026, [https://www.thejournal.club/c/paper/938963/](https://www.thejournal.club/c/paper/938963/)  
6. \[Revue de papier\] The Silent Hyperparameter: Quantifying the Impact of Inference Backends on LLM Reproducibility \- Moonlight, accessed May 21, 2026, [https://www.themoonlight.io/fr/review/the-silent-hyperparameter-quantifying-the-impact-of-inference-backends-on-llm-reproducibility](https://www.themoonlight.io/fr/review/the-silent-hyperparameter-quantifying-the-impact-of-inference-backends-on-llm-reproducibility)  
7. Conflict Resolution Powered by CRDTs \- Ditto, accessed May 21, 2026, [https://www.ditto.com/solutions/conflict-resolution-powered-by-crdts](https://www.ditto.com/solutions/conflict-resolution-powered-by-crdts)  
8. Syncing Data \- Quickstart \- Ditto, accessed May 21, 2026, [https://docs.ditto.live/key-concepts/syncing-data](https://docs.ditto.live/key-concepts/syncing-data)  
9. upb-cn/MoRAGBench: MoRAGBench is a modular ... \- GitHub, accessed May 21, 2026, [https://github.com/upb-cn/MoRAGBench](https://github.com/upb-cn/MoRAGBench)  
10. StructEval: Benchmarking LLMs' Capabilities to Generate Structural Outputs, accessed May 21, 2026, [https://tiger-ai-lab.github.io/StructEval/](https://tiger-ai-lab.github.io/StructEval/)  
11. asg017/sqlite-vec: A vector search SQLite extension that runs anywhere\! \- GitHub, accessed May 21, 2026, [https://github.com/asg017/sqlite-vec](https://github.com/asg017/sqlite-vec)  
12. sqlite-vec on Android and iOS devices | sqlite-vec \- Alex Garcia, accessed May 21, 2026, [https://alexgarcia.xyz/sqlite-vec/android-ios.html](https://alexgarcia.xyz/sqlite-vec/android-ios.html)  
13. SQLite-Vector is a cross-platform, ultra-efficient SQLite extension that brings vector search capabilities to your embedded database. \- GitHub, accessed May 21, 2026, [https://github.com/sqliteai/sqlite-vector](https://github.com/sqliteai/sqlite-vector)  
14. peat-protocol 0.9.0-rc.1 on Cargo \- Libraries.io, accessed May 21, 2026, [https://libraries.io/cargo/peat-protocol](https://libraries.io/cargo/peat-protocol)  
15. Getting started with Bluetooth File Sync \- Ditto, accessed May 21, 2026, [https://www.ditto.com/blog/getting-started-with-bluetooth-file-sync](https://www.ditto.com/blog/getting-started-with-bluetooth-file-sync)  
16. Ditto for Developers, accessed May 21, 2026, [https://resources.ditto.live/developers](https://resources.ditto.live/developers)  
17. cactus-compute/cactus: Low-latency AI engine for mobile ... \- GitHub, accessed May 21, 2026, [https://github.com/cactus-compute/cactus](https://github.com/cactus-compute/cactus)  
18. This month in rustsim \#11 (April \- May 2020): cross-platform deterministic physics using nphysics with fixed-point numbers\! : r/rust \- Reddit, accessed May 21, 2026, [https://www.reddit.com/r/rust/comments/gyeaik/this\_month\_in\_rustsim\_11\_april\_may\_2020/](https://www.reddit.com/r/rust/comments/gyeaik/this_month_in_rustsim_11_april_may_2020/)  
19. Deterministic Decoding in Transformer Models: Challenges and Solutions \- Medium, accessed May 21, 2026, [https://medium.com/@gwrx2005/deterministic-decoding-in-transformer-models-challenges-and-solutions-3ede45b3d039](https://medium.com/@gwrx2005/deterministic-decoding-in-transformer-models-challenges-and-solutions-3ede45b3d039)  
20. All About Transformer Inference | How To Scale Your Model \- GitHub Pages, accessed May 21, 2026, [https://jax-ml.github.io/scaling-book/inference/](https://jax-ml.github.io/scaling-book/inference/)  
21. Running a local model with 8GB VRAM \- Is it even remotely possible? : r/LocalLLaMA, accessed May 21, 2026, [https://www.reddit.com/r/LocalLLaMA/comments/19f9z64/running\_a\_local\_model\_with\_8gb\_vram\_is\_it\_even/](https://www.reddit.com/r/LocalLLaMA/comments/19f9z64/running_a_local_model_with_8gb_vram_is_it_even/)  
22. Cross-platform deterministic physics with Unity DOTS physics and soft floats \- Reddit, accessed May 21, 2026, [https://www.reddit.com/r/Unity3D/comments/lkxb9d/crossplatform\_deterministic\_physics\_with\_unity/](https://www.reddit.com/r/Unity3D/comments/lkxb9d/crossplatform_deterministic_physics_with_unity/)  
23. Overview \- Cactus Compute, accessed May 21, 2026, [https://cactuscompute.com/docs/v1.7](https://cactuscompute.com/docs/v1.7)  
24. Cactus v1: Cross-Platform LLM Inference on Mobile with Zero Latency and Full Privacy, accessed May 21, 2026, [https://www.infoq.com/news/2025/12/cactus-on-device-inference/](https://www.infoq.com/news/2025/12/cactus-on-device-inference/)  
25. \[2512.22280\] Valori: A Deterministic Memory Substrate for AI Systems \- arXiv, accessed May 21, 2026, [https://arxiv.org/abs/2512.22280](https://arxiv.org/abs/2512.22280)  
26. ljwagerfield/crdt: CRDT Tutorial for Beginners (a digestible explanation with less math\!) \- GitHub, accessed May 21, 2026, [https://github.com/ljwagerfield/crdt](https://github.com/ljwagerfield/crdt)  
27. How Does Ditto Company Operate? \- Business Model Canvas Templates, accessed May 21, 2026, [https://businessmodelcanvastemplate.com/blogs/how-it-works/ditto-how-it-works](https://businessmodelcanvastemplate.com/blogs/how-it-works/ditto-how-it-works)  
28. Valori: A Deterministic Memory Substrate for AI Systems \- ResearchGate, accessed May 21, 2026, [https://www.researchgate.net/publication/399174596\_Valori\_A\_Deterministic\_Memory\_Substrate\_for\_AI\_Systems](https://www.researchgate.net/publication/399174596_Valori_A_Deterministic_Memory_Substrate_for_AI_Systems)  
29. Conflict-free Replicated Data Types (CRDTs) \- DEV Community, accessed May 21, 2026, [https://dev.to/learnwithvikzzy/conflict-free-replicated-data-types-crdts-ij6](https://dev.to/learnwithvikzzy/conflict-free-replicated-data-types-crdts-ij6)  
30. Edge SDK \- Ditto, accessed May 21, 2026, [https://www.ditto.com/products/edge-sdk](https://www.ditto.com/products/edge-sdk)  
31. GitHub \- asg017/sqlite-vss: A SQLite extension for efficient vector search, based on Faiss\!, accessed May 21, 2026, [https://github.com/asg017/sqlite-vss](https://github.com/asg017/sqlite-vss)  
32. How to Build Robust Offline-First Apps: A Technical Guide to Conflict Resolution with CRDTs and Ditto, accessed May 21, 2026, [https://www.ditto.com/blog/how-to-build-robust-offline-first-apps-a-technical-guide-to-conflict-resolution-with-crdts-and-ditto](https://www.ditto.com/blog/how-to-build-robust-offline-first-apps-a-technical-guide-to-conflict-resolution-with-crdts-and-ditto)  
33. Transport Multiplexing in Mobile Sync: Why Multi-Transport Beats Single-Transport Systems, accessed May 21, 2026, [https://dev.to/biozal/transport-multiplexing-in-mobile-sync-why-multi-transport-beats-single-transport-systems-l37](https://dev.to/biozal/transport-multiplexing-in-mobile-sync-why-multi-transport-beats-single-transport-systems-l37)  
34. Local Area Network \- Quickstart \- Ditto, accessed May 21, 2026, [https://docs.ditto.live/sdk/latest/deployment/network-deployment](https://docs.ditto.live/sdk/latest/deployment/network-deployment)  
35. Best Open-Source Embedding Models Benchmarked and Ranked \- Supermemory, accessed May 21, 2026, [https://supermemory.ai/blog/best-open-source-embedding-models-benchmarked-and-ranked/](https://supermemory.ai/blog/best-open-source-embedding-models-benchmarked-and-ranked/)  
36. Atom: Efficient On-Device Video-Language Pipelines Through Modular Reuse \- arXiv, accessed May 21, 2026, [https://arxiv.org/html/2512.17108v1](https://arxiv.org/html/2512.17108v1)  
37. LLM Structured Output Benchmarks are Riddled with Mistakes \- Cleanlab, accessed May 21, 2026, [https://cleanlab.ai/blog/structured-output-benchmark/](https://cleanlab.ai/blog/structured-output-benchmark/)  
38. ‍ Cooking Up Creativity: Enhancing LLM Creativity through Structured Recombination | Transactions of the Association for Computational Linguistics | MIT Press, accessed May 21, 2026, [https://direct.mit.edu/tacl/article/doi/10.1162/TACL.a.638/136339/Cooking-Up-Creativity-Enhancing-LLM-Creativity](https://direct.mit.edu/tacl/article/doi/10.1162/TACL.a.638/136339/Cooking-Up-Creativity-Enhancing-LLM-Creativity)  
39. DataChef: Cooking Up Optimal Data Recipes for LLM Adaptation via Reinforcement Learning \- arXiv, accessed May 21, 2026, [https://arxiv.org/html/2602.11089v2](https://arxiv.org/html/2602.11089v2)  
40. Evolutionary Optimization of Model Merging Recipes \- arXiv, accessed May 21, 2026, [https://arxiv.org/html/2403.13187v1](https://arxiv.org/html/2403.13187v1)  
41. ICML Poster MERGE$^3$: Efficient Evolutionary Merging on Consumer-grade GPUs, accessed May 21, 2026, [https://icml.cc/virtual/2025/poster/43950](https://icml.cc/virtual/2025/poster/43950)  
42. MCAP: Deployment-Time Layer Profiling for Memory-Constrained LLM Inference \- arXiv, accessed May 21, 2026, [https://arxiv.org/html/2604.21026v1](https://arxiv.org/html/2604.21026v1)  
43. Generate OpenAI Embeddings Locally with MiniLM ( 70x Cost Saving / Speed Improvement ) : r/Python \- Reddit, accessed May 21, 2026, [https://www.reddit.com/r/Python/comments/1qlx02c/generate\_openai\_embeddings\_locally\_with\_minilm/](https://www.reddit.com/r/Python/comments/1qlx02c/generate_openai_embeddings_locally_with_minilm/)  
44. Ditto Vs PowerSync, accessed May 21, 2026, [https://powersync.com/blog/ditto-vs-powersync](https://powersync.com/blog/ditto-vs-powersync)  
45. Offline-First Architecture \- Ditto, accessed May 21, 2026, [https://www.ditto.com/solutions/offline-first-architecture](https://www.ditto.com/solutions/offline-first-architecture)  
46. Notes | Harris Jose, accessed May 21, 2026, [https://harrisjose.dev/notes](https://harrisjose.dev/notes)  
47. MongoDB \+ Ditto Reference Architecture Guide, accessed May 21, 2026, [https://sy6xxuj5rs5nwwun.public.blob.vercel-storage.com/images/MongoDB\_\_Ditto\_Reference\_Architecture\_Guide-pCdhhPzWyWDFEZjnPFB5LxrqRq0BVu.pdf](https://sy6xxuj5rs5nwwun.public.blob.vercel-storage.com/images/MongoDB__Ditto_Reference_Architecture_Guide-pCdhhPzWyWDFEZjnPFB5LxrqRq0BVu.pdf)  
48. LLMForge: Multi-Backend Hardware-Aware Neural Architecture Search with Infinite-Head Attention for Edge Language Models \- arXiv, accessed May 21, 2026, [https://arxiv.org/html/2605.17653v1](https://arxiv.org/html/2605.17653v1)  
49. Company \- | SBIR, accessed May 21, 2026, [https://www.sbir.gov/portfolio/1629457](https://www.sbir.gov/portfolio/1629457)  
50. Ditto SDK v5: Built for Speed and Developer Experience, accessed May 21, 2026, [https://www.ditto.com/blog/ditto-sdk-v5](https://www.ditto.com/blog/ditto-sdk-v5)

[image1]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADUAAAAaCAYAAAAXHBSTAAAB9klEQVR4Xt2VLU8EMRCGp0DQBAECg0CQYPAIDA5BgkBjUeBw/AAECQkowldIUAgSgiEoFCQI+At4QPAhCMkxs93utbPttre73c3xJHN3+3Zm+nZ73QVoE8EFjaKxpnB7cI/ohGV5KNuE6srW5ghpFJITj3Znl5gerjA6PUQbTGE8gJz/lo1ZocQVi5YsQFv/tNLiYdtxMQ/mvLPsOkNVj4LcKQ0xIGTRk6knvHChGJtJRdEJNXTysqYLyA/GPdNSBFwnnyYbIBstMX0YY4dpsRkD6YW+dW5SPUNfxLr2W/EO9u0dwRjnYmS2wO7lGJTOt8RBdp4yAgsjcAnci2Qf7LrCcDyI0UHlURd74KwgTjFOMI4wDjEOQD7VirgDu/ldkPoEH8gjYBNk8iIfaolzsC9qD6Q+pIuuP9QHWJq4kjmheT2QO1PpHLTTOZ8u0vPksJfKjlFiOzwEfc+kdS7mQHoqePp13dh80SObEr3nyVYcEfK0zLRPjDemWaGDSw1WDbXhFSi0aWlXftmGkM/JTGHQHfgG+W56TYPOFb2xu//ZpGF+daTk1Sg8Y3xhXID0tZCoDU1eC+W8+g88qNHinFCqd6neoU/pi4X7TYqQpGrU0r+WJv+R5MYYd0e/aOq2sXlamrZmSnYPKvMk0bAnxYNZXa2XnT8Z0mQTL5NxWwAAAABJRU5ErkJggg==>

[image2]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAmwAAAA6CAYAAAAN3QXmAAAEzklEQVR4Xu3dS8g1cxgA8HG/5ZaibFCUS30bkih9LCQkCdkotyjZfAsldm4lbLCUS7KwYWUjhRALSomy+nKJZCOSKPF/es/7fnOeM+ecmfPOubzn/H719M7/mTnznzPnfef/nJk5560qgD3usJwAAAAAAACocS0BAAAANoEzAAAAwKbxPggAAJiJNxMAMG9GWwBYa4Z6AAAWQuEJAGwgJRAAwMZSCgIAsFeoXVk2v4PAGnAoA2Dg+BKn5eQSfJETTPVDTizYtzkBAPTvuhLv5uScPVbiv0FkTblVclJOLNG/ten3qvH7dN6W0SfL5swfrCN/2Susz8H2+pyYIPr9KCeLM0vclJMTfJ0Tc9Tnvtqtv0pcnXKvl3g85aZ5Midm0PU1AwA6uLXEZTm5Cw/lxARR/ByXkwNdCqMuy+7GhyWOzcklanreTblp3smJGc3SNwDQwvc5UXN3iRtycoquBVt4ayi7Jea1vfQ4XChMP5l7VLV1SfbBPGOK73JiijhzdWJO9ujjnKi29sWRJd6s2heXXQu2K0u8XeLclFewAcCcNA2yF1TD+Zi+uNaepG3Bdle1td4jBu28HdF+LuXGyY+d5McS5w2m/ylxY23etihEDqb4JbUf3ll61GfVoW26ozbdpwMlbkm516rR162NLgXbpPXnNgDQk6ZBNnL3p3aT00tckuL51L5wZ+lhsc4TUrsu7s+KwqdJ7jMem3NNrqiG+4n7rtr6MicmqPdxT2rX5W1uisN3lh4Wxdk5KRf9fJra59faIS5B5z4+acg1ifXtq7Xz5ex4zQBggUYuq40k1kVTMVHPnZXadXEmKs5Q1ePV1L5qe+EkrzO3/6zGf8VH7jMem3NN/qjan7Wri0uobb1YDT+Xg6ldl7e5KY7ZWXrYKyXOTrno59rUzk6pRvv4vCGXReHYtL66eM2AFtZ2RAHmJg/CcemzbcHRpO0l0fo6rynxe60dYv7LKTdO2+2L5docJy8q8Xct4nH1dsSzO0sPi6Iwn518tMQDtVwf7i1xc8rV98NTqT1Jm0uit1fT1zdtPtBSmwMVsFl+yonq0MAbN63HdNxg/s2h2RPNUrA1DfSROzUnx2h6fJNHquFi6qva9DhdPzRweYmXBtNRqG1v26+Dn316P7Wjr/gC5O3pvj90kPdz/TvgQp4PAPTkzmr0AwVvVFuDbwzkcYN+TN83tMR4bQu2EOuNaLrk2GXw77JsnAGL5eMs2dFpXpPfcqKFuDQYfewv8cFgeh7yeuOesu192kXbgi321/b640t6s679AgAd9DnQ3pYTM4h/kbU/Jyfo+nUbbT1Tjd4ntkridbs0J6cavdbyQk7MoOtrBgB09ES19b1dq6LPAnI3ns6JFdRuX40WaX1rtx3A5pn/8Qc2StO/iFqGM0qcnJOMFZ8i3ZeTC/Zz5TWDCVQsAAAAbCLvh4HVt3FHqo17wrDC/D0C7F2O4QAAAAAAq8aZWwAAYFN5PwRLsJg/vMX0AkvnVx1g/TnWA9CZwQMAAAAAAAAAAGDp3MoFAAAAAAAAsBQu1wKweoxOAOyGcQQAYIEUXwAA9E+VCQAAAAAAAAAAe8/eue9n72wpAAAAAAAAAAAAAACw4XwMAmAu1vvwut7PDgBg/annAFbS/0Ti1Lz7oJH7AAAAAElFTkSuQmCC>

[image3]: <data:image/png;base64,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>

[image4]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAmwAAAA5CAYAAACLSXdIAAAFeElEQVR4Xu3dWchtUxwA8HVNZQyREg88eCDzFFI3lKGQCC+8KXVJihJSHgzJWF68uIbyYFZejN2SKHMoZbhCkTGkzKz/PXvfs7717TPc4dzvnPP9frd/Z631P2fvc77z9e3/WXvtc1MCYOasqAeYP8vgTV4GLxEAYLopyAAAAAAAAAAAYMNZdwMAAADMNrMbLGd+/wEAAAAmw7wLAAAAU8eHVQAAYFr5vAIAAAAAMKOOqgfYbHbIcVg9ODGm6gFgkXNz/J7j1xxbVblTcvyZ45dqvPZ+PTAB/9UDhcgNy8+yq+qBDi/mOCLH9jnurnJ75lib458cB1S5EO/5Hzm+zLFNlQtPpeE/3+9SP/9zjh9Sb18/5di5uB8AsJFOznFP0Y+D7vVNOw7u5VxHFHVHFv1WPGbSBds5aXDBEHZNw/OjPFgPTIFPc5yVxntdbcEUsXuVK9+byH9f9KNIf77IDdpXbGNQLtyeFuef6BgDADbCwTn+LfpxgH2rab+beoVQK2ZaHij6IQ7Ul6XRBVs9c9c6vR7ocGaOK9Pwg3/M5AzLj7Ipj520cZ7bjfVAoXx8XZSV7XiPti36pTfT8OfRVbCd3TEGMMss2Fh2pvctjwPsXk372qa/qsjVPkrjFWxdj41TrbE2apSY2Qtd22jtlPr5u3KcVuTitO4hOQ7PsXeO3XKckOP4Jn9B6j32jCZKcTpyTTW2f44vUq94fX1haiKGve7WsIKtFNu6rWnf0vRDFMXDvJH69z0ux6E5ju2nOwu2OI1ejwEAmyDWG3UdXKMwifGu3DvN7TgFWyi38VfRHubeot31HFo7pl5+l6Zfz7j9WPXjdF25Xqtr2+VYtC9v2jdV410uTL11Y6NiHAP2saDqj/sctL69+APBV+vGFz4o1pnFKdHzmn7kn+ynFygLtm9yfFzkQluwlXHMgnsAbBGL/wDCPIoD7dVNOxawv9S04+AeuYub/mupv6B83IItxDbGLdZCuWZuQOGyTluwlT7J8XDRL/P1fev+h6m3ri1mGyOeS/37xO3TOU5s+pNWP7dRoqBq37dabOvzol1u+4aqX2oLtjXVeKtrhi0KthiL36P55LgAwBIpD+L1Afi+YixuY+1bXF34d9Ee5ZUcl+bYrk50KPcREf24bU/plboKtjWpd9Vi684cr+Z4KPVOoZbqx0a/vtqytSL/i1OhdcEzKaP2EesQy+caV4wOekxbeId4DZ8VuWHrBNuCbWVauOax1VWwhS31MwKAuRYH0/g6h7LfHmC7DrRdY4+k8WbYygN910F/lK59t7oKtm9zXFONDSog2rHHm9tnU28WcZSubYVLUr/QHBTt2rxRBu2jVZ6uDHG68oOm/XWVK19/rEX7rcjF1cGD9vV2Wvh7sbrIhWEFW1ztygwygQgwPcpiLcQBNk6Nhfdy7FPk4sAbC/RrL6TeGqlhYmanFkVb1/d+DdJVELSiYIvttV/uelHqvn+MxUUHtbIYKcdubdqn5riuaa9tbkPXPjanPVL3PmLswKYdV3fGRRRlrnVFjv2KfuTq599+DUi0Xy5ypZiJa7e7b9OOiy9aq5uxUvTrMQBgI8VMS6zJilOetbiy8pkcd9SJKXZ+PVCIr6cYZNDjovirnZTj6HpwCW2d4/4cN9eJ1PtqljgN/GidaKxMvVPVACwXptCZQuW37cdVkbCOv1cAMD3ii4Djf3R4rE4AAAAAAAAAAMB6Vn8CAADMEp/imAS/VwAAwFzyYQcAYM4o8IAh/InYAEv+w1ryJwAAAADA8mJCCgAAAACALcakNAAAAAAAAAAAAAAAAAAAAAAA88k37AAAAAAAAAAAAAAAAMAEuYAHAAAAAAAAAApOpAMAAAAAhP8B0e06f4DVYk0AAAAASUVORK5CYII=>