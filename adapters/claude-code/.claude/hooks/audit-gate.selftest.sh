#!/usr/bin/env bash
# Self-test for audit-gate.sh + audit-track.sh — the audit-debt gate. Same reason as the other two
# self-tests: a missing or broken hook exits 127, which does NOT block, so this gate fails OPEN with
# no warning. Both hooks read ${CLAUDE_PROJECT_DIR}/.gate to decide whether to stand down, so the
# cases below pin that parse: text written into the gate must never be mistaken for its status.
# A misparse here is silent — the audit loop is skipped rather than anything visibly failing.
#
#   bash audit-gate.selftest.sh
#
# Expected: "ALL PASS". Anything else means the audit loop can be skipped without anyone noticing.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGATE="$DIR/audit-gate.sh"
ATRACK="$DIR/audit-track.sh"

for f in "$AGATE" "$ATRACK"; do
  [ -f "$f" ] || { echo "FAIL: $f does not exist. The gate is not installed (or the symlink is broken)."; exit 1; }
done

fails=0

# audit-gate.sh is a Stop hook: rc 2 = refuse to end the turn (audit owed), rc 0 = allow.
# $1 label | $2 expected rc | $3 gate contents
gate () {
  D=$(mktemp -d); printf '%b' "$3" > "$D/.gate"; printf 'build\n' > "$D/.audit-pending"
  printf '{}' | CLAUDE_PROJECT_DIR="$D" bash "$AGATE" >/dev/null 2>&1; got=$?
  rm -rf "$D"
  if [ "$got" = "$2" ]; then printf '  ok    %-50s -> rc=%s\n' "$1" "$got"
  else printf '  FAIL  %-50s -> rc=%s (expected %s)\n' "$1" "$got" "$2"; fails=$((fails+1)); fi
}

# audit-track.sh is a SubagentStop hook: it records one line of debt per role run.
# $1 label | $2 expected debt lines | $3 gate contents
track () {
  D=$(mktemp -d); printf '%b' "$3" > "$D/.gate"
  printf '{"agent_type":"build"}' | CLAUDE_PROJECT_DIR="$D" bash "$ATRACK" >/dev/null 2>&1
  got=$( [ -f "$D/.audit-pending" ] && wc -l < "$D/.audit-pending" | tr -d ' ' || echo 0 )
  rm -rf "$D"
  if [ "$got" = "$2" ]; then printf '  ok    %-50s -> %s\n' "$1" "$got"
  else printf '  FAIL  %-50s -> %s (expected %s)\n' "$1" "$got" "$2"; fails=$((fails+1)); fi
}

# Same hook, but with a real subagent report attached — the channel that must NOT carry control.
# The plain track() above only ever sends {"agent_type":"build"}, so it exercises neither the
# debt-CLEARING branch nor any report text; these cases do both.
# $1 label | $2 expected debt lines | $3 agent_type | $4 last_assistant_message | $5 starting ledger
# | $6 gate contents (optional, default 'status: done')
track_msg () {
  D=$(mktemp -d); printf '%b' "${6:-status: done\n}" > "$D/.gate"; printf '%b' "$5" > "$D/.audit-pending"
  python3 -c 'import json,sys; print(json.dumps({"agent_type":sys.argv[1],"last_assistant_message":sys.argv[2]}))' "$3" "$4" \
    | CLAUDE_PROJECT_DIR="$D" bash "$ATRACK" >/dev/null 2>&1
  got=$( [ -f "$D/.audit-pending" ] && wc -l < "$D/.audit-pending" | tr -d ' ' || echo 0 )
  rm -rf "$D"
  if [ "$got" = "$2" ]; then printf '  ok    %-50s -> %s\n' "$1" "$got"
  else printf '  FAIL  %-50s -> %s (expected %s)\n' "$1" "$got" "$2"; fails=$((fails+1)); fi
}

# A grilling question may quote the phrase, with or without the '#' prefix. Neither form is the
# status line: comment-stripping catches the first, start-of-line anchoring catches the second.
Q_HASH='status: done\n# B3 keep the "status: blocked" wording?\n'
Q_PLAIN='status: done\nB9 why not status: blocked here?\n'

# Any artifact ABOUT these gates quotes "status: blocked" — inline, or in a fenced example where it
# sits at the start of a line. That is prose, never a control signal: suppression is read from .gate
# alone (audit-track.sh). Inferring it from the report made a role's audit vanish with no output and
# no failure, which is exactly what a self-test is for.
R_INLINE='The role must write "status: blocked" to the gate file before asking the human.'
R_FENCED='Mirror your grilling state to the gate file:

```
status: blocked
# B1 does a sub-category OWN or CLASSIFY its items?
```

That is the whole change.'

gate  "gate done, debt owed -> enforces the audit"      2 'status: done\n'
gate  "gate blocked -> stands down"                     0 'status: blocked\n'
gate  "done + '#' question quoting the phrase"          2 "$Q_HASH"
gate  "done + un-prefixed line quoting the phrase"      2 "$Q_PLAIN"
track "gate done -> debt recorded"                      1 'status: done\n'
track "gate blocked -> no debt recorded"                0 'status: blocked\n'
track "done + '#' question quoting the phrase"          1 "$Q_HASH"
track "done + un-prefixed line quoting the phrase"      1 "$Q_PLAIN"
track_msg "auditor clears debt, report quotes phrase"    0 build-audit "$R_INLINE" 'build\n'
track_msg "auditor clears debt, fenced phrase at line start" 0 build-audit "$R_FENCED" 'build\n'
track_msg "role writing ABOUT the gate still owes an audit" 1 build "$R_INLINE" ''
track_msg "role ABOUT the gate, fenced phrase at line start" 1 build "$R_FENCED" ''
track_msg "role self-blocked, mirrored to .gate -> no debt"  0 build "$R_INLINE" '' 'status: blocked\n'
# The pair below is the point of the two 'status: blocked' gate cases: same blocked .gate, opposite
# outcomes. A ROLE is suppressed by it; an AUDITOR must NEVER be, because its whole job is to CLEAR a
# debt. That asymmetry is exactly what breaks if the .gate check is ever hoisted back above the
# `case` in audit-track.sh, and nothing else here can see that placement.
track_msg "auditor not suppressed by a blocked .gate"       0 build-audit "$R_INLINE" 'build\n' 'status: blocked\n'

if [ "$fails" = "0" ]; then echo "ALL PASS (14/14)"; else echo "$fails FAILURE(S) — the audit gate can be skipped silently"; exit 1; fi
