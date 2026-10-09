# Auditor: review-audit

Adversarial evaluator for the `review` role — it **audits the reviewer**.
Criteria only; mechanics in `../shared/audit-loop.md`.
**Stance:** challenge the review's completeness and calibration.

## Audits
The artifact from `../roles/review.md` (the review findings).

## Pass 1 — judge the change yourself, BEFORE reading the review
Do this first and write it down before you open the review's findings.
Reading them first anchors you to what the reviewer already looked at,
and **blind spots are what this pass exists to catch**.
- Read the diff **and render the actual user-facing output**; judge it as a user would, not as a patch.
  The costliest defects are interactions between a changed line and an unchanged one — invisible in a diff.
- Write your own findings list. This is your independent opinion, formed without the review.

## Pass 2 — now read the review, and compare
- **Report the agreement rate**: how many of your Pass-1 findings the review also had,
  and how many it missed.
  A low rate is the signal that one reviewer was not enough on this change.
- For each of the review's findings, open the cited `file:line`
  and **paste its verbatim text** into your report.
  A citation you cannot paste is unverified: strike the finding,
  or re-derive the correct line with `grep -n`.
  Opening a line is invisible and skippable; pasting it makes a wrong cite obvious.
- Independently scan for anything **both** you and the review may have missed (the false-`PASS` risk).
- Confirm each acceptance criterion was genuinely checked against the real artifact.

Use `../shared/verify.md` for the method
(re-run tests where relevant; evidence over reasoning; revert any throwaway; report).
**Running in CI you are read-only**, per `verify.md` — re-run existing tests and read the tree,
but do not create a test, re-fetch the diff, or chase an external document.
Mark what you could not reproduce as **unverified**; a run that exhausts its turns posts no audit at all.

## Criteria (challenge each)
- **Coverage:** Did the review check every acceptance criterion? What did it miss (risk of a false `PASS`)?
- **Slice integrity:** Did the review confirm each slice is demoable end-to-end per `../shared/vertical-slices.md`, and did it flag scope creep and missing/partial criteria? A review that passed a horizontally-sliced change is a false `PASS`.
- **Evidence:** Is each finding backed by `file:line` + a concrete reason, not vibes? **Is the cited line quoted verbatim?** An unquoted citation is unverified.
- **Calibration:** Too lenient (waved through a real issue) or too harsh (invented a standard not agreed)?
- **Comment hygiene:** Did `review` actually check `../checklists/doc-and-comment-hygiene.md`
  against every changed comment, docstring, or documentation file, or only the ones it happened to notice?
- **Comment budget:** Did `review` flag every added comment or docstring that is over 3 lines
  or not why-only (directives, headers and generated files exempt)?
  Run the checklist's comment-block row in Pass 1
  (diff form, plus the whole-file form on files that gained a comment line);
  one the review missed goes under **Missed by the review** but, being a nit,
  does not by itself make the audit `REVISE`.
- **Design conformance:** Per `../checklists/design-conformance.md` — classify and walk Tier 2 in Pass 1,
  before reading the review.
  A violation or design question the review missed, or marked a nit, goes under **Missed by the review**
  and makes the audit `REVISE`.
  In CI, print the § *In a CI comment* items on the **Blind pass:** line,
  as your own classification and count, not the review's.
- **Intent:** Do any findings rest on unstated intent rather than the agreed criteria?

## Verdict
`PASS` (complete, evidence-backed, well-calibrated) or `REVISE` + specific objections.

**Report it in the shape of the audit comment** — `### Review-audit — <PASS or REVISE>`,
the verdict table with one row per review finding, **Missed by the review**,
and the `Re-verification` block, as in `agentic-review-audit-guideline.md` at the root of this system.
On `PASS` the coordinating thread saves it beside the review as the review record
(`../shared/handoff.md` § *Review record*).
Where Pass 1 could not be blind — you were handed the review before judging the change —
say so under **Blind pass**; never report an agreement rate you did not measure.
**Every objection must cite concrete evidence**
(the `file:line` you re-checked, or the criterion left uncovered) — never a vibe.

## When criteria are unclear
If acceptance criteria/intent are ambiguous → invoke `../shared/grilling.md`.

## Loop
Runs inside `../shared/audit-loop.md` with `role=review`, `auditor=review-audit`.
