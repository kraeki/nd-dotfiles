#!/usr/bin/env bash
set -e

declare -i last_called=0
declare -i throttle_by=4

@throttle() {
  local -i now=$(date +%s)
  if (($now - $last_called > $throttle_by)); then
    # delay execution
    sleep $throttle_by
    # execute
    "$@"
  fi
  last_called=$(date +%s)
}

function arrange_workspaces() {
  # Maintain 10 workspaces across multiple monitors
  # This script assumes that the monitors are in horizontal layout and already
  # correctly setup
  monitors_json=$(hyprctl monitors -j)
  workspaces_json=$(hyprctl workspaces -j)

  monitors=($(echo $monitors_json | jq -r '. | sort_by(.x) | .[].name'))
  workspace_count=$(echo $workspaces_json | jq -r '. | length')
  active_workspaces=($(echo $monitors_json | jq -r '. | sort_by(.x) | .[].activeWorkspace.id'))

  echo "Detected ${#monitors[@]} monitors with $workspace_count workspaces and $(
    IFS=,
    echo ${active_workspaces[*]}
  ) active"

  # create or fix workspaces
  # this requires support for persistent workspaces
  # see https://github.com/hyprwm/Hyprland/pull/3346
  for ((i = 1; i <= 10; i++)); do
    workspace=$(echo $workspaces_json | jq -r ".[] | select(.id == $i)")
    if [ -z "$workspace" ]; then
      echo "Workspaces $i does not exist, creating it"
      hyprctl dispatch workspace $i >/dev/null
      hyprctl dispatch workspaceopt persistent >/dev/null
    else
      persistent=$(echo $workspace | jq -r ".persistent")
      if [ "$persistent" = false ]; then
        echo "Workspaces $i is not persistent, persisting it"
        hyprctl dispatch workspace $i >/dev/null
        hyprctl dispatch workspaceopt persistent >/dev/null
      fi
    fi
  done

  # assign and move workspaces
  if [[ "${#monitors[@]}" == 1 ]]; then
    for ((i = 10; i >= 1; i--)); do
      echo "Moving workspace $i to ${monitors[0]}"
      hyprctl keyword workspace "$i, monitor:${monitors[0]}" >/dev/null
      hyprctl dispatch moveworkspacetomonitor $i ${monitors[0]} >/dev/null
    done
  elif [[ "${#monitors[@]}" == 2 ]]; then
    for ((i = 10; i >= 6; i--)); do
      echo "Moving workspace $i to ${monitors[1]}"
      hyprctl keyword workspace "$i, monitor:${monitors[1]}" >/dev/null
      hyprctl dispatch moveworkspacetomonitor $i ${monitors[1]} >/dev/null
    done
    hyprctl dispatch workspace 6 >/dev/null
    for ((i = 5; i >= 1; i--)); do
      echo "Moving workspace $i to ${monitors[0]}"
      hyprctl keyword workspace "$i, monitor:${monitors[0]}" >/dev/null
      hyprctl dispatch moveworkspacetomonitor $i ${monitors[0]} >/dev/null
    done
  elif [[ "${#monitors[@]}" == 3 ]]; then
    for ((i = 10; i >= 8; i--)); do
      echo "Moving workspace $i to ${monitors[2]}"
      hyprctl keyword workspace "$i, monitor:${monitors[2]}" >/dev/null
      hyprctl dispatch moveworkspacetomonitor $i ${monitors[2]} >/dev/null
    done
    for ((i = 7; i >= 4; i--)); do
      echo "Moving workspace $i to ${monitors[1]}"
      hyprctl keyword workspace "$i, monitor:${monitors[1]}" >/dev/null
      hyprctl dispatch moveworkspacetomonitor $i ${monitors[1]} >/dev/null
    done
    for ((i = 3; i >= 1; i--)); do
      echo "Moving workspace $i to ${monitors[0]}"
      hyprctl keyword workspace "$i, monitor:${monitors[0]}" >/dev/null
      hyprctl dispatch moveworkspacetomonitor $i ${monitors[0]} >/dev/null
    done
  else # more than 3 monitors...
    echo "Too many monitors"
  fi
  for id in "${active_workspaces[@]}"; do
    echo "Activating workspace $id"
    hyprctl dispatch workspace $id >/dev/null
  done
}

function configure_monitors() {
  # rely an kanshi for profile detection and output configuration
  # see https://todo.sr.ht/~emersion/kanshi/54#event-235509
  echo "Configuring monitors..."
  kanshi >/dev/null 2>&1 &
  sleep 1
  killall kanshi

  # arrange workspaces to match the new configuration
  #echo "Configuring workspaces..."
  #arrange_workspaces
}

function handle {
  if [[ ${1:0:12} == "monitoradded" ]]; then
    echo "Event detected: monitor added"
    @throttle configure_monitors
  elif [[ ${1:0:14} == "monitorremoved" ]]; then
    echo "Event detected: monitor removed"
    @throttle configure_monitors
  fi
}

cli_help() {
  cli_name=${0##*/}
  echo "
$cli_name
Hyprland monitors control
Usage: $cli_name [command]
Commands:
  configure_monitors    Configure monitors using kanshi
  arrange_workspaces    Arrange workspaces on monitors
  listen    Listen for hypr monitor events and arrange workspaces automatically
  *         Help
"
  exit 1
}

case "$1" in
configure_monitors)
  configure_monitors
  ;;
arrange_workspaces)
  arrange_workspaces
  ;;
listen)
  echo "Listening to monitor events..."
  socat - UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock | while read line; do handle $line; done

  ;;
*)
  cli_help
  ;;
esac
