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
echo "=== resolve-state-path.sh (work-state layout resolver) ==="
RESOLVE="$(dirname "$HOOKS_FILE")/resolve-state-path.sh"

# 1) No work-state at all → empty output (graceful).
sb=$(mktemp -d)
out=$(cd "$sb" && bash "$RESOLVE" 2>&1); ec=$?
if [ "$ec" = "0" ] && [ -z "$out" ]; then
  log_pass "resolve-state-path: no work-state → empty"
else
  log_fail "resolve-state-path: no work-state → empty" "ec=$ec out='$out'"
fi
rm -rf "$sb"

# 2) Legacy single-state → resolves to legacy team-state.json file path.
sb=$(mktemp -d); mkdir -p "$sb/.work-state"; printf '{"schema":1}\n' > "$sb/.work-state/team-state.json"
out=$(cd "$sb" && bash "$RESOLVE" 2>&1); ec=$?
if [ "$ec" = "0" ] && [ "$out" = ".work-state/team-state.json" ]; then
  log_pass "resolve-state-path: legacy team-state.json → legacy file"
else
  log_fail "resolve-state-path: legacy team-state.json → legacy file" "ec=$ec out='$out'"
fi
rm -rf "$sb"

# 3) Active feature with matching subdir → resolves to that feature's state.json.
sb=$(mktemp -d); mkdir -p "$sb/.work-state/features/feat-login-fix"
printf '{"schema":1}\n' > "$sb/.work-state/features/feat-login-fix/state.json"
printf 'feat-login-fix\n' > "$sb/.work-state/.active-feature"
out=$(cd "$sb" && bash "$RESOLVE" 2>&1); ec=$?
if [ "$ec" = "0" ] && [ "$out" = ".work-state/features/feat-login-fix/state.json" ]; then
  log_pass "resolve-state-path: active-feature + matching state → feature file"
else
  log_fail "resolve-state-path: active-feature + matching state → feature file" "ec=$ec out='$out'"
fi
rm -rf "$sb"

# 4) Active feature set but pointing at missing subdir → falls back to legacy if present.
sb=$(mktemp -d); mkdir -p "$sb/.work-state"
printf '{"schema":1}\n' > "$sb/.work-state/team-state.json"
printf 'feat-ghost\n' > "$sb/.work-state/.active-feature"
out=$(cd "$sb" && bash "$RESOLVE" 2>&1); ec=$?
if [ "$ec" = "0" ] && [ "$out" = ".work-state/team-state.json" ]; then
  log_pass "resolve-state-path: active-feature → missing subdir falls back to legacy"
else
  log_fail "resolve-state-path: active-feature → missing subdir falls back to legacy" "ec=$ec out='$out'"
fi
rm -rf "$sb"

# 5) Active feature + legacy both present → feature wins (new convention preferred).
sb=$(mktemp -d); mkdir -p "$sb/.work-state/features/feat-a"
printf '{"schema":1}\n' > "$sb/.work-state/team-state.json"
printf '{"schema":1}\n' > "$sb/.work-state/features/feat-a/state.json"
printf 'feat-a\n' > "$sb/.work-state/.active-feature"
out=$(cd "$sb" && bash "$RESOLVE" 2>&1); ec=$?
if [ "$ec" = "0" ] && [ "$out" = ".work-state/features/feat-a/state.json" ]; then
  log_pass "resolve-state-path: feature takes precedence over legacy"
else
  log_fail "resolve-state-path: feature takes precedence over legacy" "ec=$ec out='$out'"
fi
rm -rf "$sb"

# 6) Whitespace-only .active-feature → empty slug, ignored.
sb=$(mktemp -d); mkdir -p "$sb/.work-state"
printf '{"schema":1}\n' > "$sb/.work-state/team-state.json"
printf '   \n' > "$sb/.work-state/.active-feature"
out=$(cd "$sb" && bash "$RESOLVE" 2>&1); ec=$?
if [ "$ec" = "0" ] && [ "$out" = ".work-state/team-state.json" ]; then
  log_pass "resolve-state-path: whitespace-only active-feature → legacy"
else
  log_fail "resolve-state-path: whitespace-only active-feature → legacy" "ec=$ec out='$out'"
fi
rm -rf "$sb"

# 7) Active feature file is itself valid in WORK_STATE_DIR sandbox.
sb=$(mktemp -d)
out=$(cd "$sb" && WORK_STATE_DIR=.work-state bash "$RESOLVE" 2>&1); ec=$?
if [ "$ec" = "0" ] && [ -z "$out" ]; then
  log_pass "resolve-state-path: WORK_STATE_DIR override honored"
else
  log_fail "resolve-state-path: WORK_STATE_DIR override honored" "ec=$ec out='$out'"
fi
rm -rf "$sb"

# 8) dod-gate reads via helper: missing state → graceful exit 0 (legacy allow).
sb=$(mktemp -d)
DOD_HOOK="$(dirname "$HOOKS_FILE")/dod-gate.sh"
out=$(cd "$sb" && bash "$DOD_HOOK" 2>&1); ec=$?
if [ "$ec" = "0" ]; then
  log_pass "dod-gate: missing state → graceful exit 0 (helper)"
else
  log_fail "dod-gate: missing state → graceful exit 0 (helper)" "ec=$ec out='$out'"
fi
rm -rf "$sb"

# 9) dod-gate end-to-end: per-feature state file in WORK_STATE_DIR sandbox, done-claim,
#    no DoD artifact under that feature → blocks. Proves per-feature layout is wired.
sb=$(mktemp -d); mkdir -p "$sb/.work-state/features/feat-end-to-end"
if (cd "$sb" && git init -q -b test-branch 2>/dev/null); then
  BR=$(cd "$sb" && git rev-parse --abbrev-ref HEAD 2>/dev/null)
  cat > "$sb/.work-state/features/feat-end-to-end/state.json" <<EOF
{"schema":1,"branch":"$BR","classification":{"type":"FEATURE","workflow":"standard"},"pause":{"kind":"done"},"stage_cursor":"summary"}
EOF
  printf 'feat-end-to-end\n' > "$sb/.work-state/.active-feature"
  out=$(cd "$sb" && WORK_STATE_DIR=.work-state bash "$DOD_HOOK" 2>&1); ec=$?
  if [ "$ec" = "2" ] && echo "$out" | grep -q "BLOCK (DoD)"; then
    log_pass "dod-gate: per-feature done-claim without DoD → BLOCK (end-to-end)"
  else
    log_fail "dod-gate: per-feature done-claim without DoD → BLOCK (end-to-end)" "ec=$ec out='$out'"
  fi
else
  log_pass "dod-gate: skipped end-to-end (no git in sandbox)"
fi
rm -rf "$sb"

echo ""
echo "=== SessionStart ==="
cmd=$(get_cmd_idx SessionStart 0)
out=$(bash -c "$cmd"); ec=$?
assert "SessionStart prints banner" 0 "Dream Team" "$ec" "$out"

# PR-1: SessionStart also pre-creates .work-state/archive/ (for stale-state archiving)
archcmd=$(jq -r '.hooks.SessionStart[0].hooks[1].command' "$HOOKS_FILE")
sb=$(mktemp -d)
run_in_sandbox "$sb" "$archcmd" >/dev/null 2>&1; ec=$?
if [ "$ec" = "0" ] && [ -d "$sb/.work-state/archive" ]; then
  log_pass "SessionStart creates .work-state/archive/"
else
  log_fail "SessionStart creates .work-state/archive/" "ec=$ec dir=$( [ -d "$sb/.work-state/archive" ] && echo yes || echo no )"
fi
rm -rf "$sb"

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

# PR-1: manual-qa agent (env probe) with no marker → auto-create + allow
sb=$(mktemp -d)
out=$(run_in_sandbox "$sb" "$cmd" CLAUDE_AGENT_TYPE="fullstack-team:manual-qa"); ec=$?
if [ "$ec" = "0" ] && [ -f "$sb/.work-state/.manual-qa-active" ]; then
  log_pass "chrome tool as manual-qa → lazy auto-create marker + allow"
else
  log_fail "chrome tool as manual-qa → lazy auto-create marker + allow" "ec=$ec marker=$( [ -f "$sb/.work-state/.manual-qa-active" ] && echo yes || echo no )"
fi
rm -rf "$sb"

# PR-1: non-manual-qa agent with no marker → still block (protection preserved)
sb=$(mktemp -d)
out=$(run_in_sandbox "$sb" "$cmd" CLAUDE_AGENT_TYPE="fullstack-team:developer-kotlin"); ec=$?
assert "chrome tool as non-manual-qa → block" 2 "MCP Chrome tools restricted" "$ec" "$out"
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

# PR-1: manual-qa agent (env probe) with no marker → auto-create + allow
sb=$(mktemp -d)
out=$(run_in_sandbox "$sb" "$cmd" CLAUDE_AGENT_TYPE="fullstack-team:manual-qa"); ec=$?
if [ "$ec" = "0" ] && [ -f "$sb/.work-state/.manual-qa-active" ]; then
  log_pass "mobile tool as manual-qa → lazy auto-create marker + allow"
else
  log_fail "mobile tool as manual-qa → lazy auto-create marker + allow" "ec=$ec"
fi
rm -rf "$sb"

# PR-1: non-manual-qa agent with no marker → still block
sb=$(mktemp -d)
out=$(run_in_sandbox "$sb" "$cmd" CLAUDE_AGENT_TYPE="fullstack-team:developer-mobile"); ec=$?
assert "mobile tool as non-manual-qa → block" 2 "MCP Mobile interaction tools restricted" "$ec" "$out"
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

# PR-1: SubagentStop cleans up the .manual-qa-active marker so it doesn't leak to the next agent
clcmd=$(jq -r '.hooks.SubagentStop[0].hooks[1].command' "$HOOKS_FILE")
sb=$(mktemp -d); mkdir -p "$sb/.work-state"; touch "$sb/.work-state/.manual-qa-active"
run_in_sandbox "$sb" "$clcmd" >/dev/null 2>&1; ec=$?
if [ "$ec" = "0" ] && [ ! -f "$sb/.work-state/.manual-qa-active" ]; then
  log_pass "SubagentStop removes .manual-qa-active marker"
else
  log_fail "SubagentStop removes .manual-qa-active marker" "ec=$ec marker=$( [ -f "$sb/.work-state/.manual-qa-active" ] && echo present || echo gone )"
fi
rm -rf "$sb"

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

# PR-1: blocking messages go to STDERR (Stop-hook protocol: only stderr feeds Claude on exit 2)
sb=$(mktemp -d); mk_state "$sb" '{"classification":{"workflow":"full-feature","branch":"feat/x"},"stage_cursor":"summary"}'
errout=$( (cd "$sb" && env CLAUDE_PLUGIN_ROOT="$REPO_ROOT" CURRENT_BRANCH="feat/x" bash -c "$cmd" 2>/tmp/dg_err.$$ 1>/dev/null); cat /tmp/dg_err.$$ ); rm -f /tmp/dg_err.$$
echo "$errout" | grep -qF "BLOCK (DoD)" \
  && log_pass "dod-gate BLOCK message on stderr" \
  || log_fail "dod-gate BLOCK message on stderr" "not on stderr: '$errout'"
rm -rf "$sb"

# PR-1: unknown pause.kind → warn (never block), fall through
sb=$(mktemp -d); mk_state "$sb" '{"classification":{"workflow":"full-feature","branch":"feat/x"},"stage_cursor":"implementation","pause":{"kind":"bogus"}}'
out=$(run_in_sandbox "$sb" "$cmd" CLAUDE_PLUGIN_ROOT="$REPO_ROOT" CURRENT_BRANCH="feat/x"); ec=$?
assert "dod-gate unknown pause.kind → warn+allow" 0 "unknown pause.kind" "$ec" "$out"; rm -rf "$sb"

# PR-1: known pause.kind → no unknown-warning
sb=$(mktemp -d); mk_state "$sb" '{"classification":{"workflow":"full-feature","branch":"feat/x"},"stage_cursor":"implementation","pause":{"kind":"background_wait"}}'
out=$(run_in_sandbox "$sb" "$cmd" CLAUDE_PLUGIN_ROOT="$REPO_ROOT" CURRENT_BRANCH="feat/x"); ec=$?
if [ "$ec" = "0" ] && ! echo "$out" | grep -q "unknown pause.kind"; then
  log_pass "dod-gate known pause.kind → no warn"
else
  log_fail "dod-gate known pause.kind → no warn" "ec=$ec out='$out'"
fi
rm -rf "$sb"

# PR-1: branch mismatch → warn + archive stale state (mkdir first)
sb=$(mktemp -d); mk_state "$sb" '{"classification":{"workflow":"full-feature","branch":"feat/OLD"},"stage_cursor":"summary"}'
out=$(run_in_sandbox "$sb" "$cmd" CLAUDE_PLUGIN_ROOT="$REPO_ROOT" CURRENT_BRANCH="feat/x"); ec=$?
if [ "$ec" = "0" ] && [ -f "$sb/.work-state/archive/team-state.json.feat-OLD.bak" ] && [ ! -f "$sb/.work-state/team-state.json" ]; then
  log_pass "dod-gate branch mismatch → archives stale state"
else
  log_fail "dod-gate branch mismatch → archives stale state" "ec=$ec archived=$(ls "$sb/.work-state/archive" 2>/dev/null) out='$out'"
fi
rm -rf "$sb"

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
# emits the absolute plugin-assets root so the model reads workflow files from the real path
assert "team-nudge on /team → emits plugin root" 0 "Plugin assets root: $REPO_ROOT" "$ec" "$out"

# no CLAUDE_PLUGIN_ROOT (e.g. degraded env) → still reminder, just no root line
out=$(cd "$REPO_ROOT" && env -u CLAUDE_PLUGIN_ROOT bash hooks/team-nudge.sh '/team review branch' 2>/dev/null); ec=$?
if [ "$ec" = "0" ] && echo "$out" | grep -qF "WORKFLOW INTERPRETER" && ! echo "$out" | grep -qF "Plugin assets root"; then
  log_pass "team-nudge without plugin root → reminder, no root line"
else
  log_fail "team-nudge without plugin root" "ec=$ec out='$out'"
fi

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

echo ""
echo "=== PreToolUse Bash safety-guard.sh (fail-closed) ==="
SG="$REPO_ROOT/hooks/safety-guard.sh"
if [ -f "$SG" ]; then
  # must BLOCK (exit 2)
  for bad in "rm -rf /" "rm -rf ~" "rm -rf \$HOME" "sudo rm x" "chmod -R 777 ." "git push --force origin feat/x"; do
    out=$(CLAUDE_COMMAND="$bad" bash "$SG" 2>&1); ec=$?
    assert "safety-guard blocks: $bad" 2 "BLOCK" "$ec" "$out"
  done
  # must ALLOW (exit 0) — legit dev commands
  for ok in "rm -rf build/" "rm -rf node_modules" "git push origin feat/x" "git push --force-with-lease origin feat/x" "chmod +x file.sh" "ls -la"; do
    out=$(CLAUDE_COMMAND="$ok" bash "$SG" 2>&1); ec=$?
    assert "safety-guard allows: $ok" 0 "" "$ec" "$out"
  done
  # wired into hooks.json as a Bash matcher
  jq -e '[.hooks.PreToolUse[] | select(.matcher == "Bash")] | length >= 1' "$HOOKS_FILE" >/dev/null \
    && log_pass "safety-guard wired as PreToolUse Bash matcher" \
    || log_fail "safety-guard wired as PreToolUse Bash matcher" "no Bash matcher in hooks.json"
else
  log_fail "hooks/safety-guard.sh present" "$SG missing"
fi

echo ""
echo "=== UserPromptSubmit skill-suggest.sh (soft auto-activation) ==="
SS="$REPO_ROOT/hooks/skill-suggest.sh"
if [ -f "$SS" ]; then
  out=$(bash "$SS" "fix the goroutine deadlock in the worker" 2>&1); ec=$?
  assert "skill-suggest fires on bug+go" 0 "go-patterns" "$ec" "$out"
  out=$(bash "$SS" "add a new spring controller for orders" 2>&1); ec=$?
  assert "skill-suggest fires on feature+spring" 0 "kotlin-spring-boot" "$ec" "$out"
  # stays silent: no stack keyword, /team invocation, chitchat
  out=$(bash "$SS" "fix the thing" 2>&1); [ -z "$out" ] \
    && log_pass "skill-suggest silent without stack keyword" || log_fail "skill-suggest silent without stack" "out='$out'"
  out=$(bash "$SS" "/team add oauth" 2>&1); [ -z "$out" ] \
    && log_pass "skill-suggest silent on /team (team-nudge owns it)" || log_fail "skill-suggest silent on /team" "out='$out'"
  out=$(bash "$SS" "what is the weather today" 2>&1); [ -z "$out" ] \
    && log_pass "skill-suggest silent on chitchat" || log_fail "skill-suggest silent on chitchat" "out='$out'"
  jq -e '[.hooks.UserPromptSubmit[]] | length >= 2' "$HOOKS_FILE" >/dev/null \
    && log_pass "skill-suggest wired as second UserPromptSubmit hook" \
    || log_fail "skill-suggest wired" "UserPromptSubmit has <2 hooks"
else
  log_fail "hooks/skill-suggest.sh present" "$SS missing"
fi

echo ""
echo "=== review verdict normalization (P-1) ==="
# every review stage gate is the normalized verdict, not a subjective confidence number
badgate=0
for p in "$REPO_ROOT"/workflows/{bug-fix,full-feature,emergency,lightweight,review,standard}.json; do
  if grep -q 'confidence>=80' "$p"; then log_fail "review gate normalized in $(basename "$p")" "still confidence>=80"; badgate=$((badgate+1)); fi
done
[ "$badgate" = "0" ] && log_pass "no review stage uses the old confidence>=80 gate"
grep -q 'verdict != reject' "$REPO_ROOT/workflows/full-feature.json" \
  && log_pass "full-feature review gate = verdict != reject" \
  || log_fail "full-feature review gate" "missing verdict != reject"
jq -e '.definitions.review.required | index("verdict")' "$REPO_ROOT/workflows/artifacts-schema.json" >/dev/null \
  && log_pass "review artifact requires a normalized verdict" \
  || log_fail "review artifact verdict" "verdict not required in schema"

echo ""
echo "=== sequenced review pipeline (v3.0 — PR-2) ==="
SCHEMA="$REPO_ROOT/workflows/artifacts-schema.json"
FF="$REPO_ROOT/workflows/full-feature.json"
ST="$REPO_ROOT/workflows/standard.json"
LW="$REPO_ROOT/workflows/lightweight.json"

# new artifact schema definitions exist with their required fields
jq -e '.definitions.manual_qa.required | (index("verdict") and index("evidence"))' "$SCHEMA" >/dev/null \
  && log_pass "manual_qa artifact schema present (verdict+evidence required)" \
  || log_fail "manual_qa schema" "missing or wrong required set"
jq -e '.definitions.manual_qa.properties.verdict.enum | (index("PASS") and index("FAIL"))' "$SCHEMA" >/dev/null \
  && log_pass "manual_qa.verdict enum = PASS|FAIL" \
  || log_fail "manual_qa.verdict enum" "not PASS|FAIL"
jq -e '.definitions.qa_tests.required | index("tests_added")' "$SCHEMA" >/dev/null \
  && log_pass "qa_tests artifact schema present" \
  || log_fail "qa_tests schema" "missing"
jq -e '.definitions.feature_spec.required | (index("goal") and index("acceptance_criteria"))' "$SCHEMA" >/dev/null \
  && log_pass "feature_spec artifact schema present" \
  || log_fail "feature_spec schema" "missing"

# full-feature: code_review → review_fixes → manual_qa → qa_tests → summary, in order
order=$(jq -r '[.stages[].id] | join(",")' "$FF")
case "$order" in
  *code_review,review_fixes,manual_qa,qa_tests,summary) log_pass "full-feature ends with the sequenced pipeline order" ;;
  *) log_fail "full-feature pipeline order" "got: $order" ;;
esac
# code_review is static: roles must NOT contain qa or manual-qa
jq -e '[.stages[] | select(.id=="code_review") | .roles[]] | (index("qa") or index("manual-qa")) | not' "$FF" >/dev/null \
  && log_pass "full-feature code_review excludes qa/manual-qa (static only)" \
  || log_fail "code_review static" "code_review still bundles qa/manual-qa"
# manual_qa gated on has_runtime (not has_ui) — runs for backend/CLI too; has_ui only selects mode
jq -e '.stages[] | select(.id=="manual_qa") | .skip_if == "!scope.has_runtime"' "$FF" >/dev/null \
  && log_pass "full-feature manual_qa skip_if !scope.has_runtime (not has_ui)" \
  || log_fail "manual_qa skip_if" "expected !scope.has_runtime"
# manual_qa artifact records mode (ui|runtime)
jq -e '.definitions.manual_qa.properties.mode.enum | (index("ui") and index("runtime"))' "$SCHEMA" >/dev/null \
  && log_pass "manual_qa artifact has ui|runtime mode" \
  || log_fail "manual_qa mode" "missing ui|runtime enum"
# has_runtime documented as a built-in flag
grep -q "has_runtime" "$REPO_ROOT/workflows/README.md" \
  && log_pass "workflows/README documents has_runtime built-in" \
  || log_fail "has_runtime doc" "missing in workflows/README.md"
jq -e '.stages[] | select(.id=="manual_qa") | .produces == "manual_qa"' "$FF" >/dev/null \
  && log_pass "manual_qa stage produces manual_qa artifact" \
  || log_fail "manual_qa produces" "wrong"
jq -e '.stages[] | select(.id=="qa_tests") | .produces == "qa_tests"' "$FF" >/dev/null \
  && log_pass "qa_tests stage produces qa_tests artifact" \
  || log_fail "qa_tests produces" "wrong"

# standard has_infra conditional parity with full-feature
jq -e '[.stages[] | select(.id=="code_review") | .conditional[].if] | index("scope.has_infra")' "$ST" >/dev/null \
  && log_pass "standard code_review has has_infra conditional (parity with full-feature)" \
  || log_fail "standard has_infra parity" "missing has_infra conditional"

# lightweight: has qa_tests, NO manual_qa (QUICK skips manual QA)
jq -e '[.stages[].id] | (index("qa_tests") and (index("manual_qa") | not))' "$LW" >/dev/null \
  && log_pass "lightweight has qa_tests but no manual_qa (QUICK)" \
  || log_fail "lightweight pipeline" "qa_tests missing or manual_qa present"

echo ""
echo "=== multi-source DoD fan-in (PR-3) ==="
# schema: dod gained contributions (audit map) + updated_at, items gained id + source
jq -e '.definitions.dod.properties.contributions.type == "object"' "$SCHEMA" >/dev/null \
  && log_pass "dod.contributions audit map in schema" \
  || log_fail "dod.contributions" "missing"
jq -e '.definitions.dod.properties.updated_at' "$SCHEMA" >/dev/null \
  && log_pass "dod.updated_at in schema" \
  || log_fail "dod.updated_at" "missing"
jq -e '.definitions.dod.properties.items.items.properties | (.id and .source)' "$SCHEMA" >/dev/null \
  && log_pass "dod item gained id + source (fan-in provenance)" \
  || log_fail "dod item id/source" "missing"

# ID uniqueness invariant a fan-in must preserve: [items[].id] | unique == items count
sb=$(mktemp -d)
cat > "$sb/dod.json" <<'EOF'
{ "items": [
  { "id": "exploration-1", "source": "exploration", "criterion": "login works", "verify_method": "manual-qa", "status": "pending" },
  { "id": "architecture-1", "source": "architecture", "criterion": "p99 < 200ms", "verify_method": "load test", "status": "pending" },
  { "id": "manual_qa-1", "source": "manual_qa", "criterion": "error banner visible", "verify_method": "screenshot", "status": "pending" }
], "updated_at": "2026-07-21T00:00:00Z", "type_requirements_met": false }
EOF
uniq_ok=$(jq -r '([.items[].id] | unique | length) == (.items | length)' "$sb/dod.json")
[ "$uniq_ok" = "true" ] && log_pass "fan-in DoD keeps item ids unique across sources" \
  || log_fail "fan-in id uniqueness" "duplicate ids across sources"
rm -rf "$sb"

# stage files carry the append/close instruction
faninmiss=0
for s in exploration architecture implementation code_review qa_tests manual_qa; do
  grep -qi "DoD fan-in" "$REPO_ROOT/workflows/stages/$s.md" || { log_fail "stages/$s.md DoD fan-in note" "missing"; faninmiss=$((faninmiss+1)); }
done
[ "$faninmiss" = "0" ] && log_pass "every fan-in stage file documents append/close"

# team.md documents the fan-in convention
grep -q "Multi-source fan-in" "$REPO_ROOT/commands/team.md" \
  && log_pass "team.md documents Multi-source fan-in" \
  || log_fail "team.md fan-in section" "missing"

echo ""
echo "=== housekeeping / architect variants (PR-5) ==="
# architect consilium: named variants, count <= 3 (design choice C: 1 MEDIUM / 3 COMPLEX)
acount=$(jq -r '[.stages[] | select(.id=="architecture") | .roles // [.role]] | flatten | map(select(startswith("architect"))) | length' "$FF")
[ "$acount" -le 3 ] && [ "$acount" -ge 1 ] \
  && log_pass "full-feature architecture uses 1..3 architects ($acount)" \
  || log_fail "full-feature architect count" "got $acount (expected 1..3)"
jq -e '[.stages[] | select(.id=="architecture") | .roles[]] | (index("architect_minimal") and index("architect_clean") and index("architect_pragmatic"))' "$FF" >/dev/null \
  && log_pass "full-feature architects are named variants (minimal/clean/pragmatic)" \
  || log_fail "architect named variants" "not using named variant roles"
# no repeated bare 'architect' triple left anywhere
badarch=0
for p in "$REPO_ROOT"/workflows/{full-feature,standard,lightweight,bug-fix,debug-cycle}.json; do
  if jq -e '.stages[] | select(.id=="architecture") | (.roles // []) | map(select(. == "architect")) | length > 1' "$p" >/dev/null 2>&1; then
    log_fail "no duplicated bare architect role in $(basename "$p")" "found repeated \"architect\""; badarch=$((badarch+1))
  fi
done
[ "$badarch" = "0" ] && log_pass "no profile repeats the bare 'architect' role (named variants instead)"
# team.config maps the variant roles → architect agent
jq -e '.roles | (.architect_minimal == "architect" and .architect_clean == "architect" and .architect_pragmatic == "architect")' "$REPO_ROOT/workflows/team.config.example.json" >/dev/null \
  && log_pass "team.config maps architect_* variants → architect agent" \
  || log_fail "architect variant roles map" "missing in team.config.example.json"
# doc drift fixed
grep -q "15-agent" "$REPO_ROOT/commands/team.md" \
  && log_pass "team.md says 15-agent (drift fixed)" \
  || log_fail "team.md agent count" "still 13-agent"
grep -q "15 Specialized Agents" "$REPO_ROOT/README.md" \
  && log_pass "README says 15 Specialized Agents" \
  || log_fail "README agent count" "not 15"
grep -q "developer-go" "$REPO_ROOT/README.md" \
  && log_pass "README lists developer-go" \
  || log_fail "README developer-go row" "missing"
# frontend-developer no longer claims the kmp skill
grep -qE '^skills:.*\bkmp\b' "$REPO_ROOT/agents/frontend-developer.md" \
  && log_fail "frontend-developer kmp skill removed" "still lists kmp" \
  || log_pass "frontend-developer no longer lists kmp skill"

echo ""
echo "=== coordinator + yolo loop (PR-4) ==="
PU="$REPO_ROOT/hooks/profile-usage.sh"
# hook exists and is valid bash
if [ -f "$PU" ] && bash -n "$PU" 2>/dev/null; then
  log_pass "hooks/profile-usage.sh present + valid"
else
  log_fail "hooks/profile-usage.sh" "missing or syntax error"
fi
# appends a JSONL activation line when state is present
sb=$(mktemp -d); mkdir -p "$sb/.work-state"
echo '{"classification":{"type":"FEATURE","complexity":"COMPLEX","workflow":"full-feature","branch":"feat/x"},"stage_cursor":"implementation"}' > "$sb/.work-state/team-state.json"
(cd "$sb" && env WORK_STATE_DIR=".work-state" COORD_SLUG="demo" bash "$PU") >/dev/null 2>&1; ec=$?
JL="$sb/.work-state/coordinator/demo/profile-usage.jsonl"
if [ "$ec" = "0" ] && [ -f "$JL" ] && jq -e '.workflow == "full-feature" and .type == "FEATURE" and .stage == "implementation"' "$JL" >/dev/null 2>&1; then
  log_pass "profile-usage appends a valid activation JSONL line"
else
  log_fail "profile-usage jsonl" "ec=$ec content=$(cat "$JL" 2>/dev/null)"
fi
# second launch appends (not overwrites)
(cd "$sb" && env WORK_STATE_DIR=".work-state" COORD_SLUG="demo" bash "$PU") >/dev/null 2>&1
[ "$(wc -l < "$JL" | tr -d ' ')" = "2" ] \
  && log_pass "profile-usage is append-only (2 launches → 2 lines)" \
  || log_fail "profile-usage append" "expected 2 lines, got $(wc -l < "$JL")"
rm -rf "$sb"
# no state → no-op, no file created
sb=$(mktemp -d)
(cd "$sb" && env WORK_STATE_DIR=".work-state" COORD_SLUG="demo" bash "$PU") >/dev/null 2>&1; ec=$?
if [ "$ec" = "0" ] && [ ! -f "$sb/.work-state/coordinator/demo/profile-usage.jsonl" ]; then
  log_pass "profile-usage no state → silent no-op"
else
  log_fail "profile-usage no state" "ec=$ec created a file unexpectedly"
fi
rm -rf "$sb"
# wired into hooks.json as a PostToolUse Task hook
jq -e '[.hooks.PostToolUse[] | select(.matcher == "Task") | .hooks[0].command] | map(select(test("profile-usage.sh"))) | length >= 1' "$HOOKS_FILE" >/dev/null \
  && log_pass "profile-usage wired as PostToolUse Task hook" \
  || log_fail "profile-usage wiring" "not in hooks.json PostToolUse"

# new coordinator components exist
for f in commands/pulse.md commands/team-yolo.md commands/coordinator-stats.md \
         agents/coordinator.md agents/coordinator-yolo.md \
         skills/coordinator/SKILL.md skills/coordinator-yolo/SKILL.md \
         skills/coordinator-yolo-stop/SKILL.md skills/coordinator-stats/SKILL.md \
         skills/vision-bootstrap/SKILL.md; do
  [ -f "$REPO_ROOT/$f" ] && log_pass "PR-4 component present: $f" || log_fail "PR-4 component: $f" "missing"
done
# coordinator agent is read-only (no Write/Edit in its tools)
grep -qE '^tools:.*(Write|Edit)' "$REPO_ROOT/agents/coordinator.md" \
  && log_fail "coordinator agent read-only" "has Write/Edit in tools" \
  || log_pass "coordinator agent is read-only (no Write/Edit)"
# diagnostics two-tier gate documents bilingual approval triggers
grep -qi "исправь" "$REPO_ROOT/agents/diagnostics.md" && grep -qi "go ahead" "$REPO_ROOT/agents/diagnostics.md" \
  && log_pass "diagnostics two-tier gate has bilingual approval triggers" \
  || log_fail "diagnostics approval triggers" "missing bilingual set"

echo ""
echo "=== Go scope wiring (bug #2) ==="
CFG="$REPO_ROOT/workflows/team.config.example.json"
jq -e '.scope_map[] | select(.scope == "go") | .dev_agent == "developer-go"' "$CFG" >/dev/null \
  && log_pass "team.config maps go scope → developer-go" \
  || log_fail "go scope mapping" "missing in scope_map"
# scope renamed backend → backend-kotlin (no bare 'backend' scope left)
jq -e '[.scope_map[].scope] | index("backend-kotlin") and (index("backend") | not)' "$CFG" >/dev/null \
  && log_pass "backend scope renamed to backend-kotlin" \
  || log_fail "backend-kotlin rename" "scope still 'backend' or backend-kotlin missing"
# precedence invariant: mobile MUST be ordered before backend-kotlin (KMP .kt disambiguation)
mi=$(jq -r '[.scope_map[].scope] | index("mobile")' "$CFG")
bi=$(jq -r '[.scope_map[].scope] | index("backend-kotlin")' "$CFG")
if [ -n "$mi" ] && [ -n "$bi" ] && [ "$mi" -lt "$bi" ]; then
  log_pass "scope_map orders mobile before backend-kotlin (first-match precedence)"
else
  log_fail "scope_map precedence" "mobile idx=$mi not before backend-kotlin idx=$bi"
fi
! grep -q 'issue.zone.dev_agent' "$REPO_ROOT/workflows/full-feature.json" "$REPO_ROOT/workflows/standard.json" \
  && log_pass "review_fixes no longer uses undefined \${issue.zone.dev_agent}" \
  || log_fail "review_fixes role" "still references issue.zone.dev_agent"

echo ""
echo "=== /init-team command (P3 — project agent config) ==="
IT="$REPO_ROOT/commands/init-team.md"
if [ -f "$IT" ]; then
  grep -q '.claude/team.config.json' "$IT" \
    && log_pass "init-team writes .claude/team.config.json" \
    || log_fail "init-team output target" "no .claude/team.config.json reference"
  grep -q 'plugins' "$IT" && grep -qi 'cross-plugin\|other installed plugins\|~/.claude/plugins' "$IT" \
    && log_pass "init-team does cross-plugin agent discovery" \
    || log_fail "init-team cross-plugin scan" "missing"
  grep -qi 'not the directory name\|plugin.json' "$IT" \
    && log_pass "init-team resolves invoke_name from plugin.json name (not dir)" \
    || log_fail "init-team namespace rule" "missing plugin.json-name caveat"
  grep -qi 'dry-run' "$IT" \
    && log_pass "init-team dry-runs the scope_map before finishing" \
    || log_fail "init-team dry-run" "missing"
  grep -qi 'AskUserQuestion\|confirm' "$IT" \
    && log_pass "init-team confirms mapping interactively" \
    || log_fail "init-team confirmation" "missing"
else
  log_fail "commands/init-team.md present" "$IT missing"
fi
# the orphaned discovery agent now has a consumer (bug #5)
grep -qi 'Team-Config Discovery' "$REPO_ROOT/agents/discovery.md" \
  && log_pass "discovery agent has a Team-Config mode (no longer orphaned)" \
  || log_fail "discovery Team-Config mode" "missing"

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
