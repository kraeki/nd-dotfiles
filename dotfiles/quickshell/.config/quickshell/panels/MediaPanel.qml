import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import qs
import qs.services

// Now playing: art, track, position, transport. Every MPRIS player is listed
// underneath so a paused one can be picked up again.
Popup {
  id: root

  fixedWidth: Theme.cardWidth

  readonly property MprisPlayer player: Media.player

  function time(s) {
    if (!isFinite(s) || s < 0) return "–:––"
    const m = Math.floor(s / 60)
    return m + ":" + String(Math.floor(s % 60)).padStart(2, "0")
  }

  // MPRIS does not push position updates; poll while visible and playing.
  Timer {
    running: root.open && (root.player?.isPlaying ?? false)
    interval: 1000
    repeat: true
    onTriggered: root.player.positionChanged()
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: 12

    Rectangle {
      Layout.preferredWidth: 72
      Layout.preferredHeight: 72
      radius: Theme.radius
      color: Theme.surface0
      clip: true
      Image {
        id: art
        anchors.fill: parent
        source: root.player?.trackArtUrl ?? ""
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 144
        sourceSize.height: 144
        asynchronous: true
        visible: status === Image.Ready
      }
      Label {
        anchors.centerIn: parent
        visible: !art.visible
        text: "󰝚"
        font.pixelSize: Theme.fontDisplay
        color: Theme.overlay0
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 2
      Label { heading: true; text: root.player?.trackTitle || "Nothing playing"; elide: Text.ElideRight; Layout.fillWidth: true }
      Label { text: root.player?.trackArtist ?? ""; elide: Text.ElideRight; Layout.fillWidth: true; visible: text !== "" }
      Label { dim: true; text: root.player?.trackAlbum ?? ""; elide: Text.ElideRight; Layout.fillWidth: true; visible: text !== "" }
      Label { dim: true; text: root.player?.identity ?? ""; color: Theme.overlay0 }
    }
  }

  ColumnLayout {
    Layout.fillWidth: true
    visible: (root.player?.lengthSupported ?? false) && root.player.length > 0
    spacing: 2
    Slider {
      Layout.fillWidth: true
      value: root.player && root.player.length > 0 ? root.player.position / root.player.length : 0
      onMoved: v => { if (root.player?.canSeek) root.player.position = v * root.player.length }
    }
    RowLayout {
      Layout.fillWidth: true
      Label { dim: true; text: root.time(root.player?.position ?? 0) }
      Item { Layout.fillWidth: true }
      Label { dim: true; text: root.time(root.player?.length ?? 0) }
    }
  }

  RowLayout {
    Layout.alignment: Qt.AlignHCenter
    spacing: 8
    Button { text: "󰒮"; onClicked: root.player?.previous(); opacity: root.player?.canGoPrevious ? 1 : 0.4 }
    Button { text: root.player?.isPlaying ? "󰏤" : "󰐊"; checked: true; onClicked: root.player?.togglePlaying() }
    Button { text: "󰒭"; onClicked: root.player?.next(); opacity: root.player?.canGoNext ? 1 : 0.4 }
  }

  ColumnLayout {
    Layout.fillWidth: true
    visible: Media.players.length > 1
    spacing: 2
    Label { dim: true; text: "Players" }
    Repeater {
      model: Media.players
      delegate: Rectangle {
        id: prow
        required property MprisPlayer modelData
        Layout.fillWidth: true
        implicitHeight: 28
        radius: Theme.radius
        color: pArea.containsMouse ? Theme.surface0 : "transparent"
        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 8
          anchors.rightMargin: 8
          Label { text: prow.modelData === root.player ? "󰄬" : ""; color: Theme.accent; Layout.preferredWidth: 16 }
          Label {
            text: prow.modelData.identity + (prow.modelData.trackTitle ? " · " + prow.modelData.trackTitle : "")
            color: prow.modelData === root.player ? Theme.text : Theme.subtext0
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
          Label { text: prow.modelData.isPlaying ? "󰐊" : "󰏤"; dim: true }
        }
        MouseArea {
          id: pArea
          anchors.fill: parent
          hoverEnabled: true
          onClicked: Media.pinned = prow.modelData
        }
      }
    }
  }
}
