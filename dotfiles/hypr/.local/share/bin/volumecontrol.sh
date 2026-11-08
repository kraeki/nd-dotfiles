#!/usr/bin/env sh

# Volume / mute for the media keys. No notification of its own: the
# quickshell OSD (dotfiles/quickshell/.config/quickshell/osd/Osd.qml) watches
# PipeWire and shows every change, from here or from anywhere else.
#
# Usage: volumecontrol.sh -o|-i <i|d|m> [step]
#   -o  output (default sink)     -i  input (default source)
#   i   +step% (default 5)        d   -step%        m   toggle mute

usage() {
  sed -n '/^# Usage:/,/^$/p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 1
}

case "$1" in
  -o) device=@DEFAULT_AUDIO_SINK@ ;;
  -i) device=@DEFAULT_AUDIO_SOURCE@ ;;
  *) usage ;;
esac
step="${3:-5}"

# Mute used to always hit the sink, so the mic-mute key muted the speakers.
case "$2" in
  i) wpctl set-volume "$device" "${step}%+" ;;
  d) wpctl set-volume "$device" "${step}%-" ;;
  m) wpctl set-mute "$device" toggle ;;
  *) usage ;;
esac
