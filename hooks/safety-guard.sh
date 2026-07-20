#!/usr/bin/env bash
# safety-guard.sh — PreToolUse(Bash) fail-closed guard.
#
# Blocks a small set of catastrophic / foot-gun shell commands that a subagent (or the
# orchestrator) should never run. Inspired by xpowers/superpowers' fail-closed hook layer.
# This COMPLEMENTS the git-branch guards in hooks.json (push/merge/commit to main); here we
# block destructive filesystem + privilege + history-rewrite operations regardless of branch.
#
# Contract: the command line arrives as $CLAUDE_COMMAND (Claude Code sets this for
# PreToolUse Bash hooks). Print a reason + `exit 2` to BLOCK; `exit 0` to allow. Default is
# allow — we only deny on an explicit dangerous match, but each pattern is written narrowly so
# legitimate dev commands (rm -rf build/, rm -rf node_modules) are NOT caught.
#
# Test override: pass the command as $1.

set -u

CMD="${1:-${CLAUDE_COMMAND:-}}"
[ -z "$CMD" ] && exit 0

block() {
  echo "🚫 BLOCK (safety-guard): $1" >&2
  echo "   Command: $CMD" >&2
  [ -n "${2:-}" ] && echo "   $2" >&2
  exit 2
}

# 1) Catastrophic recursive delete — only root-ish / home / cwd-wide targets, NOT subdirs.
#    Matches: rm -rf /, rm -rf /*, rm -rf ~, rm -rf $HOME, rm -fr ., rm -rf .. , rm --recursive --force /
if printf '%s' "$CMD" | grep -qE '\brm\b[^|;&]*-[a-zA-Z]*r[a-zA-Z]*f|\brm\b[^|;&]*-[a-zA-Z]*f[a-zA-Z]*r|\brm\b[^|;&]*--recursive[^|;&]*--force|\brm\b[^|;&]*--force[^|;&]*--recursive'; then
  if printf '%s' "$CMD" | grep -qE '\brm\b[^|;&]*[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*(/|/\*|~|~/\*|\$HOME|\${HOME}|\.|\.\.|\.\/\*)([[:space:]]|$)'; then
    block "recursive force-delete of a root/home/cwd-wide path" "Delete a specific subdirectory instead (e.g. rm -rf build/), never / ~ . or .."
  fi
fi

# 2) Privilege escalation — agents must not sudo.
if printf '%s' "$CMD" | grep -qE '(^|[|;&[:space:]])sudo([[:space:]]|$)'; then
  block "sudo / privilege escalation" "Ask the user to run privileged commands themselves (! prefix in the prompt)."
fi

# 3) World-writable recursive chmod — insecure permissions.
if printf '%s' "$CMD" | grep -qE '\bchmod\b[^|;&]*-[a-zA-Z]*R[a-zA-Z]*[[:space:]]+0?777|\bchmod\b[^|;&]*[[:space:]]+0?777[^|;&]*-[a-zA-Z]*R'; then
  block "recursive chmod 777 (world-writable)" "Grant the narrowest permission that works (e.g. chmod +x file), never -R 777."
fi

# 4) Force-push that rewrites remote history. Allow --force-with-lease (the safe variant).
if printf '%s' "$CMD" | grep -qE '\bgit[[:space:]]+push\b'; then
  if printf '%s' "$CMD" | grep -qE '([-][-]force([[:space:]]|=|$)|[[:space:]]-f([[:space:]]|$))' \
     && ! printf '%s' "$CMD" | grep -qE '[-][-]force-with-lease'; then
    block "git push --force (rewrites remote history)" "Use --force-with-lease if you must force-push your own branch."
  fi
fi

exit 0
