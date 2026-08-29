#!/usr/bin/env bash
#
# launch-or-focus.sh — focus a native app's window if it exists, else launch it.
#
#   launch-or-focus.sh <class-or-title-regex> <command> [args...]
#
# Native-app counterpart to webapp.sh (which does the same for Chrome --app
# windows). Modelled on Omarchy's omarchy-launch-or-focus.
set -euo pipefail

(($# >= 2)) || {
  echo "usage: launch-or-focus.sh <class-or-title-regex> <command> [args...]" >&2
  exit 1
}

pattern="$1"
shift

addr=$(hyprctl clients -j | jq -r --arg p "$pattern" \
  '.[] | select((.class | test($p; "i")) or (.title | test($p; "i"))) | .address' | head -1)

if [[ -n $addr ]]; then
  hyprctl dispatch "hl.dsp.focus({ window = \"address:$addr\" })" >/dev/null
else
  exec setsid "$@" >/dev/null 2>&1
fi
