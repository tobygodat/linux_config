import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// AI usage — every Claude and Codex rate-limit window, how far into it the
// clock is, and when it resets. Numbers come from ./usage-fetch. Clicking a
// window picks it as the one the bar pill shows for that provider.
//
// Nothing polls while the card is closed. The panel stays loaded
// (keepLoaded), so the last numbers are on screen the moment it opens and the
// fetch only freshens them.
Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  property bool opened: false

  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color accent: Color.accent
  readonly property color dim: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.62)
  readonly property color hairline: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.14)
  property string fontFamily: Style.font.menuFamily
  property string monoFamily: Style.font.family

  readonly property string script: String(Qt.resolvedUrl("usage-fetch")).replace(/^file:\/\//, "")
  readonly property string settingsPath: Quickshell.env("HOME") + "/.config/tobygodat-usage/settings.json"

  // ------------------------------------------------------------- lifecycle

  function open(payloadJson) {
    // The bar pill says where it is so the card can drop down from under it.
    var anchor = {}
    try { anchor = JSON.parse(payloadJson || "{}") || {} } catch (e) {}
    root.anchorX = typeof anchor.x === "number" ? anchor.x : -1
    root.anchorScreen = typeof anchor.screen === "string" ? anchor.screen : ""
    root.opened = true
    fetch(false)
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() { root.opened = false }

  function dismiss() {
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "tobygodat.usage")
    else close()
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  // ------------------------------------------------------------------ data

  property var entries: []
  property double generatedAt: 0
  property bool loading: false

  // Where the card hangs from: the pill's centre on its screen, or -1 to sit
  // at the right edge (opened from a keybind or the CLI).
  property real anchorX: -1
  property string anchorScreen: ""

  // Last document usage-fetch wrote, so the card has numbers before the
  // script answers (the bar pill does the same).
  FileView {
    id: lastDoc
    path: Quickshell.env("HOME") + "/.cache/tobygodat-usage/last.json"
    printErrors: false
    blockLoading: true
  }
  Component.onCompleted: {
    var cached = lastDoc.text()
    if (cached) {
      root.applyUsage(cached)
      try { root.generatedAt = (JSON.parse(cached).generated_at || 0) * 1000 } catch (e) {}
    }
  }

  function fetch(force) {
    if (usageProc.running) return
    usageProc.command = force ? [root.script, "--force"] : [root.script]
    root.loading = true
    usageProc.running = true
  }

  function applyUsage(raw) {
    root.loading = false
    try {
      var doc = JSON.parse(raw)
    } catch (e) { return }
    entries = doc.entries || []
    generatedAt = Date.now()
  }

  Process {
    id: usageProc
    stdout: StdioCollector {
      onStreamFinished: root.applyUsage(text)
    }
  }

  // Keeps "resets in" honest while the card stays open.
  Timer {
    interval: 60 * 1000
    repeat: true
    running: root.opened
    onTriggered: root.fetch(false)
  }

  function age(entry) {
    if (!entry.fetched_at) return ""
    var secs = Math.max(0, Math.floor(root.generatedAt / 1000) - entry.fetched_at)
    if (secs < 90) return "just now"
    if (secs < 5400) return Math.round(secs / 60) + "m ago"
    if (secs < 129600) return Math.round(secs / 3600) + "h ago"
    return Math.round(secs / 86400) + "d ago"
  }

  function caption(metric) {
    var parts = []
    if (metric.resets_in) parts.push("resets in " + metric.resets_in)
    if (metric.pace !== null && metric.pace !== undefined) {
      if (metric.pace > 2) parts.push(metric.pace + " pts ahead of the clock")
      else if (metric.pace < -2) parts.push(-metric.pace + " pts under")
      else parts.push("on pace")
    }
    return parts.join("  ·  ")
  }

  // -------------------------------------------------------------- settings

  // Which window the bar pill shows per provider: a window label, or
  // "tightest". The pill reads the same file.
  property var pill: ({})

  function pillChoice(id) { return pill[id] || "session" }

  function choose(id, label) {
    var next = {}
    for (var k in pill) next[k] = pill[k]
    next[id] = label
    pill = next
    saveProc.command = ["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf '%s\\n' \"$2\" > \"$1\"", "sh",
      root.settingsPath, JSON.stringify({ pill: next }, null, 2)]
    saveProc.running = true
  }

  FileView {
    id: settingsFile
    path: root.settingsPath
    printErrors: false
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      try { root.pill = JSON.parse(text()).pill || {} } catch (e) {}
    }
  }

  Process { id: saveProc }

  readonly property var iconNames: ({ "anthropic": "claude-desktop", "openai": "chatgpt" })

  // ------------------------------------------------------------ components

  component Word: Text {
    property bool hot: wordMouse.containsMouse
    signal clicked()

    color: hot ? root.accent : root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.body

    MouseArea {
      id: wordMouse
      anchors.fill: parent
      anchors.margins: -Style.spacing.sm
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: parent.clicked()
    }
  }

  // One rate-limit window. The tick on the rule is the clock: fill left of
  // it means headroom, fill past it means burning faster than the window.
  component Window: Item {
    id: win
    property var metric
    property bool chosen: false
    signal picked()

    readonly property bool spent: metric.severity === "critical" || metric.severity === "high"
    readonly property color tone: spent ? Color.urgent : root.accent

    implicitHeight: winBody.implicitHeight

    Column {
      id: winBody
      width: parent.width
      spacing: Style.spacing.sm

      Item {
        width: parent.width
        height: winLabel.implicitHeight

        Text {
          id: winLabel
          text: win.metric.label
          color: winMouse.containsMouse ? root.foreground : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
        Text {
          anchors.left: winLabel.right
          anchors.leftMargin: Style.spacing.md
          anchors.baseline: winLabel.baseline
          visible: win.chosen || winMouse.containsMouse
          text: win.chosen ? "in bar" : "show in bar"
          color: root.accent
          opacity: win.chosen ? 1 : 0.7
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.italic: true
        }
        Text {
          anchors.right: parent.right
          text: win.metric.value
          color: win.spent ? Color.urgent : root.foreground
          font.family: root.monoFamily
          font.pixelSize: Style.font.bodySmall
        }
      }

      Item {
        width: parent.width
        height: Style.space(8)

        Rectangle {
          id: rule
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width
          height: Math.max(2, Style.space(2))
          color: root.hairline

          Rectangle {
            width: parent.width * Math.max(0, Math.min(1, win.metric.percent / 100))
            height: parent.height
            color: win.tone

            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
          }
        }

        Rectangle {
          visible: win.metric.elapsed !== null && win.metric.elapsed !== undefined
          x: Math.round((parent.width - width) * Math.max(0, Math.min(1, (win.metric.elapsed || 0) / 100)))
          width: Math.max(1, Style.space(1))
          height: parent.height
          color: root.foreground
          opacity: 0.55
        }
      }

      Text {
        width: parent.width
        visible: text !== ""
        text: root.caption(win.metric)
        color: root.dim
        opacity: 0.8
        elide: Text.ElideRight
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    MouseArea {
      id: winMouse
      anchors.fill: parent
      anchors.margins: -Style.spacing.sm
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: win.picked()
    }
  }

  // -------------------------------------------------------------------- UI

  PanelWindow {
    id: window
    visible: root.opened
    screen: {
      var want = root.anchorScreen || (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "")
      var screens = Quickshell.screens
      for (var i = 0; want && i < screens.length; i++)
        if (screens[i].name === want) return screens[i]
      return screens[0]
    }
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "tobygodat-usage"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      // Directly under the pill, centred on it, kept on screen.
      readonly property real edge: Style.gapsOut * 2
      anchors.top: parent.top
      anchors.topMargin: Style.bar.sizeHorizontal + Style.gapsOut
      x: root.anchorX < 0
        ? window.width - width - edge
        : Math.round(Math.max(edge, Math.min(window.width - width - edge, root.anchorX - width / 2)))
      width: Math.min(Style.space(400), window.width - Style.gapsOut * 4)
      height: body.implicitHeight + contentTopInset + contentBottomInset
      radius: Style.cornerRadius
      color: root.background
      borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(1)))
      padding: Style.spacing.panelPadding

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.onPressed: function(event) {
          if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) return
          var handled = true
          if (event.key === Qt.Key_Escape || event.key === Qt.Key_Q) root.dismiss()
          else if (event.key === Qt.Key_R) root.fetch(true)
          else handled = false
          event.accepted = handled
        }
      }

      ColumnLayout {
        id: body
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: card.contentTopInset
        anchors.leftMargin: card.contentLeftInset
        anchors.rightMargin: card.contentRightInset
        spacing: Style.spacing.panelGap

        Repeater {
          model: root.entries

          ColumnLayout {
            id: provider
            required property var modelData
            required property int index
            readonly property string choice: root.pillChoice(modelData.id)
            // A choice the provider does not have (Codex has no session
            // window on this plan) falls back to the tightest one.
            readonly property bool choiceExists: {
              for (var i = 0; i < modelData.metrics.length; i++)
                if (modelData.metrics[i].label === choice) return true
              return false
            }

            Layout.fillWidth: true
            spacing: Style.spacing.lg

            PanelSeparator {
              visible: provider.index > 0
              foreground: root.foreground
              Layout.fillWidth: true
              Layout.bottomMargin: Style.spacing.sm
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.spacing.md

              Image {
                readonly property string name: root.iconNames[provider.modelData.id] || ""
                visible: name !== "" && status === Image.Ready
                source: name !== "" ? Quickshell.iconPath(name, true) : ""
                sourceSize.width: 64
                sourceSize.height: 64
                Layout.preferredWidth: Style.space(18)
                Layout.preferredHeight: Style.space(18)
              }
              Text {
                text: "//"
                color: root.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.heading
                font.italic: true
              }
              Text {
                text: String(provider.modelData.display_name).toLowerCase()
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.heading
                font.bold: true
              }
              Item { Layout.fillWidth: true }
              Text {
                text: provider.modelData.plan || ""
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Repeater {
              model: provider.modelData.metrics

              Window {
                required property var modelData
                Layout.fillWidth: true
                metric: modelData
                chosen: provider.choice === modelData.label
                onPicked: root.choose(provider.modelData.id, modelData.label)
              }
            }

            Text {
              visible: provider.modelData.metrics.length === 0 && !provider.modelData.error
              text: "no windows reported"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            Text {
              Layout.fillWidth: true
              visible: !!provider.modelData.error
              text: (provider.modelData.error || "") + (provider.modelData.stale ? "  ·  showing " + root.age(provider.modelData) : "")
              color: Color.urgent
              wrapMode: Text.WordWrap
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.spacing.lg

              Text {
                text: "bar shows"
                color: root.dim
                opacity: 0.8
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
              Word {
                text: "tightest"
                font.pixelSize: Style.font.caption
                color: provider.choice === "tightest" || hot ? root.accent : root.dim
                onClicked: root.choose(provider.modelData.id, "tightest")
              }
              Text {
                Layout.fillWidth: true
                visible: provider.choice !== "tightest"
                text: "/  " + provider.choice + (provider.choiceExists ? "" : "  (none here, so tightest)")
                color: provider.choiceExists ? root.accent : root.dim
                elide: Text.ElideRight
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
              Item { Layout.fillWidth: true; visible: provider.choice === "tightest" }
            }

            Text {
              visible: (provider.modelData.resets_available || 0) > 0
              text: provider.modelData.resets_available + " limit reset available"
              color: root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.italic: true
            }
          }
        }

        Text {
          visible: root.entries.length === 0
          text: root.loading ? "asking…" : "nothing yet"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }

        PanelSeparator {
          foreground: root.foreground
          Layout.fillWidth: true
        }

        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: refresh.implicitHeight

          Word {
            id: refresh
            text: root.loading ? "asking…" : "refresh"
            font.pixelSize: Style.font.caption
            onClicked: root.fetch(true)
          }
          Text {
            anchors.right: parent.right
            text: "click a window to show it in the bar  ·  r  ·  esc"
            color: root.dim
            opacity: 0.7
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }
}
