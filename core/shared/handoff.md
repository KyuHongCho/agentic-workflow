# Shared skill: handoff

The protocol for passing work across a **boundary**. Tool-agnostic; invoked by every role and
auditor. (Cross-cutting concern — factored out of the roles so it lives in one place.)

Two boundaries need it, and they lose different things:

- **Stage → stage** — `plan` → `build` → `review`, inside one session. The artifact is on disk and
  the context is still warm, so the record is a short pointer.
- **Session → session** — one context ends, a fresh one continues. `vertical-slices.md` makes this
  routine ("one slice per fresh context"), and it is the boundary where reasoning is actually lost:
  everything not written down is gone, and the next session cannot ask you what you meant.

## When to invoke
- **Stage:** at the end of a stage, once its artifact is produced **and** no open `grilling` questions remain.
- **Session:** before a context ends with work unfinished — a slice completed, a budget exhausted, or
  the human stopping for the day.

## Where to write it

**These next two sections — *Where to write it* and *What to name it* — govern any workflow document
this system produces, not just handoff records, and so does § *Rules*.** Today there are two kinds: a
**handoff record** (this file) and a **plan document** (`../roles/plan.md`). Read `<kind>` below as
whichever you are writing — `handoff` or `plan`. What belongs to the handoff record alone is the
boundary split above, § *Stage handoff*, § *Session handoff*, and the § *Rules* bullets about the
record itself — the `recorded:` clock, `status: blocked`, the receiving stage's confirmation, and
keeping the record a pointer.

**Default to outside the repository.** A workflow document describes internal process; a tracked
`handoffs/` or `plans/` directory publishes it to anyone who clones the repo. Write inside the repo
only when it is private *and* that has been agreed.

**Who asks: the coordinating thread.** A role or auditor produces the artifact and hands it back;
it does not run this section itself. Where one agent plays every role, that agent is the
coordinating thread — it asks and it writes.

**Ask the human — do not choose for them.** Derive the project name from the repo root
(`~/work/crop-climate-advisor` → `crop-climate-advisor`), then offer:

1. `<workspace>/documents/<project-name>/` — **the default keepsake location**, beside that
   project's other documents. Durable, outside the repo, and where the last one will be found.
2. **The OS temp directory** — satisfies "outside the repo", but is ephemeral: gone on reboot, so
   the next session may find nothing.
3. **A gitignored path inside the repo** — beside the work. Only if `.gitignore` already covers it;
   check, and say what you found.
4. **Somewhere else** — let them name a path.

## What to name it

`<kind>-<project-name>_<n>-<summary>.md` — `<kind>` is `handoff` or `plan`, `<project-name>` the one
you derived above, then:

- **`<n>` — the next number in the chosen directory.** Read it off the directory; never guess it, and
  never restart at 1 because you personally have not written one before. **The sequence is per project
  *and per kind*:** the recipe matches `^<kind>-<project-name>_`, so `handoff-` and `plan-` number
  separately by construction. Within one kind the boundary makes no difference — a stage handoff and a
  session handoff share that kind's run of numbers:

  ```bash
  ls <dir> | sed -n 's/^<kind>-<project-name>_\([0-9][0-9]*\).*/\1/p' | sort -n | tail -1
  ```

  Empty output means this is `1`. Names that do not match are documents of another kind, or older,
  pre-convention files — leave them where they are and do not count them.

- **`<summary>` — a few kebab-case words saying what this document is *about*.**
  `nasa-power-mcp-build`, `eval-harness-slice-2`, `the-cap-that-binned-reviews`. The point is that a
  human scanning the directory can pick the right one without opening any of them, so name the work,
  not the mechanism: `session-to-session` is true of nearly every file there and therefore
  distinguishes nothing.

If the name you land on already exists — whichever kind it is — say so and ask whether to add or
supersede — **never overwrite silently.**

## Stage handoff

1. **Record the artifact** in the agreed location.
2. **Set status:** `done` (ready for the next stage) or `blocked` (open questions from `grilling` remain — do **not** hand off).
3. **Write the record** (format below).
4. The next stage **reads the handoff record + artifact** as its input.

```
from: <stage>          to: <stage>
recorded: <date + time + timezone, read off the machine clock — see Rules>
status: done | blocked
artifact: <path or link>
slice: <which vertical slice this is> (blocked-by: <slices> | none)
frontier: <slices now unblocked and ready to start>
summary: <one line>
inputs-for-next: <what the next stage needs to start>
```

## Session handoff

Same discipline, more context — the reader shares none of yours.

```
from: session <n>      to: session <n+1>
recorded: <date + time + timezone, read off the machine clock — see Rules>
status: done | blocked
focus-next: <the one thing the next session is for>

state: <verified facts — branch, commit, test count, CI, working-tree cleanliness>
       Re-run the commands; never copy these from earlier in your own transcript.

artifacts: <paths/URLs to the plan, review, PR, log — each one opened and confirmed to exist>

traps: <what would waste the next session's first hour>
       Wrong interpreter, tooling that will not load from this directory, a stale
       branch, a gate that must be cleared by hand. Be specific: the command, and
       what a healthy result looks like.

open: <decisions the human still owes, and anything you could not verify>
suggested: <skills/commands the next session should invoke, and any it should NOT>
```

The `traps` field earns its place: the costliest session failures in practice are environmental, not
technical, and they are invisible to a reader who assumes a working setup.

## Rules
- **Stamp it from the machine, never from memory.** Run the clock and paste what it prints:

  ```bash
  date '+%Y-%m-%d %H:%M:%S %Z (%z)'     # -> 2026-09-01 06:18:31 BST (+0100)
  ```

  Do not write the date from your own sense of what day it is. An agent's notion of "today" is
  injected context: it can be stale, and it carries neither a time of day nor a timezone — both of
  which the reader needs, because a handoff may be written from a machine in a different zone from
  the person reading it. Age is the first thing the next reader needs, because every `state` value
  in a handoff decays, and one that cannot be dated cannot be trusted or superseded.
- Never hand off while `status: blocked`.
- The receiving stage or session must confirm it has what it needs; if not → invoke `grilling.md`.
- Keep the record minimal — it is an index/pointer, not a copy of the artifact. Reference specs,
  plans, ADRs, commits and diffs by path or URL; never restate them.
- **Every path you list must exist when you write it.** Open it and confirm. A handoff naming an
  artifact that is not on disk is worse than one naming none, because the next reader trusts it —
  this has happened: a hand-off cited an "audited plan" that did not exist, and the next session
  spent a round discovering that.
- **Redact before writing.** No credentials, tokens, keys, or personal contact details. A handoff
  outlives the session that wrote it and may be read by someone outside the work.
- **Distinguish verified from recalled.** State how each fact was established, or mark it unverified.
  A confident sentence and a checked one look identical to the next reader.
- **Never ship.** Committing, pushing, opening a PR or merging one is not part of any stage — see
  `shipping.md`. Handing off tells the next stage the work is ready; it is not permission to
  publish it. Only the coordinating thread ships, and only after the human answers Q1–Q3.
