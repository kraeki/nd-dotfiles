pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// Idle handling -- the hypridle this config never had (Omarchy 4 does the
// same inside its shell). After 4 min the laptop panel dims, after 5 min the
// screen locks (hyprlock), after 5.5 min every display goes dark; any input
// undoes the dim and wakes the displays. The lock stays until unlocked.
//
// "Stay awake" (bar / power panel) disables all three, and so does anything
// holding a Wayland idle inhibitor -- a playing video in Chrome, a
// presentation -- because the monitors respect inhibitors.
//
// Also locks *before* the machine sleeps (lid closed off the dock, suspend
// from the menu): a logind delay inhibitor holds the suspend for a moment
// while hyprlock comes up, the way hypridle's before_sleep_cmd does.
Singleton {
  id: root

  readonly property int dimAfter: 240      // seconds
  readonly property int lockAfter: 300
  readonly property int screenOffAfter: 330

  readonly property bool enabled: !ShellState.stayAwake

  function lock() {
    Quickshell.execDetached(["sh", "-c", "pidof hyprlock >/dev/null || exec hyprlock"])
  }

  IdleMonitor {
    enabled: root.enabled
    timeout: root.dimAfter
    respectInhibitors: true
    // -s saves the current level so -r can put it back exactly.
    onIsIdleChanged: Quickshell.execDetached(["sh", "-c", isIdle
      ? "brightnessctl -q -s && brightnessctl -q set 10%"
      : "brightnessctl -q -r"])
  }

  IdleMonitor {
    enabled: root.enabled
    timeout: root.lockAfter
    respectInhibitors: true
    onIsIdleChanged: if (isIdle) root.lock()
  }

  IdleMonitor {
    enabled: root.enabled
    timeout: root.screenOffAfter
    respectInhibitors: true
    onIsIdleChanged: Hyprland.dispatch(`hl.dsp.dpms({ action = "${isIdle ? "off" : "on"}" })`)
  }

  // --- lock before sleep ----------------------------------------------------
  // The inhibitor delays suspend (logind caps that at InhibitDelayMaxSec, 5s
  // by default) until it is released; it is re-taken after resume.
  Process {
    id: inhibitor
    running: true
    command: ["systemd-inhibit", "--what=sleep", "--mode=delay", "--who=nd-shell",
              "--why=Lock the screen before sleeping", "sleep", "infinity"]
  }

  Timer {
    id: release
    interval: 800      // long enough for hyprlock to map its surface
    onTriggered: inhibitor.running = false
  }

  // gdbus, not dbus-monitor: subscribing to broadcast signals needs no
  // privileges, whereas `dbus-monitor --system` wants to become a monitor,
  // which only root may. Lines look like
  //   /org/freedesktop/login1: org.freedesktop.login1.Manager.PrepareForSleep (true,)
  //   /org/freedesktop/login1/session/_32: org.freedesktop.login1.Session.Lock ()
  Process {
    running: true
    command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1"]
    stdout: SplitParser {
      onRead: line => {
        if (line.includes(".PrepareForSleep (true")) {
          root.lock()
          release.restart()
        } else if (line.includes(".PrepareForSleep (false")) {
          inhibitor.running = true
        } else if (line.includes(".Session.Lock ")) {
          // `loginctl lock-session`
          root.lock()
        }
      }
    }
  }
}
