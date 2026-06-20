#!/usr/bin/env bash
# skill-suggest.sh — UserPromptSubmit hook (soft skill/workflow auto-activation).
#
# Inspired by xpowers' skills-auto-activation: cut the slash-command ceremony by surfacing the
# relevant workflow + skills when the user types a plain request. Deliberately CONSERVATIVE —
# it only speaks when it sees BOTH an intent verb AND a concrete stack keyword, so it stays
# quiet on chit-chat and never fires twice with team-nudge (which owns /team invocations).
#
# UserPromptSubmit contract: prompt JSON on stdin; stdout is added to model context; always
# exit 0 (never blocks). Test override: pass the prompt as $1.

set -u

PROMPT="${1:-}"
if [ -z "$PROMPT" ]; then
  RAW="$(cat 2>/dev/null)"
  if command -v jq >/dev/null 2>&1 && printf '%s' "$RAW" | jq empty >/dev/null 2>&1; then
    PROMPT="$(printf '%s' "$RAW" | jq -r '.prompt // .user_prompt // empty' 2>/dev/null)"
  fi
  [ -z "$PROMPT" ] && PROMPT="$RAW"
fi
[ -z "$PROMPT" ] && exit 0

# team-nudge already handles /team and /team-next — stay silent there to avoid double nudges.
if printf '%s' "$PROMPT" | grep -qiE 'fullstack-team:team|(^|[[:space:]])/team(-next)?([[:space:]]|$)'; then
  exit 0
fi

lc="$(printf '%s' "$PROMPT" | tr '[:upper:]' '[:lower:]')"

has() { printf '%s' "$lc" | grep -qE "$1"; }

# Intent — what kind of work. Require at least one to fire at all.
intent=""
if   has '\b(fix|bug|broken|error|crash|fails?|doesnt work|does not work|regression|stacktrace)\b'; then intent="bug"
elif has '\b(add|implement|create|build|new feature|introduce|support for)\b'; then intent="feature"
elif has '\b(refactor|clean ?up|simplify|restructure|extract|rename)\b'; then intent="refactor"
elif has '\b(review|audit|check( the)? (code|diff|pr)|feedback)\b'; then intent="review"
fi
[ -z "$intent" ] && exit 0

# Stack — map keywords to the skills that carry that domain. Require >=1 (else stay quiet).
skills=""
add_skill() { case " $skills " in *" $1 "*) ;; *) skills="$skills $1";; esac; }

has '\b(spring|spring ?boot|controller|@service|jpa)\b'           && add_skill kotlin-spring-boot
has '\b(jooq|sql query|repository|postgres)\b'                    && add_skill jooq-patterns
has '\b(ktor)\b'                                                  && add_skill ktor-client
has '\b(telegram|bot|ktgbotapi|inline keyboard)\b'               && add_skill ktgbotapi-patterns
has '\b(go|golang|goroutine|grpc)\b'                             && add_skill go-patterns
has '\b(channel|sync\.|mutex|waitgroup|concurren)\b'            && add_skill go-concurrency
has '\b(microservice|service discovery|circuit breaker)\b'      && add_skill go-microservices
has '\b(react|tsx|jsx|vite)\b'                                   && add_skill react-vite
has '\b(mini ?app|webapp|initdata)\b'                            && add_skill telegram-mini-apps
has '\b(compose|kmp|multiplatform|decompose)\b'                  && add_skill compose-arch
has '\b(koog|llm|ai agent|tool calling|prompt)\b'               && add_skill koog
has '\b(workmanager|background (work|task|sync))\b'            && add_skill workmanager
has '\b(opentelemetry|tracing|observability|metrics)\b'         && add_skill opentelemetry

skills="$(printf '%s' "$skills" | sed 's/^ *//')"
[ -z "$skills" ] && exit 0

# Map intent -> the workflow that fits.
case "$intent" in
  bug)      wf="/team (classifies as BUG_FIX → bug-fix / debug-cycle profile)";;
  feature)  wf="/team (classifies as FEATURE → standard / full-feature profile)";;
  refactor) wf="/team (classifies as REFACTOR)";;
  review)   wf="/team (classifies as REVIEW → parallel review profile)";;
esac

echo "💡 skill-suggest: this looks like a ${intent} task touching: ${skills}."
echo "   Consider running ${wf}, and load the matching skill(s) before coding:"
for s in $skills; do echo "     • Skill: $s"; done
exit 0
