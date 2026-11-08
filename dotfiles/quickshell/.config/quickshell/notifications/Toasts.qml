import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services

// Toast stack in the top-right corner, where dunst put them, on the monitor
// that had focus when the stack started (it does not chase focus while
// visible, or toasts would jump between screens mid-read).
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

  anchors { top: true; right: true }
  margins { top: Theme.gap; right: Theme.gap }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "nd-notifications"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  color: "transparent"

  implicitWidth: 380
  implicitHeight: Math.max(1, stack.implicitHeight)

  Column {
    id: stack
    width: parent.width
    spacing: 6

    Repeater {
      // Newest on top.
      model: Notifs.popups.slice().reverse()
      NotificationCard {
        required property var modelData
        notification: modelData
        popup: true
        width: stack.width
      }
    }
  }
}
