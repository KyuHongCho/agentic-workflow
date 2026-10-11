#!/usr/bin/env bash
# Stop hook (Claude Code). Refuses to end the turn while any role's adversarial audit is
# still owed. This is what makes the loop *always* run instead of run-when-remembered.
# No `set -e` here: under it a missing helper below would end the hook silently on bash 3.2.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
unset AGENTIC_SS_LOADED
. "$HERE/session-state.sh" 2>/dev/null || true
if [ "${AGENTIC_SS_LOADED:-}" != 1 ]; then
  # Helper missing or truncated: fall back to the shared ledger. Key only on USE_LEGACY and an empty
  # sid_dir, never on any other helper function -- a half-loaded helper may define some of them.
  sid_dir() { :; }
  USE_LEGACY=1
fi
ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
payload=$(cat)

# Escape hatch: if a previous Stop hook already blocked and we're looping, let it go.
case "$payload" in *'"stop_hook_active":true'*|*'"stop_hook_active": true'*) exit 0 ;; esac

# Deadlock guard: while this session's (or the legacy shared) grilling gate is 'blocked', auditors cannot
# run Bash/Edit (gate-check.sh blocks those in subagents too), so demanding an audit would livelock the
# turn: the human owes an answer. Another session's blocked gate gates its own tools, not ours.
session_id=$(printf '%s' "$payload" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("session_id") or "")' 2>/dev/null)
sdir=""
[ "${USE_LEGACY:-}" = 1 ] || sdir=$(sid_dir "$session_id")
GATES=("$ROOT/.gate")
[ -n "$sdir" ] && GATES+=("$sdir/gate")
for GATE in "${GATES[@]}"; do
  if [ -f "$GATE" ] && [ "$(grep -vE '^[[:space:]]*#' "$GATE" | grep -oE '^[[:space:]]*status:[[:space:]]*(done|blocked)' | head -1 | awk '{print $2}')" = blocked ]; then exit 0; fi
done

# Enforce only THIS session's ledger. No usable session id -> the shared legacy ledger plus every
# per-session one: the debt may belong to this very session under an id this payload failed to carry.
LEDGERS=()
NOID=0
if [ "${USE_LEGACY:-}" = 1 ]; then
  [ -s "$ROOT/.audit-pending" ] && LEDGERS+=("$ROOT/.audit-pending")
elif [ -n "$sdir" ]; then
  [ -s "$sdir/audit-pending" ] && LEDGERS+=("$sdir/audit-pending")
else
  NOID=1
  [ -s "$ROOT/.audit-pending" ] && LEDGERS+=("$ROOT/.audit-pending")
  for f in "$ROOT"/.agentic/*/audit-pending; do [ -s "$f" ] && LEDGERS+=("$f"); done
fi
[ "${#LEDGERS[@]}" -gt 0 ] || exit 0                 # nothing owed -> allow the turn to end

# Field 1 is the role; a bare pre-format line has no tab, so cut returns the whole line.
pending=$(cut -f1 "${LEDGERS[@]}" | tr '\n' ' ' | sed 's/ *$//')
{
  echo "Blocked: the adversarial audit loop has not been run for: ${pending}."
  echo "(One OPEN entry per subagent, keyed on agent_id: a role that hands back more than once for"
  echo " the same artifact updates its entry rather than adding one. So two 'build' entries are two"
  echo " different subagents — two slices — and each owes its own audit.)"
  for ledger in "${LEDGERS[@]}"; do
    where=""
    [ "$NOID" = 1 ] && where=" [ledger: ${ledger#$ROOT/}]"
    # '|| [ -n "$r" ]' so a final line with no trailing newline is not silently dropped.
    while IFS="$(printf '\t')" read -r r id ts || [ -n "$r" ]; do
      [ -n "$r" ] || continue
      echo "  - dispatch '${r}-audit' for the '${r}' run by agent ${id:-unknown} at ${ts:-unknown}${where}, per \$AGENTIC_WORKFLOW_HOME/core/shared/audit-loop.md"
    done < "$ledger"
  done
  echo "Each auditor run clears the OLDEST entry for that role — audit them in that order. Out of"
  echo "order, the surviving entry still carries the AUDITED run's id and time: the count is right,"
  echo "the attribution is not, so do not clear by id in that state."
  echo "If an entry has no artifact behind it, say so and ask the human to run"
  echo "  \$AGENTIC_WORKFLOW_HOME/adapters/claude-code/bin/audit-clear <agent_id>"
  echo "— an entry shown as agent 'unknown' predates the metadata and is cleared by role name"
  echo "instead. Never edit a ledger file yourself."
  if [ "$NOID" = 1 ]; then
    echo "This Stop payload carried no usable session id, so every session's ledger is enforced; an"
    echo "entry may belong to another session, and audit-clear <agent_id> is then the only exit."
  fi
  echo "On REVISE, hand the objection list back to the role verbatim and re-audit."
  echo "Do not finish until every audit returns PASS, or escalate to the human with the full objection history."
} >&2
exit 2                                               # Stop + exit 2 = don't stop; stderr goes to the model
