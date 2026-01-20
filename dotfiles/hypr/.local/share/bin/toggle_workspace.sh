#!/usr/bin/env bash

# Get the current workspace
current_workspace=$(hyprctl activeworkspace -j | jq '.id')

# Define the target workspace
target_workspace=$1

# Close any visible special workspaces before switching
# Check monitors for visible special workspaces
visible_special=$(hyprctl monitors -j | jq -r '.[] | .specialWorkspace | select(.id != 0) | .name')
if [ -n "$visible_special" ]; then
	while IFS= read -r workspace; do
		workspace_name=${workspace#special:}
		if [ -z "$workspace_name" ]; then
			# Generic special workspace
			hyprctl dispatch togglespecialworkspace
		else
			# Named special workspace (slack, obsidian, etc.)
			hyprctl dispatch togglespecialworkspace "$workspace_name"
		fi
	done <<< "$visible_special"
fi

if [ "$current_workspace" -eq "$target_workspace" ]; then
	# If we are already on the target workspace, move to the previous one
	hyprctl dispatch workspace previous
else
	# Otherwise, move to the target workspace
	hyprctl dispatch workspace "$target_workspace"
fi
