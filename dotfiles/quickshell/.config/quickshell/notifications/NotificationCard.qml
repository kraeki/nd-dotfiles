import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import qs
import qs.services

// One notification. As a toast (`popup`) it times out into the history; in
// the history panel it just sits there. Left click runs the default action
// (or dismisses), right/middle click dismisses -- dunst's old mouse mapping.
Rectangle {
  id: root

  required property Notification notification
  property bool popup: false

  readonly property bool critical: notification.urgency === NotificationUrgency.Critical
  // `notify-send -i name` arrives as image://icon/<name>, which Qt's own
  // provider cannot resolve against the icon theme; look it up instead.
  function resolve(src) {
    if (src.startsWith("image://icon/")) {
      const name = src.slice("image://icon/".length)
      return name.startsWith("/") ? "file://" + name : Quickshell.iconPath(name, true)
    }
    return src.startsWith("/") ? "file://" + src : src
  }

  readonly property string iconSource: {
    const img = notification.image
    if (img) return root.resolve(img)
    const icon = notification.appIcon
    if (!icon) return ""
    if (icon.includes("/")) return root.resolve(icon)
    return Quickshell.iconPath(icon, true)
  }
  readonly property var buttons: notification.actions.filter(a => a.identifier !== "default")

  implicitHeight: content.implicitHeight + 24
  radius: Theme.radius
  color: Theme.alpha(Theme.base, root.popup ? 0.97 : 1)
  border.width: 2
  border.color: root.critical ? Theme.red : root.popup ? Theme.accent : Theme.surface1

  HoverHandler { id: hover }

  Timer {
    id: expiry
    interval: Notifs.timeoutMs(root.notification)
    running: root.popup && interval > 0 && !hover.hovered
    onTriggered: Notifs.hidePopup(root.notification)
  }

  // A sender replacing its notification (notify-send -r) mutates this object
  // in place; give the new text the full timeout.
  Connections {
    target: root.notification
    function onSummaryChanged() { expiry.restart() }
    function onBodyChanged() { expiry.restart() }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    cursorShape: Qt.PointingHandCursor
    onClicked: mouse => {
      if (mouse.button === Qt.LeftButton) Notifs.activate(root.notification)
      else Notifs.dismiss(root.notification)
    }
  }

  RowLayout {
    id: content
    x: 12
    y: 12
    width: root.width - 24
    spacing: 12

    Image {
      Layout.alignment: Qt.AlignTop
      Layout.preferredWidth: 40
      Layout.preferredHeight: 40
      visible: root.iconSource !== "" && status !== Image.Error
      source: root.iconSource
      fillMode: Image.PreserveAspectFit
      sourceSize.width: 80
      sourceSize.height: 80
      asynchronous: true
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 3

      RowLayout {
        Layout.fillWidth: true
        Text {
          Layout.fillWidth: true
          text: root.notification.summary
          color: Theme.text
          font.family: Theme.font
          font.pixelSize: Theme.fontSize
          font.bold: true
          elide: Text.ElideRight
          textFormat: Text.PlainText
        }
        Text {
          text: root.notification.appName
          visible: text !== ""
          color: Theme.overlay0
          font.family: Theme.font
          font.pixelSize: Theme.fontSmall
          Layout.maximumWidth: 110
          elide: Text.ElideRight
        }
        Text {
          text: "󰅖"
          color: closeArea.containsMouse ? Theme.red : Theme.overlay0
          font.family: Theme.font
          font.pixelSize: Theme.iconSize
          MouseArea {
            id: closeArea
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            onClicked: Notifs.dismiss(root.notification)
          }
        }
      }

      Text {
        Layout.fillWidth: true
        visible: text !== ""
        text: root.notification.body
        color: Theme.subtext0
        font.family: Theme.font
        font.pixelSize: Theme.fontSmall + 1
        wrapMode: Text.Wrap
        maximumLineCount: root.popup ? 5 : 3
        elide: Text.ElideRight
        textFormat: Text.StyledText
        onLinkActivated: link => Qt.openUrlExternally(link)
      }

      Flow {
        Layout.fillWidth: true
        Layout.topMargin: 4
        visible: root.buttons.length > 0
        spacing: 6
        Repeater {
          model: root.buttons
          Rectangle {
            required property NotificationAction modelData
            implicitHeight: 26
            implicitWidth: actionLabel.implicitWidth + 20
            radius: 13
            color: actionArea.containsMouse ? Theme.surface1 : Theme.surface0
            Text {
              id: actionLabel
              anchors.centerIn: parent
              text: parent.modelData.text
              color: Theme.text
              font.family: Theme.font
              font.pixelSize: Theme.fontSmall + 1
              font.bold: true
            }
            MouseArea {
              id: actionArea
              anchors.fill: parent
              hoverEnabled: true
              onClicked: {
                parent.modelData.invoke()
                Notifs.dismiss(root.notification)
              }
            }
          }
        }
      }
    }
  }
}
