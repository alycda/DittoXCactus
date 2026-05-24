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

# ─── U1 determinism harness (tools/determinism_harness/) ───────────────────

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

# Compare two per-device measurement JSONs (extracted from harness-measure
# logs or pulled off the devices). Exit 0 if R2 gate clears (>=0.95).
[working-directory: 'tools/determinism_harness']
harness-check A B:
    dart run run.dart check {{A}} {{B}}

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
