# SEED-A — Learning Together: flashcards that improve with each new student

**Status:** seed for Stage 0.5 candidate A (refinement of hackmd Candidate A)
**Parent commit:** `rpwkxyyx c4a6dda0` (Mesh RAG Stage 0, post-maxTokens=768)
**Date:** 2026-05-21
**Frame:** weekend pivot. Same Ditto + Cactus + flat-cosine stack, more LLM-friendly downstream task.

> **One-liner:** Generate 3–5 flashcards from local notes. When more students' phones join the mesh, the same request produces *better* cards — because the LLM now sees notes that fill gaps the lone phone couldn't.

## Why pivot from recipes

Stage 0 verified that retrieval + sync work end-to-end on two phones. The
weakness was the **recipe-merge LLM eval (U3)**: synthesizing a coherent
multi-step recipe from 5 heterogeneous variants is too cognitively heavy
for a 1.5B on-device model. Output truncates, dedup is sloppy, the merged
recipe reads like a stitched list.

Same data shape, different downstream task: **two (or three) students
studying for the same class. Each has their own notes — different
examples, different emphasis, different recall hooks. They open the app
and ask "give me 3-5 flashcards on this topic." Alone, each phone makes
cards from its own notes. When the phones meet over BLE, the same
request produces noticeably better cards because the LLM now has access
to the union of everyone's notes.**

The LLM task drops from "generate a coherent recipe" to "generate a
Q/A pair from this passage". That's well within a 1.5B model's reach.
Anki has been doing exactly this with cloud LLMs for two years — what's
novel here is the **mesh provenance** and the **learning-together
effect**: the same student, asking the same question, gets a different
(and observably *better*) study aid the moment a peer's phone joins.

## Thesis

A study group's collective notes are a CRDT. Each member's coverage is
partial; the union is more complete than any individual's. Flashcards
generated from the union surface concepts that any single person's notes
would miss. The on-device LLM is doing the work *they* would do over an
hour at the library — but provably from their own material, no cloud,
no shared Google Doc.

**The mesh isn't a sync mechanism. It's a study aid.**

## Demo moment

Two phones (Stage 1: three), both in airplane mode. Each phone holds
5–10 short notes on the same topic — pick a topic the audience knows
well enough to evaluate ("CRDT internals", "RAG architecture",
"Bluetooth mesh", etc.).

1. **Alone.** On phone A, ask "give me 5 flashcards." App returns 5
   Q/A cards drawn from phone A's notes only. Attribution footer:
   "drew on 5 notes (0 from peers)."
2. **Read a card.** The cards are pedagogically OK but you can see the
   blind spots — phone A's notes skipped X, so there's no card about X.
3. **Bring phone B into BLE range.** Mesh pill goes green.
4. **Same request, same phone.** Tap "give me 5 flashcards" again. Now
   one or two cards probe concepts that *only* phone B's notes covered.
   Attribution: "drew on 5 notes (2 from peers)."

The audience can read both phones' notes off-camera and verify: yes,
that card about X required phone B's notes. The improvement is *legible*
in the same way "answer drew on tuples from another device" was in the
recipes demo — except now the improvement is intuitive (a missing
flashcard appeared) rather than mushy (a recipe got "better").

## Schema

`StudyNote` (renames `RecipeTuple`):

```dart
{
  id: UUID,            // deterministic from (contributor, topic, createdAt)
  topic: String,       // "CRDT internals", "Bluetooth mesh", etc.
  contributor: String, // "phone-a" or "phone-b" (or real names at demo time)
  body: String,        // 1-3 paragraph note
  tags: List<String>,  // optional: ["definition", "example", "diagram"]
  embedding: List<double>,
  createdAt: DateTime,
}
```

`Flashcard` (new — runtime only, not synced; regenerable):
```dart
{ question: String, answer: String, sourceNoteIds: List<String> }
```

## What changes vs Stage 0 (file count: ~6)

| File | Change |
|---|---|
| `lib/models/recipe_tuple.dart` | → `lib/models/study_note.dart`. Rename `dish` → `topic`, `ingredients`+`steps` → `body`+`tags`. |
| `lib/prompts/recipe_merge.dart` | → `lib/prompts/flashcard_gen.dart`. New system prompt: "Given these notes, produce N flashcards as JSON. Each card must be answerable from the provided notes alone." |
| `lib/services/retrieval_service.dart` | `answerQuery` → `generateFlashcards(topic, n)`. Returns a list of `Flashcard` objects, not a streaming answer. |
| `assets/seed_recipes_*.json` | → `assets/seed_notes_*.json`. 5-8 short notes per phone on the same topic. |
| `lib/widgets/query_screen.dart` | Replace streaming answer pane with a card stack. Flip-on-tap to reveal answer. |
| `lib/prompts/dql_queries.dart` | Collection rename `recipes` → `notes`. |

What stays unchanged: BootScreen, MeshStatusWidget, Ditto/Cactus services,
flat-cosine top-k retrieval, BLE permissions, plan + spike docs structure.

## What it doesn't try to do (Stage 1+ deferrals)

- **Spaced repetition.** Flashcards don't persist; they regenerate per
  query. Stage 1 = Ditto-persisted card-review history.
- **User-attributed flashcards.** The card itself doesn't show which note
  it came from — just the aggregate count. Stage 1 = source citations.
- **Cross-topic notes.** Stage 0.5 assumes one topic per demo. Stage 1+
  could let users tag and filter.

## Why this passes the on-device LLM bar

| Task | Token budget | LLM difficulty |
|---|---|---|
| Stage 0: synthesize merged recipe | ~768 (and still hitting the cap) | hard — generative, multi-step, easy to confabulate |
| Stage 0.5/A: generate Q/A from passage | ~256 per card × 5 = 1280 in one streamed call | easy — extractive-ish, well within Qwen 2.5 1.5B's range |

Anki's flashcard-from-passage prompts run on **gemma 270M** acceptably.
We're using **1.5B with 1024-dim embeddings**. The LLM has more than
enough capacity.

## Hand-off to ce-work / ce-plan

This is a seed, not a plan. The implementer's next move depends on
appetite:

- **ce-work directly** — small enough to execute. ~6 files of changes.
  The plan is in this seed.
- **ce-plan first** — formalizes the U-IDs and verification gates if
  the implementer wants R1-style holdouts before coding.

## Sources

- Origin: hackmd Candidate A (`https://hackmd.io/4ChwPprHQBOvgi_DyWur0g`)
- Current Stage 0 plan: `docs/plans/2026-05-21-001-feat-mesh-rag-stage-0-implementation-plan.md`
- Why we're pivoting: U3 recipe-merge eval (`docs/spikes/U3-recipe-merge-eval.md`) — answer-quality was the gap, not retrieval or sync.
