#!/bin/bash

# Get a list of paired Bluetooth devices using bluetoothctl
device_list=$(bluetoothctl devices | awk '{print $2 " " substr($0, index($0,$3))}')

# Check if there are any devices
if [[ -z "$device_list" ]]; then
  notify-send "Bluetooth" "No devices found."
  exit 1
fi

# Use rofi to select a device
device_info=$(echo "$device_list" | rofi -dmenu -p "Select Bluetooth Device:")

# Check if a device was selected
if [[ -z "$device_info" ]]; then
  notify-send "Bluetooth" "No device selected."
  exit 1
fi

# Extract the device MAC address
device_mac=$(echo "$device_info" | awk '{print $1}')

echo "Connecting to $device_mac..."

# Connect to the selected device
bluetoothctl connect "$device_mac" && notify-send "Bluetooth" "Connected to $(echo "$device_info" | awk '{print substr($0, index($0,$2))}')" || notify-send "Bluetooth" "Failed to connect."
