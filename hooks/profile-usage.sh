#!/usr/bin/env bash
# profile-usage.sh — PostToolUse(Task) telemetry for the coordinator.
#
# Appends one JSONL line per agent launch to
#   <work-state>/coordinator/<project-slug>/profile-usage.jsonl
# so /coordinator-stats can roll up which profiles / stages actually get used across
# sessions and propose new named profiles for recurring shapes.
#
# Never blocks (always exit 0) — this is best-effort telemetry, not a gate. Degrades to a
# silent no-op with no state, no jq, or unparseable state.
#
# Test overrides: WORK_STATE_DIR (sandbox root), COORD_SLUG (project slug).

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WS="${WORK_STATE_DIR:-.work-state}"

STATE="$(bash "$SCRIPT_DIR/resolve-state-path.sh" 2>/dev/null)"
STATE="${STATE:-$WS/team-state.json}"

# No machine state → nothing to record. Allow.
[ -f "$STATE" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0
jq empty "$STATE" >/dev/null 2>&1 || exit 0

SLUG="${COORD_SLUG:-$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")}"
DIR="$WS/coordinator/$SLUG"
mkdir -p "$DIR" 2>/dev/null || exit 0

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)"
WORKFLOW=$(jq -r '.classification.workflow // .workflow // ""' "$STATE")
TYPE=$(jq -r '.classification.type // ""' "$STATE")
COMPLEXITY=$(jq -r '.classification.complexity // ""' "$STATE")
CURSOR=$(jq -r '.stage_cursor // ""' "$STATE")
BRANCH=$(jq -r '.branch // .classification.branch // ""' "$STATE")

jq -cn \
  --arg ts "$TS" --arg wf "$WORKFLOW" --arg ty "$TYPE" \
  --arg cx "$COMPLEXITY" --arg st "$CURSOR" --arg br "$BRANCH" \
  '{ts:$ts, workflow:$wf, type:$ty, complexity:$cx, stage:$st, branch:$br}' \
  >> "$DIR/profile-usage.jsonl" 2>/dev/null || true

exit 0
