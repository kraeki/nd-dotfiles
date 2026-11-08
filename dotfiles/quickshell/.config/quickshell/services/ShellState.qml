pragma Singleton

import QtQuick
import Quickshell

// Shell-wide toggles (not "State": that name is QtQuick's own type and wins) that every bar reflects. PersistentProperties so a
// config reload (saving a .qml file) keeps them; a restart resets them.
Singleton {
  id: root

  property bool stayAwake: false

  // `qs ipc call panels toggle <name>` -> the bar on that monitor opens it.
  // A signal rather than an IpcHandler per bar: one target may only have
  // one handler, and there is a bar per screen.
  signal panelRequested(string name, string screen)
  onStayAwakeChanged: persist.stayAwake = root.stayAwake

  PersistentProperties {
    id: persist
    reloadableId: "nd-state"
    property bool stayAwake: false

  // `qs ipc call panels toggle <name>` -> the bar on that monitor opens it.
  // A signal rather than an IpcHandler per bar: one target may only have
  // one handler, and there is a bar per screen.
  signal panelRequested(string name, string screen)
    onLoaded: root.stayAwake = persist.stayAwake
  }
}
