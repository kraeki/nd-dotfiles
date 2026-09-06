#!/usr/bin/env bash
# nd-install TUI prototype B — "monolith card".
# Full screen, everything inside ONE centered card: wordmark on top, progress
# dots, a single question at a time beneath. Calm, hyprlock-like. Mock only.
set -euo pipefail
T=6; P=3
W=$(tput cols); H=$(tput lines)

LOGO='███▄▄▄▄   ████████▄   ▄██████▄     ▄████████
███▀▀▀██▄ ███   ▀███ ███    ███   ███    ███
███   ███ ███    ███ ███    ███   ███    █▀
███   ███ ███    ███ ███    ███   ███
███   ███ ███    ███ ███    ███ ▀███████████
███   ███ ███    ███ ███    ███          ███
███   ███ ███   ▄███ ███    ███    ▄█    ███
 ▀█   █▀  ████████▀   ▀██████▀   ▄████████▀'

dots() { # $1 current (1-based), $2 total
  local out="" i
  for ((i=1;i<=$2;i++)); do
    if (( i < $1 )); then out+="$(gum style --foreground $T "●") "
    elif (( i == $1 )); then out+="$(gum style --foreground $P "●") "
    else out+="$(gum style --faint "○") "; fi
  done
  printf '%s' "$out"
}

card() { # $1 step, $2 total, $3 title, $4 body...
  clear
  local inner
  inner=$(gum join --vertical --align center \
    "$(gum style --foreground $T "$LOGO")" \
    " " \
    "$(dots "$1" "$2")   $(gum style --faint "step $1 of $2")" \
    " " \
    "$(gum style --bold --foreground $P "$3")" \
    "$(gum style --width 56 --align center "$4")")
  # center the card
  gum style --border rounded --border-foreground $T --padding "1 4" \
    --margin "$(( (H-24)/2 )) $(( (W-62)/2 ))" "$inner"
}

card 1 6 "who are you" "pick a hostname and a user — this becomes your own config repo"
tput cup $((H/2+7)) $(( W/2 - 20 ))
host=$(gum input --placeholder "hostname" --width 40)
card 3 6 "where do i live" "everything on the chosen disk will be erased,
after one final confirmation"
tput cup $((H/2+7)) $(( W/2 - 24 ))
disk=$(printf '/dev/nvme0n1  931G  Samsung SSD 990\n/dev/sda      3.6T  WD Elements' | gum choose --cursor.foreground $P | awk '{print $1}')
card 6 6 "point of no return" "ERASE $disk and install '$host'
1G ESP + 32G encrypted swap + ~899G encrypted root"
tput cup $((H/2+8)) $(( W/2 - 16 ))
gum confirm --default=false "ERASE $disk?" || true
clear; gum style --margin "2 4" --foreground $T "$LOGO"; gum style --margin "0 4" --bold "prototype B done"
