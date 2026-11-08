import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services

// What cpuinfo.sh's tooltip used to say, plus a gauge per core.
Popup {
  id: root

  onOpenChanged: Sys.detailed = open

  function heat(t) { return t >= 85 ? Theme.red : t >= 65 ? Theme.peach : t >= 45 ? Theme.yellow : Theme.accent }

  Label { heading: true; text: Sys.model || "CPU"; Layout.maximumWidth: 360; elide: Text.ElideRight }

  GridLayout {
    columns: 2
    columnSpacing: 16
    rowSpacing: 3
    Label { dim: true; text: "Usage" }
    Label { text: Math.round(Sys.cpu * 100) + "%" }
    Label { dim: true; text: "Clock" }
    Label { text: Math.round(Sys.freqMhz) + (Sys.maxFreqMhz ? " / " + Math.round(Sys.maxFreqMhz) : "") + " MHz" }
    Label { dim: true; text: "Temperature" }
    Label { text: isNaN(Sys.temp) ? "n/a" : Math.round(Sys.temp) + " °C"; color: isNaN(Sys.temp) ? Theme.text : root.heat(Sys.temp) }
    Label { dim: true; text: "Memory" }
    Label { text: Sys.memUsed.toFixed(1) + " / " + Sys.memTotal.toFixed(1) + " GiB" }
    Label { dim: true; text: "Swap"; visible: Sys.swapTotal > 0 }
    Label { text: Sys.swapUsed.toFixed(1) + " / " + Sys.swapTotal.toFixed(1) + " GiB"; visible: Sys.swapTotal > 0 }
  }

  Meter { Layout.fillWidth: true; value: Sys.memTotal ? Sys.memUsed / Sys.memTotal : 0; fill: Theme.peach }

  Label { dim: true; text: "Cores" }
  GridLayout {
    columns: 4
    columnSpacing: 10
    rowSpacing: 5
    Repeater {
      model: Sys.cores.length
      Meter {
        required property int index
        implicitWidth: 80
        value: Sys.cores[index] ?? 0
        fill: (Sys.cores[index] ?? 0) > 0.85 ? Theme.red : Theme.accent
      }
    }
  }
}
