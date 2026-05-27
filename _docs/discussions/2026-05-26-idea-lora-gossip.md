<!--
DRAFT — GitHub Discussion, category: Ideas
Repo: alycda/DittoXCactus
Source: README.md, option D ("Model weights gossip"), present from commit dfcad2a3 through main

Pre-post checklist:
- [x] Source is committed on main and visible at https://github.com/alycda/DittoXCactus/blob/main/README.md#L261-L270
- [ ] Strip this HTML preamble before posting
- [ ] Title: "Federated learning, without the federation: LoRA gossip over Ditto mesh"
- [ ] Category id: DIC_kwDOSlRUbc4C9qmY (Ideas)
-->

# Federated learning, without the federation: LoRA gossip over Ditto mesh

Pulling forward the most ambitious of the four candidate framings I
brainstormed before picking what became the demo. Option **D — "Model
weights gossip"** — lives as a seven-line section in the
[README](https://github.com/alycda/DittoXCactus/blob/main/README.md#L261-L270),
marked *"Not pursued"* with the note "kept for the brainstorm record." A
year later, after actually shipping option A (Mesh RAG — embeddings as
CRDT), I think D is the natural follow-up and deserves a home of its own.

This isn't a plan. It's the case for why someone should pick this up next.

## What got built (A) vs. what D extends

The shipped demo proves a specific claim: **embeddings travel
losslessly over a CRDT mesh**. Two phones meet over BLE, vector indexes
merge as a grow-only union, retrieval works against the merged set with
no cloud. The substrate question — *what payloads survive a CRDT
merge?* — got one concrete answer.

D is the same question, asked about a different payload class: **LoRA
adapter deltas**.

- Each phone collects examples (custom labels, wake words, sample
  images, tagged notes — task-shaped data).
- Cactus does on-device LoRA fine-tuning, producing a tiny tensor
  delta — typically tens-to-hundreds of MB before quantization,
  potentially low MB after INT8/INT4. Small enough that BLE-class
  transfers are feasible.
- The deltas gossip over Ditto. Phone A trains, phone B inherits, the
  on-device model improves additively as the mesh grows.

The thesis from the original brainstorm: *"model deltas are
mesh-friendly payloads. If embeddings are CRDTs (A), so are LoRA
tensors."* Whether that's actually true is the load-bearing question
this discussion is for.

## Why this is the most thesis-relevant unbuilt option

[The writeup's specialists thread](https://github.com/alycda/DittoXCactus/discussions/8)
closes on a four-part future-work arc — *specialists, preference-aware
merge, adversarial filtering, generational evolution.* D is what
**generational evolution** actually looks like in practice:

- A static catalog (today's situation) ships fixed weights to every
  phone. Updates require a release.
- Federated learning at scale (Google's keyboard, Apple's Siri) gets
  generational improvement from millions of devices via a central
  server.
- **LoRA gossip is the version of generational evolution that fits in
  the mesh-only, no-cloud-trust-boundary the demo defends.** Each peer
  is both trainer and consumer. The "generation" is the LoRA stack on
  any given phone at any given moment, formed from whoever they've
  recently met.

The other two arc threads also get something out of D:

- **Adversarial filtering.** Untrusted-peer LoRA deltas need a
  pre-merge filter that rejects malicious or off-distribution updates.
  Mesh RAG doesn't have to solve this because embeddings are
  inherently grounded in source notes the user authored; LoRA
  gossip *does* have to solve it because a peer's delta can shift
  the model's behavior on inputs the user authored. Real research
  question.
- **Preference-aware merge.** Not all LoRA deltas should merge into
  every peer's stack. A user might want to inherit a friend's
  domain-expert LoRA but not their dialect LoRA. Merge has to be
  *selective* in a way embedding-CRDT merge isn't.

## What makes this hard, honestly

The README marks it *"real risk this overflows the weekend. Not
pursued."* — and that risk is genuine. The order-of-difficulty stack:

1. **On-device LoRA fine-tuning on consumer hardware.** Cactus's
   public surface today is inference-only. Training requires
   reverse-mode autodiff, an optimizer, and a much higher RAM ceiling
   than INT4 inference uses. Some recent work makes this tractable on
   8GB+ phones (peft + bnb int8, MLC's training fork, MLX's mobile
   target), but it's not a "use the existing SDK" task — it's a
   pipeline build.

2. **LoRA delta serialization to a CRDT.** A LoRA adapter is N
   per-layer rank-r matrices. Serializing them as a CRDT-mergeable
   payload is plausible (treat each layer as a tuple, use last-writer-
   wins with version vectors, or build a numerical-CRDT for the
   tensor values) but the shape isn't shaped like Ditto's standard
   document model. Custom encoding required.

3. **The merge semantics question.** If phone A trains a LoRA on its
   examples and phone B trains a LoRA on its examples, the *literal
   tensor average* of those deltas is the FedAvg recipe — but FedAvg
   assumes IID data, which mesh-meeting peers don't have. The right
   merge might be "concatenate adapters in a multi-LoRA stack" (each
   peer's contribution stays separate, applied additively at inference)
   rather than "average them into one."

4. **Adversarial robustness.** Embeddings can drift the *retrieval*;
   LoRA deltas can drift the *behavior*. Need a verification step
   before merge that's stronger than what Mesh RAG needs.

5. **Storage and forgetting.** A phone that meets 30 peers a year
   accumulates 30 LoRA stacks. At some point you need a forgetting
   policy or a consolidation step. This is the Stage-2-of-Stage-2
   problem.

## Why someone should still want to build it

Three reasons:

- **It's the demo with the strongest narrative.** "Phone A trains a
  custom classifier. Phone B inherits the model and classifies the
  same things without ever having been trained. Phone C inherits
  from both A and B and is better than either." That's a 30-second
  demo that doesn't have any comparable demo on the cloud side, because
  the cloud side is *exactly the federation server we're not running*.
- **It's the demo with the strongest writeup.** "Federated learning,
  without the federation" is the title in the README and it writes
  itself once you have the demo working. The current Mesh RAG writeup
  has a hard time finding a one-line thesis that doesn't also describe
  what some existing on-device-RAG library does; D doesn't have that
  problem.
- **It's the demo where the trust-boundary argument actually matters.**
  Mesh RAG's "no cloud" claim is true but the user could shrug at it
  ("ok but I'd be fine with the cloud here, my notes aren't secret").
  LoRA gossip's "no cloud" claim has teeth — a user's *fine-tuned
  model* is much more privacy-sensitive than their raw notes. The
  on-device-only constraint is no longer aesthetic; it's load-bearing.

## What I'd want a real brainstorm or research pass to nail down

- **Concrete adapter size budget.** What size LoRA, on what base model,
  fits in what BLE-transfer window? Estimate the ceiling for "per-meet
  delta exchange" before designing the rest.
- **The merge primitive.** Multi-LoRA stack (additive, peer-attributable)
  vs. FedAvg-style average (single adapter, no attribution) vs. selective
  per-task adapter (user picks which peer-LoRA to apply). The choice
  determines a lot of downstream design.
- **The training trigger.** Is this user-tap-driven ("teach this phone
  this") or background-passive ("phone learns from your usage")? The
  first is easier to demo, the second is more useful in practice.
- **Base model lineage.** Different base models can't share LoRA
  adapters. Does the mesh assume everyone runs the same base
  (Qwen3-1.7, etc.)? That's a strong coupling that may or may not be
  realistic across users.
- **Tooling.** What would the LoRA convert+gossip pipeline look like
  inside Cactus's existing graph model? Could the same `.weights` +
  `.scale` per-layer format the engine already mmaps absorb LoRA
  deltas, or does this need its own bundle shape?
- **Defensible analogue prior art.** [Petals](https://github.com/bigscience-workshop/petals)
  for inference, [FedLab](https://github.com/SMILELab-FL/FedLab) for
  federated training simulation, [DiLoCo](https://arxiv.org/abs/2311.08105)
  for low-bandwidth federated training — what's the closest existing
  thing? The brainstorm note was 2026-05-22; there's been a year of
  research since.

## What I want feedback on

- **The thesis itself.** *"If embeddings are CRDTs, so are LoRA
  tensors"* — is that actually true or just rhetorically convenient?
  What's the strongest argument against it?
- **The hardest sub-problem.** I'd guess it's #1 (on-device training)
  in terms of pure engineering and #3 (merge semantics) in terms of
  research uncertainty. Anyone closer to the LoRA-on-edge world have a
  better ranking?
- **The right starting model.** A small Qwen 3 variant is the
  on-device default; would the LoRA-trainability constraint push that
  to a different base?
- **Is anyone already shipping this?** I haven't seen federated LoRA
  + BLE-class-bandwidth gossip as a public-facing product. If it
  exists, the prior-art makes the demo less novel; if it doesn't, the
  greenfield matters for the writeup.

## Source

Currently a seven-line callout in the README, at
[README.md option D](https://github.com/alycda/DittoXCactus/blob/main/README.md#L261-L270).
Surfaced from commit `dfcad2a3` (May 2026), kept through every rewrite.
This Idea discussion is the home for picking it up later — the README
will keep marking it *"Not pursued."*

Related arcs:
- The shipped Mesh RAG demo (option A): [#8](https://github.com/alycda/DittoXCactus/discussions/8)
- The other unbuilt direction worth seeding: [#11 Workflowy Merge](https://github.com/alycda/DittoXCactus/discussions/11)
- The C++ engine reality check that bounds what's possible on the runtime side today: [#10](https://github.com/alycda/DittoXCactus/discussions/10)
