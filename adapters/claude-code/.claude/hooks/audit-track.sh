#!/usr/bin/env bash
# SubagentStop hook (Claude Code). Keeps score of the audit loop: records that a role ran
# (an audit is now owed) and clears the debt when the matching auditor runs.
# Never blocks anything — audit-gate.sh does the enforcing.
STATE="${CLAUDE_PROJECT_DIR:-$PWD}/.audit-pending"   # one role name per line = audits still owed
payload=$(cat)

# Which subagent just finished? Claude Code supplies `agent_type` on SubagentStop.
agent=$(printf '%s' "$payload" | sed -n 's/.*"agent_type"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
[ -n "$agent" ] || exit 0                            # not a subagent we can identify -> nothing to do

# A role that self-blocked on grilling produced a QUESTION, not an artifact — there is
# nothing to audit, and handoff.md forbids handing off while blocked. Recording a debt
# here would penalise the role for correctly refusing to proceed on an assumption.
GATE="${CLAUDE_PROJECT_DIR:-$PWD}/.gate"
if [ -f "$GATE" ] && grep -qE 'status:[[:space:]]*blocked' "$GATE"; then exit 0; fi

touch "$STATE"
case "$agent" in
  plan|build|review)                                 # a role finished -> one more audit owed
    # One line per run, NOT deduped: `build ↔ build-audit` runs once per vertical slice
    # (see core/shared/vertical-slices.md), so two slices owe two audits.
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
