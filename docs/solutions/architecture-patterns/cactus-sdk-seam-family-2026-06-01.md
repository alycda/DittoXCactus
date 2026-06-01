---
title: "Cactus 1.3.0 SDK seam family: the runtime abstracts away the network and metric points your demo controls"
date: 2026-06-01
category: architecture-patterns
module: cactus-sdk
problem_type: architecture_pattern
component: tooling
severity: high
applies_when:
  - Building an on-device RAG path on top of Cactus 1.3.0 (or comparable generalist-shaped runtime)
  - Demo or production guarantee depends on no-outbound-traffic, calibrated retrieval scores, or deterministic model state
  - Designing for the specialists-vs-generalists writeup thread (this pattern is its load-bearing evidence)
  - Evaluating whether a runtime SDK is fit for the demo's threat model before wiring it into hot paths
  - Reviewing a PR that consumes a new Cactus API and wondering "what did this hide from me"
related_components:
  - tooling
  - documentation
tags:
  - cactus
  - sdk
  - ondevice-llm
  - architecture
  - runtime-abstraction
  - r7-holdout
  - retrieval-calibration
  - specialists-thesis
---

# Cactus 1.3.0 SDK seam family: the runtime abstracts away the network and metric points your demo controls

## Context

DittoXCactus uses Cactus 1.3.0 as the on-device LLM runtime — embedder (`qwen3-0.6-embed`) and completion (`qwen3-1.7`) for the mesh-RAG demo. Three holdouts depend on knowing exactly what the runtime does and does not do:

- **R7 (end-to-end offline)** — never cut, no internet during the demo
- **R3/R4 (sync idempotence, convergence)** — depend on deterministic retrieval ranking across phones
- **R2 (cross-platform parity)** — embeddings must be bit-identical across iOS/Android

Cactus 1.3.0 is a generalist-shaped runtime: it assumes cloud-backed model catalogs, hides retrieval metric details behind RAG abstractions, and ships sane-for-prototyping defaults. Each of those is the correct decision for a generalist runtime. Each of those is a **seam** when the demo's argument is built on the opposite assumptions.

This is not a list of bugs. It's a pattern: **whenever the SDK abstracts away a network call, a distance metric, or a deterministic-state knob, the demo has to reach back through the abstraction to keep its guarantees.** Three concrete instances are documented today; the pattern predicts more will surface.

## Guidance

For each Cactus SDK surface the demo consumes, run this two-question check before wiring it into a hot path:

1. **Does this surface produce or consume bytes outside the device?** (network calls, telemetry, model-catalog lookups, dynamic asset downloads) — if yes, R7 is at risk; assume the SDK will not honor a single global kill switch
2. **Does this surface abstract a metric, a distance, a threshold, or a deterministic ordering?** (RAG search, embedding similarity, top-k) — if yes, R3/R4 are at risk; assume the SDK is making opinionated choices that don't match your calibration needs

If either answer is yes, **do not consume the SDK abstraction directly.** Reach back to the lower-level primitive (raw embedder, raw completion, raw model cache) and build the abstraction yourself with the metric/network points pinned. This is more code today; it preserves the truth of your evidence chain forever.

The three instances we've encountered so far:

### Seam 1 — Cloud model-registry call ignores `isTelemetryEnabled` (issue #33)

`Supabase.getModel(slug)` fires a GET to `vlqqczxwyaodtcdmdmlw.supabase.co/functions/v1/get-models` on every model init, sending model slug + SDK name/version. **No `isTelemetryEnabled` guard**, unlike sibling functions `sendLogRecord` / `registerDevice` which both early-return when telemetry is off. Verified in [`lib/src/services/api/supabase.dart:135-158`](https://pub.dev/packages/cactus/versions/1.3.0) inside cactus 1.3.0.

R7 holds *functionally* only because airplane mode fails the DNS lookup closed before any payload leaves the device — and because the SDK's failure mode is a `debugPrint`, not a thrown exception, so downstream flow continues via local `ModelCache`. A host-side packet capture during the recording window would observe an outbound DNS query and break the evidence chain.

Mitigation in [`lib/services/cactus_service.dart`](../../../lib/services/cactus_service.dart): pin `CactusConfig.isTelemetryEnabled = false` (kills `sendLogRecord` + `registerDevice`), boot online once to warm the model cache, then go airplane. Disclose the residual DNS attempt in the writeup; do not claim "zero outbound traffic" without the disclosure. *(auto memory [claude]: `project_cactus_supabase_leak`)*

### Seam 2 — `CactusRAG.search()` exposes raw Euclidean distance (issue #37)

[Cactus issue #37](https://github.com/cactus-compute/cactus-flutter/issues/37) (opened 2026-05-28): `CactusRAG.search()` returns `ChunkSearchResult.distance` from ObjectBox's default Euclidean HNSW index. Even after mapping through `obx_vector_distance_to_relevance`, absolute similarity scores cluster ~0.45–0.50 for very different queries — useless for threshold-based routing (`hasContentThreshold ≈ 0.4`).

The reporter (CascadiaSolutions) hit this with Qwen3-0.6B 1024-dim embeddings, exactly our setup. The diagnosis is correct: Euclidean over un-normalized embeddings is dominated by vector magnitude, not direction. The workaround direction is correct: normalize both sides + swap to cosine distance. The API just doesn't expose the knob.

DittoXCactus avoids the seam by **never using CactusRAG**. [`lib/services/retrieval_service.dart:506`](../../../lib/services/retrieval_service.dart) does `dot(normalize(query), normalize(doc))` — brute-force true cosine over the Ditto-materialized notes set, bounded `[-1, 1]`. `defaultMinScore = 0.3` works because we own the metric end-to-end. Real cosines from the 2026-05-25 dry-run, documented inline at retrieval_service.dart:460–462:

```
"Saturn" (on-topic proper noun)  → top cosine 0.430
"saturn" (lowercase, OOD)         → top cosine 0.262
"mars"   (off-topic from corpus) → top cosine 0.077
```

~5× separation between strong match and off-topic. CactusRAG would have hidden this exact information. *(auto memory [claude]: `project_cactusrag_distance_seam`)*

### Seam 3 — Token-callback `FormatException` on multi-byte UTF-8 boundaries

Less severe than the other two but illustrates the same pattern at a different layer. The Cactus FFI hands the Dart side a `String` decoded from a byte buffer at token boundaries; multi-byte UTF-8 characters (Chinese, in our case — triggered by Qwen's bilingual CoT drift) get split mid-codepoint. The decoder errors are noise — the final assembled stream parses cleanly — but they're concrete evidence that the SDK assumes single-byte text and offloads the consequences to the consumer.

Cross-references `model-quirks.md` (the bilingual-CoT trigger) and `cactus-sdk-quirks.md` (the byte-boundary mechanics).

## Why This Matters

This is the **load-bearing evidence for the writeup's specialists-thread argument.** The thesis arc (per `project_writeup_thesis_arc` auto memory) closes on a four-thread future-work pitch — *specialists, preference-aware merge, adversarial filtering, generational evolution* — and the opening rhetorical lift comes from showing that **a generalist on-device LLM runtime structurally cannot meet the demo's offline + calibration + determinism guarantees** without consumer-side workarounds.

Each seam is concrete texture for that argument:

- A specialist runtime would have **no model-registry concept** — model weights are a fixed asset baked into the package, no Supabase call exists to fire
- A specialist runtime would expose **the embedder and a brute-force cosine** at the top level, not a generic RAG abstraction over an HNSW index with hidden Euclidean defaults
- A specialist runtime would ship a **single tokenizer + decoder boundary**, owned end-to-end, not a generalist Unicode handler retrofitted to multi-byte streams

Three independent observations becomes a *family*. A family becomes a *pattern*. A pattern becomes a *paragraph in the post* that no skeptical reader can dismiss as cherry-picking. This is the compounding move.

## When to Apply

- **Before** wiring any new Cactus API into a path that touches an R-numbered holdout — run the two-question check above
- **During** PR review when a diff introduces a new SDK consumer — challenge "what did this hide from me"
- **At writeup time** — pull from this doc when arguing the specialists thesis; cite the issues filed upstream (#33, #37) as the public anchors
- **At Stage 2 scoping** (out-of-scope but documented) — if/when arbitrary file ingestion lands, the temptation to "just use CactusRAG for the vector store" is exactly the failure mode this doc names. Re-read before reaching for it.

## Examples

### Example 1 — the pattern shape, concrete

```dart
// ❌ Consume the abstraction. SDK chooses the metric and the network behavior.
final results = await cactusRag.search(query: "Saturn", topK: 5);
final score = results.first.distance; // ObjectBox Euclidean. Unbounded.
                                       // Mapped relevance clusters ~0.499.
if (score > threshold) { /* unusable */ }

// ✓ Reach back through. Own the metric.
final qVec = normalize(await embedder.embed(toTitleCase(query)));
final candidates = await ditto.materializeNotes();
final ranked = candidates
    .map((n) => (note: n, score: dot(qVec, normalize(n.embedding))))
    .where((r) => r.score >= 0.3) // bounded [-1, 1], calibrated threshold
    .toList()..sort((a, b) => b.score.compareTo(a.score));
```

### Example 2 — the two-question check, in conversation

> "Hey, can we use Cactus's `voice-models` API for the TTS overlay?"
>
> Two-question check:
> 1. Does this surface produce/consume bytes outside the device?
>    → Yes — `fetchVoiceModels` is a sibling of `getModel`. Per issue #33 it
>    won't honor `isTelemetryEnabled`. R7 risk.
> 2. Does it abstract a metric or deterministic state?
>    → Maybe — voice model selection has latent ordering. R3 risk if any
>    voice picker depends on it.
>
> Answer: not without (a) compile-time stubbing the network path or (b) pinning
> the chosen voice model to a fixed asset.

### Example 3 — upstream issues filed as the public anchor

The truth of this pattern needs a paper trail outside this repo or the writeup is "anonymous engineer complains about SDK." The three issues filed at [cactus-compute/cactus-flutter](https://github.com/cactus-compute/cactus-flutter) are the anchor:

- [#33](https://github.com/cactus-compute/cactus-flutter/issues/33) — Seam 1 (telemetry flag ignored by model registry)
- [#34](https://github.com/cactus-compute/cactus-flutter/issues/34) — chat-tuned slugs accepting `embed()` with cryptic runtime failure (forced the two-model architecture)
- [#37](https://github.com/cactus-compute/cactus-flutter/issues/37) — Seam 2 (CactusRAG Euclidean distance not fit for threshold routing) — observational comment added 2026-06-01

If any of these land upstream, this doc's specific instances become historical; the *pattern* survives because the next SDK version will introduce its own abstractions over things the demo controls.

## Related

- [_docs/notes/cactus-sdk-quirks.md](../../../_docs/notes/cactus-sdk-quirks.md) — project-specific deep-dive on each seam individually (this doc is the cross-cutting pattern that ties them together)
- [_docs/notes/model-quirks.md](../../../_docs/notes/model-quirks.md) — the model-side companion (Qwen 1.7B quirks: bilingual CoT, `<think>`-despite-ban, etc.)
- [project_writeup_thesis_arc](file:///Users/alyssaevans/.claude/projects/-Users-alyssaevans-Experiments-DittoXCactus/memory/project_writeup_thesis_arc.md) (auto memory) — the four-thread future-work arc this pattern feeds
- [project_specialist_small_models_thesis](file:///Users/alyssaevans/.claude/projects/-Users-alyssaevans-Experiments-DittoXCactus/memory/project_specialist_small_models_thesis.md) (auto memory) — the specialists thesis this pattern is evidence for
- [tools/holdout_7/offline_witness.md](../../../tools/holdout_7/offline_witness.md) — R7 evidence checklist; Seam 1's residual DNS attempt is disclosed there
- Sibling architecture-pattern doc opportunity: structural-gates-on-small-model-paths (feedback_structural_gates + project_grounding_must_be_structural in auto memory) — the *consumer-side discipline* this seam pattern motivates
