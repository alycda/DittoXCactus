# Build the Likec4 dashboard at docs/c4/dashboard/ (gitignored — rerun on fresh checkouts or after editing model.c4).
c4-build:
    npx --yes likec4@latest build docs/c4 -o docs/c4/dashboard

# Build (if missing) then serve the C4 dashboard at http://localhost:8000.
[working-directory: 'docs/c4/dashboard']
c4-model: c4-build
    python3 -m http.server 8000
