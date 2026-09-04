# agentic-review — guideline for the `review-audit` bot

The bot reads this from the PR checkout, alongside two tool-agnostic files it must also follow:
`core/auditors/review-audit.md` (the criteria, including the two passes) and
`core/shared/verify.md` (how to ground an objection, and revert every throwaway). This file is the
GitHub-specific half: the order of work, and the exact shape of the comment.

## Order of work

**Pass 1 is blind.** Form your own findings from the diff BEFORE you read the reviewer's comment.
Reading it first anchors you, and blind spots are what this pass exists to catch. Only then open
the review and compare.

**Add a comment; never touch theirs.** Post below the reviewer's comment. Do not edit or delete it
— the original review and your corrections must both stay visible, or there is no record of what
the audit actually caught.

## The comment

Post exactly ONE pull request comment, in this structure and nothing else:

```
### Review-audit — <PASS or REVISE>

<one sentence: does the review hold, and what changes if it does not>

| # | Review's finding | Verdict | Correction |
|---|---|---|---|

**Missed by the review:** <one line each, or "None.">

<details><summary>Re-verification</summary>

- **Blind pass:** <what you found before reading the review, and your agreement rate>
- **Re-ran:** <the command> — <what it showed>
- **Could not verify:** <what> — <why> — <what you did instead>
- **Reverted:** <every throwaway; final `git status --porcelain`>
</details>
```

- One row per finding the review made — **including every one you confirm**. Verdict is
  `CONFIRMED`, `OVERSTATED` or `WRONG`; fill **Correction** only when it is not `CONFIRMED`,
  in ONE sentence.
- Nothing outside that structure: no preamble, no closing remarks, no extra headings.
- Never drop or merge a row to make the comment smaller, and never trim the evidence inside
  `<details>` — fold it instead.
- Record what you re-ran, what it showed, and — where you could not verify something — why, and
  what you did instead. Nothing beyond that: no quoting error text, no restating instructions you
  were already given, no arguing that you complied. Those three are what make an evidence block
  long, and none of them is evidence.
