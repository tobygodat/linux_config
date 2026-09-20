import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.Commons

// One pill in the middle of the bar: focused app, then day and time. The whole
// pill is the dashboard button.
Item {
  id: root

  property var bar
  property string moduleName
  property var settings

  readonly property int cell: bar ? bar.barSize : 26
  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property string family: bar ? bar.fontFamily : Style.font.family
  readonly property int maxTitle: Number(settings && settings.maxTitle ? settings.maxTitle : 320)
  readonly property int iconSize: Style.space(16)

  readonly property var toplevel: ToplevelManager.activeToplevel
  readonly property string appId: toplevel ? (toplevel.appId || "") : ""
  readonly property string title: toplevel ? (toplevel.title || appId) : "desktop"
  readonly property string icon: {
    if (appId === "") return ""
    var entry = DesktopEntries.heuristicLookup(appId)
    return Quickshell.iconPath(entry && entry.icon ? entry.icon : appId, "application-x-executable")
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  implicitWidth: row.implicitWidth + Style.space(14) * 2
  implicitHeight: cell

  Rectangle {
    id: pill
    anchors.fill: parent
    anchors.topMargin: Style.space(4)
    anchors.bottomMargin: Style.space(4)
    radius: height / 2
    color: hover.containsMouse ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.08) : "transparent"
    border.width: 1
    border.color: hover.containsMouse
      ? Color.accent
      : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.22)

    Behavior on border.color { ColorAnimation { duration: 120 } }
  }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Style.spacing.lg

    Item {
      visible: root.icon !== ""
      width: root.iconSize
      height: root.iconSize
      anchors.verticalCenter: parent.verticalCenter

      Image {
        id: appIcon
        anchors.fill: parent
        visible: false
        source: root.icon
        sourceSize.width: 64
        sourceSize.height: 64
        asynchronous: true
      }
      MultiEffect {
        anchors.fill: appIcon
        source: appIcon
      }
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      width: Math.min(root.maxTitle, implicitWidth)
      textFormat: Text.PlainText
      text: root.title.toLowerCase()
      elide: Text.ElideRight
      color: root.foreground
      font.family: root.family
      font.pixelSize: Style.font.body
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: "/"
      color: Color.accent
      opacity: 0.75
      font.family: root.family
      font.pixelSize: Style.font.body
      font.italic: true
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: Qt.formatDate(clock.date, "ddd d MMM").toLowerCase()
      color: root.foreground
      opacity: 0.7
      font.family: root.family
      font.pixelSize: Style.font.body
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: Qt.formatTime(clock.date, "h:mm ap").toLowerCase()
      color: Color.accent
      font.family: root.family
      font.pixelSize: Style.font.body
    }
  }

  MouseArea {
    id: hover
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: if (root.bar) root.bar.run("omarchy-shell shell toggle tobygodat.dashboard")
  }

  // A pill, not an icon: it stays where it is (see Locked.qml).
  Locked {}
}
