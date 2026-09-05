# nd-install — runs on the ndos ISO. Wifi → GitHub auth → the archinstall-style
# questions (user, password, timezone, disk, encryption) → generates YOUR OWN
# config repo (a complete flake that consumes the ndos distro as an input) →
# disko partitioning → nixos-install → offers to push the config repo to
# GitHub → reboot. (Wrapped by writeShellScriptBin in iso/default.nix.)
#
# Two-repo model: the distro repo (ND_REPO) carries the modules, branding and
# installer; the machine you are installing gets its own repo (~/ndos-config on
# the installed system) holding only its hosts + home config. That repo pins
# the distro as a flake input, so it is complete in itself — rebuild from it,
# update the distro with `nix flake update nd`.
set -euo pipefail

ND_REPO="${ND_REPO:-https://github.com/kraeki/nd-dotfiles.git}"
ND_DIR="${ND_DIR:-/root/nd-dotfiles}"
CFG_DIR="${CFG_DIR:-/root/ndos-config}"
# The generated flake pins the distro via git+https (not github:) so the
# git credential helper (gh) can serve it while the distro repo is private.
ND_URL="git+${ND_REPO%.git}"

TEAL=$'\033[36m'; DIM=$'\033[2m'; BOLD=$'\033[1m'; RED=$'\033[31m'; RESET=$'\033[0m'
say() { printf '%s[nd]%s %s\n' "$TEAL" "$RESET" "$*"; }
die() { printf '%s[nd]%s %s\n' "$RED" "$RESET" "$*" >&2; exit 1; }

[ "$(id -u)" = 0 ] || exec sudo ND_REPO="$ND_REPO" ND_DIR="$ND_DIR" CFG_DIR="$CFG_DIR" "$0" "$@"

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
printf '  %sthis will ERASE a disk on this machine — nothing happens before a final confirmation%s\n\n' "$DIM" "$RESET"

## 1. Network
if ! nm-online -q -t 5 2>/dev/null; then
  say "No network. Pick a wifi network:"
  nmcli device wifi rescan 2>/dev/null || true; sleep 2
  ssid=$(nmcli -t -f SSID device wifi list | grep -v '^$' | sort -u | gum choose --header "Wifi network")
  wpass=$(gum input --password --header "Passphrase for $ssid")
  nmcli device wifi connect "$ssid" password "$wpass"
  nm-online -q -t 30 || die "Still offline — check the connection and re-run nd-install."
fi

## 2. GitHub (device flow: code on screen, confirm on phone). Needed to clone
##    the private distro repo, and later to offer pushing your config repo.
if ! gh auth status >/dev/null 2>&1; then
  say "Authenticate with GitHub. A one-time code will appear —"
  say "open the URL on your phone and enter it."
  gh auth login --hostname github.com --git-protocol https
fi
gh auth setup-git

## 3. The distro
if [ ! -d "$ND_DIR/.git" ]; then
  say "Cloning the ndos distro ($ND_REPO)"
  git clone "$ND_REPO" "$ND_DIR"
fi

## 4. Which machine?
mapfile -t hosts < <(find "$ND_DIR/hosts" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
choice=$(gum choose --header "Install which machine?" "✚ new machine (your own config repo)" "${hosts[@]}")

nixeval() { nix --extra-experimental-features 'nix-command flakes' eval "$@"; }

NEW=0
if [ "$choice" = "✚ new machine (your own config repo)" ]; then
  NEW=1

  ## 5. The questions (all upfront — nothing more to answer after ERASE)
  host=$(gum input --header "Hostname for this machine" --placeholder "e.g. desktop")
  [ -n "$host" ] || die "A hostname is required."
  username=$(gum input --header "Your username" --placeholder "e.g. kim")
  [ -n "$username" ] || die "A username is required."
  fullname=$(gum input --header "Your full name" --value "")

  p1=$(gum input --password --header "Password for $username")
  p2=$(gum input --password --header "Repeat password")
  [ "$p1" = "$p2" ] || die "Passwords don't match."
  [ -n "$p1" ] || die "Empty password."

  tz=$(timedatectl list-timezones 2>/dev/null | gum filter --placeholder "Time zone (type to search)") \
    || tz=$(gum input --header "Time zone" --value "Europe/Berlin")

  mapfile -t disks < <(lsblk -dno NAME,SIZE,MODEL --sort NAME | awk '$1 !~ /^(loop|sr|ram)/ {print "/dev/"$0}')
  disk=$(printf '%s\n' "${disks[@]}" | gum choose --header "Install to which disk? (WILL BE ERASED)" | awk '{print $1}')

  # Size the layout for THIS machine, not naptop's. The swap partition exists
  # for hibernation, so it must hold a full RAM image: RAM rounded up + 1G.
  mem_kb=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
  swap_g=$(( (mem_kb + 1048575) / 1048576 + 1 ))
  disk_g=$(( $(lsblk -bdno SIZE "$disk") / 1073741824 ))
  [ "$disk_g" -ge 24 ] || die "$disk is only ${disk_g}G — too small for the ndos profile (24G minimum)."
  if [ "$disk_g" -lt $(( swap_g + 21 )) ]; then
    # Not enough room for hibernation swap + a usable root. Keep a small swap
    # (still useful as the zram safety net's backstop) and give root the rest.
    say "Small disk (${disk_g}G): using 4G swap instead of ${swap_g}G — hibernation won't fit."
    swap_g=4
  fi
  layout="1G ESP + ${swap_g}G encrypted swap + ~$(( disk_g - swap_g - 1 ))G encrypted root"

  if gum confirm "Use the same password for disk encryption?"; then
    dp="$p1"
  else
    d1=$(gum input --password --header "Disk encryption passphrase")
    d2=$(gum input --password --header "Repeat passphrase")
    [ "$d1" = "$d2" ] || die "Passphrases don't match."
    [ -n "$d1" ] || die "Empty passphrase."
    dp="$d1"
  fi
  printf '%s' "$dp" > /tmp/disk.key; unset dp d1 d2

  release=$(nixos-version | grep -oE '^[0-9]+\.[0-9]+' || echo "25.05")

  ## 6. Generate YOUR config repo — a complete flake consuming the distro
  say "Generating your config repo ($CFG_DIR)"
  rm -rf "$CFG_DIR"; mkdir -p "$CFG_DIR/hosts/$host"

  cat > "$CFG_DIR/flake.nix" <<EOF
{
  description = "$host — my machine on the ndos profile";

  inputs = {
    # The distro. git+https so the git credential helper (gh auth) can serve
    # it while the distro repo is private; switch to github:… if it goes
    # public. Update with: nix flake update nd
    nd.url = "$ND_URL";
    nixpkgs.follows = "nd/nixpkgs";
    home-manager.follows = "nd/home-manager";
  };

  outputs = { self, nd, nixpkgs, home-manager, ... }: {
    nixosConfigurations.$host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        home-manager.nixosModules.home-manager
        nd.nixosModules.default
        { home-manager.sharedModules = [ nd.homeManagerModules.default ]; }
        nd.inputs.disko.nixosModules.disko
        ./hosts/$host
        { nixpkgs.config.allowUnfree = true; }
      ];
    };
  };
}
EOF

  say "Probing hardware"
  nixos-generate-config --no-filesystems --show-hardware-config \
    > "$CFG_DIR/hosts/$host/hardware-configuration.nix"

  # Disk layout: the distro's reference shape (GPT, 1G ESP, LUKS2 swap+root),
  # sized for THIS machine — naptop's disko.nix hardcodes its own 34G swap,
  # which overflows smaller disks. disko owns the mounts on a generated host
  # (no enableConfig=false), so the fresh partitions mount by stable paths.
  cat > "$CFG_DIR/hosts/$host/disko.nix" <<EOF
# $host disk layout, generated by the ndos installer.
# GPT: 1G ESP, ${swap_g}G LUKS swap, LUKS ext4 root on the rest.
{ ... }:

{
  disko.devices.disk.main = {
    type = "disk";
    device = "$disk";
    content = {
      type = "gpt";
      partitions = {
        esp = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "fmask=0077" "dmask=0077" ];
          };
        };
        swap = {
          # Sized at install time from this machine's RAM (hibernation swap).
          size = "${swap_g}G";
          content = {
            type = "luks";
            name = "cryptswap";
            passwordFile = "/tmp/disk.key";
            settings.allowDiscards = true;
            content = { type = "swap"; };
          };
        };
        luks = {
          size = "100%";
          content = {
            type = "luks";
            name = "cryptroot";
            passwordFile = "/tmp/disk.key";
            settings.allowDiscards = true;
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    };
  };
}
EOF

  cat > "$CFG_DIR/hosts/$host/default.nix" <<EOF
# $host — generated by the ndos installer. Hardware truth and this machine's
# basics; identity comes from the nd modules. Toggle what you don't want:
#   nd.gaming.enable = false;    nd.theme.accent = "mauve";    …
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
  ];

  # The whole ndos profile.
  nd.enable = true;
  nd.locale.timeZone = "$tz";
  # nd.locale.regionalFormat = "de_DE.UTF-8";   # dates/numbers/paper format

  networking.hostName = "$host";

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

  # NixOS release at first install — do not bump on upgrades.
  system.stateVersion = "$release";
}
EOF

  cat > "$CFG_DIR/home.nix" <<EOF
# $username's home: the ndos home profile plus whatever is yours.
{ config, pkgs, ... }:

{
  # ndos home profile (shell with zsh/p10k/fzf/z-lua, tuned Chrome).
  nd.enable = true;
  # nd.chrome.enable = false;

  home.username = "$username";
  home.homeDirectory = "/home/$username";
  home.stateVersion = "$release";

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    firefox
  ];
}
EOF

  cat > "$CFG_DIR/README.md" <<EOF
# $host

My machine, on the [ndos](${ND_REPO%.git}) profile. Generated by the ndos
installer; this repo is complete in itself — the distro is a pinned flake
input.

\`\`\`sh
sudo nixos-rebuild switch --flake ~/ndos-config#$host   # apply changes
nix flake update nd                                     # pull distro updates
nix flake update                                        # update everything
\`\`\`

Customize via \`nd.*\` options in \`hosts/$host/default.nix\` and \`home.nix\`.
The distro's stow-managed dotfiles (Hyprland etc.) live in the distro repo:
clone it and run \`make\` there.
EOF

  git -C "$CFG_DIR" init -q -b main
  git -C "$CFG_DIR" add -A
  git -C "$CFG_DIR" -c user.name="ndos installer" -c user.email="installer@ndos" \
    commit -qm "machine config for $host, generated by the ndos installer"

  FLAKE_DIR="$CFG_DIR"
else
  ## Existing distro-owned host (installs straight from the distro repo)
  host=$choice
  # It must let disko own its mounts, or the fresh partitions (new UUIDs)
  # won't match its hardware-configuration.nix.
  if [ "$(nixeval "$ND_DIR#nixosConfigurations.$host.config.disko.enableConfig" 2>/dev/null)" != "true" ]; then
    die "hosts/$host still mounts via hardware-configuration.nix UUIDs. Follow the 'Bare-metal reinstall' flip steps in the README (enableConfig + --no-filesystems), push, and re-run."
  fi
  disk=$(nixeval --raw "$ND_DIR#nixosConfigurations.$host.config.disko.devices.disk.main.device")
  username=$(nixeval --raw "$ND_DIR#nixosConfigurations.$host.config" --apply \
    'c: builtins.head (builtins.filter (n: c.users.users.${n}.isNormalUser or false) (builtins.attrNames c.users.users))' 2>/dev/null) \
    || username=$(gum input --header "Username on $host")

  p1=$(gum input --password --header "Password for $username")
  p2=$(gum input --password --header "Repeat password")
  [ "$p1" = "$p2" ] || die "Passwords don't match."
  [ -n "$p1" ] || die "Empty password."

  d1=$(gum input --password --header "Disk encryption passphrase")
  d2=$(gum input --password --header "Repeat passphrase")
  [ "$d1" = "$d2" ] || die "Passphrases don't match."
  printf '%s' "$d1" > /tmp/disk.key; unset d1 d2

  layout="the layout in hosts/$host/disko.nix"
  FLAKE_DIR="$ND_DIR"
fi

## 7. Point of no return — everything after this runs unattended
echo
gum confirm --default=false \
  "ERASE $disk ($layout) and install '$host'? This destroys everything on the disk." \
  || { say "Aborted — nothing was touched."; exit 0; }

say "Partitioning $disk (disko)"
disko --mode destroy,format,mount --yes-wipe-all-disks --flake "$FLAKE_DIR#$host"

say "Installing (first run downloads/compiles a lot)"
nixos-install --flake "$FLAKE_DIR#$host" --no-root-passwd

say "Setting the password for '$username'"
printf '%s:%s\n' "$username" "$p1" | nixos-enter --root /mnt -c chpasswd
unset p1 p2

if [ "$NEW" = 1 ]; then
  # Lock file was written during the build — it pins the distro revision.
  git -C "$CFG_DIR" add -A
  git -C "$CFG_DIR" -c user.name="ndos installer" -c user.email="installer@ndos" \
    commit -qm "lock flake inputs" 2>/dev/null || true

  ## 8. Offer GitHub for the config repo
  echo
  if gum confirm "Create a private GitHub repo for this machine's config and push it?"; then
    reponame=$(gum input --header "Repository name" --value "ndos-config")
    gh repo create "$reponame" --private --source "$CFG_DIR" --push \
      && say "Pushed to GitHub as $reponame." \
      || say "Repo creation failed — the local git repo is intact; push it later with 'gh repo create'."
  else
    say "Skipped. The config is a local git repo; push it any time with 'gh repo create'."
  fi

  say "Moving your config repo to the new home (~/ndos-config)"
  mkdir -p "/mnt/home/$username"
  cp -r "$CFG_DIR" "/mnt/home/$username/ndos-config"
  nixos-enter --root /mnt -c "chown -R $username /home/$username/ndos-config" || true
else
  # Distro-owned machine: the distro repo travels to the new home.
  say "Copying the distro repo to the new home"
  mkdir -p "/mnt/home/$username/work"
  cp -r "$ND_DIR" "/mnt/home/$username/work/nd-dotfiles"
  nixos-enter --root /mnt -c "chown -R $username /home/$username/work" || true
fi

shred -u /tmp/disk.key 2>/dev/null || rm -f /tmp/disk.key
echo
say "${BOLD}Done.${RESET} After reboot: log in and run 'gh auth login' once so git"
say "can reach the private distro input (and your config repo, if pushed)."
if [ "$NEW" = 1 ]; then
  say "Your machine lives in ~/ndos-config; rebuild with: sudo nixos-rebuild switch --flake ~/ndos-config#$host"
fi
say "For the distro's dotfiles (Hyprland etc.): clone the distro repo and run 'make'."
gum confirm "Reboot now?" && reboot
