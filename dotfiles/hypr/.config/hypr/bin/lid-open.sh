#!/bin/sh
# Fired on lid OPEN (switch:off:Lid Switch in hyprland.lua).
#
# Re-enable the internal panel if it was disabled for clamshell docking. Enabling
# from a just-resumed / recently-headless state can report "ok" without actually
# committing, so verify and retry a few times. Idempotent: if eDP-1 is already
# on (the undocked path in lid-close.sh never disabled it), the first check
# passes and we exit immediately.
#
# `hyprctl monitors` (not `all`) lists only ENABLED monitors, so an eDP-1
# "Monitor" header means the panel is live.
i=0
while [ "$i" -lt 5 ]; do
	if hyprctl monitors | grep -q '^Monitor eDP-1 '; then
		exit 0
	fi
	hyprctl eval 'hl.monitor({output="eDP-1", mode="preferred", position="auto", scale=1.333, disabled=false})'
	i=$((i + 1))
	sleep 0.4
done
exit 0
