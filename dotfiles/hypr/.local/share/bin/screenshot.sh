#!/usr/bin/env sh
# Screenshot helper for Hyprland. Modes (passed as $1 by hyprland.lua binds):
#   sf  selection  — region chosen with slurp   (Super+X)
#   m   monitor    — the currently focused output (Super+ALT+P)
#   p   print all  — every output at once         (Print)
#
# The capture is opened in swappy for optional annotation; saving (Ctrl+S)
# writes a timestamped PNG into ~/obsidian/Files/ per ~/.config/swappy/config
# (save_filename_format = %y%m%d_%Hh%Mm%Ss_screenshot.png).

mode="${1:-sf}"

case "$mode" in
  sf)
    geom="$(slurp)" || exit 1          # aborted selection → bail quietly
    grim -g "$geom" - | swappy -f -
    ;;
  m)
    out="$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .name')"
    grim -o "$out" - | swappy -f -
    ;;
  p)
    grim - | swappy -f -
    ;;
  *)
    echo "usage: screenshot.sh [sf|m|p]" >&2
    exit 2
    ;;
esac
