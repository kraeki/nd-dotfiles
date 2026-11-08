pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Which MPRIS player the bar shows: the one picked in the media panel while
// it still exists, else whichever is playing, else the first one.
Singleton {
  id: root

  // Chrome publishes an MPRIS player as soon as it runs, with no track at
  // all; counting that one would park "Chrome" in the bar permanently.
  readonly property var players: Mpris.players.values.filter(p => p.isPlaying || p.trackTitle)
  property MprisPlayer pinned: null

  readonly property MprisPlayer player: {
    if (root.pinned && root.players.includes(root.pinned)) return root.pinned
    return root.players.find(p => p.isPlaying) ?? root.players[0] ?? null
  }
}
