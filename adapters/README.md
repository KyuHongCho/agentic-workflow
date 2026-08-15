# adapters/ — thin per-tool glue

Each adapter wires **one** tool into the portable `core/`. An adapter carries **no logic** —
it just points its tool at `core/`.

- `agents-md/` — a single **`AGENTS.md`** → the near-universal standard: **Codex, Cursor, Augment Code, Gemini CLI**, and many more. Conveys the system as **instructions** (soft gate).
- `claude-code/` — `CLAUDE.md` + `.claude/agents/` subagents + hooks → adds **hard-enforced** gates (the one tool that gives more than instructions).

**Enforcement strength varies by tool; the logic is identical everywhere** (one core, many adapters).
`AGENTS.md` is stewarded by the Agentic AI Foundation (Linux Foundation); see https://agents.md/.
