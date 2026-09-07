#!/usr/bin/env bash
# SubagentStop hook (Claude Code). Keeps score of the audit loop: records that a role ran
# (an audit is now owed) and clears the debt when the matching auditor runs.
# Never blocks anything — audit-gate.sh does the enforcing.
STATE="${CLAUDE_PROJECT_DIR:-$PWD}/.audit-pending"   # one TAB-separated entry per line: role, agent_id, UTC stamp
payload=$(cat)

# Which subagent just finished? Parse the TOP-LEVEL agent_type: a greedy sed matches the LAST
# one, which may be nested in background_tasks — that misread billed roles that never finished.
agent=$(printf '%s' "$payload" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("agent_type") or "")' 2>/dev/null)
[ -n "$agent" ] || exit 0                            # not a subagent we can identify -> nothing to do

# agent_id is unique per subagent and STABLE across a resume (verified against real payloads), so it
# distinguishes "one artifact handed back twice" from "two slices". Absent on older CLIs: the guard
# below simply never fires and we append as before, which over-counts but never under-counts.
agent_id=$(printf '%s' "$payload" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("agent_id") or "")' 2>/dev/null)

# A role that self-blocked on grilling asked a QUESTION rather than producing an artifact, so it
# owes no audit. Only a line that IS the status counts: comment lines are stripped and the match is
# anchored, so a question in .gate quoting the phrase must never suppress a real debt.
GATE="${CLAUDE_PROJECT_DIR:-$PWD}/.gate"

touch "$STATE"
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
    if [ -n "$agent_id" ] && awk -F'\t' -v a="$agent_id" '$2==a{f=1} END{exit !f}' "$STATE"; then exit 0; fi
    printf '%s\t%s\t%s\n' "$agent" "${agent_id:-unknown}" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" >> "$STATE"
    ;;
  plan-audit|build-audit|review-audit)               # an auditor ran -> clear exactly ONE debt
    role="${agent%-audit}"
    tmp="$STATE.tmp.$$"
    # Match FIELD 1, not the whole line: a bare pre-format line has no tab, so $1 is the whole line
    # and an old ledger still clears correctly.
    awk -F'\t' -v r="$role" 'BEGIN{done=0} $1==r && !done {done=1; next} {print}' "$STATE" > "$tmp"
    mv "$tmp" "$STATE"
    ;;
esac
exit 0
