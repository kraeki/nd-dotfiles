#!/usr/bin/env bash
#
# _get_chrome_profile.sh — Chrome profile directory for the ACTIVE workspace.
# Prints nothing if the workspace maps to no context. Used by
# browser-launcher.sh (Super+Shift+Return) so the browser opens the account
# that belongs to wherever you are.
#
# Thin consumer: the workspace/account table lives in nd-contexts, shared with
# goto-context, which needs the mapping the other way round. Do not reintroduce
# a local `case "$ws"` here -- that is how the two drift apart. (It had: the
# table claimed ws 7 was nd@team85.ch, an account with no Chrome profile at
# all, so Super+Shift+Return on workspace 7 silently opened Chrome's Default
# profile instead of Team85.)
set -euo pipefail

self_dir=$(dirname "$(readlink -f "$0")")

ws=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id')
email=$("$self_dir/nd-contexts" email-for-workspace "$ws")
[[ -n $email ]] || exit 0

# email -> profile directory via Chrome's own Local State, because Chrome
# renumbers profiles and a hardcoded number opens the wrong account.
jq -r --arg e "$email" \
  'first(.profile.info_cache | to_entries[] | select(.value.user_name == $e) | .key) // ""' \
  "$HOME/.config/google-chrome/Local State"
