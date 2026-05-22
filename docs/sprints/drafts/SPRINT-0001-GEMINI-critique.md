# Critique: SPRINT-0001-GEMINI

This critique evaluates `SPRINT-0001-GEMINI.md` against the two sibling drafts, `SPRINT-0001-CODEX.md` (Draft A) and `SPRINT-0001-CLAUDE.md` (Draft B).

## Comparison: CODEX (Draft A)

### What is Stronger
*   **Infrastructure Rigor:** CODEX includes a dedicated section for "Repo skeleton and kickoff" (Task 6.0), including legal checks for Ditto's license terms and explicit version-pinning for all SDKs. My draft assumes these are trivial.
*   **Deterministic Depth:** In "Spike A" (Task 6.1), CODEX specifies pinning the Cactus backend to CPU/Vulkan and forcing a batch-size of 1 to ensure parity. This addresses the "Thinking Machines" guidance found in the research, which my draft misses.
*   **Operational Readiness:** The "Demo-day readiness" (Task 6.8) is superior, including B-roll recording, a second hardware pair on standby, and stopwatch rehearsals.
*   **Risk Management:** The risk matrix (Section 7) is significantly more professional, quantifying likelihood and impact with specific mitigations like "pre-bake KV-cache."

### What is Weaker
*   **Narrative Flow:** My "Phase" structure is slightly more intuitive for a quick hackathon mental model compared to CODEX's very dense engineering checklist.

### Missing Tasks
*   **Task 6.0:** Ditto trial/license resolution for public redistribution.
*   **Task 6.1:** Pinning model backends away from ANE/Hexagon paths to maximize cross-platform parity.
*   **Task 6.8:** Capturing B-roll as a fallback for live radio flakiness.

### Underweighted Risks
*   **Legal/Licensing:** The risk of being unable to publish the repo due to Ditto's trial terms (R6 in CODEX).
*   **System Interference:** iOS background-BLE limitations (R5 in CODEX) which could kill sync during a demo.

### Sequencing Issues
*   My draft builds the UI in Phase 3, whereas CODEX correctly identifies that the repo skeleton and dependency wiring (Task 6.0) must happen before any spikes can run.

---

## Comparison: CLAUDE (Draft B)

### What is Stronger
*   **Evaluation Quality:** CLAUDE’s "Gate B" is much more specific about the eval fixtures (chicken tortilla soup, avocado preference, adversarial cases). My draft is vague about the 10 recipe strings.
*   **Demo Utility:** CLAUDE includes a "one-tap reset for demo data" and "one-tap seed action" (Task: Demo UI). In a live hackathon demo, being able to reset the state instantly after a failed attempt is a lifesaver.
*   **Validation Traceability:** The "Validation Harness" task requires creating trace artifacts for every holdout, ensuring the results are reproducible and documented, not just "verified" mentally.

### What is Weaker
*   **Tooling Specification:** My draft's "comparison harness" in Task 1 is a clearer directive for a developer than CLAUDE's "Build smallest possible harness."

### Missing Tasks
*   **Task: Demo UI:** One-tap reset and one-tap seed buttons.
*   **Task: Validation Harness:** Generating stable trace artifacts (JSON/logs) for each SEED holdout.
*   **Task: Cactus Integration:** Eager-loading models at app startup (Cactus Integration section) to meet the 10s budget.

### Underweighted Risks
*   **Synthesis Failure:** CLAUDE treats the "Cars fallback" more seriously as a hot-swappable corpus (Risk: Recipe synthesis is too weak).

### Sequencing Issues
*   CLAUDE’s "Day 0" setup vs "Day 1" gate execution is a better way to handle the Friday night/Saturday morning transition than my linear Phase 1–4.

---

## Merging Recommendations

If merging these into a final "Gold" plan:

1.  **Keep from CODEX (Draft A):**
    *   The technical rigour of **Task 6.1 (Spike A)**: Pinning CPU/Vulkan and batch=1 is essential to pass the 0.999 cosine gate.
    *   The **Risk Matrix** and **Demo-day readiness (Task 6.8)** (B-roll + backup hardware).
    *   The **legal/license check** for the Ditto SDK.

2.  **Keep from CLAUDE (Draft B):**
    *   The **specific fixture definitions** (Chicken tortilla soup + Avocado) for the merge eval.
    *   The **"one-tap reset" button** in the UI.
    *   The **trace artifact requirement** for holdout validation.
