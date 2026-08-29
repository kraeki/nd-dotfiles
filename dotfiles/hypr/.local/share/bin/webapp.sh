#!/usr/bin/env bash
#
# webapp.sh — launch-or-focus a Chrome web app window, pinned to a Chrome profile.
#
#   webapp.sh <profile|email|name> <url>
#
# Modelled on Omarchy's omarchy-launch-or-focus-webapp, with one addition this
# machine needs: the profile is pinned per web app instead of derived from the
# active workspace (browser-launcher.sh does that). A "work calendar" hotkey must
# always open the Roche profile, whatever workspace you happen to be on.
#
# Chrome names --app windows `chrome-<host>__<path>-<Profile_N>`, so the window
# class identifies both the site AND the account — two calendars from different
# profiles are distinct windows and each key focuses its own.
set -euo pipefail

browser=google-chrome-stable
state="$HOME/.config/google-chrome/Local State"

(($# >= 2)) || {
  echo "usage: webapp.sh <profile-dir|email|profile-name> <url>" >&2
  exit 1
}

profile_arg="$1"
url="$2"

# Accept a literal profile dir, or resolve an email / display name via Local
# State (survives Chrome renumbering profiles).
if [[ $profile_arg == Default || $profile_arg == Profile\ * ]]; then
  profile="$profile_arg"
else
  profile=$(jq -r --arg e "$profile_arg" \
    '.profile.info_cache | to_entries[]
     | select((.value.user_name == $e) or (.value.name == $e) or (.value.gaia_name == $e))
     | .key' "$state" 2>/dev/null | head -1)
fi

if [[ -z ${profile:-} ]]; then
  notify-send -u critical "webapp.sh" "No Chrome profile matching '$profile_arg'"
  exit 1
fi

host=${url#*://}
host=${host%%/*}
class="^chrome-${host//./\\.}.*-${profile// /_}$"

addr=$(hyprctl clients -j | jq -r --arg c "$class" \
  '.[] | select(.class | test($c)) | .address' | head -1)

if [[ -n $addr ]]; then
  hyprctl dispatch "hl.dsp.focus({ window = \"address:$addr\" })" >/dev/null
else
  exec setsid "$browser" "--profile-directory=$profile" --app="$url" >/dev/null 2>&1
fi
