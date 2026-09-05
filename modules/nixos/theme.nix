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
    # Qt apps follow Catppuccin through Kvantum, not through the GTK bridge.
    # "gtk2" here used to set QT_STYLE_OVERRIDE=gtk2, which loads qt6gtk2 --
    # and qt6gtk2 reads a GTK *2* theme, of which Catppuccin has none, so every
    # Qt6 window (xdg-desktop-portal-hyprland's share picker most visibly)
    # rendered in stock beige GTK2 Raleigh. It also fought the stowed
    # qt6ct.conf, which has asked for style=kvantum all along while neither
    # qt6ct nor the Kvantum plugin was installed.
    #
    # "qt5ct" installs qt5ct AND qt6ct (hyprland.lua exports
    # QT_QPA_PLATFORMTHEME=qt6ct, which is the one that matters here);
    # "kvantum" installs both Kvantum style plugins and sets
    # QT_STYLE_OVERRIDE=kvantum, so Qt5 apps get the palette too even though
    # they cannot load qt6ct.
    #
    # Which Kvantum theme is picked is NOT parameterised by nd.theme: it comes
    # from the stowed dotfiles/kvantum/.config/Kvantum/kvantum.kvconfig, which
    # names catppuccin-<flavor>-<accent> literally. Changing flavor/accent
    # below means editing that file too.
    qt.platformTheme = "qt5ct";
    qt.style = "kvantum";

    # systemPackages only links the subdirectories listed in
    # environment.pathsToLink, and /share/Kvantum is not one of them. Without
    # this, catppuccin-kvantum is in the closure but nothing of it reaches
    # /run/current-system/sw -- the reason it can be listed below for ages
    # while `ls /run/current-system/sw/share/Kvantum` comes up empty. Kvantum
    # itself is fine with the location: nixpkgs patches it to search XDG dirs.
    environment.pathsToLink = [ "/share/Kvantum" ];

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
      # Defaults to frappe/blue. The override also decides the directory name
      # -- share/Kvantum/catppuccin-<variant>-<accent> -- which is what
      # kvantum.kvconfig points at.
      catppuccin-kvantum = pkgs.catppuccin-kvantum.override {
        accent = cfg.accent;
        variant = cfg.flavor;
      };
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
