# claude-code adapter — install

The hooks themselves need no env var — but `AGENTIC_WORKFLOW_HOME` must be set before you run the
install below, because every symlink is built from it, and an unset one silently produces five broken
links (`ln -s` never checks its target). The adapter must also be **installed at the project root**: the
directory Claude Code is started in. A repo's own `.claude/` is inert unless that repo *is* the project
root, and a missing install fails **silently and open** — no hooks, no warning, while `CLAUDE.md` still
loads. You get the rules without the enforcement.

```bash
cd /path/to/project-root        # the directory you start Claude Code in
ADP="$AGENTIC_WORKFLOW_HOME/adapters/claude-code"
if [ ! -d "$ADP" ]; then
  echo "STOP: AGENTIC_WORKFLOW_HOME is unset or wrong — [$AGENTIC_WORKFLOW_HOME]"
else
  mkdir -p .claude
  ln -s "$ADP/.claude/settings.json" .claude/settings.json
  ln -s "$ADP/.claude/hooks"         .claude/hooks
  ln -s "$ADP/.claude/skills"        .claude/skills
  ln -s "$ADP/agents"                .claude/agents    # agents sits BESIDE .claude, not inside it
  ln -s "$ADP/CLAUDE.md"             CLAUDE.local.md
  [ -d .git ] && printf '.claude/\nCLAUDE.local.md\n.gate\n.gate-asked\n.audit-pending\n.agentic/\n' >> .git/info/exclude
  bash .claude/hooks/ship-gate.selftest.sh    # expect ALL PASS (15/15)
  bash .claude/hooks/gate-check.selftest.sh   # expect ALL PASS (70/70)
  bash .claude/hooks/audit-gate.selftest.sh   # expect ALL PASS (76/76)
fi
```

Each selftest ends with a wiring case that turns red when a script `settings.json` registers (or `session-state.sh`) is missing, a broken symlink, or fails `bash -n`, or when `session-state.sh` does not end with its `AGENTIC_SS_LOADED=1` line.
It checks this repo's own `settings.json` and scripts, and cannot detect a Claude Code started from a directory whose `.claude/settings.json` is not this one, where no hook is registered at all.

An install made before per-session state lacks `.agentic/` in its exclude list, so `git add -A` could stage ledgers and gates.
From the project root, add it once with `grep -qxF '.agentic/' .git/info/exclude || echo '.agentic/' >> .git/info/exclude` (it appends only once).

Keep `.claude/` a **real directory** with symlinks inside, as above. Symlinking `.claude` itself sends
Claude Code's per-project writes (e.g. `worktrees/`) into this repo.

Opening a parent directory that holds several repos? Install at that parent instead: one install then
gates every repo beneath it, because the gate reads only the command, not the working directory.

The self-tests prove the scripts work — **not** that they are wired. It cannot see how Claude
Code was launched. If the gate seems silent, check that `.claude/settings.json` exists in the directory
you started in.

## Stale state

Each session keeps its audit ledger and grilling gate under `.agentic/<session_id>/`.
`/clear` and `--fork-session` start a new session id and leave the old id's folder behind.
A `SessionStart` hook (`session-start-warn.sh`, registered by the same `settings.json`) prints one line at `startup`, `clear` and `resume` when another session's folder holds audit debt or a blocked gate, or the legacy `.audit-pending` or `.gate` do.
It cannot tell a finished session from one running now, so check before clearing anything.
It only warns: it never blocks, moves, adopts or deletes anything.
List what is owed with `$AGENTIC_WORKFLOW_HOME/adapters/claude-code/bin/audit-clear`, and what is blocked with `.../bin/unblock`; both show an age for each entry.
Remove folders that hold nothing with `bin/audit-clear --prune [days]` (default 14, at most 99999).
Prune refuses when `.agentic` is itself a symlink.
Prune deletes only a folder with an empty or absent ledger, no blocked gate, and no change for at least that many days.
It never touches a folder with debt or a blocked gate, nor the legacy files, and nothing prunes automatically.
