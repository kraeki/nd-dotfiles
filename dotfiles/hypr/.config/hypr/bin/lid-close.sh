#!/bin/sh
# Fired on lid CLOSE (switch:on:Lid Switch in hyprland.lua).
#
# Only disable the internal panel for CLAMSHELL DOCKING — i.e. when at least one
# EXTERNAL monitor is active. When UNDOCKED, do NOTHING: logind's HandleLidSwitch
# suspends the machine and eDP-1 restores itself on resume. Disabling the SOLE
# monitor here would leave Hyprland headless (zero outputs), and re-enabling
# eDP-1 on lid-open then frequently reports "ok" without committing — a black
# panel that needs a power cycle.
#
# That guard now lives in toggle-laptop-display (which refuses to disable the
# only active monitor), so this is a thin wrapper. --quiet because a closing lid
# should not raise a notification; `|| exit 0` because the undocked refusal is
# the expected path here, not an error.
"$HOME/.local/share/bin/toggle-laptop-display" off --quiet
exit 0
