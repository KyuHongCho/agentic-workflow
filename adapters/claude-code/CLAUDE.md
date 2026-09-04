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

**This gate fails OPEN if either script is missing, and it fails _silently_** — a broken
`.claude/hooks` symlink makes the hook exit 127, the `Stop` hook does not block, and the turn simply
ends with the audit never demanded. Nothing turns red; the only symptom is an audit that never
happened. After installing, and after ever moving this repo, run:
`bash .claude/hooks/audit-gate.selftest.sh` — expect `ALL PASS (8/8)`.

## Hard-enforced grilling gate (Claude Code only)
A PreToolUse hook (`.claude/hooks/gate-check.sh`, wired in `.claude/settings.json`) gates
`Write`/`Edit`/`Bash` while a gate file marks questions open — routing them to the human's approval
prompt, or hard-blocking where no prompt would be shown. To make it bite, **mirror your grilling
state to the gate file**:

- **When grilling raises an open question** → write `status: blocked` to `${CLAUDE_PROJECT_DIR}/.gate`,
then **one `# <question>` line per open question**, then ask the human. (You can — you are not yet
blocked.) Those `#` lines are what `gate-check.sh` puts into the approval prompt; without them it
shows `(gate file lists no questions)` and the human is asked to release a gate whose reason they
cannot see. Only the status line may begin with `status:` — a question that starts with it would be
read as the status instead:

  ```
  status: blocked
  # B1 does a sub-category OWN or CLASSIFY its items?
  # B2 is items.slug mutable on update?
  ```
- **Only the human clears the gate — but they now do it in-session.** Your first `Write`/`Edit`/`Bash`
after blocking raises an approval prompt carrying the open questions; approving it releases the gate
(`gate-clear.sh`), declining leaves it shut. You still cannot release it yourself: `gate-clear.sh`
acts only on a gate `gate-check.sh` recorded a prompt for, so the gate *you* set is never wiped by
your own tool call. Do **not** route around it (subagents, alternate tools).
- **Where no prompt would be shown it hard-blocks instead** — inside a subagent, or in
`bypassPermissions`/`dontAsk` (and `acceptEdits` for `Write`/`Edit`), because an unshown prompt is not
an answer. Then ask in the conversation and the human runs
`$AGENTIC_WORKFLOW_HOME/adapters/claude-code/bin/unblock` — the install in `README.md` does not
symlink `bin/`, so there is no `bin/unblock` at the project root.

While blocked you can still read, search, and ask — you just cannot change code until the human
releases the gate.

**This gate fails OPEN if either script is missing** — a broken `.claude/hooks` symlink makes the
hook exit 127, which does not block. After installing, and after ever moving this repo, run:
`bash .claude/hooks/gate-check.selftest.sh` — expect `ALL PASS (18/18)`.

## Hard-enforced shipping gate (Claude Code only)
Publishing is **not** a stage — see `$AGENTIC_WORKFLOW_HOME/core/shared/shipping.md`. A `PreToolUse`
hook (`.claude/hooks/ship-gate.sh`) intercepts `git commit` / `git push`,
`gh pr create|merge|ready`, `gh release create`, and write calls to `gh api`:

- **Inside a role or auditor subagent → blocked outright (exit 2).** These agents have no
  user-facing tool, so they can never obtain consent. The subagent reports its artifact and hands
  back — that hand-back is the correct behaviour, not a failure.
- **In the main thread → routed to your approval prompt.** You are the gate. In a permission mode
  that would not actually prompt (`bypassPermissions`, `dontAsk`) it hard-blocks instead, because
  an unshown prompt is not consent.

**You (the main thread) own the consent sequence.** After a slice reaches `build-audit` PASS, run
Q1 → Q2 → Q3 from `shipping.md`, **one question at a time**: propose a one-line commit message
derived from the staged diff and ask whether to commit; report whether an upstream is set and ask
whether to push; ask whether to open the PR and, if yes, run the `open-pr` skill. Never bundle the
questions, and never treat "build this" as consent to publish it.

Read-only forms (`git status`, `git diff`, `git log`, `git push --dry-run`, `gh pr view|checks`)
pass through untouched. Local-only `git tag` / `git merge` are deliberately not gated: they publish
nothing, and the push they would need is gated.

**This gate fails OPEN if its script is missing** — a broken `.claude/hooks` symlink makes the hook
exit 127, which does not block. After installing, and after ever moving this repo, run:
`bash .claude/hooks/ship-gate.selftest.sh` — expect `ALL PASS (14/14)`.

**It also fails open if it is never wired.** Hooks load from the **project root's**
`.claude/settings.json` — the directory Claude Code was started in. A repo's own `.claude/` is inert
unless that repo *is* the project root: open a parent directory instead and every hook here is
silently inactive, with the `CLAUDE.md` instructions still loading normally. You get the rules
without the enforcement. `ship-gate.selftest.sh` cannot detect this — it tests the script, not
whether it is registered — so check `.claude/settings.json` exists at the directory you started in.

**Editing `ship-gate.sh` can lock out Bash.** A shell syntax error makes it exit 2, which blocks the
tool call, so *every* Bash call fails while the file is broken (the matcher is `Bash`). `Edit`/`Write`
still work — only `gate-check.sh` matches those — so repair it with the editor, or from a plain
terminal outside Claude Code.
