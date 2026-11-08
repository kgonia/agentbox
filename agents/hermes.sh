# Nous Research's Hermes Agent. Sourced by agentbox; see "Agent profiles" in
# README.md.

# No features: Nous publishes no dev container feature. Its installer puts
# Hermes, with its own Python, Node, ripgrep and ffmpeg, inside HERMES_HOME,
# which is the agent's volume, so it's installed once (about 2.5 GB), survives
# rebuilds, and `hermes update` can update it.
AGENT_FEATURES=()

# The variable that points it at its config folder, the agent's volume.
AGENT_ENV=HERMES_HOME

# No history sharing: Hermes keeps its sessions in a SQLite database, which
# shouldn't be shared between the host and a container.

# How to start it: a sh -c script, with the agent's arguments in "$@".
# The browser tools are left out: their Chromium needs system libraries that
# dev container images rarely have. So is computer use, which drives a desktop.
# UV_MANAGED_PYTHON: the installer would otherwise take a system Python of the
# version it wants, and a partial one (python3-minimal, which packages such as
# the Claude feature's pull in) has no http module and breaks the install.
AGENT_RUN='
hermes=$HERMES_HOME/hermes-agent/.hermes/bin/hermes
if [ ! -x "$hermes" ]; then
  echo "agentbox: installing Hermes Agent in $HERMES_HOME (a few minutes)" >&2
  curl -fsSL https://hermes-agent.nousresearch.com/install.sh | UV_MANAGED_PYTHON=1 \
    bash -s -- --non-interactive --skip-browser --skip-computer-use || exit 1
fi
exec "$hermes" "$@"'
