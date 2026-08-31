# adapters/ — thin per-tool glue

Each adapter wires **one** tool into the portable `core/`. An adapter carries **no logic** —
it just points its tool at `core/`.

- `agents-md/` — a single **`AGENTS.md`** → the near-universal standard: **Codex, Cursor, Augment Code**, and many more read it natively. Conveys the system as **instructions** (soft gate).
- `claude-code/` — `CLAUDE.md` + `.claude/agents/` subagents + hooks → adds **hard-enforced** gates (the one tool that gives more than instructions). See [`claude-code/README.md`](claude-code/README.md).
- Gemini CLI needs **no adapter of its own**: its default context file is `GEMINI.md` and it does **not** read `AGENTS.md`, so the install points a second symlink at the *same* `agents-md/AGENTS.md`. A symlink, not an `@./AGENTS.md` import — see the note below.

**Enforcement strength varies by tool; the logic is identical everywhere** (one core, many adapters).
`AGENTS.md` is stewarded by the Agentic AI Foundation (Linux Foundation); see https://agents.md/.

## Install into a repo

```bash
# Any AGENTS.md-native tool (Codex, Cursor, …)
ln -s "$AGENTIC_WORKFLOW_HOME/adapters/agents-md/AGENTS.md" AGENTS.md

# Gemini CLI — it reads GEMINI.md, not AGENTS.md. Point it at the SAME file.
ln -s "$AGENTIC_WORKFLOW_HOME/adapters/agents-md/AGENTS.md" GEMINI.md
```

Claude Code needs more than a file; see [`claude-code/README.md`](claude-code/README.md).

> **Why a second symlink and not `@./AGENTS.md`.** Verified by calling Gemini CLI's own
> `readGeminiMdFiles` from `@google/gemini-cli-core` v0.50.0, v0.51.0 and v0.57.0: from **v0.51.0**
> the import processor canonicalises every import on disk (`validateImportPath` →
> `resolveToRealPath`) and rejects any whose real file lies outside the project root. The install
> above symlinks `AGENTS.md` into *this* repo, so an `@./AGENTS.md` import loaded
> `<!-- Import failed: ./AGENTS.md - Path traversal attempt -->` — 61 bytes — in place of the
> rules, silently. Pointing `GEMINI.md` at the file directly carries no import, so nothing is
> validated: the whole file loads on every version tested — 1743 bytes, which the loader reports
> as 1705 characters because 19 of them are non-ASCII. A symlink *committed to this repo* would
> have the same effect on Unix but degrade to a plain file holding a path string on any
> `core.symlinks=false` checkout, so the symlink is made at install time instead. See the
> [GEMINI.md docs](https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/gemini-md.md)
> and [google-gemini/gemini-cli#28233](https://github.com/google-gemini/gemini-cli/pull/28233).
