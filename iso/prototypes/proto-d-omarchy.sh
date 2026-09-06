#!/usr/bin/env bash
# nd-install TUI prototype D — "omarchy".
# A faithful take on the Omarchy installer's look: the big wordmark up top, a
# two-line tagline, then — per step — an accent-coloured section label followed
# by a single unadorned gum list/prompt. No borders, no rail, no panels; gum
# draws its own pagination dots and "navigate · enter submit" footer, exactly
# like Omarchy. Mock flow only; nothing runs, nothing is erased.
#
# Robust pattern: the header is drawn to the terminal (never captured), and
# ONLY the gum prompt's result is assigned.
set -uo pipefail
A=6            # accent — teal, console palette slot 6 (Catppuccin teal)

# The wordmark master. On the ISO this is /etc/ndos-logo (see below); when run
# straight from a checkout it falls back to the repo copy.
LOGO_FILE="${ND_LOGO:-/etc/ndos-logo}"
[ -r "$LOGO_FILE" ] || LOGO_FILE="$(dirname "$0")/../../branding/logo.txt"

header() {
  clear
  gum style --foreground $A "$(cat "$LOGO_FILE")"
  echo
  gum style "Let's set up your machine..."
  gum style --faint "Press Ctrl+C to abort — nothing is erased before the final confirmation."
  echo
}

# The accent section label rides in gum's own --header, so there is no stray
# "Choose:" and the label sits with the list — Omarchy exactly.
pick() { # $1 label, then the options
  header
  gum choose --header "$1" --header.foreground $A \
    --cursor "> " --cursor.foreground $A --selected.foreground $A "${@:2}"
}
ask() { # $1 label, $2 placeholder
  header
  gum input --header "$1" --header.foreground $A \
    --prompt "> " --placeholder "$2" --width 44
}

kbd=$(pick "Select keyboard layout" \
  "English (US)" "English (UK)" "English (US, Dvorak)" "English (US, Colemak)" \
  "Azerbaijani" "Belarusian" "Belgian" "Bulgarian" "Croatian" "Czech" \
  "German" "German (Switzerland)" "Spanish" "French" || echo "English (US)")

mode=$(pick "What is this machine?" \
  "New machine — generate my own config repo" "naptop" "naptop-old")

host=$(ask "Hostname for this machine" "e.g. desktop")
user=$(ask "Your username" "e.g. kim")

header
tz=$(printf 'Europe/Zurich\nEurope/Berlin\nEurope/London\nAmerica/New_York\nAsia/Tokyo\nUTC' \
  | gum filter --header "Time zone" --header.foreground $A \
      --placeholder "type to search" --indicator "> " --indicator.foreground $A)

disk=$(pick "Install to which disk?  (it will be ERASED)" \
  "/dev/nvme0n1  931G  Samsung SSD 990" "/dev/sda  3.6T  WD Elements" | awk '{print $1}')

enc=$(pick "Disk encryption" "Use the same password as my login" "Set a separate passphrase")

header
gum style --foreground $A "Ready to install"
gum style "  $host · $user · $tz"
gum style "  $disk  —  1G ESP + 32G encrypted swap + rest encrypted root"
echo
gum confirm --default=false "ERASE $disk and install '$host'?" \
  && msg="would install now" || msg="aborted — nothing was touched"

header
gum style --foreground $A "$msg"
