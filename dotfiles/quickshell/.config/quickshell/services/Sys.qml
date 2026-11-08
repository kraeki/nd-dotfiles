pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// CPU, memory and temperature, sampled from /proc and /sys. Replaces waybar's
// cpu/memory modules and cpuinfo.sh (which forked top, sensors and jq every
// five seconds to produce one tooltip).
Singleton {
  id: root

  property real cpu: 0            // 0..1, all cores
  property var cores: []          // 0..1 per core
  property var history: []        // last `historyLength` cpu samples
  readonly property int historyLength: 8
  property real memUsed: 0        // GiB
  property real memTotal: 0
  property real swapUsed: 0
  property real swapTotal: 0
  property real temp: NaN         // °C, k10temp Tctl
  property string model: ""
  property real freqMhz: 0
  property real maxFreqMhz: 0

  // Per-core frequency is only read while someone shows it (the panel).
  property bool detailed: false

  property var prev: null
  property string tempPath: ""

  FileView { id: stat; path: "/proc/stat"; blockLoading: true; printErrors: false }
  FileView { id: meminfo; path: "/proc/meminfo"; blockLoading: true; printErrors: false }
  FileView { id: cpuinfo; path: "/proc/cpuinfo"; blockLoading: true; printErrors: false }
  FileView { id: tempFile; path: root.tempPath; blockLoading: true; printErrors: false }
  FileView {
    path: "/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq"
    blockLoading: true
    printErrors: false
    onLoaded: root.maxFreqMhz = Number(text().trim()) / 1000
  }

  // The hwmon index moves between boots, so look k10temp up by name. Intel
  // machines get coretemp's package sensor instead.
  Process {
    running: true
    command: ["sh", "-c", "for h in /sys/class/hwmon/hwmon*; do case $(cat $h/name) in k10temp|coretemp) echo $h/temp1_input; exit;; esac; done"]
    stdout: StdioCollector { onStreamFinished: root.tempPath = text.trim() }
  }

  function read(file) {
    file.reload()
    file.waitForJob()
    return file.text()
  }

  function sampleCpu() {
    const lines = read(stat).split("\n").filter(l => l.startsWith("cpu"))
    const now = lines.map(l => {
      const f = l.trim().split(/\s+/).slice(1).map(Number)
      const idle = f[3] + f[4]
      return { idle: idle, total: f.reduce((a, b) => a + b, 0) }
    })
    if (root.prev && root.prev.length === now.length) {
      const usage = now.map((c, i) => {
        const dt = c.total - root.prev[i].total
        return dt > 0 ? 1 - (c.idle - root.prev[i].idle) / dt : 0
      })
      root.cpu = usage[0]
      root.cores = usage.slice(1)
      root.history = root.history.concat([usage[0]]).slice(-root.historyLength)
    }
    root.prev = now
  }

  function sampleMem() {
    const kv = {}
    for (const l of read(meminfo).split("\n")) {
      const m = l.match(/^(\w+):\s+(\d+)/)
      if (m) kv[m[1]] = Number(m[2])
    }
    const gib = 1024 * 1024
    root.memTotal = kv.MemTotal / gib
    root.memUsed = (kv.MemTotal - kv.MemAvailable) / gib
    root.swapTotal = kv.SwapTotal / gib
    root.swapUsed = (kv.SwapTotal - kv.SwapFree) / gib
  }

  function sampleDetail() {
    if (root.model === "" || root.detailed) {
      const text = read(cpuinfo)
      const m = text.match(/model name\s*:\s*(.*)/)
      if (m) root.model = m[1].trim()
      // No String.matchAll in QML's JS engine.
      const re = /cpu MHz\s*:\s*([\d.]+)/g
      let sum = 0, n = 0, x
      while ((x = re.exec(text)) !== null) { sum += Number(x[1]); n++ }
      if (n) root.freqMhz = sum / n
    }
    if (root.tempPath !== "") {
      const t = Number(read(tempFile).trim())
      root.temp = isNaN(t) ? NaN : t / 1000
    }
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      root.sampleCpu()
      root.sampleMem()
      root.sampleDetail()
    }
  }
}
