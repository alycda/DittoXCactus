---
title: "Add justfile recipes early and often; treat the justfile as load-bearing UX"
date: 2026-06-01
category: conventions
module: tooling
problem_type: convention
component: development_workflow
severity: medium
applies_when:
  - Introducing a new command that will run more than once
  - Command sources `.env` (DITTO_APP_ID, DITTO_LICENSE, ANTHROPIC_API_KEY, TOGETHER_API_KEY, etc.)
  - Command takes more than 2–3 flags or `--dart-define` pairs
  - Command crosses a per-unit boundary (run on iOS, then Android, then compare results)
  - Onboarding a fresh checkout — the justfile is the canonical answer to "how do I run this project"
related_components:
  - development_workflow
  - documentation
tags:
  - justfile
  - tooling
  - developer-experience
  - dotenv
  - ux
---

# Add justfile recipes early and often; treat the justfile as load-bearing UX

## Context

This project relies on a long-tail of repeated commands across many surfaces: Flutter app boots with role-specific `--dart-define` flags, Ditto wipes per device id, holdout runners, determinism-harness measure/check passes, c4 model build/serve, knowledge-graph regeneration, Magpie generation jobs, eval harness drivers. Almost every one of them sources `.env` and takes device-id positional arguments.

Asking the user (or a future agent) to remember the long forms is friction. The justfile already had recipes like `c4-build`, `c4-model`, `harness-test`, `harness-measure DEVICE`, `harness-check A B` before this convention was named — the convention captures what the project was already doing well.

## Guidance

When introducing a new repeated command, **add a justfile recipe in the same commit that introduces the command** — don't paste the long form into agent responses, the README, or chat history. The justfile is the source of truth for "how do I run this project."

Rules:

- **Group recipes by domain** with hyphenated prefixes: `c4-*`, `harness-*`, `app-*`, `ditto-*`, `holdout-*`, `specialist-*`. Lowercase, hyphen-separated.
- **Prefer positional args** (`harness-measure DEVICE`) over hardcoded targets, unless the action is genuinely target-specific (e.g. `app-run-a-demo` vs `app-run-b-demo` where the role is the whole point).
- **Use `set dotenv-load` at the top of the justfile** — just's built-in `.env` autoload. Recipes then reference `$DITTO_APP_ID` etc. directly. Cleaner than `set -a; source .env; ...` shell idioms.
- **Document non-obvious recipes** with a one-line comment above the recipe name (existing pattern in this repo).
- **Add proactively** — do not wait for the user to ask. If a command runs twice in one session, it belongs in the justfile.

## Why This Matters

The justfile is the **user-visible interface** to the project's command surface. It surfaces in `just --list`, in CLAUDE.md, in onboarding docs. Every command that lives only in agent responses or shell history rots — the next person to need it pays the discovery cost again.

The user has articulated this preference explicitly and has twice opened the justfile mid-session as a nudge to add to it. The shared cost of a missing recipe is small per occurrence but compounds across sessions, agents, and contributors. The cost of adding a recipe is ~30 seconds.

This also has a hidden benefit for offline / mesh holdouts: a justfile recipe is the durable record of *what we ran* during the airplane-mode capture. Without it the run is unreproducible.

## When to Apply

- Any command sourcing `.env`
- Any command with more than 2–3 flags
- Any command that will be run more than once
- Any device-specific or role-specific invocation (`flutter run --dart-define=PHONE_ROLE=a -d <id>`)
- Any build step that produces a tracked artifact (the c4 dashboard, the knowledge-graph dashboard)

## Examples

**Before** (paste-and-pray, what NOT to do):

```
flutter run -d 1AB2... --dart-define=PHONE_ROLE=a --dart-define=DEMO_OVERLAY=true --dart-define=DITTO_APP_ID=$DITTO_APP_ID --dart-define=DITTO_LICENSE=$DITTO_LICENSE
```

**After**:

```just
# Boot phone A in demo mode (PHONE_ROLE=a + HUD overlay)
app-run-a-demo DEVICE:
    flutter run -d {{DEVICE}} \
        --dart-define=PHONE_ROLE=a \
        --dart-define=DEMO_OVERLAY=true \
        --dart-define=DITTO_APP_ID=$DITTO_APP_ID \
        --dart-define=DITTO_LICENSE=$DITTO_LICENSE
```

Then `just app-run-a-demo 1AB2...` — six tokens instead of forty-something, and the recipe lives where the next agent will find it.

## Related

- `set dotenv-load` documented in [just's manual](https://just.systems/man/en/chapter_24.html)
- Project's full recipe catalogue: `just --list`
- Sibling convention: [jj-new-before-unrelated-edits-2026-05-28.md](jj-new-before-unrelated-edits-2026-05-28.md)
