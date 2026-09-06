#!/usr/bin/env bash
# nd-install TUI prototype C — "mission control".
# archinstall-style: full screen with the wordmark up top and a live SUMMARY
# of every answer. You pick any row to (re)edit, in any order; the Install row
# unlocks when everything is answered. One screen owns the whole flow. Mock.
set -euo pipefail
T=6; P=3; R=1
W=$(tput cols); H=$(tput lines)

LOGO='
  ███▄▄▄▄   ████████▄   ▄██████▄     ▄████████
  ███▀▀▀██▄ ███   ▀███ ███    ███   ███    ███
  ███   ███ ███    ███ ███    ███   ███    █▀
  ███   ███ ███    ███ ███    ███   ███
  ███   ███ ███    ███ ███    ███ ▀███████████
  ███   ███ ███    ███ ███    ███          ███
  ███   ███ ███   ▄███ ███    ███    ▄█    ███
   ▀█   █▀  ████████▀   ▀██████▀   ▄████████▀'

host="" user="" tz="Europe/Zurich" disk="" enc="same as password"

row() { # $1 label, $2 value
  local v
  if [ -n "$2" ]; then v=$(gum style --foreground $T "$2"); else v=$(gum style --faint "— not set"); fi
  printf '%-14s %s' "$1" "$v"
}

screen() {
  clear
  gum style --foreground $T "$LOGO"
  gum style --margin "0 2" --faint "your machine, as it will be installed — pick a row to change it"
  echo
}

while :; do
  screen
  ready=""
  [ -n "$host" ] && [ -n "$user" ] && [ -n "$disk" ] && ready=1
  install_row=$([ -n "$ready" ] && gum style --bold --foreground $P "⏻  Install now" || gum style --faint "⏻  Install (answer everything first)")
  choice=$(printf '%s\n' \
      "$(row "  hostname" "$host")" \
      "$(row "  user" "$user")" \
      "$(row "  time zone" "$tz")" \
      "$(row "  disk" "$disk")" \
      "$(row "  encryption" "$enc")" \
      "$install_row" \
    | gum choose --height 9 --cursor "▸ " --cursor.foreground $P | sed 's/\x1b\[[0-9;]*m//g')
  case "$choice" in
    *hostname*)  host=$(gum input --placeholder hostname --prompt "hostname ❯ ");;
    *user*)      user=$(gum input --placeholder username --prompt "user ❯ ");;
    *"time zone"*) tz=$(printf 'Europe/Zurich\nEurope/Berlin\nUTC' | gum filter);;
    *disk*)      disk=$(printf '/dev/nvme0n1  931G  Samsung SSD 990\n/dev/sda  3.6T  WD Elements' | gum choose | awk '{print $1}');;
    *encryption*) enc=$(printf 'same as password\nseparate passphrase' | gum choose);;
    *Install*)
      [ -n "$ready" ] || continue
      screen
      gum style --border thick --border-foreground $R --padding "1 3" --margin "0 2" \
        "$(gum style --bold --foreground $R "ERASE $disk")" \
        "host $host · user $user · $tz" \
        "1G ESP + 32G encrypted swap + ~899G encrypted root"
      gum confirm --default=false "Destroy everything on $disk and install?" && break || true;;
  esac
done
clear; gum style --foreground $T "$LOGO"; gum style --margin "0 2" --bold "prototype C done"
