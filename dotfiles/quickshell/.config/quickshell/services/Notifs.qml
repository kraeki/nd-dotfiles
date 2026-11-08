pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Notifications

// The notification daemon (replaces dunst). Every notification stays tracked
// after its toast times out, which is the history the bar's bell opens --
// dunst's sticky_history. Dismissing (click, right click, "clear") is what
// removes one for good.
Singleton {
  id: root

  // Survives restarts and logins: a file in Quickshell's state dir
  // (~/.local/state/quickshell/by-shell/<id>/dnd), "1" or "0".
  property bool dnd: false
  readonly property int historyLimit: 30

  // A fullscreen window on the focused monitor (a video, a presentation)
  // silences toasts the same way DND does; they still go to the history.
  readonly property bool fullscreen: Hyprland.focusedMonitor?.activeWorkspace?.hasFullscreen ?? false
  readonly property bool quiet: root.dnd || root.fullscreen

  FileView {
    id: dndFile
    path: Quickshell.statePath("dnd")
    printErrors: false
    onLoaded: root.dnd = text().trim() === "1"
  }
  onDndChanged: dndFile.setText(root.dnd ? "1" : "0")

  // Ids currently shown as a toast. A plain map plus a revision counter, not
  // a ListModel: a QObject held in a model role dangles once the server
  // destroys it, and the next read crashes.
  property var popupIds: ({})
  property int popupRevision: 0

  readonly property var list: server.trackedNotifications.values
  readonly property var popups: {
    root.popupRevision
    return root.list.filter(n => root.popupIds[n.id] === true)
  }

  NotificationServer {
    id: server
    keepOnReload: true
    actionsSupported: true
    actionIconsSupported: false
    bodySupported: true
    bodyMarkupSupported: true
    bodyHyperlinksSupported: true
    imageSupported: true
    persistenceSupported: true

    onNotification: n => {
      n.tracked = true
      // Stack tags: a newer notification with the same tag replaces the
      // older one. This is how scripts "update in place" -- a fixed
      // `notify-send -r 9731` cannot, since the server issues the ids and an
      // unknown replace id is simply a new notification.
      const tag = root.tagOf(n)
      if (tag !== "")
        root.list.filter(o => o !== n && root.tagOf(o) === tag).forEach(o => root.dismiss(o))
      // DND / fullscreen still let critical through: those are the ones that
      // stick until read (the speed test result, a dying battery).
      if (!root.quiet || n.urgency === NotificationUrgency.Critical)
        root.showPopup(n)
      const all = root.list
      if (all.length > root.historyLimit)
        all.slice(0, all.length - root.historyLimit).forEach(old => old.dismiss())
    }
  }

  function tagOf(n) {
    const h = n.hints || {}
    return String(h["x-canonical-private-synchronous"] || h["x-dunst-stack-tag"] || "")
  }

  function showPopup(n) {
    root.popupIds[n.id] = true
    root.popupRevision++
  }

  function hidePopup(n) {
    if (!root.popupIds[n.id]) return
    delete root.popupIds[n.id]
    root.popupRevision++
  }

  function dismiss(n) {
    root.hidePopup(n)
    n.dismiss()
  }

  // Click on the card body: the "default" action if the sender offered one
  // (notification-send.sh's "open in swappy"), otherwise just dismiss.
  function activate(n) {
    const def = n.actions.find(a => a.identifier === "default")
    if (def) def.invoke()
    root.dismiss(n)
  }

  function clearAll() {
    root.list.slice().forEach(n => n.dismiss())
    root.popupIds = {}
    root.popupRevision++
  }

  // Critical stays until dismissed. Otherwise the sender's own timeout wins
  // (a 1.5s "moved to workspace" status should not linger for 6s), capped at
  // 30s; without one, low gets 4s and normal 6s. expireTimeout is the raw
  // D-Bus value: ms, -1/0 meaning "server's call" (`-t 3000` arrives as 3000).
  function timeoutMs(n) {
    if (n.urgency === NotificationUrgency.Critical) return 0
    if (n.expireTimeout > 0) return Math.min(30000, n.expireTimeout)
    return n.urgency === NotificationUrgency.Low ? 4000 : 6000
  }

  IpcHandler {
    target: "notifications"
    function toggleDnd(): void { root.dnd = !root.dnd }
    function clear(): void { root.clearAll() }
    function dismissLatest(): void {
      const p = root.popups
      if (p.length) root.dismiss(p[p.length - 1])
    }
    function count(): int { return root.list.length }
  }
}
