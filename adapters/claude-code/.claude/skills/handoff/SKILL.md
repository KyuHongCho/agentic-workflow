---
name: handoff
description: Save a workflow document — a handoff record for a boundary (stage → stage, session → session), or a plan document from the plan role. Follow core/shared/handoff.md, ask the human where it goes, and name it <kind>-<project-name>_<n>-<summary>.md. Use when a plan is audited PASS, or when a context is about to end with work unfinished.
---

# handoff

**The protocol is `$AGENTIC_WORKFLOW_HOME/core/shared/handoff.md`. Read it and follow it.** It
carries the boundary split, the sections, the state to re-run, redaction, and the save-location
options. Nothing here repeats it.

**Two kinds of document use this skill:** a **handoff record** (stage → stage, session → session) and
a **plan document** produced by `core/roles/plan.md`. `handoff.md` § *Where to write it*, § *What to
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
