# Shared skill: verify (empirical verification)

How to establish a **fact** by evidence, not reasoning. Invoked by **every role and every auditor**
— as `vertical-slices.md:4` and `core/README.md:8` already state. Tool-agnostic. Distinct from
`grilling.md`, which resolves *decisions* with the human — this resolves *facts* against reality.

## Be objective
Judge on evidence alone. Do not defer to the producer, to a previous decision, or to your own earlier
opinion. A claim is **unverified until reality confirms it**.

## How to verify
1. **Evidence over reasoning** — reproduce the claim; don't infer it.
2. If the claim is about **behaviour**: run the relevant existing tests and read the output.
   **If no test covers it, create a throwaway test — and/or temporarily amend the code — run it, and
   observe.** This applies where you can write to the tree — the local `build ↔ build-audit` loop.
   A reviewer running in CI **reads and reports; it does not reproduce**.
3. If the claim is about **the codebase** (a file/util exists, a path is right): read/search the real
   source; don't take the artifact's word. In CI the PR's merge ref is **already checked out** — read
   the working tree; do not re-fetch the diff by another route.
4. If the claim is about **a third party** (another tool's behaviour, an external document): cite the
   source and mark it **unverified**. One lookup at most, never a search. Chasing an external fact is
   how a run exhausts its turn budget and reports nothing.

## Clean up (always)
- **Delete every throwaway test** you created.
- **Revert every temporary code amendment** to its original state.
- Leave the working tree exactly as found — except the artifact under audit.

## Report
State what you did: which tests you ran, any throwaway test/amendment you made and removed, and the
evidence (`file:line`, command + output) behind each finding.
