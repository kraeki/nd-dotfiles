#!/bin/sh
# Lua config (Hyprland 0.55+): runtime monitor changes go through `hyprctl eval`
# with hl.monitor() (legacy `hyprctl keyword monitor ...` is rejected now).
# transform=1 == 90 degrees. Monitors matched by description with the desc: prefix.
#
# NOTE on mode: these Dell U2518D units report NO preferred mode over EDID, so
# mode="preferred" falls back to 1280x720 (wrong resolution + DPI). Pin the
# native 2560x1440@59.95Hz explicitly so docking is deterministic.
#
# NOTE on disabled=false: coming from the laptop-only layout the Dells were set
# `disabled=true`; a mode/position rule alone does NOT clear that flag, so it is
# required. Enable the Dells FIRST (so eDP-1's workspaces have a landing monitor)
# THEN disable eDP-1.
hyprctl eval 'hl.monitor({output="desc:Dell Inc. DELL U2518D 3C4YP898AHPL", mode="2560x1440@59.95", position="0x0", transform=1, scale=1, disabled=false})'
hyprctl eval 'hl.monitor({output="desc:Dell Inc. DELL U2518D 3C4YP8A4AGBL", mode="2560x1440@59.95", position="1440x560", scale=1, disabled=false})'
hyprctl eval 'hl.monitor({output="eDP-1", disabled=true})'
