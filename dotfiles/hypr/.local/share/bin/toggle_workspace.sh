#!/usr/bin/env bash

# Get the current workspace
current_workspace=$(hyprctl activeworkspace -j | jq '.id')

# Define the target workspace
target_workspace=$1

# Hiding the open scratchpad is NOT done here any more. This used to close every
# visible special workspace before switching, via toggle_special -- which always
# acts on the FOCUSED monitor, so a scratchpad open on the other monitor was
# *moved onto the one you were switching to* rather than hidden. It now lives in
# hyprland.lua (binds:hide_special_on_workspace_change plus a workspace.active
# sweep), which also covers the paths that never go through this script: the
# 4-finger swipe, waybar clicks, and focus({workspace="previous"}) below.

if [ "$current_workspace" -eq "$target_workspace" ]; then
	# If we are already on the target workspace, move to the previous one
	hyprctl dispatch 'hl.dsp.focus({workspace="previous"})'
else
	# Otherwise, move to the target workspace
	hyprctl dispatch "hl.dsp.focus({workspace=$target_workspace})"
fi
