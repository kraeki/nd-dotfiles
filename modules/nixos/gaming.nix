# Gaming: Steam plus the 32-bit graphics stack and controller udev rules.
{ config, lib, ... }:

{
  options.nd.gaming.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.nd.enable;
    defaultText = lib.literalExpression "config.nd.enable";
    description = "Steam, 32-bit graphics libraries, game controller support.";
  };

  config = lib.mkIf config.nd.gaming.enable {
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;  # Optional: only if you plan to use Remote Play
      dedicatedServer.openFirewall = false;  # Optional
    };

    hardware.graphics.enable32Bit = true; # Required for 32-bit games
    hardware.steam-hardware.enable = true;  # Enables udev rules for game controllers
  };
}
