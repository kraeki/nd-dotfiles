#!/usr/bin/env bash

# Get active workspace ID
ws=$(hyprctl activeworkspace -j | jq -r '.id')

# Map workspace to Chrome profile by signed-in email
case "$ws" in
1) email="andreas.schmid.as3@roche.com" ;;  # Roche
3) email="ikeark@gmail.com" ;;               # Private
5) email="andreas.schmid@jacwohlen.ch" ;;    # JACW
7) email="nd@team85.ch" ;;                   # T85 (formerly JGO)
9) email="andreas.schmid@ajv.ag" ;;          # AJV
*) email="" ;;
esac

[ -z "$email" ] && exit 0

# Resolve email to profile folder via Local State
jq -r --arg e "$email" \
  '.profile.info_cache | to_entries[] | select(.value.user_name==$e) | .key' \
  "$HOME/.config/google-chrome/Local State" | head -1
