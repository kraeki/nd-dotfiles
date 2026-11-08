pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// PipeWire defaults and devices, for the bar's speaker element and the audio
// panel (replacing the vicinae pulseaudio extension as the everyday path).
Singleton {
  id: root

  readonly property PwNode sink: Pipewire.defaultAudioSink
  readonly property PwNode source: Pipewire.defaultAudioSource

  // Hardware endpoints only: streams (an app's playback) are nodes too.
  readonly property var sinks: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
  readonly property var sources: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream)

  readonly property real volume: sink?.audio?.volume ?? 0
  readonly property bool muted: sink?.audio?.muted ?? false
  readonly property bool micMuted: source?.audio?.muted ?? false

  PwObjectTracker { objects: root.sinks.concat(root.sources) }

  function label(node) {
    return node ? (node.nickname || node.description || node.name) : ""
  }

  function icon(vol, mute) {
    return mute ? "󰝟" : vol < 0.34 ? "󰕿" : vol < 0.67 ? "󰖀" : "󰕾"
  }

  function setVolume(node, v) {
    if (node?.audio) node.audio.volume = Math.max(0, Math.min(1.5, v))
  }

  function nudge(delta) {
    root.setVolume(root.sink, root.volume + delta)
  }

  function toggleMute(node) {
    if (node?.audio) node.audio.muted = !node.audio.muted
  }

  function makeDefault(node) {
    if (node.isSink) Pipewire.preferredDefaultAudioSink = node
    else Pipewire.preferredDefaultAudioSource = node
  }
}
