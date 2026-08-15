#!/usr/bin/env bash
# PreToolUse hook (Claude Code). Blocks a *mutating* tool (Write/Edit/Bash) while the workflow
# gate is 'blocked' — i.e. grilling has open, unresolved questions. Reading, searching, and
# grilling (asking the human) stay allowed; only *changing things* is gated.
GATE="${CLAUDE_PROJECT_DIR}/.gate"                 # the "traffic light" file at the project root
[ -f "$GATE" ] || exit 0                            # no gate present -> nothing to enforce -> allow
status=$(grep -oE 'status:[[:space:]]*(done|blocked)' "$GATE" | awk '{print $2}')
if [ "$status" = "blocked" ]; then
  echo "Blocked: open grilling questions are unresolved. Resolve them (grill the human), set the gate to 'done', then retry." >&2
  exit 2                                            # PreToolUse + exit 2 = block this tool; stderr is shown to the model
fi
exit 0                                              # gate is 'done' (or absent) -> allow
