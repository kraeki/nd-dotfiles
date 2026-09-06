#!/usr/bin/env bash
# nd-install TUI prototype B — "monolith".
# Full screen, one centered stack: the wordmark, a row of progress dots, the
# current question's title, and the prompt. Calm and focused — one thing at a
# time, hyprlock-like. Mock only; nothing runs, nothing is erased.
set -uo pipefail
T=6; P=3

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
    if   (( i <  $1 )); then out+="$(gum style --foreground $T "●") "
    elif (( i == $1 )); then out+="$(gum style --foreground $P "●") "
    else                     out+="$(gum style --faint "○") "
    fi
  done
  printf '%s' "${out% }"
}

draw() { # $1 step, $2 total, $3 title, $4 body — centered stack, cursor below
  clear
  echo
  gum style --align center --width 80 --foreground $T "$LOGO"
  echo
  gum style --align center --width 80 "$(dots "$1" "$2")    $(gum style --faint "step $1 of $2")"
  echo
  gum style --align center --width 80 --bold --foreground $P "$3"
  gum style --align center --width 80 --faint "$4"
  echo
}

draw 1 5 "what shall we call it" "this machine becomes your own config repo, ndos pinned as an input"
host=$(gum input --prompt "                                                    ❯ " --placeholder "hostname" --width 40)

draw 2 5 "who is the pilot" "your account — the password is set at the end, never stored"
user=$(gum input --prompt "                                                    ❯ " --placeholder "username" --width 40)

draw 3 5 "where does it live" "every byte on the chosen disk is erased, after one last confirmation"
disk=$(printf '/dev/nvme0n1  931G  Samsung SSD 990\n/dev/sda      3.6T  WD Elements' \
  | gum choose --cursor "❯ " --cursor.foreground $P | awk '{print $1}')

draw 5 5 "point of no return" "${host:-?} · ${user:-?} · ${disk:-?}
1G ESP + 32G encrypted swap + ~899G encrypted root"
gum confirm --default=false "ERASE ${disk:-disk}?" && msg="would install now" || msg="aborted — nothing touched"

clear; echo
gum style --align center --width 80 --foreground $T "$LOGO"
echo
gum style --align center --width 80 --bold "prototype B · $msg"
