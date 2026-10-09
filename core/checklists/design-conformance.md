# Checklist: design-conformance

Whether a change follows the target repo's `DESIGN.md`. Tool-agnostic.
Invoked by every role and auditor; § *How each role uses this* says how.

## Trigger
Read and classify (below) applies whenever the target repo has a `DESIGN.md` at its root.
Tiers 1-3 apply only if the work **also** changes anything a user sees or uses: components, pages, styles,
design tokens, markup, icons, static assets, user-facing strings, or `DESIGN.md` itself.
A change to `DESIGN.md` alone counts.
A `DESIGN.md` anywhere else does not trigger this.
With no root `DESIGN.md`, write `design-conformance: n/a` once and stop.

## Read and classify
- Read `DESIGN.md` **in full** before planning, building or judging, every slice, every run:
  a section you skipped is a rule you cannot check.
- State the classification: `design: §<n>, §<m>`
  (the sections the work touches; the heading where a section is unnumbered) or `design: none — <reason>`.
  `plan` states it per slice; every later stage re-derives it from the diff,
  and a disagreement is a finding.
  With `design: none`, stop there: no Tier 1-3 work and no rule-walk entry.

## Tier 1 — guard tests
Run every test `DESIGN.md` names as its guard; a failure is a violation.
They are a floor: a hand-written card shadow passes them, so Tier 2 is never skipped.
Read-only CI cannot run them: say so once under **Could not verify** and do not re-report it per rule.

## Tier 2 — rule walk
For every rule in the classified sections, record one of: **met** (`file:line`),
**violated** (`file:line`, the verbatim line, the rule quoted), or **n/a** (why).
A rule you could not check is **unverified**, never met.
Scope: every line the work adds or changes, plus any unchanged element whose rendering the change alters;
a pre-existing violation elsewhere is not a finding.
Every violation blocks: `REVISE` from an auditor, a non-nit finding that makes a review CHANGES REQUESTED.

## Tier 3 — questions and amendments
When `DESIGN.md` is silent on what the work needs, contradicts itself, reads two ways, or should change,
invoke `../shared/grilling.md`: one question, with the amendment wording you recommend.
Never edit `DESIGN.md` without the human's yes;
an approved amendment lands in the same slice as the code it governs.
In CI there is no human: post a `(design question)` finding with the recommended answer.
It blocks like a violation, and is settled only by a change in the PR — to `DESIGN.md`,
or to the code so the question no longer arises; a reply in a comment does not settle it.

## In a CI comment
Evidence: `read DESIGN.md — design: §<n>, §<m>` (or `design: none — <reason>`)
and, unless the classification is `design: none`, `rule walk — <n> met, <n> violated, <n> n/a, <n> unverified`.
A review prints each as a `**Ran:**` entry.
An audit prints them on its `**Blind pass:**` line, as its own Pass 1 result, not the review's.
Each violation and design question is a finding; the per-rule list is not printed.

## How each role uses this
- **`plan`**: read, classify every slice, and raise Tier 3 questions before handing back.
- **`plan-audit`**: re-derive each slice's classification; an unclassified slice,
  or a design question the plan assumed away, is `REVISE`.
- **`build`**: read in step 0, before any code; write to the rules; run Tier 1
  and walk Tier 2 on your own diff before handing back; grill on Tier 3 rather than guess.
- **`build-audit`**: run Tier 1 yourself, re-derive the classification from the diff,
  walk Tier 2 independently.
- **`review`**: all three tiers on the diff, rendering the changed screen per `../roles/review.md` step 3.
  In CI, print the § *In a CI comment* entries under **Ran:**.
- **`review-audit`**: classify and walk Tier 2 in Pass 1, before reading the review.
  A violation or design question the review missed, or one it marked a nit,
  goes under **Missed by the review** and makes the audit `REVISE`.
  In CI, print the § *In a CI comment* items on the **Blind pass:** line,
  as your own classification and count, not the review's.

## Loop
No new loop — findings here are ordinary objections inside `../shared/audit-loop.md`.
