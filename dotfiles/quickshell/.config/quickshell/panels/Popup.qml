import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs

// A card that opens above a bar element (the bar sits at the bottom), centred
// on it and kept on screen. Click anywhere else or press Escape to close:
// HyprlandFocusGrab clears as soon as a click lands outside these two windows.
// Pattern from Omarchy 4's Ui/PopupCard.qml.
PopupWindow {
  id: root

  required property Item target
  property bool open: false
  property int pad: 16
  default property alias content: body.data

  readonly property int lift: 6   // gap between the bar and the card

  function toggle() { root.open = !root.open }

  // Stays mapped through the fade-out.
  visible: root.open || card.opacity > 0.01
  color: "transparent"
  implicitWidth: card.implicitWidth
  implicitHeight: card.implicitHeight + root.lift

  anchor {
    id: anc
    window: root.target.QsWindow.window
    adjustment: PopupAdjustment.Slide
    // Anchor on the bar's top edge and grow upwards from it.
    edges: Edges.Top | Edges.Left
    gravity: Edges.Top | Edges.Right
    rect.width: 1
    rect.height: 1
    onAnchoring: {
      const win = root.target.QsWindow.window
      const p = win.contentItem.mapFromItem(root.target, root.target.width / 2 - root.implicitWidth / 2, 0)
      anc.rect.x = Math.round(Math.max(Theme.gap, Math.min(p.x, win.width - root.implicitWidth - Theme.gap)))
      anc.rect.y = 0
    }
  }

  HyprlandFocusGrab {
    active: root.open
    windows: [root, root.target.QsWindow.window]
    onCleared: root.open = false
  }

  Rectangle {
    id: card
    width: root.width
    implicitWidth: body.implicitWidth + 2 * root.pad
    implicitHeight: body.implicitHeight + 2 * root.pad
    height: implicitHeight
    radius: Theme.radius
    color: Theme.base
    border.width: 2
    border.color: Theme.accent

    opacity: root.open ? 1 : 0
    y: root.open ? 0 : 8
    Behavior on opacity { NumberAnimation { duration: root.open ? 160 : 110 } }
    Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    focus: root.open
    Keys.onEscapePressed: root.open = false

    ColumnLayout {
      id: body
      x: root.pad
      y: root.pad
      width: card.width - 2 * root.pad
      spacing: 10
    }
  }
}
