# Data model: Ditto RecipeTuple + seed loader

Defines the project's core data structure and persistence layer:

- RecipeTuple schema (Ditto document type)
- Idempotent CRUD wrappers (upsert by deterministic key)
- Seed loader that hydrates Ditto from assets/seed_notes_*.json

Original commit:
- toruoutv (feat(u4): Ditto RecipeTuple schema + idempotent CRUD + seed loader)

Note: this still uses the "recipe" vocabulary; the flashcard pivot comes
later (commit 9) and reuses the same tuple shape.
