# Shared skill: handoff

The protocol **every** stage uses to pass work to the next. Tool-agnostic; invoked by every role
and auditor. (Cross-cutting concern — factored out of the roles so it lives in one place.)

## When to invoke
At the end of a stage, once its artifact is produced **and** no open `grilling` questions remain.

## Protocol
1. **Record the artifact** in the agreed location (e.g. `handoffs/<stage>.md`, or the issue tracker).
2. **Set status:** `done` (ready for the next stage) or `blocked` (open questions from `grilling` remain — do **not** hand off).
3. **Write a handoff record** (format below).
4. The next stage **reads the handoff record + artifact** as its input.

## Handoff record (format)
```
from: <stage>          to: <stage>
status: done | blocked
artifact: <path or link>
slice: <which vertical slice this is> (blocked-by: <slices> | none)
frontier: <slices now unblocked and ready to start>
summary: <one line>
inputs-for-next: <what the next stage needs to start>
```

## Rules
- Never hand off while `status: blocked`.
- The receiving stage must confirm it has what it needs; if not → invoke `grilling.md`.
- Keep the record minimal — it is an index/pointer, not a copy of the artifact.
- **Never ship.** Committing, pushing, opening a PR or merging one is not part of any stage — see
  `shipping.md`. Handing off tells the next stage the work is ready; it is not permission to
  publish it. Only the coordinating thread ships, and only after the human answers Q1–Q3.
