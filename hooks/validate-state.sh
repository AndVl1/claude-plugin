#!/usr/bin/env bash
# validate-state.sh — deterministic state gate for the /team interpreter.
#
# Runs as a PreToolUse(Task) hook. Two checks against .work-state/team-state.json:
#   P5  classification gate: classification.{type,complexity} must be present, and the
#       resolved `workflow` must match the Type×Complexity→Workflow table (workflows/README.md).
#   P4  transition gate: stage progress must be monotonic — no stage left `pending`
#       while a later stage is already `done`/`in_progress` (catches phase-skipping).
#
# Design: NEVER brick the user. Missing jq, missing/legacy markdown-only state, or a parse
# error all degrade to exit 0 (allow + optional note). Only a *clear* inconsistency in a
# present, parseable JSON state blocks (exit 2). An explicit "workflow_override": true in the
# state disables the P5 check for intentional manual overrides.
#
# Test override: set TEAM_STATE_JSON to point at a state file.

set -u

STATE="${TEAM_STATE_JSON:-.work-state/team-state.json}"
STATE_MD="${TEAM_STATE_MD:-.work-state/team-state.md}"

# No JSON state. If a markdown state exists, the run is on the legacy flow and the
# determinism/DoD gates are DORMANT (they key off team-state.json) — nudge to migrate.
# Either way, allow (never block the legacy path).
if [ ! -f "$STATE" ]; then
  if [ -f "$STATE_MD" ]; then
    echo "ℹ️  validate-state: launching agents with team-state.md but no team-state.json — the P4/P5/P8 gates are DORMANT. Write .work-state/team-state.json (classification + workflow + stages) to activate deterministic enforcement."
  fi
  exit 0
fi

# No jq → cannot validate deterministically. Note once, allow.
if ! command -v jq >/dev/null 2>&1; then
  echo "ℹ️  validate-state: jq not found — skipping deterministic state validation (install jq for full P4/P5 enforcement)."
  exit 0
fi

# Unparseable JSON → don't block work over a transient write. Warn, allow.
if ! jq empty "$STATE" >/dev/null 2>&1; then
  echo "⚠️  validate-state: team-state.json is not valid JSON — skipping validation."
  exit 0
fi

TYPE=$(jq -r '.classification.type // ""' "$STATE")
COMPLEXITY=$(jq -r '.classification.complexity // ""' "$STATE")
WORKFLOW=$(jq -r '.classification.workflow // .workflow // ""' "$STATE")
AUTONOMOUS=$(jq -r '.autonomous // false' "$STATE")
OVERRIDE=$(jq -r '.workflow_override // false' "$STATE")

# ── P5: classification gate ─────────────────────────────────────────────────────
if [ -z "$TYPE" ]; then
  echo "🚫 BLOCK (P5): team-state.json has no classification.type. Classify the request and write the CLASSIFICATION block to state BEFORE launching agents."
  exit 2
fi

# expected workflow from Type × Complexity (mirrors workflows/README.md)
expected_workflow() {
  local t="$1" c="$2" auto="$3"
  case "$t" in
    FEATURE|REFACTOR)
      case "$c" in
        QUICK) echo "lightweight" ;;
        MEDIUM) echo "standard" ;;
        COMPLEX|CRITICAL) echo "full-feature" ;;
        *) echo "standard" ;;
      esac ;;
    OPS)
      case "$c" in QUICK) echo "lightweight" ;; *) echo "standard" ;; esac ;;
    BUG_FIX)
      if [ "$auto" = "true" ]; then echo "debug-cycle"
      elif [ "$c" = "QUICK" ]; then echo "bug-fix"
      else echo "debug-cycle"; fi ;;
    INVESTIGATION) echo "research" ;;
    REVIEW) echo "review" ;;
    HOTFIX) echo "emergency" ;;
    *) echo "" ;;  # unknown type → no expectation (lenient)
  esac
}

EXPECTED=$(expected_workflow "$TYPE" "$COMPLEXITY" "$AUTONOMOUS")

if [ "$OVERRIDE" != "true" ] && [ -n "$EXPECTED" ] && [ -n "$WORKFLOW" ] && [ "$WORKFLOW" != "$EXPECTED" ]; then
  echo "🚫 BLOCK (P5): workflow '$WORKFLOW' does not match classification (type=$TYPE complexity=$COMPLEXITY autonomous=$AUTONOMOUS → expected '$EXPECTED')."
  echo "    Fix the workflow in team-state.json, or set \"workflow_override\": true to override intentionally."
  exit 2
fi

# ── P4: transition gate (monotonic stage progress) ──────────────────────────────
# Violation: a stage with status 'pending' precedes a stage with status 'done' or 'in_progress'.
# 'skipped' is allowed anywhere. Only checked when a stages[] array is present.
HAS_STAGES=$(jq -r 'if (.stages | type) == "array" then "yes" else "no" end' "$STATE")
if [ "$HAS_STAGES" = "yes" ]; then
  VIOLATION=$(jq -r '
    [.stages[].status // "pending"] as $s
    | ($s | index("pending")) as $firstPending
    | if $firstPending == null then "ok"
      else
        ([ $s[($firstPending+1):][] | select(. == "done" or . == "in_progress") ] | length) as $after
        | if $after > 0 then "violation" else "ok" end
      end
  ' "$STATE")
  if [ "$VIOLATION" = "violation" ]; then
    echo "🚫 BLOCK (P4): stage progress is not monotonic in team-state.json — a later stage is done/in_progress while an earlier stage is still pending."
    echo "    Update stages[] to reflect reality (mark skipped stages 'skipped', not 'pending') before launching agents."
    exit 2
  fi
fi

exit 0
