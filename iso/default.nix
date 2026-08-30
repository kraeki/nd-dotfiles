# The nd installer ISO: a minimal live system whose job is to run
# `nd-install` — wifi → GitHub device-flow auth → clone this (private)
# repo → pick/generate a host → disko partitioning → nixos-install.
#
# Build:  nix build .#iso        (result/iso/nd-*.iso)
# Flash:  dd if=result/iso/nd-*.iso of=/dev/sdX bs=4M status=progress
#
# Deliberately NOT the nd profile — the ISO stays small; the full system
# is what gets installed.
{ config, lib, pkgs, modulesPath, inputs, ... }:

{
  imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];

  image.baseName = lib.mkForce "nd";
  networking.hostName = "nd-iso";

  # NetworkManager for the installer's wifi prompt (the minimal CD defaults
  # to wpa_supplicant).
  networking.networkmanager.enable = true;
  networking.wireless.enable = lib.mkForce false;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Catppuccin console, same palette as modules/nixos/theme.nix.
  console = {
    earlySetup = true;
    colors = [
      "24273a" "ed8796" "a6da95" "eed49f" "8aadf4" "f5bde6" "8bd5ca" "cad3f5"
      "5b6078" "ed8796" "a6da95" "eed49f" "8aadf4" "f5bde6" "8bd5ca" "a5adcb"
    ];
  };

  environment.systemPackages = with pkgs; [
    git
    gh
    gum
    vim
    parted
    inputs.disko.packages.${pkgs.stdenv.hostPlatform.system}.default
    (writeShellScriptBin "nd-install" (builtins.readFile ./nd-install.sh))
  ];

  services.getty.helpLine = lib.mkAfter ''

      ┌─┐┌─┐
      │ ││ │  nd·os installer
      └─┘└─┘

      run  nd-install  to begin
  '';
}
