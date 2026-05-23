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

---

## Update — 2026-05-22: a real answer to "why be near each other?"

(Keeping this as an appended section, not a rewrite. The framing
evolution is the artifact.)

### c) Trivia / Jeopardy night at a bar (indirect socializing)

Alyssa's framing: *"could be a bar game, like trivia night / jeopardy
night where socializing is indirect. whoever wins each round by vote
wins small bar prizes, free appetizer, $5 credit, free dessert?"*

This is the first candidate that gives the proximity constraint a
genuine answer. Players are NOT playing AT each other (Jackbox model);
they're playing parallel-to each other in a shared physical room
(trivia-night model). The room is the context, not the medium.

**What proximity buys here:**

- **Material prizes.** A free appetizer, $5 bar credit, or free dessert
  needs the venue to physically hand it over. Remote play can't
  replicate it. The reward is the proximity.
- **Room-as-judge.** Per-round winners by audience vote — only works
  with the room present. The mesh can collect votes from every phone
  in range; the bartender doesn't need a stack of paper.
- **Existing cultural slot.** Trivia / Jeopardy nights are already a
  thing. People know how to walk into them. We're slotting into a
  familiar format, not inventing one.
- **Indirect socialization > direct play.** Important distinction from
  Jackbox / CAH: at a bar trivia night you're not interacting with
  every other player; you're interacting with your table while a shared
  game runs in parallel. That's a much lower social-friction entry
  point — strangers, dates, regulars, study buddies all work.

**What the mesh substrate uniquely enables:**

- No infrastructure cost for the venue. Bartender's phone as an
  optional admin node, every player phone is a peer.
- Local content. The bar's "house corpus" (sports stats, music trivia,
  the venue's own lore) lives on the bartender's phone and syncs to
  players who walk in.
- Offline-OK by default. Bar wifi flakes; mesh works regardless.

**Open questions specific to this direction:**

- Is the bar a paying customer (subscription), an organic adopter
  (free + content marketing), or a partnership channel (e.g. content
  packs sold to bar chains)?
- Does the corpus come from the venue, the players, or both? Mixed
  corpora are technically trivial but raise content-moderation
  questions (NSFW player notes in a public room).
- How does the bartender award the prize without breaking the mesh
  abstraction? Probably: bartender's phone shows the round winner;
  bartender walks over and hands them the appetizer. Boring but
  reliable.
- Round cadence: trivia nights are typically 60-90 min, 4-6 rounds.
  Each round needs to generate and resolve in <10 min including the
  Jeopardy-style think-time. With qwen3-1.7 at current decode speed
  that's tight but plausible — worth measuring before committing to
  the venue-game pitch.

**Why this direction probably wins over (a) and (b):**

- (a) Jeopardy Together for learning is a niche audience. Bar trivia
  is mass-market.
- (b) CAH-style has content-moderation liability the venue won't want;
  the bar isn't going to take on adjudicating raunchy player cards.
- (c) Trivia night has a 30-year cultural template the demo can slot
  into without re-educating the audience.

But all three are still seeds. The right move is a `/ce-brainstorm`
pass that interrogates assumptions across all three before picking.
