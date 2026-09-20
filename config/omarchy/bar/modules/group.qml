import QtQuick
import qs.Commons

// Invisible marker that draws pills (islands) around the stock widgets near
// it. Each marker needs its own id in shell.json ("pill-tray", "pill-status",
// ... with "source" pointing here): the bar's drag-to-rearrange finds entries
// by id, so repeated ids make it move the wrong one.
//
// How widgets are shared out, so that nothing is ever left bare however the
// bar is rearranged:
//   - hard boundaries (usage, session, ...) cut the section into runs;
//   - inside a run, a marker owns everything from itself to the next marker,
//     and the first marker also owns whatever sits before it;
//   - a run with no marker at all (the tray is pinned to the inner edge by
//     the stock bar, so anything dragged to the front lands between it and
//     its marker) is drawn by the first marker in the section.
//
// With "reveal": true, hovering any widget in this marker's pills unfolds the
// stock indicators widget's hidden items (and the stock "hover the centre of
// the bar" reveal is switched off). Only widgets at or right of the
// indicators count: the right section is laid out from the right edge, so
// the unfolding pushes everything to its left further left. A hovered widget
// to the left would slide out from under the cursor, the reveal would fold
// back, it would slide back under, and the bar would flicker in a loop. (The
// stock tray is always pinned first, so it can never be the trigger.)
Item {
  id: root

  property var bar
  property string moduleName
  property var settings

  readonly property bool reveal: settings && settings.reveal === true
  readonly property int cell: bar ? bar.barSize : 26
  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property int pad: Style.space(6)
  readonly property var boundaries: ["divider", "session", "usage", "center", "ws", "omarchy.spacer"]

  function isMarker(item) { return String(item.moduleName).indexOf("pill") === 0 }
  function isBoundary(item) { return boundaries.indexOf(String(item.moduleName)) !== -1 }

  // Space before the pill, unless the marker sits inside its own pill (it
  // owns widgets in front of it). Never zero: the bar's Row leaves
  // zero-sized slots unpositioned and unpainted.
  property bool inside: false
  implicitWidth: inside ? 1 : Style.space(20)
  implicitHeight: cell

  // The bar rebuilds every slot in a section whenever shell.json changes (a
  // rearrange, the tray saving its pinned icons), and widgets then load and
  // size themselves over several frames. Bindings across that churn go stale,
  // so the pills are re-measured on a short tick instead: they always follow
  // what is actually on screen.
  property Item slot: null
  property Item row: null
  property var members: []
  property var spans: []
  property var indicators: null
  // Left edge of the indicators widget: only widgets from here rightwards
  // may trigger the reveal.
  property real indicatorEdge: -1
  property bool settled: false

  function measure() {
    // widget → loader → ModuleSlot → Row of slots
    var mine = root.parent
    while (mine && mine.region === undefined) mine = mine.parent
    if (slot !== mine) slot = mine
    var row = mine ? mine.parent : null
    if (!row) return
    if (root.row !== row) root.row = row

    // Visible widgets by position: after a live rearrange the Row's child
    // order no longer matches the screen, and hidden widgets are left
    // unpositioned.
    var slots = []
    var found = null
    var edge = -1
    var children = row.children
    for (var i = 0; i < children.length; i++) {
      var child = children[i]
      if (!child || child.moduleName === undefined) continue
      if (child.moduleName === "omarchy.indicators") {
        found = child.activeItem
        // Folded with nothing active it is zero-wide, and the Row does not
        // position zero-wide slots, so its x is stale: it sits where the
        // widget before it ends.
        if (child.visible && child.width > 0) edge = child.x
        else {
          for (var p = i - 1; p >= 0 && edge < 0; p--) {
            var before = children[p]
            if (before && before.moduleName !== undefined && before.visible && before.width > 0)
              edge = before.x + before.width
          }
          if (edge < 0) edge = 0
        }
      }
      if (child.visible && child.width > 0) slots.push(child)
    }
    slots.sort(function(a, b) { return a.x - b.x })
    if (indicators !== found) indicators = found
    if (indicatorEdge !== edge) indicatorEdge = edge

    // Share the widgets out. owner[i] is the marker that draws slots[i].
    var firstMarker = null
    for (var m = 0; m < slots.length && !firstMarker; m++) if (isMarker(slots[m])) firstMarker = slots[m]

    var groups = []   // { owner, items } in screen order
    var run = []
    function flush() {
      if (run.length === 0) return
      var lead = null
      for (var r = 0; r < run.length && !lead; r++) if (isMarker(run[r])) lead = run[r]
      var current = { owner: lead || firstMarker, items: [] }
      for (var q = 0; q < run.length; q++) {
        if (isMarker(run[q])) {
          if (run[q] !== lead) {
            groups.push(current)
            current = { owner: run[q], items: [] }
          }
        } else current.items.push(run[q])
      }
      groups.push(current)
      run = []
    }
    for (var n = 0; n < slots.length; n++) {
      if (isBoundary(slots[n])) flush()
      else run.push(slots[n])
    }
    flush()

    var nextSpans = []
    var nextMembers = []
    var nowInside = false
    for (var g = 0; g < groups.length; g++) {
      if (groups[g].owner !== mine || groups[g].items.length === 0) continue
      var items = groups[g].items
      var start = items[0].x
      var end = items[items.length - 1].x + items[items.length - 1].width
      nextSpans.push({ x: start, width: end - start })
      if (start < mine.x && end > mine.x) nowInside = true
      for (var k = 0; k < items.length; k++) nextMembers.push(items[k])
    }
    if (inside !== nowInside) inside = nowInside

    var sameMembers = nextMembers.length === members.length
    for (var a = 0; sameMembers && a < nextMembers.length; a++) sameMembers = nextMembers[a] === members[a]
    if (!sameMembers) members = nextMembers

    var sameSpans = nextSpans.length === spans.length
    for (var b = 0; sameSpans && b < nextSpans.length; b++)
      sameSpans = nextSpans[b].x === spans[b].x && nextSpans[b].width === spans[b].width
    if (!sameSpans) spans = nextSpans
  }

  // A widget growing or shrinking (the indicators unfolding, the tray
  // expanding) changes the section's width and shifts its neighbours at
  // once, so follow every frame for a moment instead of waiting for the slow
  // tick; otherwise the outlines trail the icons they surround.
  property bool following: false

  function follow() {
    following = true
    followTimer.restart()
    Qt.callLater(root.measure)
  }

  Connections {
    target: root.row
    function onWidthChanged() { root.follow() }
  }

  Timer {
    id: followTimer
    interval: 400
    onTriggered: root.following = false
  }

  // Every frame while the section is still building or changing, otherwise
  // a slow tick as a safety net.
  Timer {
    interval: root.settled && !root.following ? 120 : 16
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.measure()
  }

  Timer {
    interval: 1500
    running: true
    onTriggered: root.settled = true
  }

  Repeater {
    model: root.spans.length

    Rectangle {
      required property int index
      readonly property var span: root.spans[index] || ({ x: 0, width: 0 })

      x: span.x - (root.slot ? root.slot.x : 0) - root.pad
      y: Style.space(4)
      width: span.width + root.pad * 2
      height: root.cell - Style.space(8)
      radius: height / 2
      color: "transparent"
      border.width: 1
      border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.22)

      // No glide: the stock widgets inside snap to their new places, so an
      // animated outline would lag behind them.
    }
  }

  // ---- indicator reveal

  readonly property bool groupHovered: {
    for (var i = 0; i < members.length; i++) {
      var m = members[i]
      if (m.hovered !== true || m.moduleName === "omarchy.tray") continue
      if (indicatorEdge < 0 || m.x >= indicatorEdge - 1) return true
    }
    return false
  }

  function sync() {
    if (reveal && indicators && typeof indicators.setIndicatorAreaHovered === "function")
      indicators.setIndicatorAreaHovered(groupHovered)
  }

  onGroupHoveredChanged: sync()
  onIndicatorsChanged: sync()

  // `bar` is assigned after the module loads, so this cannot live only in
  // Component.onCompleted.
  function suppressCentreReveal() {
    if (reveal && bar && typeof bar.setCenterHoverRevealSuppressed === "function")
      bar.setCenterHoverRevealSuppressed(true)
  }

  onBarChanged: suppressCentreReveal()
  onRevealChanged: suppressCentreReveal()
  Component.onCompleted: suppressCentreReveal()

  // The pill stays where it is; only the icons in it move (see Locked.qml).
  Locked {}
}
