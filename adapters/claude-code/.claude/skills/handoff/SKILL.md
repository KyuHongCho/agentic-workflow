---
name: handoff
description: Save a workflow document — a handoff record for a boundary (stage → stage, session → session), a plan document from the plan role, or a review record once review-audit returns PASS. Follow core/shared/handoff.md, ask the human where it goes, and name it <kind>-<project-name>_<n>-<summary>.md (a review record: review-<project-name>-pr-<number>-<branch>.md). Use when a plan is audited PASS, when review-audit returns PASS, when the human asks for a handoff record, or when a context is about to end with work unfinished.
---

# handoff

**The protocol is `$AGENTIC_WORKFLOW_HOME/core/shared/handoff.md`. Read it and follow it.** It
carries the boundary split, the sections, the state to re-run, redaction, and the save-location
options. Nothing here repeats it.

**Three kinds of document use this skill:** a **handoff record** (stage → stage, session → session), a
**plan document** produced by `core/roles/plan.md`, and a **review record** (the review and audit
comments of a finished loop — `handoff.md` § *Review record*; named
`review-<project-name>-pr-<number>-<branch>.md`, **not** by the `<n>-<summary>` recipe below, and
never given a `state:` or `recorded:` field). `handoff.md` § *Where to write it*, § *What to
name it* and § *Rules* govern **both** — the name `<kind>-<project-name>_<n>-<summary>.md`, and the
rules on paths existing, redaction, verified-vs-recalled and never shipping. The boundary split, §
*Stage handoff*, § *Session handoff* and the § *Rules* bullets about the record itself are the
handoff record's alone; a plan document is the plan itself, saved under that name.

Six things it cannot know about Claude Code:

- **Ask the location question with `AskUserQuestion`.** `handoff.md` requires the human to choose
  and lists the four options; present them as that tool's choices, `documents/<project-name>/`
  marked *(recommended)*. Never pick one yourself, and never skip the question because a previous
  document went somewhere.
- **Only the main thread writes either document.** A role or auditor subagent has no user-facing
  tool, so it cannot ask — it reports its artifact and hands back. That hand-back is correct
  behaviour, for a plan document exactly as for a handoff record.
- **`Read` does not expand `$AGENTIC_WORKFLOW_HOME`** — resolve it with Bash first, then use the
  absolute path.
- **Handoff record only — re-run the `state` values with Bash and paste the real output.**
  `handoff.md` requires them re-established at write time; a figure carried from earlier in the
  conversation is the commonest way a handoff goes stale. A plan document has no `state:` field, so
  there is nothing here to re-run for one.
- **Handoff record only — the `recorded:` timestamp comes from `date`, not from your context.**
  Claude Code puts a date in the system prompt, but it is a date only — no clock time, no timezone —
  and you cannot tell how stale it is. Run `date '+%Y-%m-%d %H:%M:%S %Z (%z)'` and paste its output
  verbatim. A plan document has no `recorded:` field either; do not add one to it.
- **Compute `<n>` from the directory the human just chose**, after they answer the location question
  — not before, and not from the last document you can remember. One `ls | sed | sort -n | tail -1`
  as `handoff.md` specifies, matching `^<kind>-<project-name>_` for the kind you are writing, so plan
  documents and handoff records number separately; empty output means `1`.
- **Review record only — two `AskUserQuestion` prompts, in order, never bundled:** (1) the location,
  as above; (2) the PR number. For the second, run
  `gh pr list --head <branch> --state all --json number` first and offer what it found; with no PR the
  options are `pending` and "type a number". Replace every `/` in the branch name with `-`. Assemble
  the file from the **verbatim hand-backs** of `review` and `review-audit` (final round); keep them
  verbatim in your own context rather than reconstructing them, and say so in the file where a field
  (typically the audit's blind pass) did not happen.
