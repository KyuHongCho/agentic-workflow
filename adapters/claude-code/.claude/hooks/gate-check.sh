#!/usr/bin/env bash
# PreToolUse hook (Claude Code). Gates *mutating* tools (Write/Edit/Bash) while grilling has open
# questions. Reading, searching and asking stay allowed; only *changing things* is gated.
#
# The human releases the gate by answering the approval prompt this raises — the same mechanism
# ship-gate.sh uses (:10-11) and for the same reason: the agent cannot forge that prompt, so
# "only a human clears the gate" still holds. Where a prompt would NOT be shown, this falls back to
# exit 2, because an unshown prompt is not an answer (ship-gate.sh:105-116).
# No `set -e` here: under it a missing helper below would end the hook silently on bash 3.2.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
unset AGENTIC_SS_LOADED
. "$HERE/session-state.sh" 2>/dev/null || true
if [ "${AGENTIC_SS_LOADED:-}" != 1 ]; then
  # Helper missing or truncated: use the shared .gate. Key only on USE_LEGACY and an empty sid_dir,
  # never on any other helper function -- a half-loaded helper may define some of them.
  sid_dir() { :; }
  USE_LEGACY=1
fi
ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"   # :-$PWD matches audit-gate.sh and bin/unblock

# Comment lines are the questions, and a question may quote the phrase "status: blocked". Strip
# them first and take the FIRST status, or the gate fails open on its own question text.
is_blocked() {
  [ -f "$1" ] || return 1
  [ "$(grep -vE '^[[:space:]]*#' "$1" | grep -oE '^[[:space:]]*status:[[:space:]]*(done|blocked)' | head -1 | awk '{print $2}')" = blocked ]
}

# Nothing that could hold a gate exists -> nothing to read from stdin or to parse.
if [ ! -f "$ROOT/.gate" ] && [ ! -d "$ROOT/.agentic" ]; then rm -f "$ROOT/.gate-asked"; exit 0; fi

payload=$(cat)
# The payload id decides which gate is ours; the env var covers a payload that lacks it.
sid=$(printf '%s' "$payload" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("session_id") or "")' 2>/dev/null)
[ -n "$sid" ] || sid="${CLAUDE_CODE_SESSION_ID:-}"
sdir=""
[ "${USE_LEGACY:-}" = 1 ] || sdir=$(sid_dir "$sid")

# This session's own gate first; a blocked legacy .gate also gates (and is releasable by) any session.
GATE=""
if [ -n "$sdir" ] && is_blocked "$sdir/gate"; then GATE="$sdir/gate"
elif is_blocked "$ROOT/.gate"; then GATE="$ROOT/.gate"; fi
[ -n "$sdir" ] && ! is_blocked "$sdir/gate" && rm -f "$sdir/gate-asked"
is_blocked "$ROOT/.gate" || rm -f "$ROOT/.gate-asked"

if [ -z "$GATE" ]; then
  # Another session's blocked gate never gates this one, but a gate written under an id this session
  # does not carry would otherwise fail open unseen, so say so -- once, and never block.
  if [ "${USE_LEGACY:-}" != 1 ]; then
    n=0; first=""
    for g in "$ROOT"/.agentic/*/gate; do
      d="${g%/gate}"; [ "$d" = "$sdir" ] && continue
      if is_blocked "$g"; then n=$((n+1)); [ -n "$first" ] || first="${d##*/}"; fi
    done
    [ "$n" -gt 0 ] && echo "$n blocked gate(s) exist for other sessions (first: $first); this session is ${sid:-unidentified}" >&2
  fi
  exit 0
fi
MARK="$GATE-asked"
if [ "$GATE" = "$ROOT/.gate" ]; then SCOPE="the shared legacy gate (.gate), which holds every session that has none of its own"
else SCOPE="this session's gate only"; fi

GATE_FILE="$GATE" GATE_MARK="$MARK" GATE_SCOPE="$SCOPE" GATE_PAYLOAD="$payload" python3 - <<'PY'
import hashlib, json, os, sys
try:
    d = json.loads(os.environ.get("GATE_PAYLOAD") or "")
except Exception:                            # cannot tell subagent from main thread -> fail closed
    sys.stderr.write("Blocked: the grilling gate is set and the hook payload was unreadable, so "
                     "this cannot tell whether a prompt would be shown. Failing closed.\n")
    sys.exit(2)

raw = open(os.environ["GATE_FILE"], "rb").read()
q = "\n".join(l for l in raw.decode("utf-8", "replace").splitlines()
              if l.lstrip().startswith("#")) or "(gate file lists no questions)"

if d.get("agent_id"):                        # a subagent has no channel to ask -> hard block
    sys.stderr.write('Blocked: the grilling gate is set and you are inside the "{a}" subagent. '
                     "Report what you need and hand back to the main thread.\n"
                     "Open questions:\n{q}\n".format(a=d.get("agent_type") or "subagent", q=q))
    sys.exit(2)

mode = d.get("permission_mode") or "default"
tool = d.get("tool_name") or ""
if mode in ("bypassPermissions", "dontAsk") or (mode == "acceptEdits" and tool in ("Write", "Edit")):
    sys.stderr.write("Blocked: the grilling gate is set and permission_mode is '{m}', so no prompt "
                     "would be shown for {t} - and an unshown prompt is not an answer. Ask the "
                     "human in the conversation; they release it with bin/unblock.\n"
                     "Open questions:\n{q}\n".format(m=mode, t=tool or "this tool", q=q))
    sys.exit(2)

# Proof that a human was prompted about THIS gate. gate-clear.sh refuses to release without it.
open(os.environ["GATE_MARK"], "w").write(hashlib.sha256(raw).hexdigest() + "\n")

print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason":
        "GRILLING GATE - these questions are still open:\n" + q +
        "\n\nApproving releases " + os.environ["GATE_SCOPE"] + ". Decline if they are unanswered."
}}))
PY
exit $?
