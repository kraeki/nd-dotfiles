import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs
import qs.services

// Output and input: level, mute, and which device is the default.
Popup {
  id: root

  fixedWidth: Theme.cardWidth

  component DeviceSection: ColumnLayout {
    id: section
    required property string title
    required property PwNode current
    required property var devices
    required property string muteIcon
    required property string liveIcon

    Layout.fillWidth: true
    spacing: 6

    Label { heading: true; text: section.title }

    RowLayout {
      Layout.fillWidth: true
      spacing: 10
      Label {
        text: section.current?.audio?.muted ? section.muteIcon : section.liveIcon
        font.pixelSize: Theme.iconSize + 2
        color: section.current?.audio?.muted ? Theme.overlay0 : Theme.accent
        MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: Audio.toggleMute(section.current) }
      }
      Slider {
        Layout.fillWidth: true
        value: section.current?.audio?.volume ?? 0
        muted: section.current?.audio?.muted ?? false
        onMoved: v => Audio.setVolume(section.current, v)
      }
      Label {
        text: Math.round((section.current?.audio?.volume ?? 0) * 100) + "%"
        Layout.preferredWidth: 42
        horizontalAlignment: Text.AlignRight
      }
    }

    Repeater {
      model: section.devices
      delegate: Rectangle {
        id: row
        required property PwNode modelData
        readonly property bool isDefault: modelData === section.current
        Layout.fillWidth: true
        implicitHeight: 30
        radius: Theme.radius
        color: rowArea.containsMouse ? Theme.surface0 : "transparent"
        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 8
          anchors.rightMargin: 8
          Label { text: row.isDefault ? "󰄬" : ""; color: Theme.accent; Layout.preferredWidth: 16 }
          Label {
            text: Audio.label(row.modelData)
            color: row.isDefault ? Theme.text : Theme.subtext0
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
        }
        MouseArea {
          id: rowArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: Audio.makeDefault(row.modelData)
        }
      }
    }
  }

  DeviceSection {
    title: "Output"
    current: Audio.sink
    devices: Audio.sinks
    muteIcon: "󰝟"
    liveIcon: Audio.icon(Audio.volume, false)
  }

  Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.surface0 }

  DeviceSection {
    title: "Input"
    current: Audio.source
    devices: Audio.sources
    muteIcon: "󰍭"
    liveIcon: "󰍬"
  }
}
