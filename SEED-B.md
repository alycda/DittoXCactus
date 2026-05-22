# SEED-B — Workflowy Merge: AI repairs what CRDTs can't reach

**Status:** seed for Stage 0.5 candidate B (realization of hackmd Candidate B)
**Parent commit:** `rpwkxyyx c4a6dda0` (Mesh RAG Stage 0, post-maxTokens=768)
**Date:** 2026-05-21
**Frame:** weekend pivot. Same Ditto + Cactus + flat-cosine stack, **inverted task**: the LLM acts on incoming-from-peer items, not on user queries.

> **One-liner:** Two outliners. Each phone holds a list. When they meet
> over BLE and items sync in, the on-device LLM proposes semantic merges
> for near-duplicates the CRDT can't dedupe. The user accepts or rejects
> each one.

## Why this is a stronger frame than recipes

Stage 0 forced the LLM to *generate* prose (synthesize a merged recipe
from variants). That's the hardest task in NLP at this parameter count.

This candidate inverts it: the LLM only ever *judges* — given two short
items (≤ 50 tokens each), output one of:

```
{ "verdict": "same" | "subset" | "sibling" | "different",
  "canonicalName": "...",   // present if same/subset
  "rationale": "..." }       // 1 line max
```

That's a structured classification task with a tiny output budget.
Qwen 2.5 1.5B (or even 0.6B) handles it cleanly. **The CRDT-merge thesis
from hackmd Candidate B literally maps onto this:** "AI is good at
intent; CRDTs are good at structure. The fusion is bigger than either."

## Demo moment

Two phones, both in airplane mode. Each phone holds 5–8 list items.
Items are picked to exercise four merge modes:

| Phone A | Phone B | Merge mode | Expected LLM verdict |
|---|---|---|---|
| lettuce | salad mix | **synonym** | `same` → canonical: "leafy greens" |
| sandwich meat | sliced turkey | **subset** (turkey ⊂ sandwich meat) | `subset` |
| Coke | Pepsi | **siblings** under "cola" | `sibling` |
| Mr Pibb | Dr Pepper | **near-clone** | `same` → canonical: "Dr Pepper-style soda" |
| milk | almond milk | **sibling** (both "milk" beverages, distinct) | `sibling` |
| tomatoes | tomato | **same** (spelling/number variant) | `same` → "tomato" |
| dish soap | hand soap | **different** | `different` |

These pairs are difficulty calibration: synonym and near-clone are
trivial; subset is where smaller models start tripping; sibling and
different are where the LLM has to actually disambiguate.

**The demo, in beats:**

1. **Alone.** Phone A shows its 5–8 items. Plain bulleted outline. No
   merge cards.
2. **Bring phone B into BLE range.** Mesh pill turns green. Items from
   phone B sync in. The list now shows ~15 items.
3. **Merge candidates appear inline.** For each high-cosine pair, a small
   card appears between the items: "These look similar. [merge] [keep
   both] — *rationale: lettuce and salad mix are both leafy greens.*"
4. **Tap merge on one.** Both items vanish; a single new item appears
   with the canonical name and a small "merged from A's 'lettuce' + B's
   'salad mix'" pill.
5. **The merged item syncs back to phone B.** Phone B now also shows
   the merged item with the same provenance pill.

That last beat is the moment of magic. The audience sees that the LLM's
judgment, made on *phone A*, propagated to *phone B* over BLE — without
any cloud arbitration.

## Thesis

Ditto's delta-state CRDTs merge structured fields by construction.
Free-text fields they can't reach: they let both edits through, leaving
near-duplicates that compound forever. **The on-device LLM is the
arbiter the CRDT can't be — and because it runs on-device on each peer
independently, the arbitration is itself mesh-compatible.**

When phone A's user taps "merge", phone B doesn't need to re-run the LLM;
it just accepts the merge as a regular CRDT operation (a `tombstone +
new-tuple` or a `mergedFrom` field write). Both phones converge to the
same state. The AI happened *inside* the CRDT semantics, not bolted on
top.

This is the framing the hackmd Candidate B page calls "**the fusion is
bigger than either**":
- CRDT alone → near-dup spam.
- LLM alone (no mesh) → can dedupe a list but it's just your phone.
- CRDT + on-device LLM + mesh → list stays clean as it grows across
  contributors, no cloud.

## Schema

`ListItem` (renames `RecipeTuple`):

```dart
{
  id: UUID,            // deterministic from (contributor, text, createdAt)
  text: String,        // the item itself
  contributor: String, // "phone-a" or "phone-b"
  mergedFrom: List<String>?,   // ids of items this one supersedes
  embedding: List<double>,
  createdAt: DateTime,
}
```

A merge becomes a single new `ListItem` whose `mergedFrom` field references
the two source items. The originals are evicted locally on each peer via
DQL `EVICT`. Provenance survives in `mergedFrom`.

## Retrieval becomes "candidate-finding"

Cosine top-k changes role: instead of "find tuples relevant to a query",
it's "for each item just-synced-from-peer, find the local item with
highest cosine and propose for LLM judgment if score ≥ threshold."

```dart
// pseudo
for newItem in newlySyncedItems:
  topMatch = cosine_top_1(newItem.embedding, localItems.where(i => i.contributor != newItem.contributor))
  if topMatch.score >= 0.7 and topMatch.score < 0.99:
    askLLM(newItem, topMatch.item)  // gray zone
  elif topMatch.score >= 0.99:
    autoMerge()                     // exact dupe; no LLM needed
  else:
    keepSeparate()                   // too far; not a candidate
```

The 0.99+ threshold catches typo-level duplicates without burning LLM
tokens. The 0.7-0.99 gray zone is where the LLM earns its keep.

## What changes vs Stage 0 (file count: ~7)

| File | Change |
|---|---|
| `lib/models/recipe_tuple.dart` | → `lib/models/list_item.dart`. Adds `mergedFrom`. |
| `lib/prompts/recipe_merge.dart` | → `lib/prompts/item_merge.dart`. New system prompt: structured JSON verdict. |
| `lib/services/retrieval_service.dart` | Add `proposeMerges(newItems)` method. `answerQuery` becomes vestigial / removable. |
| `lib/services/ditto_service.dart` | Add `mergeItems(ids, newCanonical)` method (write merged tuple + evict originals). |
| `lib/prompts/dql_queries.dart` | Collection rename → `items`. Add `EVICT FROM items WHERE _id IN :ids`. |
| `assets/seed_recipes_*.json` | → `assets/seed_items_*.json`. Items per the table above. |
| `lib/widgets/query_screen.dart` | → `lib/widgets/outline_screen.dart`. Inline merge cards. |

What stays unchanged: BootScreen, MeshStatusWidget, Ditto/Cactus init,
BLE permissions, plan/spike doc shapes.

## What it doesn't try to do (Stage 1+ deferrals)

- **Hierarchical outlines.** Stage 0.5 is flat (Workflowy without nesting).
  Stage 1 = indentation / parent-child.
- **Undo a merge.** Once merged + accepted on both peers, no revert.
  Stage 1 = user-initiated "unmerge" with conflict-free semantics.
- **Multi-way merges (≥ 3 items).** Stage 0.5 only handles pairs. Stage 1+
  could do n-way.
- **Persistent merge-card backlog.** If the user closes the app with
  pending merge cards, they regenerate on next launch (LLM is cheap
  enough). Stage 1 = persist pending cards in Ditto.

## Why this passes the on-device LLM bar even better than Candidate A

| Task | Tokens in | Tokens out | Difficulty |
|---|---|---|---|
| Stage 0 (recipe merge) | ~600 | ~600 (hits 768 cap) | hard — generative synthesis |
| Stage 0.5/A (flashcards) | ~400 | ~400 (5 cards) | medium — extractive QA |
| Stage 0.5/B (item merge) | ~80 | ~40 per pair | trivial — structured classification |

A typical demo session: ~10–15 pairs to judge, each ~120 total tokens.
The LLM call is sub-second; the user perceives it as instant.

## Hand-off to ce-work

Smallest of the three options. Could ship in a half day:
- ~7 files of changes
- New JSON seed lists designed for the four merge modes
- Inline merge card is a single new widget

Recommend `ce-work` directly. If the implementer wants more rigor:
`ce-plan` would surface U-IDs for "the 7 merge-mode test cases pass"
as the U2-style holdout.

## Sources

- Origin: hackmd Candidate B (`https://hackmd.io/4ChwPprHQBOvgi_DyWur0g`)
- Stage 0 plan: `docs/plans/2026-05-21-001-feat-mesh-rag-stage-0-implementation-plan.md`
- Stage 0 architecture review: `docs/architecture-vs-flutter-skills.md`
- Why pivot: U3 recipe-merge eval gap — the LLM can't synthesize but it
  can judge.
