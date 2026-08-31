# Agentic Workflow (generic · tool-agnostic)

[![CI](https://github.com/KyuHongCho/agentic-workflow/actions/workflows/ci.yml/badge.svg)](https://github.com/KyuHongCho/agentic-workflow/actions/workflows/ci.yml)

A personal, tool-agnostic system for a **human-in-the-loop, adversarially-audited**
`plan → build → review` loop. Names are deliberately generic (no employer terms).

## Architecture — portable core + thin adapters + MCP

- **`core/`** — Portable **Markdown**: role definitions, auditor criteria, the grilling
  protocol, checklists. **Tool-agnostic** — any coding agent can read it.
- **`adapters/`** — Thin per-tool glue that points one tool at `core/` (no logic of its own):
  - `agents-md/` — one `AGENTS.md` → Codex, Cursor and others read it natively (soft gate: instruction, not a mechanical block)
  - `claude-code/` — `CLAUDE.md` + `.claude/skills/` + subagents + hooks (hard-enforced gates — the one tool offering more than instructions)
  - Gemini CLI — no adapter of its own: a `GEMINI.md` symlink to the same `agents-md/AGENTS.md`, since it does not read `AGENTS.md` by default
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

Adapters must still be **installed at the project root** — the directory the tool is started in. A
missing install fails **silently and open**. Per-adapter install steps:
[`adapters/claude-code/`](adapters/claude-code/README.md) · [`adapters/README.md`](adapters/README.md).

Ultimately the Claude Code adapter can ship as a plugin (`${CLAUDE_PLUGIN_ROOT}`), removing even this env var.

### Automated PR review (optional)

`.github/workflows/agentic-review.yml` runs `review → review-audit` on every PR, and on a
`/agentic-review` comment. It needs two things, and **does nothing — silently, and green — without them**:

```bash
# From `claude setup-token`. Uses your Claude subscription instead of API billing.
# Paste at gh's own prompt — do NOT use `-b/--body`, which writes the token to your
# shell history and exposes it in `ps` while the command runs.
gh secret set CLAUDE_CODE_OAUTH_TOKEN

gh label create "Review ongoing"  -c FBCA04
gh label create "Audit ongoing"   -c 1D76DB
gh label create "Review finished" -c 0E8A16
```

Actions minutes are free on public repos with standard runners.

## Contributing

This is a personal repository demonstrating my own `plan → build → review` workflow, so **I'm not
accepting external pull requests.** You're welcome to fork it and reuse it under the MIT licence, and
issues are welcome if something is wrong or unclear.

Every change here — including my own — goes through a pull request with green CI. `main` is
protected with `enforce_admins`, so direct pushes are rejected even for me.

## Status
Scaffold only (Module 0). Built step-by-step.
