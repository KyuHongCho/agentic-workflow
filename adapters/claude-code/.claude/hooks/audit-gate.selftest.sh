#!/usr/bin/env bash
# Self-test for audit-gate.sh + audit-track.sh — the audit-debt gate. Like the other two: a
# missing or broken hook exits 127, which does NOT block, so this gate fails OPEN with no warning.
#
# Six things are pinned: the ${CLAUDE_PROJECT_DIR}/.gate parse both hooks stand down on; that a
# subagent's report is never read as control, however it quotes the phrase; that suppression stays
# inside the role branch, so an auditor can always clear the debt it discharged; the ledger's
# CONTENTS, including the UTC stamp each entry promises; the agent_id keying — one OPEN entry per
# subagent, still clearable now that an entry carries metadata; and bin/audit-clear, the only
# sanctioned way to retire a debt WITHOUT an audit, which is enforcement surface like the hooks.
# The first two fail in silence; the third loudly but wrongly — the debt sticks.
#
#   bash audit-gate.selftest.sh
#
# Expected: "ALL PASS". Anything else means the audit loop can be skipped without anyone noticing.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGATE="$DIR/audit-gate.sh"
ATRACK="$DIR/audit-track.sh"
# Resolve bin/ PHYSICALLY. In an installed project .claude/hooks is a symlink, and bash's logical
# pwd would make "$DIR/../../bin" the project root's bin — which the install never creates.
ACLEAR="$(cd -P "$DIR/../.." 2>/dev/null && pwd)/bin/audit-clear"

for f in "$AGATE" "$ATRACK"; do
  [ -f "$f" ] || { echo "FAIL: $f does not exist. The gate is not installed (or the symlink is broken)."; exit 1; }
done
[ -f "$ACLEAR" ] || { echo "FAIL: $ACLEAR does not exist. The human has no way to clear a stale entry."; exit 1; }

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

# audit-track.sh is a SubagentStop hook: it records one line of debt per role COMPLETION — a
# resumed role adds one each time it hands back, so the count is not a count of artifacts.
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

# Ledger CONTENTS, not just its line count. Most of these would also trip a count — their kill
# power is the inputs the cases above never use. Contents catches the one failure no count can
# see: a hook that records the WRONG NAME.
# $1 label | $2 expected ledger | $3 agent_type | $4 last_assistant_message | $5 starting ledger
# $6 gate contents, or NOGATE for a fresh install with no .gate | $7 nested agent_type
ledger () {
  D=$(mktemp -d); [ "${6:-status: done\n}" = "NOGATE" ] || printf '%b' "${6:-status: done\n}" > "$D/.gate"
  printf '%b' "$5" > "$D/.audit-pending"
  python3 -c 'import json,sys; d={"agent_type":sys.argv[1],"last_assistant_message":sys.argv[2]};
if len(sys.argv)>3 and sys.argv[3]: d["background_tasks"]=[{"agent_type":sys.argv[3]}]
print(json.dumps(d))' "$3" "$4" "${7:-}" \
    | CLAUDE_PROJECT_DIR="$D" bash "$ATRACK" >/dev/null 2>&1
  # A MISSING ledger is not an EMPTY one: reading both as "[]" lets a hook that deleted the file
  # satisfy an "[]" expectation. Distinguish them — and don't leak the redirect's error either.
  if [ -f "$D/.audit-pending" ]; then got="[$(cut -f1 < "$D/.audit-pending" | tr '\n' ' ' | sed 's/ *$//')]"
  else got='[NOFILE]'; fi
  rm -rf "$D"
  if [ "$got" = "$2" ]; then printf '  ok    %-50s -> %s\n' "$1" "$got"
  else printf '  FAIL  %-50s -> %s (expected %s)\n' "$1" "$got" "$2"; fails=$((fails+1)); fi
}

# Ledger after a SEQUENCE of hand-backs that carry an agent_id — the field the one-entry-per-subagent
# rule keys on. Neither track() nor ledger() ever sends one, so neither can tell a resumed role
# (one artifact, two hand-backs) from two slices, and neither exercises clearing a metadata-bearing
# entry: matching the whole line instead of field 1 leaves that debt permanently unclearable.
# $1 label | $2 expected ledger (field 1 of each line) | $3 starting ledger | $4.. 'agent_type:agent_id'
ledger_ids () {
  label="$1"; want="$2"; start="$3"; shift 3
  D=$(mktemp -d); printf 'status: done\n' > "$D/.gate"; printf '%b' "$start" > "$D/.audit-pending"
  for spec in "$@"; do
    python3 -c 'import json,sys; print(json.dumps({"agent_type":sys.argv[1],"agent_id":sys.argv[2]}))' \
      "${spec%%:*}" "${spec#*:}" | CLAUDE_PROJECT_DIR="$D" bash "$ATRACK" >/dev/null 2>&1
  done
  if [ -f "$D/.audit-pending" ]; then got="[$(cut -f1 < "$D/.audit-pending" | tr '\n' ' ' | sed 's/ *$//')]"
  else got='[NOFILE]'; fi
  rm -rf "$D"
  if [ "$got" = "$want" ]; then printf '  ok    %-50s -> %s\n' "$label" "$got"
  else printf '  FAIL  %-50s -> %s (expected %s)\n' "$label" "$got" "$want"; fails=$((fails+1)); fi
}

# audit-gate.sh's MESSAGE, not just its rc. The per-entry lines come from a `read` loop, which drops
# a final line with no trailing newline unless the loop guards for it — a debt silently never named.
# $1 label | $2 expected number of '  - dispatch' lines | $3 ledger contents (printf %b, verbatim)
gate_lines () {
  D=$(mktemp -d); printf 'status: done\n' > "$D/.gate"; printf '%b' "$3" > "$D/.audit-pending"
  msg=$(printf '{}' | CLAUDE_PROJECT_DIR="$D" bash "$AGATE" 2>&1 >/dev/null)
  rm -rf "$D"
  got=$(printf '%s\n' "$msg" | awk '/^  - dispatch/{n++} END{print n+0}')
  if [ "$got" = "$2" ]; then printf '  ok    %-50s -> %s\n' "$1" "$got"
  else printf '  FAIL  %-50s -> %s (expected %s)\n' "$1" "$got" "$2"; fails=$((fails+1)); fi
}

# bin/audit-clear — the ONLY sanctioned way to retire a debt without an audit, so it is enforcement
# surface and pinned like the hooks. Checks the rc, the ledger LEFT BEHIND, that no .tmp.$$ survives,
# and whether the file changed at all: a refused drop must leave it byte-identical, not merely
# same-looking. $1 label | $2 expected 'rc=N|[fields 1,2]|tmp=N|file=same|changed'
# | $3 starting ledger | $4.. arguments to audit-clear (none = the listing path)
aclear () {
  label="$1"; want="$2"; start="$3"; shift 3
  D=$(mktemp -d); printf '%b' "$start" > "$D/.audit-pending"
  before=$(cksum < "$D/.audit-pending")
  CLAUDE_PROJECT_DIR="$D" bash "$ACLEAR" "$@" >/dev/null 2>&1; rc=$?
  after=$(cksum < "$D/.audit-pending")
  left=$(cut -f1,2 < "$D/.audit-pending" | tr '\t' ':' | tr '\n' ' ' | sed 's/ *$//')
  strays=$(find "$D" -name '.audit-pending.tmp.*' | wc -l | tr -d ' ')
  [ "$before" = "$after" ] && ch=same || ch=changed
  got="rc=$rc|[$left]|tmp=$strays|file=$ch"
  rm -rf "$D"
  if [ "$got" = "$want" ]; then printf '  ok    %-50s -> %s\n' "$label" "$got"
  else printf '  FAIL  %-50s -> %s (expected %s)\n' "$label" "$got" "$want"; fails=$((fails+1)); fi
}

# The recorded UTC stamp. Every case above reads field 1 or a hand-written ledger, so emitting an
# empty or malformed field 3 passes them all — while CLAUDE.md promises each entry names its time.
# Spelled out digit by digit: awk interval expressions {4} are not portable.
stamp () {
  D=$(mktemp -d); printf 'status: done\n' > "$D/.gate"; : > "$D/.audit-pending"
  python3 -c 'import json;print(json.dumps({"agent_type":"build","agent_id":"A1"}))' \
    | CLAUDE_PROJECT_DIR="$D" bash "$ATRACK" >/dev/null 2>&1
  got=$(awk -F'\t' 'NR==1{print ($3 ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z$/) ? "ISO8601Z" : "BAD[" $3 "]"}' "$D/.audit-pending")
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

ledger "every role records under its own name"    "[plan]"        plan        "$R_INLINE" ''
ledger "the matching auditor clears that debt"    "[]"            plan-audit  "$R_INLINE" 'plan\n'
ledger "one auditor clears ONE debt, not both"    "[build]"       build-audit "$R_INLINE" 'build\nbuild\n'
ledger "no .gate yet (fresh install) -> debt"     "[build]"       build       "$R_INLINE" '' NOGATE
ledger "nested agent_type is not the top-level"   "[]"            build-audit "$R_INLINE" 'build\n' 'status: done\n' build

# The phantom: before agent_id keying, a role that handed back, waited on the human and handed back
# again recorded TWO debts for ONE artifact — the second unpayable, because no second artifact exists.
ledger_ids "same subagent twice, no audit between -> ONE"   "[build]"       '' build:A1 build:A1
# Load-bearing for audit-track.sh's clearing awk. Match the whole LINE instead of field 1 and this is
# "[build]": the debt survives its own audit and the gate can never be satisfied again.
ledger_ids "auditor clears a metadata-bearing entry"        "[]"            '' build:A1 build-audit:A9
# Keying must not turn into memory: after a REVISE the entry was already cleared, so the same
# subagent handing back again opens a FRESH debt.
ledger_ids "audited, then hands back again -> owes again"   "[build]"       '' build:A1 build-audit:A9 build:A1
# Two slices are two subagents and still owe two audits — what naive dedup-by-role would collapse.
ledger_ids "two different subagents -> TWO entries"         "[build build]" '' build:A1 build:A2
# A ledger written without a trailing newline (hand-edited, or a truncated write) must still name
# every entry; an unguarded `read` loop drops the last one and the human is never told it is owed.
gate_lines "last line, no trailing newline, still named"    2 'plan\tA1\t2026-01-01T00:00:00Z\nbuild\tA2\t2026-01-01T00:00:01Z'

# CLAUDE.md promises every entry names the UTC time it was recorded; only this case can see it.
stamp "the recorded stamp is a real UTC timestamp"  ISO8601Z

# bin/audit-clear. The legacy case is the one that mattered: a pre-format entry has no agent_id, so
# before it was matched by role name NO argument the human could type would clear it — and a leftover
# from before the metadata is exactly the entry this whole change exists to let them retire.
aclear "audit-clear: drops named id, keeps the other"  "rc=0|[build:A2]|tmp=0|file=changed" 'build\tA1\tT1\nbuild\tA2\tT2' A1
aclear "audit-clear: unknown id -> rc=1, no mutation"  "rc=1|[build:A1]|tmp=0|file=same"    'build\tA1\tT1'                 nope
aclear "audit-clear: legacy bare entry clears by role" "rc=0|[plan]|tmp=0|file=changed"     'build\nplan\n'                 build
aclear "audit-clear: no argument lists, never mutates" "rc=0|[build:A1]|tmp=0|file=same"    'build\tA1\tT1'
# An EMPTY argument is not "no argument": '$2==""' matches every legacy line, so without the
# '[ -z "$1" ]' half of the guard `audit-clear ""` retires a real debt with rc=0 and a success
# message. That is the hazard this file's header warns about, on the one path that can do it.
aclear "audit-clear: empty arg lists, never drops"   "rc=0|[build plan]|tmp=0|file=same"  'build\nplan\n'  ""

if [ "$fails" = "0" ]; then echo "ALL PASS (30/30)"; else echo "$fails FAILURE(S) — the audit gate can be skipped silently"; exit 1; fi
