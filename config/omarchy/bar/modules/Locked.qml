import QtQuick

// Keeps a bar module where shell.json puts it. The stock bar lets every
// widget be dragged to reorder; the pills (ws, center, usage, the group
// markers) and the end caps should stay put so that dragging only ever moves
// icons from one pill to another. Icons can still be dropped next to a locked
// module, which is how they change pills.
//
// Drop one in as a child of the module's root item: `Locked {}`.
//
// The drag lives in the bar's ModuleSlot, on a MouseArea layered over the
// module, so the lock switches that MouseArea off. Clicks then reach the
// module's own MouseArea directly. The bar rebuilds its slots on every
// shell.json write, and this is rebuilt with them, so the lock is re-applied.
Item {
  id: lock

  width: 0
  height: 0

  property Item pointer: null
  property int tries: 0

  function find() {
    // module → Loader → ModuleSlot (the one with a `region`)
    var slot = lock.parent
    while (slot && slot.region === undefined) slot = slot.parent
    if (!slot) return false
    var children = slot.children
    for (var i = 0; i < children.length; i++) {
      if (children[i].canReorder !== undefined) {
        pointer = children[i]
        return true
      }
    }
    return false
  }

  // The module is parented into its slot after it completes; poll briefly.
  Timer {
    interval: 16
    repeat: true
    running: lock.pointer === null && lock.tries < 120
    triggeredOnStart: true
    onTriggered: {
      lock.tries++
      lock.find()
    }
  }

  Binding {
    when: lock.pointer !== null
    target: lock.pointer
    property: "enabled"
    value: false
    restoreMode: Binding.RestoreBindingOrValue
  }
}
