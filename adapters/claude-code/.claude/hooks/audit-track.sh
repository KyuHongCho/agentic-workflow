#!/usr/bin/env bash
# SubagentStop hook (Claude Code). Keeps score of the audit loop: records that a role ran
# (an audit is now owed) and clears the debt when the matching auditor runs.
# Never blocks anything — audit-gate.sh does the enforcing.
STATE="${CLAUDE_PROJECT_DIR:-$PWD}/.audit-pending"   # one role name per line = audits still owed
payload=$(cat)

# Which subagent just finished? Parse the TOP-LEVEL agent_type: a greedy sed matches the LAST
# one, which may be nested in background_tasks — that misread billed roles that never finished.
agent=$(printf '%s' "$payload" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("agent_type") or "")' 2>/dev/null)
[ -n "$agent" ] || exit 0                            # not a subagent we can identify -> nothing to do

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
    #
    # Cost: whether a self-blocked role owes a debt depends on .gate at SubagentStop, not on the
    # role. Blocked gate -> no line; otherwise a line it does not owe. So a leftover line cannot be
    # attributed to the role that just blocked — the ledger holds bare role names — and may be
    # another role's real, unaudited debt. Loud and recoverable beats an audit that never happens.
    if [ -f "$GATE" ] && grep -vE '^[[:space:]]*#' "$GATE" | grep -qE '^[[:space:]]*status:[[:space:]]*blocked'; then exit 0; fi
    # One line per COMPLETION, NOT deduped: two slices owe two audits, per
    # core/shared/vertical-slices.md. A resumed role hands back repeatedly and so records more
    # lines than artifacts, but deduping would collapse the genuine two-slices case.
    # audit-gate.sh explains which is which.
    echo "$agent" >> "$STATE"
    ;;
  plan-audit|build-audit|review-audit)               # an auditor ran -> clear exactly ONE debt
    role="${agent%-audit}"
    tmp="$STATE.tmp.$$"
    awk -v r="$role" 'BEGIN{done=0} $0==r && !done {done=1; next} {print}' "$STATE" > "$tmp"
    mv "$tmp" "$STATE"
    ;;
esac
exit 0
