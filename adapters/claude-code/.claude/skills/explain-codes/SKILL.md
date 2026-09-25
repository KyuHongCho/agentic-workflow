---
name: explain-codes
description: Explain a change, file, or feature in plain language for a novice or non-developer reader — verified against the live code, with tables/diagrams and background on the tools involved. Follow core/skills/explain-codes.md. Use when the human runs /explain-codes, or asks in any words to have code/a change/a feature explained, especially for a novice or non-technical reader.
---

# explain-codes

**The procedure is `$AGENTIC_WORKFLOW_HOME/core/skills/explain-codes.md`. Read it and follow it.**
It carries the target-confirmation requirement, the fresh-scan requirement, the per-file/visual/
tool-stack explanation steps, the claim-grounding rules, and the four mandatory closing checks.
Nothing here repeats them.

Four things it cannot know about this tool:

- **Resolve `$AGENTIC_WORKFLOW_HOME` first.** `Read` does not expand it — resolve it with a shell
  command, then use the absolute path.
- **Use `AskUserQuestion` for step 0's target confirmation.** Present the candidates as its options,
  the most likely one labelled "(Recommended)" — never proceed past step 0 on an assumed target,
  even one that looks obvious, unless the human's own request already named it explicitly. Put the
  depth question (line by line marked "(Recommended)") in the same call, and for a whole-repo target
  ask the shape question (feature by feature / architecture map / summary) as a follow-up call.
- **"Whatever the environment provides" (the core file's step 1) means, here:** file search/read
  tools for scanning, a shell for diffs/tests/temporary verification, and a web-fetch tool for
  checking a third-party tool's own docs or package registry when step 5 calls for it. Use them
  directly — there is no separate setup.
- **This is a plain answer in conversation, not a stage in the audit loop.** It carries no handoff
  payload and does not touch `.audit-pending` — nothing here should ever cause the audit gate to
  report a debt. If the target is large enough that a full fresh read would be expensive to keep in
  the main conversation's context, delegating the scan-and-draft to a disposable sub-task is fine —
  but the four closing checks in step 6 of the core procedure must still run, explicitly, on the
  final draft before it's shown to the human.
