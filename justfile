# DittoXCactus — Mesh RAG project root commands.
# Run `just` (no args) to list available targets.

# Default target: list targets
default:
    @just --list

# Start the Likec4 dev server (hot-reloads on .c4 source edits)
serve:
    npx --yes likec4@latest start docs/c4

# Validate the Likec4 DSL
validate:
    npx --yes likec4@latest validate docs/c4

# Build the static Likec4 dashboard at docs/c4/dashboard
build:
    npx --yes likec4@latest build docs/c4 -o docs/c4/dashboard

# Open the most recent static-built dashboard in the default browser (macOS)
open-dashboard:
    open docs/c4/dashboard/index.html
