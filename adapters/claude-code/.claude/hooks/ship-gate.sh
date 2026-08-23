#!/usr/bin/env bash
# PreToolUse hook (Claude Code). Gates *shipping* actions behind explicit human consent.
# The roles produce code and the auditors verify it, but deciding to publish is the human's call,
# not the loop's. Instructions alone did not produce compliance before (that is why the audit gate
# is a hook and not a paragraph), so this is mechanical too. See core/shared/shipping.md.
#
# Two different answers, because the two callers differ in what they *can* do:
#   - inside a subagent  -> exit 2 (hard block). These agents have no user-facing tool, so they can
#                           never obtain consent, so they must never ship. They hand back instead.
#   - in the main thread -> "ask": routes to the human's own approval prompt, which cannot be
#                           forged by the agent. Escalated to a hard block in modes that would not
#                           actually prompt, where "ask" would be a silent no-op.
#
# Scope is exactly the three decisions the human is asked about - commit, push, PR - plus the REST
# equivalents. Local-only `git tag` / `git merge` publish nothing and are covered by the push gate,
# so they are left alone to keep the false-positive surface small.
#
# Known and accepted limits - this is a guardrail against forgetting, NOT a sandbox against evasion:
#   * A command that runs a *script* which ships (`bash deploy.sh`) cannot be recognised here.
#   * A command that merely mentions a shipping verb in quotes will also prompt. A wasted
#     confirmation is cheap; a missed one publishes without consent.
#   * If THIS FILE IS MISSING the hook exits 127 and the tool call proceeds - the gate fails OPEN,
#     silently. `.claude/hooks` is usually a symlink, so re-run the self-test after moving this
#     repo:  printf '{"tool_input":{"command":"git commit -m x"}}' | bash ship-gate.sh ; echo $?
#     Expect JSON + rc=0 for the main thread, and rc=2 when "agent_id" is present.
#
# The payload reaches python through the environment, NOT interpolated into a quoted -c string: an
# apostrophe in a message would otherwise break the script and fail the gate open. JSON is parsed
# properly rather than sed'd - a greedy regex over a hook payload is exactly the bug that caused
# every spurious audit debt (see audit-track.sh).
payload=$(cat)

SHIP_GATE_PAYLOAD="$payload" python3 - <<'PY'
import json, os, re, sys

try:
    d = json.loads(os.environ.get("SHIP_GATE_PAYLOAD") or "")
except Exception:
    sys.exit(0)                       # unparseable -> never interfere with the tool call

cmd = (d.get("tool_input") or {}).get("command") or ""
if not cmd:
    sys.exit(0)

# Read-only forms. Evaluated PER SEGMENT: checking these against the whole command let
# `git push --dry-run && git push` through, because the safe half vouched for the unsafe half.
SAFE = re.compile(r"""
    --dry-run\b
  | --help\b | (?:^|\s)-h(?:\s|$)
  | \bgh\s+pr\s+(?:view|list|checks|diff|status)\b
""", re.VERBOSE)

# Shipping verbs. Unanchored within a segment so `bash -c 'git commit'` is still caught; the
# leading class therefore admits quotes as well as shell operators.
SHIP = re.compile(r"""
    (?:^|[;&|(\s'"])
    (?:
        git (?:\s+--?[^\s]+(?:\s+[^\s-][^\s]*)?)* \s+ (?:commit|push)\b
      | gh \s+ pr \s+ (?:create|merge|ready)\b
      | gh \s+ release \s+ create\b
    )
""", re.VERBOSE)

# `gh api` is a second front door to the same actions (opening a PR, pushing a ref). Gate it only
# when it is a WRITE: an explicit non-GET method, or a field flag, which implies POST.
GH_API_WRITE = re.compile(r"""
    \bgh\s+api\b
    (?=.*(?:
        (?:-X|--method)\s+(?:POST|PUT|PATCH|DELETE)\b
      | (?:^|\s)(?:-f|-F|--field|--raw-field)\s
    ))
""", re.VERBOSE | re.IGNORECASE)

LEADING_ENV = re.compile(r"^(?:[A-Za-z_][A-Za-z0-9_]*=\S*\s+)*")


def ships(segment):
    seg = LEADING_ENV.sub("", segment.strip())
    if not seg:
        return False
    if SAFE.search(seg):
        return False
    return bool(SHIP.search(seg) or GH_API_WRITE.search(seg))


# Split on shell separators so each command is judged on its own merits.
if not any(ships(s) for s in re.split(r"\|\||&&|[;&|\n]", cmd)):
    sys.exit(0)                       # nothing publishes -> normal permission flow

# MEASURED, not assumed: agent_id is absent in the main thread and present inside a subagent.
if d.get("agent_id"):
    # Exit 2 rather than a JSON "deny": exit 2 always blocks, whereas a JSON decision can be
    # overridden by permission mode. A subagent can never obtain consent, so this must not be
    # overridable.
    agent = d.get("agent_type") or "subagent"
    sys.stderr.write(
        'Blocked: shipping is not permitted inside the "{a}" subagent. A subagent has no channel '
        "to ask the human, and publishing is the human's decision - so a subagent must never "
        "commit, push, open a PR, or merge one. Finish your artifact, report what changed plus "
        "the evidence, and hand back to the main thread; it runs the commit/push/PR consent "
        "sequence with the human (core/shared/shipping.md).\n".format(a=agent)
    )
    sys.exit(2)

# Main thread. In a mode that does not prompt, "ask" would be a silent no-op - which is precisely
# how a PR once got opened with nobody asked. Fail closed instead, and say why.
mode = d.get("permission_mode") or "default"
if mode in ("bypassPermissions", "dontAsk"):
    sys.stderr.write(
        "Blocked: this is a shipping action and permission_mode is '{m}', so an approval prompt "
        "would not be shown - consent cannot be obtained from a dialog here. Ask the human "
        "directly in the conversation (Q1 commit / Q2 push / Q3 PR, one at a time, per "
        "core/shared/shipping.md). If they agree, they can run the command themselves, or re-run "
        "this session in a mode that prompts.\n".format(m=mode)
    )
    sys.exit(2)

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "ask",
        "permissionDecisionReason": (
            "Shipping action - this prompt IS the human's approval step.\n"
            "Before approving, the main thread should already have asked, in order: "
            "(Q1) proposed a one-line commit message derived from the staged diff and asked "
            "whether to commit; (Q2) reported whether an upstream remote is set and asked whether "
            "to push; (Q3) asked whether to open the PR. If it did not ask, decline and make it ask."
        ),
    }
}))
PY
# Propagate python's status. A literal `exit 0` here would swallow the block entirely.
exit $?
