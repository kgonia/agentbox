# claudebox

Runs Claude Code inside a project's own dev container, without editing the
project. It works with any `.devcontainer`, including a team one that knows
nothing about Claude.

```sh
cd ~/Projects/some-repo
claudebox            # build or start the container, run claude in it
claudebox -c         # arguments go to claude (here: continue the last session)
claudebox --shell    # a shell in the same container
```

## Requirements

- Docker
- Node.js and the [Dev Containers CLI](https://github.com/devcontainers/cli):
  `npm install -g @devcontainers/cli`

## Install

```sh
ln -s "$PWD/bin/claudebox" ~/.local/bin/claudebox
```

## Usage

```
claudebox [options] [--] [claude args...]

  --rebuild             recreate the container from its definition, then continue
  --shell               open a shell in the container instead of claude
  --rm                  remove this project's claudebox containers and exit
  --config FILE         use FILE as devcontainer.json
  --share-history       share chat history with Claude on the host; this
                        project keeps sharing until --no-share-history
  --no-share-history    stop sharing chat history for this project
  -h, --help            show this help
```

Arguments after the options go to `claude`. Use `--` to pass one that
claudebox would take itself: `claudebox -- --help` shows Claude's help.

## Settings

`~/.config/claudebox/config` is plain shell:

```sh
CLAUDEBOX_SHARE_HISTORY=yes     # share history in new containers (default: no)
CLAUDEBOX_VOLUME=claude-config  # Docker volume for Claude's login and config
```

`CLAUDEBOX_VOLUME` can also be set in the environment, which overrides the
file. History sharing can't: it's controlled by the flags below and the file.

## Sharing history with Claude on the host

```sh
claudebox --share-history       # turn it on for this project
claudebox                       # stays on
claudebox --no-share-history    # turn it off again
```

With sharing on, `claude --resume` on the host lists the sessions from the
container, and the other way round. Per-project memory is shared too. The
login and settings still come from the volume.

Claude files history by project path, as in
`~/.claude/projects/-home-you-Projects-repo/`. So claudebox:

- mounts the host's `~/.claude/projects` at `/claude-config/projects`;
- also mounts the project's git root at its host path, and starts Claude there
  instead of under `/workspaces`.

A container keeps the mounts it was created with, so each project's container
remembers its mode:

- A flag that changes the mode recreates the container once.
- Without a flag, an existing container keeps its mode, including through
  `--rebuild`.
- A new container, for example after `claudebox --rm`, takes the default from
  the config file.

Changing the config file doesn't affect existing containers. While sharing is
on, the history stored in the volume is hidden, not deleted.

Only `projects/` is shared, never all of `~/.claude`. That folder also holds
`settings.json` and hooks, which a project's script could change to run
commands on your host.

## What it does

1. **Finds the definition.** Starting in the current folder and walking up,
   it takes the first of `.devcontainer/claude/devcontainer.json`,
   `.devcontainer/devcontainer.json` or `.devcontainer.json`. With none, it
   uses `default/devcontainer.json` (plain Ubuntu) for the git root, or the
   current folder outside git.
2. **Runs `devcontainer up` with additions** that leave the project untouched:
   - the Node and Claude Code features (`--additional-features`). Node is
     there because the Claude feature fails to install it on current Ubuntu
     images. Options the project sets for the Node feature take precedence.
   - the `claude-config` volume at `/claude-config`, with `CLAUDE_CONFIG_DIR`
     pointing at it, so the login, settings and history survive rebuilds.
   - its own id labels (`claudebox.folder`, `claudebox.config`), so it never
     reuses a container VS Code created for the same folder. That container
     would not have Claude installed.
   - `--no-lockfile`, so the CLI doesn't write claudebox's features into the
     project's `devcontainer-lock.json`. As a result, a lockfile the project
     has is not checked either.
3. **Gives the volume to the container's user**, because Docker creates it
   owned by root.
4. **Runs `claude` with `devcontainer exec`**, in the same subfolder you are
   in on the host, with your `TERM` and `COLORTERM`.

The first build takes a minute or more. After that the container stays
running and `claudebox` takes under a second. Changes to `devcontainer.json`
apply only after `claudebox --rebuild`. The volume keeps its contents through
a rebuild.

## Cleanup

```sh
claudebox --rebuild                                             # recreate from the definition
claudebox --rm                                                  # remove this project's containers
docker rm -f $(docker ps -aq --filter label=claudebox.folder)   # remove every claudebox container
docker volume rm claude-config                                  # forget the login and history
```

## Caveats

- **The project's definition sets the isolation, not claudebox.** If
  `devcontainer.json` mounts the Docker socket, runs privileged or mounts host
  folders, Claude gets the same access. Read it before you trust it.
- **All projects share one login volume.** Anything that runs in a project's
  container can read the Claude login token and every project's history. That
  includes the project's own `postCreateCommand` and install scripts, not just
  Claude. For a repo you don't trust, use a separate volume:
  `CLAUDEBOX_VOLUME=claude-untrusted claudebox`. If projects run as users with
  different UIDs, claudebox re-owns the volume each time you switch between
  them.
- **Shared history is open to every container.** With sharing on, anything
  running in a project's container can read all of your host chat history,
  including projects that never ran in claudebox. It can also write
  transcripts and memory that Claude on the host loads later. Keep sharing off
  for a repo you don't trust. Sharing also assumes the container's user has
  your UID, which the Dev Containers CLI arranges on Linux. A container
  running as root would leave root-owned files in your history.
- **A firewall can't be added from outside.** It needs `--cap-add=NET_ADMIN`
  and a start command in the definition itself. Write a Claude-only variant in
  `.devcontainer/claude/devcontainer.json`, which claudebox prefers. Build it
  from the same image or Dockerfile as the main one, remembering that relative
  paths are one folder deeper. `example/.devcontainer/claude/devcontainer.json`
  is a working example. It runs the `init-firewall.sh` that the Claude Code
  feature installs. Version 1.0.5 of that script stops when a domain on its
  list no longer resolves (`statsig.anthropic.com` doesn't), so the example
  patches that while running it. If the start command fails, run
  `claudebox --rebuild` after fixing it. Otherwise the next run reuses the
  container, which is then running without the firewall.
- **On Windows, use WSL2** and keep the repo on the Linux file system (`~/...`),
  not under `/mnt/c`. Bind mounts from the Windows drive are slow.

## Example

`example/` is a minimal project for trying it out: `cd example && claudebox`.
It has a plain definition and a firewalled Claude variant, which is the one
claudebox uses.
