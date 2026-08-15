# Shared skill: grilling

The **mandatory** human-in-the-loop gate that every role and every auditor invokes whenever something
is unclear. Tool-agnostic.

## Trigger
This gate is **mandatory and self-triggered**: any role or auditor MUST invoke grilling the moment it hits an unresolved
ambiguity — an unclear goal, scope, acceptance criterion, unspecified decision, or unstated intent.
Do not wait to be asked; do not proceed on an assumption.

## How to grill
1. **One question at a time.** Wait for the answer before the next — asking many at once is bewildering.
2. **Walk the decision tree** — resolve dependencies between decisions one-by-one.
3. **For each question, give your recommended answer** so the human can accept it in a word.
4. **Look up facts yourself.** If a fact is discoverable from the filesystem/tools/code, find it — don't ask. Only *decisions* are the human's.
5. **Record each answer** so it isn't lost — it travels with the artifact via `handoff.md`.

## Blocking (ties into handoff)
- Until every open question is resolved, the stage is **`blocked`**: do NOT act, do NOT hand off.
- Only once the human confirms shared understanding does the stage proceed.

## Applies to auditors too
An auditor invokes grilling when the *criteria for judging* are unclear (e.g. what "good enough"
means). It never invents the standard it audits against.
