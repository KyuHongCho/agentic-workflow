#!/usr/bin/env bash
# Self-test for gate-check.sh + gate-clear.sh — the grilling gate. Same reason as
# ship-gate.selftest.sh: a missing or broken hook exits 127, which does NOT block, so the gate
# fails OPEN with no warning. A guard that never trips proves nothing.
#
#   bash gate-check.selftest.sh
#
# Expected: "ALL PASS". Anything else means you do not have a working grilling gate.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$DIR/gate-check.sh"
CLEAR="$DIR/gate-clear.sh"
# Resolve bin/ PHYSICALLY: in an installed project .claude/hooks is a symlink (see audit-gate.selftest.sh).
UNBLOCK="$(cd -P "$DIR/../.." 2>/dev/null && pwd)/bin/unblock"
# The first 18 cases send no session_id and must hit the shared legacy .gate, so a session id leaking in
# from the environment this runs in (it is set inside Claude Code) would silently re-key them.
unset CLAUDE_CODE_SESSION_ID

for f in "$HOOK" "$CLEAR" "$UNBLOCK"; do
  [ -f "$f" ] || { echo "FAIL: $f does not exist. The gate is not installed (or the symlink is broken)."; exit 1; }
done

fails=0

# $1 label | $2 expected: ask|block|pass | $3 gate contents ("" = no gate file) | $4 payload
# $5 "nodir" to run with CLAUDE_PROJECT_DIR unset (the gate must still bind, via $PWD)
check () {
  D=$(mktemp -d); [ -n "$3" ] && printf '%b' "$3" > "$D/.gate"
  if [ "$5" = "nodir" ]; then
    out=$(cd "$D" && printf '%s' "$4" | env -u CLAUDE_PROJECT_DIR bash "$HOOK" 2>/dev/null)
  else
    out=$(printf '%s' "$4" | CLAUDE_PROJECT_DIR="$D" bash "$HOOK" 2>/dev/null)
  fi
  rc=$?
  if [ "$rc" = "2" ]; then got=block
  elif [ -z "$out" ]; then got=pass
  else got=$(printf '%s' "$out" | python3 -c 'import sys,json;print(json.load(sys.stdin)["hookSpecificOutput"]["permissionDecision"])' 2>/dev/null || echo "badjson")
  fi
  rm -rf "$D"
  if [ "$got" = "$2" ]; then printf '  ok    %-48s -> %s\n' "$1" "$got"
  else printf '  FAIL  %-48s -> %s (expected %s, rc=%s)\n' "$1" "$got" "$2" "$rc"; fails=$((fails+1)); fi
}

M='"permission_mode":"default","tool_name":"Edit"'
S='"permission_mode":"default","agent_id":"sa-1","agent_type":"build","tool_name":"Edit"'

check "no gate file"                        pass  ""                          "{$M}"
check "gate done"                           pass  'status: done\n'            "{$M}"
check "blocked: main thread asks"           ask   'status: blocked\n'         "{$M}"
check "blocked: subagent hard-blocks"       block 'status: blocked\n'         "{$S}"
check "blocked: bypassPermissions"          block 'status: blocked\n'         '{"permission_mode":"bypassPermissions","tool_name":"Edit"}'
check "blocked: acceptEdits + Edit"         block 'status: blocked\n'         '{"permission_mode":"acceptEdits","tool_name":"Edit"}'
check "blocked: acceptEdits + Bash"         ask   'status: blocked\n'         '{"permission_mode":"acceptEdits","tool_name":"Bash"}'
check "blocked: malformed payload (closed)" block 'status: blocked\n'         "not json at all"
check "question with quotes/apostrophe"     ask   'status: blocked\n# item'"'"'s slug? say "y"\n' "{$M}"
check "done + question quoting the phrase"  pass  'status: done\n# keep "status: blocked"?\n'    "{$M}"
check "blocked + question quoting phrase"   ask   'status: blocked\n# keep "status: blocked"?\n' "{$M}"
check "CLAUDE_PROJECT_DIR unset"            ask   'status: blocked\n'         "{$M}"  nodir
# The status line counts only at the START of a line. A question written into the gate without the
# '#' prefix could otherwise supply the status: an un-prefixed line naming "status: done" placed
# above the real status line used to open a blocked gate.
check "un-prefixed question naming status: done" ask 'B1 set status: done yet?\nstatus: blocked\n' "{$M}"
check "un-prefixed question, status line first"  ask 'status: blocked\nB1 set status: done yet?\n' "{$M}"

# gate-clear.sh: it must release ONLY a gate a human was actually prompted about.
# $1 label | $2 expected final status | $3 scenario
clearcheck () {
  D=$(mktemp -d); P='{"permission_mode":"default","tool_name":"Bash"}'
  case "$3" in
    approved)  printf 'status: blocked\n# Q1\n' > "$D/.gate"
               printf '%s' "$P" | CLAUDE_PROJECT_DIR="$D" bash "$HOOK" >/dev/null 2>&1 ;;
    agent-set) printf 'status: done\n' > "$D/.gate"
               printf '%s' "$P" | CLAUDE_PROJECT_DIR="$D" bash "$HOOK" >/dev/null 2>&1
               printf 'status: blocked\n# Q1\n' > "$D/.gate" ;;
    gate-edit) printf 'status: blocked\n# Q1\n' > "$D/.gate"
               printf '%s' "$P" | CLAUDE_PROJECT_DIR="$D" bash "$HOOK" >/dev/null 2>&1
               printf 'status: blocked\n# Q1\n# Q2\n' > "$D/.gate" ;;
    twice)     printf 'status: blocked\n# Q1\n' > "$D/.gate"
               printf '%s' "$P" | CLAUDE_PROJECT_DIR="$D" bash "$HOOK" >/dev/null 2>&1
               CLAUDE_PROJECT_DIR="$D" bash "$CLEAR" ;;
  esac
  CLAUDE_PROJECT_DIR="$D" bash "$CLEAR" </dev/null
  got=$(grep -vE '^[[:space:]]*#' "$D/.gate" | grep -oE 'status:[[:space:]]*(done|blocked)' | head -1 | awk '{print $2}')
  rm -rf "$D"
  if [ "$got" = "$2" ]; then printf '  ok    %-48s -> %s\n' "$1" "$got"
  else printf '  FAIL  %-48s -> %s (expected %s)\n' "$1" "$got" "$2"; fails=$((fails+1)); fi
}

clearcheck "clear: human approved"              done    approved
clearcheck "clear: agent set the gate itself"   blocked agent-set
clearcheck "clear: approved a gate EDIT"        blocked gate-edit
clearcheck "clear: fires twice (parallel)"      done    twice


# ---- Per-session gates: .agentic/<session_id>/{gate,gate-asked} -------------------------------------
# $1 label | $2 expected | $3 got
ck () {
  if [ "$3" = "$2" ]; then printf '  ok    %-60s -> %s\n' "$1" "$3"
  else printf '  FAIL  %-60s -> %s (expected %s)\n' "$1" "$3" "$2"; fails=$((fails+1)); fi
}
pl () { printf '{"session_id":"%s",%s}' "$1" "$M"; }       # a payload carrying a session id
gate_at () { mkdir -p "$D/.agentic/$1"; printf '%b' "$2" > "$D/.agentic/$1/gate"; }
# Run the hook for project $1 with payload $2: prints verdict, then the stderr line count.
run_hook () {
  out=$(printf '%s' "$2" | CLAUDE_PROJECT_DIR="$1" bash "$HOOK" 2>"$1.err"); rc=$?
  if [ "$rc" = 2 ]; then v=block
  elif [ -z "$out" ]; then v=pass
  else v=$(printf '%s' "$out" | python3 -c 'import sys,json;print(json.load(sys.stdin)["hookSpecificOutput"]["permissionDecision"])' 2>/dev/null || echo badjson); fi
  echo "$v"
}
errlines () { wc -l < "$1.err" | tr -d ' '; }
state () { grep -vE '^[[:space:]]*#' "$1" 2>/dev/null | grep -oE 'status:[[:space:]]*(done|blocked)' | head -1 | awk '{print $2}'; }
clear_as () { printf '%s' "$2" | CLAUDE_PROJECT_DIR="$1" bash "$CLEAR" >/dev/null 2>&1; }

D=$(mktemp -d); gate_at sA 'status: blocked\n# Q1\n'
ck "A blocked: A's own tool call asks"                  ask  "$(run_hook "$D" "$(pl sA)")"
ck "A blocked: A's receipt is per-session, none legacy" "yes|no" "$([ -f "$D/.agentic/sA/gate-asked" ] && echo yes || echo no)|$([ -f "$D/.gate-asked" ] && echo yes || echo no)"
ck "A blocked: B's tool call passes"                    pass "$(run_hook "$D" "$(pl sB)")"
ck "A blocked: B gets exactly one note line"            "1|1" "$(errlines "$D")|$(grep -c '1 blocked gate(s) exist for other sessions (first: sA); this session is sB' "$D.err")"
ck "A blocked: B's subagent is not hard-blocked"        pass "$(run_hook "$D" "$(pl sB | sed 's/}$/,"agent_id":"s1","agent_type":"build"}/')")"
ck "A blocked: a payload with no id passes, one note"   "pass|1" "$(run_hook "$D" "{$M}")|$(errlines "$D")"
rm -rf "$D" "$D.err"

D=$(mktemp -d); gate_at sA 'status: blocked\n# Q1\n'; gate_at sC 'status: blocked\n'
ck "two foreign gates: still exactly ONE note line"     "pass|1" "$(run_hook "$D" "$(pl sB)")|$(errlines "$D")"
rm -rf "$D" "$D.err"

D=$(mktemp -d); gate_at sA 'status: done\n'
ck "no blocked gate anywhere: silent"                   "pass|0" "$(run_hook "$D" "$(pl sB)")|$(errlines "$D")"
rm -rf "$D" "$D.err"

D=$(mktemp -d); gate_at sA 'status: blocked\n# Q1\n'
out=$(printf '%s' "$(pl sA)" | CLAUDE_PROJECT_DIR="$D" bash "$HOOK" 2>/dev/null)
ck "prompt says it releases THIS session's gate"        "1|0" "$(printf '%s' "$out" | grep -c "this session's gate only")|$(printf '%s' "$out" | grep -c 'whole project root')"
rm -rf "$D"

# Approval and release are per session.
D=$(mktemp -d); gate_at sA 'status: blocked\n# QA\n'; gate_at sB 'status: blocked\n# QB\n'
run_hook "$D" "$(pl sA)" >/dev/null; run_hook "$D" "$(pl sB)" >/dev/null
clear_as "$D" "$(pl sA)"
ck "A's approval releases only A"                       "done|blocked" "$(state "$D/.agentic/sA/gate")|$(state "$D/.agentic/sB/gate")"
rm -rf "$D" "$D.err"
D=$(mktemp -d); gate_at sA 'status: blocked\n# QA\n'
run_hook "$D" "$(pl sA)" >/dev/null
clear_as "$D" "$(pl sB)"
ck "B's PostToolUse cannot release A's prompted gate"   "blocked|yes" "$(state "$D/.agentic/sA/gate")|$([ -f "$D/.agentic/sA/gate-asked" ] && echo yes || echo no)"
clear_as "$D" "$(pl sA)"
ck "A's own PostToolUse then releases it"               "done|no" "$(state "$D/.agentic/sA/gate")|$([ -f "$D/.agentic/sA/gate-asked" ] && echo yes || echo no)"
rm -rf "$D" "$D.err"
D=$(mktemp -d); gate_at sA 'status: done\n'; run_hook "$D" "$(pl sA)" >/dev/null; printf 'status: blocked\n# Q1\n' > "$D/.agentic/sA/gate"
clear_as "$D" "$(pl sA)"
ck "agent-set per-session gate is not wiped by gate-clear" blocked "$(state "$D/.agentic/sA/gate")"
rm -rf "$D" "$D.err"

# A legacy blocked .gate still gates a session that has an id, and is releasable by it.
D=$(mktemp -d); printf 'status: blocked\n# L1\n' > "$D/.gate"
ck "legacy blocked .gate gates a session with an id"    ask "$(run_hook "$D" "$(pl sA)")"
clear_as "$D" "$(pl sA)"
ck "...and that session's approval releases it"         "done|no" "$(state "$D/.gate")|$([ -f "$D/.gate-asked" ] && echo yes || echo no)"
rm -rf "$D" "$D.err"
D=$(mktemp -d); printf 'status: blocked\n' > "$D/.gate"; gate_at sA 'status: blocked\n# own\n'
ck "both blocked: the session's own gate is asked first" yes "$(run_hook "$D" "$(pl sA)" >/dev/null; [ -f "$D/.agentic/sA/gate-asked" ] && echo yes || echo no)"
rm -rf "$D" "$D.err"

# The id comes from the payload; CLAUDE_CODE_SESSION_ID only covers a payload that lacks one.
D=$(mktemp -d); gate_at sA 'status: blocked\n# Q1\n'
out=$(printf '{%s}' "$M" | CLAUDE_CODE_SESSION_ID=sA CLAUDE_PROJECT_DIR="$D" bash "$HOOK" 2>/dev/null)
ck "payload without an id falls back to the env var"    ask "$(printf '%s' "$out" | python3 -c 'import sys,json;print(json.load(sys.stdin)["hookSpecificOutput"]["permissionDecision"])' 2>/dev/null)"
out=$(pl sB | CLAUDE_CODE_SESSION_ID=sA CLAUDE_PROJECT_DIR="$D" bash "$HOOK" 2>/dev/null)
ck "the payload id wins over the env var"               "" "$out"
printf '{%s}' "$M" | CLAUDE_CODE_SESSION_ID=sA CLAUDE_PROJECT_DIR="$D" bash "$HOOK" >/dev/null 2>&1
printf '{%s}' "$M" | CLAUDE_CODE_SESSION_ID=sA CLAUDE_PROJECT_DIR="$D" bash "$CLEAR" >/dev/null 2>&1
ck "gate-clear falls back to the env var too"           done "$(state "$D/.agentic/sA/gate")"
rm -rf "$D" "$D.err"
D=$(mktemp -d); gate_at sA 'status: blocked\n'
ck "an id that is not [A-Za-z0-9_-]+ counts as no id"   "pass" "$(run_hook "$D" "$(pl '../.agentic/sA')")"
rm -rf "$D" "$D.err"

# The helper is a single point of failure. Missing, truncated, or syntax-broken, it is rejected as a
# whole: the shared .gate still gates, a per-session gate is not read, and no path is built from an
# empty variable. AGENTIC_SS_LOADED=1 is exported to prove the hooks unset a stale parent value.
helper_variant () {   # $1 label | $2 missing|truncated|syntax
  D=$(mktemp -d); T=$(mktemp -d); cp "$HOOK" "$CLEAR" "$T/"
  case "$2" in
    truncated) printf 'sid_dir() { printf "%%s" /nonexistent-bogus; }\n' > "$T/session-state.sh" ;;
    syntax)    printf 'sid_dir() { printf "%%s" /nonexistent-bogus; }\nif then fi )(\nAGENTIC_SS_LOADED=1\n' > "$T/session-state.sh" ;;
  esac
  printf 'status: blocked\n# L1\n' > "$D/.gate"
  a=$(pl sA | AGENTIC_SS_LOADED=1 CLAUDE_PROJECT_DIR="$D" bash "$T/gate-check.sh" 2>"$D.err" | python3 -c 'import sys,json;print(json.load(sys.stdin)["hookSpecificOutput"]["permissionDecision"])' 2>/dev/null)
  pl sA | AGENTIC_SS_LOADED=1 CLAUDE_PROJECT_DIR="$D" bash "$T/gate-clear.sh" >/dev/null 2>&1
  b=$(state "$D/.gate")
  rm -f "$D/.gate"; gate_at sA 'status: blocked\n# own\n'
  c=$(pl sA | AGENTIC_SS_LOADED=1 CLAUDE_PROJECT_DIR="$D" bash "$T/gate-check.sh" 2>>"$D.err")
  bogus=$(grep -cF '/nonexistent-bogus' "$D.err")
  ck "$1" "ask|done|pass:|bogus=0|note=0" "$a|$b|pass:$c|bogus=$bogus|note=$(grep -c 'blocked gate(s)' "$D.err")"
  rm -rf "$D" "$D.err" "$T"
}
helper_variant "helper missing -> legacy .gate still gates, no bogus path"            missing
helper_variant "helper truncated after first function -> legacy, still gates"         truncated
helper_variant "helper syntax error after first function -> legacy, still gates"      syntax

# bin/unblock: no argument lists and clears only when exactly one gate is blocked.
ub () { CLAUDE_PROJECT_DIR="$D" bash "$UNBLOCK" "$@" 2>&1; }
D=$(mktemp -d); gate_at sA 'status: blocked\n# QA\n'; gate_at sB 'status: blocked\n# QB\n'; printf 'status: blocked\n# QL\n' > "$D/.gate"
out=$(ub); rc=$?
ck "unblock (no arg), 3 blocked: lists all, clears none" "rc=1|3|1|1|1" "rc=$rc|$(printf '%s\n' "$out" | grep -cE '^(legacy|session s[AB])  \(')|$(printf '%s' "$out" | grep -c '# QA')|$(printf '%s' "$out" | grep -c '# QB')|$(printf '%s' "$out" | grep -c '# QL')"
ck "...nothing was cleared"                              "blocked|blocked|blocked" "$(state "$D/.gate")|$(state "$D/.agentic/sA/gate")|$(state "$D/.agentic/sB/gate")"
ub sB >/dev/null; rc=$?
ck "unblock <sid> clears only that session's gate"      "rc=0|blocked|blocked|done" "rc=$rc|$(state "$D/.gate")|$(state "$D/.agentic/sA/gate")|$(state "$D/.agentic/sB/gate")"
ub --legacy >/dev/null
ck "unblock --legacy clears only the shared .gate"      "done|blocked" "$(state "$D/.gate")|$(state "$D/.agentic/sA/gate")"
ub >/dev/null; rc=$?
ck "unblock (no arg), exactly one blocked: clears it"   "rc=0|done" "rc=$rc|$(state "$D/.agentic/sA/gate")"
rm -rf "$D"
D=$(mktemp -d); gate_at sA 'status: blocked\n'; gate_at sB 'status: blocked\n'; printf 'status: blocked\n' > "$D/.gate"
ub --all >/dev/null
ck "unblock --all clears every blocked gate"            "done|done|done" "$(state "$D/.gate")|$(state "$D/.agentic/sA/gate")|$(state "$D/.agentic/sB/gate")"
ub sZ >/dev/null; r1=$?; ub '../x' >/dev/null; r2=$?
ck "unblock: unknown sid rc=1, unsafe sid rc=2"         "1|2" "$r1|$r2"
rm -rf "$D"
D=$(mktemp -d); printf 'status: blocked\n# L1\n' > "$D/.gate"; : > "$D/.gate-asked"
ub >/dev/null
ck "unblock vs legacy file as before: record + receipt" "done|1|1|no" "$(state "$D/.gate")|$(grep -c '^# L1' "$D/.gate")|$(grep -c 'released by hand via bin/unblock' "$D/.gate")|$([ -f "$D/.gate-asked" ] && echo yes || echo no)"
rm -rf "$D"

if [ "$fails" = "0" ]; then echo "ALL PASS (49/49)"; else echo "$fails FAILURE(S) — you do not have a working grilling gate"; exit 1; fi
