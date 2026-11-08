pragma Singleton

import QtQuick
import Quickshell

// Shell-wide toggles (not "State": that name is QtQuick's own type and wins) that every bar reflects. PersistentProperties so a
// config reload (saving a .qml file) keeps them; a restart resets them.
Singleton {
  id: root

  property bool stayAwake: false
  onStayAwakeChanged: persist.stayAwake = root.stayAwake

  PersistentProperties {
    id: persist
    reloadableId: "nd-state"
    property bool stayAwake: false
    onLoaded: root.stayAwake = persist.stayAwake
  }
}
