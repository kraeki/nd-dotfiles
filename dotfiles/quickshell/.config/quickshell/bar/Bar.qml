import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import qs
import qs.services
import qs.panels

// One bar per monitor, along the bottom edge (where waybar sat).
//   left:   workspaces of this monitor · now playing         -> MediaPanel
//   centre: cpu sparkline · memory · temperature          -> SysPanel
//   right:  tray · notifications · volume · bluetooth · power profile
//           · stay awake · battery
//           · network · clock                             -> their panels
PanelWindow {
  id: bar

  anchors { bottom: true; left: true; right: true }
  implicitHeight: Theme.barHeight
  color: "transparent"
  property alias content: content

  WlrLayershell.namespace: "nd-bar"
  WlrLayershell.layer: WlrLayer.Top

  // Waybar's idle_inhibitor. A no-op until an idle daemon exists (none is
  // configured, see the hyprlock note in modules/nixos/desktop.nix), kept so
  // the toggle means the same thing when one does.
  IdleInhibitor {
    window: bar
    enabled: ShellState.stayAwake
  }

  // Drawn by an item, not the window colour, so the bar can be rendered with
  // grabToImage (handy for checking a change while the screen is locked).
  Rectangle {
    id: content
    anchors.fill: parent
    color: Theme.alpha(Theme.bg, 0.9)

    // --- left ---------------------------------------------------------------
    Row {
      anchors.left: parent.left
      anchors.leftMargin: Theme.gap
      anchors.verticalCenter: parent.verticalCenter
      spacing: Theme.innerGap

      Workspaces { screen: bar.screen }

      // Now playing; hidden while no MPRIS player exists.
      Pill {
        id: mediaPill
        visible: Media.player !== null
        active: mediaPanel.open
        icon: Media.player?.isPlaying ? "󰐊" : "󰏤"
        iconColor: Media.player?.isPlaying ? Theme.accent : Theme.subtext0
        text: {
          const p = Media.player
          if (!p) return ""
          const t = [p.trackArtist, p.trackTitle].filter(x => x).join(" – ") || p.identity
          return t.length > 42 ? t.slice(0, 41) + "…" : t
        }
        color: Media.player?.isPlaying ? Theme.text : Theme.subtext0
        // Middle click plays/pauses without opening anything.
        onClicked: mouse => mouse.button === Qt.MiddleButton ? Media.player.togglePlaying() : mediaPanel.toggle()
      }
    }

    // --- centre -------------------------------------------------------------
    Pill {
      id: sysPill
      anchors.centerIn: parent
      active: sysPanel.open
      readonly property string bars: "▁▂▃▄▅▆▇█"
      icon: "󰍛"
      text: Sys.history.map(v => bars[Math.min(7, Math.floor(v * 8))]).join("")
        + "  󰾆 " + Sys.memUsed.toFixed(1) + "G"
        + (isNaN(Sys.temp) ? "" : "  \uf2c9 " + Math.round(Sys.temp) + "°")
      color: Sys.memTotal && Sys.memUsed / Sys.memTotal > 0.9 ? Theme.red : Theme.text
      onClicked: sysPanel.toggle()
    }
    SysPanel { id: sysPanel; target: sysPill }

    // --- right --------------------------------------------------------------
    RowLayout {
      anchors.right: parent.right
      anchors.rightMargin: Theme.gap
      anchors.verticalCenter: parent.verticalCenter
      spacing: 2

      Tray {}

      Item { implicitWidth: 6 }

      Pill {
        id: audioPill
        active: audioPanel.open
        icon: Audio.icon(Audio.volume, Audio.muted)
        iconColor: Audio.muted ? Theme.overlay0 : Theme.text
        text: Audio.muted ? "" : Math.round(Audio.volume * 100) + "%"
        // Wheel = volume, middle click = mute, click = panel.
        onWheel: wheel => Audio.nudge(wheel.angleDelta.y > 0 ? 0.05 : -0.05)
        onClicked: mouse => mouse.button === Qt.MiddleButton ? Audio.toggleMute(Audio.sink) : audioPanel.toggle()
      }

      Pill {
        id: btPill
        readonly property var adapter: Bluetooth.defaultAdapter
        readonly property int connected: (adapter?.devices.values ?? []).filter(d => d.connected).length
        visible: adapter !== null
        active: btPanel.open
        icon: !adapter?.enabled ? "󰂲" : connected > 0 ? "󰂱" : "󰂯"
        iconColor: !adapter?.enabled ? Theme.overlay0 : connected > 0 ? Theme.accent : Theme.text
        text: connected > 1 ? connected.toString() : ""
        onClicked: btPanel.toggle()
      }

      Pill {
        id: bellPill
        active: notifPanel.open
        icon: Notifs.dnd ? "󰂛" : Notifs.list.length > 0 ? "󰂚" : "󰂜"
        iconColor: Notifs.dnd ? Theme.overlay0 : Notifs.list.length > 0 ? Theme.accent : Theme.text
        text: Notifs.list.length > 0 ? Notifs.list.length.toString() : ""
        onClicked: mouse => mouse.button === Qt.RightButton ? Notifs.dnd = !Notifs.dnd : notifPanel.toggle()
      }

      Pill {
        id: profilePill
        // Font Awesome bolt / leaf / scale, as in the old waybar module.
        icon: PowerProfiles.profile === PowerProfile.Performance ? "\uf0e7"
            : PowerProfiles.profile === PowerProfile.PowerSaver ? "\uf06c" : "\uf24e"
        // Click cycles saver -> balanced -> performance, like the waybar module.
        onClicked: {
          const order = [PowerProfile.PowerSaver, PowerProfile.Balanced]
          if (PowerProfiles.hasPerformanceProfile) order.push(PowerProfile.Performance)
          PowerProfiles.profile = order[(order.indexOf(PowerProfiles.profile) + 1) % order.length]
        }
      }

      Pill {
        icon: ShellState.stayAwake ? "󰅶" : "󰾪"
        iconColor: ShellState.stayAwake ? Theme.peach : Theme.text
        onClicked: ShellState.stayAwake = !ShellState.stayAwake
      }

      Pill {
        id: batteryPill
        readonly property UPowerDevice bat: UPower.displayDevice
        readonly property bool charging: bat.state === UPowerDeviceState.Charging
        readonly property bool plugged: !UPower.onBattery
        readonly property int pct: Math.round(bat.percentage * 100)
        visible: bat.isLaptopBattery
        active: powerPanel.open
        icon: charging ? "󰂄" : plugged ? "󰚥"
            : ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"][Math.min(10, Math.floor(pct / 10))]
        text: pct + "%"
        color: !plugged && pct <= 20 ? Theme.red : !plugged && pct <= 30 ? Theme.yellow : Theme.text
        iconColor: charging ? Theme.green : color
        onClicked: powerPanel.toggle()
      }

      Pill {
        id: netPill
        active: netPanel.open
        icon: Net.icon
        iconColor: Net.kind === "disconnected" ? Theme.red : Theme.text
        text: Net.kind === "disconnected" ? ""
          : (Net.kind === "wifi" ? Net.name + " " : "") + "↓" + Net.fmtRate(Net.down) + " ↑" + Net.fmtRate(Net.up)
        // Right click keeps the quick path: measure, then a sticky notification.
        onClicked: mouse => mouse.button === Qt.RightButton
          ? Quickshell.execDetached(["net-speedtest", "--notify"])
          : netPanel.toggle()
      }

      Pill {
        id: clockPill
        active: calendar.open
        property date now: new Date()
        icon: "󰃭"
        text: Qt.formatDateTime(now, "dd-MMM | HH:mm")
        onClicked: calendar.toggle()

        // Fire on the minute boundary instead of polling every second.
        Timer {
          running: true
          interval: 60000 - Date.now() % 60000 + 50
          onTriggered: {
            clockPill.now = new Date()
            interval = 60000 - Date.now() % 60000 + 50
            restart()
          }
        }
      }
    }
  }

  Connections {
    target: ShellState
    function onPanelRequested(name, screen) {
      if (screen !== bar.screen.name) return
      const panel = { sys: sysPanel, notifications: notifPanel, power: powerPanel,
                      network: netPanel, calendar: calendar, audio: audioPanel,
                      bluetooth: btPanel, media: mediaPanel }[name]
      if (panel) panel.toggle()
    }
  }

  NotificationPanel { id: notifPanel; target: bellPill }
  AudioPanel { id: audioPanel; target: audioPill }
  BluetoothPanel { id: btPanel; target: btPill }
  MediaPanel { id: mediaPanel; target: mediaPill }
  PowerPanel { id: powerPanel; target: batteryPill }
  NetworkPanel { id: netPanel; target: netPill }
  CalendarPanel { id: calendar; target: clockPill }
}
