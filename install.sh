#!/usr/bin/env bash
# nd installer — interactive, Omarchy-style. One command from a fresh NixOS login:
#
#   curl -sL https://raw.githubusercontent.com/kraeki/nd-dotfiles/main/install.sh | bash
#
# Asks which machine this is (or probes the hardware and generates a new
# hosts/<name>/ for it), symlinks the dotfiles, and rebuilds. Idempotent:
# safe to re-run to update an existing setup.
#
# Non-interactive use: set ND_HOST to an existing host to skip all prompts
# (plus ND_DIR / ND_REPO to override paths). Prompts need a terminal; the
# script grabs /dev/tty so it survives `curl | sh`.
set -euo pipefail

ND_REPO="${ND_REPO:-https://github.com/kraeki/nd-dotfiles.git}"
ND_DIR="${ND_DIR:-$HOME/work/nd-dotfiles}"
ND_HOST="${ND_HOST:-}"

TEAL=$'\033[36m'; DIM=$'\033[2m'; BOLD=$'\033[1m'; RED=$'\033[31m'; RESET=$'\033[0m'

banner() {
  printf '%s' "$TEAL"
  cat <<'LOGO'

  ███▄▄▄▄   ████████▄   ▄██████▄     ▄████████
  ███▀▀▀██▄ ███   ▀███ ███    ███   ███    ███
  ███   ███ ███    ███ ███    ███   ███    █▀
  ███   ███ ███    ███ ███    ███   ███
  ███   ███ ███    ███ ███    ███ ▀███████████
  ███   ███ ███    ███ ███    ███          ███
  ███   ███ ███   ▄███ ███    ███    ▄█    ███
   ▀█   █▀  ████████▀   ▀██████▀   ▄████████▀
LOGO
  printf '%s' "$RESET"
  printf '  %sNixOS + Hyprland, declarative all the way down%s\n\n' "$DIM" "$RESET"
}

say() { printf '%s[nd]%s %s\n' "$TEAL" "$RESET" "$*"; }
die() { printf '%s[nd]%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }

# Tools may not exist yet on a fresh install — fall back to running them out
# of nixpkgs without installing anything (gum is what draws the prompts).
run() {
  local tool="$1"; shift
  if command -v "$tool" >/dev/null 2>&1; then
    "$tool" "$@"
  else
    nix --extra-experimental-features 'nix-command flakes' \
      shell "nixpkgs#$tool" -c "$tool" "$@"
  fi
}
ui() { run gum "$@"; }

banner
[ -e /etc/NIXOS ] || die "This installer expects NixOS. For other setups, clone the repo and run 'make' for dotfiles only."

# `curl | sh` leaves stdin on the pipe; reattach to the terminal for prompts.
if [ ! -t 0 ]; then
  if [ -r /dev/tty ]; then exec </dev/tty; else
    [ -n "$ND_HOST" ] || die "No terminal for prompts. Set ND_HOST=<host> for a non-interactive install."
  fi
fi

## Get the repo
if [ -d "$ND_DIR/.git" ]; then
  say "Updating existing checkout at $ND_DIR"
  run git -C "$ND_DIR" pull --ff-only
else
  say "Cloning $ND_REPO to $ND_DIR"
  mkdir -p "$(dirname "$ND_DIR")"
  run git clone "$ND_REPO" "$ND_DIR"
fi

## Which machine is this?
NEW_HOST=0
if [ -z "$ND_HOST" ]; then
  mapfile -t hosts < <(find "$ND_DIR/hosts" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
  choice=$(ui choose --header "Which machine is this?" "${hosts[@]}" "✚ new machine (probe hardware)")
  case "$choice" in
    "✚ new machine"*) NEW_HOST=1 ;;
    *) ND_HOST="$choice" ;;
  esac
fi

## New machine: generate YOUR OWN config repo (~/ndos-config) — a complete
## flake that consumes the distro as an input. Two-repo model: your machines
## live in your repo; the distro repo carries the modules and dotfiles.
CFG_DIR="${CFG_DIR:-$HOME/ndos-config}"
if [ "$NEW_HOST" = 1 ]; then
  [ -e "$CFG_DIR" ] && die "$CFG_DIR already exists — rebuild from it instead: sudo nixos-rebuild switch --flake $CFG_DIR#<host>"
  ND_HOST=$(ui input --header "Hostname for this machine" --placeholder "e.g. desktop" --value "")
  [ -n "$ND_HOST" ] || die "A hostname is required."
  username=$(ui input --header "Your username" --value "${SUDO_USER:-${USER:-kraeki}}")
  fullname=$(ui input --header "Your full name (for the user account)" --value "")
  tz=$(timedatectl list-timezones 2>/dev/null | ui filter --placeholder "Time zone (type to search)") \
    || tz=$(ui input --header "Time zone" --value "Europe/Berlin")
  release=$(nixos-version | grep -oE '^[0-9]+\.[0-9]+' || echo "25.05")
  ND_URL="git+${ND_REPO%.git}"

  say "Generating your config repo at $CFG_DIR"
  mkdir -p "$CFG_DIR/hosts/$ND_HOST"

  cat > "$CFG_DIR/flake.nix" <<EOF
{
  description = "$ND_HOST — my machine on the ndos profile";

  inputs = {
    # The distro. git+https so the git credential helper (gh auth) can serve
    # it while the distro repo is private; switch to github:… if it goes
    # public. Update with: nix flake update nd
    nd.url = "$ND_URL";
    nixpkgs.follows = "nd/nixpkgs";
    home-manager.follows = "nd/home-manager";
  };

  outputs = { self, nd, nixpkgs, home-manager, ... }: {
    nixosConfigurations.$ND_HOST = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        home-manager.nixosModules.home-manager
        nd.nixosModules.default
        { home-manager.sharedModules = [ nd.homeManagerModules.default ]; }
        ./hosts/$ND_HOST
        { nixpkgs.config.allowUnfree = true; }
      ];
    };
  };
}
EOF

  say "Probing hardware (nixos-generate-config)"
  sudo nixos-generate-config --show-hardware-config \
    > "$CFG_DIR/hosts/$ND_HOST/hardware-configuration.nix"

  cat > "$CFG_DIR/hosts/$ND_HOST/default.nix" <<EOF
# $ND_HOST — generated by install.sh. Hardware truth and this machine's
# basics; identity comes from the nd modules. Toggle what you don't want:
#   nd.gaming.enable = false;    nd.theme.accent = "mauve";    …
{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # The whole ndos profile.
  nd.enable = true;
  nd.locale.timeZone = "$tz";

  networking.hostName = "$ND_HOST";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  users.users.$username = {
    isNormalUser = true;
    description = "$fullname";
    extraGroups = [ "networkmanager" "wheel" "docker" "video" "render" ];
    shell = pkgs.zsh;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.$username = import ../../home.nix;
  };

  # NixOS release at first install of this machine — do not bump on upgrades.
  system.stateVersion = "$release";
}
EOF

  cat > "$CFG_DIR/home.nix" <<EOF
# $username's home: the ndos home profile plus whatever is yours.
{ config, pkgs, ... }:

{
  nd.enable = true;

  home.username = "$username";
  home.homeDirectory = "/home/$username";
  home.stateVersion = "$release";

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    firefox
  ];
}
EOF

  # Flakes only see git-tracked files.
  run git -C "$CFG_DIR" init -q -b main
  run git -C "$CFG_DIR" add -A
  run git -C "$CFG_DIR" commit -qm "machine config for $ND_HOST, generated by install.sh" || true
  say "Generated $CFG_DIR — your machine's own repo, with the distro as a flake input."
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    if ui confirm "Create a private GitHub repo for it and push?"; then
      reponame=$(ui input --header "Repository name" --value "ndos-config")
      run gh repo create "$reponame" --private --source "$CFG_DIR" --push || say "Repo creation failed — push later with 'gh repo create'."
    fi
  else
    say "To sync it with GitHub later: gh auth login && gh repo create ndos-config --private --source $CFG_DIR --push"
  fi
fi

## Dotfiles
say "Symlinking dotfiles into \$HOME (stow)"
(cd "$ND_DIR/dotfiles" && run stow --target="$HOME" --restow -- */)

# Hyprland expects the script directory to exist (see CLAUDE.md).
mkdir -p "$HOME/.local/share/bin"

## Build & switch — a new machine builds from its own config repo, a distro
## host from the distro repo.
FLAKE_DIR="$ND_DIR"
if [ "$NEW_HOST" = 1 ]; then FLAKE_DIR="$CFG_DIR"; fi
echo
ui confirm "Build and switch to the '$ND_HOST' system now? (first run downloads/compiles a lot)" \
  || { say "Skipped. Later: sudo nixos-rebuild switch --flake $FLAKE_DIR#$ND_HOST"; exit 0; }

sudo env NIX_CONFIG="experimental-features = nix-command flakes" \
  nixos-rebuild switch --flake "$FLAKE_DIR#$ND_HOST"

if [ "$NEW_HOST" = 1 ]; then
  # The build wrote flake.lock — commit it so the distro revision is pinned.
  run git -C "$CFG_DIR" add -A
  run git -C "$CFG_DIR" commit -qm "lock flake inputs" || true
fi

echo
say "Done. Log out/in (or reboot) and start the desktop with: ${BOLD}hypr${RESET}"
if [ "$NEW_HOST" = 1 ]; then
  say "This machine lives in $CFG_DIR — commit & push changes there to keep it reproducible."
fi
