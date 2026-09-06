#!/usr/bin/env bash
# nd-install TUI prototype A — "rail wizard".
# Full screen: teal wordmark on top, a step rail on the left (done ✓ / current ▸
# / todo) beside one bordered question panel, key-hint line, then the prompt.
# Mock flow only — nothing runs, nothing is erased; answers just fill variables.
#
# Robust pattern: the screen chrome is drawn to stdout (so it shows), and ONLY
# the gum prompt's result is captured — never wrap the drawing in $(...).
set -uo pipefail
T=6; P=3        # Catppuccin console palette: 6 = teal, 3 = peach/yellow slot

LOGO='
  ███▄▄▄▄   ████████▄   ▄██████▄     ▄████████
  ███▀▀▀██▄ ███   ▀███ ███    ███   ███    ███
  ███   ███ ███    ███ ███    ███   ███    █▀
  ███   ███ ███    ███ ███    ███   ███
  ███   ███ ███    ███ ███    ███ ▀███████████
  ███   ███ ███    ███ ███    ███          ███
  ███   ███ ███   ▄███ ███    ███    ▄█    ███
   ▀█   █▀  ████████▀   ▀██████▀   ▄████████▀'

STEPS=(Machine Identity Storage Encryption Install)

rail() { # $1 = index (0-based) of the current step
  local out="" i=0 s
  for s in "${STEPS[@]}"; do
    if   (( i <  $1 )); then out+="$(gum style --foreground $T "  ✓ $s")"$'\n'
    elif (( i == $1 )); then out+="$(gum style --bold --foreground $P "  ▸ $s")"$'\n'
    else                     out+="$(gum style --faint "    $s")"$'\n'
    fi
    i=$((i+1))
  done
  gum style --border rounded --border-foreground $T --padding "1 1" --width 18 "${out%$'\n'}"
}

panel() { # $1 title, $2 body
  gum style --border double --border-foreground $P --padding "1 3" --width 72 \
    "$(gum style --bold --foreground $P "$1")" "" "$2"
}

draw() { # $1 step-index, $2 title, $3 body — full-screen chrome, cursor left below
  clear
  gum style --foreground $T "$LOGO"
  echo
  gum join --horizontal --align top "$(rail "$1")" "  " "$(panel "$2" "$3")"
  echo
  gum style --faint "  enter continue · ctrl+c abort — nothing is erased before the final confirmation"
  echo
}

draw 0 "Machine" "This machine gets its own config repo, with the ndos distro pinned as a flake input."
host=$(gum input --prompt "  hostname ❯ " --placeholder "e.g. desktop" --width 44)

draw 1 "Identity" "Your account on ${host:-this machine}. The password is set at the end of the install, never stored in the repo."
user=$(gum input --prompt "  username ❯ " --placeholder "e.g. kim" --width 44)

draw 2 "Storage" "Install to which disk? Everything on it is erased — but only after one final confirmation."
disk=$(printf '/dev/nvme0n1  931G  Samsung SSD 990\n/dev/sda      3.6T  WD Elements' \
  | gum choose --cursor "  ▸ " --cursor.foreground $P | awk '{print $1}')

draw 4 "Ready" "host ${host:-?} · user ${user:-?} · disk ${disk:-?}

  1G ESP  +  32G encrypted swap  +  ~899G encrypted root"
gum confirm --default=false "  ERASE ${disk:-disk} and install '${host:-machine}'?" \
  && msg="would install now" || msg="aborted — nothing touched"

clear
gum style --foreground $T "$LOGO"
echo
gum style --bold --margin "0 2" "  prototype A · $msg"
