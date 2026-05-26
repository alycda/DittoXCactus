# Auto-load .env (DITTO_APP_ID, DITTO_LICENSE, etc.) into every recipe.
set dotenv-load

# ─── C4 architecture model ─────────────────────────────────────────────────

# Build the Likec4 dashboard at docs/c4/dashboard/ (gitignored — rerun on
# fresh checkouts or after editing model.c4).
c4-build:
    npx --yes likec4@latest build docs/c4 -o docs/c4/dashboard

# Build (if missing) then serve the C4 dashboard at http://localhost:8000.
[working-directory: 'docs/c4/dashboard']
c4-model: c4-build
    python3 -m http.server 8000

# ─── U1 / U13 determinism harness (tools/determinism_harness/) ─────────────

# Run the determinism-harness unit tests (pure-Dart math; no device needed).
[working-directory: 'tools/determinism_harness']
harness-test:
    flutter test

# Run the on-device measurement for the U1 R2 gate on DEVICE. Logs the
# per-device JSON output between BEGIN/END markers so it can be extracted
# without adb-pulling. Use `flutter devices` to find a device id.
[working-directory: 'tools/determinism_harness']
harness-measure DEVICE:
    flutter test integration_test/measure_test.dart -d {{DEVICE}}

# U1 cross-platform gate: compare two per-device measurement JSONs.
# Exit 0 if R2 gate clears (>=0.95).
[working-directory: 'tools/determinism_harness']
harness-check A B:
    dart run run.dart check {{A}} {{B}}

# U1 cross-platform gate in CI mode — emits a single JSON line on stdout.
[working-directory: 'tools/determinism_harness']
harness-check-ci A B:
    dart run run.dart check {{A}} {{B}} --ci

# U13 regression: compare a fresh DEVICE measurement against the canonical
# BASELINE (typically baselines/latest/<device>.json). Same exit-code
# semantics as harness-check.
[working-directory: 'tools/determinism_harness']
harness-check-baseline BASELINE DEVICE:
    dart run run.dart check-baseline {{BASELINE}} {{DEVICE}}

# U13 regression in CI mode — single JSON line on stdout; non-zero exit
# when agreement_rate < 0.95.
[working-directory: 'tools/determinism_harness']
harness-check-baseline-ci BASELINE DEVICE:
    dart run run.dart check-baseline {{BASELINE}} {{DEVICE}} --ci

# ─── Main Flutter app (mesh_rag) ────────────────────────────────────────────
#
# All app-* recipes read DITTO_APP_ID + DITTO_LICENSE from .env (gitignored).
# PHONE_ROLE is passed per recipe — `-a` / `-b` variants give the two demo
# phones their disjoint seed corpora (assets/seed_notes_<role>.json).

# Run unit + widget tests for the main app.
app-test:
    flutter test

# Static analyze the main app (excludes _inspiration/ and the harness).
app-analyze:
    flutter analyze

ci: app-analyze app-test

# Run mesh_rag on DEVICE as phone-a. Reads DITTO_APP_ID + DITTO_LICENSE
# from .env. Stage 0: debug mode (release mode has a known ditto_live 5.0.0
# Android crash — see memory feedback_ditto_release_mode_bug).
app-run-a DEVICE:
    flutter run -d {{DEVICE}} \
      --dart-define=DITTO_APP_ID="$DITTO_APP_ID" \
      --dart-define=DITTO_LICENSE="$DITTO_LICENSE" \
      --dart-define=PHONE_ROLE=a

# Same as app-run-a but with PHONE_ROLE=b.
app-run-b DEVICE:
    flutter run -d {{DEVICE}} \
      --dart-define=DITTO_APP_ID="$DITTO_APP_ID" \
      --dart-define=DITTO_LICENSE="$DITTO_LICENSE" \
      --dart-define=PHONE_ROLE=b

# Smoke-build the debug Android APK with .env credentials and ROLE=a. Used
# to validate manifest merging + gradle config without installing on a
# device. Doesn't actually run; just exits 0 on a clean build.
app-build-apk:
    flutter build apk --debug \
      --dart-define=DITTO_APP_ID="$DITTO_APP_ID" \
      --dart-define=DITTO_LICENSE="$DITTO_LICENSE" \
      --dart-define=PHONE_ROLE=a

# ─── U15a / U15b — holdout runners + verdict (tools/holdout_3{4,7}/) ───────

# U15a unit tests for the pure-Dart convergence + idempotence math (no
# devices needed). Runs as part of `app-test` too; this recipe is the
# focused-loop variant.
holdout-34-test:
    flutter test test/holdouts/idempotence_check_test.dart

# U15a live-device runner — interactive bash walkthrough that captures
# pre/post/re-meet snapshots and runs the verdict at the end. Requires
# both phones already booted via `app-run-a` / `app-run-b`.
holdout-34:
    tools/holdout_34/runner.sh

# U15a verdict CLI — standalone PASS/FAIL on a set of snapshot JSONs.
# Use this when re-running the math on already-captured evidence (e.g.,
# a post-mortem on a recorded artifact). Pass paths as a single env var
# block; --ci toggles JSON-only output. Example:
#   PRE_A=/tmp/a-pre.json PRE_B=/tmp/b-pre.json \
#   POST_A=/tmp/a-post.json POST_B=/tmp/b-post.json \
#   REMEET_A=/tmp/a-remeet.json REMEET_B=/tmp/b-remeet.json \
#   just holdout-34-verdict
holdout-34-verdict:
    dart run tools/holdout_34/verdict.dart \
      --pre-a "$PRE_A" --pre-b "$PRE_B" \
      --post-a "$POST_A" --post-b "$POST_B" \
      --remeet-a "$REMEET_A" --remeet-b "$REMEET_B"

# U15b pre-demo offline-witness checklist — opens the markdown so the
# demonstrator can walk it before each recording take. No-op
# automation; the checklist is the artifact.
holdout-7-witness:
    $EDITOR tools/holdout_7/offline_witness.md

# ─── U12 demo recipes — Holdout 1 dry-run flags ────────────────────────────
#
# Wraps app-run-a / app-run-b with the U12 demo flags pre-set:
#   - DEMO_OVERLAY=true        → top-right HUD (peer count, note count, latency)
#   - INITIAL_TOPIC="Saturn"   → topic field pre-filled per _docs/demo-script.md
#
# Pass the rehearsed topic as the second argument to override, e.g.
#   just app-run-a-demo <device-id> "Jupiter's moons"

app-run-a-demo DEVICE TOPIC="Saturn":
    flutter run -d {{DEVICE}} \
      --dart-define=DITTO_APP_ID="$DITTO_APP_ID" \
      --dart-define=DITTO_LICENSE="$DITTO_LICENSE" \
      --dart-define=PHONE_ROLE=a \
      --dart-define=DEMO_OVERLAY=true \
      --dart-define=INITIAL_TOPIC="{{TOPIC}}"

app-run-b-demo DEVICE TOPIC="Saturn":
    flutter run -d {{DEVICE}} \
      --dart-define=DITTO_APP_ID="$DITTO_APP_ID" \
      --dart-define=DITTO_LICENSE="$DITTO_LICENSE" \
      --dart-define=PHONE_ROLE=b \
      --dart-define=DEMO_OVERLAY=true \
      --dart-define=INITIAL_TOPIC="{{TOPIC}}"

# ─── Seed-embedding bake (R5 cold-load lever) ──────────────────────────────
#
# Run app with BAKE_EMBEDDINGS=true. Boots normally, runs ensureEmbeddings,
# then writes the embedded JSON to the device's app documents directory.
# Path is logged at the end of boot (look for "[BakeEmbeddings] wrote ...").
#
# Workflow:
#   1. Edit assets/seed_notes_a.json (add / edit a note).
#   2. just bake-seeds-a <android-device-id>
#   3. Stop the app once you see the "[BakeEmbeddings] wrote ..." log line.
#   4. just bake-seeds-pull-a   # adb-pulls + overwrites the asset.
#   5. Repeat for role=b.
#   6. Commit the asset diff.
#
# Drops cold-load by ~9.7s on Pixel 6a (78% of total). See
# _docs/model-quirks.md (R5 lever §) for the deeper story.

bake-seeds-a DEVICE:
    flutter run -d {{DEVICE}} \
      --dart-define=DITTO_APP_ID="$DITTO_APP_ID" \
      --dart-define=DITTO_LICENSE="$DITTO_LICENSE" \
      --dart-define=PHONE_ROLE=a \
      --dart-define=BAKE_EMBEDDINGS=true

bake-seeds-b DEVICE:
    flutter run -d {{DEVICE}} \
      --dart-define=DITTO_APP_ID="$DITTO_APP_ID" \
      --dart-define=DITTO_LICENSE="$DITTO_LICENSE" \
      --dart-define=PHONE_ROLE=b \
      --dart-define=BAKE_EMBEDDINGS=true

# Pull the baked seed JSON off Android and overwrite the asset. Uses
# `run-as` so it works without root on debuggable builds.
#
# Resolves `adb` from $PATH first, then falls back to the macOS Android
# Studio default install location. If neither hits, prints a clear
# error pointing at the setup the dev needs to do once.
bake-seeds-pull-a:
    #!/usr/bin/env bash
    set -euo pipefail
    ADB="$(command -v adb 2>/dev/null || echo "$HOME/Library/Android/sdk/platform-tools/adb")"
    if [ ! -x "$ADB" ]; then
      echo "error: adb not found in PATH or at $ADB." >&2
      echo "Add Android SDK platform-tools to PATH, e.g. in ~/.zshrc:" >&2
      echo "  export PATH=\"\$HOME/Library/Android/sdk/platform-tools:\$PATH\"" >&2
      exit 1
    fi
    REMOTE_PATH="app_flutter/seed_notes_a_baked.json"
    # Write to a temp file first so a failed pull doesn't truncate the
    # asset. mv only runs if the cat succeeded and produced bytes.
    TMP="$(mktemp)"
    trap 'rm -f "$TMP"' EXIT
    "$ADB" exec-out run-as com.dittoxcactus.mesh_rag cat "$REMOTE_PATH" > "$TMP"
    if [ ! -s "$TMP" ]; then
      echo "error: pulled file is empty. Did the bake step run? Check the device:" >&2
      echo "  $ADB shell run-as com.dittoxcactus.mesh_rag ls $REMOTE_PATH" >&2
      exit 1
    fi
    mv "$TMP" assets/seed_notes_a.json
    echo "✓ assets/seed_notes_a.json updated. Diff with git diff."

bake-seeds-pull-b:
    #!/usr/bin/env bash
    set -euo pipefail
    ADB="$(command -v adb 2>/dev/null || echo "$HOME/Library/Android/sdk/platform-tools/adb")"
    if [ ! -x "$ADB" ]; then
      echo "error: adb not found in PATH or at $ADB." >&2
      echo "Add Android SDK platform-tools to PATH, e.g. in ~/.zshrc:" >&2
      echo "  export PATH=\"\$HOME/Library/Android/sdk/platform-tools:\$PATH\"" >&2
      exit 1
    fi
    REMOTE_PATH="app_flutter/seed_notes_b_baked.json"
    TMP="$(mktemp)"
    trap 'rm -f "$TMP"' EXIT
    "$ADB" exec-out run-as com.dittoxcactus.mesh_rag cat "$REMOTE_PATH" > "$TMP"
    if [ ! -s "$TMP" ]; then
      echo "error: pulled file is empty. Did the bake step run? Check the device:" >&2
      echo "  $ADB shell run-as com.dittoxcactus.mesh_rag ls $REMOTE_PATH" >&2
      exit 1
    fi
    mv "$TMP" assets/seed_notes_b.json
    echo "✓ assets/seed_notes_b.json updated. Diff with git diff."
