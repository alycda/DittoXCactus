# ⭐ Flashcards UX: the full learner surface

The user-facing build-out of the flashcard pivot. Bundled as one ⭐ commit
because each sub-feature is small but they only make sense together —
splitting them would produce 6 commits that each say "tweaked the
flashcards UI."

What lands:
- Tabbed UI (Flashcards / Notes / Query) + Q/A flashcard format that
  survives 1.5B-parameter drift (the small-model robustness work — would
  have stood alone as ⭐ if not folded here)
- Rate mode (per-card thumbs up/down)
- Portrait orientation lock
- Few-shot saved exemplars (good ratings become future few-shot examples)
- Per-card source transparency (which note(s) produced this card)
- Chip-row overflow fix
- Selective clone of peer notes (manual fork, no automerge — the social
  learning insight: you copy a peer's note into your own corpus when you
  find it useful)
- Edit your own notes + dedup self-clones from peer section
- Reviewer-role idea (captured as a seed-a note: TA-as-peer, GitHub-style
  note suggestions for future iteration)

Original commits:
- wzqosvzy (tabbed UI + Q/A format that survives 1.5B drift)
- qvyuluys (rate mode + portrait lock + few-shot saved exemplars)
- rqqlmpzp (per-card source transparency + chip-row overflow fix)
- rvxvxvqk (selective clone of peer notes — manual fork)
- vormwuzl (reviewer-role idea captured)
- xyszqpyx (edit own notes + dedup self-clones)
