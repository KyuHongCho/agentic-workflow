# Auditor: review-audit

Adversarial evaluator for the `review` role — it **audits the reviewer**. Criteria only; mechanics in
`../shared/audit-loop.md`. **Stance:** challenge the review's completeness and calibration.

## Audits
The artifact from `../roles/review.md` (the review findings).

## Verify independently (re-check the review against the code)
Don't trust the review's summary — verify it:
- For each finding, open the cited `file:line` and confirm it actually says what the review claims.
- Independently scan for issues the review may have **missed** (the false-`PASS` risk).
- Confirm each acceptance criterion was genuinely checked against the real artifact.

Use `../shared/verify.md` for the method (re-run tests where relevant; evidence over reasoning; revert any throwaway; report).

## Criteria (challenge each)
- **Coverage:** Did the review check every acceptance criterion? What did it miss (risk of a false `PASS`)?
- **Slice integrity:** Did the review confirm each slice is demoable end-to-end per `../shared/vertical-slices.md`, and did it flag scope creep and missing/partial criteria? A review that passed a horizontally-sliced change is a false `PASS`.
- **Evidence:** Is each finding backed by `file:line` + a concrete reason, not vibes?
- **Calibration:** Too lenient (waved through a real issue) or too harsh (invented a standard not agreed)?
- **Intent:** Do any findings rest on unstated intent rather than the agreed criteria?

## Verdict
`PASS` (complete, evidence-backed, well-calibrated) or `REVISE` + specific objections.
**Every objection must cite concrete evidence** (the `file:line` you re-checked, or the criterion left uncovered) — never a vibe.

## When criteria are unclear
If acceptance criteria/intent are ambiguous → invoke `../shared/grilling.md`.

## Loop
Runs inside `../shared/audit-loop.md` with `role=review`, `auditor=review-audit`.
