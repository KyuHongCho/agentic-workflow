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

# A grilling question may quote the phrase, with or without the '#' prefix. Neither form is the
# status line: comment-stripping catches the first, start-of-line anchoring catches the second.
Q_HASH='status: done\n# B3 keep the "status: blocked" wording?\n'
Q_PLAIN='status: done\nB9 why not status: blocked here?\n'

gate  "gate done, debt owed -> enforces the audit"      2 'status: done\n'
gate  "gate blocked -> stands down"                     0 'status: blocked\n'
gate  "done + '#' question quoting the phrase"          2 "$Q_HASH"
gate  "done + un-prefixed line quoting the phrase"      2 "$Q_PLAIN"
track "gate done -> debt recorded"                      1 'status: done\n'
track "gate blocked -> no debt recorded"                0 'status: blocked\n'
track "done + '#' question quoting the phrase"          1 "$Q_HASH"
track "done + un-prefixed line quoting the phrase"      1 "$Q_PLAIN"

if [ "$fails" = "0" ]; then echo "ALL PASS (8/8)"; else echo "$fails FAILURE(S) — the audit gate can be skipped silently"; exit 1; fi
