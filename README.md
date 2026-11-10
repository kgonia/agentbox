# agentbox

Runs a coding agent (Claude Code, Codex or Hermes Agent) inside a project's own
dev container, without editing the project. It works with any `.devcontainer`,
including a team one that knows nothing about agents.

```sh
cd ~/Projects/some-repo
agentbox claude       # build or start the container, run Claude Code in it
agentbox claude -c    # arguments after the agent go to it (here: continue)
agentbox codex        # Codex, in the same container
agentbox hermes       # Hermes Agent, in the same container
agentbox --shell      # a shell in the same container
```

`claudebox` still works and means `agentbox claude`.

## Requirements

- Docker
- Node.js and the [Dev Containers CLI](https://github.com/devcontainers/cli):
  `npm install -g @devcontainers/cli`
- `flock` (util-linux) to stop containers when you're done; without it they
  keep running

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/kgonia/agentbox/main/install.sh | bash
```

This puts the latest release in `~/.local/share/agentbox` and the `agentbox`
and `claudebox` commands in `~/.local/bin`. Running it again updates
agentbox. `agentbox --version` shows which release you have.

- To read the script before running it:
  `curl -fsSLO https://raw.githubusercontent.com/kgonia/agentbox/main/install.sh`,
  then `less install.sh` and `bash install.sh`.
- `curl ... | AGENTBOX_VERSION=v0.1.0 bash` installs a particular release, and
  `AGENTBOX_VERSION=main` the development version. `AGENTBOX_BIN_DIR` puts the
  commands somewhere else.
- To uninstall: `rm -rf ~/.local/share/agentbox ~/.local/bin/agentbox ~/.local/bin/claudebox`.
  The containers and volumes stay until you remove them (see Cleanup).

To work on agentbox, link the commands from a clone instead. The installer
leaves such links alone.

```sh
git clone https://github.com/kgonia/agentbox.git && cd agentbox
ln -s "$PWD/bin/agentbox" ~/.local/bin/agentbox
ln -s "$PWD/bin/claudebox" ~/.local/bin/claudebox   # optional
```

## Usage

```
agentbox [options] AGENT [agent args...]
agentbox [options] --shell [AGENT]

  --rebuild             recreate the container from its definition, then continue
  --shell               open a shell in the container instead of an agent
  --rm                  remove this project's agentbox containers and exit
  --config FILE         use FILE as devcontainer.json
  --share-history       share chat history with the agents on the host (those
                        whose profile supports it); this project keeps sharing
                        until --no-share-history
  --no-share-history    stop sharing chat history for this project
  --keep-running        leave the container running when this session ends
                        (by default the last session to end stops it)
  -y, --yes             answer yes to agentbox's questions
  --version             show agentbox's version
  -h, --help            show this help
```

Options go before the agent's name. Everything after it goes to the agent:
`agentbox claude --help` shows Claude's help.

## Agents

| | Installed | Config folder | Logging in from the container | Shares history |
|---|---|---|---|---|
| `claude` | Claude Code's dev container feature, with Node, when the container is built | `CLAUDE_CONFIG_DIR` = `/claude-config` | Pick the subscription login, open the URL it prints on your host, paste the code back | Yes |
| `codex` | OpenAI's installer, into the volume, on first run | `CODEX_HOME` = `/codex-config` | `agentbox codex login --device-auth` (turn on device code login in ChatGPT's security settings first), or `printenv OPENAI_API_KEY \| agentbox codex login --with-api-key` | No |
| `hermes` | Nous Research's installer, into the volume, on first run (a few minutes, about 2.5 GB) | `HERMES_HOME` = `/hermes-config` | `agentbox hermes setup` or `agentbox hermes model`: providers log in with a device code or an API key | No |

Each agent's config folder is a Docker volume named `<agent>-config`, shared
by every project. It holds the agent's login, settings and history, and for
Codex and Hermes the agent itself, so `codex update` and `hermes update` work
and last. Log in once per agent.

- **Codex** runs with `--sandbox danger-full-access` unless you pass a sandbox
  flag yourself. Its own sandbox (bubblewrap) can't create namespaces in a
  Docker container, so the container is the sandbox. Its usual browser login
  doesn't work, because it redirects to `localhost:1455` on the machine
  running Codex, the container.
- **Hermes** is installed without its browser tools, whose Chromium needs
  system libraries that dev container images rarely have, and without computer
  use, which drives a desktop. `hermes chat` starts a background gateway that
  would finish a turn after you leave, but it stops with the container: use
  `--keep-running` for that.
- **Claude** stays at the version installed when the container's image was
  first built. Its own auto-update fails in the container, and `--rebuild`
  doesn't help, because Docker reuses the cached feature layer.

Codex and Hermes keep their sessions in SQLite databases, which shouldn't be
shared between the host and a container, so `--share-history` covers only
Claude for now.

## One container for all agents

Each project has one container, and every agent you run there uses it. An
agent is added the first time you run it in a project. Agents are part of how
a container is built, so adding one means recreating the container: its
sessions end, and anything installed in it outside the volumes is lost.
agentbox asks before that, and before it starts a plain container where there's
no `.devcontainer`:

```
agentbox: This project's container has to be recreated to add codex. That drops
anything installed in it outside the volumes, and ends the other sessions running
in it. Go ahead? [y/N]
```

`--rebuild` asks only when other sessions are using the container. `--yes`
answers yes to all of these. Without a terminal to ask on, agentbox stops
rather than guess.

## Settings

`~/.config/agentbox/config` is plain shell:

```sh
AGENTBOX_SHARE_HISTORY=yes      # share history in new containers (default: no)
AGENTBOX_VOLUME_PREFIX=work-    # volumes named work-claude-config and so on (default: none)
```

`AGENTBOX_VOLUME_PREFIX` can also be set in the environment, which overrides
the file. History sharing can't: it's controlled by the flags and the file.

## Sharing history with the host

```sh
agentbox --share-history claude      # turn it on for this project
agentbox claude                      # stays on
agentbox --no-share-history claude   # turn it off again
```

With sharing on, `claude --resume` on the host lists the sessions from the
container, and the other way round. Per-project memory is shared too. The
login and settings still come from the volume.

Claude files history by project path, as in
`~/.claude/projects/-home-you-Projects-repo/`. So agentbox:

- mounts the host's `~/.claude/projects` at `/claude-config/projects`;
- also mounts the project's git root at its host path, and starts the agent
  there instead of under `/workspaces`.

A container keeps the mounts it was created with, so each project's container
remembers its mode:

- A flag that changes the mode recreates the container once, after asking.
- Without a flag, an existing container keeps its mode, including through
  `--rebuild`.
- A new container, for example after `agentbox --rm`, takes the default from
  the config file.

Changing the config file doesn't affect existing containers. While sharing is
on, the history stored in the volume is hidden, not deleted.

Only `projects/` is shared, never all of `~/.claude`. That folder also holds
`settings.json` and hooks, which a project's script could change to run
commands on your host.

## What it does

1. **Finds the definition.** Starting in the current folder and walking up,
   it takes the first of `.devcontainer/agentbox/devcontainer.json`,
   `.devcontainer/devcontainer.json` or `.devcontainer.json`. With none, it
   offers `default/devcontainer.json` (plain Ubuntu) for the git root, or the
   current folder outside git.
2. **Runs `devcontainer up` with additions** that leave the project untouched:
   - the features of the container's agents (`--additional-features`).
     Options the project sets for the same features take precedence.
   - each agent's volume at `/<agent>-config`, with the agent's variable
     pointing at it. The mounts also tell agentbox later which agents a
     container has.
   - its own id labels (`agentbox.folder`, `agentbox.config`), so it never
     reuses a container VS Code created for the same folder. That container
     would not have the agents.
   - `--no-lockfile`, so the CLI doesn't write agentbox's features into the
     project's `devcontainer-lock.json`. As a result, a lockfile the project
     has is not checked either.
3. **Gives the volumes to the container's user**, because Docker creates them
   owned by root.
4. **Runs the agent with `devcontainer exec`**, in the same subfolder you are
   in on the host, with your `TERM` and `COLORTERM`.

The first build takes a minute or more. Changes to `devcontainer.json` apply
only after `agentbox --rebuild`. The volumes keep their contents through a
rebuild.

## When the container stops

When the last session in a project's container ends, agentbox stops the
container. Every agent's session counts, and so does `--shell`. Closing the
terminal ends a session too. Stopping is not removing: anything installed in
the container is still there next time.

- The next session starts the container again in a few seconds. The
  project's `postStartCommand` runs again, so with the example's firewall it
  takes longer.
- While one session is open, others can come and go. Each one holds a shared
  lock, and only the last to end stops the container.
- `--keep-running` leaves it running when that session ends, for example when
  an agent started a server you want to keep. The next session that ends
  without the flag, as the last one, stops it.
- Processes left running in the container stop with it.

## Agent profiles

Each agent is a shell file, `agents/<name>.sh`, which agentbox sources. Adding
an agent means adding one. It sets:

- `AGENT_FEATURES`: dev container features that install the agent, as an array
  of ids (they get default options). Leave it empty if `AGENT_RUN` installs
  the agent.
- `AGENT_ENV`: the variable that points the agent at its config folder.
- `AGENT_HISTORY` and `AGENT_HOST_HISTORY` (optional): the history folder
  inside the config folder, filed by project path, and the host's
  counterpart, for `--share-history`.
- `AGENT_RUN`: a `sh -c` script that starts the agent, with its arguments in
  `"$@"`. It can install the agent into its config folder first.

`agents/claude.sh` also passes `--add-dir` with the container user's home
when that home has a `.claude` folder. Without it, Claude wouldn't load the
skills, commands and agents an image installs there, because its config
folder is the volume.

## Cleanup

```sh
agentbox --rebuild ...                                          # recreate from the definition
agentbox --rm                                                   # remove this project's containers
docker rm -f $(docker ps -aq --filter label=agentbox.folder)    # remove every agentbox container
docker volume rm codex-config                                   # forget an agent's login, history and install
```

Containers made by claudebox, before the rename, aren't found by agentbox.
Remove them with
`docker rm -f $(docker ps -aq --filter label=claudebox.folder)`. Claude's
volume is the same, so its login carries over.

## Caveats

- **The project's definition sets the isolation, not agentbox.** If
  `devcontainer.json` mounts the Docker socket, runs privileged or mounts host
  folders, the agents get the same access. Read it before you trust it.
- **All projects share each agent's volume.** Anything that runs in a project's
  container can read the logins and history of its agents. That includes the
  project's own `postCreateCommand` and install scripts, not just the agents.
  For a repo you don't trust, use separate volumes:
  `AGENTBOX_VOLUME_PREFIX=untrusted- agentbox claude`. If projects run as
  users with different UIDs, agentbox re-owns the volumes each time you switch
  between them.
- **Shared history is open to every container.** With sharing on, anything
  running in a project's container can read all of your host chat history,
  including projects that never ran in agentbox. It can also write
  transcripts and memory that the agent on the host loads later. Keep sharing
  off for a repo you don't trust. Sharing also assumes the container's user
  has your UID, which the Dev Containers CLI arranges on Linux. A container
  running as root would leave root-owned files in your history.
- **A firewall can't be added from outside.** It needs `--cap-add=NET_ADMIN`
  and a start command in the definition itself. Write a variant for agents in
  `.devcontainer/agentbox/devcontainer.json`, which agentbox prefers. Build it
  from the same image or Dockerfile as the main one, remembering that relative
  paths are one folder deeper. `example/.devcontainer/agentbox/devcontainer.json`
  is a working example for Claude. It runs the `init-firewall.sh` that the
  Claude Code feature installs, which lets through only what Claude needs, so
  Codex and Hermes can't reach their services from behind it. Version 1.0.5
  of that script stops when a domain on its list no longer resolves
  (`statsig.anthropic.com` doesn't), so the example patches that while running
  it. If the start command fails, run `agentbox --rebuild ...` after fixing
  it. Otherwise the next run reuses the container, which is then running
  without the firewall.
- **On Windows, use WSL2** and keep the repo on the Linux file system (`~/...`),
  not under `/mnt/c`. Bind mounts from the Windows drive are slow.

## Example

`example/` is a minimal project for trying it out: `cd example && agentbox claude`.
It has a plain definition and a firewalled variant for Claude, which is the one
agentbox uses.

## License

MIT, see [LICENSE](LICENSE).
