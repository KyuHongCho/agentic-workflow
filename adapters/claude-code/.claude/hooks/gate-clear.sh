#!/usr/bin/env bash
# PostToolUse hook (Claude Code). Releases the grilling gate once a mutating tool has ACTUALLY run
# — but ONLY when gate-check.sh recorded that a human was prompted about *this exact* gate.
# The `gate-asked` marker beside this session's (or the legacy) gate holds a sha256 of it as it stood when prompted.
#
# The marker is what makes this safe. Without it, this would wipe the gate the agent itself just
# set: the agent's own `echo 'status: blocked' > .gate` is a successful Bash call and PostToolUse
# fires on it. Matching the checksum, not merely the marker's presence, also stops an approval of a
# gate *edit* (adding a question) from being read as an approval to release.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
unset AGENTIC_SS_LOADED
. "$HERE/session-state.sh" 2>/dev/null || true   # no set -e: it would end the hook silently here on bash 3.2
if [ "${AGENTIC_SS_LOADED:-}" != 1 ]; then
  # Helper missing or truncated: use the shared .gate. Key only on USE_LEGACY and an empty sid_dir,
  # never on any other helper function -- a half-loaded helper may define some of them.
  sid_dir() { :; }
  USE_LEGACY=1
fi
ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"

# No prompt receipt anywhere -> nothing to release, and no payload worth parsing.
have=0; [ -f "$ROOT/.gate-asked" ] && have=1
for m in "$ROOT"/.agentic/*/gate-asked; do [ -f "$m" ] && have=1; done
[ "$have" = 1 ] || exit 0

payload=""; [ -t 0 ] || payload=$(cat)   # a terminal on stdin means no payload is coming
sid=$(printf '%s' "$payload" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("session_id") or "")' 2>/dev/null)
[ -n "$sid" ] || sid="${CLAUDE_CODE_SESSION_ID:-}"
sdir=""
[ "${USE_LEGACY:-}" = 1 ] || sdir=$(sid_dir "$sid")

release() {   # $1 gate file | $2 its prompt receipt
  local GATE="$1" MARK="$2" now qs
  [ -f "$GATE" ] && [ -f "$MARK" ] || return 0
  [ "$(grep -vE '^[[:space:]]*#' "$GATE" | grep -oE '^[[:space:]]*status:[[:space:]]*(done|blocked)' | head -1 | awk '{print $2}')" = blocked ] || { rm -f "$MARK"; return 0; }
  now=$(GATE_FILE="$GATE" python3 -c 'import hashlib,os;print(hashlib.sha256(open(os.environ["GATE_FILE"],"rb").read()).hexdigest())' 2>/dev/null)
  [ -n "$now" ] && [ "$now" = "$(head -1 "$MARK")" ] || return 0
  qs=$(grep -E '^[[:space:]]*#' "$GATE")     # keep the questions as a record of what was released
  { printf 'status: done\n'
    [ -n "$qs" ] && printf '%s\n' "$qs"
    printf '# released by human approval, %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z (%z)')"
  } > "$GATE"
  rm -f "$MARK"
}

# Only this session's gate and the shared legacy one: another session's receipt is not ours to act on.
[ -n "$sdir" ] && release "$sdir/gate" "$sdir/gate-asked"
release "$ROOT/.gate" "$ROOT/.gate-asked"
exit 0
