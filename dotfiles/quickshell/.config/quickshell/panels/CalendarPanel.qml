import QtQuick
import QtQuick.Layouts
import Quickshell
import qs

// Month calendar with ISO week numbers (Monday first, the de_CH week).
// Wheel or the chevrons step months; clicking the title jumps back to today.
Popup {
  id: root

  property date now: new Date()
  property int year: now.getFullYear()
  property int month: now.getMonth()

  function today() {
    root.now = new Date()
    root.year = root.now.getFullYear()
    root.month = root.now.getMonth()
  }
  onOpenChanged: if (open) root.today()

  function step(delta) {
    const d = new Date(root.year, root.month + delta, 1)
    root.year = d.getFullYear()
    root.month = d.getMonth()
  }

  function isoWeek(d) {
    const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
    const day = t.getUTCDay() || 7
    t.setUTCDate(t.getUTCDate() + 4 - day)
    const jan1 = new Date(Date.UTC(t.getUTCFullYear(), 0, 1))
    return Math.ceil(((t - jan1) / 86400000 + 1) / 7)
  }

  // Six rows of [week, d1..d7]; always 6 so the card never changes height.
  readonly property var rows: {
    const first = new Date(root.year, root.month, 1)
    const offset = (first.getDay() + 6) % 7
    const start = new Date(root.year, root.month, 1 - offset)
    const out = []
    for (let r = 0; r < 6; r++) {
      const days = []
      for (let c = 0; c < 7; c++) {
        days.push(new Date(start.getFullYear(), start.getMonth(), start.getDate() + r * 7 + c))
      }
      out.push({ week: root.isoWeek(days[0]), days: days })
    }
    return out
  }

  RowLayout {
    Layout.fillWidth: true

    Label {
      text: "‹"
      heading: true
      MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: root.step(-1) }
    }
    Label {
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
      heading: true
      text: Qt.locale().standaloneMonthName(root.month) + " " + root.year
      MouseArea { anchors.fill: parent; onClicked: root.today() }
    }
    Label {
      text: "›"
      heading: true
      MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: root.step(1) }
    }
  }

  GridLayout {
    id: grid
    columns: 8
    rowSpacing: 2
    columnSpacing: 2

    Label { text: "KW"; dim: true; Layout.preferredWidth: 30; horizontalAlignment: Text.AlignHCenter }
    Repeater {
      model: 7
      Label {
        required property int index
        Layout.preferredWidth: 30
        horizontalAlignment: Text.AlignHCenter
        dim: true
        color: index >= 5 ? Theme.peach : Theme.subtext0
        text: Qt.locale().dayName((index + 1) % 7, Locale.ShortFormat).slice(0, 2)
      }
    }

    Repeater {
      model: root.rows
      delegate: Repeater {
        id: weekRow
        required property var modelData
        model: 8
        delegate: Rectangle {
          required property int index
          readonly property var day: index > 0 ? weekRow.modelData.days[index - 1] : null
          readonly property bool today: day !== null && day.toDateString() === root.now.toDateString()
          readonly property bool inMonth: day !== null && day.getMonth() === root.month

          Layout.preferredWidth: 30
          Layout.preferredHeight: 26
          radius: 13
          color: today ? Theme.accent : "transparent"

          Label {
            anchors.centerIn: parent
            text: parent.day === null ? weekRow.modelData.week : parent.day.getDate()
            dim: parent.day === null || !parent.inMonth
            opacity: parent.day !== null && !parent.inMonth ? 0.45 : 1
            color: parent.today ? Theme.crust : parent.day === null ? Theme.overlay0 : Theme.text
            font.bold: parent.today
          }
        }
      }
    }
  }

  Label {
    Layout.fillWidth: true
    horizontalAlignment: Text.AlignHCenter
    dim: true
    text: root.now.toLocaleDateString(Qt.locale(), "dddd, d. MMMM yyyy") + "  ·  KW " + root.isoWeek(root.now)
  }

  WheelHandler {
    target: null
    property real acc: 0
    onWheel: event => {
      acc += event.angleDelta.y
      while (Math.abs(acc) >= 120) {
        root.step(acc > 0 ? -1 : 1)
        acc -= Math.sign(acc) * 120
      }
    }
  }
}
