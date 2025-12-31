#!/usr/bin/env bash

browser=google-chrome-stable
profile=$($HOME/.local/share/bin/_get_chrome_profile.sh)

$browser "--profile-directory=${profile}" --new-window $1
