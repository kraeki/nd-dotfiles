#!/bin/bash

# Get a list of audio output devices with descriptive names
devices=$(pactl list sinks | awk -F': ' '/Description/ {print $2}')

# Show the list in rofi and capture the selected device description
selected_device_desc=$(echo "$devices" | rofi -dmenu -i -p "Select Audio Output")

# Find the corresponding sink name for the selected description
selected_device=$(pactl list sinks | awk -v desc="$selected_device_desc" -F': ' '/Sink #/{sink=$2} /Description/ && $2==desc {print sink}')

# Check if a device was selected
if [ -n "$selected_device" ]; then
  # Set the selected device as the default
  pactl set-default-sink "$selected_device"

  # Move all currently playing streams to the selected device
  for stream in $(pactl list short sink-inputs | awk '{print $1}'); do
    pactl move-sink-input "$stream" "$selected_device"
  done

  notify-send "Audio Output Switched" "Now using: $selected_device_desc"
else
  notify-send "Audio Output Switcher" "No device selected."
fi
