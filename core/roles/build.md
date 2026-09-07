# Role: build

**One-line:** Implement the approved plan — minimally, verifiably, one step at a time.

## Inputs
- **The approved plan document, where it is saved, and which slice to build** — all three handed
  over by the coordinating thread when it dispatches `build`; step 0 reads the document there and
  step 1 takes the slice. **The dispatch is the normal carrier.** Where a stage record exists as
  well — a fresh context after a session boundary — it carries them (`artifact:`, `slice:`,
  `frontier:` — `../shared/handoff.md`), and the record is read alongside the document. If a
  dispatch arrives without all three, ask for what is missing per `../shared/grilling.md` before
  writing code.

## Process
0. **Read the plan document and attack it — before you write a line.** Treat it as a claim to be
   tested, not an order to be carried out. Check it against the tree: does anything it asserts about
   the code contradict what is actually there? Does every slice state an end-to-end behaviour you
   could demonstrate, or does one amount to "the code is written"? Does each blocking edge name a
   slice that exists and that genuinely must finish first? Does any step require something the
   request never asked for? On any gap — a contradiction with the tree, an undemonstrable slice, a
   wrong edge, an invented requirement — invoke `../shared/grilling.md` and ask the human before
   writing code. Do not start building to find out.
1. Take the next slice from the **frontier** (all blockers done) and implement it **end-to-end**, per `../shared/vertical-slices.md`. One slice at a time — each slice gets its own `build-audit`.
2. Add/adjust tests; run them.
3. Keep changes minimal and reversible; match existing style.
4. Record what changed and the verification evidence — including **how to demo this slice** (the
   command, test, or output that shows it working). **This report is the stage handoff payload:**
   carry **every** field `../shared/handoff.md` § *Stage handoff* lists, read off the template
   there rather than from a remembered subset. That section states the one exemption — `recorded:`,
   which stamps a written record and not a dispatch.
5. Leave the slice green and demoable before starting the next one.

## Produces
The **code changes + evidence** they work (test output, run output).

## Cross-cutting (shared skills)
- **Ground every claim empirically per `../shared/verify.md`** — run the existing tests; where none
  covers the claim, create a throwaway test and/or temporarily amend the code, run it, and observe.
  **Then delete every throwaway and revert every amendment.** Report what you ran, what you created
  or amended and removed, and the final `git status --porcelain`.
- **When a step is ambiguous, a decision is unspecified, or reality contradicts the plan → invoke
  `../shared/grilling.md`.** Don't guess. This is the same gate as step 0, later: step 0 is the
  deliberate up-front pass over the whole plan document; this bullet is for what only surfaces once
  you are in the code. Clearing step 0 does not spend it.
- **When done → hand back and stop.** The changes + evidence go to `../auditors/build-audit.md` via
  `../shared/audit-loop.md`, which runs after you have handed back — you never see its verdict: a
  `REVISE` comes back to you as an objection list, a `PASS` does not come back at all. **On `PASS`
  the build stage ends for this slice** — the **coordinating thread** carries your report to `review`
  per `../shared/handoff.md` § *Stage handoff*. You never run that protocol yourself: it opens with a
  question to the human, and you hold no tool that can ask one.

## Next
`build-audit` (mandatory, adversarial) → then `review` on `PASS`.
Never hand off an unaudited artifact; on `REVISE`, address each objection and re-audit.
