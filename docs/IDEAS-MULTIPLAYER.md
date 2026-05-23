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

---

## Update — 2026-05-22 (later same day): bar Clue / social deduction

(Still appending, still not rewriting. Evolution visible.)

### d) Bar Clue (mesh-private hand deduction)

Alyssa's framing: *"another idea, bar Clue. you 'sign up' when you walk
in the door (qr code or something) and your phone has some clues that
you can decide to share? i don't really know the game clue that well
but i think there's an idea here."*

The intuition is correct: Clue's mechanic and a mesh substrate are
nearly isomorphic.

**How Clue actually works (for reference):**

- A scenario is sealed — typically "who killed Mr. Boddy, with what
  weapon, in what room?" — and that sealed answer is the goal.
- The remaining suspect/weapon/room cards are dealt as private hands
  to each player. Every player holds a subset; the union of hands
  excludes the answer cards (by construction).
- Players move around the board making **suggestions** ("I think
  Colonel Mustard in the library with the candlestick"). Other players
  who hold *any* of those cards must privately show *one* to the
  suggester. The room sees that a card was shown, but not which one.
- Deduction unfolds across rounds. The first player to make a correct
  **accusation** wins; a wrong accusation eliminates them.

**Mapping board Clue → mesh substrate:**

| Board Clue                           | Mesh equivalent                              |
| ------------------------------------ | -------------------------------------------- |
| Player's hand of cards               | Encrypted local state on phone               |
| Showing one card to one other player | BLE point-to-point reveal (private channel)  |
| Walking around the board             | Walking around the bar physically            |
| Murder + weapon + location cards     | LLM-generated cast: regulars, drinks, spots in the bar |
| Sealed case file                     | Commit-then-reveal value all phones can verify but none can read until accusation |
| Correct-accuser wins                 | Free drink / appetizer for the deducer       |

**Why this is the most mesh-load-bearing direction yet:**

The other three directions (Jeopardy-Together, CAH-style, trivia night)
use the mesh as a *convenience* — they could work, awkwardly, with
WiFi + a server. Clue's mechanic is *fundamentally* about selective
private reveals to specific other players. Take the proximity away and
you take the game away. That's the strongest "why must players be near
each other?" answer in this document.

**Bar-specific framings the user gestured at:**

- **QR-on-the-door onboarding.** Scan when you walk in, get dealt a
  hand, you're in. No app pre-install needed if the QR launches the
  PWA / app store flow. New players can join an in-progress game.
- **"clues you can decide to share."** This IS Clue's mechanic — the
  player chooses which card to reveal in response to a suggestion.
  Bluffing, withholding, strategic reveals — all in-person dynamics.

**What the LLM uniquely buys here (vs. board Clue):**

- **Fresh scenarios every night.** Board Clue has six suspects, six
  weapons, nine rooms — it gets old. An LLM generating the cast from
  the bar's house corpus (regulars, drinks, named seats, this week's
  events) means tonight's mystery has never been played before.
- **Topical variants.** Halloween night: ghost stories. Sports night:
  who broke the trophy case? St. Patrick's Day: who drank the lucky pint?
  Same mechanic, fresh scaffold.
- **Adaptive difficulty.** First-time players get smaller hands and
  more obvious cards; regulars get tighter information. The LLM can
  generate distractor cards calibrated to the table.

**Open questions specific to this direction:**

- **Game length.** Board Clue is 30-60 min. Bar Clue probably wants 15-
  30 min so it fits a drink cycle. Round structure TBD.
- **Game master.** Is the bartender's phone a non-player observer
  (verifies the accusation, dispenses prizes)? Or fully decentralized
  (every phone holds a shard of the sealed answer)?
- **Drop-in / drop-out.** Bars are open all night and people come and
  go. Does a single mystery run all night with rolling players, or do
  short matches reset every 20 min?
- **Cheat resistance.** Phones are private but the player isn't —
  someone could walk to the bathroom and screenshot their hand to a
  friend. Probably not a problem at the "free appetizer" stakes level,
  but worth flagging.
- **Liability for bartender.** If the LLM generates a scenario that
  implicates a real regular ("Brenda was in the bathroom with the
  knife"), does the bar want that? Probably needs corpus curation /
  a "fictional-cast" toggle.

**Ranking against the other directions:**

- (a) Jeopardy-Together (learning): niche audience.
- (b) CAH-style: content moderation liability for the venue.
- (c) Trivia night: cleanest cultural slot, but mesh is a convenience
  not a necessity.
- (d) Bar Clue: **mesh is the entire point of the mechanic.** Strongest
  technical fit and most novel game proposition. Slightly higher design
  burden (a Clue-like format isn't as well-known as trivia night), but
  could be the differentiator.

Probably bumps to the new lead, displacing (c). Both still seeds —
the `/ce-brainstorm` pass should interrogate (c) vs (d) on
adoptability vs. defensibility.
