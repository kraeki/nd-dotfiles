import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs
import qs.services

// Battery detail, power profile and the stay-awake toggle in one place.
Popup {
  id: root

  readonly property UPowerDevice bat: UPower.displayDevice
  readonly property bool charging: bat.state === UPowerDeviceState.Charging
  readonly property bool discharging: bat.state === UPowerDeviceState.Discharging

  function duration(s) {
    if (!s || s <= 0 || s > 7 * 86400) return ""
    const h = Math.floor(s / 3600)
    const m = Math.round((s % 3600) / 60)
    return h > 0 ? `${h} h ${m} min` : `${m} min`
  }

  readonly property string stateText: {
    switch (bat.state) {
    case UPowerDeviceState.Charging: return "Charging" + (root.duration(bat.timeToFull) ? ", full in " + root.duration(bat.timeToFull) : "")
    case UPowerDeviceState.Discharging: return "On battery" + (root.duration(bat.timeToEmpty) ? ", " + root.duration(bat.timeToEmpty) + " left" : "")
    case UPowerDeviceState.FullyCharged: return "Fully charged"
    // Held at the charge limit (battery-charge-threshold in hosts/naptop).
    case UPowerDeviceState.PendingCharge: return "Plugged in, holding at the charge limit"
    default: return UPower.onBattery ? "On battery" : "Plugged in"
    }
  }

  ColumnLayout {
    Layout.preferredWidth: 320
    visible: root.bat.isLaptopBattery
    spacing: 6

    RowLayout {
      spacing: 10
      Label { text: Math.round(root.bat.percentage * 100) + "%"; font.pixelSize: 28; font.bold: true; color: Theme.accent }
      Label { text: root.stateText; dim: true; wrapMode: Text.WordWrap; Layout.fillWidth: true }
    }
    Meter {
      Layout.fillWidth: true
      implicitHeight: 8
      value: root.bat.percentage
      fill: root.bat.percentage < 0.2 && root.discharging ? Theme.red : Theme.accent
    }
    GridLayout {
      columns: 2
      columnSpacing: 16
      rowSpacing: 3
      Label { dim: true; text: root.charging ? "Charging at" : "Drawing" }
      Label { text: Math.abs(root.bat.changeRate).toFixed(1) + " W" }
      Label { dim: true; text: "Energy" }
      Label { text: root.bat.energy.toFixed(1) + " / " + root.bat.energyCapacity.toFixed(1) + " Wh" }
      Label { dim: true; text: "Health"; visible: root.bat.healthSupported }
      Label { text: Math.round(root.bat.healthPercentage) + "%"; visible: root.bat.healthSupported }
    }
  }

  Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.surface0; visible: root.bat.isLaptopBattery }

  Label { heading: true; text: "Power profile" }
  RowLayout {
    spacing: 6
    Button { text: "\uf06c  Saver"; checked: PowerProfiles.profile === PowerProfile.PowerSaver; onClicked: PowerProfiles.profile = PowerProfile.PowerSaver }
    Button { text: "\uf24e  Balanced"; checked: PowerProfiles.profile === PowerProfile.Balanced; onClicked: PowerProfiles.profile = PowerProfile.Balanced }
    Button {
      text: "\uf0e7  Performance"
      visible: PowerProfiles.hasPerformanceProfile
      checked: PowerProfiles.profile === PowerProfile.Performance
      onClicked: PowerProfiles.profile = PowerProfile.Performance
    }
  }

  RowLayout {
    Layout.fillWidth: true
    ColumnLayout {
      spacing: 0
      Label { text: "Stay awake" }
      Label { dim: true; text: "Inhibit idle while the bar is up" }
    }
    // A layout can only grow as wide as its widest child allows; the spacer
    // is what actually pushes the button to the edge.
    Item { Layout.fillWidth: true }
    Button { text: ShellState.stayAwake ? "On" : "Off"; checked: ShellState.stayAwake; onClicked: ShellState.stayAwake = !ShellState.stayAwake }
  }
}
