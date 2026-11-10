#!/usr/bin/env bash
# Installs agentbox, or updates it to the latest release:
#
#   curl -fsSL https://raw.githubusercontent.com/kgonia/agentbox/main/install.sh | bash
#
# Settings, as environment variables for bash (curl ... | AGENTBOX_VERSION=v0.1.0 bash):
#   AGENTBOX_VERSION  a release tag such as v0.1.0, or a branch such as main
#                     (default: the latest release)
#   AGENTBOX_BIN_DIR  where the agentbox and claudebox commands go
#                     (default: ~/.local/bin)
#
# agentbox itself goes to ~/.local/share/agentbox ($XDG_DATA_HOME/agentbox).
# The agents' volumes, the containers and ~/.config/agentbox are left alone.

die() { echo "agentbox install: $*" >&2; exit 1; }

# The download is unpacked here, then swapped in; removed if anything fails.
new=

# Everything happens in main, which runs only once bash has read the whole
# script, so a download that breaks off halfway doesn't run half of it.
main() {
  set -euo pipefail
  local repo=kgonia/agentbox
  local version=${AGENTBOX_VERSION:-}
  local dest=${XDG_DATA_HOME:-$HOME/.local/share}/agentbox
  local bin_dir=${AGENTBOX_BIN_DIR:-$HOME/.local/bin}

  local tool
  for tool in curl tar; do
    command -v "$tool" >/dev/null || die "$tool not found"
  done

  if [[ -z $version ]]; then
    # This redirects to the latest release, or to the list of releases when
    # there is none.
    version=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$repo/releases/latest") ||
      die "couldn't look up the latest release on github.com/$repo"
    version=${version##*/}
    [[ $version != releases ]] ||
      die "$repo has no release yet; AGENTBOX_VERSION=main installs the development version"
  fi

  # Never unpack over a folder that isn't agentbox's.
  if [[ -e $dest && ! -f $dest/bin/agentbox ]]; then
    die "$dest exists and isn't agentbox; move it away first"
  fi

  echo "agentbox: downloading $version"
  mkdir -p -- "$(dirname -- "$dest")"
  new=$(mktemp -d "$dest.new.XXXXXX")
  trap 'rm -rf -- "$new"' EXIT
  curl -fsSL "https://github.com/$repo/archive/$version.tar.gz" |
    tar -xzf - -C "$new" --strip-components=1 ||
    die "couldn't download $version from github.com/$repo"
  [[ -f $new/bin/agentbox && -d $new/agents ]] ||
    die "the download of $version doesn't contain agentbox"
  printf '%s\n' "$version" >"$new/VERSION"
  chmod 755 -- "$new"

  # Swap folders rather than overwrite files: a running agentbox is still
  # reading its script.
  if [[ -e $dest ]]; then
    rm -rf -- "$dest.old"
    mv -- "$dest" "$dest.old"
  fi
  mv -- "$new" "$dest"
  rm -rf -- "$dest.old"

  # Commands that lead somewhere else, such as links to a clone, stay as they are.
  mkdir -p -- "$bin_dir"
  local name link target ours
  ours=$(readlink -f -- "$dest/bin/agentbox")
  for name in agentbox claudebox; do
    link=$bin_dir/$name
    if [[ -e $link || -L $link ]]; then
      target=$(readlink -f -- "$link" || true)
      if [[ $target != "$ours" ]]; then
        echo "agentbox: left $link alone, it leads to ${target:-nowhere}"
        continue
      fi
    fi
    ln -sfn -- "$dest/bin/$name" "$link"
  done

  echo "agentbox: installed $version in $dest"
  case ":$PATH:" in
    *":$bin_dir:"*) ;;
    *) echo "agentbox: add $bin_dir to your PATH to run it" ;;
  esac
  command -v docker >/dev/null ||
    echo "agentbox: it also needs Docker"
  command -v devcontainer >/dev/null ||
    echo "agentbox: it also needs the Dev Containers CLI: npm install -g @devcontainers/cli"
  command -v flock >/dev/null ||
    echo "agentbox: without flock (util-linux), containers keep running after your sessions end"
}

main "$@"
