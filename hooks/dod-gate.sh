#!/usr/bin/env bash
# dod-gate.sh — Definition-of-Done backstop, runs as a Stop hook.
#
# Blocks a "done" claim (exit 2) when a task that reached completion has an incomplete DoD.
# This is the deterministic backstop behind the profile's `dod_complete` gate — it reads the
# typed dod artifact (.work-state/artifacts/dod.json), never greps prose, so it does not drift
# with the human-readable team-state.md.
#
# NEVER wedge the user. Stop is allowed (exit 0) in every legitimate pause:
#   - no JSON state / no jq / unparseable     → not our concern
#   - stale state (state branch != current)   → another task's leftover
#   - pause.kind in background_wait | user_checkpoint | needs_human | failed
#   - override marker .work-state/.dod-override present
#   - workflow in research | review | emergency (no implementation / urgent escape)
#   - not claiming done yet (cursor not at summary and pause.kind != done)
#
# Only a genuine done-claim with an unmet DoD blocks. The block message tells the model
# exactly how to proceed.
#
# Test overrides: TEAM_STATE_JSON, DOD_JSON, CURRENT_BRANCH, OVERRIDE_FILE.

set -u

STATE="${TEAM_STATE_JSON:-.work-state/team-state.json}"
DOD="${DOD_JSON:-.work-state/artifacts/dod.json}"
OVERRIDE="${OVERRIDE_FILE:-.work-state/.dod-override}"

# No machine state → markdown-only/legacy flow; the legacy Stop hook handles it. Allow.
[ -f "$STATE" ] || exit 0

command -v jq >/dev/null 2>&1 || exit 0
jq empty "$STATE" >/dev/null 2>&1 || exit 0

# Override marker → always allow (mandatory escape hatch).
if [ -f "$OVERRIDE" ]; then
  echo "ℹ️  dod-gate: .dod-override present — DoD enforcement skipped for this stop."
  exit 0
fi

WORKFLOW=$(jq -r '.classification.workflow // .workflow // ""' "$STATE")
PAUSE=$(jq -r '.pause.kind // "none"' "$STATE")
CURSOR=$(jq -r '.stage_cursor // ""' "$STATE")
STATE_BRANCH=$(jq -r '.branch // .classification.branch // ""' "$STATE")

# Staleness: state stamped with a branch that isn't the current one → leftover from another task.
if [ -n "$STATE_BRANCH" ]; then
  CUR="${CURRENT_BRANCH:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null)}"
  if [ -n "$CUR" ] && [ "$CUR" != "$STATE_BRANCH" ]; then
    echo "ℹ️  dod-gate: team-state.json branch '$STATE_BRANCH' != current '$CUR' — stale state, DoD not enforced. Archive it: mv .work-state/team-state.json .work-state/archive/"
    exit 0
  fi
fi

# Workflows without an implementation phase, or the urgent-escape hotfix, are exempt.
case "$WORKFLOW" in
  research|review|emergency) exit 0 ;;
esac

# Legitimate intentional pauses → allow.
case "$PAUSE" in
  background_wait|user_checkpoint|needs_human|failed) exit 0 ;;
esac

# Claiming done? Only enforce at the finish line, never mid-work (no nagging).
CLAIMING_DONE="no"
[ "$PAUSE" = "done" ] && CLAIMING_DONE="yes"
[ "$CURSOR" = "summary" ] && CLAIMING_DONE="yes"
[ "$CLAIMING_DONE" = "yes" ] || exit 0

# ── enforce DoD ─────────────────────────────────────────────────────────────────
if [ ! -f "$DOD" ] || ! jq empty "$DOD" >/dev/null 2>&1; then
  echo "🚫 BLOCK (DoD): task is claiming done but .work-state/artifacts/dod.json is missing or invalid."
  echo "    Write the Definition of Done (acceptance criteria + verify_method per item, fixed during exploration/diagnose)."
  echo "    To pause instead of finishing, set team-state.json .pause.kind to background_wait|user_checkpoint|needs_human|failed."
  echo "    To override deliberately: touch .work-state/.dod-override"
  exit 2
fi

# Items that are not met, or 'met' without evidence.
OPEN=$(jq -r '[.items[] | select((.status != "met") or ((.evidence // "") | length == 0))] | length' "$DOD")
TYPE_OK=$(jq -r '.type_requirements_met // false' "$DOD")

if [ "$OPEN" != "0" ]; then
  echo "🚫 BLOCK (DoD): $OPEN DoD item(s) are unmet or marked met without evidence."
  echo "    Close each with proof: a screenshot WITH what is visible on it, a gist URL, test output, curl result, or a named root cause."
  jq -r '.items[] | select((.status != "met") or ((.evidence // "") | length == 0)) | "      - [" + (.status // "pending") + "] " + .criterion + "  (verify: " + (.verify_method // "?") + ")"' "$DOD"
  echo "    Genuinely blocked (no env, creds)? Set .pause.kind=needs_human, or: touch .work-state/.dod-override"
  exit 2
fi

if [ "$TYPE_OK" != "true" ]; then
  echo "🚫 BLOCK (DoD): dod.type_requirements_met is not true — the per-task-type minimum criteria are not confirmed present (see workflows/artifacts-schema.json)."
  echo "    e.g. BUG_FIX needs a named root cause + repro before/after; any UI needs 'what must be visible' recorded."
  exit 2
fi

# DoD satisfied. Soft §5 reminder (cannot be hard-enforced from a hook).
echo "✅ dod-gate: DoD complete. Reminder: publish reports via the publish-gist-report skill and invoke required skills before the action, not from memory."
exit 0
