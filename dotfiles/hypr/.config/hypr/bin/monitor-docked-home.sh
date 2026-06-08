#!/bin/sh
# Lua config (Hyprland 0.55+): runtime monitor changes go through `hyprctl eval`
# with hl.monitor() (legacy `hyprctl keyword monitor ...` is rejected now).
# transform=1 == 90 degrees. Monitors matched by description with the desc: prefix.
hyprctl eval 'hl.monitor({output="eDP-1", disabled=true})'
hyprctl eval 'hl.monitor({output="desc:Dell Inc. DELL U2518D 3C4YP898AHPL", mode="preferred", position="0x0", transform=1, scale=1})'
hyprctl eval 'hl.monitor({output="desc:Dell Inc. DELL U2518D 3C4YP8A4AGBL", mode="preferred", position="1440x560", scale=1})'
