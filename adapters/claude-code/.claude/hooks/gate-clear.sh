#!/usr/bin/env bash
# PostToolUse hook (Claude Code). Releases the grilling gate once a mutating tool has ACTUALLY run
# — but ONLY when gate-check.sh recorded that a human was prompted about *this exact* gate.
# `.gate-asked` holds a sha256 of the gate file as it stood when the prompt was raised.
#
# The marker is what makes this safe. Without it, this would wipe the gate the agent itself just
# set: the agent's own `echo 'status: blocked' > .gate` is a successful Bash call and PostToolUse
# fires on it. Matching the checksum, not merely the marker's presence, also stops an approval of a
# gate *edit* (adding a question) from being read as an approval to release.
GATE="${CLAUDE_PROJECT_DIR:-$PWD}/.gate"
MARK="$GATE-asked"
[ -f "$GATE" ] && [ -f "$MARK" ] || exit 0
grep -vE '^[[:space:]]*#' "$GATE" | grep -qE '^[[:space:]]*status:[[:space:]]*blocked' || { rm -f "$MARK"; exit 0; }
now=$(GATE_FILE="$GATE" python3 -c 'import hashlib,os;print(hashlib.sha256(open(os.environ["GATE_FILE"],"rb").read()).hexdigest())' 2>/dev/null)
[ -n "$now" ] && [ "$now" = "$(head -1 "$MARK")" ] || exit 0
qs=$(grep -E '^[[:space:]]*#' "$GATE")     # keep the questions as a record of what was released
{ printf 'status: done\n'
  [ -n "$qs" ] && printf '%s\n' "$qs"
  printf '# released by human approval, %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z (%z)')"
} > "$GATE"
rm -f "$MARK"
exit 0
