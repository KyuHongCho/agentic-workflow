#!/usr/bin/env bash
# Stop hook (Claude Code). Refuses to end the turn while any role's adversarial audit is
# still owed. This is what makes the loop *always* run instead of run-when-remembered.
STATE="${CLAUDE_PROJECT_DIR:-$PWD}/.audit-pending"
payload=$(cat)

# Escape hatch: if a previous Stop hook already blocked and we're looping, let it go.
case "$payload" in *'"stop_hook_active":true'*|*'"stop_hook_active": true'*) exit 0 ;; esac

# Deadlock guard: while the grilling gate is 'blocked', auditors cannot run Bash/Edit
# (gate-check.sh blocks those inside subagents too), so demanding an audit now would
# livelock the turn. At that point the human owes an answer, not the agent.
GATE="${CLAUDE_PROJECT_DIR:-$PWD}/.gate"
if [ -f "$GATE" ] && grep -vE '^[[:space:]]*#' "$GATE" | grep -qE '^[[:space:]]*status:[[:space:]]*blocked'; then exit 0; fi

[ -s "$STATE" ] || exit 0                            # nothing owed -> allow the turn to end

# Field 1 is the role; a bare pre-format line has no tab, so cut returns the whole line.
pending=$(cut -f1 < "$STATE" | tr '\n' ' ' | sed 's/ *$//')
{
  echo "Blocked: the adversarial audit loop has not been run for: ${pending}."
  echo "(One OPEN entry per subagent, keyed on agent_id: a role that hands back more than once for"
  echo " the same artifact updates its entry rather than adding one. So two 'build' entries are two"
  echo " different subagents — two slices — and each owes its own audit.)"
  # '|| [ -n "$r" ]' so a final line with no trailing newline is not silently dropped.
  while IFS="$(printf '\t')" read -r r id ts || [ -n "$r" ]; do
    [ -n "$r" ] || continue
    echo "  - dispatch '${r}-audit' for the '${r}' run by agent ${id:-unknown} at ${ts:-unknown}, per \$AGENTIC_WORKFLOW_HOME/core/shared/audit-loop.md"
  done < "$STATE"
  echo "Each auditor run clears the OLDEST entry for that role — audit them in that order. Out of"
  echo "order, the surviving entry still carries the AUDITED run's id and time: the count is right,"
  echo "the attribution is not, so do not clear by id in that state."
  echo "If an entry has no artifact behind it, say so and ask the human to run"
  echo "  \$AGENTIC_WORKFLOW_HOME/adapters/claude-code/bin/audit-clear <agent_id>"
  echo "— an entry shown as agent 'unknown' predates the metadata and is cleared by role name"
  echo "instead. Never edit .audit-pending yourself."
  echo "On REVISE, hand the objection list back to the role verbatim and re-audit."
  echo "Do not finish until every audit returns PASS, or escalate to the human with the full objection history."
} >&2
exit 2                                               # Stop + exit 2 = don't stop; stderr goes to the model
