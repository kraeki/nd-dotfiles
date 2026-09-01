# Branding: the machine boots, locks, and greets under the ndos wordmark —
# "NDOS" in Delta Corps Priest 1, the figlet font the Omarchy logo is drawn in.
# Master: branding/logo.txt, from which branding/logo.svg is derived exactly
# (the font uses only full/half block glyphs, so each cell is one rect).
# Other surfaces: fastfetch greeting (dotfiles/fastfetch), hyprlock label +
# branded wallpaper (dotfiles/hypr).
#
# Ported from the ndos repo, where this is a `nd.branding.enable` module.
# There is no nd.* option namespace here, so it is unconditional — drop the
# import from flake.nix to get the full text boot back.
{ pkgs, ... }:

{
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
        rsvg-convert -w 528 ${./branding/logo.svg} -o $out
      '';
  };

  # Splash instead of scrolling kernel messages. Diagnostics are one keypress
  # away (Esc during boot). Merges with the list in hosts/naptop/configuration.nix.
  boot.kernelParams = [ "quiet" ];
}
