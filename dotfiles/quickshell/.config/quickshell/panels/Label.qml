import QtQuick
import qs

Text {
  property bool dim: false
  property bool heading: false

  color: dim ? Theme.subtext0 : Theme.text
  font.family: Theme.font
  font.pixelSize: heading ? Theme.fontHeading : dim ? Theme.fontSmall : Theme.fontSize
  font.bold: heading
}
