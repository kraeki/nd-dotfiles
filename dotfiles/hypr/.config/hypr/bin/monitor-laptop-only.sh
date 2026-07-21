#!/bin/sh
# Lua config (Hyprland 0.55+): runtime monitor changes go through `hyprctl eval`
# with hl.monitor(); the old `hyprctl dispatch exec "hyprctl keyword ..."` no
# longer works ("keyword can't work with non-legacy parsers").
#
# NOTE: `disabled=false` is REQUIRED. Coming from the docked layout, eDP-1 was
# set `disabled=true`; applying a mode/position/scale rule alone does NOT clear
# that flag, so without this the laptop panel stays dark on undock.
#
# Enable eDP-1 FIRST so its workspaces have a landing monitor, THEN fold away the
# externals: on undock Hyprland can keep the Dells as phantom (still "enabled")
# monitors, which would strand their workspaces on a physically-off screen.
# Disabling by description is a harmless no-op if the monitors are already gone.
hyprctl eval 'hl.monitor({output="eDP-1", mode="preferred", position="auto", scale=1.333, disabled=false})'
hyprctl eval 'hl.monitor({output="desc:Dell Inc. DELL U2518D 3C4YP898AHPL", disabled=true})'
hyprctl eval 'hl.monitor({output="desc:Dell Inc. DELL U2518D 3C4YP8A4AGBL", disabled=true})'
