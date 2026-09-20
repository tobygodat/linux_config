import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.Commons

// Focused window: app icon, then the title running down the bar.
Item {
  id: root

  property var bar
  property string moduleName
  property var settings

  readonly property bool vertical: bar ? bar.vertical : true
  readonly property int cell: bar ? bar.barSize : 28
  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property int maxLength: Number(settings && settings.maxLength ? settings.maxLength : 260)

  readonly property var toplevel: ToplevelManager.activeToplevel
  readonly property string appId: toplevel ? (toplevel.appId || "") : ""
  readonly property string title: toplevel ? (toplevel.title || appId) : "desktop"
  readonly property string icon: {
    if (appId === "") return ""
    var entry = DesktopEntries.heuristicLookup(appId)
    return Quickshell.iconPath(entry && entry.icon ? entry.icon : appId, "application-x-executable")
  }
  readonly property real labelLength: Math.min(maxLength, label.implicitWidth)
  readonly property int gap: Style.spacing.lg

  implicitWidth: vertical ? cell : iconSize + gap + labelLength
  implicitHeight: vertical ? iconSize + gap + labelLength : cell

  readonly property int iconSize: Style.space(18)

  Image {
    id: appIcon
    width: root.iconSize
    height: root.iconSize
    x: root.vertical ? (root.width - width) / 2 : 0
    y: root.vertical ? 0 : (root.height - height) / 2
    visible: false
    source: root.icon
    sourceSize.width: 64
    sourceSize.height: 64
    asynchronous: true
  }

  MultiEffect {
    anchors.fill: appIcon
    source: appIcon
    visible: root.icon !== ""
    saturation: -1
    opacity: 0.85
  }

  Item {
    x: root.vertical ? 0 : root.iconSize + root.gap
    y: root.vertical ? root.iconSize + root.gap : 0
    width: root.vertical ? root.cell : root.labelLength
    height: root.vertical ? root.labelLength : root.cell
    clip: true

    Text {
      id: label
      anchors.centerIn: parent
      width: root.labelLength
      rotation: root.vertical ? 90 : 0
      textFormat: Text.PlainText
      text: root.title.toLowerCase()
      elide: Text.ElideRight
      color: root.foreground
      opacity: 0.85
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onEntered: if (root.bar && root.toplevel) root.bar.showTooltip(root, root.title)
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }
}
