# Google's Antigravity CLI (agy). Sourced by agentbox; see "Agent profiles" in
# README.md.

# No features: Google publishes no dev container feature. Its installer can put
# the binary in any folder, so it goes into the agent's volume: installed once,
# it survives rebuilds, and agy's own updates last.
AGENT_FEATURES=()

# agy has no variable for its config folder: it always uses ~/.gemini. So this
# variable is agentbox's own, and AGENT_RUN links ~/.gemini into the volume.
AGENT_ENV=AGENTBOX_ANTIGRAVITY_HOME

# No history sharing: agy keeps its conversations under ~/.gemini, not filed by
# project path.

# How to start it: a sh -c script, with the agent's arguments in "$@".
# A ~/.gemini the image already has as a real folder is left alone; agy then
# works, but its login and settings don't outlast the container.
AGENT_RUN='
home=$AGENTBOX_ANTIGRAVITY_HOME
agy=$home/bin/agy
if [ ! -x "$agy" ]; then
  echo "agentbox: installing the Antigravity CLI in $home" >&2
  curl -fsSL https://antigravity.google/cli/install.sh | bash -s -- --dir "$home/bin" || exit 1
fi
mkdir -p "$home/gemini"
if [ -L "$HOME/.gemini" ] || [ ! -e "$HOME/.gemini" ]; then
  ln -sfn "$home/gemini" "$HOME/.gemini"
else
  echo "agentbox: $HOME/.gemini is a folder of the image, so agy keeps its login there, not in $home" >&2
fi
exec "$agy" "$@"'
