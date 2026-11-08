import QtQuick
import qs

// Drag or click to set, wheel to nudge. `value` is 0..1; emits `moved` with
// the new value and leaves storing it to the owner (PipeWire round-trips).
Item {
  id: root

  property real value: 0
  property bool muted: false
  signal moved(real value)

  implicitHeight: 20
  implicitWidth: 200

  function at(x) { return Math.max(0, Math.min(1, x / width)) }

  Rectangle {
    id: track
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width
    height: 6
    radius: 3
    color: Theme.surface0

    Rectangle {
      width: Math.max(track.height, track.width * Math.min(1, root.value))
      height: parent.height
      radius: parent.radius
      color: root.muted ? Theme.overlay0 : Theme.accent
    }
  }

  Rectangle {
    x: Math.min(1, root.value) * (root.width - width)
    anchors.verticalCenter: parent.verticalCenter
    width: 14
    height: 14
    radius: 7
    color: area.pressed || area.containsMouse ? Theme.text : Theme.subtext0
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onPressed: mouse => root.moved(root.at(mouse.x))
    onPositionChanged: mouse => { if (pressed) root.moved(root.at(mouse.x)) }
    onWheel: wheel => root.moved(Math.max(0, Math.min(1, root.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
  }
}
