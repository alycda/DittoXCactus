# U3 — Recipe-merge LLM eval

**Goal:** An off-the-shelf small LLM (≤ 3B) coherently synthesizes a normalized
recipe from 5 heterogeneous chicken-tortilla-soup variants.

**Gate:** R1 (indirectly — gates whether *recipes* is the demo corpus).

## Procedure

Run on the more capable phone (typically iPhone). Eval doesn't need
cross-device parity.

1. Bundle a fixture: 5 hand-picked chicken-tortilla-soup variants with moderate
   ingredient overlap and at least one polarizing ingredient (e.g. avocado,
   vegetarian variant). `assets/seed_recipes_a.json` already qualifies.
2. For each candidate LLM (Qwen 2.5 1.5B, SmolLM2 1.7B, Phi-3 Mini if Cactus
   has it), feed the same `RecipeMergePrompt` (already used in `U6`).
3. Capture the merged output. Score by the rubric below.

## Rubric

Each output scored 1–5 on:

| Dimension | What 5 looks like |
|-----------|-------------------|
| Coherence | Reads like a single coherent recipe, not a stitched list |
| Ingredient recall | Mentions every ingredient that appeared in ≥3 variants |
| Deduplication | Doesn't list the same ingredient twice under different names |
| Instruction clarity | Steps are followable end-to-end |

**Threshold:** ≥ one candidate scores ≥ 3.0 average across the rubric on at
least 3 of 5 audience-likely queries.

## Audience-likely queries to test

- "What's in chicken tortilla soup?"
- "Make me a chicken tortilla soup that's vegetarian."
- "I have chipotle peppers — what soup should I make?"
- "Quick chicken tortilla soup for a weeknight."
- "Authentic Mexican chicken tortilla soup."

## Results

| Model | Coherence | Recall | Dedup | Clarity | Avg | Pass-3-of-5? |
|-------|-----------|--------|-------|---------|-----|--------------|
| Qwen 2.5 1.5B | _todo_ | _todo_ | _todo_ | _todo_ | _todo_ | _todo_ |
| SmolLM2 1.7B | _todo_ | _todo_ | _todo_ | _todo_ | _todo_ | _todo_ |
| Phi-3 Mini | _todo_ | _todo_ | _todo_ | _todo_ | _todo_ | _todo_ |

## Decision

- [ ] **Pass** — keep recipes corpus. Lock chosen LLM.
- [ ] **Fail** — pivot to cars corpus per SEED.md gating clause. Lock smallest
      coherent model.

Chosen LLM: _todo_
Chosen corpus: _todo_
Decision date: _todo_
