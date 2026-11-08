import QtQuick
import qs

Text {
  property bool dim: false
  property bool heading: false

  color: dim ? Theme.subtext0 : Theme.text
  font.family: Theme.font
  font.pixelSize: heading ? 16 : dim ? Theme.fontSmall + 1 : Theme.fontSize
  font.bold: heading
}
