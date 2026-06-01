---
title: "Structural gates beat prompt instructions and stream watchdogs on small-model paths"
date: 2026-06-01
category: architecture-patterns
module: retrieval-pipeline
problem_type: architecture_pattern
component: service_object
severity: high
applies_when:
  - Building any path that hands user input to a 1–2B parameter LLM and expects constrained output
  - Designing the boundary between retrieval and generation in a RAG loop
  - Tempted to add a watchdog, circuit breaker, or stream-level detector on model output
  - Writing prompts that include "do not fabricate" or "output nothing if X" clauses
  - Reviewing a PR that gates model behavior with a prompt instruction instead of a service-layer check
related_components:
  - service_object
  - tooling
tags:
  - small-model
  - rag
  - grounding
  - structural-gate
  - watchdog
  - prompt-engineering
  - specialists-thesis
---

# Structural gates beat prompt instructions and stream watchdogs on small-model paths

## Context

The 2026-05-25 on-device dry-run on Pixel 6a (Qwen3-1.7B, mesh-RAG demo) captured the load-bearing observation that motivates this pattern. With the system prompt set to `(no notes available — output nothing.)` for queries that returned zero retrieved notes, the model's `<think>` block contained, verbatim:

> *"perhaps the assistant must comply and output exactly zero flashcards? But that contradicts with wanting three. Alternatively, maybe they made a mistake in instructions?"*

Then it produced three fabricated Saturn flashcards from training-distribution priors anyway. *(auto memory [claude]: `project_grounding_must_be_structural`)*

This isn't an instruction-following bug. It's the model **smart enough to read the rule, smart enough to identify the conflict, and not smart enough — or not aligned tightly enough — to resist resolving the conflict in favor of the user's apparent intent.** At 1.5B scale, prompt-level guardrails like "don't make things up" and "output nothing if no notes" are not enforceable. The model rationalizes past them on-device, with the rationalization preserved in the `<think>` block as an artifact.

The pattern: **the grounding decision must be made outside the model.** Three structural gates were added at the retrieval→generation boundary, and one stream-level watchdog was tried then rolled back as the worked example of why this pattern matters.

## Guidance

For any small-model (≤2B) generation path, prefer **structural gates at the service-layer input boundary** over both:

- **Prompt-level instructions** (don't fabricate, output nothing if X) — the model rationalizes past these
- **Stream-level output detectors** (watchdogs, circuit breakers, mid-stream classifiers) — these ask an ambiguous question ("did the model emit the right shape?") with no clean answer between verbose-but-honest and verbose-but-stuck

The decision-procedure for any new model-touching code:

1. **What input would have prevented this bad output?** If you can answer that, gate on the input. Never add the model to the call chain.
2. **What constraint is unambiguous from the inputs alone?** If you can express it as a boolean (`empty == 0`, `cosine < 0.3`, `entity_overlap == 0`), it belongs in a service-layer check.
3. **What constraint is only knowable from the output?** If you genuinely need the model's response to know whether the model was wrong, you have an output-detector problem — and on small models, no detector cleanly separates the failure modes. Step back and add an upstream gate that makes the failure mode impossible to reach.

The three structural gates currently shipped in [`lib/services/retrieval_service.dart`](../../../lib/services/retrieval_service.dart):

### Gate 1 — Title-case input normalization

```dart
Future<Float32List> embedQuery(String query) async {
  return CactusService.instance.embedF32(_toTitleCase(query));
}
```

Qwen-embed is highly case-sensitive on proper-noun tokens (verified: `"Saturn"` → 0.430, `"saturn"` → 0.262). Lowercase proper nouns are out-of-distribution and produce drifted embeddings. The gate forces the query into the embedder's training distribution before any retrieval math runs. *(auto memory [claude]: drawn from `feedback_structural_gates`, "title-case normalization" as one of the four service-layer gates)*

### Gate 2 — Cosine threshold (`defaultMinScore = 0.3`)

`topK` filters retrieved candidates by cosine similarity. Weak retrievals (off-topic, noise) never enter the generation budget. The threshold is calibrated against real on-device cosines from the dry-run — strong matches separate at ~5× from off-topic, so 0.3 sits in the gap and routes reliably.

### Gate 3 — Entity-overlap grounding gate

```dart
final retrieved = filterByEntityMention(cosineRetrieved, topic);
if (retrieved.isEmpty) {
  if (kDebugMode) print('skipping LLM call (grounding gate)');
  return; // LLM is never called
}
```

After cosine passes the threshold, the entity filter drops anything that doesn't actually mention the query topic. When the result is empty, **the LLM is never called.** The failure the model rationalized past — fabricating from training priors — can no longer arise, because there is no model call. *(auto memory [claude]: `feedback_llm_grounding` insists on "not enough info" beats fabrication; the gate enforces it without trusting the prompt)*

### Gate 4 — Stop sequences

Every Cactus completion call is configured with `_kDefaultStopSequences` (`\boxed`, `\begin{aligned}`, `\text{`) that abort the stream when the model drifts into math-mode reasoning. This is the only gate that operates on the output stream, and even here it's structural (string match on known artifacts), not heuristic.

### The anti-pattern that motivated this doc: watchdog rollback

The U12 watchdog (`lvpuysomzuvq`, now-dangling jj change; the abandoned `u12-watchdog` branch at commit `afa8b0a0`) tried to detect "model is looping inside `<think>`" by inspecting the streaming buffer for `Q:` outside think-blocks. It was rolled back on 2026-05-25 once the three upstream gates were in place — the watchdog became simultaneously obsolete and net-negative on false positives. **The right gate was further upstream.** *(auto memory [claude]: `feedback_structural_gates`, "lvp rollback 2026-05-25" is the worked example)*

Note: an older auto-memory entry (`project_grounding_must_be_structural`) described the watchdog as a third defense layer alongside the cosine threshold and grounding gate. That memory predates the rollback and reflects an intermediate state. The current truth, encoded in `lib/services/retrieval_service.dart`, is three structural gates and no stream watchdog.

## Why This Matters

This pattern is **load-bearing evidence for the specialists-vs-generalists thesis** that the writeup closes on. The seam-family doc ([cactus-sdk-seam-family-2026-06-01.md](./cactus-sdk-seam-family-2026-06-01.md)) names this as its sibling: *seams in the SDK motivate gates in the consumer.* Together they form one argument:

- The generalist on-device runtime (Cactus) ships abstractions that hide network and metric points the demo controls (seam-family doc)
- The generalist on-device model (Qwen 1.7B) rationalizes past prompt-level constraints because it's smart enough to identify them as constraints and not aligned tightly enough to honor them (this doc)
- A **specialist** small model trained on a single task — say, study-note merging on a fixed corpus — has no instruction-conflict to rationalize past, because the only behavior in its training distribution *is* the desired behavior

The on-device `<think>` quote above is the smoking gun. Three sentences from the model's own reasoning trace where it identifies the rule, identifies the conflict, and decides the user must have made a mistake in instructions. Worth quoting verbatim in the writeup's "what makes this hard" section.

This also captures a **general engineering rule** that applies far beyond on-device LLM work: when you find yourself reaching for an output detector, ask whether an input gate would make the failure impossible. The output detector treats a symptom; the input gate eliminates the failure mode. The watchdog rollback is the small worked example; the structural-gates discipline is the durable lesson.

## When to Apply

- Designing any new RAG path, even on bigger models (the discipline applies; the urgency scales with how small the model is)
- About to add `_kStopWords`, `_kForbiddenPhrases`, `WatchdogStream`, `OutputClassifier`, or similar — pause and ask the decision-procedure question first
- Writing a system prompt that includes "do not", "output nothing if", "only respond when" — the small-model version of that prompt won't hold; design the service-layer gate that makes the prompt unnecessary
- Reviewing PRs that gate model behavior with prompt instructions — request the equivalent structural gate before approving

## Examples

### Example 1 — the watchdog rollback, full shape

**Before (rolled back):**

```dart
// Stream-level watchdog: detect "stuck reasoning" by looking for Q: outside <think> blocks
class WatchdogStream extends Transformer<String, String> {
  bool insideThink = false;
  int tokenBudget = 200;
  void onToken(String t) {
    if (t.contains('<think>')) insideThink = true;
    if (t.contains('</think>')) insideThink = false;
    if (--tokenBudget < 0 && !t.contains('Q:')) abort('stuck');
  }
}
```

Ambiguous question: is the model verbose-but-honest (it's about to emit `Q:` next token) or verbose-but-stuck (it's looping in `<think>`)? No detector cleanly separates these on Qwen 1.7B.

**After (shipped):**

```dart
// Service-layer grounding gate: don't call the model if retrieval can't ground the answer.
final retrieved = filterByEntityMention(
  await topK(topic, k: 10, minScore: 0.3),
  topic,
);
if (retrieved.isEmpty) {
  return; // LLM never called. Failure mode cannot arise.
}
final stream = cactus.complete(buildPrompt(topic, retrieved));
```

Unambiguous question: did retrieval produce any grounded candidates? Boolean answer. The failure the watchdog was built to catch — model burning the token budget reasoning over ungrounded input — is now structurally impossible.

### Example 2 — the prompt-vs-gate decision

**Before (prompt-level, doesn't hold):**

```
System prompt:
  "You are a flashcard generator. Use only the retrieved notes below. If no notes are
   provided, output exactly nothing. Do not fabricate."

User prompt:
  "Generate 3 flashcards about Saturn."

[no notes attached]
```

Model identifies the conflict in `<think>`, decides the user must have made a mistake, fabricates from training priors. Three Saturn flashcards. Demo broken.

**After (service-layer, holds):**

```dart
// The "no notes → output nothing" rule lives here, not in the prompt.
if (retrieved.isEmpty) return;
```

The prompt no longer needs the clause. The model is never called with an ungrounded input.

### Example 3 — the litmus test, applied prospectively

> "Should we add a profanity filter on flashcard output?"
>
> Apply the decision procedure:
> 1. What input would have prevented this? Profanity in the corpus, or a query that elicits it. Gate on those at ingest / query time.
> 2. Is that constraint unambiguous from inputs? Yes — string match against a profanity list.
> 3. Do we genuinely need the output to know? No.
>
> Answer: don't add an output filter. Add ingest-side and query-side checks. The output filter would treat a symptom; the input gates eliminate the failure mode.

## Related

- [docs/solutions/architecture-patterns/cactus-sdk-seam-family-2026-06-01.md](./cactus-sdk-seam-family-2026-06-01.md) — the sibling pattern: seams in the SDK motivate gates in the consumer
- [lib/services/retrieval_service.dart](../../../lib/services/retrieval_service.dart) — the three shipped gates live here; line 636 has the grounding-gate skip, line 483 has the title-case normalization, line 223 has the entity filter
- [_docs/notes/model-quirks.md](../../../_docs/notes/model-quirks.md) — Qwen 1.7B model-side quirks the gates work around (bilingual CoT, `<think>`-despite-ban, verbose-budget-exhaustion)
- Auto-memory entries this doc consolidates:
  - `feedback_structural_gates` — the gate-vs-detector decision rule with the watchdog rollback as worked example
  - `project_grounding_must_be_structural` — the on-device `<think>` quote and the three-layer architecture
  - `feedback_llm_grounding` — the demo-credibility motivation ("not enough info" beats fabrication)
- Abandoned-branch reference: `u12-watchdog` at `afa8b0a0` (jj change `lvpuysomzuvq`, now dangling) — the watchdog this doc names as the anti-pattern
