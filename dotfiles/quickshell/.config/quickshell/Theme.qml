pragma Singleton

import QtQuick
import Quickshell

// Catppuccin Mocha with the teal accent -- the nd.theme default
// (modules/nixos/theme.nix). Hardcoded rather than read from the module: the
// rest of the stowed dotfiles (kvantum, vicinae, cliamp) pin the palette the
// same way, so a flavor change is a grep, not a plumbing job.
Singleton {
  readonly property color crust: "#11111b"
  readonly property color mantle: "#181825"
  readonly property color base: "#1e1e2e"
  readonly property color surface0: "#313244"
  readonly property color surface1: "#45475a"
  readonly property color surface2: "#585b70"
  readonly property color overlay0: "#6c7086"
  readonly property color subtext0: "#a6adc8"
  readonly property color text: "#cdd6f4"

  readonly property color accent: "#94e2d5"   // teal
  readonly property color peach: "#fab387"    // secondary accent (the logo's ❯)
  readonly property color red: "#f38ba8"
  readonly property color yellow: "#f9e2af"
  readonly property color green: "#a6e3a1"
  readonly property color blue: "#89b4fa"

  readonly property string font: "JetBrainsMono Nerd Font"
  readonly property int fontSize: 13
  readonly property int fontSmall: 11
  readonly property int iconSize: 15

  readonly property int barHeight: 34
  // Mirrors hyprland.lua: decoration.rounding = 10, general.gaps_out = 8.
  readonly property int radius: 10
  readonly property int gap: 8

  function alpha(c, a) {
    return Qt.rgba(c.r, c.g, c.b, a)
  }
}
