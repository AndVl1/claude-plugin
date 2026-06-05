#!/usr/bin/env bash
# team-nudge.sh — UserPromptSubmit hook.
#
# Fires when the user invokes /team (or /fullstack-team:team) and injects a reminder to run
# the interpreter's Step A *before any other tool*. This catches the #1 failure mode: the
# model treats /team like a normal request and starts investigating/implementing inline
# (git diff, Read, Bash) — skipping classification, the profile, the consilium, and leaving
# the determinism/DoD gates dormant (they only arm once team-state.json exists).
#
# UserPromptSubmit contract: prompt JSON arrives on stdin; whatever this prints on stdout is
# added to the model's context. Always exits 0 (never blocks a prompt).
#
# Test override: pass the prompt as $1, or pipe JSON / raw text on stdin.

set -u

PROMPT="${1:-}"
if [ -z "$PROMPT" ]; then
  RAW="$(cat 2>/dev/null)"
  if command -v jq >/dev/null 2>&1 && printf '%s' "$RAW" | jq empty >/dev/null 2>&1; then
    PROMPT="$(printf '%s' "$RAW" | jq -r '.prompt // .user_prompt // empty' 2>/dev/null)"
  fi
  [ -z "$PROMPT" ] && PROMPT="$RAW"
fi

# Only nudge on a /team invocation (not /team-next, which is its own controlled flow).
if printf '%s' "$PROMPT" | grep -qE 'fullstack-team:team-next|(^|[[:space:]])/team-next'; then
  exit 0
fi
if ! printf '%s' "$PROMPT" | grep -qE 'fullstack-team:team|(^|[[:space:]])/team([[:space:]]|$)'; then
  exit 0
fi

cat <<'EOF'
🧭 /team — run the WORKFLOW INTERPRETER. BEFORE any git/Read/Bash/Task:
  1. Classify (type, complexity, confidence) → resolve the workflow profile (workflows/README.md table).
  2. Write .work-state/team-state.json (classification + workflow + stages[]) — this arms the
     validate-state (P5) and dod-gate (P8) hooks; without it they stay dormant.
  3. If a team-state from another task/branch is lying around, archive it — don't inherit it.
  Then walk workflows/<profile>.json, reading workflows/stages/<id>.md per stage. Do NOT do
  the task inline. consilium stages = launch all roles in ONE message (parallel Task fan-out).
EOF
exit 0
