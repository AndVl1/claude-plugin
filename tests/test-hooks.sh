#!/usr/bin/env bash
# Cross-platform tests for hooks/hooks.json
# Validates JSON, extracts each hook command, runs scenarios, asserts behavior.

set -u

HOOKS_FILE="${HOOKS_FILE:-$(dirname "$0")/../hooks/hooks.json}"
HOOKS_FILE="$(cd "$(dirname "$HOOKS_FILE")" && pwd)/$(basename "$HOOKS_FILE")"

PASS=0
FAIL=0
FAILED_TESTS=()

log_pass() {
  echo "  PASS  $1"
  PASS=$((PASS + 1))
}

log_fail() {
  echo "  FAIL  $1"
  echo "        $2"
  FAIL=$((FAIL + 1))
  FAILED_TESTS+=("$1")
}

# get command by event + matcher
get_cmd() {
  local event="$1" matcher="$2"
  jq -r --arg e "$event" --arg m "$matcher" '
    .hooks[$e][] | select(.matcher == $m) | .hooks[0].command
  ' "$HOOKS_FILE" | head -1
}

# get command by event + index (for matcher-less hooks)
get_cmd_idx() {
  local event="$1" idx="$2"
  jq -r --arg e "$event" --argjson i "$idx" '
    .hooks[$e][$i].hooks[0].command
  ' "$HOOKS_FILE"
}

# get nth occurrence of matcher (for duplicated matchers like "Bash(git commit:*)")
get_cmd_n() {
  local event="$1" matcher="$2" n="$3"
  jq -r --arg e "$event" --arg m "$matcher" --argjson n "$n" '
    [.hooks[$e][] | select(.matcher == $m)][$n].hooks[0].command
  ' "$HOOKS_FILE"
}

# run command in sandbox dir with env, return exit + output via files
run_in_sandbox() {
  local sandbox="$1" cmd="$2"
  shift 2
  (
    cd "$sandbox" || exit 99
    env "$@" bash -c "$cmd"
  ) 2>&1
}

assert() {
  local name="$1" expected_exit="$2" expected_match="$3" actual_exit="$4" output="$5"
  if [ "$actual_exit" != "$expected_exit" ]; then
    log_fail "$name" "expected exit $expected_exit got $actual_exit | output: $output"
    return
  fi
  if [ -n "$expected_match" ] && ! echo "$output" | grep -qF "$expected_match"; then
    log_fail "$name" "missing '$expected_match' in: $output"
    return
  fi
  log_pass "$name"
}

# set state file mtime (cross-platform)
set_mtime() {
  local file="$1" age_seconds="$2"
  if [ "$(uname)" = "Darwin" ]; then
    touch -t "$(date -v -"${age_seconds}"S '+%Y%m%d%H%M.%S')" "$file"
  else
    touch -d "@$(($(date +%s) - age_seconds))" "$file"
  fi
}

# init throwaway git repo with branch
init_git() {
  local dir="$1" branch="$2"
  (
    cd "$dir" || exit
    git init -q -b "$branch" 2>/dev/null || { git init -q; git checkout -q -b "$branch"; }
    git config user.email "t@t"
    git config user.name "t"
    : > x
    git add x
    git commit -q -m init
  )
}

# ── tests ─────────────────────────────────────────────────────────────────────

echo "=== Validate JSON ==="
if jq empty "$HOOKS_FILE" 2>/dev/null; then
  log_pass "hooks.json is valid JSON"
else
  log_fail "hooks.json JSON validity" "jq parse failed"
  exit 1
fi

echo ""
echo "=== SessionStart ==="
cmd=$(get_cmd_idx SessionStart 0)
out=$(bash -c "$cmd"); ec=$?
assert "SessionStart prints banner" 0 "Dream Team" "$ec" "$out"

echo ""
echo "=== PostToolUse Write|Edit (changes.log) ==="
sb=$(mktemp -d)
cmd=$(get_cmd "PostToolUse" "Write|Edit")
out=$(run_in_sandbox "$sb" "$cmd" CLAUDE_FILE_PATH=foo.txt); ec=$?
if [ "$ec" = "0" ] && [ -f "$sb/.work-state/changes.log" ] && grep -q "Modified: foo.txt" "$sb/.work-state/changes.log"; then
  log_pass "PostToolUse Write|Edit writes changes.log"
else
  log_fail "PostToolUse Write|Edit writes changes.log" "ec=$ec log=$(cat "$sb/.work-state/changes.log" 2>/dev/null)"
fi
rm -rf "$sb"

echo ""
echo "=== PostToolUse Task (state staleness) ==="
cmd=$(get_cmd "PostToolUse" "Task")

# 1. no state file → silent
sb=$(mktemp -d)
out=$(run_in_sandbox "$sb" "$cmd"); ec=$?
assert "PostToolUse Task no state → silent" 0 "" "$ec" "$out"
rm -rf "$sb"

# 2. fresh state → silent
sb=$(mktemp -d)
mkdir -p "$sb/.work-state"
touch "$sb/.work-state/team-state.md"
out=$(run_in_sandbox "$sb" "$cmd"); ec=$?
if [ "$ec" = "0" ] && [ -z "$out" ]; then
  log_pass "PostToolUse Task fresh state → silent"
else
  log_fail "PostToolUse Task fresh state → silent" "ec=$ec out='$out'"
fi
rm -rf "$sb"

# 3. stale state (>300s) → warning
sb=$(mktemp -d)
mkdir -p "$sb/.work-state"
touch "$sb/.work-state/team-state.md"
set_mtime "$sb/.work-state/team-state.md" 600
out=$(run_in_sandbox "$sb" "$cmd"); ec=$?
assert "PostToolUse Task stale → warning" 0 "STATE REMINDER" "$ec" "$out"
rm -rf "$sb"

echo ""
echo "=== PreToolUse Write|Edit (sensitive files) ==="
cmd=$(get_cmd "PreToolUse" "Write|Edit")
out=$(CLAUDE_FILE_PATH=foo.txt bash -c "$cmd"); ec=$?
assert "PreToolUse Write|Edit safe file → pass" 0 "" "$ec" "$out"

out=$(CLAUDE_FILE_PATH=.env bash -c "$cmd"); ec=$?
assert "PreToolUse Write|Edit .env → block" 2 "BLOCK: Sensitive file" "$ec" "$out"

out=$(CLAUDE_FILE_PATH=path/credentials.json bash -c "$cmd"); ec=$?
assert "PreToolUse Write|Edit credentials → block" 2 "BLOCK: Sensitive file" "$ec" "$out"

out=$(CLAUDE_FILE_PATH=.secret-key bash -c "$cmd"); ec=$?
assert "PreToolUse Write|Edit .secret → block" 2 "BLOCK: Sensitive file" "$ec" "$out"

echo ""
echo "=== PreToolUse Task ==="
cmd=$(get_cmd "PreToolUse" "Task")

# 1. no state file → warning
sb=$(mktemp -d)
out=$(run_in_sandbox "$sb" "$cmd"); ec=$?
assert "PreToolUse Task no state → warn" 0 "No .work-state/team-state.md found" "$ec" "$out"
rm -rf "$sb"

# 2. fresh state → silent
sb=$(mktemp -d)
mkdir -p "$sb/.work-state"
touch "$sb/.work-state/team-state.md"
out=$(run_in_sandbox "$sb" "$cmd"); ec=$?
if [ "$ec" = "0" ] && [ -z "$out" ]; then
  log_pass "PreToolUse Task fresh state → silent"
else
  log_fail "PreToolUse Task fresh state → silent" "ec=$ec out='$out'"
fi
rm -rf "$sb"

# 3. stale state (>600s) → warning (THE LINUX BUG — must work on both OS)
sb=$(mktemp -d)
mkdir -p "$sb/.work-state"
touch "$sb/.work-state/team-state.md"
set_mtime "$sb/.work-state/team-state.md" 700
out=$(run_in_sandbox "$sb" "$cmd"); ec=$?
assert "PreToolUse Task stale state → warn (cross-OS stat)" 0 "not updated for" "$ec" "$out"
rm -rf "$sb"

# 4. fallback to .claude/team-state.md
sb=$(mktemp -d)
mkdir -p "$sb/.claude"
touch "$sb/.claude/team-state.md"
set_mtime "$sb/.claude/team-state.md" 700
out=$(run_in_sandbox "$sb" "$cmd"); ec=$?
assert "PreToolUse Task fallback to .claude/" 0 "not updated for" "$ec" "$out"
rm -rf "$sb"

echo ""
echo "=== PreToolUse Bash(git commit:*) — branch guard ==="
cmd=$(get_cmd_n "PreToolUse" "Bash(git commit:*)" 0)

sb=$(mktemp -d); init_git "$sb" main
out=$(run_in_sandbox "$sb" "$cmd"); ec=$?
assert "git commit on main → block" 2 "BLOCK: Direct commits to main" "$ec" "$out"
rm -rf "$sb"

sb=$(mktemp -d); init_git "$sb" production
out=$(run_in_sandbox "$sb" "$cmd"); ec=$?
assert "git commit on production → block" 2 "BLOCK: Direct commits" "$ec" "$out"
rm -rf "$sb"

sb=$(mktemp -d); init_git "$sb" feat/x
out=$(run_in_sandbox "$sb" "$cmd"); ec=$?
assert "git commit on feat/x → pass" 0 "" "$ec" "$out"
rm -rf "$sb"

echo ""
echo "=== PreToolUse Bash(git push:*) ==="
cmd=$(get_cmd "PreToolUse" "Bash(git push:*)")
sb=$(mktemp -d); init_git "$sb" feat/x

out=$(run_in_sandbox "$sb" "$cmd" CLAUDE_COMMAND="git push origin main"); ec=$?
assert "git push origin main → block" 2 "BLOCK: Direct push" "$ec" "$out"

out=$(run_in_sandbox "$sb" "$cmd" CLAUDE_COMMAND="git push origin production"); ec=$?
assert "git push origin production → block" 2 "BLOCK: Direct push" "$ec" "$out"

out=$(run_in_sandbox "$sb" "$cmd" CLAUDE_COMMAND="git push origin feat/x"); ec=$?
assert "git push origin feat/x → pass" 0 "" "$ec" "$out"
rm -rf "$sb"

echo ""
echo "=== PreToolUse Bash(gh pr merge:*) ==="
cmd=$(get_cmd "PreToolUse" "Bash(gh pr merge:*)")
out=$(bash -c "$cmd"); ec=$?
assert "gh pr merge → always block" 2 "BLOCK: PR merging" "$ec" "$out"

echo ""
echo "=== PreToolUse Bash(git merge:*) ==="
cmd=$(get_cmd "PreToolUse" "Bash(git merge:*)")

sb=$(mktemp -d); init_git "$sb" main
out=$(run_in_sandbox "$sb" "$cmd"); ec=$?
assert "git merge on main → block" 2 "BLOCK: Manual merging" "$ec" "$out"
rm -rf "$sb"

sb=$(mktemp -d); init_git "$sb" feat/x
out=$(run_in_sandbox "$sb" "$cmd"); ec=$?
assert "git merge on feat/x → pass" 0 "" "$ec" "$out"
rm -rf "$sb"

echo ""
echo "=== PreToolUse Bash(git add:*) — .work-state guard ==="
cmd=$(get_cmd "PreToolUse" "Bash(git add:*)")
out=$(CLAUDE_COMMAND="git add .work-state/team-state.md" bash -c "$cmd"); ec=$?
assert "git add .work-state → block" 2 "BLOCK: Do not stage .work-state" "$ec" "$out"

out=$(CLAUDE_COMMAND="git add src/foo.kt" bash -c "$cmd"); ec=$?
assert "git add normal file → pass" 0 "" "$ec" "$out"

echo ""
echo "=== PreToolUse Bash(git commit:*) — .work-state staged guard ==="
cmd=$(get_cmd_n "PreToolUse" "Bash(git commit:*)" 1)

sb=$(mktemp -d); init_git "$sb" feat/x
mkdir -p "$sb/.work-state"
echo data > "$sb/.work-state/team-state.md"
(cd "$sb" && git add -f .work-state/team-state.md)
out=$(run_in_sandbox "$sb" "$cmd"); ec=$?
assert "git commit with .work-state staged → block" 2 "BLOCK: .work-state/ files are staged" "$ec" "$out"
rm -rf "$sb"

sb=$(mktemp -d); init_git "$sb" feat/x
out=$(run_in_sandbox "$sb" "$cmd"); ec=$?
assert "git commit clean → pass" 0 "" "$ec" "$out"
rm -rf "$sb"

echo ""
echo "=== PreToolUse mcp__claude-in-chrome__* ==="
cmd=$(get_cmd "PreToolUse" "mcp__claude-in-chrome__*")

sb=$(mktemp -d)
out=$(run_in_sandbox "$sb" "$cmd"); ec=$?
assert "chrome tool no marker → block" 2 "MCP Chrome tools restricted" "$ec" "$out"
rm -rf "$sb"

sb=$(mktemp -d)
mkdir -p "$sb/.work-state"; touch "$sb/.work-state/.manual-qa-active"
out=$(run_in_sandbox "$sb" "$cmd"); ec=$?
assert "chrome tool with marker → pass" 0 "" "$ec" "$out"
rm -rf "$sb"

echo ""
echo "=== PreToolUse mcp__mobile__* ==="
cmd=$(get_cmd "PreToolUse" "mcp__mobile__(screenshot|get_ui|analyze_screen|tap|long_press|swipe|find_and_tap|tap_by_text|input_text|press_key|find_element|get_current_activity|launch_app|stop_app|shell|open_url|get_logs|launch_desktop_app|stop_desktop_app|get_window_info|focus_window|resize_window|get_clipboard|set_clipboard)")

sb=$(mktemp -d)
out=$(run_in_sandbox "$sb" "$cmd"); ec=$?
assert "mobile tool no marker → block" 2 "MCP Mobile interaction tools restricted" "$ec" "$out"
rm -rf "$sb"

sb=$(mktemp -d)
mkdir -p "$sb/.work-state"; touch "$sb/.work-state/.manual-qa-active"
out=$(run_in_sandbox "$sb" "$cmd"); ec=$?
assert "mobile tool with marker → pass" 0 "" "$ec" "$out"
rm -rf "$sb"

echo ""
echo "=== PreCompact ==="
cmd=$(get_cmd_idx PreCompact 0)
sb=$(mktemp -d)
mkdir -p "$sb/.work-state"; echo "state body" > "$sb/.work-state/team-state.md"
out=$(run_in_sandbox "$sb" "$cmd"); ec=$?
assert "PreCompact prints state" 0 "Context compacting" "$ec" "$out"
rm -rf "$sb"

echo ""
echo "=== Stop ==="
cmd=$(get_cmd_idx Stop 0)
sb=$(mktemp -d)
mkdir -p "$sb/.work-state"
cat > "$sb/.work-state/team-state.md" <<EOF
- [x] Phase 1
- [ ] Phase 2
EOF
out=$(run_in_sandbox "$sb" "$cmd"); ec=$?
assert "Stop reports incomplete phases" 0 "INCOMPLETE PHASES" "$ec" "$out"
rm -rf "$sb"

echo ""
echo "=== SubagentStop ==="
cmd=$(get_cmd_idx SubagentStop 0)
out=$(bash -c "$cmd"); ec=$?
assert "SubagentStop prints reminder" 0 "Subagent finished" "$ec" "$out"

echo ""
echo "=== PreToolUse Task (validate-state.sh — P4/P5) ==="
# Second "Task" matcher block invokes hooks/validate-state.sh via CLAUDE_PLUGIN_ROOT.
REPO_ROOT="$(cd "$(dirname "$HOOKS_FILE")/.." && pwd)"
cmd=$(get_cmd_n "PreToolUse" "Task" 1)

# 0. no json state → allow silently (markdown-only / not started)
sb=$(mktemp -d)
out=$(run_in_sandbox "$sb" "$cmd" CLAUDE_PLUGIN_ROOT="$REPO_ROOT"); ec=$?
if [ "$ec" = "0" ] && [ -z "$out" ]; then
  log_pass "validate-state no json state → allow"
else
  log_fail "validate-state no json state → allow" "ec=$ec out='$out'"
fi
rm -rf "$sb"

# 1. consistent classification + monotonic stages → allow
sb=$(mktemp -d); mkdir -p "$sb/.work-state"
echo '{"classification":{"type":"FEATURE","complexity":"COMPLEX","workflow":"full-feature"},"stages":[{"id":"a","status":"done"},{"id":"b","status":"in_progress"},{"id":"c","status":"pending"}]}' > "$sb/.work-state/team-state.json"
out=$(run_in_sandbox "$sb" "$cmd" CLAUDE_PLUGIN_ROOT="$REPO_ROOT"); ec=$?
assert "validate-state consistent → allow" 0 "" "$ec" "$out"
rm -rf "$sb"

# 2. workflow mismatch (FEATURE/COMPLEX should be full-feature, not standard) → block
sb=$(mktemp -d); mkdir -p "$sb/.work-state"
echo '{"classification":{"type":"FEATURE","complexity":"COMPLEX","workflow":"standard"}}' > "$sb/.work-state/team-state.json"
out=$(run_in_sandbox "$sb" "$cmd" CLAUDE_PLUGIN_ROOT="$REPO_ROOT"); ec=$?
assert "validate-state workflow mismatch → block" 2 "BLOCK (P5)" "$ec" "$out"
rm -rf "$sb"

# 3. missing classification.type → block
sb=$(mktemp -d); mkdir -p "$sb/.work-state"
echo '{"classification":{"workflow":"full-feature"}}' > "$sb/.work-state/team-state.json"
out=$(run_in_sandbox "$sb" "$cmd" CLAUDE_PLUGIN_ROOT="$REPO_ROOT"); ec=$?
assert "validate-state no type → block" 2 "no classification.type" "$ec" "$out"
rm -rf "$sb"

# 4. non-monotonic stages (pending before done) → block
sb=$(mktemp -d); mkdir -p "$sb/.work-state"
echo '{"classification":{"type":"FEATURE","complexity":"COMPLEX","workflow":"full-feature"},"stages":[{"id":"a","status":"pending"},{"id":"b","status":"done"}]}' > "$sb/.work-state/team-state.json"
out=$(run_in_sandbox "$sb" "$cmd" CLAUDE_PLUGIN_ROOT="$REPO_ROOT"); ec=$?
assert "validate-state non-monotonic → block" 2 "BLOCK (P4)" "$ec" "$out"
rm -rf "$sb"

# 5. autonomous BUG_FIX (any complexity) → debug-cycle expected → allow
sb=$(mktemp -d); mkdir -p "$sb/.work-state"
echo '{"classification":{"type":"BUG_FIX","complexity":"MEDIUM","workflow":"debug-cycle"},"autonomous":true}' > "$sb/.work-state/team-state.json"
out=$(run_in_sandbox "$sb" "$cmd" CLAUDE_PLUGIN_ROOT="$REPO_ROOT"); ec=$?
assert "validate-state autonomous bug→debug-cycle → allow" 0 "" "$ec" "$out"
rm -rf "$sb"

# 6. explicit workflow_override bypasses P5 mismatch → allow
sb=$(mktemp -d); mkdir -p "$sb/.work-state"
echo '{"classification":{"type":"FEATURE","complexity":"COMPLEX","workflow":"standard"},"workflow_override":true}' > "$sb/.work-state/team-state.json"
out=$(run_in_sandbox "$sb" "$cmd" CLAUDE_PLUGIN_ROOT="$REPO_ROOT"); ec=$?
assert "validate-state override → allow" 0 "" "$ec" "$out"
rm -rf "$sb"

# 7. malformed JSON → degrade to allow (never brick)
sb=$(mktemp -d); mkdir -p "$sb/.work-state"
echo '{ this is not json' > "$sb/.work-state/team-state.json"
out=$(run_in_sandbox "$sb" "$cmd" CLAUDE_PLUGIN_ROOT="$REPO_ROOT"); ec=$?
assert "validate-state malformed json → allow" 0 "not valid JSON" "$ec" "$out"
rm -rf "$sb"

echo ""
echo "=== workflow profiles (JSON validity + schema invariants) ==="
WF_DIR="$REPO_ROOT/workflows"
if [ -d "$WF_DIR" ]; then
  for f in "$WF_DIR"/*.json; do
    base=$(basename "$f")
    if jq empty "$f" 2>/dev/null; then
      log_pass "workflows/$base valid JSON"
    else
      log_fail "workflows/$base valid JSON" "jq parse failed"
    fi
  done
  # every profile (excluding schema/config files) has name+match+stages, and name == filename
  for f in "$WF_DIR"/*.json; do
    base=$(basename "$f" .json)
    case "$base" in _schema|artifacts-schema|team.config.schema|team.config.example) continue ;; esac
    ok=$(jq -r '(if (.name and .match and .stages) then "y" else "n" end)' "$f" 2>/dev/null)
    nm=$(jq -r '.name // ""' "$f" 2>/dev/null)
    if [ "$ok" = "y" ] && [ "$nm" = "$base" ]; then
      log_pass "profile $base has name/match/stages and name matches filename"
    else
      log_fail "profile $base structure" "ok=$ok name='$nm' file='$base'"
    fi
  done
else
  log_fail "workflows dir present" "$WF_DIR missing"
fi

echo ""
echo "=== team.config (custom agents + roster_overrides) ==="
CFG="$REPO_ROOT/workflows/team.config.example.json"
if [ -f "$CFG" ]; then
  rolesok=$(jq -r 'if (.roles|type)=="object" then "y" else "n" end' "$CFG")
  [ "$rolesok" = "y" ] && log_pass "config roles is an object" || log_fail "config roles is an object" "type mismatch"
  # roster_overrides (if present) only contains add/remove/replace arrays
  badkeys=$(jq -r '(.roster_overrides // {}) | to_entries[] | .value | keys[] | select(. != "add" and . != "remove" and . != "replace")' "$CFG")
  [ -z "$badkeys" ] && log_pass "config roster_overrides keys limited to add/remove/replace" || log_fail "config roster_overrides keys" "unexpected: $badkeys"
else
  log_fail "team.config.example.json present" "$CFG missing"
fi

echo ""
echo "=== Stop dod-gate.sh (P8 — Definition of Done backstop) ==="
REPO_ROOT="$(cd "$(dirname "$HOOKS_FILE")/.." && pwd)"
cmd=$(get_cmd_idx Stop 1)

mk_state() { mkdir -p "$1/.work-state/artifacts"; printf '%s' "$2" > "$1/.work-state/team-state.json"; }
mk_dod()   { printf '%s' "$2" > "$1/.work-state/artifacts/dod.json"; }

# mid-work (cursor implementation) → allow
sb=$(mktemp -d); mk_state "$sb" '{"classification":{"workflow":"full-feature","branch":"feat/x"},"stage_cursor":"implementation"}'
out=$(run_in_sandbox "$sb" "$cmd" CLAUDE_PLUGIN_ROOT="$REPO_ROOT" CURRENT_BRANCH="feat/x"); ec=$?
assert "dod-gate mid-work → allow" 0 "" "$ec" "$out"; rm -rf "$sb"

# done-claim, no dod → block
sb=$(mktemp -d); mk_state "$sb" '{"classification":{"workflow":"full-feature","branch":"feat/x"},"stage_cursor":"summary"}'
out=$(run_in_sandbox "$sb" "$cmd" CLAUDE_PLUGIN_ROOT="$REPO_ROOT" CURRENT_BRANCH="feat/x"); ec=$?
assert "dod-gate done, no dod → block" 2 "BLOCK (DoD)" "$ec" "$out"; rm -rf "$sb"

# done-claim, dod with open item → block
sb=$(mktemp -d); mk_state "$sb" '{"classification":{"workflow":"full-feature","branch":"feat/x"},"stage_cursor":"summary"}'
mk_dod "$sb" '{"items":[{"criterion":"login works","verify_method":"manual-qa","status":"pending"}],"type_requirements_met":true}'
out=$(run_in_sandbox "$sb" "$cmd" CLAUDE_PLUGIN_ROOT="$REPO_ROOT" CURRENT_BRANCH="feat/x"); ec=$?
assert "dod-gate open item → block" 2 "BLOCK (DoD)" "$ec" "$out"; rm -rf "$sb"

# done-claim, all met w/ evidence + type ok → allow
sb=$(mktemp -d); mk_state "$sb" '{"classification":{"workflow":"full-feature","branch":"feat/x"},"stage_cursor":"summary"}'
mk_dod "$sb" '{"items":[{"criterion":"login works","verify_method":"manual-qa","status":"met","evidence":"gist shows input+output"}],"type_requirements_met":true}'
out=$(run_in_sandbox "$sb" "$cmd" CLAUDE_PLUGIN_ROOT="$REPO_ROOT" CURRENT_BRANCH="feat/x"); ec=$?
assert "dod-gate complete → allow" 0 "DoD complete" "$ec" "$out"; rm -rf "$sb"

# pause background_wait → allow
sb=$(mktemp -d); mk_state "$sb" '{"classification":{"workflow":"full-feature","branch":"feat/x"},"stage_cursor":"summary","pause":{"kind":"background_wait"}}'
out=$(run_in_sandbox "$sb" "$cmd" CLAUDE_PLUGIN_ROOT="$REPO_ROOT" CURRENT_BRANCH="feat/x"); ec=$?
assert "dod-gate background_wait → allow" 0 "" "$ec" "$out"; rm -rf "$sb"

# stale branch → allow
sb=$(mktemp -d); mk_state "$sb" '{"classification":{"workflow":"full-feature","branch":"feat/OLD"},"stage_cursor":"summary"}'
out=$(run_in_sandbox "$sb" "$cmd" CLAUDE_PLUGIN_ROOT="$REPO_ROOT" CURRENT_BRANCH="feat/x"); ec=$?
assert "dod-gate stale branch → allow" 0 "stale state" "$ec" "$out"; rm -rf "$sb"

# emergency workflow → allow
sb=$(mktemp -d); mk_state "$sb" '{"classification":{"workflow":"emergency","branch":"feat/x"},"stage_cursor":"summary"}'
out=$(run_in_sandbox "$sb" "$cmd" CLAUDE_PLUGIN_ROOT="$REPO_ROOT" CURRENT_BRANCH="feat/x"); ec=$?
assert "dod-gate emergency → allow" 0 "" "$ec" "$out"; rm -rf "$sb"

# override marker → allow
sb=$(mktemp -d); mk_state "$sb" '{"classification":{"workflow":"full-feature","branch":"feat/x"},"stage_cursor":"summary","pause":{"kind":"done"}}'
touch "$sb/.work-state/.dod-override"
out=$(run_in_sandbox "$sb" "$cmd" CLAUDE_PLUGIN_ROOT="$REPO_ROOT" CURRENT_BRANCH="feat/x"); ec=$?
assert "dod-gate override → allow" 0 "override present" "$ec" "$out"; rm -rf "$sb"

# no state json → allow
sb=$(mktemp -d)
out=$(run_in_sandbox "$sb" "$cmd" CLAUDE_PLUGIN_ROOT="$REPO_ROOT" CURRENT_BRANCH="feat/x"); ec=$?
assert "dod-gate no state → allow" 0 "" "$ec" "$out"; rm -rf "$sb"

echo ""
echo "=== PreToolUse Write|Edit root-cause reminder (BUG_FIX §4) ==="
cmd=$(get_cmd_n "PreToolUse" "Write|Edit" 1)

# BUG_FIX, no diagnosis root_cause → reminder, allow
sb=$(mktemp -d); mkdir -p "$sb/.work-state"
echo '{"classification":{"type":"BUG_FIX"}}' > "$sb/.work-state/team-state.json"
out=$(run_in_sandbox "$sb" "$cmd" CLAUDE_FILE_PATH=src/foo.kt); ec=$?
assert "root-cause reminder BUG_FIX no root → warn" 0 "root-cause gate" "$ec" "$out"; rm -rf "$sb"

# BUG_FIX WITH root_cause → silent
sb=$(mktemp -d); mkdir -p "$sb/.work-state/artifacts"
echo '{"classification":{"type":"BUG_FIX"}}' > "$sb/.work-state/team-state.json"
echo '{"root_cause":"off-by-one in expiry check"}' > "$sb/.work-state/artifacts/diagnosis.json"
out=$(run_in_sandbox "$sb" "$cmd" CLAUDE_FILE_PATH=src/foo.kt); ec=$?
assert "root-cause reminder BUG_FIX with root → silent" 0 "" "$ec" "$out"; rm -rf "$sb"

# FEATURE → silent (not a bug)
sb=$(mktemp -d); mkdir -p "$sb/.work-state"
echo '{"classification":{"type":"FEATURE"}}' > "$sb/.work-state/team-state.json"
out=$(run_in_sandbox "$sb" "$cmd" CLAUDE_FILE_PATH=src/foo.kt); ec=$?
assert "root-cause reminder FEATURE → silent" 0 "" "$ec" "$out"; rm -rf "$sb"

echo ""
echo "=== UserPromptSubmit team-nudge.sh (P9) ==="
cmd=$(get_cmd_idx UserPromptSubmit 0)

out=$(run_in_sandbox "$PWD" "$cmd" CLAUDE_PLUGIN_ROOT="$REPO_ROOT" 2>/dev/null <<< '/fullstack-team:team review branch'); ec=$?
assert "team-nudge on /team → reminder" 0 "WORKFLOW INTERPRETER" "$ec" "$out"

out=$(printf '%s' '/team-next' | env CLAUDE_PLUGIN_ROOT="$REPO_ROOT" bash -c "$cmd" 2>/dev/null); ec=$?
[ -z "$out" ] && log_pass "team-nudge on /team-next → silent" || log_fail "team-nudge on /team-next → silent" "out='$out'"

out=$(printf '%s' 'fix the login bug' | env CLAUDE_PLUGIN_ROOT="$REPO_ROOT" bash -c "$cmd" 2>/dev/null); ec=$?
[ -z "$out" ] && log_pass "team-nudge on non-team → silent" || log_fail "team-nudge on non-team → silent" "out='$out'"

out=$(printf '%s' '{"prompt":"/team add pagination"}' | env CLAUDE_PLUGIN_ROOT="$REPO_ROOT" bash -c "$cmd" 2>/dev/null); ec=$?
assert "team-nudge stdin JSON → reminder" 0 "WORKFLOW INTERPRETER" "$ec" "$out"

echo ""
echo "=== validate-state dormant-gates nudge (json absent, md present) ==="
vcmd=$(get_cmd_n "PreToolUse" "Task" 1)
sb=$(mktemp -d); mkdir -p "$sb/.work-state"; echo "# team state" > "$sb/.work-state/team-state.md"
out=$(run_in_sandbox "$sb" "$vcmd" CLAUDE_PLUGIN_ROOT="$REPO_ROOT"); ec=$?
assert "validate-state md-only → dormant nudge" 0 "DORMANT" "$ec" "$out"; rm -rf "$sb"

echo ""
echo "=== stage files referential integrity (P9) ==="
missing=0
for p in "$REPO_ROOT"/workflows/*.json; do
  base=$(basename "$p" .json)
  case "$base" in _schema|artifacts-schema|team.config.schema|team.config.example) continue ;; esac
  for sid in $(jq -r '.stages[].id' "$p" 2>/dev/null); do
    if [ ! -f "$REPO_ROOT/workflows/stages/$sid.md" ]; then
      log_fail "stage file workflows/stages/$sid.md (used by $base)" "missing"
      missing=$((missing+1))
    fi
  done
done
[ "$missing" = "0" ] && log_pass "every profile stage id has a workflows/stages/<id>.md"

echo ""
echo "=== orchestrator role boundary (delegate-don't-DIY governance) ==="
TEAM_MD="$REPO_ROOT/commands/team.md"
DISC_MD="$REPO_ROOT/workflows/stages/discovery.md"
if [ -f "$TEAM_MD" ]; then
  grep -q "ORCHESTRATOR ROLE BOUNDARY" "$TEAM_MD" \
    && log_pass "team.md has ORCHESTRATOR ROLE BOUNDARY section" \
    || log_fail "team.md ORCHESTRATOR ROLE BOUNDARY section" "missing"
  grep -q "Smell test" "$TEAM_MD" \
    && log_pass "team.md role boundary has a smell test" \
    || log_fail "team.md role boundary smell test" "missing"
  # HARD RULE 3 must reference the boundary so the discovery-as-license loophole is closed
  grep -q "router, not the executor" "$TEAM_MD" \
    && log_pass "HARD RULE 3 frames orchestrator as router" \
    || log_fail "HARD RULE 3 router framing" "missing"
else
  log_fail "commands/team.md present" "$TEAM_MD missing"
fi
if [ -f "$DISC_MD" ]; then
  grep -qi "Scope ceiling" "$DISC_MD" \
    && log_pass "discovery.md has the orientation scope ceiling" \
    || log_fail "discovery.md scope ceiling" "missing"
else
  log_fail "workflows/stages/discovery.md present" "$DISC_MD missing"
fi

# ── summary ───────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════"
echo "Total: $((PASS + FAIL)) | Pass: $PASS | Fail: $FAIL"
echo "OS: $(uname -s) | stat: $(command -v stat)"
echo "═══════════════════════════════════════════"

if [ $FAIL -gt 0 ]; then
  echo ""
  echo "Failed tests:"
  for t in "${FAILED_TESTS[@]}"; do echo "  - $t"; done
  exit 1
fi
exit 0
