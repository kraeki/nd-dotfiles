pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Network state for the bar and its panel. The facts come from `net-status`
// (dotfiles/hypr/.local/share/bin), the same source the speed test logs
// against, so bar, panel and history cannot disagree about the connection.
// Throughput is a delta of the kernel's own byte counters -- what net-waybar
// used to do across invocations, here held in memory.
Singleton {
  id: root

  property string kind: "disconnected"   // wifi | ethernet | disconnected
  property string name: ""
  property int signal: 0                 // percent, wifi only
  property string iface: ""
  property real down: 0                  // Mbit/s
  property real up: 0

  // Filled on demand by refreshDetails(): key -> value from `net-status --verbose`.
  property var details: ({})
  property var history: []               // lines of `net-speedtest --history --here`

  // Speed test, driven by `net-speedtest --stream`.
  property bool testing: false
  property string testPhase: ""          // down | up
  property real testDown: 0
  property real testUp: 0
  property bool testDone: false

  readonly property string icon: {
    if (kind === "ethernet") return "󰈀"
    if (kind !== "wifi") return "󰤭"
    return ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"][Math.min(4, Math.floor(signal / 21))]
  }

  function fmtRate(v) {
    return v >= 10 ? Math.round(v).toString() : v.toFixed(1)
  }

  Process {
    id: status
    command: ["net-status"]
    stdout: StdioCollector {
      onStreamFinished: {
        const f = text.trim().split("\t")
        root.kind = f[0] || "disconnected"
        root.name = f[1] || ""
        root.signal = Number(f[2]) || 0
      }
    }
  }

  // The interface carrying the default route, the same question net-status
  // answers -- with a dock, a VPN and docker0 up, "first UP device" is wrong.
  Process {
    id: route
    command: ["ip", "-o", "route", "get", "1.1.1.1"]
    stdout: StdioCollector {
      onStreamFinished: {
        const m = text.match(/\bdev (\S+)/)
        const next = m ? m[1] : ""
        if (next !== root.iface) root.prevSample = null
        root.iface = next
      }
    }
  }

  Timer {
    interval: 10000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      status.running = true
      route.running = true
    }
  }

  FileView { id: rx; path: root.iface ? `/sys/class/net/${root.iface}/statistics/rx_bytes` : ""; blockLoading: true; printErrors: false }
  FileView { id: tx; path: root.iface ? `/sys/class/net/${root.iface}/statistics/tx_bytes` : ""; blockLoading: true; printErrors: false }
  property var prevSample: null

  // 3s is also the averaging window: a longer one smears a burst out.
  Timer {
    interval: 3000
    running: root.iface !== ""
    repeat: true
    onTriggered: {
      rx.reload(); rx.waitForJob()
      tx.reload(); tx.waitForJob()
      const now = { t: Date.now(), rx: Number(rx.text().trim()), tx: Number(tx.text().trim()) }
      const p = root.prevSample
      // A counter that went backwards (link bounced, /sys reset) is "no rate
      // yet", not a bogus spike.
      if (p && now.rx >= p.rx && now.tx >= p.tx && now.t > p.t) {
        const dt = (now.t - p.t) / 1000
        root.down = (now.rx - p.rx) * 8 / 1e6 / dt
        root.up = (now.tx - p.tx) * 8 / 1e6 / dt
      } else {
        root.down = 0
        root.up = 0
      }
      root.prevSample = now
    }
  }

  Process {
    id: verbose
    command: ["net-status", "--verbose"]
    stdout: StdioCollector {
      onStreamFinished: {
        const d = {}
        for (const l of text.split("\n")) {
          const i = l.indexOf("\t")
          if (i > 0) d[l.slice(0, i)] = l.slice(i + 1)
        }
        root.details = d
      }
    }
  }

  Process {
    id: hist
    command: ["net-speedtest", "--history", "--here", "--limit", "5"]
    stdout: StdioCollector {
      onStreamFinished: root.history = text.split("\n").filter(l => l.trim() !== "")
    }
  }

  function refreshDetails() {
    verbose.running = true
    hist.running = true
  }

  Process {
    id: speedtest
    command: ["net-speedtest", "--stream"]
    stdout: SplitParser {
      onRead: line => {
        const f = line.trim().split(/\s+/)
        if (f[0] === "down" || f[0] === "up") {
          root.testPhase = f[0]
          if (f[0] === "down") root.testDown = Number(f[1]) || 0
          else root.testUp = Number(f[1]) || 0
        } else if (f[0] === "result") {
          root.testDown = Number(f[1]) || 0
          root.testUp = Number(f[2]) || 0
          root.testDone = true
        }
      }
    }
    onExited: {
      root.testing = false
      root.testPhase = ""
      Qt.callLater(root.refreshDetails)
    }
  }

  function runSpeedtest() {
    if (root.testing) return
    root.testDown = 0
    root.testUp = 0
    root.testDone = false
    root.testing = true
    speedtest.running = true
  }

  function stopSpeedtest() {
    speedtest.signal(15)
  }
}
