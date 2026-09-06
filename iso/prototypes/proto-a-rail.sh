#!/usr/bin/env bash
# nd-install TUI prototype A — "rail wizard".
# Full screen: teal header band, step rail on the left (done/current/todo),
# one bordered question panel on the right, key-hint footer. Mock flow only —
# nothing is executed; answers land in variables and the run ends on the
# summary screen.
set -euo pipefail
T=6   # teal      (Catppuccin console palette: color 6)
P=3   # peach-ish (console yellow slot)
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

STEPS=(network github machine identity storage encryption install)
declare -A LABEL=( [network]="Network" [github]="GitHub" [machine]="Machine"
  [identity]="Identity" [storage]="Storage" [encryption]="Encryption" [install]="Install" )

rail() { # $1 = index of current step
  local out="" i=0
  for s in "${STEPS[@]}"; do
    if   (( i <  $1 )); then out+=" $(gum style --foreground $T "✓ ${LABEL[$s]}")"$'\n'
    elif (( i == $1 )); then out+=" $(gum style --bold --foreground $P "▸ ${LABEL[$s]}")"$'\n'
    else                     out+=" $(gum style --faint "  ${LABEL[$s]}")"$'\n'; fi
    i=$((i+1))
  done
  gum style --border rounded --border-foreground $T --padding "1 2" --height 11 --width 18 "$out"
}

frame() { # $1 step-index, $2 panel-content
  clear
  gum style --foreground $T "$LOGO"
  printf '\n'
  gum join --horizontal --align top "$(rail "$1")" "  " "$2"
  # footer
  tput cup $((H-2)) 0
  gum style --faint " enter continue · esc back · ctrl+c abort — nothing is erased before the final confirmation"
}

panel() { # $1 title, $2 body
  gum style --border double --border-foreground $P --padding "1 3" --width $((W-30)) \
    "$(gum style --bold --foreground $P "$1")" "" "$2"
}

ask() { # $1 step-idx, $2 title, $3 prompt, $4 placeholder
  frame "$1" "$(panel "$2" "$3")"
  tput cup $((H-8)) 24
  gum input --placeholder "$4" --width 40
}

host=$(ask 2 "Machine" "This machine gets its own config repo, with the ndos distro pinned as a flake input." "hostname, e.g. desktop")
user=$(ask 3 "Identity" "Your account on $host. The password is set at the end of the install, never stored." "username")
frame 4 "$(panel "Storage" "Install to which disk? Everything on it will be erased — after one final confirmation.")"
tput cup $((H-9)) 24
disk=$(printf '/dev/nvme0n1  931G  Samsung SSD 990\n/dev/sda      3.6T  WD Elements' | gum choose --cursor.foreground $P | awk '{print $1}')
frame 6 "$(panel "Ready" "host $host · user $user · disk $disk
1G ESP + 32G encrypted swap + ~899G encrypted root")"
tput cup $((H-8)) 24
gum confirm --default=false "ERASE $disk and install '$host'?" && echo yes || true
clear; gum style --foreground $T "$LOGO"; gum style --bold "  prototype A done"
