#!/usr/bin/env bash
# resolve-state-path.sh — echoes the active state.json path, or empty.
#
# Per-task state files: hoisted out of the .work-state/ root into per-feature subdirs so
# parallel tasks don't trample each other (manual-qa on branch A while the implementer
# runs branch B, etc.). Resolution order, mirroring the legacy-fallback idiom so the
# v2.4.x single-state layout stays working:
#
#   1. .work-state/.active-feature (a single-line file containing a feature slug) and
#      .work-state/features/<slug>/state.json existing → that file.
#   2. .work-state/team-state.json existing (legacy) → that file.
#   3. Neither → empty string. The calling hook falls through to its "no state → allow"
#      branch with no extra failure mode.
#
# Per-feature subdir is named "state.json" (not "team-state.json") so callers can tell
# the new convention from the legacy convention. Hooks must call this once and use
# dirname() to locate sibling files (artifacts/dod.json, team-state.md) — keeps the
# resolution logic in one place.
#
# Test override: WORK_STATE_DIR to point at a sandbox.

set -u

WS="${WORK_STATE_DIR:-.work-state}"

# 1) Active feature (per-feature subdir convention — new)
if [ -f "$WS/.active-feature" ]; then
  SLUG="$(tr -d '[:space:]' < "$WS/.active-feature" 2>/dev/null || true)"
  if [ -n "$SLUG" ] && [ -f "$WS/features/$SLUG/state.json" ]; then
    echo "$WS/features/$SLUG/state.json"
    exit 0
  fi
fi

# 2) Legacy single-state at .work-state/ root (existing project default — kept so
#    v2.4.x state flows without forcing users to migrate).
if [ -f "$WS/team-state.json" ]; then
  echo "$WS/team-state.json"
  exit 0
fi

# 3) None
echo ""
