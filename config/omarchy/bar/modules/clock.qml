import QtQuick
import Quickshell
import qs.Commons

// Day in the bar's text colour, time in the accent. Click opens the dashboard.
Item {
  id: root

  property var bar
  property string moduleName
  property var settings

  readonly property bool vertical: bar ? bar.vertical : false
  readonly property int cell: bar ? bar.barSize : 26
  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property string family: bar ? bar.fontFamily : Style.font.family

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  readonly property string time: Qt.formatTime(clock.date, "h:mm ap").toLowerCase()

  implicitWidth: vertical ? cell : row.implicitWidth + Style.spacing.lg * 2
  implicitHeight: vertical ? column.implicitHeight + Style.spacing.lg * 2 : cell

  Row {
    id: row
    visible: !root.vertical
    anchors.centerIn: parent
    spacing: Style.spacing.lg

    Text {
      text: Qt.formatDate(clock.date, "dddd").toLowerCase()
      color: root.foreground
      opacity: 0.7
      font.family: root.family
      font.pixelSize: Style.font.body
    }
    Text {
      text: root.time
      color: Color.accent
      font.family: root.family
      font.pixelSize: Style.font.body
    }
  }

  Column {
    id: column
    visible: root.vertical
    anchors.centerIn: parent

    Repeater {
      model: root.time.split(" ")[0].split(":")

      Text {
        required property string modelData
        anchors.horizontalCenter: parent.horizontalCenter
        text: modelData
        color: Color.accent
        font.family: root.family
        font.pixelSize: Style.font.body
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: if (root.bar) root.bar.run("omarchy-shell shell toggle tobygodat.dashboard")
    onEntered: if (root.bar) root.bar.showTooltip(root, Qt.formatDate(clock.date, "dddd d MMMM yyyy").toLowerCase() + "  ·  dashboard")
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }
}
