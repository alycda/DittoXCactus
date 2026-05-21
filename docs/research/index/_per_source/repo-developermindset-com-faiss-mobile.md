# FAISS Mobile

- **Source ID:** repo-developermindset-com-faiss-mobile
- **Kind:** repo
- **Path:** inspiration/repos/DeveloperMindset-com__faiss-mobile
- **Density:** 2

## Elevator summary

A community port of Faiss (Facebook AI's similarity-search library) to iOS, macOS, tvOS, watchOS, and Android using XCFramework + NDK packaging. While FAISS itself is for classical vector indexing on single machines or GPU clusters, this port demonstrates how to compile and distribute dense linear-algebra libraries to mobile targets. For Mesh RAG, it's a reference for the *shape* of mobile-native packaging (build once, distribute as precompiled frameworks) rather than the direct library choice — we sidestep HNSW complexity in Stage 0 with brute-force cosine, but this repo shows the infrastructure pattern if we need ANN later.

## Tags

`faiss`, `mobile`, `vector-search`, `ios`, `android`, `native-compilation`, `xcframework`

## Topics covered

1. Cross-compiling C++ libraries (FAISS) for mobile platforms
2. iOS/macOS XCFramework packaging and distribution
3. Android NDK integration and ABI management
4. Swift Package Manager and Cocoapods integration
5. Multiple-platform CI/CD for pre-built binaries

## What we'd take from this

- Packaging a high-performance C++ library for iOS *and* Android requires separate build pipelines (Swift PM + CocoaPods for Apple; Gradle + NDK for Android); the payoff is bytewise-identical behavior across platforms.
- Pre-compiled XCFramework distributions let iOS developers integrate without building FAISS locally — the release infrastructure pattern is worth copying for Cactus integration if we ever wrap its C FFI in a Swift Package.
- Architecture-specific ABI selection (arm64-v8a, x86_64, x86 on Android; arm64/arm64e/x86_64-sim on iOS) is necessary for performance; the repo automates this; ignore this complexity for Stage 0 (where we run cosine in Dart/Swift/Kotlin anyway).

## Cross-references (optional)

- paper-2401.02385 (Faiss library fundamentals)
- repo-facebookresearch-faiss (source upstream)
