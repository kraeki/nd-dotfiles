# The nd system profile, as a module library.
#
# Import this (or the flake's `nixosModules.default`) and set
# `nd.enable = true` to get the whole profile. Every submodule follows
# `nd.enable` by default but can be toggled individually, e.g.
# `nd.gaming.enable = false;`. Hosts stay thin: hardware truth and
# machine-specific choices live under hosts/, identity lives here.
{ lib, ... }:

{
  imports = [
    ./branding.nix
    ./cache.nix
    ./core.nix
    ./desktop.nix
    ./docker.nix
    ./gaming.nix
    ./libvirt.nix
    ./locale.nix
    ./networking.nix
    ./power.nix
    ./theme.nix
  ];

  options.nd.enable = lib.mkEnableOption "the nd system profile (all nd.* modules default to this)";
}
