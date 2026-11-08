import QtQuick
import qs

// A thin horizontal gauge, 0..1.
Rectangle {
  id: root

  property real value: 0
  property color fill: Theme.accent

  implicitHeight: 6
  implicitWidth: 120
  radius: height / 2
  color: Theme.surface0

  Rectangle {
    width: Math.max(root.height, parent.width * Math.max(0, Math.min(1, root.value)))
    height: parent.height
    radius: parent.radius
    color: root.fill
    visible: root.value > 0
    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
  }
}
