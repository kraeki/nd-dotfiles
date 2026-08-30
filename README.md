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

Or bootstrap everything (clone + dotfile symlinks + rebuild):

```bash
curl -sL https://raw.githubusercontent.com/kraeki/nd-dotfiles/main/install.sh | sh
```

## Day-to-day

```bash
make            # symlink all dotfiles into $HOME (stow)
make delete     # remove the symlinks
make switch     # rebuild + switch NixOS (HOST=naptop by default)
make upgrade    # update flake inputs, then rebuild + switch
```

## CI & binary cache

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

The flake exports the system as a library: import `nixosModules.default`
(and `homeManagerModules.default` on the home-manager side), set
`nd.enable = true`, then toggle what you don't want:

```nix
nd.enable = true;
nd.gaming.enable = false;
nd.theme.accent = "mauve";
```

Hosts stay thin — compare `hosts/naptop/default.nix`: hardware truth and the
machine's user, everything else comes from the modules.
