pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// The notification daemon (replaces dunst). Every notification stays tracked
// after its toast times out, which is the history the bar's bell opens --
// dunst's sticky_history. Dismissing (click, right click, "clear") is what
// removes one for good.
Singleton {
  id: root

  property bool dnd: false
  readonly property int historyLimit: 30

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
      // DND still lets critical through: those are the ones that stick until
      // read (the speed test result, a dying battery).
      if (!root.dnd || n.urgency === NotificationUrgency.Critical)
        root.showPopup(n)
      const all = root.list
      if (all.length > root.historyLimit)
        all.slice(0, all.length - root.historyLimit).forEach(old => old.dismiss())
    }
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

  // Low 4s, normal 6s, critical until dismissed; a sender asking for longer
  // gets it, capped at 30s. expireTimeout is the raw D-Bus value: ms, with
  // -1/0 meaning "server's call" (`notify-send -t 3000` arrives as 3000).
  function timeoutMs(n) {
    if (n.urgency === NotificationUrgency.Critical) return 0
    const base = n.urgency === NotificationUrgency.Low ? 4000 : 6000
    const asked = n.expireTimeout > 0 ? n.expireTimeout : 0
    return Math.min(30000, Math.max(base, asked))
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
