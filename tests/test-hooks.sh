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
