#!/usr/bin/env bash
# Take a screenshot.
#
# Ported from Omarchy 4's omarchy-capture-screenshot. Adapted to this setup:
# shots land in ~/obsidian/Files with the YYMMDD_HHhMMmSSs_screenshot.png name
# the swappy config already uses, and swappy is the editor the notification
# opens (Omarchy ships tensaku-edit).
#
# Usage: capture-screenshot.sh [smart|region|windows|fullscreen] [slurp|copy|save]
#
#   smart (default)  drag a region, or click to snap to the window under it
#   region           freeform drag only
#   windows          snap to a window/monitor rectangle
#   fullscreen       the focused monitor, no picker
#
#   slurp (default)  save to file AND clipboard, with a clickable notification
#   copy             clipboard only
#   save             file only

SRC_DIR="$(dirname "$(readlink -f "$0")")"
OUTPUT_DIR="${SCREENSHOT_DIR:-$HOME/obsidian/Files}"

if [[ ! -d $OUTPUT_DIR ]]; then
  mkdir -p "$OUTPUT_DIR"
  "$SRC_DIR/notification-send.sh" "Created screenshot directory: $OUTPUT_DIR" -t 2000
fi

# A second press while the picker is up cancels it.
pkill slurp && exit 0

SCREENSHOT_EDITOR="${SCREENSHOT_EDITOR:-swappy}"

MODE="${1:-smart}"
PROCESSING="${2:-slurp}"

# The picker leaves the screen freeze running (PID on its first output line)
# so grim captures the frozen overlay rather than live content shifting
# during teardown.
#
# Software-composited cursors (Hyprland's fallback on GPUs without working
# hardware cursors) are baked into the frames grim captures, so force
# hardware cursors until after grim runs and restore the setting on exit.
NO_HW_CURSORS=$(hyprctl getoption cursor:no_hardware_cursors -j | jq '.int')

set_no_hw_cursors() {
  hyprctl eval "hl.config({ cursor = { no_hardware_cursors = $1 } })" &>/dev/null
}

cleanup() {
  [[ -n $FREEZE_PID ]] && kill $FREEZE_PID 2>/dev/null
  set_no_hw_cursors "$NO_HW_CURSORS"
}
trap cleanup EXIT

set_no_hw_cursors 0
{ read -r FREEZE_PID; read -r SELECTION; } < <("$SRC_DIR/capture-region.sh" "$MODE" --keep-freeze)

[[ -z $SELECTION ]] && exit 0

FILENAME="$(date +'%y%m%d_%Hh%Mm%Ss')_screenshot.png"
FILEPATH="$OUTPUT_DIR/$FILENAME"

case "$PROCESSING" in
  slurp)
    grim -g "$SELECTION" "$FILEPATH" || exit 1
    echo "$FILEPATH"
    wl-copy --type image/png <"$FILEPATH"

    # Best-effort: the screenshot is already saved and on the clipboard, so a
    # notification outage must not report the capture itself as failed.
    "$SRC_DIR/notification-send.sh" "Screenshot saved to clipboard and file" "Click to edit in ${SCREENSHOT_EDITOR##*/}" \
      --image "$FILEPATH" \
      --exec "$SCREENSHOT_EDITOR" -f "$FILEPATH" || true
    ;;
  copy)
    grim -g "$SELECTION" - | wl-copy --type image/png
    ;;
  save)
    grim -g "$SELECTION" "$FILEPATH" || exit 1
    echo "$FILEPATH"
    ;;
esac
