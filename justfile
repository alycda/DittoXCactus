# Build the Likec4 dashboard at docs/c4/dashboard/ (gitignored — rerun on fresh checkouts or after editing model.c4).
c4-build:
    npx --yes likec4@latest build docs/c4 -o docs/c4/dashboard

# Build (if missing) then serve the C4 dashboard at http://localhost:8000.
[working-directory: 'docs/c4/dashboard']
c4-model: c4-build
    python3 -m http.server 8000

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
