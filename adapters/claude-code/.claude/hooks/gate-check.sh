#!/usr/bin/env bash
# PreToolUse hook (Claude Code). Gates *mutating* tools (Write/Edit/Bash) while grilling has open
# questions. Reading, searching and asking stay allowed; only *changing things* is gated.
#
# The human releases the gate by answering the approval prompt this raises — the same mechanism
# ship-gate.sh uses (:10-11) and for the same reason: the agent cannot forge that prompt, so
# "only a human clears the gate" still holds. Where a prompt would NOT be shown, this falls back to
# exit 2, because an unshown prompt is not an answer (ship-gate.sh:105-116).
GATE="${CLAUDE_PROJECT_DIR:-$PWD}/.gate"   # :-$PWD matches audit-gate.sh:13 and bin/unblock:6
MARK="$GATE-asked"
[ -f "$GATE" ] || { rm -f "$MARK"; exit 0; }
# Comment lines are the questions, and a question may quote the phrase "status: blocked". Strip
# them first and take the FIRST status, or the gate fails open on its own question text.
st=$(grep -vE '^[[:space:]]*#' "$GATE" | grep -oE '^[[:space:]]*status:[[:space:]]*(done|blocked)' | head -1 | awk '{print $2}')
[ "$st" = "blocked" ] || { rm -f "$MARK"; exit 0; }

payload=$(cat)
GATE_FILE="$GATE" GATE_PAYLOAD="$payload" python3 - <<'PY'
import hashlib, json, os, sys
try:
    d = json.loads(os.environ.get("GATE_PAYLOAD") or "")
except Exception:                            # cannot tell subagent from main thread -> fail closed
    sys.stderr.write("Blocked: the grilling gate is set and the hook payload was unreadable, so "
                     "this cannot tell whether a prompt would be shown. Failing closed.\n")
    sys.exit(2)

raw = open(os.environ["GATE_FILE"], "rb").read()
q = "\n".join(l for l in raw.decode("utf-8", "replace").splitlines()
              if l.lstrip().startswith("#")) or "(gate file lists no questions)"

if d.get("agent_id"):                        # a subagent has no channel to ask -> hard block
    sys.stderr.write('Blocked: the grilling gate is set and you are inside the "{a}" subagent. '
                     "Report what you need and hand back to the main thread.\n"
                     "Open questions:\n{q}\n".format(a=d.get("agent_type") or "subagent", q=q))
    sys.exit(2)

mode = d.get("permission_mode") or "default"
tool = d.get("tool_name") or ""
if mode in ("bypassPermissions", "dontAsk") or (mode == "acceptEdits" and tool in ("Write", "Edit")):
    sys.stderr.write("Blocked: the grilling gate is set and permission_mode is '{m}', so no prompt "
                     "would be shown for {t} - and an unshown prompt is not an answer. Ask the "
                     "human in the conversation; they release it with bin/unblock.\n"
                     "Open questions:\n{q}\n".format(m=mode, t=tool or "this tool", q=q))
    sys.exit(2)

# Proof that a human was prompted about THIS gate. gate-clear.sh refuses to release without it.
open(os.environ["GATE_FILE"] + "-asked", "w").write(hashlib.sha256(raw).hexdigest() + "\n")

print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason":
        "GRILLING GATE - these questions are still open:\n" + q +
        "\n\nApproving releases the gate for the whole project root. Decline if they are unanswered."
}}))
PY
exit $?
