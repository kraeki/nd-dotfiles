# The nd installer ISO: a minimal live system whose job is to run
# `nd-install` — wifi → GitHub device-flow auth → clone this (private)
# repo → pick/generate a host → disko partitioning → nixos-install.
#
# Build:  nix build .#iso        (result/iso/ndos-*.iso)
# Flash:  dd if=result/iso/ndos-*.iso of=/dev/sdX bs=4M status=progress
#
# Deliberately NOT the nd profile — the ISO stays small; the full system
# is what gets installed.
{ config, lib, pkgs, modulesPath, inputs, ... }:

{
  imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix") ];

  image.baseName = lib.mkForce "ndos";
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

  # The wordmark straight from the branding master. Block glyphs (█ ▀ ▄)
  # render on the kernel console; box-drawing characters do not (verified
  # in a QEMU boot — they show as hollow boxes). Plain concatenation, not an
  # indented string: ''-interpolation would indent only the first line of
  # the multi-line wordmark and skew its top row.
  services.getty.helpLine = lib.mkAfter
    ("\n" + builtins.readFile ../branding/logo.txt + "\n  run  nd-install  to begin\n");
}
