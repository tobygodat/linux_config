import QtQuick
import qs.Commons

// Power glyph at the foot of the bar; opens Omarchy's system menu.
Item {
  id: root

  property var bar
  property string moduleName
  property var settings

  readonly property int cell: bar ? bar.barSize : 28

  // Leading space is built in, so no separate spacer module is needed (the
  // bar's drag-to-rearrange cannot tell identical spacers apart).
  readonly property int lead: Style.space(10)

  implicitWidth: cell + lead
  implicitHeight: cell

  Text {
    anchors.centerIn: parent
    anchors.horizontalCenterOffset: root.lead / 2
    text: ""
    color: Color.urgent
    opacity: hover.containsMouse ? 1 : 0.8
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.iconLarge
  }

  MouseArea {
    id: hover
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: if (root.bar) root.bar.run("omarchy-menu toggle system")
    onEntered: if (root.bar) root.bar.showTooltip(root, "system")
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  // Part of the frame, not an icon: it stays where it is (see Locked.qml).
  Locked {}
}
