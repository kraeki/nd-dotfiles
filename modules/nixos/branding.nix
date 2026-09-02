# Branding: the machine boots, locks, and greets under the ndos wordmark —
# "NDOS" in Delta Corps Priest 1, the figlet font the Omarchy logo is drawn in.
# Master: branding/logo.txt, from which branding/logo.svg is derived exactly
# (the font uses only full/half block glyphs, so each cell is one rect).
# Other surfaces: fastfetch greeting (dotfiles/fastfetch), hyprlock label +
# branded wallpaper (dotfiles/hypr). See branding/README.md.
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
      # Width only — the wordmark is 2.75:1, so pinning both axes would squash it.
      # 528 = 44 cells x 12px: on a non-multiple of the 44-cell grid the cell
      # edges land on fractional pixels and rsvg antialiases hairline seams
      # between the rects. Keep any size change a multiple of 44.
      logo = pkgs.runCommand "nd-plymouth-logo.png"
        { nativeBuildInputs = [ pkgs.librsvg ]; }
        ''
          rsvg-convert -w 528 ${../../branding/logo.svg} -o $out
        '';
    };

    # Splash instead of scrolling kernel messages. Diagnostics are one
    # keypress away (Esc during boot), and `nd.branding.enable = false`
    # brings the full text boot back.
    boot.kernelParams = [ "quiet" ];
  };
}
