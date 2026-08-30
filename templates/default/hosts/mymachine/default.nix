# mymachine — rename the directory and hostname to taste. This file holds
# what is true of THIS machine; identity comes from the nd profile.
{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # The whole nd profile. Toggle the parts you don't want:
  nd.enable = true;
  # nd.gaming.enable = false;
  # nd.branding.enable = false;          # text boot instead of splash
  # nd.theme.accent = "mauve";           # any catppuccin accent
  # nd.locale.timeZone = "Europe/Zurich";

  networking.hostName = "mymachine";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  users.users.me = {
    isNormalUser = true;
    description = "Me";
    extraGroups = [ "networkmanager" "wheel" "docker" "video" "render" ];
    shell = pkgs.zsh;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.me = import ../../home.nix;
  };

  # NixOS release at first install — do not bump on upgrades.
  system.stateVersion = "25.05";
}
