#!/usr/bin/env bash
# The slice of Omarchy 4's omarchy-notification-send that the capture scripts
# rely on: an optional thumbnail and a clickable action that runs a command.
# Backed by dunstify, since dunst is this setup's notification daemon.
#
# Usage: notification-send.sh [-u urgency] [-t ms] [-g glyph] [--image PATH]
#                             [--exec CMD [ARGS...]] SUMMARY [BODY]
#
# --exec swallows the rest of the argv, so it has to come last. dunstify blocks
# for as long as the notification is on screen once -A is passed, so the click
# handler is detached; without --exec this is fire-and-forget.

urgency=normal
timeout=5000
glyph=""
image=""
exec_cmd=()
args=()

while (( $# )); do
  case "$1" in
    -u) urgency="${2:-normal}"; shift 2 ;;
    -t) timeout="${2:-5000}"; shift 2 ;;
    -g) glyph="${2:-}"; shift 2 ;;
    --image) image="${2:-}"; shift 2 ;;
    --exec) shift; exec_cmd=("$@"); break ;;
    *) args+=("$1"); shift ;;
  esac
done

summary="${args[0]:-}"
body="${args[1]:-}"
[[ -n $glyph ]] && summary="$glyph  $summary"

opts=(-a screenshot -u "$urgency" -t "$timeout")
[[ -n $image ]] && opts+=(-i "$image")

if (( ${#exec_cmd[@]} )); then
  # Omarchy writes `--exec mpv -- file`; drop that bare separator.
  [[ ${exec_cmd[1]:-} == "--" ]] && exec_cmd=("${exec_cmd[0]}" "${exec_cmd[@]:2}")

  (
    [[ $(dunstify "${opts[@]}" -A "default,Open" "$summary" "$body" 2>/dev/null) == default ]] &&
      exec "${exec_cmd[@]}"
  ) >/dev/null 2>&1 &
  disown
else
  dunstify "${opts[@]}" "$summary" "$body" >/dev/null 2>&1
fi
