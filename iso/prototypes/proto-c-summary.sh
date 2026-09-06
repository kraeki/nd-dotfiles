#!/usr/bin/env bash
# nd-install TUI prototype C — "mission control".
# archinstall-style: the wordmark up top and a live summary of every answer on
# one screen. Pick any row to (re)set it, in any order; the Install row unlocks
# once hostname, user and disk are answered. One screen owns the whole flow.
# Mock only; nothing runs, nothing is erased.
set -uo pipefail
T=6; P=3; R=1   # 1 = red slot

LOGO='
  ███▄▄▄▄   ████████▄   ▄██████▄     ▄████████
  ███▀▀▀██▄ ███   ▀███ ███    ███   ███    ███
  ███   ███ ███    ███ ███    ███   ███    █▀
  ███   ███ ███    ███ ███    ███   ███
  ███   ███ ███    ███ ███    ███ ▀███████████
  ███   ███ ███    ███ ███    ███          ███
  ███   ███ ███   ▄███ ███    ███    ▄█    ███
   ▀█   █▀  ████████▀   ▀██████▀   ▄████████▀'

host="" user="" tz="Europe/Zurich" disk="" enc="same as login password"

field() { # $1 label, $2 value  -> "  label        value|— not set"
  local v
  if [ -n "$2" ]; then v=$(gum style --foreground $T "$2"); else v=$(gum style --faint "— not set"); fi
  printf '  %-13s%s' "$1" "$v"
}

draw() {
  clear
  gum style --foreground $T "$LOGO"
  gum style --margin "0 2" --faint "your machine, as it will be installed — pick a row to change it, then Install"
  echo
}

while :; do
  draw
  ready=""; [ -n "$host" ] && [ -n "$user" ] && [ -n "$disk" ] && ready=1
  if [ -n "$ready" ]; then
    install_row="$(gum style --bold --foreground $P "⏻  Install now")"
  else
    install_row="$(gum style --faint "⏻  Install  (set hostname, user and disk first)")"
  fi
  choice=$(printf '%s\n' \
      "$(field hostname   "$host")" \
      "$(field user       "$user")" \
      "$(field "time zone" "$tz")" \
      "$(field disk       "$disk")" \
      "$(field encryption "$enc")" \
      "$install_row" \
    | gum choose --height 8 --cursor "  ▸ " --cursor.foreground $P)
  case "$choice" in
    *hostname*)   host=$(gum input --prompt "hostname ❯ " --placeholder "e.g. desktop" --width 40);;
    *user*)       user=$(gum input --prompt "user ❯ "     --placeholder "e.g. kim" --width 40);;
    *"time zone"*) tz=$(printf 'Europe/Zurich\nEurope/Berlin\nAmerica/New_York\nUTC' | gum filter --placeholder "type to search");;
    *disk*)       disk=$(printf '/dev/nvme0n1  931G  Samsung SSD 990\n/dev/sda      3.6T  WD Elements' | gum choose | awk '{print $1}');;
    *encryption*) enc=$(printf 'same as login password\nseparate passphrase' | gum choose);;
    *Install*)
      [ -n "$ready" ] || continue
      draw
      gum style --border thick --border-foreground $R --padding "1 3" --margin "0 2" \
        "$(gum style --bold --foreground $R "ERASE $disk")" \
        "$host · $user · $tz" \
        "1G ESP + 32G encrypted swap + ~899G encrypted root"
      gum confirm --default=false "Destroy everything on $disk and install?" && break || true;;
  esac
done
clear; gum style --foreground $T "$LOGO"; gum style --margin "0 2" --bold "prototype C · would install now"
