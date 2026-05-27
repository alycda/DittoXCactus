<!--
DRAFT — GitHub Discussion, category: Ideas
Repo: alycda/DittoXCactus
Source: spike branch, three commits (kspyropu, ksuxslln, lzykrwkv) appending to docs/IDEAS-MULTIPLAYER.md
Source file: docs/IDEAS-MULTIPLAYER.md (235 lines)

Pre-post checklist:
- [x] Source branch `spike` is on origin
- [ ] Strip this HTML preamble before posting
- [ ] Title: "Multiplayer mesh-RAG: from Jeopardy Together to bar Clue"
- [ ] Category id: DIC_kwDOSlRUbc4C9qmY (Ideas)
-->

# Multiplayer mesh-RAG: from Jeopardy Together to bar Clue

Pulling forward another dangling spike — three commits on the `spike`
branch ([`docs/IDEAS-MULTIPLAYER.md`](https://github.com/alycda/DittoXCactus/blob/spike/docs/IDEAS-MULTIPLAYER.md))
that grew an idea across appends rather than rewrites. Posting as an Idea
discussion so the framing-evolution arc — and the question it kept
circling — is visible outside a branch nobody's looking at.

**The question that won't go away:** *Why do players have to be near each
other to generate a game?* If we can't answer that, the mesh-RAG
substrate isn't load-bearing for the multiplayer pitch — players would
be better off on a server with WiFi. The four candidates below are an
honest evolution of trying, failing, and refining that answer.

## Where it started: Jeopardy Together (and CAH)

The Jeopardy toggle on the existing single-phone demo
([`lib/widgets/flashcards_tab.dart`](https://github.com/alycda/DittoXCactus/blob/main/lib/widgets/flashcards_tab.dart))
is already a game-like surface. The first instinct was to scale that into
something Jackbox-shaped:

### (a) Jeopardy Together (learning-style)

- Each phone carries its own personal-notes corpus (today's capability).
- Game phase pools the corpora over the mesh; the on-device LLM
  generates clues from the merged set.
- Other players race to give the correct response.
- **Proximity justification:** "I want to play with the notes my friends
  have." Audience: study groups, classes, book clubs.

### (b) CAH-style ("virtual Cards Against Humanity")

- Players either write their own 5 cards or get 5 dealt from the
  on-device generator.
- LLM-generated cards solve CAH's expansion-pack staleness — the corpus
  is always local, always fresh.
- **Proximity justification:** same as physical CAH — the room dynamic
  IS the game (eye contact, reaction timing).

Honest assessment: (a) is niche-audience, (b) has content-moderation
liability for any commercial venue. Neither answers "why be near each
other?" with much force — both could work, awkwardly, with WiFi + a
server.

## The first real answer: trivia night at a bar

### (c) Bar trivia / Jeopardy night (indirect socializing)

> "could be a bar game, like trivia night / jeopardy night where
> socializing is indirect. whoever wins each round by vote wins small
> bar prizes — free appetizer, $5 credit, free dessert?"

This is the first candidate that gives the proximity constraint a
genuine answer. Players are NOT playing *at* each other (Jackbox
model); they're playing *parallel-to* each other in a shared physical
room (trivia-night model). The room is the context, not the medium.

**What proximity buys here:**

- **Material prizes.** A free appetizer, $5 bar credit, free dessert —
  needs the venue to physically hand it over. Remote play can't
  replicate it. *The reward is the proximity.*
- **Room-as-judge.** Per-round winners by audience vote — only works
  with the room present. The mesh collects votes from every phone in
  range; the bartender doesn't need a stack of paper.
- **Existing cultural slot.** Trivia / Jeopardy nights are already a
  thing. People know how to walk into them. Slotting into a familiar
  format, not inventing one.
- **Indirect socialization > direct play.** Important distinction from
  Jackbox / CAH: at a bar trivia night you're not interacting with
  every other player; you're interacting with your table while a
  shared game runs in parallel. Much lower social-friction entry —
  strangers, dates, regulars, study buddies all work.

**What the mesh substrate uniquely enables:**

- No venue infrastructure. Bartender's phone as optional admin node;
  every player phone is a peer.
- Local content. The bar's "house corpus" (sports stats, music
  trivia, the venue's own lore) lives on the bartender's phone and
  syncs to players who walk in.
- Offline-OK by default. Bar Wi-Fi flakes; mesh works regardless.

**The honest caveat for (c):** the mesh is a *convenience* here, not a
necessity. A bar with reliable Wi-Fi and a Kahoot subscription is
already running this format. The mesh-RAG substrate makes the venue
side cheaper and more reliable, but doesn't change what the game IS.

## The strongest answer yet: bar Clue

### (d) Bar Clue (mesh-private hand deduction)

> "another idea, bar Clue. you 'sign up' when you walk in the door (qr
> code or something) and your phone has some clues that you can decide
> to share? i don't really know the game clue that well but i think
> there's an idea here."

The intuition is right: Clue's mechanic and a mesh substrate are
nearly isomorphic.

**Mapping board Clue → mesh substrate:**

| Board Clue                           | Mesh equivalent                              |
| ------------------------------------ | -------------------------------------------- |
| Player's hand of cards               | Encrypted local state on phone               |
| Showing one card to one other player | BLE point-to-point reveal (private channel)  |
| Walking around the board             | Walking around the bar physically            |
| Murder + weapon + location cards     | LLM-generated cast: regulars, drinks, spots in the bar |
| Sealed case file                     | Commit-then-reveal value all phones can verify but none can read until accusation |
| Correct accusation wins              | Free drink / appetizer for the deducer       |

**Why this is the most mesh-load-bearing direction yet.** Candidates
(a)–(c) use the mesh as a *convenience* — they could work, awkwardly,
with WiFi + a server. Clue's mechanic is *fundamentally* about
selective private reveals to specific other players. Take the
proximity away and you take the game away. **That's the strongest
answer to "why must players be near each other?" in this whole
document.**

**What the LLM uniquely buys here (vs. board Clue):**

- **Fresh scenarios every night.** Board Clue has six suspects, six
  weapons, nine rooms. It gets old. An LLM generating the cast from
  the bar's house corpus (regulars, drinks, named seats, this week's
  events) means tonight's mystery has never been played before.
- **Topical variants.** Halloween night: ghost stories. Sports night:
  who broke the trophy case? St. Patrick's Day: who drank the lucky
  pint? Same mechanic, fresh scaffold.
- **Adaptive difficulty.** First-time players get smaller hands and
  more obvious cards; regulars get tighter information. The LLM
  generates distractor cards calibrated to the table.

**Bar-specific framings worth lingering on:**

- **QR-on-the-door onboarding.** Scan when you walk in, get dealt a
  hand, you're in. No app pre-install if the QR launches the PWA / app
  store flow. New players can join an in-progress game.
- **"Clues you can decide to share."** This IS Clue's mechanic — the
  player chooses which card to reveal in response to a suggestion.
  Bluffing, withholding, strategic reveals — all in-person dynamics.

## How I'd rank them

| Direction | Mesh is... | Audience | Risk |
| --- | --- | --- | --- |
| (a) Jeopardy-Together (learning) | a convenience | niche (study groups, classes) | LLM clue quality |
| (b) CAH-style | a convenience | adult party game | content-moderation liability for venues |
| (c) Bar trivia / Jeopardy night | a convenience | mass-market, slots into existing trivia-night culture | undifferentiated vs Kahoot + Wi-Fi |
| **(d) Bar Clue** | **the entire point** | adult social-deduction crowd | higher design burden (less familiar format) |

(d) probably leads. (c) is the safe slot-into-existing-culture play. Both
are still seeds — a proper `/ce-brainstorm` pass should interrogate
(c) vs. (d) on **adoptability vs. defensibility** before picking.

## Open questions I'd want a real brainstorm to take on

For all directions:

- Audience: study group? families? adult party game? bar regulars?
- Corpus model: per-phone, or pooled at game-start?
- LLM role: generating from notes (learning-style) or from prompts (party-style)?
- Scoring without a central authority — how?
- Does game phase need cloud / big-peer, or is mesh self-sufficient?

For (c) / (d) specifically:

- Is the bar a paying customer (subscription), organic adopter (free +
  content marketing), or a partnership channel (content packs sold to
  bar chains)?
- Does the corpus come from the venue, the players, or both? Mixed
  corpora are technically trivial but raise content-moderation questions
  (NSFW player notes in a public room).
- Drop-in / drop-out at a bar — single mystery runs all night with
  rolling players, or short matches reset every 20 min?
- Cheat resistance — phones are private but the player isn't. Someone
  could screenshot their hand. Probably not a problem at the
  free-appetizer-stakes level, but worth flagging.
- Liability for the bartender if the LLM implicates a real regular
  ("Brenda was in the bathroom with the knife"). Needs corpus curation
  or a "fictional-cast" toggle.

## What I want feedback on

- **The "why proximity?" test as a filter for game ideas.** Does it
  actually discriminate between mesh-load-bearing and mesh-as-decor
  designs, or am I leaning on it as a crutch?
- **The (c) vs (d) split.** Trivia night is *familiar*; bar Clue is
  *unique*. Which is the right risk profile for an
  early-on-device-mesh-LLM product?
- **The Clue ⇄ mesh mapping.** I think it's nearly isomorphic. Anyone
  who knows Clue deeply — does the mapping break anywhere?
- **The bar as a venue, more broadly.** Are there other "everyone in a
  shared physical context, no cloud assumed" frames I'm missing? Music
  venues, gyms, coffee shops, conferences, hotels?

## Source

Three commits on branch
[`spike`](https://github.com/alycda/DittoXCactus/blob/spike/docs/IDEAS-MULTIPLAYER.md),
appended over a single afternoon — the file's evolution is the artifact.
Not merged to main; not built. The Jeopardy *toggle* (single-phone) IS
shipped in the demo. Everything else is here so someone (maybe future
me) can pick it up.
