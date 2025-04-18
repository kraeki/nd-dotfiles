#!/bin/bash

# Build sink list with index and description
sink_info=$(pactl list sinks | awk '
  /^Sink #/ {
    match($0, /Sink #([0-9]+)/, m)
    sink_index = m[1]
  }
  /^\s*Description:/ {
    desc = substr($0, index($0,$2))
    print sink_index "|" desc
  }
')

# Show descriptions via rofi
selected_desc=$(echo "$sink_info" | cut -d'|' -f2- | rofi -dmenu -i -p "Select Audio Output")

# Match description back to index
set -x
selected_sink=$(echo "$sink_info" | while IFS='|' read -r index desc; do
  if [ "$desc" = "$selected_desc" ]; then
    echo "$index"
    break
  fi
done)
set +x

# Switch output
if [ -n "$selected_sink" ]; then
  pactl set-default-sink "$selected_sink"
  for input in $(pactl list short sink-inputs | awk '{print $1}'); do
    pactl move-sink-input "$input" "$selected_sink"
  done
  notify-send "Audio Output Switched" "Now using: $selected_desc"
else
  notify-send "Audio Output Switcher" "No device selected."
fi
