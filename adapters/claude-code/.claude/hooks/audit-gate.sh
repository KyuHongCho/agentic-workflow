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
if [ -f "$GATE" ] && grep -qE 'status:[[:space:]]*blocked' "$GATE"; then exit 0; fi

[ -s "$STATE" ] || exit 0                            # nothing owed -> allow the turn to end

pending=$(tr '\n' ' ' < "$STATE" | sed 's/ *$//')
{
  echo "Blocked: the adversarial audit loop has not been run for: ${pending}."
  echo "(One entry per role run — 'build build' means two slices landed and each owes its own audit.)"
  for r in $(printf '%s\n' $pending | sort -u); do
    n=$(printf '%s\n' $pending | grep -cxF "$r")
    echo "  - dispatch the '${r}-audit' subagent ${n}x — once per artifact '${r}' produced, per \$AGENTIC_WORKFLOW_HOME/core/shared/audit-loop.md"
  done
  echo "On REVISE, hand the objection list back to the role verbatim and re-audit."
  echo "Do not finish until every audit returns PASS, or escalate to the human with the full objection history."
} >&2
exit 2                                               # Stop + exit 2 = don't stop; stderr goes to the model
