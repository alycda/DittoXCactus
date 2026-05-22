# ⭐ Pivot: recipes → flashcards

The conceptual turning point. The original SEED was framed around "recipes"
as the unit of P2P-synced knowledge; this commit reframes the same machinery
around "flashcards from study notes" — a more compelling demo domain that
also exposes the small-model drift problem in a clearer way.

What changes:
- SEED-A.md updated: stage-0.5 framing as "Learning Together — flashcards
  that improve with each new student"
- StudyNote model added (reuses RecipeTuple shape under the hood)
- assets/seed_notes_*.json replace the recipe seed corpus

Original commits:
- smoqxltx (seed(stage-0.5/a): Learning Together flashcards framing)
- vkvqyuyo (feat(seed-a): pivot recipes → flashcards from study notes)
- zvywsroo (no-description intermediate; collapsed into pivot)

Marked ⭐ because pivots are the moments most worth documenting in history —
they're the decisions that made the demo land.
