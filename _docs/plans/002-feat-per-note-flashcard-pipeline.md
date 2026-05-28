# Plan 002: Per-note flashcard generation pipeline

**Status:** Proposed
**Replaces:** The one-shot prompt path in `generateFlashcards` (plan 001 §U11)
**Motivation:** The one-shot prompt fails ~50% at n≥3 cards due to format-collapse
(model-quirks.md "Format-collapse to summary article at n≥3"). Per-note calls
stay in the n=1 regime where the model already works reliably.

---

## Granularity decision: per-note, not per-fact

One model call per retrieved note, asking for 1 flashcard each.

**Why not per-fact (extract facts, then generate Q/A per fact)?**
- Doubles the number of model calls (3 notes × 2 steps = 6 calls)
- At 5–15s per call on a Pixel 6a, 6 calls = 30–90s — unacceptable
- The extraction prompt itself can produce malformed output that poisons step 2
- Per-note at 1 card each (3 calls = 15–45s) is comparable to current one-shot (10–30s)
  and already takes >30s in practice anyway

**Why this works:** The 2048-token context window easily fits 1 note (~100–200 tokens)
+ 1 card request + system instructions. The format-collapse problem is eliminated by
design — the model never sees multiple sources or a multi-card request.

---

## Pipeline flow

```
Step 1: topK + entity filter                         [app code, unchanged]
Step 2: yield FlashcardEventRetrieved                 [unchanged]
Step 3: grounding gate                                [unchanged]
Step 4: FOR EACH retrieved note (up to effectiveN):
  4a. yield FlashcardEventProgress(i, total)          [new event type]
  4b. Build per-note prompt via buildPerNote(...)      [new, simpler prompt]
  4c. complete(messages, maxTokens: 732)               [one call, small budget]
  4d. Stream FlashcardEventPartial chunks              [unchanged semantics]
  4e. Parse single card via existing parse()           [unchanged]
  4f. Set sourceNoteIds = [currentNote.id]             [app code, replaces backfill]
  4g. Per-card validation (on-topic, reasoning-leak, answer-length)
  4h. yield FlashcardEventCards([card])                [incremental]
Step 5: Final dedup pass across all emitted cards      [app code]
Step 6: yield FlashcardEventDone                       [unchanged]
```

---

## What changes

### `lib/prompts/flashcard_gen.dart` — new `buildPerNote` method

Simpler prompt. One note, one card, trailing `Q:` anchor to prime format:

```
System: You are a careful study buddy. You make study flashcards from short notes.
[format rules — same as current but without multi-card rules]

User: Topic: [topic]
Note: [noteId] [noteBody]
Output exactly 1 flashcard about "[topic]" using only facts from this note.
Q:
```

The trailing `Q:` structurally primes the model to continue in Q:/A:/SOURCE:
format rather than drifting. The existing one-shot prompt says "start with Q:"
but doesn't structurally enforce it.

The existing `build()` and `parse()` stay for backward compatibility and tests.

### `lib/services/retrieval_service.dart` — rewritten `generateFlashcards`

- Loop over retrieved notes, one `complete()` call per note
- `maxTokens` drops from `512 + 220*N` to `512 + 220*1 = 732` per call
  (may reduce further if `<think>` budget can shrink for simpler prompts)
- Source attribution is a one-liner: `sourceNoteIds: [note.id]`
- `backfillCardSources` becomes unnecessary (deterministic attribution)
- `cleanCards` runs as a final dedup-only pass; per-card filters run inline

New sealed class variant:
```dart
class FlashcardEventProgress extends FlashcardEvent {
  final int current;  // 1-indexed
  final int total;
  const FlashcardEventProgress(this.current, this.total);
}
```

### `lib/widgets/flashcards_tab.dart` — incremental card display

Cards appear one at a time as each note's pipeline completes:

```
t=0s:    "Generate" tapped
t=0.1s:  Retrieved(3 notes) → "drew on 3 notes"
t=0.2s:  Progress(1, 3) → "generating card 1 of 3…"
t=0–8s:  Partial chunks → thinking panel streams
t=8s:    Cards([card1]) → first card appears in stack
t=8.1s:  Progress(2, 3) → "generating card 2 of 3…"
t=8–16s: Partial chunks
t=16s:   Cards([card2]) → second card appears
t=16–24s: ...
t=24s:   Cards([card3]) → third card
t=24.1s: Done → spinner disappears
```

Implementation: `_stagedCards` list accumulates cards. Each `FlashcardEventCards`
appends and replaces `_history[0]` with an updated `_Generation`. Partial buffer
resets between notes via `FlashcardEventProgress` handler.

---

## What simplifies

| Current layer | Per-note pipeline | Status |
|--------------|-------------------|--------|
| `backfillCardSources` (30 lines, content-matching heuristic) | One-liner: `sourceNoteIds = [note.id]` | **Eliminated** |
| Citation-required filter in `cleanCards` | Always passes (attribution is structural) | **Redundant** (keep as defense-in-depth) |
| Multi-card parser edge cases (truncation mid-card-2, blank-line separators) | Parser only ever sees 1 card | **Irrelevant** (code stays, cases don't fire) |
| `effectiveN` scaling | Natural: 1 note = 1 card | **Simplified** |
| Token budget arithmetic (`thinkBudget + perCard * N`) | Fixed: `thinkBudget + perCard` | **Simplified** |
| Format-collapse at n≥3 | **Cannot happen** (n is always 1) | **Eliminated by design** |
| Fullwidth Chinese digits in UUIDs | Model never sees UUIDs | **Eliminated by design** |

## What stays

| Filter | Why it's still needed |
|--------|----------------------|
| On-topic (Q or A mentions topic) | Mars note mentioning moons can still produce an Olympus Mons card |
| Reasoning-leak ("Wait,", "Hmm,") | `<think>`-despite-ban is model-level, not prompt-level |
| Answer-length (>300 chars) | Less likely at n=1, but model can still ramble |
| Dedup across notes | Two notes about Venus could produce the same question |
| Cap at N | Backstop if more notes pass entity filter than cards requested |

---

## Testing strategy

### CI-testable (no device needed)

1. `FlashcardGenPrompt.buildPerNote` prompt assembly — pin system message,
   verify single note in user message, verify `Q:` anchor
2. `FlashcardGenPrompt.parse` on single-card output — existing tests cover this
3. Per-card validation (`_isCardAcceptable`) — extract from `cleanCards`, unit test
4. Source attribution — verify `sourceNoteIds: [note.id]` for each card
5. `FlashcardsTab` incremental rendering — emit multiple `FlashcardEventCards`,
   verify card stack grows
6. Dedup across notes — two notes producing same question → 1 card
7. `FlashcardEventProgress` exhaustiveness — compiler enforces

### Requires on-device (issue #3 / PR #14)

1. **Format compliance rate** — run per-note pipeline on seed corpus, measure
   % of calls producing a valid card. Hypothesis: near 100% (vs ~50% at n≥3)
2. **Wall-clock latency** — compare one-shot vs per-note for 3 cards
3. **Token budget tuning** — experiment with reducing `_kThinkBudget` for
   per-note calls (simpler prompt may not trigger `<think>`)
4. **Back-to-back `complete()` calls** — verify no Cactus context-reuse
   bottleneck or cold-start penalty between calls

---

## Implementation sequence

| Phase | What | Files |
|-------|------|-------|
| 1 | Add `buildPerNote` prompt + tests | `flashcard_gen.dart`, `flashcard_gen_test.dart` |
| 2 | Add `FlashcardEventProgress` to sealed class + UI handler | `retrieval_service.dart`, `flashcards_tab.dart` |
| 3 | Rewrite `generateFlashcards` to per-note loop | `retrieval_service.dart` |
| 4 | Update `FlashcardsTab` for incremental cards | `flashcards_tab.dart`, `flashcards_tab_test.dart` |
| 5 | On-device validation | Deploy to Pixel 6a, compare pipelines |

---

## Risks

**Latency:** 3 sequential calls may be slower than 1 one-shot call. Mitigated by:
smaller token budget per call, and the one-shot already takes >30s and fails half
the time (retry cost makes effective latency much higher).

**Narrower questions:** Per-note loses cross-source comparative context. The model
can't write "How does Jupiter's moon count compare to Saturn's?" from a single note.
Acceptable trade-off: a pipeline that works 95% of the time with direct questions
beats one that works 50% of the time with occasionally richer questions.

**Cactus context reuse:** Sequential `complete()` calls may or may not reuse the
KV cache. If each call re-initializes from scratch, setup cost is paid 3×. Verify
empirically on-device.

---

## Thesis connection

This is the specialist architecture described in the writeup's Thread 1, implemented
without fine-tuned models. Each per-note call is a task simple enough that the
generalist model acts as a specialist for that one subtask. A future fine-tuned
specialist would just be faster at it.

The one-shot prompt's `cleanCards` pipeline (12 defensive filters) is the scar tissue
of asking a generalist to do a specialist's job in one pass. The per-note pipeline
eliminates 3 of those filters by design and makes 2 more nearly redundant.
