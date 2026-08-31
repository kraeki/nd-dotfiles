#!/bin/sh
# Fired on lid OPEN (switch:off:Lid Switch in hyprland.lua).
#
# Re-enable the internal panel if it was disabled for clamshell docking.
# Idempotent, and the verify+retry (enabling from a just-resumed state can
# report "ok" without committing) lives in toggle-laptop-display.
exec "$HOME/.local/share/bin/toggle-laptop-display" on --quiet
