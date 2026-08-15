# Role: review

**One-line:** Independently check the implementation against the plan and standards.

## Inputs
- The changes + evidence, and the original plan (received via `../shared/handoff.md`).

## Process
1. Check: correctness, plan-adherence, whether the tests actually verify the behaviour, simplicity, safety.
2. Check **slice integrity** per `../shared/vertical-slices.md`: did each slice land end-to-end and is it demoable on its own? Flag missing/partial acceptance criteria, and scope creep (behaviour in the diff the slice never asked for).
3. Produce findings: **PASS**, or a list of concrete issues — each with `file:line` evidence and why it matters.

## Produces
**Review findings:** PASS/FAIL + issues (each with location + reason).

## Cross-cutting (shared skills)
- **When acceptance criteria or intended behaviour are unclear → invoke `../shared/grilling.md`.**
- **When done → the findings go to `../auditors/review-audit.md` via `../shared/audit-loop.md`. Only on `PASS` invoke `../shared/handoff.md`** to return findings to the human (and to `build` for fixes if FAIL).

## Next
`review-audit` (mandatory, adversarial) → then the human on `PASS` (and `build` on FAIL).
Never return unaudited findings; on `REVISE`, address each objection and re-audit.
