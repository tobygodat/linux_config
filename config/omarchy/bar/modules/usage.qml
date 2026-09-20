import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons

// Claude and Codex plan usage in one pill, read from the tobygodat.usage
// plugin's usage-fetch script. Shows one window per provider: the 5-hour
// session by default, or whatever was picked in the plugin's panel
// (~/.config/tobygodat-usage/settings.json). Green while there is headroom,
// the danger colour once that window is nearly spent. Click opens the panel.
Item {
  id: root

  property var bar
  property string moduleName
  property var settings

  readonly property int cell: bar ? bar.barSize : 26
  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property string family: bar ? bar.fontFamily : Style.font.family
  readonly property var providers: settings && settings.providers ? settings.providers : ["anthropic", "openai"]
  // The pill re-reads every minute so a refresh from the panel shows up
  // quickly; the script only goes to the network once its cache is older
  // than refreshSec.
  readonly property int refreshSec: Number(settings && settings.refreshSec ? settings.refreshSec : 300)
  readonly property string home: Quickshell.env("HOME")
  readonly property string script: home + "/.config/omarchy/plugins/tobygodat.usage/usage-fetch"

  // Window shown per provider: a window label, or "tightest".
  property var pill: ({})

  FileView {
    path: root.home + "/.config/tobygodat-usage/settings.json"
    printErrors: false
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      try { root.pill = JSON.parse(text()).pill || {} } catch (e) {}
    }
  }

  property var entries: []

  // Brand marks come from the installed desktop apps' icons; a provider with
  // no icon falls back to its name.
  readonly property var iconNames: ({ "anthropic": "claude-desktop", "openai": "chatgpt" })
  function iconFor(id) {
    var name = iconNames[id]
    return name ? Quickshell.iconPath(name, true) : ""
  }

  function applyUsage(raw) {
    try {
      var all = JSON.parse(raw).entries || []
    } catch (e) { return }
    var out = []
    for (var i = 0; i < providers.length; i++)
      for (var j = 0; j < all.length; j++)
        if (all[j].id === providers[i] && all[j].metrics && all[j].metrics.length > 0) out.push(all[j])
    entries = out
  }

  // The chosen window, or the tightest when the provider has no such
  // window (Codex has no session window on some plans).
  function shown(entry) {
    var want = pill[entry.id] || "session"
    for (var i = 0; want !== "tightest" && i < entry.metrics.length; i++)
      if (entry.metrics[i].label === want) return entry.metrics[i]
    return tightest(entry)
  }

  function tightest(entry) {
    var best = entry.metrics[0]
    for (var i = 1; i < entry.metrics.length; i++)
      if (entry.metrics[i].percent > best.percent) best = entry.metrics[i]
    return best
  }

  function tooltipText() {
    var lines = []
    for (var i = 0; i < entries.length; i++) {
      var e = entries[i]
      lines.push(e.display_name + (e.plan ? "  ·  " + e.plan : ""))
      for (var j = 0; j < e.metrics.length; j++)
        lines.push("  " + e.metrics[j].label + "  " + e.metrics[j].value
          + (e.metrics[j].resets_in ? "  ·  resets in " + e.metrics[j].resets_in : ""))
      if (e.error) lines.push("  " + e.error)
    }
    return lines.join("\n")
  }

  // Last known numbers, read synchronously so the pill is there on the first
  // frame after the bar rebuilds this section.
  FileView {
    id: lastDoc
    path: root.home + "/.cache/tobygodat-usage/last.json"
    printErrors: false
    blockLoading: true
  }
  Component.onCompleted: applyUsage(lastDoc.text())

  Process {
    id: usageProc
    command: [root.script]
    environment: ({ "USAGE_TTL": String(root.refreshSec) })
    stdout: StdioCollector {
      onStreamFinished: root.applyUsage(text)
    }
  }

  Timer {
    interval: 60 * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.fetch(false)
  }

  // The panel drops down from under the pill, so tell it where the pill is:
  // the centre of the drawn pill in the bar window (which spans its screen),
  // and which screen that is.
  function togglePanel() {
    var centre = root.mapToItem(null, root.lead + (root.width - root.lead - root.tail) / 2, root.height)
    var window = root.QsWindow.window
    var payload = JSON.stringify({
      x: Math.round(centre.x),
      screen: window && window.screen ? window.screen.name : ""
    })
    Quickshell.execDetached(["omarchy-shell", "shell", "toggle", "tobygodat.usage", payload])
  }

  function fetch(force) {
    if (usageProc.running) return
    usageProc.command = force ? [root.script, "--force"] : [root.script]
    usageProc.running = true
  }

  visible: entries.length > 0
  // Leading space is built in; see session.qml.
  // The tail matches how far a group pill overhangs its widgets, so every
  // pill can use the same lead whatever it lands next to.
  readonly property int lead: Style.space(14)
  readonly property int tail: Style.space(6)
  implicitWidth: visible ? row.implicitWidth + Style.space(14) * 2 + lead + tail : 0
  implicitHeight: cell

  Rectangle {
    anchors.fill: parent
    anchors.leftMargin: root.lead
    anchors.rightMargin: root.tail
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
    anchors.horizontalCenterOffset: (root.lead - root.tail) / 2
    spacing: Style.spacing.xxl

    Repeater {
      model: root.entries

      Row {
        id: provider
        required property var modelData
        readonly property var metric: root.shown(modelData)
        readonly property bool spent: metric.severity === "critical" || metric.severity === "high" || metric.percent >= 90
        readonly property color tone: spent ? Color.urgent : Color.accent

        spacing: Style.spacing.md

        readonly property string icon: root.iconFor(modelData.id)

        Item {
          visible: provider.icon !== ""
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(16)
          height: width

          Image {
            id: brand
            anchors.fill: parent
            visible: false
            source: provider.icon
            sourceSize.width: 64
            sourceSize.height: 64
            asynchronous: true
          }
          MultiEffect {
            anchors.fill: brand
            source: brand
          }
        }

        Text {
          visible: provider.icon === ""
          anchors.verticalCenter: parent.verticalCenter
          text: String(provider.modelData.display_name).toLowerCase()
          color: root.foreground
          opacity: 0.7
          font.family: root.family
          font.pixelSize: Style.font.body
        }

        // 2px meter, same idiom as the dashboard's.
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(28)
          height: 2
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)

          Rectangle {
            width: parent.width * Math.max(0, Math.min(1, provider.metric.percent / 100))
            height: parent.height
            color: provider.tone
          }
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: provider.metric.value
          color: provider.tone
          font.family: root.family
          font.pixelSize: Style.font.body
        }
      }
    }
  }

  MouseArea {
    id: hover
    anchors.fill: parent
    anchors.leftMargin: root.lead
    anchors.rightMargin: root.tail
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton) root.fetch(true)
      else root.togglePanel()
    }
    onEntered: if (root.bar) root.bar.showTooltip(root, root.tooltipText())
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  // A pill, not an icon: it stays where it is (see Locked.qml).
  Locked {}
}
