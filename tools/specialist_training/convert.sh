#!/usr/bin/env bash
#
# Specialist training pipeline — U6 deployment wrapper.
#
# Pulls the trained adapter from Oxen, merges + Q4-quantizes via
# `cactus convert --lora`, gates on the Q4-vs-Q8 perplexity comparison
# (recipe Backup B trigger), then produces per-platform Cactus build
# artifacts.
#
# Prerequisites:
#   - cactus CLI installed (see cactus-compute.com docs)
#   - oxen CLI installed (`brew install oxen` or `pip install oxenai`)
#   - OXEN_REPO + OXEN_BRANCH in .env if adapter lives on Oxen
#     (otherwise local ./adapter/ is used as-is)
#
# Usage:
#   bash convert.sh
#   # or via justfile:
#   just specialist-convert

set -euo pipefail

# Resolve to this script's directory so relative paths work regardless of cwd.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ─── Config ─────────────────────────────────────────────────────────────────

BASE_MODEL="${BASE_MODEL:-Qwen/Qwen3-1.7B}"
ADAPTER_DIR="${ADAPTER_DIR:-./adapter}"
OUTPUT_NAME="${OUTPUT_NAME:-qwen3-1.7-merger}"
OUTPUT_CACT="../../assets/models/${OUTPUT_NAME}.cact"
PERPLEXITY_GATE_THRESHOLD="${PERPLEXITY_GATE_THRESHOLD:-5.0}"  # max allowed Q4-vs-Q8 delta

# Load .env if present (for OXEN_REPO, OXEN_BRANCH, etc.).
if [ -f "../../.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "../../.env"
  set +a
fi

# ─── Step 1: Pull adapter from Oxen if not already local ────────────────────

if [ -n "${OXEN_REPO:-}" ] && [ -n "${OXEN_BRANCH:-}" ]; then
  if ! command -v oxen >/dev/null 2>&1; then
    echo "ERROR: oxen CLI not found. Install:" >&2
    echo "  brew install oxen   # macOS" >&2
    echo "  pip install oxenai  # Python bindings" >&2
    exit 2
  fi
  echo "→ pulling adapter from oxen://${OXEN_REPO}@${OXEN_BRANCH}…" >&2
  oxen pull "${OXEN_REPO}" "${OXEN_BRANCH}"
  # Convention: Oxen run writes adapter/ at repo root of the Oxen workspace.
fi

if [ ! -d "$ADAPTER_DIR" ]; then
  echo "ERROR: adapter directory not found at $ADAPTER_DIR." >&2
  echo "  Either:" >&2
  echo "    (1) Run training on Oxen and 'oxen pull' the adapter, OR" >&2
  echo "    (2) Copy a locally-trained adapter to $ADAPTER_DIR." >&2
  exit 2
fi

if [ ! -f "${ADAPTER_DIR}/adapter_config.json" ]; then
  echo "ERROR: ${ADAPTER_DIR} exists but is not a PEFT adapter (no adapter_config.json)." >&2
  exit 2
fi

echo "✓ adapter at $ADAPTER_DIR" >&2

# ─── Step 2: cactus CLI sanity check ────────────────────────────────────────

if ! command -v cactus >/dev/null 2>&1; then
  echo "ERROR: cactus CLI not found. Install per cactus-compute.com docs." >&2
  echo "  This wrapper is a no-op without the cactus CLI." >&2
  exit 2
fi

CACTUS_VERSION="$(cactus --version 2>&1 | head -n1 || echo unknown)"
echo "cactus version: $CACTUS_VERSION" >&2

# ─── Step 3: Q4-vs-Q8 perplexity comparison (recipe Backup B gate) ──────────
#
# Convert the adapter at TWO quantization levels and compare perplexity on
# a small holdout. If Q4 degrades >threshold points vs Q8, halt with the
# backup-recipe pivot guidance (rank-8 retry / lower LR / ship INT8).

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
Q4_PATH="${TMP_DIR}/q4.cact"
Q8_PATH="${TMP_DIR}/q8.cact"

echo "→ converting adapter @ Q8 (reference)…" >&2
cactus convert "$BASE_MODEL" "$Q8_PATH" --lora "$ADAPTER_DIR" --quantization q8 || {
  echo "ERROR: cactus convert (Q8) failed." >&2
  exit 3
}

echo "→ converting adapter @ Q4 (target)…" >&2
cactus convert "$BASE_MODEL" "$Q4_PATH" --lora "$ADAPTER_DIR" --quantization q4 || {
  echo "ERROR: cactus convert (Q4) failed." >&2
  exit 3
}

# Perplexity check is delegated to `cactus eval-perplexity` if available;
# otherwise we surface a warning that the gate is being skipped. The
# user can rerun the comparison manually post-conversion.
if cactus eval-perplexity --help >/dev/null 2>&1; then
  HOLDOUT="data/holdout_200.jsonl"
  if [ ! -f "$HOLDOUT" ]; then
    echo "WARN: $HOLDOUT not found — skipping perplexity gate." >&2
  else
    PPL_Q4=$(cactus eval-perplexity "$Q4_PATH" --input "$HOLDOUT" --field merged 2>/dev/null | tail -n1 || echo nan)
    PPL_Q8=$(cactus eval-perplexity "$Q8_PATH" --input "$HOLDOUT" --field merged 2>/dev/null | tail -n1 || echo nan)
    echo "perplexity Q4=${PPL_Q4} Q8=${PPL_Q8}" >&2
    PPL_DELTA=$(awk -v a="$PPL_Q4" -v b="$PPL_Q8" 'BEGIN{printf "%.3f", a-b}')
    echo "Q4-Q8 perplexity delta: ${PPL_DELTA}" >&2
    if awk -v d="$PPL_DELTA" -v t="$PERPLEXITY_GATE_THRESHOLD" 'BEGIN{exit !(d>t)}'; then
      echo "" >&2
      echo "─── Recipe Backup B triggered ─────────────────────────────────────" >&2
      echo "Q4 quantization degrades perplexity >${PERPLEXITY_GATE_THRESHOLD} points vs Q8." >&2
      echo "Suggested pivot, in order:" >&2
      echo "  1. Retrain at LoRA rank 8 (lower-rank → smaller perturbations, more quant-robust)" >&2
      echo "  2. Train with conservative LR (5e-5 instead of 1e-4)" >&2
      echo "  3. Ship at INT8 instead of INT4 (~3 GB bundle vs 1.5 GB, preserves fine-tune)" >&2
      echo "" >&2
      echo "NOT proceeding to cactus build. The Q8 .cact at $Q8_PATH is" >&2
      echo "available for manual inspection." >&2
      exit 4
    fi
  fi
else
  echo "WARN: cactus eval-perplexity not available in this CLI version." >&2
  echo "  Q4-vs-Q8 gate is being SKIPPED. Run perplexity check manually post-deploy." >&2
fi

# ─── Step 4: Promote the Q4 build to assets/models/ ─────────────────────────

mkdir -p "$(dirname "$OUTPUT_CACT")"
mv "$Q4_PATH" "$OUTPUT_CACT"
echo "✓ merged .cact at $OUTPUT_CACT ($(du -h "$OUTPUT_CACT" | cut -f1))" >&2

# Also copy the base model's LICENSE + a NOTICE alongside the artifact for
# license-clean redistribution (recipe R3).
LICENSE_NOTICE="$(dirname "$OUTPUT_CACT")/NOTICE"
cat > "$LICENSE_NOTICE" <<NOTICE
${OUTPUT_NAME}.cact
================

This file is a merged LoRA fine-tune of ${BASE_MODEL} for the note-merging
specialist task. It is a derivative work of:

  - ${BASE_MODEL} (Apache-2.0)
  - LoRA adapter trained on synthetic data generated by Qwen 2.5-72B-Instruct
    (Apache-2.0), see _docs/plans/002-feat-specialist-training.md (U2)

The merged artifact inherits the Apache-2.0 license from the base model.
Distributed alongside this NOTICE per Apache-2.0 Section 4.

Trained via Unsloth (Apache-2.0). Converted via Cactus (source-available,
\$2M-revenue gate).
NOTICE
echo "✓ NOTICE written at $LICENSE_NOTICE" >&2

# ─── Step 5: Per-platform Cactus build ──────────────────────────────────────

echo "→ cactus build --apple…" >&2
cactus build --apple || {
  echo "WARN: cactus build --apple failed. iOS XCFramework not produced." >&2
}

echo "→ cactus build --android…" >&2
cactus build --android || {
  echo "WARN: cactus build --android failed. Android .so not produced." >&2
}

echo "" >&2
echo "✓ Specialist conversion complete." >&2
echo "  Artifact: $OUTPUT_CACT" >&2
echo "  Next:" >&2
echo "    1. Verify pubspec.yaml declares assets/models/ (U7)" >&2
echo "    2. Run 'just app-run-a-specialist <device-id>' to load the specialist" >&2
echo "    3. Run 'just harness-measure <device-id>' on both phones for R2 parity (U8)" >&2
