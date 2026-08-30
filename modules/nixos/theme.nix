# Theme: Catppuccin everywhere. Flavor and accent are options so a consumer
# can rebuild the whole look with two lines (`nd.theme.accent = "mauve";`).
{ config, lib, pkgs, ... }:

let
  cfg = config.nd.theme;
  cap = s: lib.toUpper (builtins.substring 0 1 s) + builtins.substring 1 (builtins.stringLength s) s;
  gtkTheme = "catppuccin-${cfg.flavor}-${cfg.accent}-standard";
  cursorTheme = "Catppuccin-${cap cfg.flavor}-${cap cfg.accent}";
in
{
  options.nd.theme = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.nd.enable;
      defaultText = lib.literalExpression "config.nd.enable";
      description = "Catppuccin GTK/Qt/cursor/console theming.";
    };
    flavor = lib.mkOption {
      type = lib.types.enum [ "latte" "frappe" "macchiato" "mocha" ];
      default = "mocha";
      description = "Catppuccin flavor.";
    };
    accent = lib.mkOption {
      type = lib.types.str;
      default = "teal";
      description = "Catppuccin accent color (teal, mauve, peach, ...).";
    };
    cursorSize = lib.mkOption {
      type = lib.types.int;
      default = 30;
      description = "Cursor size (matches the HiDPI 1.333 scale).";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.variables.GTK_THEME = gtkTheme;
    environment.variables.XCURSOR_THEME = cursorTheme;
    environment.variables.XCURSOR_SIZE = toString cfg.cursorSize;
    environment.variables.HYPRCURSOR_THEME = cursorTheme;
    environment.variables.HYPRCURSOR_SIZE = toString cfg.cursorSize;

    qt.enable = true;
    qt.platformTheme = "gtk2";
    qt.style = "gtk2";

    console = {
      earlySetup = true;
      colors = [
        "24273a"
        "ed8796"
        "a6da95"
        "eed49f"
        "8aadf4"
        "f5bde6"
        "8bd5ca"
        "cad3f5"
        "5b6078"
        "ed8796"
        "a6da95"
        "eed49f"
        "8aadf4"
        "f5bde6"
        "8bd5ca"
        "a5adcb"
      ];
    };

    # Override packages
    nixpkgs.config.packageOverrides = pkgs: {
      colloid-icon-theme = pkgs.colloid-icon-theme.override { colorVariants = [ cfg.accent ]; };
      catppuccin-gtk = pkgs.catppuccin-gtk.override {
        accents = [ cfg.accent ]; # You can specify multiple accents here to output multiple themes
        size = "standard";
        variant = cfg.flavor;
      };
      discord = pkgs.discord.override {
        withOpenASAR = true;
        withTTS = true;
      };
    };

    environment.systemPackages = with pkgs; [
      numix-icon-theme-circle
      colloid-icon-theme
      catppuccin-gtk
      catppuccin-kvantum
      catppuccin-cursors.${cfg.flavor + cap cfg.accent}
    ];
  };
}
