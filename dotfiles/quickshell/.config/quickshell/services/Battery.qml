pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Battery warnings, replacing batterynotify.sh -- a HyDE leftover whose
// thresholds came from a hyde.conf that no longer exists. Sent through
// notify-send so they land in the normal toast/history path, with a stack
// tag so a newer state replaces an older one instead of piling up.
//
// The hard floor is not here: upower suspends/hibernates at its own critical
// level (modules/nixos/power.nix).
Singleton {
  id: root

  readonly property UPowerDevice bat: UPower.displayDevice
  readonly property bool present: bat.isLaptopBattery
  readonly property int pct: Math.round(bat.percentage * 100)
  readonly property bool discharging: bat.state === UPowerDeviceState.Discharging

  readonly property int lowAt: 20
  readonly property int criticalAt: 10

  // Last level warned about, so each threshold fires once per discharge.
  property int warned: 101
  property bool primed: false

  function notify(urgency, summary, body) {
    Quickshell.execDetached(["notify-send", "-a", "Power", "-u", urgency,
      "-h", "string:x-canonical-private-synchronous:battery", "-i", "battery", summary, body])
  }

  onPctChanged: root.check()

  function check() {
    if (!root.present || !root.discharging) return
    if (root.pct <= root.criticalAt && root.warned > root.criticalAt) {
      root.warned = root.criticalAt
      root.notify("critical", "Battery critically low", root.pct + "% left. Plug in now.")
    } else if (root.pct <= root.lowAt && root.warned > root.lowAt) {
      root.warned = root.lowAt
      root.notify("normal", "Battery low", root.pct + "% left. Connect the charger.")
    }
  }

  // Plugging in / unplugging. Not on startup: UPower reports the initial state
  // as a change once it has loaded.
  Timer { interval: 5000; running: true; onTriggered: root.primed = true }
  Connections {
    target: UPower
    function onOnBatteryChanged() {
      if (!root.primed || !root.present) return
      if (UPower.onBattery) {
        root.notify(root.pct <= root.lowAt ? "critical" : "low", "On battery", root.pct + "%")
        root.check()
      } else {
        root.warned = 101
        root.notify("low", "Charger connected", root.pct + "%")
      }
    }
  }
}
