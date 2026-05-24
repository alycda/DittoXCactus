# `assets/` — Stage 0 seed corpus

Two JSON files, one per phone-role, that the app preloads at boot. Each
phone runs with `PHONE_ROLE=a` or `PHONE_ROLE=b` and `SeedLoader` reads
only the matching file ([plan U8](../_docs/plans/001-feat-mesh-rag-demo.md#u8-seed-insert--late-embedding-backfill-two-phase-corpus-preload)).

| File | Role | Topical coverage | Count |
|---|---|---|---|
| [`seed_notes_a.json`](seed_notes_a.json) | `phone-a` | The Sun + inner solar system (Mercury, Venus, Earth's Moon, Mars) | 5 |
| [`seed_notes_b.json`](seed_notes_b.json) | `phone-b` | Outer solar system (Jupiter, Saturn, Uranus, Neptune) + Pluto | 5 |

**Post-sync corpus:** 10 distinct notes.

## Schema

Each entry is a flat object:

```json
{
  "topic":       "Mars",
  "contributor": "phone-a",
  "createdAt":   "2026-05-22T19:31:00.000Z",
  "tags":        ["inner-planet", "olympus-mons", "valles-marineris"],
  "body":        "Mars has the largest volcano…"
}
```

There is no `_id` field on disk. The application derives `_id` at load
time as `UUIDv5('<contributor>|<topic>|<createdAt-iso8601>')`, which
makes re-running the seed loader an idempotent UPSERT (same input →
same id; Ditto's `ON ID CONFLICT DO UPDATE` finishes the job).

There is no `embedding` field on disk either. Embeddings are filled in
post-boot by `RetrievalService.ensureEmbeddings` once the Cactus model
has loaded (plan §U8).

## Why this corpus

Per [U2's thesis-framing pick](../_docs/thesis-framings.md), the demo's
headline is "Knowledge composes when devices meet — Bluetooth pairing
for ideas." Audience-submitted study notes from a study group is the
corpus that embodies the metaphor at demo time: two classmates'
notebooks, briefly mesh-syncing, leave with combined understanding
neither had alone.

## The split is contrived

The clean inner-vs-outer partition is **staged for visualization**, not
realistic. In an actual audience-submitted study group, notes would
overlap heavily — two students might both have something on Mars or
both reference Jupiter's moons.

Why we contrived it: R1's "moment of magic" needs an obvious before/after.
"Ask about Jupiter's moons on phone A → no hit; airplane mode + BLE
meet → ask again → answer with citations from phone B" is camera-legible
only if the corpora are visibly disjoint. If they overlapped, the
mesh-merge value would still be there mathematically but illegible to
the audience.

**Demo writeup must acknowledge this.** The clean separation is stage
theatre, not a thesis claim. Real-world mesh-RAG corpora converge — that's
why the future-work arc points at preference-aware merge (thread 2) and
adversarial filtering (thread 3): in the realistic case you DO need to
reconcile, not just union.

## Disjoint-by-design property (for R1)

At least 10 R1-style queries land on exactly one device. Selected
disjoint queries:

**A-only (zero hits in B alone, ≥1 hit post-sync):**
- "Which planet is hottest in the solar system?" → Venus (A3)
- "What is the largest volcano in the solar system?" → Olympus Mons (A5)
- "What is the giant-impact hypothesis?" → Moon (A4)
- "How long is a year on Mercury?" → Mercury (A2)
- "What fraction of the solar system's mass is the Sun?" → Sun (A1)

**B-only (zero hits in A alone, ≥1 hit post-sync):**
- "What are the Galilean moons?" → Jupiter (B1)
- "What are Saturn's rings made of?" → Saturn (B2)
- "Which planet rotates on its side?" → Uranus (B3)
- "Which planet has the strongest winds?" → Neptune (B4)
- "Why isn't Pluto a planet anymore?" → Pluto (B5)

The formal query → expected-source mapping for the R6a rehearsal set is
captured in [`_docs/rehearsed-queries.md`](../_docs/rehearsed-queries.md)
once U16 lands.

## Anti-hallucination requirement (forward-looking, for U11)

The Stage 1 flashcard generator must constrain output to retrieved-note
content. Audience members and demonstrators have priors about the solar
system; a fabricated planet fact would be immediately detectable and
embarrassing. Prompt design (U11's `FlashcardGenPrompt`) and parser
(`Q:/A:/SOURCE:` validation) must enforce grounding: if the retrieved
notes don't support an answer, the cards say so rather than confabulate.
See user-memory `feedback_llm_grounding.md` for the full constraint.
