# Speaker notes — Mesh RAG, Stage 0

Target runtime: ~10 minutes plus 5 minutes Q&A.

## Slide 1 — Title + thesis (~45 s)

- Open by holding both phones in the air. Airplane-mode icon visible.
- "Two phones. Airplane mode. They meet over Bluetooth. The vector index merges.
  The answer changes on camera."
- Beat. Then: "That's the whole show. The rest is why it matters."

## Slide 2 — The problem with cloud RAG (~90 s)

- Don't sell *cost* — the SEED chose the *latency + offline-first* framing on
  purpose. Cost is a derived effect, not the durable property.
- Walk the math: physics gives you a floor cloud-RAG cannot beat. On-device
  has no such floor.
- Land it on: "Cloud RAG cannot get faster than light. On-device can."

## Slide 3 — The CRDT insight (~90 s)

- The pivot is: the *vector index* itself is the CRDT, not just the document
  store under it.
- Stress the "no HNSW under concurrent inserts" line — it's the technical
  payoff. Mention but don't dwell on Tschudin's G-Set work + arXiv 2407.07871
  if pressed in Q&A.

## Slide 4 — Architecture (~120 s)

- Walk the sequence top-to-bottom. Two beats: the "alone" path on the left,
  the "after handshake" path on the right.
- Cactus narrow: the audience may know Cactus has its own RAG primitives.
  Explain *why* we don't use them — Cactus would want to own persistence and
  would fight Ditto's CRDT-merged tuple set.
- 7.7 MB number is memorable. Use it.

## Slide 5 — Live demo (~120 s)

- This is the moment of magic. Slow down. Let the BLE handshake breathe.
- If BLE flakes for > 10 s, cut to B-roll *without* breaking eye contact.
  Pre-rehearsed line: "you can see the same thing in our recorded take."
- Point at the **mesh pill** going green at the moment the answer changes.

## Slide 6 — Scope honesty (~60 s)

- Lead with what we *are*. Audiences appreciate honesty on what we aren't.
- Stage 1 (audience participation) and Stage 2 (real corpora) signal there's
  a path beyond the demo without making promises.

## Slide 7 — Four-thread arc (~120 s)

- This is the writeup hook. Don't promise we've done any of it.
- The thesis arc is: today's demo uses a *generalist* on-device because that's
  what the off-the-shelf ecosystem ships. The destination is **specialists**:
  per-peer fine-tuned small models that each handle a narrow slice of the
  corpus.
- Pause on adversarial filtering — that's the most novel research thread. The
  insight: "CRDT-shaped trust" (signed witnesses, reputation in the document
  itself) is unexplored.

## Slide 8 — Q&A (~60 s + open)

- Surface the plan path so the audience can read after.
- If asked about Ditto licensing: it's a commercial SDK with a free
  development tier; we used it under the hackathon terms.
- If asked about Llama: explain why we deliberately picked Qwen (Apache-2.0)
  over Llama (Community License + attribution).
- If asked about iOS background BLE: known constraint, environmental, not
  user-app-solvable. Briar has no iOS app for the same reason.
