# Claude Code. Sourced by agentbox; see "Agent profiles" in README.md.

# Dev container features that install it. Node is listed because the Claude
# feature's own Node fallback fails on current Ubuntu images; options a project
# sets for Node still win.
AGENT_FEATURES=(ghcr.io/devcontainers/features/node:1 ghcr.io/anthropics/devcontainer-features/claude-code:1)

# The variable that points it at its config folder, the agent's volume.
AGENT_ENV=CLAUDE_CONFIG_DIR

# Its history inside that folder, filed by project path, and the host's
# counterpart, for --share-history.
AGENT_HISTORY=projects
AGENT_HOST_HISTORY=${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects

# How to start it: a sh -c script, with the agent's arguments in "$@".
# CLAUDE_CONFIG_DIR hides the skills, commands and agents an image installs in
# ~/.claude; --add-dir loads them. With "=", a prompt right after it isn't
# taken as another folder.
AGENT_RUN='[ -d "$HOME/.claude" ] && set -- --add-dir="$HOME" "$@"; exec claude "$@"'
