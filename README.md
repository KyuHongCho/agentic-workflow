# Agentic Workflow (generic · tool-agnostic)

[![CI](https://github.com/KyuHongCho/agentic-workflow/actions/workflows/ci.yml/badge.svg)](https://github.com/KyuHongCho/agentic-workflow/actions/workflows/ci.yml)

A personal, tool-agnostic system for a **human-in-the-loop, adversarially-audited**
`plan → build → review` loop. Names are deliberately generic (no employer terms).

## Architecture — portable core + thin adapters + MCP

- **`core/`** — Portable **Markdown**: role definitions, auditor criteria, the grilling
  protocol, checklists. **Tool-agnostic** — any coding agent can read it.
- **`adapters/`** — Thin per-tool glue that points one tool at `core/` (no logic of its own):
  - `claude-code/` — `CLAUDE.md` + `.claude/skills/` + subagents + hooks (hard-enforced gates)
  - `codex/` — `AGENTS.md` (soft gate: strong instruction, not a mechanical block)
  - `gemini/` — `GEMINI.md` / extension
- **`mcp/`** — MCP servers = executable capabilities that work across MCP-capable tools.

## The loop (generic naming)

```
plan   ↔ plan-audit
build  ↔ build-audit
review ↔ review-audit
```

Each stage is an **evaluator-optimizer** loop (agent ↔ adversarial auditor).
Every agent **and** auditor must **grill the human** when something is unclarified.

## Setup

Adapters locate the portable `core/` via the **`AGENTIC_WORKFLOW_HOME`** environment variable — set it
to this repo's root (no hardcoded machine paths):

```bash
export AGENTIC_WORKFLOW_HOME="/path/to/agentic-workflow"   # add to your shell profile
```

Shell-executed pieces (the Claude Code hook) use the tool-provided `${CLAUDE_PROJECT_DIR}` and need no setup.
Ultimately the Claude Code adapter can ship as a plugin (`${CLAUDE_PLUGIN_ROOT}`), removing even this env var.

## Status
Scaffold only (Module 0). Built step-by-step.
