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
# After those, in order: the per-session ledger and its fallbacks, the per-session grilling gate those
# hooks stand down on, and bin/audit-clear's age column and --prune.
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

# Per-session ledgers (.agentic/<session_id>/audit-pending). The cases above send no session_id, so
# they keep pinning the shared legacy file; these pin the isolation and every fallback around it.
ck () {   # $1 label | $2 expected | $3 got
  if [ "$3" = "$2" ]; then printf '  ok    %-50s -> %s\n' "$1" "$3"
  else printf '  FAIL  %-50s -> %s (expected %s)\n' "$1" "$3" "$2"; fails=$((fails+1)); fi
}
payload () {   # $1 agent_type | $2 agent_id | $3 session_id (may be empty = key absent)
  python3 -c 'import json,sys; d={"agent_type":sys.argv[1],"agent_id":sys.argv[2]}
if sys.argv[3]: d["session_id"]=sys.argv[3]
print(json.dumps(d))' "$1" "$2" "$3"
}
stop_rc () {   # $1 project dir | $2 session_id (may be empty) ; optional $3 = hooks dir
  python3 -c 'import json,sys; d={}
if sys.argv[1]: d["session_id"]=sys.argv[1]
print(json.dumps(d))' "$2" | CLAUDE_PROJECT_DIR="$1" bash "${3:-$DIR}/audit-gate.sh" >/dev/null 2>&1; echo $?
}
lines_of () { [ -f "$1" ] && wc -l < "$1" | tr -d ' ' || echo none; }

D=$(mktemp -d)
payload build A1 sA | CLAUDE_PROJECT_DIR="$D" bash "$ATRACK" >/dev/null 2>&1
ck "two sessions: A's Stop is refused"                  2 "$(stop_rc "$D" sA)"
ck "two sessions: B's Stop is allowed"                  0 "$(stop_rc "$D" sB)"
payload build-audit A9 sB | CLAUDE_PROJECT_DIR="$D" bash "$ATRACK" >/dev/null 2>&1
ck "B's auditor leaves A's ledger intact"               1 "$(lines_of "$D/.agentic/sA/audit-pending")"
payload build-audit A9 sA | CLAUDE_PROJECT_DIR="$D" bash "$ATRACK" >/dev/null 2>&1
ck "A's auditor clears it; emptied ledger is deleted"   none "$(lines_of "$D/.agentic/sA/audit-pending")"
ck "legacy file never touched by id'd sessions"         "none" "$(lines_of "$D/.audit-pending")"
rm -rf "$D"

D=$(mktemp -d)
payload Explore X1 sA | CLAUDE_PROJECT_DIR="$D" bash "$ATRACK" >/dev/null 2>&1
payload build-audit X2 sA | CLAUDE_PROJECT_DIR="$D" bash "$ATRACK" >/dev/null 2>&1
ck "non-role subagent / stray auditor create no state"  "" "$(ls -A "$D")"
rm -rf "$D"

D=$(mktemp -d)
payload build A1 '../x' | CLAUDE_PROJECT_DIR="$D" bash "$ATRACK" >/dev/null 2>&1
ck "track: an invalid id counts as no id (legacy only)"   "1|no|none" "$(lines_of "$D/.audit-pending")|$([ -e "$D/.agentic" ] && echo yes || echo no)|$(lines_of "$D/../x/audit-pending")"
rm -rf "$D"

D=$(mktemp -d)
payload build A1 "" | CLAUDE_PROJECT_DIR="$D" bash "$ATRACK" >/dev/null 2>&1
ck "no session_id -> legacy ledger, no .agentic"        "1|no" "$(lines_of "$D/.audit-pending")|$([ -e "$D/.agentic" ] && echo yes || echo no)"
rm -rf "$D"

D=$(mktemp -d); printf 'build\tL1\tT\n' > "$D/.audit-pending"
ck "legacy ledger does not block a session with an id"  0 "$(stop_rc "$D" sA)"
ck "legacy ledger still blocks a payload with no id"    2 "$(stop_rc "$D" "")"
rm -rf "$D"

D=$(mktemp -d); mkdir -p "$D/.agentic/sA"; printf 'build\tA1\tT\n' > "$D/.agentic/sA/audit-pending"
msg=$(printf '{}' | CLAUDE_PROJECT_DIR="$D" bash "$AGATE" 2>&1 >/dev/null); rc=$?
ck "Stop with no id enforces .agentic/*, names the exit" "2|1" "$rc|$(printf '%s' "$msg" | grep -c 'audit-clear <agent_id> is then the only exit')"
ck "an id that is not [A-Za-z0-9_-]+ counts as no id"   2 "$(stop_rc "$D" '../sB')"
rm -rf "$D"

# Each hook must reject a missing, truncated or syntax-broken helper as a whole and fall back to the shared
# ledger, never a path built from an empty var. AGENTIC_SS_LOADED=1 is exported to prove it unsets a stale one.
helper_variant () {   # $1 label | $2 missing|truncated|syntax
  D=$(mktemp -d); T=$(mktemp -d); cp "$AGATE" "$ATRACK" "$T/"
  case "$2" in
    truncated) printf 'sid_dir() { printf "%%s" /nonexistent-bogus; }\n' > "$T/session-state.sh" ;;
    syntax)    printf 'sid_dir() { printf "%%s" /nonexistent-bogus; }\nif then fi )(\nAGENTIC_SS_LOADED=1\n' > "$T/session-state.sh" ;;
  esac
  payload build A1 sA | AGENTIC_SS_LOADED=1 CLAUDE_PROJECT_DIR="$D" bash "$T/audit-track.sh" >"$D.err" 2>&1
  rc=$(stop_rc "$D" sA "$T" ); err=$(cat "$D.err")
  bogus=$(printf '%s' "$err" | grep -cF '/audit-pending')
  got1="legacy=$(lines_of "$D/.audit-pending")|agentic=$([ -e "$D/.agentic" ] && echo yes || echo no)|stop=$rc|bogus=$bogus"
  # Legacy behaviour means the shared file ONLY: another session's ledger must not be globbed in.
  rm -f "$D/.audit-pending"; mkdir -p "$D/.agentic/sZ"; printf 'build\tZ1\tT\n' > "$D/.agentic/sZ/audit-pending"
  ck "$1" "legacy=1|agentic=no|stop=2|bogus=0|stop_other_ledger=0" "$got1|stop_other_ledger=$(stop_rc "$D" sA "$T")"
  rm -rf "$D" "$D.err" "$T"
}
helper_variant "helper missing -> legacy, no bogus path"            missing
helper_variant "helper truncated after first function -> legacy"    truncated
helper_variant "helper syntax error after first function -> legacy" syntax

# bin/audit-clear across sessions: lists every ledger (legacy first) and drops by agent_id from
# whichever ledger holds it, leaving the others byte-identical.
D=$(mktemp -d); mkdir -p "$D/.agentic/sA" "$D/.agentic/sB"
printf 'plan\tL1\tT0\n' > "$D/.audit-pending"
printf 'build\tA1\tT1\n' > "$D/.agentic/sA/audit-pending"; printf 'review\tB1\tT2\n' > "$D/.agentic/sB/audit-pending"
out=$(CLAUDE_PROJECT_DIR="$D" bash "$ACLEAR" 2>&1)
order=$(printf '%s\n' "$out" | grep -E '^(legacy|session) ' | awk '{print $1 ($1=="session" ? ":" $2 : "")}' | tr '\n' ' ')
ck "audit-clear lists legacy first, then both sessions" "legacy session:sA session:sB " "$order"
ck "audit-clear listing shows a last-modified time"      3 "$(printf '%s\n' "$out" | grep -cE 'last modified [0-9]{4}-')"
CLAUDE_PROJECT_DIR="$D" bash "$ACLEAR" B1 >/dev/null 2>&1; rc=$?
ck "audit-clear <agent_id> drops it from B's ledger only" "rc=0|none|1|1" "rc=$rc|$(lines_of "$D/.agentic/sB/audit-pending")|$(lines_of "$D/.agentic/sA/audit-pending")|$(lines_of "$D/.audit-pending")"
CLAUDE_PROJECT_DIR="$D" bash "$ACLEAR" build >/dev/null 2>&1; rc=$?
ck "audit-clear <role> never drops a session's entry"     "rc=1|1" "rc=$rc|$(lines_of "$D/.agentic/sA/audit-pending")"
mkdir -p "$D/.agentic/sB"; printf 'review\tB2\tT3\n' > "$D/.agentic/sB/audit-pending"
CLAUDE_PROJECT_DIR="$D" bash "$ACLEAR" --session sB A1 >/dev/null 2>&1; rc=$?
ck "audit-clear --session scopes the search"              "rc=1|1" "rc=$rc|$(lines_of "$D/.agentic/sA/audit-pending")"
rm -rf "$D"
# A bare role name is the legacy file's escape hatch only; in a session ledger it must not match.
D=$(mktemp -d); mkdir -p "$D/.agentic/sC"; printf 'build\n' > "$D/.agentic/sC/audit-pending"
CLAUDE_PROJECT_DIR="$D" bash "$ACLEAR" build >/dev/null 2>&1; rc=$?
ck "audit-clear <role> skips bare lines in session ledgers" "rc=1|1" "rc=$rc|$(lines_of "$D/.agentic/sC/audit-pending")"
rm -rf "$D"


# The grilling gate is per session too (.agentic/<session_id>/gate): a session's blocked gate stands down
# its own Stop and does not suppress its own auditor, but never another session's debt or Stop.
gate_for () { mkdir -p "$D/.agentic/$1"; printf '%b' "$2" > "$D/.agentic/$1/gate"; }
ledger_of () { [ -f "$1" ] && cut -f1 < "$1" | tr '\n' ' ' | sed 's/ *$//' || echo none; }

D=$(mktemp -d)
payload build A1 sA | CLAUDE_PROJECT_DIR="$D" bash "$ATRACK" >/dev/null 2>&1
payload build B1 sB | CLAUDE_PROJECT_DIR="$D" bash "$ATRACK" >/dev/null 2>&1
gate_for sA 'status: blocked\n# Q1\n'
ck "A's blocked gate stands down A's own Stop"          0 "$(stop_rc "$D" sA)"
ck "A's blocked gate does not stand down B's Stop"      2 "$(stop_rc "$D" sB)"
payload build A2 sA | CLAUDE_PROJECT_DIR="$D" bash "$ATRACK" >/dev/null 2>&1
payload build B2 sB | CLAUDE_PROJECT_DIR="$D" bash "$ATRACK" >/dev/null 2>&1
ck "A blocked: A's role records none, B's build records debt" "build|build build" "$(ledger_of "$D/.agentic/sA/audit-pending")|$(ledger_of "$D/.agentic/sB/audit-pending")"
payload build-audit B9 sB | CLAUDE_PROJECT_DIR="$D" bash "$ATRACK" >/dev/null 2>&1
payload build-audit A9 sA | CLAUDE_PROJECT_DIR="$D" bash "$ATRACK" >/dev/null 2>&1
ck "A blocked: each auditor still clears its own ledger" "none|build" "$(ledger_of "$D/.agentic/sA/audit-pending")|$(ledger_of "$D/.agentic/sB/audit-pending")"
rm -rf "$D"

D=$(mktemp -d); printf 'status: blocked\n# L1\n' > "$D/.gate"
payload build A1 sA | CLAUDE_PROJECT_DIR="$D" bash "$ATRACK" >/dev/null 2>&1
ck "legacy blocked .gate: an id'd session's role records none" none "$(lines_of "$D/.agentic/sA/audit-pending")"
mkdir -p "$D/.agentic/sA"; printf 'build\tA1\tT\n' > "$D/.agentic/sA/audit-pending"
ck "legacy blocked .gate stands down an id'd session's Stop"  0 "$(stop_rc "$D" sA)"
rm -rf "$D"

D=$(mktemp -d); mkdir -p "$D/.agentic/sA"; printf 'build\tA1\tT\n' > "$D/.agentic/sA/audit-pending"
gate_for sA 'status: done\n# Q1 keep "status: blocked"?\n'
ck "A's done gate (question quotes the phrase) does not stand down" 2 "$(stop_rc "$D" sA)"
rm -rf "$D"

# With the helper rejected both hooks are legacy-only: a per-session gate is not read, so it neither
# stands the Stop down nor suppresses a role's debt.
D=$(mktemp -d); T=$(mktemp -d); cp "$AGATE" "$ATRACK" "$T/"
printf 'build\tL1\tT\n' > "$D/.audit-pending"; gate_for sA 'status: blocked\n'
payload build A1 sA | CLAUDE_PROJECT_DIR="$D" bash "$T/audit-track.sh" >/dev/null 2>&1
ck "helper missing: a per-session blocked gate is not read" "stop=2|legacy=2" "stop=$(stop_rc "$D" sA "$T")|legacy=$(lines_of "$D/.audit-pending")"
rm -rf "$D" "$T"

# Stale state is visible and prunable. Aging uses touch -t (portable); 2020 is far past any threshold.
OLD=202001010000
mk () {   # $1 session | $2 ledger contents, or NONE | $3 gate contents, or NONE | $4 old|new
  mkdir -p "$D/.agentic/$1"
  [ "$2" = NONE ] || printf '%b' "$2" > "$D/.agentic/$1/audit-pending"
  [ "$3" = NONE ] || printf '%b' "$3" > "$D/.agentic/$1/gate"
  if [ "$4" = old ]; then find "$D/.agentic/$1" -exec touch -t $OLD {} +; fi
}
survivors () { ls "$D/.agentic" 2>/dev/null | tr '\n' ' ' | sed 's/ *$//'; }
D=$(mktemp -d)
mk oldclean '' 'status: done\n' old; mk oldnoledger NONE 'status: done\n' old
mk olddebt 'build\tA1\tT\n' 'status: done\n' old; mk oldblocked '' 'status: blocked\n# Q\n' old
mk fresh '' 'status: done\n' new; mk foreign '' NONE old; : > "$D/.agentic/foreign/notes.txt"; touch -t $OLD "$D/.agentic/foreign/notes.txt" "$D/.agentic/foreign"
printf 'plan\tL1\tT\n' > "$D/.audit-pending"; printf 'status: blocked\n' > "$D/.gate"; touch -t $OLD "$D/.audit-pending" "$D/.gate"
sum_before=$(cat "$D/.agentic/olddebt/audit-pending" "$D/.agentic/oldblocked/gate" "$D/.audit-pending" "$D/.gate" | cksum)
out=$(CLAUDE_PROJECT_DIR="$D" bash "$ACLEAR" --prune 2>&1); rc=$?
ck "prune: removes only the clean old folders"          "rc=0|foreign fresh oldblocked olddebt" "rc=$rc|$(survivors)"
ck "prune: debt, blocked gate and legacy files intact"  "$sum_before" "$(cat "$D/.agentic/olddebt/audit-pending" "$D/.agentic/oldblocked/gate" "$D/.audit-pending" "$D/.gate" | cksum)"
ck "prune: output says what went and why the rest stayed" "2|1|1|1|1" "$(printf '%s\n' "$out" | grep -cE '^removed  (oldclean|oldnoledger)$')|$(printf '%s' "$out" | grep -c 'kept     olddebt  (has audit debt)')|$(printf '%s' "$out" | grep -c 'kept     oldblocked  (has a blocked gate)')|$(printf '%s' "$out" | grep -c 'kept     fresh  (only <1d old)')|$(printf '%s' "$out" | grep -c 'kept     foreign  (holds files')"
CLAUDE_PROJECT_DIR="$D" bash "$ACLEAR" --prune 36500 >/dev/null 2>&1
ck "prune: a huge threshold keeps everything"           "foreign fresh oldblocked olddebt" "$(survivors)"
CLAUDE_PROJECT_DIR="$D" bash "$ACLEAR" --prune 0 >/dev/null 2>&1
ck "prune 0: also takes the fresh clean folder, nothing owed" "foreign oldblocked olddebt" "$(survivors)"
bad=""; for a in abc -1 1.5 "" "1 2"; do
  CLAUDE_PROJECT_DIR="$D" bash "$ACLEAR" --prune "$a" >/dev/null 2>&1; bad="$bad$?"
done
CLAUDE_PROJECT_DIR="$D" bash "$ACLEAR" --prune 5 6 >/dev/null 2>&1; bad="$bad$?"
ck "prune: bad days rejected (rc=2), tree untouched"    "222222|foreign oldblocked olddebt" "$bad|$(survivors)"
rm -rf "$D"
# Folders prune must not follow or delete: a symlink to a clean old folder, and names that are not session ids.
D=$(mktemp -d); E=$(mktemp -d); mkdir -p "$E/target" "$D/.agentic/real" "$D/.agentic/sp ace" "$D/.agentic/gl*ob"
printf 'x' > "$E/target/gate"; ln -s "$E/target" "$D/.agentic/link"
find "$D/.agentic" "$E" -exec touch -h -t $OLD {} + 2>/dev/null
CLAUDE_PROJECT_DIR="$D" bash "$ACLEAR" --prune >/dev/null 2>&1
ck "prune: follows no symlink, skips non-id names"      "gl*ob link sp ace|yes" "$(ls "$D/.agentic" | tr '\n' ' ' | sed 's/ *$//' | sed 's/^\(gl\*ob link sp ace\).*/\1/')|$([ -f "$E/target/gate" ] && echo yes || echo no)"
rm -rf "$D" "$E"
# days: a huge value must keep, not wrap around and delete; a leading zero is decimal, not octal.
D=$(mktemp -d); mk recent '' 'status: done\n' new; mk aged '' 'status: done\n' old
r=""; for a in 999999999999999 9223372036854775807 100000; do
  CLAUDE_PROJECT_DIR="$D" bash "$ACLEAR" --prune "$a" >/dev/null 2>&1; r="$r$?"; done
ck "prune: huge days rejected (rc=2), nothing removed"   "222|aged recent" "$r|$(survivors)"
out=$(CLAUDE_PROJECT_DIR="$D" bash "$ACLEAR" --prune 09 2>&1); rc=$?
ck "prune 09: decimal 9 days, not an octal error"        "rc=0|aged removed, recent kept" "rc=$rc|$(printf '%s' "$out" | grep -c '^removed  aged$' | sed 's/1/aged removed/')$(printf '%s' "$out" | grep -q '^kept     recent' && echo ', recent kept')"
rm -rf "$D"
D=$(mktemp -d); E=$(mktemp -d); mkdir -p "$E/abc"; ln -s "$E" "$D/.agentic"; find "$E" -exec touch -t $OLD {} +
CLAUDE_PROJECT_DIR="$D" bash "$ACLEAR" --prune >/dev/null 2>&1; rc=$?
ck "prune: refuses when .agentic is a symlink"           "rc=1|abc" "rc=$rc|$(ls "$E")"
rm -rf "$D" "$E"
D=$(mktemp -d); CLAUDE_PROJECT_DIR="$D" bash "$ACLEAR" --prune >/dev/null 2>&1; rc=$?
ck "prune: no .agentic at all is rc=0, creates nothing" "0|" "$rc|$(ls -A "$D")"
rm -rf "$D"

D=$(mktemp -d); mk sOld 'build\tA1\tT\n' NONE old; mk sNew 'review\tB1\tT\n' NONE new
out=$(CLAUDE_PROJECT_DIR="$D" bash "$ACLEAR" 2>&1)
ck "audit-clear listing: an age on every ledger"        "1|1" "$(printf '%s\n' "$out" | grep -cE '^session sOld .*\(age [0-9]+d\)$')|$(printf '%s\n' "$out" | grep -cE '^session sNew .*\(age <1d\)$')"
rm -rf "$D"
D=$(mktemp -d); mk sDebt 'build\tA1\tT\n' 'status: blocked\n# Q\n' new; mk sGate '' 'status: blocked\n# Q\n' old; mk sDone '' 'status: done\n' old
out=$(CLAUDE_PROJECT_DIR="$D" bash "$ACLEAR" 2>&1); rc=$?
ck "listing flags a blocked gate with no debt, with age" "rc=0|1|1|0" "rc=$rc|$(printf '%s\n' "$out" | grep -cE '^session sGate .*BLOCKED \(age [0-9]+d\).*bin/unblock sGate')|$(printf '%s' "$out" | grep -c 'agent A1')|$(printf '%s' "$out" | grep -c 'sDone\|BLOCKED.*sDebt\|session sDebt .*no audit debt')"
rm -rf "$D"
D=$(mktemp -d); mk sGate '' 'status: blocked\n# Q\n' old
out=$(CLAUDE_PROJECT_DIR="$D" bash "$ACLEAR" 2>&1); rc=$?
ck "blocked gate and no debt anywhere: still listed"    "rc=0|1|0" "rc=$rc|$(printf '%s' "$out" | grep -c 'session sGate .*BLOCKED')|$(printf '%s' "$out" | grep -c 'Drop one with')"
rm -rf "$D"
D=$(mktemp -d); mk sDone '' 'status: done\n' old
out=$(CLAUDE_PROJECT_DIR="$D" bash "$ACLEAR" 2>&1)
ck "nothing owed and nothing blocked: the old message"  "No outstanding audit debt under $D." "$out"
rm -rf "$D"

# Wiring: each script settings.json registers, resolved via an install-style hooks symlink, and the sourced
# session-state.sh must parse; prints problems. Copied into all three selftests, which stand alone.
# Blind spot: a Claude Code started where .claude/settings.json is not this one registers no hook at all.
wiring_problems () {
  local hd P p
  hd="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  P=$(mktemp -d); trap 'rm -rf "$P"; exit 130' INT TERM
  mkdir "$P/.claude"; ln -s "$hd" "$P/.claude/hooks"
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    case "$p" in
      '!'*) echo "${p#!}"; continue ;;
    esac
    if [ ! -f "$p" ] || [ ! -r "$p" ]; then echo "not a readable file: ${p#$P/}"
    elif ! bash -n "$p" 2>/dev/null; then echo "syntax error: ${p#$P/}"; fi
  done <<EOT
$(python3 -c 'import json,shlex,sys
n=0
pre="$CLAUDE_PROJECT_DIR/.claude/hooks/"
for g in json.load(open(sys.argv[1]))["hooks"].values():
    for m in g:
        for h in m["hooks"]:
            n+=1; t=shlex.split(h["command"])
            if len(t)==2 and t[0]=="bash" and t[1].startswith(pre) and t[1].endswith(".sh") and len(t[1])>len(pre)+3:
                print(t[1].replace("$CLAUDE_PROJECT_DIR",sys.argv[2]))
            else: print("!unrecognised hook command: "+repr(h["command"]))
if n==0: print("!no hook registered")' "$hd/../settings.json" "$P" 2>&1 || echo "!settings.json unreadable")
EOT
  p="$P/.claude/hooks/session-state.sh"
  if [ ! -f "$p" ]; then echo "helper missing: session-state.sh"
  elif ! bash -n "$p" 2>/dev/null; then echo "helper syntax error: session-state.sh"
  elif ! tail -n 1 "$p" | grep -q '^AGENTIC_SS_LOADED=1\([[:space:]]\|$\)'; then echo "helper lacks the AGENTIC_SS_LOADED=1 last line"; fi
  trap - INT TERM; rm -rf "$P"
}

ck "wiring: settings.json scripts + helper" "" "$(wiring_problems | tr '\n' ';')"

if [ "$fails" = "0" ]; then echo "ALL PASS (75/75)"; else echo "$fails FAILURE(S) — the audit gate can be skipped silently"; exit 1; fi
