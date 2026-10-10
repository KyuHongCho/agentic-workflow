#!/usr/bin/env bash
# SubagentStop hook (Claude Code). Keeps score of the audit loop: records that a role ran
# (an audit is now owed) and clears the debt when the matching auditor runs.
# Never blocks anything — audit-gate.sh does the enforcing.
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
payload=$(cat)

# Which subagent just finished? Parse the TOP-LEVEL agent_type: a greedy sed matches the LAST
# one, which may be nested in background_tasks — that misread billed roles that never finished.
agent=$(printf '%s' "$payload" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("agent_type") or "")' 2>/dev/null)
[ -n "$agent" ] || exit 0                            # not a subagent we can identify -> nothing to do

# agent_id is unique per subagent and STABLE across a resume (verified against real payloads), so it
# distinguishes "one artifact handed back twice" from "two slices". Absent on older CLIs: the guard
# below simply never fires and we append as before, which over-counts but never under-counts.
agent_id=$(printf '%s' "$payload" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("agent_id") or "")' 2>/dev/null)
session_id=$(printf '%s' "$payload" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("session_id") or "")' 2>/dev/null)

# One ledger per session, so another session's auditor can never clear this session's debt.
# No usable session id -> the shared legacy ledger, exactly as before.
STATE="${CLAUDE_PROJECT_DIR:-$PWD}/.audit-pending"   # one TAB-separated entry per line: role, agent_id, UTC stamp
PER_SESSION=0
if [ "${USE_LEGACY:-}" != 1 ]; then
  sdir=$(sid_dir "$session_id")
  if [ -n "$sdir" ]; then STATE="$sdir/audit-pending"; PER_SESSION=1; fi
fi

# A role that self-blocked on grilling asked a QUESTION rather than producing an artifact, so it
# owes no audit. Only a line that IS the status counts: comment lines are stripped and the match is
# anchored, so a question in .gate quoting the phrase must never suppress a real debt.
GATE="${CLAUDE_PROJECT_DIR:-$PWD}/.gate"

case "$agent" in
  plan|build|review)                                 # a role finished -> one more audit owed
    # Read suppression ONLY from .gate, never from the report's prose: every artifact ABOUT
    # these gates quotes that phrase, so treating prose as control skipped audits in silence.
    #
    # The check belongs HERE, inside the role branch — never before the case, or it skips the
    # clearing branch too and an auditor can never pay off the debt it just discharged. The
    # selftest case "auditor not suppressed by a blocked .gate" is what stops that coming back.
    if [ -f "$GATE" ] && grep -vE '^[[:space:]]*#' "$GATE" | grep -qE '^[[:space:]]*status:[[:space:]]*blocked'; then exit 0; fi
    # ONE OPEN ENTRY PER SUBAGENT, keyed on agent_id. A role that hands back more than once for the
    # same artifact (it paused for the human, or was re-dispatched) updates its open entry instead of
    # adding a second. Two slices are two different agent_ids and still owe two audits; after a
    # REVISE the prior entry was already cleared, so the next hand-back correctly opens a fresh one.
    if [ -n "$agent_id" ] && [ -f "$STATE" ] && awk -F'\t' -v a="$agent_id" '$2==a{f=1} END{exit !f}' "$STATE"; then exit 0; fi
    [ "$PER_SESSION" = 1 ] && mkdir -p "$sdir"       # created on first debt, never on a bare SubagentStop
    printf '%s\t%s\t%s\n' "$agent" "${agent_id:-unknown}" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >> "$STATE"
    ;;
  plan-audit|build-audit|review-audit)               # an auditor ran -> clear exactly ONE debt
    role="${agent%-audit}"
    [ -f "$STATE" ] || exit 0                        # nothing recorded here -> nothing to clear
    tmp="$STATE.tmp.$$"
    # Match FIELD 1, not the whole line: a bare pre-format line has no tab, so $1 is the whole line
    # and an old ledger still clears correctly.
    awk -F'\t' -v r="$role" 'BEGIN{done=0} $1==r && !done {done=1; next} {print}' "$STATE" > "$tmp"
    # A per-session ledger that empties is deleted; the legacy file stays, as it always has.
    if [ "$PER_SESSION" = 1 ] && [ ! -s "$tmp" ]; then rm -f "$tmp" "$STATE"; else mv "$tmp" "$STATE"; fi
    ;;
esac
exit 0
