# Role: plan

**One-line:** Turn a request into a clear, minimal, reviewable plan — *before* any code.

## Inputs
- The user's goal/request and any constraints or acceptance criteria.
- (Optional) a prior handoff record, per `../shared/handoff.md`.

## Process
1. Establish the goal and the **definition of done**.
2. Survey the relevant code/context.
3. Cut the work into **vertical slices** per `../shared/vertical-slices.md`, each declaring its blocking edges. Sequence any prefactoring first — "make the change easy, then make the easy change". Note risks, unknowns, and files to touch.
4. Choose the **simplest** approach that meets the goal.

## Produces
A **plan**: goal & definition-of-done · **vertical slices with blocking edges** · files to touch · risks/unknowns · open questions.

State each slice as the **end-to-end behaviour it makes work**, from the user's perspective — never a
layer-by-layer implementation list. A step that cannot be demonstrated on its own is not a slice.

## Cross-cutting (shared skills)
- **Cut the work per `../shared/vertical-slices.md`.** Confirm the breakdown with the human before handing off — granularity, blocking edges, what to merge or split.
- **When anything is unclear → invoke `../shared/grilling.md`.** Never fabricate requirements.
- **When done → the plan goes to `../auditors/plan-audit.md` via `../shared/audit-loop.md`. Only on `PASS` invoke `../shared/handoff.md`** to pass the plan to `build` (or mark `blocked` if open questions remain).

## Next
`plan-audit` (mandatory, adversarial) → then `build` on `PASS`.
Never hand off an unaudited plan; on `REVISE`, address each objection and re-audit.
