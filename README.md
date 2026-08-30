# nd-dotfiles

My NixOS + Hyprland system — flakes, home-manager, and stow-managed dotfiles,
organized as a reusable module library. See
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for where this is headed.

## Layout

```
flake.nix         The flake: nixosModules, homeManagerModules, hosts
modules/nixos/    The "distro": system modules behind nd.* options
modules/home/     Home-manager modules behind nd.* options
hosts/naptop/     This machine: hardware, boot, kernel quirks, its user
users/kraeki/     Personal home config (packages, aliases)
pkgs/             Custom packages not in nixpkgs (herdr, tldraw-offline)
dotfiles/         Stow-managed app configs, symlinked into $HOME
```

## Install

On an existing NixOS machine, no clone needed:

```bash
sudo nixos-rebuild switch --flake github:kraeki/nd-dotfiles#naptop
```

Or bootstrap everything (clone + dotfile symlinks + rebuild) with the
interactive installer:

```bash
curl -sL https://raw.githubusercontent.com/kraeki/nd-dotfiles/main/install.sh | bash
```

It asks which machine this is. Picking an existing host applies that config;
picking **new machine** probes the hardware (`nixos-generate-config`), asks
for hostname/username, and generates a thin `hosts/<name>/` on top of the nd
profile plus a starter `users/<name>/home.nix` — the flake discovers every
directory under `hosts/` automatically, so the new machine is immediately
buildable. Hardware truth stays per-host; the modules are hardware-agnostic.
Set `ND_HOST=<host>` for a prompt-free install.

## Day-to-day

```bash
make            # symlink all dotfiles into $HOME (stow)
make delete     # remove the symlinks
make switch     # rebuild + switch NixOS (HOST=naptop by default)
make upgrade    # update flake inputs, then rebuild + switch
```

## Bare-metal reinstall (nixos-anywhere)

`hosts/naptop/disko.nix` declares the disk layout (GPT, 1G ESP, LUKS2 →
ext4, no swap). On the running system it is inert — current mounts stay
governed by `hardware-configuration.nix`. To wipe and reinstall naptop from
any other machine:

1. In `hosts/naptop/disko.nix`: delete the `disko.enableConfig = false;`
   line (disko then owns the mounts, with reinstall-stable paths).
2. Replace the mounts in the hardware file with a mount-free scan — on the
   target run `sudo nixos-generate-config --no-filesystems
   --show-hardware-config`, put the output in
   `hosts/naptop/hardware-configuration.nix`, commit.
3. From the installing machine (target booted into any Linux with SSH root
   access, e.g. the NixOS minimal ISO):

   ```bash
   printf '%s' 'your-luks-passphrase' > /tmp/luks.pass
   nix run github:nix-community/nixos-anywhere -- \
     --disk-encryption-keys /tmp/disk.key /tmp/luks.pass \
     --flake .#naptop root@<target-ip>
   ```

It partitions per `disko.nix` (asking nothing), installs, and reboots into
the full system. **This erases the disk** — the two-step flip is deliberate.

## The installer ISO

```bash
nix build .#iso     # → result/iso/nd-*.iso
dd if=result/iso/nd-*.iso of=/dev/sdX bs=4M status=progress
```

Boot the stick and run `nd-install`: it connects wifi, authenticates to
GitHub with a device-flow code (repo is private — confirm on your phone, no
password typed on the target), clones the repo, and asks which machine this
is. An existing host installs per its `disko.nix` (after the reinstall flip
below); "new machine" probes the hardware, asks hostname/username/disk, and
generates a disko-owned `hosts/<name>/`. Then: LUKS passphrase, one final
ERASE confirmation, disko partitioning, `nixos-install`, user password,
reboot. The repo lands in `~/work/nd-dotfiles` on the new system, generated
host staged for commit.

## Bare-metal reinstall (nixos-anywhere)

Every push runs `.github/workflows/build.yml`: the `check` job evaluates the
whole naptop system (a broken module fails in CI, not on the laptop), and the
`cache` job builds the custom packages — the waybar override, Handy
(~1,100 Rust crates), wayscriber, herdr, tldraw-offline — and pushes them to
Cachix so `nixos-rebuild` downloads instead of compiling.

The cache job stays skipped until one-time setup:

1. Create a cache at [app.cachix.org](https://app.cachix.org)
2. Repo settings → **Variables**: `CACHIX_CACHE` = the cache name;
   **Secrets**: `CACHIX_AUTH_TOKEN` = an auth token for it
3. Point the machines at it in `hosts/*`:

   ```nix
   nd.cache.url = "https://<name>.cachix.org";
   nd.cache.publicKey = "<name>.cachix.org-1:...";   # from the cache page
   ```

The packages are also directly buildable: `nix build .#waybar`, `.#handy`, …

## Extending

The flake exports the system as a library — no fork needed. Scaffold your own
consumer flake:

```bash
mkdir my-machines && cd my-machines
nix flake init -t github:kraeki/nd-dotfiles
```

You get a flake that imports `nixosModules.default` +
`homeManagerModules.default`, a skeleton host, and a README with the three
setup steps (rename, drop in your `nixos-generate-config` output, rebuild).
Your customizations live in *your* repo; `nix flake update` pulls nd updates.
Everything sits behind `nd.*` options, so you toggle instead of patching:

```nix
nd.enable = true;
nd.gaming.enable = false;
nd.theme.accent = "mauve";
```

Hosts stay thin — compare `hosts/naptop/default.nix`: hardware truth and the
machine's user, everything else comes from the modules.
