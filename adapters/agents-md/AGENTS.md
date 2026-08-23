# AGENTS.md — agentic-workflow (universal adapter)

This project uses the **agentic-workflow** system. Any coding agent that reads `AGENTS.md`
— Codex, Cursor, Augment Code, Gemini CLI, and others — should follow it.

## The loop
For any non-trivial task, run **plan → build → review**. Each stage is checked by an adversarial
auditor, and you **must grill the human** whenever anything is unclear.

**The audit is mandatory, not a formality.** After each role produces its artifact, run the matching
auditor (`plan → plan-audit`, `build → build-audit`, `review → review-audit`) before advancing. On
`REVISE`, hand the objection list back to the role **verbatim** and re-audit. Never advance on an
unaudited artifact; never exit `PASS` with an objection still open.

## Follow these portable definitions (single source of truth)
- Planner  — `$AGENTIC_WORKFLOW_HOME/core/roles/plan.md`
- Builder  — `$AGENTIC_WORKFLOW_HOME/core/roles/build.md`
- Reviewer — `$AGENTIC_WORKFLOW_HOME/core/roles/review.md`
- Grilling (mandatory HITL gate) — `$AGENTIC_WORKFLOW_HOME/core/shared/grilling.md`
- Handoff (stage → stage, and session → session) — `$AGENTIC_WORKFLOW_HOME/core/shared/handoff.md`
- Auditors — `$AGENTIC_WORKFLOW_HOME/core/auditors/plan-audit.md` (+ `build-audit.md`, `review-audit.md`)
- Audit loop — `$AGENTIC_WORKFLOW_HOME/core/shared/audit-loop.md`
- Verify (empirical checks) — `$AGENTIC_WORKFLOW_HOME/core/shared/verify.md`

## Enforcement on this tool
This adapter conveys the system as **instructions** (a soft gate): you are *instructed* to grill and
to block while questions are open. Hard, mechanical enforcement (hooks) exists only on tools that
support it — see the Claude Code adapter.
