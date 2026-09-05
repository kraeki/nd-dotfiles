# From Dotfiles to Distro — the nd-dotfiles blueprint

How this repo — one Framework laptop's NixOS + Hyprland config — becomes a
named, branded, one-command-installable system that other people can extend.
Omarchy's spirit, but declarative all the way down.

## 00 · Where it stands

> **Phase 1 is done** — the flake lives at the repo root, the old monolithic
> `configuration.nix` is split into `modules/nixos/` behind `nd.*` options,
> `hosts/naptop` is a thin consumer, and `install.sh` bootstraps a fresh
> machine. The paragraph below describes the starting point it replaced.
>
> **The two-repo model is in place** — both installers now generate a NEW
> machine as its own config repo (`~/ndos-config`): a complete flake pinning
> the distro as an input (`nd.url`), holding that machine's host + home
> config, with an offered private GitHub remote (`gh repo create --push`).
> The ISO asks the archinstall basics upfront (user, password, time zone,
> disk, encryption) and runs unattended after the ERASE confirmation; the
> distro repo carries only modules, branding, dotfiles and the owner's own
> hosts.
>
> **Phase 6 (ISO installer) is done** — `nix build .#iso` produces the nd
> live stick; `nd-install` runs wifi → GitHub device-flow auth (repo stays
> private) → clone → host pick or new-machine probing (disko-owned) → LUKS
> passphrase → ERASE confirmation → disko + nixos-install → reboot.
> **Phase 4 (secrets) is deferred by decision** — the repo stays private
> for now, so espanso/work files remain plain; revisit sops-nix if it ever
> goes public.
>
> **Phase 3 (disko + nixos-anywhere) is done** — `hosts/naptop/disko.nix`
> declares the layout (GPT, ESP, LUKS2 → ext4) mirrored from the live
> hardware scan; inert on the running system (`disko.enableConfig = false`,
> verified derivation-identical) and flipped on deliberately for a
> wipe-reinstall. The README documents the nixos-anywhere flow, including
> LUKS key handoff.
>
> **Phase 7 (template + docs) is done** — `nix flake init -t
> github:kraeki/nd-dotfiles` scaffolds a consumer flake (skeleton host,
> home.nix, README) that imports the nd modules; verified end-to-end by
> evaluating a scaffolded machine. Remaining phases (3 · disko, 4 · sops-nix,
> 6 · ISO) are gated on owner input: the real disk layout, and the
> public-vs-private secrets decision.
>
> **Phase 5 (branding) is done** — `branding/logo.svg` is the vector master
> (terminal-window mark, teal + peach cursor). Plymouth boot splash renders
> it at build time (`modules/nixos/branding.nix`, `nd.branding.enable`),
> fastfetch greets with the ANSI mark, hyprlock carries a dim `ndos ❯`, and a
> subtle branded wallpaper joined the wpaperd rotation.
>
> **Phase 2 is done** — `.github/workflows/build.yml` evaluates the full
> system on every push and pre-builds the custom packages (now flake
> outputs: `waybar`, `handy`, `wayscriber`, `herdr`, `tldraw-offline`) for
> Cachix; machines subscribe via `nd.cache.*`. One-time setup remains
> yours: create the cache, set the repo's `CACHIX_CACHE` variable +
> `CACHIX_AUTH_TOKEN` secret, and fill in `nd.cache.url`/`publicKey`
> (steps in README).

Originally the flake lived in `nixos-config/`, knew exactly one host, and
mixed two different things in a 447-line `configuration.nix`: *hardware truth*
(amdgpu quirks, Framework modules, kernel params) and *identity* (Hyprland,
Catppuccin, TLP policy, vicinae, espanso). Dotfiles were stow-managed beside
it. It worked — but nothing in it could be named, reused, installed by URL, or
handed to someone else. Everything below starts by separating those two
things.

## 01 · Structure: split the distro from the host

Move the flake to the repository root and reorganize around one idea:
**the distro is a module library; a host is a thin consumer of it.**

```
flake.nix              ← at root: repo becomes installable by URL
modules/
  nixos/               desktop.nix · audio.nix · power.nix · docker.nix
  home/                hyprland.nix · shell.nix · theming.nix
hosts/
  naptop/              default.nix · hardware-configuration.nix · disko.nix
users/
  kraeki/              home.nix
dotfiles/              stays stow-shaped, live-editable
branding/              logo.svg · logo.txt · plymouth/ · wallpapers/
iso/                   installer image + installer TUI script
install.sh             curl-able bootstrap
```

- **Give it a name.** Everything downstream — the options namespace, the
  logo, the installer's first screen — hangs off it. All options live under
  one prefix: `nd.desktop.enable`, `nd.theme.accent = "teal"`,
  `nd.apps.espanso.enable = false`.
- **Keep stow, drive it from Nix.** Porting configs into `xdg.configFile`
  would land them read-only in the store and kill the `hc` edit-and-reload
  loop. Instead let home-manager symlink the existing `dotfiles/` tree via
  `mkOutOfStoreSymlink` — or run stow from an activation script.
  Live-editable files, one-command setup.
- **The discipline that makes §04 real:** `hosts/naptop` must consume the
  distro through the same public options as any outside user. You become
  user #1 of your own API.

## 02 · Speed: installable in a minute of typing

"Under a minute" means under a minute of *your* time — the build runs on its
own. Three paths, ordered by how blank the target machine is:

```bash
# already on NixOS — zero clone
sudo nixos-rebuild switch --flake github:kraeki/nd-dotfiles#naptop

# fresh $HOME — one bootstrap (clones → stows → rebuilds)
curl -sL https://raw.githubusercontent.com/kraeki/nd-dotfiles/main/install.sh | sh

# blank disk, from any other machine — disko partitions, installs, reboots
nixos-anywhere --flake .#naptop root@target-ip
```

What actually makes installs fast is a **binary cache**: a GitHub Action
builds the flake on every push and pushes to Cachix, so a fresh machine
downloads instead of compiling (this is what saves reinstalls from rebuilding
Handy's ~1,100 crates).

## 03 · Identity: the logo, everywhere it counts

A distro feel is the same mark hitting every surface. Design one SVG in Mocha
teal, then derive:

- **ANSI logo** — `branding/logo.txt`, rendered from the SVG with `chafa` or
  hand-drawn; shown by a custom fastfetch config on new shells and by an
  `nd` command.
- **Boot splash** — package it as a Plymouth theme;
  `boot.plymouth.themePackages` makes the machine boot under your brand.
- **Lock screen & wallpaper** — `hyprlock.conf` takes images; ship a branded
  default wallpaper for wpaperd.
- **The ISO** — `isoImage.isoName`, the boot menu title, and the installer
  TUI header all carry the name.

## 04 · Extensibility: a library, not a fork

Omarchy is "fork it and edit." A flake can be consumed *without* forking —
other people import your modules, flip options, and pull your updates with
`nix flake update`. Expose four outputs:

| Output | Purpose |
| --- | --- |
| `nixosModules.default` | The whole distro as one importable module — everything behind `nd.*` options, so consumers toggle instead of patching. |
| `homeManagerModules.default` | The user layer: Hyprland config, shell, theming — same option discipline. |
| `templates.default` | `nix flake init -t github:kraeki/nd-dotfiles` scaffolds a consumer flake plus an empty `hosts/their-machine/`. Their customizations live in *their* repo. |
| `packages.x86_64-linux.iso` | The branded installer image, built by CI, attached to GitHub releases. |

## 05 · The installer: boot → phone tap → your machine

Add a `nixosConfigurations.iso` that imports nixpkgs'
`installation-cd-minimal.nix` plus NetworkManager, `git`, `gh`, `disko`, the
branding, and an installer script auto-run on the login TTY. A `gum`-based
TUI is plenty — skip Calamares.

```bash
nix build .#nixosConfigurations.iso.config.system.build.isoImage
dd if=result/iso/nd-*.iso of=/dev/sdX bs=4M status=progress
```

Installer flow:

1. **Boot & connect** — logo on screen; prompt for wifi via `nmcli` if no
   ethernet.
2. **Authenticate — nothing baked in.** The ISO is a world-readable
   artifact, so it never carries a token. Public repo: no auth at all (the
   Omarchy model). Private repo: `gh auth login` device flow — a code on
   screen, confirmed on your phone, no password typed on the target.
3. **Partition** — pick the target disk; `disko` applies the declarative
   layout from `hosts/*/disko.nix`.
4. **Pick a host** — choose an existing host config, or "new host": run
   `nixos-generate-config` and commit the generated hardware file later.
5. **Install & hand over** — `nixos-install --flake`, set the user password,
   clone the repo into the new `$HOME`, stow, reboot. Interactive time: a
   wifi password, one disk choice, one phone tap.

> **Prerequisite, not afterthought — secrets.** `espanso/private.yml`,
> `roche.yml`, and wifi PSKs must leave the repo before it can go public:
> encrypt in-repo with sops-nix or agenix (decrypted by a host key the
> installer generates), or split into a private repo the installer pulls
> optionally. Given the work content, this is step one of the ISO track.

## 06 · Roadmap: seven phases, each shippable alone

| Phase | What | Ships |
| --- | --- | --- |
| 1 | **Restructure** — flake to root, module split, `nd.*` options namespace, `install.sh`. Unblocks everything; no new tools. | URL install |
| 2 | **Cache + CI** — GitHub Action builds the flake per push, pushes to Cachix. | fast installs |
| 3 | **disko + nixos-anywhere** — declarative partitioning; one-command bare-metal reinstall, before any ISO exists. | 1-cmd reinstall |
| 4 | **Secrets extraction** — sops-nix for espanso/work/wifi material; decide public vs. private. | public-ready repo |
| 5 | **Branding pass** — logo → fastfetch, Plymouth, hyprlock, wallpaper. | the look |
| 6 | **ISO + installer TUI** — branded image, gum flow, device-flow auth, CI release artifact. | the stick |
| 7 | **Template + docs** — `templates.default` and a README for outside users. | extensibility |

Phases 1–3 alone already deliver "reinstall my exact system in minutes with
one command."
