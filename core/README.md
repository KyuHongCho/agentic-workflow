# core/ — portable, tool-agnostic Markdown

Everything here is plain Markdown that **any** coding agent can consume. No tool-specific
syntax. Adapters point their tool at these files.

- `roles/` — `plan.md`, `build.md`, `review.md` (what each role does + the artifact it produces)
- `auditors/` — `plan-audit.md`, `build-audit.md`, `review-audit.md` (adversarial criteria)
- `checklists/` — content-quality standards for a given artifact type (e.g. `doc-and-comment-hygiene.md`),
  referenced by roles/auditors that produce or judge that kind of content
- `shared/` — cross-cutting skills every role & auditor invokes:
  - `grilling.md` (mandatory HITL gate)
  - `handoff.md` (passing work across a boundary — stage → stage, and session → session)
  - `shipping.md` (who may commit/push/open a PR — the human's decision, never the loop's)
  - `vertical-slices.md` (how work is cut — the unit every stage works in)
  - `verify.md` (empirical verification — evidence over reasoning)
  - `audit-loop.md` (the role ↔ auditor evaluator-optimizer mechanics)
