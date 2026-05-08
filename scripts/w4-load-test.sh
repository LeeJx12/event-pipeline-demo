#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$ROOT_DIR/infra/terraform"
EVIDENCE_DIR="$ROOT_DIR/docs/evidence/w4/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$EVIDENCE_DIR"

if ! command -v k6 >/dev/null 2>&1; then
  echo "ERROR: k6 is not installed. macOS: brew install k6" >&2
  exit 1
fi

TARGET_URL="${TARGET_URL:-$(cd "$TF_DIR" && terraform output -raw producer_url)}"
export TARGET_URL

echo "TARGET_URL=$TARGET_URL" | tee "$EVIDENCE_DIR/run.env"
echo "Evidence dir: $EVIDENCE_DIR"

k6 run \
  --summary-export "$EVIDENCE_DIR/k6-summary.json" \
  "$ROOT_DIR/k6/event-pipeline-load.js" \
  2>&1 | tee "$EVIDENCE_DIR/k6-output.log"

echo "Saved k6 output: $EVIDENCE_DIR"
