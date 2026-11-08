import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs

// This monitor's workspaces (waybar's all-outputs: false). Special
// workspaces -- the scratchpads -- have negative ids and are left out.
Item {
  id: root

  required property ShellScreen screen
  readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
  readonly property var items: Hyprland.workspaces.values
    .filter(w => w.id > 0 && w.monitor && root.monitor && w.monitor.name === root.monitor.name)
    .sort((a, b) => a.id - b.id)

  // Lua-config Hyprland: dispatch takes an hl.dsp expression; the legacy
  // "workspace N" text form is rejected (the reason waybar needed a pin).
  function focus(ws) {
    Hyprland.dispatch(`hl.dsp.focus({workspace="${ws}"})`)
  }

  implicitWidth: row.implicitWidth + 8
  implicitHeight: Theme.barHeight - 8

  Rectangle {
    anchors.fill: parent
    radius: height / 2
    color: Theme.alpha(Theme.surface0, 0.6)
  }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 2

    Repeater {
      model: root.items

      delegate: Rectangle {
        id: ws
        required property HyprlandWorkspace modelData
        readonly property bool shown: root.monitor?.activeWorkspace?.id === modelData.id
        readonly property bool occupied: modelData.toplevels.values.length > 0

        implicitHeight: Theme.barHeight - 14
        implicitWidth: shown ? 38 : 26
        radius: height / 2
        color: modelData.urgent ? Theme.red
             : shown ? Theme.accent
             : area.containsMouse ? Theme.surface1
             : "transparent"
        Behavior on implicitWidth { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 140 } }

        Text {
          anchors.centerIn: parent
          text: ws.modelData.id
          color: ws.shown || ws.modelData.urgent ? Theme.crust : Theme.text
          opacity: ws.shown || ws.occupied ? 1 : 0.5
          font.family: Theme.font
          font.pixelSize: Theme.fontSize
          font.bold: true
        }

        MouseArea {
          id: area
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.focus(ws.modelData.id)
        }
      }
    }
  }

  // Same relative steps the waybar module used. Deltas are accumulated to
  // one notch (120) per step, or a touchpad flick would skip ten workspaces.
  property real wheelAcc: 0
  WheelHandler {
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    onWheel: event => {
      root.wheelAcc += event.angleDelta.y
      while (Math.abs(root.wheelAcc) >= 120) {
        root.focus(root.wheelAcc > 0 ? "-1" : "+1")
        root.wheelAcc -= Math.sign(root.wheelAcc) * 120
      }
    }
  }
}
