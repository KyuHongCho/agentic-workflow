# Sourced by the hooks, never run. Per-session state lives in <project>/.agentic/<session_id>/.

# $1 = session_id from the hook payload. Prints the session directory, or nothing when the id is
# absent or not [A-Za-z0-9_-]+ -- an id is a path component, so anything else is treated as no id.
sid_dir() {
  case "$1" in ''|*[!A-Za-z0-9_-]*) return 0 ;; esac
  printf '%s' "${CLAUDE_PROJECT_DIR:-$PWD}/.agentic/$1"
}

AGENTIC_SS_LOADED=1   # must stay the final line: reaching it proves every function above was defined
