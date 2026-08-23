---
name: open-pr
description: Open a pull request whose description follows the repo's PR format, fact-checked and proof-read before submission. Use only after the human has explicitly approved opening a PR (Q3 of shipping.md).
---

# open-pr

**Precondition.** Only run this once the human has answered *yes* to Q3 in
`$AGENTIC_WORKFLOW_HOME/core/shared/shipping.md`. If they said no, produce the description, print
it for copy-paste, and stop — do not open anything.

## Output format — mandatory

Use the repo's own `.github/pull_request_template.md` when one exists. Otherwise use the four
sections below, which is what that template specifies:

    ## What this changes
    The end-to-end behaviour this makes work, from the user's perspective — not a layer-by-layer
    implementation list. Show real before/after output where the change is user-visible.

    ## Why
    The decision, and the alternative you rejected.

    ## Verification
    Commands run and their real output. Where a test guards this change, show that it fails when
    the change is reverted — a test that cannot be made to fail is not evidence.

    ## Risks / follow-ups
    What could go wrong; what you deliberately did not do.

Exactly these four `##` headings, in this order, with no extra top-level sections.

## Fact-check and proof-read before submitting — every time

Do not submit until each of these has been re-established, not recalled:

1. Every command quoted was actually run **in this session**, and its output is pasted verbatim.
2. Every number — test counts, versions, line numbers, file counts — re-read from a live command.
3. Every "X is unchanged" claim backed by `git diff --name-only`.
4. Every URL fetched and confirmed to resolve.
5. Any mutation / negative-control evidence is real output, not a description of it.
6. Proof-read: no stale wording from an earlier draft, and no capability described that does not
   actually ship in this PR.

State in your report which of these you checked and how.

## Then

- **Approved** → `gh pr create --base <base> --head <branch> --title <title> --body-file <file>`.
- **Not approved** → print the finished Markdown for copy-paste, plus that command. Do not run it.

Note: `gh pr create` is gated by `ship-gate.sh`, so it will still surface the human's approval
prompt. That is intentional belt-and-braces, not a bug.
