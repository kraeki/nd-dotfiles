import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services

// Toast stack in the bottom-right corner, growing upwards from the bar: the
// newest toast lands next to the bar and pushes the older ones up. It sits on
// the window grid -- right edge and bottom edge flush with the window frames
// (gaps_out from the screen edge and from the bar). Shown on the monitor that
// had focus when the stack started; it does not chase focus while visible, or
// toasts would jump between screens mid-read.
PanelWindow {
  id: root

  property var targetScreen: null

  function pickScreen() {
    const name = Hyprland.focusedMonitor?.name
    root.targetScreen = Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0]
  }

  readonly property bool hasPopups: Notifs.popups.length > 0
  onHasPopupsChanged: if (hasPopups) root.pickScreen()

  screen: root.targetScreen ?? Quickshell.screens[0]
  // Mapped only while there is something to show: an overlay-layer surface
  // blocks direct scanout of fullscreen windows on its monitor.
  visible: root.hasPopups

  anchors { bottom: true; right: true }
  // Ignore the bar's exclusive zone and place it ourselves, so the stack
  // bottom lines up exactly with the window frames above the bar. Under a
  // fullscreen window (only critical toasts get through) the bar is hidden, so
  // the stack drops to the screen edge.
  margins { bottom: (Notifs.fullscreen ? 0 : Theme.barHeight) + Theme.gap; right: Theme.gap }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "nd-notifications"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  color: "transparent"

  implicitWidth: Theme.cardWidth
  implicitHeight: Math.max(1, stack.implicitHeight)

  Column {
    id: stack
    width: parent.width
    spacing: Theme.innerGap

    // A new toast rises in from below; the ones above it glide up to make room.
    add: Transition {
      NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160 }
      NumberAnimation { property: "y"; from: stack.height; duration: 220; easing.type: Easing.OutCubic }
    }
    move: Transition {
      NumberAnimation { property: "y"; duration: 220; easing.type: Easing.OutCubic }
    }

    Repeater {
      // Oldest on top, newest at the bottom next to the bar. ScriptModel
      // diffs the array, so existing cards (and their timeout timers) survive
      // a new toast arriving instead of being rebuilt from scratch.
      model: ScriptModel { values: Notifs.popups }
      NotificationCard {
        required property var modelData
        notification: modelData
        popup: true
        width: stack.width
      }
    }
  }
}
