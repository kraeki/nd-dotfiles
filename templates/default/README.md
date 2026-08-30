# My machines on nd

Scaffolded from [nd-dotfiles](https://github.com/kraeki/nd-dotfiles) — the nd
NixOS + Hyprland profile as a library. Your customizations live here, in your
repo; `nix flake update` pulls nd's updates.

## Setup

1. Rename `hosts/mymachine/` (and the hostname inside) and `me` (the user in
   `hosts/mymachine/default.nix` and `home.nix`) to your own.
2. Replace the placeholder hardware file with your machine's scan:

   ```bash
   sudo nixos-generate-config --show-hardware-config \
     > hosts/mymachine/hardware-configuration.nix
   ```

3. Commit (flakes only see git-tracked files), then:

   ```bash
   sudo nixos-rebuild switch --flake .#mymachine
   ```

## Customizing

Everything nd sets sits behind `nd.*` options — toggle instead of patching.
See the commented examples in `hosts/mymachine/default.nix` and `home.nix`,
and the module sources under
[modules/](https://github.com/kraeki/nd-dotfiles/tree/main/modules) for the
full list. The Hyprland/waybar/etc. dotfiles are nd's stow tree — clone
nd-dotfiles and run `make` for those, or bring your own.
