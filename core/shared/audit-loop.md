# Shared skill: audit-loop (evaluator-optimizer)

The loop **mechanics** every `role ↔ auditor` pair uses. Parameterized — it injects the matching
auditor's tailored criteria; it holds **no** role-specific checks itself. Tool-agnostic.

## Parameters
- `role` — the producing role (`plan` | `build` | `review`)
- `auditor` — the matching criteria at `../auditors/<role>-audit.md`
- `max_revise_cycles` — safety cap on revise rounds; default **3** (a stage may override)
- `artifact` — what the role produced

## Granularity — one loop per slice
`build ↔ build-audit` runs **once per vertical slice** (see `vertical-slices.md`), not once per plan.
Each slice is audited the moment it lands, while it is still demoable in isolation. Auditing only
after every slice has landed cannot tell you *which* slice broke — that is horizontal slicing
re-entering through the audit door.

`plan ↔ plan-audit` runs once on the plan (it audits the slicing itself). `review ↔ review-audit`
runs once at the end.

## Protocol
1. The `role` produces its artifact.
2. Invoke the `auditor` **adversarially** against the artifact (it grounds every objection via `verify.md`) →
   verdict: `PASS`, or `REVISE` + a **structured objection list** (each objection: *what's wrong · the evidence · what would resolve it*).
3. `PASS` → done → proceed to `handoff.md`.
4. `REVISE` → **deliver the objection list to the `role` as explicit input** (never just "try again"). The role revises by
   **addressing each objection** — not starting over — and produces a new version → return to step 2, where the auditor
   first **confirms each prior objection is actually resolved** (via `verify.md`) before looking for new ones.
5. If an objection depends on unclear intent/criteria → invoke `grilling.md` (don't guess the standard).

## Termination (safety valve — never silently accept)
- **Escalate to the human immediately** (via `grilling.md`) the moment the role stops making progress —
  the same objection recurs, or it cannot satisfy the auditor.
- Escalate at the latest after `max_revise_cycles` rounds without `PASS`.
- **Never** exit `PASS` on an unresolved objection, and **never** accept merely by exhausting the cap.

## Rules
- The auditor supplies the **criteria** (grounded via `verify.md`); this loop supplies only the **mechanics**.
- Record each round (objections + revision) so the reasoning is auditable — it travels via `handoff.md`.
- The **objection list is the hand-back payload** from auditor → role on every `REVISE`; never discard it. When escalating to the human, deliver the **full objection history**.
