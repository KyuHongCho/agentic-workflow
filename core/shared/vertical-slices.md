# Shared skill: vertical-slices

How work is **cut** — the unit every role plans, builds, reviews, and audits against.
Tool-agnostic. Invoked by every role and auditor, like `grilling.md` and `verify.md`.

## The rule

<vertical-slice-rules>

- Each slice cuts a narrow but COMPLETE path through every layer (schema, API, UI, tests) — vertical, NOT a horizontal slice of one layer
- A completed slice is demoable or verifiable on its own
- Each slice is sized to fit in a single fresh context window
- Any prefactoring should be done first

</vertical-slice-rules>

Each slice declares its **blocking edges** — the slices that must finish before it can start. A slice
with no blockers can start immediately. The **frontier** is every slice whose blockers are all done;
work the frontier, one slice per fresh context.

## Definition of done for a slice
A slice is done when it can be **demonstrated without narration** — a command to run, a test that
passes, an output to look at. "The code is written" is not done.

## The anti-pattern this exists to prevent
**Horizontal slicing** — shipping one layer at a time (all the schema, then all the API), so nothing
works until every layer lands. The tell: no single step can be demonstrated to the human; "done" is
observable only at the end, and a defect introduced in step 1 is not discovered until step 5.

## The exception: wide refactors
A **wide refactor** is one mechanical change — rename a column, retype a shared symbol — whose
**blast radius** fans across the codebase, so a single edit breaks thousands of call sites at once
and no vertical slice can land green. Don't force it into a slice. Sequence it
**expand → migrate → contract**: expand (add the new form beside the old so nothing breaks), migrate
(move call sites in batches sized by blast radius, one slice per batch, staying green because the old
form still exists), contract (delete the old form once no caller remains, blocked by every batch).

This is the **only** sanctioned deviation. Any other reason to abandon vertical slicing is a
`grilling.md` question, not a judgement call.
