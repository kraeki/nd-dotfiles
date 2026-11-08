import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.notifications

// The notification history (everything not yet dismissed) and the DND switch.
Popup {
  id: root

  fixedWidth: Theme.cardWidth

  RowLayout {
    Layout.fillWidth: true
    Label { heading: true; text: "Notifications"; Layout.fillWidth: true }
    Button { text: Notifs.dnd ? "󰂛 DND" : "󰂚 DND"; checked: Notifs.dnd; onClicked: Notifs.dnd = !Notifs.dnd }
    Button { text: "Clear"; visible: Notifs.list.length > 0; onClicked: Notifs.clearAll() }
  }

  Label {
    visible: Notifs.list.length === 0
    dim: true
    text: "Nothing here."
  }

  Flickable {
    visible: Notifs.list.length > 0
    Layout.fillWidth: true
    Layout.preferredHeight: Math.min(contentHeight, 520)
    contentHeight: column.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
      id: column
      width: parent.width
      spacing: Theme.innerGap
      Repeater {
        // Newest first. ScriptModel keeps existing cards when the list changes.
        model: ScriptModel { values: Notifs.list.slice().reverse() }
        NotificationCard {
          required property var modelData
          notification: modelData
          width: column.width
        }
      }
    }
  }
}
