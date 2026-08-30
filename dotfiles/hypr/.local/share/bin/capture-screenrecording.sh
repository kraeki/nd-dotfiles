#!/usr/bin/env bash
# Start or stop a screen recording.
#
# Ported from Omarchy 4's omarchy-capture-screenrecording, reusing the same
# region picker as the screenshot path so the capture UX is identical.
#
# Trimmed relative to upstream: no webcam overlay (that needs v4l2-ctl, mpv and
# a whole overlay-resize subsystem) and no Omarchy bar indicator. The capture,
# audio, and post-processing paths are upstream's.
#
# Usage: capture-screenrecording.sh [--fullscreen] [--with-desktop-audio]
#                                   [--with-microphone-audio]
#                                   [--resolution=<WxH>] [--stop-recording]
#
# Env: SCREENRECORD_USE_PORTAL=true swaps the slurp picker for
# gpu-screen-recorder's xdg-desktop-portal backend (HDR, external-GPU monitors,
# window capture). Off by default: the portal path can fail EGL DMA-BUF
# modifier import on some configurations and then recording never starts.
# Env: SCREENRECORD_DEBUG=true appends gpu-screen-recorder's stderr to
# /tmp/screenrecord.log.

SRC_DIR="$(dirname "$(readlink -f "$0")")"
notify() { "$SRC_DIR/notification-send.sh" "$@"; }

OUTPUT_DIR="${SCREENRECORD_DIR:-$HOME/Videos}"
mkdir -p "$OUTPUT_DIR" || { notify -u critical -t 3000 "Cannot create recording directory: $OUTPUT_DIR"; exit 1; }

DESKTOP_AUDIO="false"
MICROPHONE_AUDIO="false"
RESOLUTION=""
FULLSCREEN="false"
STOP_RECORDING="false"
RECORDING_FILE="/tmp/screenrecord-filename"
LOG_FILE=$([[ ${SCREENRECORD_DEBUG:-false} == "true" ]] && echo "/tmp/screenrecord.log" || echo "/dev/null")

for arg in "$@"; do
  case "$arg" in
  --with-desktop-audio) DESKTOP_AUDIO="true" ;;
  --with-microphone-audio) MICROPHONE_AUDIO="true" ;;
  --resolution=*) RESOLUTION="${arg#*=}" ;;
  --fullscreen) FULLSCREEN="true" ;;
  --stop-recording) STOP_RECORDING="true" ;;
  esac
done

focused_monitor() {
  hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name'
}

default_resolution() {
  local width height
  read -r width height < <(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | "\(.width) \(.height)"')
  if ((width > 3840 || height > 2160)); then
    echo "3840x2160"
  else
    echo "0x0"
  fi
}

# Echoes "monitor:NAME" when the selection matches an entire monitor (prefer
# -w <monitor> over a region capture — same kms backend, but no scaling math
# and full native res), otherwise "region:WxH+X+Y". Returns non-zero if the
# user cancelled the picker.
select_capture_target() {
  local target
  target=$("$SRC_DIR/capture-region.sh" smart --match-monitor) || return 1

  if [[ $target == monitor:* ]]; then
    echo "$target"
    return
  fi

  [[ $target =~ ^(-?[0-9]+),(-?[0-9]+)[[:space:]]([0-9]+)x([0-9]+)$ ]] || return 1

  # gpu-screen-recorder wants region geometry in the compositor's logical
  # coordinate space — the same space slurp returns — so pass the values
  # through untouched. (gsr scales to physical pixels itself.)
  echo "region:${BASH_REMATCH[3]}x${BASH_REMATCH[4]}+${BASH_REMATCH[1]}+${BASH_REMATCH[2]}"
}

start_screenrecording() {
  local capture_args=()
  local target

  if [[ $FULLSCREEN == "true" ]]; then
    target="monitor:$(focused_monitor)"
    capture_args=(-w "${target#monitor:}" -s "${RESOLUTION:-$(default_resolution)}")
  elif [[ ${SCREENRECORD_USE_PORTAL:-false} == "true" ]]; then
    target="portal"
    capture_args=(-w portal -s "${RESOLUTION:-$(default_resolution)}")
  else
    target=$(select_capture_target) || return 1

    case $target in
    monitor:*)
      capture_args=(-w "${target#monitor:}" -s "${RESOLUTION:-$(default_resolution)}")
      ;;
    region:*)
      capture_args=(-w "${target#region:}")
      [[ -n $RESOLUTION ]] && capture_args+=(-s "$RESOLUTION")
      ;;
    esac
  fi

  local filename="$OUTPUT_DIR/screenrecording-$(date +'%y%m%d_%Hh%Mm%Ss').mp4"
  local audio_devices=""
  local audio_args=()

  [[ $DESKTOP_AUDIO == "true" ]] && audio_devices+="default_output"

  if [[ $MICROPHONE_AUDIO == "true" ]]; then
    # Merge into one track — separate tracks only play one at a time in most players.
    [[ -n $audio_devices ]] && audio_devices+="|"
    audio_devices+="default_input"
  fi

  [[ -n $audio_devices ]] && audio_args+=(-a "$audio_devices" -ac aac)

  echo "===== $(date '+%F %T') args: $* target: $target =====" >>"$LOG_FILE"
  gpu-screen-recorder "${capture_args[@]}" -k auto -f 60 -fm cfr -fallback-cpu-encoding yes -o "$filename" "${audio_args[@]}" 2>>"$LOG_FILE" &
  local pid=$!

  while kill -0 $pid 2>/dev/null && [[ ! -f $filename ]]; do
    sleep 0.2
  done

  if kill -0 $pid 2>/dev/null; then
    echo "$filename" >"$RECORDING_FILE"
    notify -g 󰑊 -t 2000 "Recording started" "Alt + Print to stop"
  else
    notify -u critical -t 5000 "Screen recording failed to start" "Set SCREENRECORD_DEBUG=true for a log"
  fi
}

stop_screenrecording() {
  pkill -SIGINT -f "^gpu-screen-recorder" # SIGINT required to save video properly

  # Wait a maximum of 5 seconds to finish before hard killing
  local count=0
  while pgrep -f "^gpu-screen-recorder" >/dev/null && ((count < 50)); do
    sleep 0.1
    count=$((count + 1))
  done

  if pgrep -f "^gpu-screen-recorder" >/dev/null; then
    pkill -9 -f "^gpu-screen-recorder"
    notify -u critical -t 5000 "Screen recording error" "Recording process had to be force-killed. Video may be corrupted."
  else
    finalize_recording
    local filename=$(cat "$RECORDING_FILE" 2>/dev/null)
    echo "$filename"
    local preview="${filename%.mp4}-preview.png"

    # Thumbnail from the first frame, for the notification.
    ffmpeg -y -i "$filename" -ss 00:00:00.1 -vframes 1 -q:v 2 "$preview" -loglevel quiet 2>/dev/null

    notify "Screen recording saved" "Click to play" \
      -t 10000 --image "${preview:-$filename}" \
      --exec xdg-open "$filename"

    # dunst loads the thumbnail when the toast appears and never re-reads it,
    # so the preview only has to outlive that load — not the toast.
    (
      sleep 2
      rm -f "$preview"
    ) &
  fi

  rm -f "$RECORDING_FILE"
}

screenrecording_active() {
  pgrep -f "^gpu-screen-recorder" >/dev/null
}

finalize_recording() {
  local latest
  latest=$(cat "$RECORDING_FILE" 2>/dev/null)
  [[ -f $latest ]] || return

  # Re-encode only when the first GOP contains discardable warmup packets — stream copy can't
  # trim those (it rewinds to the keyframe). Clean recordings stay on the fast stream-copy path.
  local video_codec=(-c:v copy)
  if ffprobe -v error -select_streams v:0 -read_intervals %+0.2 -show_entries packet=flags -of csv=p=0 "$latest" 2>/dev/null | grep -q D; then
    video_codec=(-c:v libx264 -preset veryfast -crf 20)
  fi

  # Trim the first frame, and normalize audio to -14 LUFS if present, in a single pass
  local args=(-y -ss 0.1 -i "$latest" "${video_codec[@]}")
  if ffprobe -v error -select_streams a -show_entries stream=codec_type -of csv=p=0 "$latest" 2>/dev/null | grep -q audio; then
    # Hard-mute the first 400ms to drop the PipeWire capture-open pop (a near-clipping
    # transient around 130-200ms that a gentle fade-in can't attenuate enough), then a
    # 50ms fade avoids a click at the boundary before loudnorm normalizes the rest.
    args+=(-af "volume=enable='lt(t,0.4)':volume=0,afade=t=in:st=0.4:d=0.05,loudnorm=I=-14:TP=-1.5:LRA=11")
  fi

  local processed="${latest%.mp4}-processed.mp4"
  if ffmpeg "${args[@]}" "$processed" -loglevel quiet 2>/dev/null; then
    mv "$processed" "$latest"
  else
    rm -f "$processed"
  fi
}

if screenrecording_active; then
  stop_screenrecording
elif [[ $STOP_RECORDING == "true" ]]; then
  exit 1
else
  start_screenrecording
fi
