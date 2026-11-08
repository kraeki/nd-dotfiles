import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs

// Adapter power, paired devices (connect / disconnect, battery where the
// device reports it), and a scan for new ones. Pairing confirmations that
// need a PIN still come from blueman-applet, which keeps running as the
// BlueZ agent with its tray icon hidden (see bar/Tray.qml).
Popup {
  id: root

  fixedWidth: Theme.cardWidth

  readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
  readonly property var devices: (adapter?.devices.values ?? [])
    .filter(d => d.paired || d.connected || root.adapter.discovering)
    .sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))

  // Scanning only while the panel is open; it costs radio time and battery.
  onOpenChanged: if (!open && adapter?.discovering) adapter.discovering = false

  function glyph(d) {
    const i = d.icon || ""
    if (i.includes("headset") || i.includes("headphone")) return "󰋋"
    if (i.includes("keyboard")) return "󰌌"
    if (i.includes("mouse")) return "󰍽"
    if (i.includes("phone")) return "󰏲"
    if (i.includes("audio") || i.includes("speaker")) return "󰓃"
    return "󰂯"
  }

  RowLayout {
    Layout.fillWidth: true
    Label { heading: true; text: "Bluetooth"; Layout.fillWidth: true }
    Button {
      visible: root.adapter?.enabled ?? false
      text: root.adapter?.discovering ? "Scanning…" : "Scan"
      checked: root.adapter?.discovering ?? false
      onClicked: root.adapter.discovering = !root.adapter.discovering
    }
    Button {
      text: root.adapter?.enabled ? "On" : "Off"
      checked: root.adapter?.enabled ?? false
      onClicked: if (root.adapter) root.adapter.enabled = !root.adapter.enabled
    }
  }

  Label {
    visible: !root.adapter
    dim: true
    text: "No Bluetooth adapter."
  }

  Label {
    visible: (root.adapter?.enabled ?? false) && root.devices.length === 0
    dim: true
    text: "No paired devices. Scan to find one."
  }

  Repeater {
    model: root.adapter?.enabled ? root.devices : []
    delegate: Rectangle {
      id: row
      required property BluetoothDevice modelData
      readonly property bool busy: modelData.pairing
        || modelData.state === BluetoothDeviceState.Connecting
        || modelData.state === BluetoothDeviceState.Disconnecting

      Layout.fillWidth: true
      implicitHeight: 40
      radius: Theme.radius
      color: rowArea.containsMouse ? Theme.surface0 : "transparent"

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 10
        Label {
          text: root.glyph(row.modelData)
          font.pixelSize: Theme.iconSize + 2
          color: row.modelData.connected ? Theme.accent : Theme.subtext0
        }
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0
          Label { text: row.modelData.name || row.modelData.address; elide: Text.ElideRight; Layout.fillWidth: true }
          Label {
            dim: true
            text: row.busy ? "…"
              : row.modelData.connected ? "Connected" + (row.modelData.batteryAvailable ? " · " + Math.round(row.modelData.battery * 100) + "%" : "")
              : row.modelData.paired ? "Paired" : "Not paired"
          }
        }
        Label {
          text: row.modelData.connected ? "Disconnect" : row.modelData.paired ? "Connect" : "Pair"
          dim: true
          visible: rowArea.containsMouse && !row.busy
        }
      }

      MouseArea {
        id: rowArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          const d = row.modelData
          if (row.busy) return
          if (d.connected) d.disconnect()
          else if (d.paired) d.connect()
          else { d.trusted = true; d.pair() }
        }
      }
    }
  }
}
