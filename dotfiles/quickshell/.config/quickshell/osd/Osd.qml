import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import qs

// Volume / mic / brightness OSD, replacing the notify-send -r 91190 toasts.
// Volume and mute are watched on PipeWire directly, so any change shows --
// media keys, pavucontrol, a headset button. Brightness has no change signal
// worth watching (sysfs does not inotify), so brightnesscontrol.sh pings it:
//   qs ipc call osd brightness
Scope {
  id: root

  property string icon: ""
  property real value: 0          // 0..1 (volume may exceed 1)
  property string label: ""
  property bool muted: false
  property bool shown: false

  property alias window: win

  readonly property PwNode sink: Pipewire.defaultAudioSink
  readonly property PwNode source: Pipewire.defaultAudioSource

  PwObjectTracker { objects: [root.sink, root.source] }

  // The first values after startup, and after the default device changes,
  // are the node being bound, not anyone touching the volume.
  property bool armed: false
  Timer { id: arm; interval: 1500; running: true; onTriggered: root.armed = true }
  onSinkChanged: { root.armed = false; arm.restart() }
  onSourceChanged: { root.armed = false; arm.restart() }

  Connections {
    target: root.sink?.audio ?? null
    function onVolumeChanged() { root.showVolume() }
    function onMutedChanged() { root.showVolume() }
  }
  Connections {
    target: root.source?.audio ?? null
    function onMutedChanged() { root.showMic() }
  }

  function show(icon, value, label, muted) {
    root.icon = icon
    root.value = value
    root.label = label
    root.muted = muted
    root.shown = true
    hide.restart()
  }

  function showVolume() {
    if (!root.armed || !root.sink?.audio) return
    const a = root.sink.audio
    const icon = a.muted ? "󰝟" : a.volume < 0.34 ? "󰕿" : a.volume < 0.67 ? "󰖀" : "󰕾"
    root.show(icon, a.volume, root.sink.description || root.sink.name, a.muted)
  }

  function showMic() {
    if (!root.armed || !root.source?.audio) return
    const a = root.source.audio
    root.show(a.muted ? "󰍭" : "󰍬", a.volume, root.source.description || root.source.name, a.muted)
  }

  Process {
    id: bright
    command: ["brightnessctl", "-m"]
    stdout: StdioCollector {
      // amdgpu_bl1,backlight,123,48%,255
      onStreamFinished: {
        const f = text.trim().split(",")
        const pct = parseInt(f[3]) / 100
        root.show(pct < 0.34 ? "󰃞" : pct < 0.67 ? "󰃟" : "󰃠", pct, "Brightness", false)
      }
    }
  }

  IpcHandler {
    target: "osd"
    function brightness(): void { bright.running = true }
    function volume(): void { root.armed = true; root.showVolume() }
  }

  Timer { id: hide; interval: 1300; onTriggered: root.shown = false }

  PanelWindow {
    id: win
    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    visible: root.shown || card.opacity > 0.01

    anchors.bottom: true
    margins.bottom: Theme.barHeight + 72
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nd-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // No input at all: the OSD must never eat a click.
    mask: Region {}
    color: "transparent"

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    Rectangle {
      id: card
      implicitWidth: 320
      implicitHeight: 64
      radius: Theme.radius
      color: Theme.alpha(Theme.base, 0.97)
      border.width: 2
      border.color: root.muted ? Theme.surface2 : Theme.accent
      opacity: root.shown ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: root.shown ? 120 : 220 } }

      RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        Text {
          text: root.icon
          color: root.muted ? Theme.overlay0 : Theme.accent
          font.family: Theme.font
          font.pixelSize: 24
          Layout.preferredWidth: 28
          horizontalAlignment: Text.AlignHCenter
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 5
          Text {
            Layout.fillWidth: true
            text: root.label
            color: Theme.subtext0
            font.family: Theme.font
            font.pixelSize: Theme.fontSmall
            elide: Text.ElideRight
          }
          Rectangle {
            Layout.fillWidth: true
            implicitHeight: 6
            radius: 3
            color: Theme.surface0
            Rectangle {
              width: parent.width * Math.min(1, root.value)
              height: parent.height
              radius: parent.radius
              color: root.muted ? Theme.overlay0 : Theme.accent
              Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            }
          }
        }

        Text {
          text: root.muted ? "muted" : Math.round(root.value * 100) + "%"
          color: Theme.text
          font.family: Theme.font
          font.pixelSize: Theme.fontSize
          font.bold: true
          Layout.preferredWidth: 46
          horizontalAlignment: Text.AlignRight
        }
      }
    }
  }
}
