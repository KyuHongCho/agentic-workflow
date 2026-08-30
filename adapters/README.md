# adapters/ — thin per-tool glue

Each adapter wires **one** tool into the portable `core/`. An adapter carries **no logic** —
it just points its tool at `core/`.

- `agents-md/` — a single **`AGENTS.md`** → the near-universal standard: **Codex, Cursor, Augment Code**, and many more read it natively. Conveys the system as **instructions** (soft gate).
- `claude-code/` — `CLAUDE.md` + `.claude/agents/` subagents + hooks → adds **hard-enforced** gates (the one tool that gives more than instructions). See [`claude-code/README.md`](claude-code/README.md).
- `gemini/` — a one-line `GEMINI.md` (`@./AGENTS.md`). Gemini CLI's default context file is `GEMINI.md`; it does **not** read `AGENTS.md` unless pointed there.

**Enforcement strength varies by tool; the logic is identical everywhere** (one core, many adapters).
`AGENTS.md` is stewarded by the Agentic AI Foundation (Linux Foundation); see https://agents.md/.

## Install into a repo

```bash
# Any AGENTS.md-native tool (Codex, Cursor, …)
ln -s "$AGENTIC_WORKFLOW_HOME/adapters/agents-md/AGENTS.md" AGENTS.md

# Gemini CLI — additionally, so it picks AGENTS.md up
ln -s "$AGENTIC_WORKFLOW_HOME/adapters/gemini/GEMINI.md"    GEMINI.md
```

Claude Code needs more than a file; see [`claude-code/README.md`](claude-code/README.md).

> The `gemini/` adapter is written from Gemini CLI's documented `@file.md` import syntax and its
> `GEMINI.md` default, and mirrors the pattern used by
> [obra/superpowers](https://github.com/obra/superpowers). It has **not** been verified against a
> running Gemini CLI. See the
> [GEMINI.md docs](https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/gemini-md.md).
