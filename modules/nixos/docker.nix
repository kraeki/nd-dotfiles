# Docker, socket-activated. Hosts add users to the "docker" group themselves
# (see hosts/naptop — the group grants root-equivalent access, so it's a
# per-machine decision, not part of the profile).
{ config, lib, pkgs, ... }:

{
  options.nd.docker.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.nd.enable;
    defaultText = lib.literalExpression "config.nd.enable";
    description = "Docker daemon (started on first use, not at boot).";
  };

  config = lib.mkIf config.nd.docker.enable {
    virtualisation.docker = {
      enable = true;
      enableOnBoot = false;  # Start on first docker command, saves ~1.8s boot
    };

    environment.systemPackages = [ pkgs.docker ];
  };
}
