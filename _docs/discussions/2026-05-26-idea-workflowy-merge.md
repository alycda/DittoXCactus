<!--
DRAFT — GitHub Discussion, category: Ideas
Repo: alycda/DittoXCactus
Source: spike-workflowy branch, commit vwtzqzwu / 59b95637
Source file: SEED-B.md (186 lines)

Pre-post checklist:
- [x] Source branch spike-workflowy is on origin
- [ ] Strip this HTML preamble before posting
- [ ] Title: "Workflowy Merge: AI repairs what CRDTs can't reach"
- [ ] Category id: DIC_kwDOSlRUbc4C9qmY (Ideas)
-->

# Workflowy Merge: AI repairs what CRDTs can't reach

Pulled from a dangling spike branch (`spike-workflowy` /
[SEED-B.md](https://github.com/alycda/DittoXCactus/blob/spike-workflowy/SEED-B.md))
that I never built. Posting as an Idea so the framing survives outside a
branch nobody looks at.

The pitch in one line: **two outliners on a mesh, items sync over BLE, and
the on-device LLM proposes semantic merges for near-duplicates the CRDT
can't dedupe.** Same Ditto + Cactus + flat-cosine stack as the current
demo, with the LLM's task *inverted* — judging rather than generating.

## Why this is a stronger LLM frame than the current demo

The shipped demo forces the LLM to *generate* — synthesize study
flashcards from merged notes. That's the hardest task in NLP at 1.5B
parameters. We absorb the failure modes (bilingual `<think>` drift,
`\boxed{}` math-mode, off-topic padding — see
[`model-quirks.md`](https://github.com/alycda/DittoXCactus/blob/main/_docs/notes/model-quirks.md))
with a layered parse pipeline.

This idea inverts it: the LLM only ever *judges* — given two short items
(≤ 50 tokens each), output one of:

```json
{ "verdict": "same" | "subset" | "sibling" | "different",
  "canonicalName": "...",   // present if same/subset
  "rationale": "..." }       // 1 line max
```

Structured classification with a tiny output budget. Qwen 2.5 1.5B or even
0.6B handles it cleanly. The CRDT-merge thesis maps directly:
**AI is good at intent; CRDTs are good at structure. The fusion is bigger
than either alone.**

## Demo moment

Two phones in airplane mode. Each holds 5–8 list items, picked to exercise
four merge modes:

| Phone A | Phone B | Merge mode | Expected verdict |
|---|---|---|---|
| lettuce | salad mix | synonym | `same` → "leafy greens" |
| sandwich meat | sliced turkey | subset (turkey ⊂ sandwich meat) | `subset` |
| Coke | Pepsi | siblings under "cola" | `sibling` |
| Mr Pibb | Dr Pepper | near-clone | `same` → "Dr Pepper-style soda" |
| milk | almond milk | sibling (both "milk", distinct) | `sibling` |
| tomatoes | tomato | spelling/number variant | `same` → "tomato" |
| dish soap | hand soap | different | `different` |

The pairs are difficulty-calibrated: synonym + near-clone are trivial;
subset is where smaller models start tripping; sibling and different are
where the LLM has to actually disambiguate.

**The demo, in beats:**

1. **Alone.** Phone A shows its 5–8 items. Plain bulleted outline. No merge cards.
2. **Bring phone B into BLE range.** Mesh pill turns green. Items sync in. The list now shows ~15 items.
3. **Merge candidates appear inline.** For each high-cosine pair, a small card appears between the items: *"These look similar. [merge] [keep both] — lettuce and salad mix are both leafy greens."*
4. **Tap merge on one.** Both items vanish; a single new item appears with the canonical name and a "merged from A's 'lettuce' + B's 'salad mix'" pill.
5. **The merged item syncs back to phone B.** Phone B now also shows the merged item with the same provenance.

That last beat is the moment of magic. The LLM's judgment, made on phone A,
propagated to phone B over BLE — without any cloud arbitration.

## Why this is the most mesh-load-bearing direction

Ditto's delta-state CRDTs merge structured fields by construction.
Free-text fields they can't reach: both edits live forever as
near-duplicates, compounding as more peers contribute. **The on-device
LLM is the arbiter the CRDT can't be — and because it runs on each peer
independently, the arbitration is itself mesh-compatible.**

When phone A's user taps "merge", phone B doesn't re-run the LLM. It
accepts the merge as a regular CRDT op (a tombstone + new-tuple, or a
`mergedFrom` field write). Both phones converge to the same state. The
AI happens *inside* CRDT semantics, not bolted on top.

- CRDT alone → near-duplicate spam.
- LLM alone (no mesh) → can dedupe a list, but it's just your phone.
- **CRDT + on-device LLM + mesh** → the list stays clean as it grows across contributors, no cloud.

## Retrieval shifts role: from query→item to item→item

Cosine top-k still runs every cycle, but the inputs change. Today's
retrieval is "find tuples relevant to a query." Workflowy Merge is
"for each item just-synced-from-peer, find the local item with the
highest cosine and propose for LLM judgment if score is in the gray
zone."

```dart
for newItem in newlySyncedItems:
  topMatch = cosine_top_1(newItem.embedding,
                          localItems.where(i => i.contributor != newItem.contributor))
  if topMatch.score >= 0.99:    autoMerge()              // typo dups, no LLM needed
  elif topMatch.score >= 0.7:   askLLM(newItem, topMatch) // gray zone
  else:                          keepSeparate()           // too far
```

The 0.99+ tier catches typo-level dups cheaply. The 0.7–0.99 gray zone
is where the LLM earns its keep. ~10–15 pairs per demo at ~120 total
tokens each = sub-second per judgment.

## Schema

`ListItem` (renames `StudyNote`-shaped tuple):

```dart
{
  id: UUID,                      // deterministic from (contributor, text, createdAt)
  text: String,                  // the item itself
  contributor: String,           // "phone-a" or "phone-b"
  mergedFrom: List<String>?,     // ids this one supersedes
  embedding: List<double>,
  createdAt: DateTime,
}
```

A merge becomes a single new `ListItem` whose `mergedFrom` field
references the two source items. The originals are evicted locally on
each peer via DQL `EVICT`. Provenance survives in `mergedFrom`.

## What's NOT in scope

- **Hierarchical outlines.** This is flat (Workflowy without nesting). Stage 1 = parent-child indentation.
- **Undo a merge.** Once accepted on both peers, no revert. Stage 1 = user-initiated "unmerge" with conflict-free semantics.
- **Multi-way merges (≥ 3 items).** Only pairs. Stage 1+ could do n-way.
- **Persistent merge-card backlog.** If you close the app with pending merges, they regenerate on next launch (LLM is cheap enough). Stage 1 = persist pending cards in Ditto.

## Why I haven't built it

Stage 0 + Stage 1 (the current demo) absorbed all the implementation
budget. Workflowy Merge is the *prettier* idea — smaller surface area,
better LLM/CRDT fit, more visually obvious demo — but the existing
codebase is shaped for *generation*, not classification. A real build
would be a ~7-file pivot:

| File | Change |
|---|---|
| `lib/models/study_note.dart` | → `lib/models/list_item.dart`. Adds `mergedFrom`. |
| `lib/prompts/flashcard_gen.dart` | → `lib/prompts/item_merge.dart`. Structured JSON verdict prompt. |
| `lib/services/retrieval_service.dart` | Add `proposeMerges(newItems)`. The current `generateFlashcards` becomes vestigial. |
| `lib/services/ditto_service.dart` | Add `mergeItems(ids, newCanonical)` (write canonical + evict originals). |
| `lib/prompts/dql_queries.dart` | Collection rename → `items`. Add `EVICT FROM items WHERE _id IN :ids`. |
| `assets/seed_notes_*.json` | → `assets/seed_items_*.json`. Items per the table above. |
| `lib/widgets/query_screen.dart` | → `lib/widgets/outline_screen.dart`. Inline merge cards. |

Everything else stays — BootScreen, MeshStatusWidget, Ditto/Cactus init,
BLE permissions, plan/spike doc structure.

## What I want feedback on

- **The pitch.** Does "AI repairs what CRDTs can't reach" land as a
  one-liner, or does it sound like CRDT-skeptic framing?
- **The mode taxonomy.** Same / subset / sibling / different — is that the
  right four-way verdict, or is there a smaller / larger set that's
  cleaner?
- **The gray zone threshold.** 0.7–0.99 is a guess. Anyone with empirical
  experience tuning cosine thresholds on similar tasks — what worked?
- **Where the LLM might still hallucinate.** Even with classification-shaped
  output, models can confidently mis-label. What's the structural fallback
  ("show both, ask user") that lets the system degrade gracefully?

## Source

Single 186-line file on branch
[`spike-workflowy`](https://github.com/alycda/DittoXCactus/blob/spike-workflowy/SEED-B.md).
Not merged to main; preserved as the seed for whoever picks this up.
