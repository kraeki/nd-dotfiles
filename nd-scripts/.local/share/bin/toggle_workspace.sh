#!/bin/bash

# Get the current workspace
current_workspace=$(hyprctl activeworkspace -j | jq '.id')

# Define the target workspace
target_workspace=$1

if [ "$current_workspace" -eq "$target_workspace" ]; then
	# If we are already on the target workspace, move to the previous one
	hyprctl dispatch workspace previous
else
	# Otherwise, move to the target workspace
	hyprctl dispatch workspace "$target_workspace"
fi
