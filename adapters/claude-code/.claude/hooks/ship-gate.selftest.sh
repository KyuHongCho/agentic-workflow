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

w=$(wiring_problems)
if [ -z "$w" ]; then printf '  ok    %-46s -> %s\n' "wiring: settings.json scripts + helper" wired
else printf '  FAIL  %-46s -> %s\n' "wiring: settings.json scripts + helper" "$(echo "$w" | tr '\n' ';')"; fails=$((fails+1)); fi

# Second layer: native ask rules force a prompt even if the hook is missing or fails open. Every verb the
# hook gates must have one, except gh api, which stays hook-only.
ask_missing=$(python3 -c 'import json,sys
want=["Bash(git commit *)","Bash(git push *)","Bash(gh pr create *)","Bash(gh pr merge *)","Bash(gh pr ready *)","Bash(gh release create *)"]
try: have=json.load(open(sys.argv[1])).get("permissions",{}).get("ask",[])
except Exception: have=[]
print(" ".join(w for w in want if w not in have))' "$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../settings.json" 2>&1)
if [ -z "$ask_missing" ]; then printf '  ok    %-46s -> %s\n' "settings.json ask rules for shipping verbs" present
else printf '  FAIL  %-46s -> %s\n' "settings.json ask rules for shipping verbs" "missing: $ask_missing"; fails=$((fails+1)); fi

if [ "$fails" = "0" ]; then echo "ALL PASS (16/16)"; else echo "$fails FAILURE(S) — you do not have a working shipping gate"; exit 1; fi
