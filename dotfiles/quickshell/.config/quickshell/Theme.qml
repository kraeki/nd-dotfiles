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

  // One material for every surface -- bar, panels, toasts, OSD -- so they
  // read as one shell. Teal is kept for *state* (active workspace, today, a
  // toggle that is on, an open element), never for frames: the window
  // borders in hyprland.lua are their own gradient, and a teal frame next to
  // one reads as two competing outlines.
  readonly property color bg: base
  readonly property color border: surface1

  readonly property string font: "JetBrainsMono Nerd Font"
  readonly property int fontSize: 13       // body and bar labels
  readonly property int fontSmall: 12      // captions: dim labels, app names, toast bodies
  readonly property int fontHeading: 16
  readonly property int fontDisplay: 26    // panel hero numbers and icons, OSD icon
  readonly property int iconSize: 15

  readonly property int barHeight: 34
  // The window grid from hyprland.lua, so shell surfaces line up with window
  // frames: decoration.rounding = 10, general.border_size = 2,
  // general.gaps_out = 8 (screen edge / bar to window), gaps_in = 3 (two
  // tiled windows sit 2 * 3 = 6 apart).
  readonly property int radius: 10
  readonly property int borderWidth: 2
  readonly property int gap: 8
  readonly property int innerGap: 6
  readonly property int pad: 14           // inside every card
  readonly property int cardWidth: 380    // toasts and the text panels share it

  function alpha(c, a) {
    return Qt.rgba(c.r, c.g, c.b, a)
  }
}
