#!/usr/bin/env bash
# nd bootstrap — clone, stow, rebuild. One command from a fresh NixOS login:
#
#   curl -sL https://raw.githubusercontent.com/kraeki/nd-dotfiles/main/install.sh | sh
#
# Idempotent: safe to re-run to update an existing setup.
# Environment overrides: ND_DIR (checkout path), ND_HOST (flake host),
# ND_REPO (git remote).
set -euo pipefail

ND_REPO="${ND_REPO:-https://github.com/kraeki/nd-dotfiles.git}"
ND_DIR="${ND_DIR:-$HOME/work/nd-dotfiles}"
ND_HOST="${ND_HOST:-naptop}"

say() { printf '\033[36m[nd]\033[0m %s\n' "$*"; }
die() { printf '\033[31m[nd]\033[0m %s\n' "$*" >&2; exit 1; }

[ -e /etc/NIXOS ] || die "This bootstrap expects NixOS. For other setups, clone the repo and run 'make' for dotfiles only."

# git and stow ship with the nd profile, but a fresh install may not have them
# yet — fall back to running them out of nixpkgs without installing anything.
run() {
  local tool="$1"; shift
  if command -v "$tool" >/dev/null 2>&1; then
    "$tool" "$@"
  else
    nix --extra-experimental-features 'nix-command flakes' \
      shell "nixpkgs#$tool" -c "$tool" "$@"
  fi
}

if [ -d "$ND_DIR/.git" ]; then
  say "Updating existing checkout at $ND_DIR"
  run git -C "$ND_DIR" pull --ff-only
else
  say "Cloning $ND_REPO to $ND_DIR"
  mkdir -p "$(dirname "$ND_DIR")"
  run git clone "$ND_REPO" "$ND_DIR"
fi

say "Symlinking dotfiles into \$HOME (stow)"
(cd "$ND_DIR/dotfiles" && run stow --target="$HOME" --restow -- */)

# Hyprland expects the script directory to exist (see CLAUDE.md).
mkdir -p "$HOME/.local/share/bin"

say "Building and switching to the '$ND_HOST' system configuration"
say "(first run downloads/compiles a lot — subsequent runs are fast)"
sudo nixos-rebuild switch --flake "$ND_DIR#$ND_HOST"

say "Done. Log out/in (or reboot) and start the desktop with: hypr"
