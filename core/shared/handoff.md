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
**Default to outside the repository** — the OS temp directory, or a gitignored path. A handoff
describes internal process; a tracked `handoffs/` directory publishes it to anyone who clones the
repo. Write inside the repo only when it is private *and* that has been agreed.

## Stage handoff

1. **Record the artifact** in the agreed location.
2. **Set status:** `done` (ready for the next stage) or `blocked` (open questions from `grilling` remain — do **not** hand off).
3. **Write the record** (format below).
4. The next stage **reads the handoff record + artifact** as its input.

```
from: <stage>          to: <stage>
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
