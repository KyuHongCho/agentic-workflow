# CLAUDE.md — agentic-workflow (Claude Code adapter)

This project uses the **agentic-workflow** system: **plan → build → review**, each checked by an
adversarial auditor, with **mandatory grilling** whenever anything is unclear.

- Roles are available as **subagents** in `.claude/agents/` (`plan`, `build`, `review`).
- **Auditors are subagents too**: `plan-audit`, `build-audit`, `review-audit`.
- Portable definitions (single source of truth): `$AGENTIC_WORKFLOW_HOME/core/` (`roles/`, `auditors/`, `shared/`).
- `Read` does **not** expand `$AGENTIC_WORKFLOW_HOME`; resolve it with Bash first, then use absolute paths.

## You (the main thread) own the audit loop
Subagents cannot dispatch each other, so **you** must run the loop — no role can call its own auditor.
After **every** role subagent returns, dispatch its auditor on the same artifact, per
`$AGENTIC_WORKFLOW_HOME/core/shared/audit-loop.md`:

`plan → plan-audit` · `build → build-audit` · `review → review-audit`

**Granularity: one `build ↔ build-audit` loop per vertical slice**, not one per plan — see
`$AGENTIC_WORKFLOW_HOME/core/shared/vertical-slices.md`. Dispatch `build` for one slice, audit it,
then move to the next. The audit gate counts one debt per role run, so two slices owe two audits.

- On `REVISE`, hand the objection list back to the role subagent **verbatim** — never just "try again" —
  then re-audit, and the auditor must confirm each prior objection is resolved before looking for new ones.
- **Never** advance a stage on an unaudited artifact, and **never** exit `PASS` with an objection still open.
- If the same objection recurs, or after 3 revise rounds without `PASS`, stop and escalate to the human
  with the full objection history.

This is enforced mechanically — see the audit gate below. Auditors hold `Edit`/`Write`/`Bash` because
`core/shared/verify.md` requires them to amend code and run tests to establish facts; they are required
to revert everything and report `git status --porcelain`.

## Hard-enforced audit gate (Claude Code only)
A `SubagentStop` hook (`.claude/hooks/audit-track.sh`) records which roles have run and which audits are
still owed, in `${CLAUDE_PROJECT_DIR}/.audit-pending`. A `Stop` hook (`.claude/hooks/audit-gate.sh`)
**refuses to let the turn end** while any audit is outstanding. You cannot skip the loop by forgetting it.

The audit gate stands down while the grilling gate is `blocked` — at that point the human owes an answer,
and auditors could not run anyway (their `Bash`/`Edit` would be gated).

## Hard-enforced grilling gate (Claude Code only)
A PreToolUse hook (`.claude/hooks/gate-check.sh`, wired in `.claude/settings.json`) blocks
`Write`/`Edit`/`Bash` while a gate file marks questions open. To make it bite, **mirror your grilling
state to the gate file**:

- **When grilling raises an open question** → write `status: blocked` to `${CLAUDE_PROJECT_DIR}/.gate`, then ask the human. (You can — you are not yet blocked.)
- **Only the human clears the gate.** Once blocked you cannot flip it back — `Write`/`Edit`/`Bash` are all gated, by design. Do **not** route around it (subagents, alternate tools). Ask the human to clear it: `echo 'status: done' > .gate` (or the `bin/unblock` helper).

While blocked you can still read, search, and ask — you just cannot change code until the human clears the gate.
