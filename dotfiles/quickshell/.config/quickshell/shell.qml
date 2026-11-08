//@ pragma UseQApplication

// ndos desktop shell: bar, click panels, notifications and OSD in one
// Quickshell process. Replaces waybar + dunst + the notify-send OSD hack.
// Look and patterns borrowed from Omarchy 4's shell/ (MIT), written lean
// for this config -- see the Quickshell section of CLAUDE.md.
//
// Run: `qs` (Hyprland autostart). Restart: Ctrl+Alt+W. Logs: `qs log`.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.bar
import qs.notifications
import qs.osd
import qs.services

ShellRoot {
  Variants {
    model: Quickshell.screens
    delegate: Component {
      Bar {
        required property ShellScreen modelData
        screen: modelData
      }
    }
  }

  Toasts {}
  Osd {}

  // Quickshell credits every workspace switch to the focused monitor and
  // does not re-read the others; refresh so each bar's active workspace and
  // the workspace->monitor mapping stay true (from Omarchy's Workspaces.qml).
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      const n = event.name
      if (n === "workspacev2" || n === "moveworkspacev2" || n === "changeworkspaceid"
          || n === "createworkspacev2" || n === "destroyworkspacev2" || n === "monitoraddedv2") {
        Hyprland.refreshMonitors()
        Hyprland.refreshWorkspaces()
      }
    }
  }

  // Touch the services at startup: Quickshell initialises them lazily, and
  // UPower/the notification server/the tray need a moment to populate.
  Component.onCompleted: [Notifs.dnd, Sys.cpu, Net.kind]
}
