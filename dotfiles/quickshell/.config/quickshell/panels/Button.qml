import QtQuick
import qs

Rectangle {
  id: root

  property string text: ""
  property bool checked: false
  signal clicked()

  implicitHeight: 30
  implicitWidth: label.implicitWidth + 24
  radius: height / 2
  color: root.checked ? Theme.accent : area.containsMouse && root.enabled ? Theme.surface1 : Theme.surface0
  opacity: root.enabled ? 1 : 0.5
  Behavior on color { ColorAnimation { duration: 120 } }

  Text {
    id: label
    anchors.centerIn: parent
    text: root.text
    color: root.checked ? Theme.crust : Theme.text
    font.family: Theme.font
    font.pixelSize: Theme.fontSize
    font.bold: true
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
