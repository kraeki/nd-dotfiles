import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs

// StatusNotifier tray (nm-applet, blueman, udiskie, Slack, ...). Right click
// opens the item's own menu as a Qt platform menu -- which is why shell.qml
// carries `pragma UseQApplication`, and why the menus follow Kvantum.
Row {
  id: root

  spacing: 4

  Repeater {
    model: SystemTray.items.values.filter(i => i.status !== Status.Passive)

    delegate: Item {
      id: entry
      required property SystemTrayItem modelData

      implicitWidth: Theme.barHeight - 8
      implicitHeight: Theme.barHeight - 8

      Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: area.containsMouse ? Theme.surface0 : "transparent"
      }

      // Image, not IconImage: decode at physical pixels or it blurs at 1.333.
      Image {
        anchors.centerIn: parent
        width: 18
        height: 18
        source: entry.modelData.icon
        fillMode: Image.PreserveAspectFit
        sourceSize.width: Math.round(width * (entry.QsWindow.window?.devicePixelRatio ?? 1))
        sourceSize.height: Math.round(height * (entry.QsWindow.window?.devicePixelRatio ?? 1))
        smooth: true
      }

      MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => {
          const item = entry.modelData
          if (mouse.button === Qt.MiddleButton) {
            item.secondaryActivate()
          } else if (mouse.button === Qt.RightButton || item.onlyMenu) {
            if (!item.hasMenu) return
            const win = entry.QsWindow.window
            const p = win.contentItem.mapFromItem(entry, 0, 0)
            item.display(win, p.x, p.y)
          } else {
            item.activate()
          }
        }
        onWheel: wheel => entry.modelData.scroll(wheel.angleDelta.y, false)
      }
    }
  }
}
