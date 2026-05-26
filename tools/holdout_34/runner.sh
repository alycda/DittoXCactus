#!/usr/bin/env bash
#
# Holdout 3 + 4 runner — manual-checklist downgrade.
#
# Per plan §U15a: the runner can be a Maestro/XCTest orchestrator OR a
# manual checklist. We ship the checklist because for a two-phone
# hackathon demo the orchestration overhead would dwarf the holdout
# itself. The script walks a human demonstrator through:
#
#   1. Pre-meet snapshot capture on A and B (corpora disjoint by seed).
#   2. BLE meet — wait for `mesh: 1 peer` on both devices.
#   3. Post-meet snapshot capture on A and B.
#   4. Re-meet (Wi-Fi off → on; BT off → on) WITHOUT authoring any
#      new notes.
#   5. Post-re-meet snapshot capture on A and B.
#   6. Verdict CLI invocation (R3 + R4 PASS/FAIL).
#
# Snapshots are JSON dumps of the on-device notes corpus — list of
# `StudyNote.toDittoDoc()`-shaped maps. The fastest way to capture one
# is the in-app "Notes" tab's long-press → "export corpus" action
# (U10), or `adb shell run-as com.dittoxcactus.mesh_rag cat …` for the
# pre-baked seed JSONs in app-private storage.
#
# Re-running the script picks up an existing run directory (one per
# `--run`); each phase clobbers its own snapshot. Sign-off is the
# `signed_off_by` field at the bottom of the run's evidence.json
# (written manually after the verdict passes).

set -euo pipefail

RUN_NAME="${RUN_NAME:-$(date -u +"%Y-%m-%dT%H-%M-%SZ")}"
RUN_DIR="${RUN_DIR:-tools/holdout_34/runs/$RUN_NAME}"
mkdir -p "$RUN_DIR"

# ─── helpers ────────────────────────────────────────────────────────────────

step() {
  echo
  echo "──────────────────────────────────────────────────────────────────"
  echo "  $1"
  echo "──────────────────────────────────────────────────────────────────"
}

prompt() {
  # Read a single 'enter' confirmation; --capture <path> mode also asks
  # the human to paste the file path of the snapshot they just captured.
  local msg="$1"
  read -r -p "$msg  [press enter to continue, q to quit] " reply
  if [[ "${reply:-}" == "q" ]]; then
    echo "aborted by user."
    exit 130
  fi
}

capture_path() {
  local label="$1"
  local target="$2"
  read -r -p "  paste path to $label snapshot JSON: " src
  if [[ -z "$src" || ! -f "$src" ]]; then
    echo "  error: file not found: $src" >&2
    exit 2
  fi
  cp "$src" "$target"
  echo "  ✓ copied to $target"
}

# ─── walkthrough ────────────────────────────────────────────────────────────

echo "Holdout 3 + 4 runner — run id: $RUN_NAME"
echo "Run dir:  $RUN_DIR"
echo "Plan:     _docs/plans/001-feat-mesh-rag-demo.md §U15a"
echo
echo "Requirements being verified:"
echo "  R3 — sync idempotence (re-meet → no diff, no top-k drift)"
echo "  R4 — bidirectional merge (post-meet, both devices hold the union)"

step "Phase 0 — preflight"
echo "Before starting, confirm:"
echo "  [ ] Both phones running release/debug build of mesh_rag"
echo "  [ ] Phone A boots with PHONE_ROLE=a (seed_notes_a.json corpus)"
echo "  [ ] Phone B boots with PHONE_ROLE=b (seed_notes_b.json corpus)"
echo "  [ ] Both 'mesh: alone' (peer count = 0) when this phase begins"
echo "  [ ] No edits will be made between Phase 3 and Phase 5"
prompt "ready?"

step "Phase 1 — capture PRE-meet snapshots"
echo "On each phone, while still 'mesh: alone':"
echo "  - long-press the corpus tab, choose 'export corpus JSON'"
echo "  - share the file off the device (AirDrop / Drive / adb pull)"
capture_path "phone A PRE-meet"  "$RUN_DIR/a-pre.json"
capture_path "phone B PRE-meet"  "$RUN_DIR/b-pre.json"

step "Phase 2 — meet over BLE"
echo "  - bring the phones into BLE range"
echo "  - watch the mesh-status pill on both: alone → '1 peer'"
echo "  - wait at least 5 seconds AFTER the peer count stabilizes for the"
echo "    note-count to settle (no further changes for 5 s)"
prompt "both phones showing '1 peer' and corpus has settled?"

step "Phase 3 — capture POST-meet snapshots"
capture_path "phone A POST-meet" "$RUN_DIR/a-post.json"
capture_path "phone B POST-meet" "$RUN_DIR/b-post.json"

step "Phase 4 — re-meet WITHOUT any authoring"
echo "  - on phone A, toggle Bluetooth off → on (or airplane on → off + BT on)"
echo "  - same on phone B"
echo "  - wait for 'mesh: 1 peer' again"
echo "  - DO NOT add, edit, or accept any notes in this window"
prompt "both phones re-paired and stable?"

step "Phase 5 — capture POST-RE-MEET snapshots"
capture_path "phone A POST-RE-MEET" "$RUN_DIR/a-remeet.json"
capture_path "phone B POST-RE-MEET" "$RUN_DIR/b-remeet.json"

step "Phase 6 — verdict"
VERDICT_JSON="$RUN_DIR/verdict.json"
set +e
dart run tools/holdout_34/verdict.dart \
  --pre-a    "$RUN_DIR/a-pre.json"    --pre-b    "$RUN_DIR/b-pre.json" \
  --post-a   "$RUN_DIR/a-post.json"   --post-b   "$RUN_DIR/b-post.json" \
  --remeet-a "$RUN_DIR/a-remeet.json" --remeet-b "$RUN_DIR/b-remeet.json" \
  --ci > "$VERDICT_JSON"
VERDICT_EXIT=$?
set -e

echo "Verdict written to $VERDICT_JSON (exit $VERDICT_EXIT)"
cat "$VERDICT_JSON"
echo

# Human-readable rerun for the demonstrator's eyes.
dart run tools/holdout_34/verdict.dart \
  --pre-a    "$RUN_DIR/a-pre.json"    --pre-b    "$RUN_DIR/b-pre.json" \
  --post-a   "$RUN_DIR/a-post.json"   --post-b   "$RUN_DIR/b-post.json" \
  --remeet-a "$RUN_DIR/a-remeet.json" --remeet-b "$RUN_DIR/b-remeet.json" \
  || true

if [[ "$VERDICT_EXIT" -eq 0 ]]; then
  echo
  echo "✅ holdout_34 PASS"
  echo "Sign-off step: edit $RUN_DIR/sign-off.md and add demonstrator + date."
  cat > "$RUN_DIR/sign-off.md" <<MD
# holdout_34 sign-off — $RUN_NAME

- R3 (sync idempotence): PASS
- R4 (bidirectional merge): PASS

Verdict JSON: \`verdict.json\` (in this directory)
Snapshots: \`a-pre.json\`, \`b-pre.json\`, \`a-post.json\`, \`b-post.json\`, \`a-remeet.json\`, \`b-remeet.json\`

**Demonstrator (fill in):**
- name:
- date (UTC):
- hardware pair: iPhone <model> ↔ Pixel <model>
- mesh_rag build commit (\`git rev-parse HEAD\`):
- Ditto version (\`pubspec.lock\` ditto_live):
- notes (any deviation from the script):
MD
  exit 0
else
  echo
  echo "❌ holdout_34 FAIL — inspect $VERDICT_JSON for the failing axis"
  exit 1
fi
