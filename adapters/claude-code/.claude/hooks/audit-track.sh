#!/usr/bin/env bash
# SubagentStop hook (Claude Code). Keeps score of the audit loop: records that a role ran
# (an audit is now owed) and clears the debt when the matching auditor runs.
# Never blocks anything — audit-gate.sh does the enforcing.
STATE="${CLAUDE_PROJECT_DIR:-$PWD}/.audit-pending"   # one role name per line = audits still owed
payload=$(cat)

# Which subagent just finished? Claude Code supplies `agent_type` on SubagentStop.
# Parse the TOP-LEVEL agent_type. A greedy sed matches the LAST "agent_type" in the
# payload, which can be one nested inside background_tasks — that misread was the cause
# of spurious debts attributed to roles that had not finished.
agent=$(printf '%s' "$payload" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("agent_type") or "")' 2>/dev/null)
[ -n "$agent" ] || exit 0                            # not a subagent we can identify -> nothing to do

# A role that self-blocked on grilling produced a QUESTION, not an artifact — there is
# nothing to audit, and handoff.md forbids handing off while blocked. Recording a debt
# here would penalise the role for correctly refusing to proceed on an assumption.
#
# Two independent signals, because neither alone is reliable: the gate file (which the
# role is instructed to mirror, but does not always) and the role's own closing words.
# Matched narrowly on "status: blocked" — a plan legitimately contains "Blocked by:"
# lines for its slice edges, and those must NOT suppress a real audit debt.
GATE="${CLAUDE_PROJECT_DIR:-$PWD}/.gate"
if [ -f "$GATE" ] && grep -vE '^[[:space:]]*#' "$GATE" | grep -qE 'status:[[:space:]]*blocked'; then exit 0; fi
if printf '%s' "$payload" | grep -qiE '[Ss]tatus:[^"]{0,20}blocked'; then exit 0; fi

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
