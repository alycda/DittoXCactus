---
title: Your knowledge base wants to be a CRDT
sub_title: "Mesh RAG: two phones meet, their knowledge composes, and neither touched the cloud"
author: "Alyssa Evans — Staff Engineer @ Ditto · @She's Fast"
theme:
  name: catppuccin-mocha
options:
  implicit_slide_ends: false
---

Hi — I'm Alyssa.

I've been writing code for almost 20 years. Or breaking things on the
internet, depending how you look at it.

<!-- pause -->

Day job: I'm a staff engineer at **Ditto**. Our whole thing is a **Rust core
exposed over C FFI** to a dozen platform SDKs — that's the part I work on. I
joined late last year and I've been learning **CRDTs in public** ever since.

<!-- pause -->

This is a weekend build pairing Ditto with **Cactus** (on-device LLM). And I'll
be honest about how it got made: it's a **dark factory** — an agent loop wrote
most of the code *and* the tests. I was the human in the loop for the one thing
a cloud loop can't fake yet — **two real phones meeting over Bluetooth**
(issue #3). Which, it turns out, *is* the whole thesis:

# Two phones meet, their knowledge composes, and neither touched the cloud.

<!-- pause -->

> You can't simulate physical proximity. So here I am, holding two phones.
> _(Need-for-speed warning: I race motorcycles. If I talk too fast, sorry in
> advance. And yes — this deck is just markdown in my terminal: `presenterm`.
> I liked it enough to send them a PR. Do more with less.)_

<!-- end_slide -->

# The problem with cloud RAG

Cloud retrieval-augmented generation is great. Until it isn't.

When you ask, **your query and your corpus both leave the building** and go
sit on someone else's server. That buys you three failure modes:

<!-- pause -->

1. **A latency floor you can't engineer past** — the network round trip is
   physics, not a profiling problem.

<!-- pause -->

2. **Offline-impossible** — no signal, no answer. You're at a conference, the
   wifi is garbage, and the note you need is on the laptop of the person next to
   you. The cloud is the long way around a two-foot gap.

<!-- pause -->

3. **Your corpus routes through a third party** — every note, every query,
   logged somewhere you don't own.

This demo avoids all three by never leaving the device. Let me show the math
on the first one, because that's the one people argue with.

<!-- end_slide -->

# The latency-floor argument

Measure, don't assume. Big-O lies; benchmark the actual data. So — actual
data:

<!-- pause -->

| Path | Cost | Can you optimize it? |
|---|---|---|
| Cloud round trip (WAN RTT) | **≥ ~200 ms floor** | No — that's routing + lightspeed |
| On-device retrieval (cosine over the set) | **< 100 ms** | No network in the loop at all |
| On-device generation (qwen3-1.7) | seconds | Yes — and it's getting cheaper monthly |

<!-- pause -->

Here's the honest part — because I'm not going to oversell it: on-device
**generation** is slower per token than a datacenter GPU **(of course it is)**.

But the number that decides the user experience isn't tokens-per-second. It's
the round trip you can never delete. On-device, there isn't one.

_Mobile-LLM latency baselines: MELTing Point — `paper-2403.12844`._

<!-- end_slide -->

# The CRDT insight

A vector index is the cleanest CRDT shape there is.

<!-- pause -->

It's a **grow-only set** (a G-Set) of `(embedding, payload)` tuples.
Embeddings are **additive** — every one is just a point in a space, nothing
ever needs reconciling. And relevance is a **pure function over a set**:

```
topK(corpus_A ∪ corpus_B)  ==  topK(corpus_B ∪ corpus_A)
```

Union is associative, commutative, idempotent — so the answer is the same no
matter which phone runs it, or what order the notes arrived. That's the whole
CRDT property, for free.

<!-- pause -->

```dart
class StudyNote {
  String   id;          // UUIDv5 — content-addressed, mechanically disjoint
  String   topic;       // "Saturn"
  String   contributor; // "phone-b"
  String   body;        // the note text the audience can read
  List<String> tags;
  List<double> embedding; // qwen3-0.6-embed — identical model on every device
  DateTime createdAt;
}
```

_CRDT theory: Shapiro, Preguiça, Baquero, Zawirski — `paper-1106.4374`._

<!-- end_slide -->

# Architecture

```
        Phone A                          Phone B
   ┌────────────────┐               ┌────────────────┐
   │  Flashcards UI │               │  Flashcards UI │   Flutter
   ├────────────────┤               ├────────────────┤
   │     Cactus     │  embed + gen  │     Cactus     │   on-device LLM:
   │  (on-device)   │   (WAN off)   │  (on-device)   │   embed: qwen3-0.6-embed
   ├────────────────┤               ├────────────────┤   gen:   qwen3-1.7
   │   Ditto store  │               │   Ditto store  │   CRDT G-Set
   │  (Rust core,   │               │  (Rust core,   │   — my day job:
   │    C FFI)      │               │    C FFI)      │   FFI all the way down
   └───────┬────────┘               └────────┬───────┘
           └──────────  BLE / LAN  ──────────┘
                      mesh — WAN off
```

<!-- pause -->

Cactus does embedding **and** generation at the leaves. Ditto syncs the notes
**and their embeddings** as the grow-only union. Between retrieval and the
rendered card there are **six structural gates** — each one added the day a
small model did something surprising on a real phone. Fix the input, not the
output.

<!-- end_slide -->

# Live demo — the moment of magic

**Setup:** airplane mode, Bluetooth on. Phone A holds the **inner** planets.
Phone B holds the **outer** planets. I ask A about **Saturn** — which isn't in
its corpus.

<!-- pause -->

**Beat 1 — A alone.** Footer reads `drew on N notes (0 from peers)`. Mesh pill:
**alone**, gray. Saturn's not there; the answer is thin. Good — that's the
setup.

<!-- pause -->

**Beat 2 — they meet.** B walks into Bluetooth range. The pill flips
**green → `1 peer`**. The Notes tab grows a `phone-b` group: Jupiter, Saturn,
Uranus, Neptune, Pluto sync in. No wifi. No cloud.

<!-- pause -->

**Beat 3 — ask again.** Same query, same model. Footer now reads
`drew on 5 notes (3 from peers)`, and the Saturn card carries a **`phone-b`
source chip**.

> Same question. Bigger corpus. The only thing that changed is another phone
> walked into the room.

<!-- end_slide -->

# What I measured — and what it isn't

**Measure, don't assume.** Cross-platform, the embeddings *drifted*: iPhone ↔
Pixel landed at **17/20 — 0.85**. I didn't round that up to a pass.

- Diagnosed it: the **chat-tuned** embedding model was the culprit.
- Swapped to the dedicated similarity-tuned slug (**`qwen3-0.6-embed`**),
  re-measured: **20/20 — 1.0000.** Zero disagreements.
- Locked the baseline, so the next regression **fails CI before it reaches a
  phone.**

<!-- pause -->

**What it _isn't_** — named, not hidden:

- **Threat model is wide open.** No peer auth, no provenance signatures, no
  corpus ACL. Anyone in BLE range is trusted.
- **A small generalist can't merge recipes.** I tried — it can't. That's why
  the demo is space facts, and why slide 8's answer is *specialists*.
- **Stage 2 (ingesting arbitrary files) is a non-goal.** Five curated notes a
  side; I'm not going to pretend it scales tonight.

<!-- pause -->

> Nothing is wasted when you document the messy middle.

<!-- end_slide -->

# Where this goes — four threads

Stage 0 ships the **simplest** version: one generalist small LLM, a flat
grow-only union. That's the stepping stone, not the destination.

<!-- pause -->

- **1 · Specialists, not generalists.** Stage 0's generalist couldn't merge
  recipes — too small. The fix isn't a *bigger* generalist; it's a *bag of small
  domain experts*, one per device. When phones meet, **expertise composes as
  freely as data does.**
- **2 · Preference-aware merge.** The set stays grow-only — every contribution
  is kept — but **synthesis is weighted by who's asking.** Hate avocado? Your
  phone quietly leaves it out.
- **3 · Adversarial / mistake filtering.** Keep everything; **gate promotion**
  into the canonical answer. Reputation, consensus, a plausibility check. The
  mesh becomes a multi-write log with curation as its own layer.
- **4 · Generational evolution.** A corpus isn't a snapshot. **Temporal drift**
  — recent contributions weigh more; branch when tastes diverge.

<!-- pause -->

> **Family recipes** — written down, passed through generations, quietly
> mutating, still recognizably *ours*. The vector index isn't just a CRDT.
> **It's a culture.**

<!-- end_slide -->

<!-- jump_to_middle -->

# Clone it. Pair your own two phones.

<!-- alignment: center -->
![](media/repo-qr.png)

<!-- alignment: center -->
**github.com/alycda/DittoXCactus**

<!-- alignment: center -->
_Build notes — how I ran this as an AI dark factory:_ hackmd.io/@alyda/r10BQw8zGg

<!-- alignment: center -->
Alyssa Evans · @She's Fast · Staff Engineer @ Ditto

<!-- alignment: center -->
_Fail in public with me._
