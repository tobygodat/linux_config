import QtQuick
import qs.Commons

// Group separator: the accent slash from the theme's "// heading" motif.
Item {
  id: root

  property var bar
  property string moduleName
  property var settings

  readonly property bool vertical: bar ? bar.vertical : false
  readonly property int cell: bar ? bar.barSize : 26
  readonly property int pad: Style.space(7)

  implicitWidth: vertical ? cell : slash.implicitWidth + pad * 2
  implicitHeight: vertical ? slash.implicitHeight + pad : cell

  Text {
    id: slash
    anchors.centerIn: parent
    text: "/"
    color: Color.accent
    opacity: 0.75
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.body
    font.italic: true
  }

  // Part of the frame, not an icon: it stays where it is (see Locked.qml).
  Locked {}
}
