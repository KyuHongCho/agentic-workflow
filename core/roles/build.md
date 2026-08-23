# Role: build

**One-line:** Implement the approved plan — minimally, verifiably, one step at a time.

## Inputs
- The approved plan (received via `../shared/handoff.md`).

## Process
1. Take the next slice from the **frontier** (all blockers done) and implement it **end-to-end**, per `../shared/vertical-slices.md`. One slice at a time — each slice gets its own `build-audit`.
2. Add/adjust tests; run them.
3. Keep changes minimal and reversible; match existing style.
4. Record what changed and the verification evidence — including **how to demo this slice** (the command, test, or output that shows it working).
5. Leave the slice green and demoable before starting the next one.

## Produces
The **code changes + evidence** they work (test output, run output).

## Cross-cutting (shared skills)
- **Ground every claim empirically per `../shared/verify.md`** — run the existing tests; where none
  covers the claim, create a throwaway test and/or temporarily amend the code, run it, and observe.
  **Then delete every throwaway and revert every amendment.** Report what you ran, what you created
  or amended and removed, and the final `git status --porcelain`.
- **When a step is ambiguous, a decision is unspecified, or reality contradicts the plan → invoke `../shared/grilling.md`.** Don't guess.
- **When done → the changes + evidence go to `../auditors/build-audit.md` via `../shared/audit-loop.md`. Only on `PASS` invoke `../shared/handoff.md`** to pass to `review`.

## Next
`build-audit` (mandatory, adversarial) → then `review` on `PASS`.
Never hand off an unaudited artifact; on `REVISE`, address each objection and re-audit.
