# Multiplayer / "Learning Together" — brainstorm seed

**Status:** Seed for a future `/ce-ideate` or `/ce-brainstorm` session. Not a
plan. Captured 2026-05-22 right after the single-phone Jeopardy toggle landed
(see `lib/widgets/flashcards_tab.dart`, commit `qsmlrxkk`).

## The thinking-out-loud, paraphrased

The Jeopardy toggle on a single phone is already a game-like surface. Could
that scale to a multiplayer "Jeopardy Together" — somewhat like Jackbox or
Truth-or-Dare, but only loosely?

**The constraint to interrogate:** *Why do players need to be near each other
to generate a game?* If we can't answer that, the mesh-RAG substrate isn't
load-bearing for the multiplayer pitch.

Alyssa's working answer: probably best suited to **learning-style** play —
the proximity buys access to *each other's notes*. Without that, there's no
reason to be in the same room rather than playing remotely.

## Direction candidates (no commitment)

### a) Jeopardy Together (learning-style)
- Each phone carries its own corpus of personal notes (today's DittoXCactus
  capability).
- Game phase pools the corpora over the mesh; on-device LLM generates clues
  from the merged set.
- Other players race to give the correct response (gameshow phrasing or
  free-form, TBD).
- Proximity justification: "I want to play with the notes my friends have."

### b) CAH-style variant ("virtual Cards Against Humanity")
- Players either **write their own 5 cards** or get 5 dealt at random from
  the on-device generator.
- LLM-generated cards solve CAH's expansion-pack staleness — the corpus is
  always local, always fresh.
- Proximity justification: same as physical CAH — the room dynamic IS the
  game (eye contact, reaction timing).

## Open questions for a real brainstorm pass

- Audience: study group? families? adult party game?
- Corpus model: per-phone, or pooled at game-start?
- LLM role: generating from notes (learning-style) or from prompts (party-style)?
- Scoring without a central authority — how?
- Does game phase need cloud / big-peer, or is mesh self-sufficient?
- Where does the existing Jeopardy toggle sit on this spectrum (single-player
  warm-up vs. game seed)?

## What's NOT in scope here
- Anything that requires a server-side authority (game state, scoring,
  matchmaking). Pursue the mesh-self-sufficient direction first; fall back
  to cloud only if absolutely necessary.
- Mechanics borrowed wholesale from existing games. The loose analogies to
  Jackbox / Truth-or-Dare / CAH are framing devices, not blueprints.
