#!/bin/bash

# Check if wl-clipboard is installed
if ! command -v wl-copy &>/dev/null || ! command -v wl-paste &>/dev/null; then
	logger "wl-clipboard could not be found, please install it using 'sudo pacman -S wl-clipboard'"
	exit
fi

# Define the program to process the text
PROCESSING_PROGRAM="wc"

wtype -P ctrl -p c

# Copy the selected text
SELECTED_TEXT=$(wl-paste)

# Check if something is selected
if [ -z "$SELECTED_TEXT" ]; then
	logger "No text selected."
	exit
fi

logger $SELECTED_TEXT

# Run the selected text through the processing program
PROCESSED_TEXT=$(echo "$SELECTED_TEXT" | $PROCESSING_PROGRAM)

# Replace the selected text with the processed text
echo -n "$PROCESSED_TEXT" | wl-copy

logger "Selected text processed and replaced."
