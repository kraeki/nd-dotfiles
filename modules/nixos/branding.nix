# Branding: the machine boots, locks, and greets under the nd mark.
# Vector master: branding/logo.svg. Other surfaces: fastfetch greeting
# (dotfiles/fastfetch), hyprlock label + branded wallpaper (dotfiles/hypr).
{ config, lib, pkgs, ... }:

{
  options.nd.branding.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.nd.enable;
    defaultText = lib.literalExpression "config.nd.enable";
    description = "Plymouth boot splash with the nd logo, quiet boot.";
  };

  config = lib.mkIf config.nd.branding.enable {
    boot.plymouth = {
      enable = true;
      # Rendered from the vector master at build time — no binary in the repo.
      logo = pkgs.runCommand "nd-plymouth-logo.png"
        { nativeBuildInputs = [ pkgs.librsvg ]; }
        ''
          rsvg-convert -w 128 -h 128 ${../../branding/logo.svg} -o $out
        '';
    };

    # Splash instead of scrolling kernel messages. Diagnostics are one
    # keypress away (Esc during boot), and `nd.branding.enable = false`
    # brings the full text boot back.
    boot.kernelParams = [ "quiet" ];
  };
}
