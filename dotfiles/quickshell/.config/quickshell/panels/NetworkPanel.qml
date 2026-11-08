import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import qs
import qs.services

// Connection facts from `net-status --verbose`, the speed test with live
// numbers, and the last runs on this access point (keyed by BSSID).
Popup {
  id: root

  fixedWidth: Theme.cardWidth

  readonly property var d: Net.details

  // --- Wi-Fi list (Quickshell's NetworkManager backend) ---------------------
  // nm-applet keeps running, tray icon hidden: it is still the secret agent
  // for 802.1X / VPN prompts, which this list does not handle.
  readonly property var wifi: Networking.devices.values.find(dev => dev.type === DeviceType.Wifi) ?? null
  readonly property var networks: {
    if (!root.wifi) return []
    const seen = {}
    return root.wifi.networks.values
      .filter(n => n.name && !seen[n.name] && (seen[n.name] = true))
      .sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength))
      .slice(0, 8)
  }
  property var askingPsk: null       // the network whose password row is open

  // Scan only while the panel is open. The flag is shared, not ref-counted,
  // so it is switched off again on close.
  onOpenChanged: {
    if (open) Net.refreshDetails()
    if (root.wifi) root.wifi.scannerEnabled = open
    if (!open) root.askingPsk = null
  }

  function secured(n) {
    return n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe
  }
  function enterprise(n) {
    return n.security === WifiSecurityType.Wpa2Eap || n.security === WifiSecurityType.WpaEap
        || n.security === WifiSecurityType.Wpa3SuiteB192
  }
  function bars(n) {
    const s = n.signalStrength <= 1 ? n.signalStrength * 100 : n.signalStrength
    return ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"][Math.min(4, Math.floor(s / 21))]
  }
  function activate(n) {
    if (n.connected) n.disconnect()
    else if (n.known || !root.secured(n)) n.connect()
    // Enterprise networks need more than a passphrase; nm-applet's dialog.
    else if (root.enterprise(n)) n.connect()
    else root.askingPsk = (root.askingPsk === n ? null : n)
  }

  function fmt(v) { return v >= 100 ? Math.round(v).toString() : v.toFixed(1) }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: 4

    RowLayout {
      spacing: 10
      Label { text: Net.icon; font.pixelSize: Theme.fontDisplay; color: Net.kind === "disconnected" ? Theme.red : Theme.accent }
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

  Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.surface0; visible: root.wifi !== null }

  RowLayout {
    Layout.fillWidth: true
    visible: root.wifi !== null
    Label { heading: true; text: "Wi-Fi"; Layout.fillWidth: true }
    Button {
      text: Networking.wifiEnabled ? "On" : "Off"
      checked: Networking.wifiEnabled
      onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
    }
  }

  Repeater {
    model: Networking.wifiEnabled ? root.networks : []
    delegate: ColumnLayout {
      id: netRow
      required property var modelData
      Layout.fillWidth: true
      spacing: 4

      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 30
        radius: Theme.radius
        color: wArea.containsMouse ? Theme.surface0 : "transparent"
        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 8
          anchors.rightMargin: 8
          spacing: 8
          Label { text: root.bars(netRow.modelData); color: netRow.modelData.connected ? Theme.accent : Theme.subtext0 }
          Label {
            text: netRow.modelData.name
            color: netRow.modelData.connected ? Theme.text : Theme.subtext0
            font.bold: netRow.modelData.connected
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
          Label {
            dim: true
            text: netRow.modelData.stateChanging ? "…"
              : wArea.containsMouse ? (netRow.modelData.connected ? "Disconnect" : "Connect")
              : (root.secured(netRow.modelData) ? "󰌾" : "") + (netRow.modelData.known ? " saved" : "")
          }
        }
        MouseArea {
          id: wArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.activate(netRow.modelData)
        }
      }

      // Passphrase for a new WPA network.
      Rectangle {
        visible: root.askingPsk === netRow.modelData
        Layout.fillWidth: true
        implicitHeight: 32
        radius: Theme.radius
        color: Theme.surface0
        border.width: 1
        border.color: psk.activeFocus ? Theme.accent : Theme.surface1
        TextInput {
          id: psk
          anchors.fill: parent
          anchors.leftMargin: 10
          anchors.rightMargin: 10
          verticalAlignment: TextInput.AlignVCenter
          echoMode: TextInput.Password
          color: Theme.text
          font.family: Theme.font
          font.pixelSize: Theme.fontSize
          clip: true
          onVisibleChanged: if (visible) { text = ""; forceActiveFocus() }
          onAccepted: {
            netRow.modelData.connectWithPsk(text)
            root.askingPsk = null
          }
          Keys.onEscapePressed: root.askingPsk = null
        }
        Label {
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: parent.left
          anchors.leftMargin: 10
          visible: psk.text === ""
          dim: true
          text: "Password, then Enter"
        }
      }
    }
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
      Label { required property string modelData; text: modelData; font.pixelSize: Theme.fontSmall }
    }
  }
}
