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
# That suppression is read from ONE signal: the gate file, the out-of-band channel the
# role writes deliberately. Matched narrowly on a "status: blocked" line — a plan
# legitimately contains "Blocked by:" lines for its slice edges, and those must NOT
# suppress a real audit debt.
GATE="${CLAUDE_PROJECT_DIR:-$PWD}/.gate"

touch "$STATE"
case "$agent" in
  plan|build|review)                                 # a role finished -> one more audit owed
    # Suppression is read ONLY from .gate — never inferred from the report's prose.
    # A second check used to sit alongside this one, grepping the subagent's own closing
    # words for /status:.{0,20}blocked/i: a CONTROL decision taken from CONTENT. But any
    # artifact ABOUT these gates contains that phrase — the docs do, this comment does —
    # so a role writing about the workflow had its audit skipped silently: no output, no
    # failure, green self-tests. .gate is a channel the role writes on purpose; its prose
    # is not. audit-gate.selftest.sh pins this rather than asserting it: its two "role
    # writing ABOUT the gate" cases fail against the pre-fix hook and pass here.
    #
    # The check lives HERE, inside the role branch — NEVER before the case. An AUDITOR must
    # never be suppressed: its whole job is to CLEAR a debt. Sited before the case it also
    # skipped the clearing branch below, so an auditor whose report merely quoted the phrase
    # left the debt it had just discharged sitting in the ledger, and audit-gate.sh blocked
    # every turn end from then on. Measured here: the plan-audit that completed
    # 2026-09-05T17:00:55Z returned REVISE and did NOT clear the `plan` debt observed in
    # `.audit-pending` at 16:51:32Z. The gate cannot explain that — `.gate` read
    # "status: done" at 16:56:42Z, and audit-gate.sh stands down on a blocked gate, so its
    # block at 17:02:34Z proves the gate still open on the far side of that completion.
    # The debt went on to block eight consecutive turn ends, 16:53:31Z to 19:25:45Z, until
    # it was cleared by hand. The selftest case "auditor not suppressed by a blocked .gate"
    # is what stops that placement coming back.
    #
    # Accepted cost: a role subagent cannot mirror .gate before its own SubagentStop fires —
    # nothing in core/ or adapters/claude-code/agents/ so much as names the file; only the
    # main thread mirrors it, and only after reading the report. So a self-blocked ROLE
    # always records a spurious debt, not merely an un-mirrored one. That is loud — the next
    # turn end names the role — and cleared by deleting the line, unlike an audit that
    # silently never happens.
    if [ -f "$GATE" ] && grep -vE '^[[:space:]]*#' "$GATE" | grep -qE '^[[:space:]]*status:[[:space:]]*blocked'; then exit 0; fi
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
