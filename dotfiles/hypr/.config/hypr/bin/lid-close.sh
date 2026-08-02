#!/bin/sh
# Fired on lid CLOSE (switch:on:Lid Switch in hyprland.lua).
#
# Only disable the internal panel for CLAMSHELL DOCKING — i.e. when at least one
# EXTERNAL monitor is active. When UNDOCKED, do NOTHING: logind's HandleLidSwitch
# suspends the machine and eDP-1 restores itself on resume. Disabling the SOLE
# monitor here would leave Hyprland headless (zero outputs), and re-enabling
# eDP-1 on lid-open then frequently reports "ok" without committing — a black
# panel that needs a power cycle. This guard is the fix for that bug.
#
# `hyprctl monitors` (not `all`) lists only ENABLED monitors, so a non-eDP-1
# "Monitor" header means a live external.
externals=$(hyprctl monitors | grep '^Monitor ' | grep -vc 'eDP-1')
[ "${externals:-0}" -gt 0 ] && hyprctl eval 'hl.monitor({output="eDP-1", disabled=true})'
exit 0
