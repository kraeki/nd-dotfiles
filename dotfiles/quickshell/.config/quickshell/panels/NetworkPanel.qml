import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services

// Connection facts from `net-status --verbose`, the speed test with live
// numbers, and the last runs on this access point (keyed by BSSID).
Popup {
  id: root

  onOpenChanged: if (open) Net.refreshDetails()

  readonly property var d: Net.details

  function fmt(v) { return v >= 100 ? Math.round(v).toString() : v.toFixed(1) }

  ColumnLayout {
    Layout.preferredWidth: 340
    spacing: 4

    RowLayout {
      spacing: 10
      Label { text: Net.icon; font.pixelSize: 26; color: Net.kind === "disconnected" ? Theme.red : Theme.accent }
      ColumnLayout {
        spacing: 0
        Label {
          heading: true
          text: Net.kind === "wifi" ? Net.name : Net.kind === "ethernet" ? "Ethernet" : "Offline"
          elide: Text.ElideRight
          Layout.fillWidth: true
        }
        Label {
          dim: true
          text: Net.kind === "wifi"
            ? [root.d.band, root.d.signal_dbm ? root.d.signal_dbm + " dBm" : "", Net.signal + "%", root.d.bitrate].filter(x => x).join("  ·  ")
            : Net.kind === "ethernet"
              ? [Net.name, root.d.speed ? root.d.speed + " Mbit/s" : "", root.d.duplex ? root.d.duplex + " duplex" : ""].filter(x => x).join("  ·  ")
              : "No route to the internet"
        }
      }
    }
  }

  GridLayout {
    visible: Net.iface !== ""
    columns: 2
    columnSpacing: 16
    rowSpacing: 3

    Label { dim: true; text: "Address" }
    Label { text: (root.d.ip ?? "?") + (root.d.prefix ? "/" + root.d.prefix : "") + "  (" + Net.iface + ")" }
    Label { dim: true; text: "Gateway" }
    Label { text: root.d.gateway ?? "?" }
    Label { dim: true; text: "Ping" }
    Label {
      text: [root.d.router_ping_ms ? "router " + root.d.router_ping_ms + " ms" : "",
             root.d.internet_ping_ms ? "internet " + root.d.internet_ping_ms + " ms" : ""].filter(x => x).join("   ") || "–"
    }
    Label { dim: true; text: "Live" }
    Label { text: "↓ " + Net.fmtRate(Net.down) + "  ↑ " + Net.fmtRate(Net.up) + " Mbit/s" }
    Label { dim: true; text: "AP"; visible: !!root.d.bssid }
    Label { text: (root.d.bssid ?? "") + (root.d.channel ? "  ch " + root.d.channel : ""); visible: !!root.d.bssid }
  }

  Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.surface0 }

  RowLayout {
    Layout.fillWidth: true
    Label { heading: true; text: "Speed test"; Layout.fillWidth: true }
    Button {
      text: Net.testing ? "Stop" : "Run"
      checked: !Net.testing
      onClicked: Net.testing ? Net.stopSpeedtest() : Net.runSpeedtest()
    }
  }

  GridLayout {
    visible: Net.testing || Net.testDone
    columns: 3
    columnSpacing: 10
    rowSpacing: 6

    Label { text: "↓"; color: Theme.accent; font.bold: true }
    Meter { Layout.fillWidth: true; Layout.preferredWidth: 220; value: Net.testDown / 1000; fill: Theme.accent }
    Label { text: root.fmt(Net.testDown) + " Mbit/s"; Layout.preferredWidth: 100; horizontalAlignment: Text.AlignRight; opacity: Net.testPhase === "up" || Net.testDone || Net.testPhase === "down" ? 1 : 0.4 }

    Label { text: "↑"; color: Theme.peach; font.bold: true }
    Meter { Layout.fillWidth: true; value: Net.testUp / 1000; fill: Theme.peach }
    Label { text: root.fmt(Net.testUp) + " Mbit/s"; Layout.preferredWidth: 100; horizontalAlignment: Text.AlignRight; opacity: Net.testPhase === "up" || Net.testDone ? 1 : 0.4 }
  }

  Label {
    visible: Net.testing
    dim: true
    text: Net.testPhase === "up" ? "Measuring upload…" : "Measuring download…"
  }

  ColumnLayout {
    visible: Net.history.length > 0
    spacing: 2
    Label { dim: true; text: "Previous runs on this access point" }
    Repeater {
      model: Net.history
      Label { required property string modelData; text: modelData; font.pixelSize: Theme.fontSmall + 1 }
    }
  }
}
