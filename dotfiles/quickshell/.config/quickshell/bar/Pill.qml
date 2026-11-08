import QtQuick
import qs

// One bar element: glyph + label on a rounded hover/active background.
Item {
  id: root

  property string icon: ""
  property string text: ""
  property color color: Theme.text
  property color iconColor: color
  property bool active: false        // its panel is open
  property alias hovered: area.containsMouse

  signal clicked(var mouse)
  signal wheel(var wheel)

  implicitHeight: Theme.barHeight - 8
  implicitWidth: row.implicitWidth + 18

  Rectangle {
    anchors.fill: parent
    radius: height / 2
    color: root.active ? Theme.surface1 : area.containsMouse ? Theme.surface0 : "transparent"
    Behavior on color { ColorAnimation { duration: 120 } }
  }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 6

    Text {
      visible: root.icon !== ""
      anchors.verticalCenter: parent.verticalCenter
      text: root.icon
      color: root.iconColor
      font.family: Theme.font
      font.pixelSize: Theme.iconSize
    }
    Text {
      visible: root.text !== ""
      anchors.verticalCenter: parent.verticalCenter
      text: root.text
      color: root.color
      font.family: Theme.font
      font.pixelSize: Theme.fontSize
      font.bold: true
    }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    cursorShape: Qt.PointingHandCursor
    onClicked: mouse => root.clicked(mouse)
    onWheel: wheel => root.wheel(wheel)
  }
}
