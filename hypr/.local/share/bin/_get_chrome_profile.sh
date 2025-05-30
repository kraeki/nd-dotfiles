#!/usr/bin/env bash

# Get active workspace ID
ws=$(hyprctl activeworkspace -j | jq -r '.id')

# Map workspace to profile folder
case "$ws" in
1) profile="Profile 2" ;; # Work
4) profile="Profile 3" ;; # Private
6) profile="Profile 5" ;; # JACW
8) profile="Profile 6" ;; # JGO
*) profile="" ;;   # fallback
esac

echo $profile
