#!/usr/bin/env bash
# Self-test for ship-gate.sh. Run after installing it, and again after ever moving or renaming
# this repo — `.claude/hooks` is normally a symlink, and a broken symlink makes the hook exit 127,
# which does NOT block. The gate then fails OPEN with no warning. A guard that never trips proves
# nothing, so check that it still trips.
#
#   bash ship-gate.selftest.sh
#
# Expected: "ALL PASS". Anything else means you do not have a working shipping gate.
GATE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ship-gate.sh"

if [ ! -f "$GATE" ]; then
  echo "FAIL: $GATE does not exist. The gate is not installed (or the symlink is broken)."
  exit 1
fi

fails=0

# $1 label | $2 expected: ask|block|pass | $3 payload
check () {
  out=$(printf '%s' "$3" | bash "$GATE" 2>/dev/null); rc=$?
  if [ "$rc" = "2" ]; then got=block
  elif [ -z "$out" ]; then got=pass
  else got=$(printf '%s' "$out" | python3 -c 'import sys,json;print(json.load(sys.stdin)["hookSpecificOutput"]["permissionDecision"])' 2>/dev/null || echo "badjson")
  fi
  if [ "$got" = "$2" ]; then printf '  ok    %-46s -> %s\n' "$1" "$got"
  else printf '  FAIL  %-46s -> %s (expected %s, rc=%s)\n' "$1" "$got" "$2" "$rc"; fails=$((fails+1)); fi
}

M='"permission_mode":"default","tool_name":"Bash"'
S='"permission_mode":"default","agent_id":"sa-1","agent_type":"build","tool_name":"Bash"'

check "main: git commit"            ask   "{$M,\"tool_input\":{\"command\":\"git commit -m x\"}}"
check "main: git push"              ask   "{$M,\"tool_input\":{\"command\":\"git push -u origin b\"}}"
check "main: gh pr create"          ask   "{$M,\"tool_input\":{\"command\":\"gh pr create --title t\"}}"
check "main: gh api POST pulls"     ask   "{$M,\"tool_input\":{\"command\":\"gh api -X POST repos/o/r/pulls\"}}"
check "main: safe-then-ship chain"  ask   "{$M,\"tool_input\":{\"command\":\"git push --dry-run && git push\"}}"
check "main: bash -c wrapped"       ask   "{$M,\"tool_input\":{\"command\":\"bash -c 'git commit -m x'\"}}"
check "subagent: git commit"        block "{$S,\"tool_input\":{\"command\":\"git commit -m x\"}}"
check "subagent: gh pr create"      block "{$S,\"tool_input\":{\"command\":\"gh pr create --title t\"}}"
check "bypass mode escalates"       block "{\"permission_mode\":\"bypassPermissions\",\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"git commit -m x\"}}"
check "main: git status"            pass  "{$M,\"tool_input\":{\"command\":\"git status --porcelain\"}}"
check "main: git push --dry-run"    pass  "{$M,\"tool_input\":{\"command\":\"git push --dry-run\"}}"
check "main: gh pr view"            pass  "{$M,\"tool_input\":{\"command\":\"gh pr view 3 --json body\"}}"
check "subagent: run tests"         pass  "{$S,\"tool_input\":{\"command\":\"python3 -m unittest discover\"}}"
check "malformed payload"           pass  "not json at all"

if [ "$fails" = "0" ]; then echo "ALL PASS (14/14)"; else echo "$fails FAILURE(S) — you do not have a working shipping gate"; exit 1; fi
