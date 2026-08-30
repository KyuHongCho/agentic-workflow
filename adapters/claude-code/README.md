# claude-code adapter — install

No env var is needed for the hooks — but the adapter must be **installed at the project root**: the
directory Claude Code is started in. A repo's own `.claude/` is inert unless that repo *is* the project
root, and a missing install fails **silently and open** — no hooks, no warning, while `CLAUDE.md` still
loads. You get the rules without the enforcement.

```bash
cd /path/to/project-root        # the directory you start Claude Code in
mkdir -p .claude
ADP="$AGENTIC_WORKFLOW_HOME/adapters/claude-code"
ln -s "$ADP/.claude/settings.json" .claude/settings.json
ln -s "$ADP/.claude/hooks"         .claude/hooks
ln -s "$ADP/.claude/skills"        .claude/skills
ln -s "$ADP/agents"                .claude/agents      # agents sits BESIDE .claude, not inside it
ln -s "$ADP/CLAUDE.md"             CLAUDE.local.md
printf '.claude/\nCLAUDE.local.md\n.gate\n.audit-pending\n' >> .git/info/exclude
bash .claude/hooks/ship-gate.selftest.sh      # expect ALL PASS (14/14)
```

Keep `.claude/` a **real directory** with symlinks inside, as above. Symlinking `.claude` itself sends
Claude Code's per-project writes (e.g. `worktrees/`) into this repo.

Opening a parent directory that holds several repos? Install at that parent instead: one install then
gates every repo beneath it, because the gate reads only the command, not the working directory.

`ship-gate.selftest.sh` proves the script works — **not** that it is wired. It cannot see how Claude
Code was launched. If the gate seems silent, check that `.claude/settings.json` exists in the directory
you started in.
