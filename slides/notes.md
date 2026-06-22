# Speaker notes — *Your knowledge base wants to be a CRDT*

Parallel to [`deck.md`](deck.md). One block per slide. Stage directions in
`(parens)`. Target: ~10 minutes, comfortable pacing. The motorcycle joke buys
me permission to talk fast; don't spend it twice.

> Voice reminders to self: self-deprecating open, breaking-things framing,
> name the trade-off out loud, land the closing line and *stop* — descending
> intonation, then a beat of silence so the room knows it can clap. Don't trail
> off into "…so yeah, that's basically it."

---

## Slide 1 — Opener

*(Walk on. Don't rush the first line — let "or breaking things on the internet"
land. It's true and it's the whole brand.)*

"Hi, I'm Alyssa. I've been writing code for almost 20 years — or breaking
things on the internet, depending how you look at it."

*(Pause.)* Set the credential lightly: staff engineer at Ditto, the Rust core
behind every SDK over C FFI — **that's the day job, not this talk.** I joined
Ditto last year and I've been learning CRDTs in public, and this is me failing
in public at the edge of that.

*(The dark-factory confession — say it plainly; it earns trust AND sets up the
thesis.)* "I'll be honest about how this got made — I didn't hand-write most of
it. An agent loop did, and wrote the tests too. I was the human in the loop for
the one thing a cloud loop can't fake: two real phones, real Bluetooth, in the
same room." *(Beat.)* "Which is the whole thesis — you can't simulate physical
proximity. So here I am, holding two phones." _(Issue #3 is the "why I'm still
the device lab" detail — only say the number if someone asks.)_

*(Wait for the bullet — the one sentence.)* Read it slowly: "Two phones meet,
their knowledge composes, and neither touched the cloud." **No apologies** — I
don't open with "it's just a hackathon build" or "the model is small." The
small on-device model *is* the thesis, not a caveat.

*(The motorcycle bit — this is the disarm. Deliver it fast, on purpose, then
slow down.)* "I race motorcycles, I have a need for speed, so if I start
talking too fast, sorry in advance." The presenterm aside is optional; use it
only if the terminal aesthetic gets a look from the room. *(Transition: "So why
not just use cloud RAG?")*

---

## Slide 2 — The problem with cloud RAG

Anti-dogma framing — I'm **not** here to dunk on cloud RAG. It's great; I'd ship
it for most things. The point is *context, not purity*: there are three
specific places it can't follow you.

*(Reveal the three one at a time. Point at #2 — "offline-impossible" — and make
it concrete and real: "a conference where the wifi has buckled under 300
laptops, and the note you need is on the machine of the person sitting next to
you. The cloud is the long way around a two-foot gap." This is the actual use
case I want to test on real bad-network data next.)*

Don't belabor #3 (privacy). Name it, move on — the room already feels it.
*(Transition: "Let me make #1 numerical, because that's the one people fight
me on.")*

---

## Slide 3 — The latency-floor argument

This is the "measure, don't assume" slide — my favorite kind. *(Point to the
table.)*

The honest beat is load-bearing here, so say it out loud and own it: on-device
*generation* is slower per token than a datacenter GPU — **of course it is.**
*(This is the parenthetical-honesty move; if I skip it, a skeptic in row two
stops trusting the rest of the deck.)*

Then the turn: tokens-per-second is the number you *can* optimize and everyone
does. The round trip is the number you **can't**. On-device, there isn't one.
That's not a speed claim, it's a topology claim. *(Cite MELTing Point only if
someone asks for the receipt — `paper-2403.12844`. Don't read paper IDs aloud.)*

*(Transition: "Okay — so on-device is defensible. Why does the *mesh* part fall
out for free? Because of the shape of the data.")*

---

## Slide 4 — The CRDT insight

The "name the math" slide. Don't hand-wave it — this is the intellectual core
and the reason the talk exists.

*(Point to the `topK(A ∪ B) == topK(B ∪ A)` line.)* Walk the three words:
associative, commutative, idempotent. Each one maps to a thing you *don't* have
to do: no ordering, no coordination, no dedupe logic. "Conflict-free" means you
deleted the conflict-resolution code, not that you wrote it well.

*(Point to code — the `StudyNote` block.)* Flag the load-bearing fields:
`embedding` (same model every device, or none of this works — that's slide 7's
caveat foreshadowed) and `contributor` (this is what powers the "from peers"
footer in the demo). *(Shapiro et al. — `paper-1106.4374` — only if asked.)*

*(Transition: "So what does that look like wired together?")*

---

## Slide 5 — Architecture

*(Let the ASCII diagram sit for a second before talking. It's deliberately
terminal-first — do more with less.)*

Three layers, bottom-up: Cactus at the leaves does both embed and generate;
Ditto in the middle syncs notes **and embeddings** as the G-Set; BLE/LAN at the
bottom, WAN off. The "FFI all the way down" aside is genuine, not a flex — the
Flutter SDK in this app is a thin Dart layer over the same Rust core I work on.

The **six structural gates** line is where I'm transparent about how the
sausage is made: each gate exists because a 1.7B model did something
predictable-in-hindsight on a real phone — drifted into Mandarin mid-`<think>`,
boxed an answer in LaTeX, padded off-topic cards when retrieval was thin. The
lesson, said plainly: **fix the input to the model, don't bolt a detector onto
the output stream.**

*(AI-transparency aside — lean in, this is the honest part:)* "I keep saying 'I
built this' — I mean I *directed* it. An agent loop wrote most of the code and
the tests; I reviewed, corrected, and ran it on real hardware. The parts I
couldn't hand off are exactly the parts a cloud loop can't reach yet — two
phones, real Bluetooth, same room (issue #3). I'm the device lab until that's
automated." *(Transition: "Enough architecture. Watch it happen.")*

---

## Slide 6 — Live demo

*(This is the 90 seconds the whole talk is built around. If live, narrate
beat 1 while the stream runs — Pixel debug is ~30–60s, don't apologize for it,
fill it. If it's the recording, still narrate over it.)*

Beat 1: read the footer aloud — "drew on N notes, **zero from peers**." That
zero is the load-bearing pre-meet signal. *(Pause for effect.)*

Beat 2 is the money shot. **Do not talk over the green flip.** Move B into
range, point at the pill, shut up, let the room watch `alone` → `1 peer` and the
notes stream in. *(Hold ~2 seconds — sync needs it, and so does the audience.)*

Beat 3: regenerate, read it out — "drew on five notes, **three from a peer**,"
and point at the `phone-b` source chip. Then the line: "Same question, bigger
corpus — the only thing that changed is another phone walked into the room."

*(If the pill stays gray: stop the take, fall back to LAN — still offline, a
hotspot with no internet. If that fails too, it's the rehearsal B-roll *with*
on-camera disclosure. Never fake the state change silently.)*

---

## Slide 7 — What this is, and what it isn't

The integrity slide — and now it's a *win*, not a confession. *(Slow down.)*

The determinism arc is the whole "measure, don't assume" ethic in one story:
"Cross-platform, the embeddings drifted — 17 of 20, 0.85. I didn't wave it off
as good-enough. I dug in: the chat-tuned model was the problem. Swapped to the
dedicated similarity-tuned embedder — `qwen3-0.6-embed` — re-measured: 20 of 20,
1.0000. Then locked the baseline so the next regression fails CI before it ever
reaches a phone." *(This is the competitive streak pointed at the right target:
I like winning, and the win was refusing to round 0.85 up.)*

Then the genuine isn'ts, fast: threat model wide open (no auth, no signatures,
no ACL — anyone in range is trusted). A small generalist can't merge recipes — I
tried; it can't — which is why the demo is space facts and why slide 8's answer
is *specialists*. Stage 2 (ingest arbitrary files) is a non-goal.

*(Land it:)* "Nothing is wasted when you document the messy middle." *(Pause —
this is the value, not a throwaway. Transition up, not down:)* "And the messy
middle is where the interesting work is."

---

## Slide 8 — Where this goes — four threads

The arc that makes a weekend build feel like a research direction. Keep the
four threads crisp — one sentence each, don't editorialize mid-list:
**specialists → preference-aware merge → adversarial filtering → generational
evolution.** *(Lift verbatim; this structure is load-bearing for the writeup.)*

Thread 1 has a receipt: the *original* corpus was recipes, and a small
generalist genuinely can't merge them coherently — I validated that, then
switched the demo to space facts. Don't bury that as a failure; it's the
evidence *for* specialists. "The mesh doesn't want a bigger generalist. It wants
a sous-chef model that only knows soup."

The avocado example on thread 2 always gets a laugh — use it, it makes
"preference-weighted retrieval over a grow-only CRDT" land without the jargon.

*(Pause for effect before the close. This is the one to land.)* "Family recipes
— written down, passed through generations, quietly mutating along the way, and
still recognizably ours even though almost nothing is exactly what grandma
wrote." *(Beat.)* "The vector index isn't just a CRDT. It's a culture."

*(Descending intonation. Stop. Let them clap.)*

---

## Slide 9 — Contact / call to action

*(Don't add words after the close landed — let the QR do the work; that's why
it's on the frame.)* One actionable thing: "The corpora are in `assets/`, the
repo's on screen — clone it, pair your own two phones, and fail in public with
me."

*(For Q&A — likely incoming, with honest answers ready:)*
- **"Why not just sync to the cloud when you have signal?"** → You can. The
  claim isn't "never use the cloud," it's "composition between proximate
  devices is a topology the cloud can't copy — the dissolution when they leave
  range *is* the point."
- **"Wasn't cross-platform determinism only 0.85?"** → It was — with the
  chat-tuned embedder. Diagnosed and fixed: dedicated similarity-tuned slug,
  now 20/20, 1.0000, with a locked CI baseline. The residual question is
  heterogeneity *at scale* — more SoCs, more models — and that's what threads 2
  and 3 (preference-aware + adversarial merge) are there to absorb.
- **"Did you really build this in a weekend?"** → I *directed* it in a weekend.
  It's a dark factory — agents wrote most of the code and the tests; I reviewed
  and tested on real devices. The four threads aren't built; they're the
  direction this points. *(I like winning, but I like being honest about scope
  more.)*
- **"Is this a Ditto product?"** → No — personal build. Ditto's the day job;
  this is me learning its problem space out loud.
