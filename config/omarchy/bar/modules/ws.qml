import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import qs.Commons

// Workspaces as a ruled group. An occupied workspace shows its windows' app
// icons bundled into one overlapping stack; an empty one shows a dot. Only the
// focused workspace is in colour, with the accent rule under the whole stack.
Item {
  id: root

  property var bar
  property string moduleName
  property var settings

  readonly property bool vertical: bar ? bar.vertical : false
  readonly property int cell: bar ? bar.barSize : 28
  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property color hairline: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.22)
  readonly property int inset: Style.space(5)
  readonly property int iconSize: Style.space(18)
  readonly property int step: Style.space(11)      // how far each stacked icon is offset
  readonly property int maxIcons: 3
  readonly property int slotPad: Style.space(8)

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++)
      if (values[i].id === id) return values[i]
    return null
  }

  readonly property var workspaceIds: {
    var ids = [1, 2, 3, 4, 5]
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0 && id <= 10 && ids.indexOf(id) === -1) ids.push(id)
    }
    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function iconsFor(workspace) {
    var out = []
    if (!workspace) return out
    var windows = workspace.toplevels.values
    for (var i = 0; i < windows.length && out.length < maxIcons; i++) {
      var ipc = windows[i].lastIpcObject || {}
      var appId = (windows[i].wayland && windows[i].wayland.appId) || ipc.class || ""
      if (appId === "") continue
      var entry = DesktopEntries.heuristicLookup(appId)
      out.push(Quickshell.iconPath(entry && entry.icon ? entry.icon : appId, "application-x-executable"))
    }
    return out
  }

  implicitWidth: vertical ? cell : group.implicitWidth + inset * 2
  implicitHeight: vertical ? group.implicitHeight + inset * 2 : cell

  Rectangle {
    anchors.fill: parent
    anchors.margins: Style.space(3)
    color: "transparent"
    border.width: 1
    border.color: root.hairline
    radius: height / 2
  }

  Grid {
    id: group
    anchors.centerIn: parent
    columns: root.vertical ? 1 : root.workspaceIds.length
    verticalItemAlignment: Grid.AlignVCenter
    horizontalItemAlignment: Grid.AlignHCenter

    Repeater {
      model: root.workspaceIds

      Item {
        id: slot
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData
        readonly property var icons: root.iconsFor(workspace)
        // Length of the icon stack along the bar.
        readonly property int stackLength: icons.length > 0 ? root.iconSize + (icons.length - 1) * root.step : Style.space(4)
        readonly property int along: stackLength + root.slotPad * 2
        readonly property int across: root.cell - Style.space(4)

        width: root.vertical ? across : along
        height: root.vertical ? along : across

        Item {
          id: stack
          anchors.centerIn: parent
          width: root.vertical ? root.iconSize : slot.stackLength
          height: root.vertical ? slot.stackLength : root.iconSize

          Repeater {
            model: slot.icons

            Item {
              id: chip
              required property string modelData
              required property int index

              x: root.vertical ? 0 : index * root.step
              y: root.vertical ? index * root.step : 0
              z: index
              width: root.iconSize
              height: root.iconSize

              // Bar-coloured backing so the icon on top cuts a clean edge
              // out of the one beneath it.
              Rectangle {
                visible: chip.index > 0
                anchors.centerIn: parent
                width: parent.width + Style.space(4)
                height: width
                radius: width / 2
                color: Color.bar.background
              }

              Image {
                id: appIcon
                anchors.fill: parent
                visible: false
                source: chip.modelData
                sourceSize.width: 64
                sourceSize.height: 64
                asynchronous: true
              }

              MultiEffect {
                anchors.fill: appIcon
                source: appIcon
                saturation: slot.focused ? 0 : -1
                opacity: slot.focused ? 1 : (hover.containsMouse ? 0.85 : 0.5)
              }
            }
          }

          Rectangle {
            anchors.centerIn: parent
            visible: slot.icons.length === 0
            width: Style.space(4)
            height: width
            radius: width / 2
            color: slot.focused ? Color.accent : root.foreground
            opacity: slot.focused ? 1 : (hover.containsMouse ? 0.8 : 0.35)
          }
        }

        // "here": one accent rule under the whole bundle.
        Rectangle {
          visible: slot.focused
          color: Color.accent
          width: root.vertical ? 2 : Math.max(Style.space(12), slot.stackLength)
          height: root.vertical ? Math.max(Style.space(12), slot.stackLength) : 2
          x: root.vertical ? Style.space(4) : (parent.width - width) / 2
          y: root.vertical ? (parent.height - height) / 2 : parent.height - height - Style.space(1)
        }

        MouseArea {
          id: hover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: if (root.bar) root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + slot.modelData + "\" })"))
        }
      }
    }
  }

  // A pill, not an icon: it stays where it is (see Locked.qml).
  Locked {}
}
