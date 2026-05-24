# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Flutter hackathon demo pursuing the **"Mesh RAG"** framing of Ditto × Cactus (Stage 0). Two phones each hold a slice of a study-notes corpus; they meet over BLE/Wi-Fi and the vector index merges as a CRDT, so a query on phone A draws on phone B's notes after handshake — with WAN off. See [README.md](README.md) and [SEED.md](SEED.md) for the thesis. Other framings (B/C/D) live in [docs/c4/model.c4](docs/c4/model.c4) and the brainstorm at [README](README.md); only A is implemented.


The order of authorship — and the validation chain — is: parent brainstorm (`README.md`) → idea doc (`_docs/IDEA-A.md`) → seed (`_docs/SEED.md`) → research brief + 6 deep-research passes + 281-source index (`_docs/research/`) → implementation plan (`_docs/plans/001-feat-mesh-rag-demo.md`) → C4 architecture model (`docs/c4/`) → implementation (next). Each layer cites the substrate beneath it: the plan cites the research index by per-source ID; the C4 model cites the plan; new code will cite the C4 components and the plan's implementation units.

## Common tasks here

```sh
just c4-model    # serves the prebuilt Likec4 dashboard at http://localhost:8000
```

The dashboard at `docs/c4/dashboard/` is a build artifact (gitignored) — regenerate it from source with `npx likec4@latest build docs/c4 -o docs/c4/dashboard` after editing `docs/c4/model.c4`. Validate the model with `npx @likec4/cli validate docs/c4/model.c4`.

Version control is **jj-first** (this is a colocated jj+git repo: both `.jj/` and `.git/` exist). The repo-local memory entries on jj are load-bearing — never `jj edit <ancestor>`, use the `jj new --insert-after/before` + `jj restore --from @ --to <new>` pattern for retroactive edits. Plain `git` commands are safe for read operations (`git log`, `git status`) but mutations should go through jj. See user memory `feedback_jj_*` entries.

## Architecture of the documentation set

```
README.md                          # parent brainstorm: framings A/B/C/D, A chosen
_docs/
  IDEA-A.md                        # the thesis: "Your knowledge base wants to be a CRDT"
  SEED.md                          # validation harness, holdouts 1–8, cut order, threat-model bound
  WEB-PROMPT.md                    # prompt used to drive the hosted deep-research passes
  RESEARCH-BRIEF.md                # task list handed to deep-research workers
  plans/001-feat-mesh-rag-demo.md  # implementation plan; cites research/index/ by per-source ID
  research/
    {claude,codex,gemini}.md                        # 3 Mode-B web-research worker outputs
    {claude,chatgpt,gemini}-deep-research.md        # 3 hosted Deep Research passes
    downloads.yaml                                  # canonical manifest of downloaded materials
    index/                                          # Reduce-phase synthesis of the above
      README.md                                     # entry point for downstream agents
      top-N.md                                      # 22 ranked must-reads
      clusters.md by-topic.md by-tag.md
      cross-references.md open-questions.md
      _per_source/                                  # 281 per-source summaries (gitignored bulk; only .gitignore is tracked)
docs/c4/
  interview.md                                      # Step 0 of c4-design skill
  model.c4                                          # Likec4 DSL — source of truth for the architecture diagrams
  dashboard/                                        # build output (gitignored)
_inspiration/                                       # locally-cloned papers/repos referenced by the index; gitignored except .gitignore (everything is excluded)
slides/                                             # planned home for the deck; only `media/` exists today
```

**The C4 model encodes the system the implementation will build.** Containers in `docs/c4/model.c4` (`phone_app`, `cactus_models`, `ditto_store`, `determinism_harness`) reference files under `lib/`, `tools/`, `assets/` that don't exist yet — they describe the target. When editing the C4 model, edit `docs/c4/model.c4` and rebuild the dashboard — never hand-edit `docs/c4/dashboard/`.

## Thesis-bearing constraints (carry across edits)

These pin the writeup's argument and the demo's scope; an edit that contradicts them likely needs the user to make the call, not Claude.

- **The cloud is not in the trust boundary.** No Cactus hybrid mode, no remote vector store, no internet path during the demo. Plan §Scope Boundaries calls this out as the thesis-breaking line.
- **iOS + Android both required** (Holdout R10). iOS + macOS does not satisfy the mobile-edge claim.
- **Holdout 7 (end-to-end offline) is never cut** under any forcing function. Every other holdout has a defined cut order in SEED.md.
- **Determinism (Holdout 2) is the pre-flight gate.** If the cross-platform cosine-parity test fails, the project pivots to brainstorm option C ("Narrate the mesh") rather than weakening the thesis.
- **Stage 1 corpus theme is audience-submitted study notes**, not recipes — recipe-merge was tried previously and didn't survive stress-testing; the clean-history plan adopts study notes from the start (see user memory `project_stage1_corpus_study_notes`).
- **The writeup's arc is specialists, not generalists.** Stage 0 (generalist small LLM + flat grow-only union) is the stepping stone; the writeup closes on a four-thread future-work arc — *specialists, preference-aware merge, adversarial filtering, generational evolution.* See user memory `project_writeup_thesis_arc` and `_docs/research/index/open-questions.md`.

## How to navigate the research index

Per `_docs/research/index/README.md`: start at `top-N.md` (22 sources, ~45 min), then branch by intent — building the demo = clusters C3 (Ditto) + C5 (Cactus + LLM) + C9 (vector search); writing the post = C1 (case for on-device) + C6 (determinism) + C7 (specialists), then `open-questions.md`. Per-source files at `_per_source/<id>.md` are catalog entries; for paper-level content prefer the worker outputs (`claude.md`/`codex.md`/`gemini.md`) which actually read the abstracts. The 281 per-source files are gitignored bulk — only `_per_source/.gitignore` is tracked.

## Editing conventions

- **Plan, SEED, README cross-link by relative path.** Keep them resolvable when reorganizing files.
- **The plan cites research by per-source ID** (e.g. `paper-2509.20354`, `article-thinkingmachines-blog-defeating-nondeterminism-in-llm-inference`). New citations should resolve to a real entry under `_per_source/`.
- **Holdout numbering (R1–R11) is shared vocabulary** across SEED, plan, and C4 interview. Don't renumber.
- **Stage 0 vs Stage 1** is shared vocabulary too. Stage 0 = CRDT vector sync + retrieval (no LLM generation); Stage 1 = adds buffered/streaming flashcard generation. Stage 2 (arbitrary file ingestion) is an explicit non-goal.
