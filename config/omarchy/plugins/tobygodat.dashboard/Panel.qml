import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// Dashboard — the glanceable half of caelestia-dots/shell's dashboard (clock,
// weather, calendar, media, resources) rebuilt on Omarchy's tokens. Rules
// instead of boxes, words instead of icons, and the accent only ever marks
// "here": today in the calendar, and how far into the track you are.
//
// Nothing polls while the card is closed. The panel stays loaded
// (keepLoaded) and weather is cached on disk, so opening it shows the last
// reading at once; a stale reading is refreshed behind it.
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

  // ------------------------------------------------------------- lifecycle

  function open(payloadJson) {
    var now = new Date()
    viewYear = now.getFullYear()
    viewMonth = now.getMonth()
    root.opened = true
    statsProc.running = true
    refreshWeather(false)
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() { root.opened = false }

  function dismiss() {
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "tobygodat.dashboard")
    else close()
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  // --------------------------------------------------------------- weather

  property string weatherText: ""
  property string weatherIcon: ""
  property double weatherFetchedAt: 0

  readonly property int weatherMaxAge: 15 * 60 * 1000
  readonly property string weatherCachePath: Quickshell.env("HOME") + "/.cache/tobygodat-dashboard/weather.json"

  // wttr.in takes one to several seconds, so the last reading is kept on
  // disk and shown while a new one is fetched.
  FileView {
    id: weatherCache
    path: root.weatherCachePath
    printErrors: false
    blockLoading: true
  }

  Component.onCompleted: {
    try {
      var cached = JSON.parse(weatherCache.text() || "{}")
      if (cached.text) root.weatherText = cached.text
      if (cached.icon) root.weatherIcon = cached.icon
      root.weatherFetchedAt = Number(cached.at) || 0
    } catch (e) {}
    // Warm up at shell start so the first open is not a cold fetch.
    refreshWeather(false)
  }

  function refreshWeather(force) {
    if (weatherProc.running || weatherIconProc.running) return
    if (!force && Date.now() - weatherFetchedAt < weatherMaxAge) return
    weatherProc.running = true
    weatherIconProc.running = true
  }

  // Both scripts run at once and land close together; write the cache once.
  function saveWeather() { saveWeatherTimer.restart() }

  Timer {
    id: saveWeatherTimer
    interval: 500
    onTriggered: root.writeWeatherCache()
  }

  function writeWeatherCache() {
    saveWeatherProc.command = ["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf '%s\\n' \"$2\" > \"$1\"", "sh",
      root.weatherCachePath,
      JSON.stringify({ text: root.weatherText, icon: root.weatherIcon, at: root.weatherFetchedAt })]
    saveWeatherProc.running = true
  }

  Process { id: saveWeatherProc }

  // "atlanta  ·  temp 82°f  ·  wind ↙9mph" → the temperature on its own, and
  // everything else as the caption beside it.
  readonly property var weatherParts: String(weatherText).split(/\s+·\s+/)
  readonly property string weatherTemp: {
    for (var i = 0; i < weatherParts.length; i++)
      if (weatherParts[i].indexOf("temp ") === 0) return weatherParts[i].slice(5)
    return ""
  }
  readonly property string weatherCaption: weatherParts.filter(function(part) {
    return part !== "" && part.indexOf("temp ") !== 0
  }).join("  ·  ")

  Process {
    id: weatherProc
    command: ["omarchy-weather-status"]
    stdout: StdioCollector {
      onStreamFinished: {
        var line = String(text || "").trim()
        // The script prints this on failure; keep the last good reading.
        if (line === "" || line === "Weather unavailable") return
        root.weatherText = line.toLowerCase()
        root.weatherFetchedAt = Date.now()
        root.saveWeather()
      }
    }
  }

  Process {
    id: weatherIconProc
    command: ["omarchy-weather-icon"]
    stdout: StdioCollector {
      onStreamFinished: {
        var glyph = String(text || "").trim()
        if (glyph === "") return
        root.weatherIcon = glyph
        root.saveWeather()
      }
    }
  }

  // -------------------------------------------------------------- calendar

  property int viewYear: 1970
  property int viewMonth: 0
  readonly property int firstDayOfWeek: Qt.locale().firstDayOfWeek % 7   // 0 = Sunday

  readonly property var weekdayLabels: {
    var out = []
    for (var i = 0; i < 7; i++)
      out.push(Qt.locale().dayName((firstDayOfWeek + i) % 7, Locale.NarrowFormat).toLowerCase())
    return out
  }

  // Always six rows so the card does not change height between months.
  readonly property var calendarCells: {
    var today = clock.date
    var lead = (new Date(viewYear, viewMonth, 1).getDay() - firstDayOfWeek + 7) % 7
    var out = []
    for (var i = 0; i < 42; i++) {
      var d = new Date(viewYear, viewMonth, 1 - lead + i)
      out.push({
        day: d.getDate(),
        inMonth: d.getMonth() === viewMonth,
        today: d.getFullYear() === today.getFullYear()
          && d.getMonth() === today.getMonth() && d.getDate() === today.getDate()
      })
    }
    return out
  }

  function shiftMonth(delta) {
    var d = new Date(viewYear, viewMonth + delta, 1)
    viewYear = d.getFullYear()
    viewMonth = d.getMonth()
  }

  function showToday() {
    viewYear = clock.date.getFullYear()
    viewMonth = clock.date.getMonth()
  }

  // ----------------------------------------------------------------- media

  readonly property var player: {
    var players = Mpris.players.values
    for (var i = 0; i < players.length; i++)
      if (players[i].isPlaying) return players[i]
    return players.length > 0 ? players[0] : null
  }

  // Mpris position is only re-read on demand, so nudge it while visible.
  Timer {
    interval: 1000
    repeat: true
    running: root.opened && root.player !== null && root.player.isPlaying
    onTriggered: root.player.positionChanged()
  }

  // Nerd Font brand glyphs; anything unrecognised gets a plain note.
  function playerGlyph(identity) {
    var name = String(identity || "").toLowerCase()
    if (name.indexOf("spotify") !== -1) return "\uf1bc"
    if (name.indexOf("firefox") !== -1 || name.indexOf("zen") !== -1) return "\uf269"
    if (name.indexOf("chrom") !== -1 || name.indexOf("brave") !== -1) return "\uf268"
    if (name.indexOf("mpv") !== -1 || name.indexOf("vlc") !== -1) return "\uf03d"
    return "\uf001"
  }

  function clockTime(seconds) {
    var s = Math.max(0, Math.floor(seconds))
    var m = Math.floor(s / 60)
    var r = s % 60
    return m + ":" + (r < 10 ? "0" : "") + r
  }

  // ------------------------------------------------------------- resources

  property real cpuFraction: 0
  property real memFraction: 0
  property real diskFraction: 0
  property string memText: ""
  property string diskText: ""
  property string tempText: ""
  property string uptimeText: ""
  property double cpuTotalPrev: 0
  property double cpuIdlePrev: 0

  readonly property string statsScript:
      'read -r _ a b c d e f g h _ < /proc/stat; echo "cpu $((a+b+c+d+e+f+g+h)) $((d+e))"\n'
    + 'awk \'/^MemTotal:/{t=$2}/^MemAvailable:/{a=$2}END{print "mem",t,a}\' /proc/meminfo\n'
    + 'df -B1 --output=size,used / | awk \'NR==2{print "disk",$1,$2}\'\n'
    + 'for z in /sys/class/hwmon/hwmon*; do case "$(cat "$z/name" 2>/dev/null)" in\n'
    + '  coretemp|k10temp|zenpower) echo "temp $(cat "$z/temp1_input")"; break;; esac; done\n'
    + 'echo "up $(cut -d. -f1 /proc/uptime)"\n'

  function gib(bytes) { return (bytes / 1073741824).toFixed(bytes >= 107374182400 ? 0 : 1) }

  function applyStats(raw) {
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var p = lines[i].trim().split(/\s+/)
      if (p[0] === "cpu") {
        var total = Number(p[1]), idle = Number(p[2])
        var dt = total - cpuTotalPrev
        if (cpuTotalPrev > 0 && dt > 0) cpuFraction = Math.max(0, Math.min(1, 1 - (idle - cpuIdlePrev) / dt))
        cpuTotalPrev = total
        cpuIdlePrev = idle
      } else if (p[0] === "mem") {
        var memTotal = Number(p[1]) * 1024, memUsed = memTotal - Number(p[2]) * 1024
        memFraction = memTotal > 0 ? memUsed / memTotal : 0
        memText = gib(memUsed) + " / " + gib(memTotal) + " gb"
      } else if (p[0] === "disk") {
        var size = Number(p[1]), used = Number(p[2])
        diskFraction = size > 0 ? used / size : 0
        diskText = gib(used) + " / " + gib(size) + " gb"
      } else if (p[0] === "temp") {
        tempText = Math.round(Number(p[1]) / 1000) + "°c"
      } else if (p[0] === "up") {
        var s = Number(p[1])
        var days = Math.floor(s / 86400), hours = Math.floor(s % 86400 / 3600), mins = Math.floor(s % 3600 / 60)
        uptimeText = (days > 0 ? days + "d " : "") + hours + "h " + mins + "m"
      }
    }
  }

  Process {
    id: statsProc
    command: ["sh", "-c", root.statsScript]
    stdout: StdioCollector {
      onStreamFinished: root.applyStats(text)
    }
  }

  Timer {
    interval: 2000
    repeat: true
    running: root.opened
    onTriggered: statsProc.running = true
  }

  // ------------------------------------------------------------ components

  component Heading: Row {
    property string text: ""
    spacing: Style.spacing.md

    Text {
      text: "//"
      color: root.accent
      font.family: root.fontFamily
      font.pixelSize: Style.font.heading
      font.italic: true
    }
    Text {
      text: parent.text
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.heading
      font.bold: true
    }
  }

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

  component Meter: Column {
    property string label: ""
    property string value: ""
    property real fraction: 0
    property string caption: ""
    property color tone: root.foreground

    spacing: Style.spacing.sm

    Item {
      width: parent.width
      height: meterLabel.implicitHeight

      Text {
        id: meterLabel
        text: parent.parent.label
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
      }
      Text {
        anchors.right: parent.right
        text: parent.parent.value
        color: root.foreground
        font.family: root.monoFamily
        font.pixelSize: Style.font.bodySmall
      }
    }

    Rectangle {
      width: parent.width
      height: Math.max(2, Style.space(2))
      color: root.hairline

      Rectangle {
        width: parent.width * Math.max(0, Math.min(1, parent.parent.fraction))
        height: parent.height
        color: parent.parent.fraction >= 0.9 ? Color.urgent : parent.parent.tone

        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
      }
    }

    Text {
      visible: parent.caption !== ""
      width: parent.width
      text: parent.caption
      color: root.dim
      opacity: 0.8
      elide: Text.ElideRight
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  component VRule: Rectangle {
    Layout.preferredWidth: 1
    Layout.fillHeight: true
    color: root.hairline
  }

  // -------------------------------------------------------------------- UI

  PanelWindow {
    id: window
    visible: root.opened
    screen: {
      var focused = Hyprland.focusedMonitor
      var screens = Quickshell.screens
      for (var i = 0; focused && i < screens.length; i++)
        if (screens[i].name === focused.name) return screens[i]
      return screens[0]
    }
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "tobygodat-dashboard"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // No scrim: this is a glance, not a modal. Clicking away still closes it.
    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      anchors.top: parent.top
      anchors.topMargin: Style.bar.sizeHorizontal + Style.gapsOut * 2
      anchors.horizontalCenter: parent.horizontalCenter
      width: Math.min(Style.space(920), window.width - Style.gapsOut * 4)
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
          else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) root.shiftMonth(-1)
          else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) root.shiftMonth(1)
          else if (event.key === Qt.Key_T) root.showToday()
          else if (event.key === Qt.Key_Space && root.player && root.player.canTogglePlaying) root.player.togglePlaying()
          else if (event.key === Qt.Key_N && root.player && root.player.canGoNext) root.player.next()
          else if (event.key === Qt.Key_P && root.player && root.player.canGoPrevious) root.player.previous()
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

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.spacing.panelGap * 1.5

          // ---- today
          ColumnLayout {
            Layout.preferredWidth: Style.space(240)
            Layout.alignment: Qt.AlignTop
            spacing: Style.spacing.lg

            Heading { text: "today" }

            Text {
              text: Qt.formatTime(clock.date, "h:mm ap").split(" ")[0]
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.displayLarge * 1.6
              Layout.topMargin: Style.spacing.sm

              Text {
                anchors.left: parent.right
                anchors.leftMargin: Style.spacing.md
                anchors.baseline: parent.baseline
                text: (Qt.formatTime(clock.date, "h:mm ap").split(" ")[1] || "").toLowerCase()
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
              }
            }

            Text {
              text: Qt.formatDate(clock.date, "dddd d MMMM").toLowerCase()
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
            }

            RowLayout {
              Layout.fillWidth: true
              Layout.topMargin: Style.spacing.sm
              spacing: Style.spacing.xl

              Text {
                visible: root.weatherIcon !== ""
                text: root.weatherIcon
                color: root.foreground
                font.family: root.monoFamily
                font.pixelSize: Style.font.displayLarge
              }

              Column {
                Layout.fillWidth: true
                spacing: Style.spacing.xxs

                Text {
                  visible: root.weatherTemp !== ""
                  text: root.weatherTemp
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                }
                Text {
                  width: parent.width
                  text: root.weatherText !== "" ? root.weatherCaption
                    : (weatherProc.running ? "fetching weather…" : "weather unavailable")
                  color: root.dim
                  elide: Text.ElideRight
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                }
              }
            }
          }

          VRule {}

          // ---- calendar
          ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: Style.spacing.lg

            RowLayout {
              Layout.fillWidth: true

              Heading { text: Qt.locale().monthName(root.viewMonth).toLowerCase() + " " + root.viewYear }
              Item { Layout.fillWidth: true }
              Row {
                spacing: Style.spacing.xl
                Word { text: "prev"; onClicked: root.shiftMonth(-1) }
                Word { text: "today"; onClicked: root.showToday() }
                Word { text: "next"; onClicked: root.shiftMonth(1) }
              }
            }

            Grid {
              id: calendarGrid
              Layout.fillWidth: true
              columns: 7
              readonly property real cellWidth: Math.floor(width / 7)
              readonly property real cellHeight: Style.space(30)

              Repeater {
                model: root.weekdayLabels

                Text {
                  required property string modelData
                  width: calendarGrid.cellWidth
                  height: calendarGrid.cellHeight
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
                  text: modelData
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }
              }

              Repeater {
                model: root.calendarCells

                Item {
                  required property var modelData
                  width: calendarGrid.cellWidth
                  height: calendarGrid.cellHeight

                  Text {
                    id: dayText
                    anchors.centerIn: parent
                    text: modelData.day
                    color: modelData.today ? root.accent : root.foreground
                    opacity: modelData.inMonth ? 1 : 0.3
                    font.family: root.monoFamily
                    font.pixelSize: Style.font.body
                  }

                  Rectangle {
                    visible: modelData.today
                    anchors.top: dayText.bottom
                    anchors.topMargin: Style.spacing.xxs
                    anchors.horizontalCenter: dayText.horizontalCenter
                    width: dayText.implicitWidth + Style.spacing.sm
                    height: 2
                    color: root.accent
                  }
                }
              }
            }
          }

          VRule {}

          // ---- now playing
          ColumnLayout {
            Layout.preferredWidth: Style.space(240)
            Layout.alignment: Qt.AlignTop
            spacing: Style.spacing.lg

            RowLayout {
              Layout.fillWidth: true

              Heading { text: "playing" }
              Item { Layout.fillWidth: true }
              Text {
                visible: root.player !== null
                text: root.player ? String(root.player.identity || "").toLowerCase() : ""
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
              // Green only while something is actually playing.
              Text {
                visible: root.player !== null
                text: root.player ? root.playerGlyph(root.player.identity) : ""
                color: root.player && root.player.isPlaying ? root.accent : root.dim
                font.family: root.monoFamily
                font.pixelSize: Style.font.iconLarge
              }
            }

            RowLayout {
              Layout.fillWidth: true
              Layout.topMargin: Style.spacing.sm
              spacing: Style.spacing.xl

              Rectangle {
                id: cover
                readonly property string art: root.player ? String(root.player.trackArtUrl || "") : ""
                visible: art !== ""
                Layout.preferredWidth: Style.space(56)
                Layout.preferredHeight: Style.space(56)
                Layout.alignment: Qt.AlignTop
                color: "transparent"
                border.width: 1
                border.color: root.hairline

                Image {
                  anchors.fill: parent
                  anchors.margins: 1
                  source: cover.art
                  asynchronous: true
                  fillMode: Image.PreserveAspectCrop
                  sourceSize.width: 160
                  sourceSize.height: 160
                }
              }

              ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: Style.spacing.sm

                Text {
                  Layout.fillWidth: true
                  text: root.player ? (root.player.trackTitle || "untitled") : "nothing playing"
                  color: root.player ? root.foreground : root.dim
                  elide: Text.ElideRight
                  maximumLineCount: 2
                  wrapMode: Text.WordWrap
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                }
                Text {
                  Layout.fillWidth: true
                  visible: root.player !== null && text !== ""
                  text: root.player ? String(root.player.trackArtist || "") : ""
                  color: root.dim
                  elide: Text.ElideRight
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                }
                Text {
                  Layout.fillWidth: true
                  visible: root.player !== null && text !== "" && text !== root.player.trackTitle
                  text: root.player ? String(root.player.trackAlbum || "") : ""
                  color: root.dim
                  opacity: 0.7
                  elide: Text.ElideRight
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }
              }
            }

            Column {
              Layout.fillWidth: true
              visible: root.player !== null && root.player.lengthSupported && root.player.length > 0
              spacing: Style.spacing.sm

              Rectangle {
                width: parent.width
                height: 2
                color: root.hairline

                Rectangle {
                  width: root.player && root.player.length > 0
                    ? parent.width * Math.max(0, Math.min(1, root.player.position / root.player.length)) : 0
                  height: parent.height
                  color: root.accent
                }
              }

              Item {
                width: parent.width
                height: elapsed.implicitHeight

                Text {
                  id: elapsed
                  text: root.player ? root.clockTime(Math.min(root.player.position, root.player.length)) : ""
                  color: root.dim
                  font.family: root.monoFamily
                  font.pixelSize: Style.font.caption
                }
                Text {
                  anchors.right: parent.right
                  text: root.player ? root.clockTime(root.player.length) : ""
                  color: root.dim
                  font.family: root.monoFamily
                  font.pixelSize: Style.font.caption
                }
              }
            }

            Row {
              visible: root.player !== null
              spacing: Style.spacing.xl

              Word {
                text: "prev"
                visible: root.player !== null && root.player.canGoPrevious
                onClicked: root.player.previous()
              }
              Word {
                text: root.player && root.player.isPlaying ? "pause" : "play"
                color: hot ? root.accent : root.foreground
                visible: root.player !== null && root.player.canTogglePlaying
                onClicked: root.player.togglePlaying()
              }
              Word {
                text: "next"
                visible: root.player !== null && root.player.canGoNext
                onClicked: root.player.next()
              }
            }

          }
        }

        PanelSeparator { foreground: root.foreground; Layout.fillWidth: true }

        // ---- resources
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.spacing.panelGap * 1.5

          Meter {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            label: "cpu" + (root.tempText !== "" ? "  ·  " + root.tempText : "")
            value: Math.round(root.cpuFraction * 100) + "%"
            fraction: root.cpuFraction
          }
          Meter {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            label: "memory"
            value: root.memText
            fraction: root.memFraction
          }
          Meter {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            label: "disk"
            value: root.diskText
            fraction: root.diskFraction
          }
        }

        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: footer.implicitHeight

          Text {
            id: footer
            text: root.uptimeText !== "" ? "up " + root.uptimeText : ""
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
          Text {
            anchors.right: parent.right
            text: "h l month  ·  t today  ·  space play  ·  n p track  ·  esc"
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
