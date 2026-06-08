#!/bin/sh
# Lua config (Hyprland 0.55+): runtime monitor changes go through `hyprctl eval`
# with hl.monitor(); the old `hyprctl dispatch exec "hyprctl keyword ..."` no
# longer works ("keyword can't work with non-legacy parsers").
hyprctl eval 'hl.monitor({output="eDP-1", mode="preferred", position="auto", scale=1.333})'
