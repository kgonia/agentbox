# OpenAI Codex CLI. Sourced by agentbox; see "Agent profiles" in README.md.

# No features: OpenAI publishes no dev container feature. Its installer puts
# Codex inside CODEX_HOME, which is the agent's volume, so it's installed once,
# survives rebuilds, and `codex update` can update it.
AGENT_FEATURES=()

# The variable that points it at its config folder, the agent's volume.
AGENT_ENV=CODEX_HOME

# No history sharing: Codex indexes its sessions in a SQLite database, which
# shouldn't be shared between the host and a container.

# How to start it: a sh -c script, with the agent's arguments in "$@".
# Codex's own Linux sandbox (bubblewrap) can't create namespaces in a Docker
# container, so unless you pass a sandbox flag yourself, it runs with
# --sandbox danger-full-access and the container is the sandbox.
AGENT_RUN='
codex=$CODEX_HOME/packages/standalone/current/bin/codex
if [ ! -x "$codex" ]; then
  echo "agentbox: installing Codex in $CODEX_HOME" >&2
  curl -fsSL https://chatgpt.com/codex/install.sh | sh || exit 1
fi
case " $* " in
  *" -s "* | *" --sandbox"* | *" --dangerously-bypass-approvals-and-sandbox "*) ;;
  *) set -- --sandbox danger-full-access "$@" ;;
esac
exec "$codex" "$@"'
