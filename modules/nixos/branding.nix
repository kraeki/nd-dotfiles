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
      # Own theme instead of `logo` on the stock one: the stock two-step
      # themes park the watermark at the bottom (WatermarkVerticalAlignment
      # .96), i.e. BELOW the LUKS passphrase dialog. This is the spinner
      # theme with the geometry flipped: wordmark above (.25), unlock dialog
      # under it (.58), spinner near the bottom (.78). Alignment maths:
      # y = alignment * (screen - image), so at 800px the 192px-tall mark
      # sits at 152..344 and the dialog starts around 380 — no overlap.
      theme = "ndos";
      themePackages = [
        (pkgs.runCommand "ndos-plymouth-theme"
          { nativeBuildInputs = [ pkgs.librsvg ]; }
          ''
            dir=$out/share/plymouth/themes/ndos
            mkdir -p $dir
            cp ${pkgs.plymouth}/share/plymouth/themes/spinner/*.png $dir/
            # The wordmark, rendered from the vector master at build time —
            # no binary in the repo. Width only (the mark is 2.75:1; pinning
            # both axes would squash it); 528 = 44 cells x 12px — off the
            # 44-cell grid, cell edges land on fractional pixels and rsvg
            # antialiases hairline seams between the glyph rects.
            rsvg-convert -w 528 ${../../branding/logo.svg} -o $dir/watermark.png
            sed -e '/^Name\[/d' \
                -e 's/^Name=.*/Name=ndos/' \
                -e 's/^Description=.*/Description=The ndos wordmark above the unlock dialog./' \
                -e "s|^ImageDir=.*|ImageDir=$dir|" \
                -e 's/^WatermarkVerticalAlignment=.*/WatermarkVerticalAlignment=.25/' \
                -e 's/^DialogVerticalAlignment=.*/DialogVerticalAlignment=.58/' \
                -e 's/^TitleVerticalAlignment=.*/TitleVerticalAlignment=.58/' \
                -e 's/^VerticalAlignment=.*/VerticalAlignment=.78/' \
                ${pkgs.plymouth}/share/plymouth/themes/spinner/spinner.plymouth \
                > $dir/ndos.plymouth
          '')
      ];
    };

    # Splash instead of scrolling kernel messages. Diagnostics are one
    # keypress away (Esc during boot), and `nd.branding.enable = false`
    # brings the full text boot back.
    boot.kernelParams = [ "quiet" ];
  };
}
