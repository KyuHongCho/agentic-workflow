#!/usr/bin/env bash
# SessionStart hook (Claude Code): /clear and --fork-session leave the old id's state behind; say so once.
# Advisory only: always exits 0, never writes, moves or deletes. Cleanup is the human's.
# No `set -e` here: under it a missing helper below would end the hook silently on bash 3.2.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
unset AGENTIC_SS_LOADED
. "$HERE/session-state.sh" 2>/dev/null || true
if [ "${AGENTIC_SS_LOADED:-}" != 1 ]; then
  # Helper missing or truncated: no own session can be told apart, so every folder is a candidate.
  # Key only on USE_LEGACY and an empty sid_dir, never on any other helper function.
  sid_dir() { :; }
  USE_LEGACY=1
fi
ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
payload=$(cat)

# Compaction keeps the session id, so nothing can have been orphaned by it.
src=$(printf '%s' "$payload" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("source") or "")' 2>/dev/null)
[ "$src" = compact ] && exit 0
sid=$(printf '%s' "$payload" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("session_id") or "")' 2>/dev/null)
[ -n "$sid" ] || sid="${CLAUDE_CODE_SESSION_ID:-}"
own=""
if [ "${USE_LEGACY:-}" != 1 ]; then own=$(sid_dir "$sid"); own="${own##*/}"; fi

is_blocked() {
  [ -f "$1" ] || return 1
  [ "$(grep -vE '^[[:space:]]*#' "$1" | grep -oE '^[[:space:]]*status:[[:space:]]*(done|blocked)' | head -1 | awk '{print $2}')" = blocked ]
}

debt=0; gates=0; legacy=""
for d in "$ROOT"/.agentic/*/; do
  [ -d "$d" ] || continue
  d="${d%/}"; [ -n "$own" ] && [ "${d##*/}" = "$own" ] && continue
  [ -s "$d/audit-pending" ] && debt=$((debt+1))
  is_blocked "$d/gate" && gates=$((gates+1))
done
[ -s "$ROOT/.audit-pending" ] && legacy="$legacy audit debt"
is_blocked "$ROOT/.gate" && legacy="$legacy${legacy:+ and} blocked gate"
[ $((debt+gates)) -gt 0 ] || [ -n "$legacy" ] || exit 0

parts=""
[ "$debt" -gt 0 ] && parts="$debt with audit debt"
[ "$gates" -gt 0 ] && parts="$parts${parts:+, }$gates with a blocked gate"
[ -n "$legacy" ] && parts="$parts${parts:+; }the shared legacy files hold${legacy}"
BIN='$AGENTIC_WORKFLOW_HOME/adapters/claude-code/bin'
msg="Other sessions' state exists under ${ROOT} (this session: ${sid:-unidentified}): $parts. It is stale if that session ended or was left by /clear or --fork-session, but a session running now looks the same. Review it with $BIN/audit-clear and $BIN/unblock; nothing was changed."

# additionalContext reaches the model and systemMessage the user (stderr reaches neither); plain stdout is the fallback.
MSG="$msg" python3 -c 'import json,os; m=os.environ["MSG"]; print(json.dumps({"systemMessage":m,"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":m}}))' 2>/dev/null || printf '%s\n' "$msg"
exit 0
