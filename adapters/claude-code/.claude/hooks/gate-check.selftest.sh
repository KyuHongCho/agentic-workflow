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

for f in "$HOOK" "$CLEAR"; do
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
  CLAUDE_PROJECT_DIR="$D" bash "$CLEAR"
  got=$(grep -vE '^[[:space:]]*#' "$D/.gate" | grep -oE 'status:[[:space:]]*(done|blocked)' | head -1 | awk '{print $2}')
  rm -rf "$D"
  if [ "$got" = "$2" ]; then printf '  ok    %-48s -> %s\n' "$1" "$got"
  else printf '  FAIL  %-48s -> %s (expected %s)\n' "$1" "$got" "$2"; fails=$((fails+1)); fi
}

clearcheck "clear: human approved"              done    approved
clearcheck "clear: agent set the gate itself"   blocked agent-set
clearcheck "clear: approved a gate EDIT"        blocked gate-edit
clearcheck "clear: fires twice (parallel)"      done    twice

if [ "$fails" = "0" ]; then echo "ALL PASS (18/18)"; else echo "$fails FAILURE(S) — you do not have a working grilling gate"; exit 1; fi
