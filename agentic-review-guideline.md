# agentic-review — guideline for the `review` bot

The bot reads this from the PR checkout, alongside two tool-agnostic files it must also follow:
`core/roles/review.md` (what to produce) and `core/shared/verify.md` (how to ground a finding, and
revert every throwaway). This file is the GitHub-specific half: where each finding goes, and the
exact shape of the comment.

## Where each finding goes

**On a changed line → inline.** Use `mcp__github_inline_comment__create_inline_comment` with
`confirmed: true`, one call per finding, giving before/after code and why it matters. Inline
threads carry GitHub's "Resolve conversation" button, which is the point — a plain PR comment
cannot be ticked off.

**Not on a changed line → the summary comment.** The PR description, a missing test, a whole file,
or a claim you could not ground. Do not stretch a finding onto a nearby line to make it fit.

**If an inline call fails**, move that finding to the summary comment and say so. Never let a
failed inline call cost you the review.

## The summary comment

Post exactly ONE pull request comment, in this structure and nothing else:

```
### Review — <PASS or CHANGES REQUESTED>

<one sentence: what this PR does, and whether it is sound>

**Findings** — <N> inline, <M> here

| # | Where | Finding |
|---|---|---|

<details><summary>Verification</summary>

- **Ran:** <the command> — <what it showed>
- **Could not verify:** <what> — <why> — <what you did instead>
- **Reverted:** <every throwaway; final `git status --porcelain`>
</details>
```

- One table row per finding that could not go inline. `path:line` in **Where**; ONE sentence in
  **Finding**, saying what is wrong and why it matters. Append ` (unverified)` to any finding you
  could not ground.
- Write `None.` in place of the table when every finding went inline.
- Nothing outside that structure: no preamble, no restatement of the diff, no closing remarks, no
  extra headings.
- Never drop, merge or shorten a finding to make the comment smaller. The table has no length
  limit, and the evidence inside `<details>` has none either — fold it, never trim it.
- Record what you ran, what it showed, and — where you could not verify something — why, and what
  you did instead. Nothing beyond that: no quoting error text, no restating instructions you were
  already given, no arguing that you complied. Those three are what make an evidence block long,
  and none of them is evidence.
