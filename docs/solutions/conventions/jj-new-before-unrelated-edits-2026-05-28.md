---
title: "jj-first repo: run `jj new` before unrelated edits to prevent auto-snapshot from mixing commits"
date: 2026-05-28
category: conventions
module: version-control
problem_type: convention
component: development_workflow
severity: medium
applies_when:
  - Editing files in a jj-managed repository (this project is jj+git colocated)
  - About to make file edits that are conceptually distinct from the commit currently described at @
  - Working through a sequence of unrelated improvements in one agent session (plan + CLAUDE.md update + new code, etc.)
related_components:
  - tooling
tags:
  - jj
  - jujutsu
  - auto-snapshot
  - commit-hygiene
  - workflow
---

# jj-first repo: run `jj new` before unrelated edits to prevent auto-snapshot from mixing commits

## Context

Jujutsu's working copy IS a commit. Every shell command jj observes (including the next `jj describe`, `jj status`, `jj log`) triggers an auto-snapshot of the working tree into the current `@`. This is excellent for "never lose work" but it has a subtle hazard: if you edit unrelated files after describing `@` but before running `jj new`, those edits land in the just-described commit and the description no longer matches its contents.

This session hit the same failure mode three times:

1. **CLAUDE.md edits mixed with the specialist-training plan commit** — the plan (U1's `docs(plan):`) commit was described, then `Flutter MCP server + Flutter skills` edits to `CLAUDE.md` were made without `jj new`. The auto-snapshot pulled CLAUDE.md into the plan commit. Required a `jj new --insert-after` + `jj squash` recovery.
2. **U1 scaffolding mixed with the CLAUDE.md commit** — same pattern, opposite direction. `jj describe` was used to set the CLAUDE.md commit message, then U1 directory scaffolding was created. Snapshot bundled the scaffolding into the CLAUDE.md commit; described again replaced the original message.
3. **U3 holdout mixed with another CLAUDE.md update** — the holdout file was added (correct), then unrelated CLAUDE.md documentation edits were made before `jj new`. Snapshot mixed them. Same recovery pattern.

Each mix-up cost ~3-5 minutes to split apart cleanly.

## Guidance

**`jj new` is the punctuation that separates one commit's content from the next.** Run it explicitly between unrelated edits — don't rely on the next describe to "implicitly" start a new commit.

The reliable pattern when iterating through multiple commits:

```bash
# edit files for commit 1
jj describe -m "feat(thing-a): ..."     # 1 — describes the current @
jj new                                  # 2 — opens a fresh empty @
# edit files for commit 2 — these land in the new @, not in thing-a
jj describe -m "feat(thing-b): ..."
jj new                                  # again before the next batch
# edit files for commit 3 ...
```

The previously-established session shortcut of running `jj describe -m "..." && jj new` as a single chained command is the right shape — it makes the boundary explicit.

If you do hit the mix-up (auto-snapshot already bundled unrelated content), the recovery is the `jj new --insert-after` + `jj squash` pattern from `feedback_jj_no_at_movement` / `feedback_jj_modify_in_ancestor`:

```bash
# Mixed commit X has both real-X-content and accidentally-snapshotted-Y-content.
# Goal: split into X (real) + new commit on top (Y).
jj new --no-edit --insert-after X -m "<correct message for Y>"   # new empty Y commit
jj squash --from X --into <new-Y-change-id> <Y-path>             # move Y's content forward
# X now has only its real content; Y commit has its content + correct description.
```

## Why This Matters

The jj auto-snapshot model is the right default — it eliminates entire classes of "I lost my work because I forgot to git add" failures. But it shifts the cost: instead of explicitly staging changes, you have to explicitly delimit commits. In a session with multiple unrelated commits (the typical /ce-work or multi-PR flow), forgetting `jj new` becomes the new "forgot to git add."

Cost of the mistake compounds when the affected commit is already pushed or part of a stacked PR: each downstream commit must be rebased, the bookmark must be moved, and history-rewrite chatter floods the PR review.

The cost of `jj new` is approximately zero — it's instant and idempotent. Treating it as required punctuation (not optional) is strictly cheaper than the recovery.

## When to Apply

- After every `jj describe` when you intend to make further edits in this session.
- Before opening any new file or editing any existing file that is conceptually unrelated to the current `@` commit's purpose.
- At the start of any agent loop iteration where the loop is going to make multiple unrelated edits.
- Especially after running a sub-agent that wrote files — the auto-snapshot snapped those into `@`; if `@` had a description, that description is now wrong unless the sub-agent's writes actually match it.

Skip the discipline only for genuine single-commit sessions where you're editing one file, describing once, and stopping.

## Examples

**Wrong (the failure mode that hit three times):**

```bash
# Working on commit A
edit lib/services/foo.dart
jj describe -m "feat(foo): add X to FooService"

# Now I want to update docs/notes/foo-quirks.md — completely unrelated
edit docs/notes/foo-quirks.md
# ↑ This edit just landed in @ alongside the foo.dart changes. The
#   "feat(foo):" commit now also contains foo-quirks.md. Confusing.

jj describe -m "docs(foo-quirks): document X"
# ↑ This REPLACED the "feat(foo)" message. Now the commit contains
#   foo.dart + foo-quirks.md with a misleading description.
```

**Right:**

```bash
# Working on commit A
edit lib/services/foo.dart
jj describe -m "feat(foo): add X to FooService"
jj new   # ← the load-bearing line

# Now editing docs/notes/foo-quirks.md
edit docs/notes/foo-quirks.md
# ↑ This lands in the new empty @, not in the foo.dart commit.

jj describe -m "docs(foo-quirks): document X"
# ↑ Describes the docs commit. Clean separation.
jj new   # if more edits are coming
```

**Recovery pattern (when you've already hit the mix-up):**

```bash
# State: @ = MIXED commit, has both feat(foo) intent + docs(foo-quirks) content.
# Goal: split — keep feat(foo) clean, put docs(foo-quirks) in a new commit on top.

jj new --no-edit --insert-after @ -m "docs(foo-quirks): document X"
jj squash --from @- --into @ docs/notes/foo-quirks.md
# Now @- = clean feat(foo) (only foo.dart), @ = clean docs(foo-quirks) (only the doc).
```

## Related learnings (in user memory)

- `feedback_jj_never_move_at` — Never `jj edit <ancestor>` to modify ancestors; use the `jj new --insert-after` + `jj restore` / `jj squash` pattern instead. Related — this convention's recovery path leans on the same primitives.
- `feedback_jj_no_at_movement` — Sequential `jj new --insert-before <main-child>` + `jj squash <path> --from <orig> --into <new>` extracts path changes back toward an ancestor without conflicts or @ movement. Same primitive, applied forward instead of backward.
- `feedback_incremental_commits` — One CLI invocation per commit. This convention is the auto-snapshot-aware version of that rule: the punctuation between commits IS the `jj new`.
