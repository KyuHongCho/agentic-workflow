# Shared skill: shipping

Publishing is **not** a stage. Producing an artifact and publishing it are different decisions, and
only the human makes the second one. Tool-agnostic; invoked from `handoff.md`.

## Who may ship
- **Roles and auditors: never.** `plan`, `build`, `review` and their auditors produce and verify
  artifacts. None of them commits, pushes, opens a PR, or merges one — not when the work is
  obviously finished, and not when told to "finish the task".
- **The coordinating (main) thread: only after the human says yes**, question by question.

The reason is structural, not stylistic: a role runs as a subagent and, as configured, has **no
user-facing tool** — so it cannot obtain consent, and must not take the action that requires it.
It reports its artifact and hands back instead.

## Where review sits
`review ↔ review-audit` runs **once per unit of work** — the slices that go up in one PR, one slice
or several — after its last slice is built, and it must be settled **before Q2 (push)**: review is
what stands between a local artifact and a public one. Q1 is a local, reversible commit, so review's
order relative to Q1 is a prompt, not a rule.

After a slice reaches `build-audit` PASS, ask *"has the review stage happened for everything now in
this unit of work?"*:

- **No, and this is its last (or only) slice** → before Q1, ask: run `review ↔ review-audit` now,
  commit first, or skip review. *Commit first* → after Q1, ask this question again before Q2; that
  re-ask offers only run now or skip. This includes an open PR whose `/agentic-review` ran before
  this slice landed: that review did not see it.
- **No, but more slices of the same unit remain** → straight to Q1. Q2 and Q3 wait until the last
  slice, then ask again.
- **Yes** — an `/agentic-review`, or a local `review ↔ review-audit`, already covered this unit and
  this is a fix round to what that review covered (addressing its findings), not new scope →
  straight to Q1; Q2 step 0 then states "covered by <that review>".

A fix round after a review's CHANGES REQUESTED, and its `build-audit`, takes the **Yes** branch:
that review covered it, so it is not asked again.

Q2 states the outcome (see Q2 step 0). No hook checks this: `ship-gate.sh` gates only the commit,
push and PR actions themselves.

## The consent sequence — Q1 → Q2 → Q3, in order, one at a time
Run it only after the artifact is audited `PASS`; the review question above must be settled before
Q2, not before Q1.
Ask each question separately; never bundle them.

### Q1 — commit
1. **Propose the message first.** Derive a one-line explanatory commit message **from the staged
   diff**, not from memory of intent: stage the change, read `git diff --cached --name-status`,
   and confirm every path is accounted for in the message.
2. Then ask: *"Shall I commit this, or would you rather commit it yourself?"*
   - **Yes** → the agent commits, then go to Q2 once the unit's last slice is built (after the
     review question, if it was deferred).
   - **No** → *"Let me know once you've committed."* Wait for the human, then go to Q2 once the
     unit's last slice is built (after the review question, if it was deferred).

### Q2 — push
0. **State review's status** — one of: *ran* for this unit of work; *skipped* by the human (quote
   their answer); or *covered* by an earlier review of this unit, named (an `/agentic-review` or a
   local `review ↔ review-audit`). If none holds, stop and ask the review question first.
1. **Check the upstream yourself** — `git rev-parse --abbrev-ref --symbolic-full-name @{u}`
   (a non-zero exit means no upstream is set). This is a fact: find it, don't ask about it.
2. Then ask: *"Shall I push?"*
   - **Yes** → push. If no upstream exists, use `git push --set-upstream origin <branch>`.
   - **No** → tell the human whether an upstream is set, and if not, give them the exact
     `--set-upstream` command. Then go to Q3.

### Q3 — pull request
Ask: *"Shall I open the PR?"*
- **Yes** → run the tool's PR skill (Claude Code: the `open-pr` skill). Never hand-roll the body.
- **No** → do **not** run the skill. Give the human a copy-paste-ready PR description in Markdown,
  in the same format the skill produces, plus the command to open it.

Either way the description must be **fact-checked and proof-read before it is shown or submitted**:
every command, number and claim re-run or re-read, never recalled.

## Rules
- Never ship an unaudited artifact — except a review the human explicitly skipped: an explicit
  answer (quoted) in Q2, a recorded waiver. Never ship while `grilling` has an open question.
- Never push to a protected/default branch, force-push, or merge, without being asked for that
  specific action.
- "The human told me to build it" is **not** consent to publish it.
