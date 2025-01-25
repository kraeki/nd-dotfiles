#!/bin/bash

# Get a list of available Wi-Fi networks with details
wifi_list=$(nmcli -t -f SSID,SIGNAL,FREQ,BARS,SECURITY dev wifi | sort -t: -k2 -nr)

# Check if any networks are available
if [ -z "$wifi_list" ]; then
  notify-send "Wi-Fi Selector" "No Wi-Fi networks found."
  exit 1
fi

# Use rofi to display the list and select a network
selected_line=$(echo "$wifi_list" | rofi -dmenu -p "Select Wi-Fi")

# Exit if no network was selected
if [ -z "$selected_line" ]; then
  exit 1
fi

# Extract the selected network's SSID and security type
selected_network=$(echo "$selected_line" | cut -d: -f1)
security=$(echo "$selected_line" | cut -d: -f5)

# Prompt for the Wi-Fi password if security is enabled
if [[ "$security" != "--" ]]; then
  password=$(rofi -dmenu -password -p "Enter password for $selected_network")
  if [ -z "$password" ]; then
    notify-send "Wi-Fi Selector" "Password cannot be empty for $selected_network."
    exit 1
  fi

  # Connect to the selected network
  if nmcli dev wifi connect "$selected_network" password "$password"; then
    notify-send "Wi-Fi Selector" "Connected to $selected_network."
  else
    notify-send "Wi-Fi Selector" "Failed to connect to $selected_network."
  fi
else
  # Connect to an open network
  if nmcli dev wifi connect "$selected_network"; then
    notify-send "Wi-Fi Selector" "Connected to $selected_network (Open Network)."
  else
    notify-send "Wi-Fi Selector" "Failed to connect to $selected_network."
  fi
fi
