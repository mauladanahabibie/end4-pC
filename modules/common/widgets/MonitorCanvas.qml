import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property var monitorConfig
    property real padding: 20
    property int selectedIndex: 0
    property var previewPositions: ({})
    property bool dragHasOverlap: false

    // Incremented every time monitor positions change (drag commit or preset).
    // Forces bounds/scaleFactor/offset to re-evaluate so the viewport
    // recenters on the new arrangement. Monitor coordinates are NEVER
    // modified for centering — only the viewport camera adjusts.
    property int _layoutRevision: 0

    implicitHeight: 220

    // Bounds are computed from COMMITTED positions only (monitor.x/y).
    // We deliberately do NOT use previewPositions here so that dragging
    // a monitor does not change bounds → scaleFactor → offset, which would
    // cause every other monitor to jump and create a feedback loop.
    // The _layoutRevision dependency ensures bounds re-evaluates after
    // preset operations that replace monitorConfig.monitors.
    property var bounds: {
        const _rev = root._layoutRevision // dependency trigger
        let minX = Infinity, minY = Infinity
        let maxX = -Infinity, maxY = -Infinity
        const mons = monitorConfig.monitors
        for (let i = 0; i < mons.length; i++) {
            const m = mons[i]
            if (m.disabled) continue
            const w = monitorConfig.logicalWidth(m)
            const h = monitorConfig.logicalHeight(m)
            minX = Math.min(minX, m.x)
            minY = Math.min(minY, m.y)
            maxX = Math.max(maxX, m.x + w)
            maxY = Math.max(maxY, m.y + h)
        }
        if (minX === Infinity) return { minX: 0, minY: 0, width: 1920, height: 1080 }
        return { minX, minY, width: maxX - minX, height: maxY - minY }
    }

    property real scaleFactor: {
        if (bounds.width === 0 || bounds.height === 0) return 0.1
        const scaleX = (canvas.width  - padding * 2) / bounds.width
        const scaleY = (canvas.height - padding * 2) / bounds.height
        return Math.min(scaleX, scaleY)
    }

    property point offset: Qt.point(
        (canvas.width  - bounds.width  * scaleFactor) / 2 - bounds.minX * scaleFactor,
        (canvas.height - bounds.height * scaleFactor) / 2 - bounds.minY * scaleFactor
    )

    function checkOverlap(monitors, idx) {
        const a = monitors[idx]
        const aw = monitorConfig.logicalWidth(a)
        const ah = monitorConfig.logicalHeight(a)
        for (let i = 0; i < monitors.length; i++) {
            if (i === idx) continue
            if (monitors[i].disabled) continue
            const b = monitors[i]
            const bw = monitorConfig.logicalWidth(b)
            const bh = monitorConfig.logicalHeight(b)
            if (a.x < b.x + bw && a.x + aw > b.x &&
                a.y < b.y + bh && a.y + ah > b.y) {
                return true
            }
        }
        return false
    }

    function computeNormalized(monitors, changedIdx, newX, newY) {
        let m = monitors.slice().map(mon => Object.assign({}, mon))
        m[changedIdx].x = newX
        m[changedIdx].y = newY
        let minX = Infinity, minY = Infinity
        for (let i = 0; i < m.length; i++) {
            if (m[i].disabled) continue
            minX = Math.min(minX, m[i].x)
            minY = Math.min(minY, m[i].y)
        }
        const offX = minX < 0 ? -minX : 0
        const offY = minY < 0 ? -minY : 0
        if (offX > 0 || offY > 0) {
            for (let i = 0; i < m.length; i++) {
                m[i].x += offX
                m[i].y += offY
            }
        }
        return m
    }

    // During drag we only update previewPositions for the dragged monitor.
    // We do NOT recompute bounds/scaleFactor/offset — those stay frozen to
    // the committed layout, preventing the feedback loop.
    function updatePreview(idx, newX, newY) {
        const normalized = computeNormalized(monitorConfig.monitors, idx, newX, newY)
        root.dragHasOverlap = checkOverlap(normalized, idx)
        // Only store the dragged monitor's preview position —
        // other monitors don't move visually during drag.
        let preview = Object.assign({}, root.previewPositions)
        preview[normalized[idx].name] = { x: normalized[idx].x, y: normalized[idx].y }
        // Also store any normalized positions for monitors that shifted
        // due to the negative-coord normalization (so they stay in sync visually)
        for (let i = 0; i < normalized.length; i++) {
            if (i === idx) continue
            if (normalized[i].x !== monitorConfig.monitors[i].x ||
                normalized[i].y !== monitorConfig.monitors[i].y) {
                preview[normalized[i].name] = { x: normalized[i].x, y: normalized[i].y }
            }
        }
        root.previewPositions = preview
    }

    function commitPosition(idx, newX, newY) {
        const normalized = computeNormalized(monitorConfig.monitors, idx, newX, newY)
        monitorConfig.monitors = normalized
        root.previewPositions = {}
        for (let i = 0; i < normalized.length; i++) {
            monitorConfig.applyMonitor(normalized[i])
        }
        monitorConfig.save()
        root._layoutRevision++
    }

    // ─────────────────────────────────────────────────────────────────
    // Quick Layout helpers — reuse commitPosition (same normalization +
    // apply + save path as drag-and-drop).  All of them operate on the
    // currently selected monitor (`selectedIndex`) relative to the
    // *first other enabled monitor* (the "reference").
    // ──────────────────────────────────────────────────────────────────

    function _enabledMonitors() {
        return monitorConfig.monitors.map((m, i) => ({ m, i }))
            .filter(e => !e.m.disabled)
    }

    function _selectedAndReference() {
        const enabled = _enabledMonitors()
        if (enabled.length < 2) return null
        const selIdx = selectedIndex
        const ref = enabled.find(e => e.i !== selIdx)
        if (!ref) return null
        return { sel: selIdx, ref: ref.i }
    }

    function _applyAll(newPositions) {
        // newPositions: array of {name,x,y} — build normalized monitors
        const m = monitorConfig.monitors.slice().map((mon, i) => {
            const np = newPositions.find(p => p.name === mon.name)
            return np ? Object.assign({}, mon, { x: np.x, y: np.y }) : mon
        })
        // normalize (shift so minX/minY >= 0)
        let minX = Infinity, minY = Infinity
        for (let i = 0; i < m.length; i++) {
            if (m[i].disabled) continue
            minX = Math.min(minX, m[i].x); minY = Math.min(minY, m[i].y)
        }
        if (minX < 0 || minY < 0) {
            const offX = minX < 0 ? -minX : 0
            const offY = minY < 0 ? -minY : 0
            for (let i = 0; i < m.length; i++) { m[i].x += offX; m[i].y += offY }
        }
        monitorConfig.monitors = m
        root.previewPositions = {}
        for (let i = 0; i < m.length; i++) monitorConfig.applyMonitor(m[i])
        monitorConfig.save()
        root._layoutRevision++
    }

    function moveMonitorAbove(gap) {
        const pair = _selectedAndReference(); if (!pair) return
        const s = monitorConfig.monitors[pair.sel], r = monitorConfig.monitors[pair.ref]
        const sh = monitorConfig.logicalHeight(s)
        const rh = monitorConfig.logicalHeight(r)
        // Left edges align, selected monitor sits above reference
        const newX = r.x
        const newY = r.y - sh - gap
        commitPosition(pair.sel, newX, newY)
    }

    function moveMonitorBelow(gap) {
        const pair = _selectedAndReference(); if (!pair) return
        const s = monitorConfig.monitors[pair.sel], r = monitorConfig.monitors[pair.ref]
        const rh = monitorConfig.logicalHeight(r)
        // Left edges align, selected monitor sits below reference
        const newX = r.x
        const newY = r.y + rh + gap
        commitPosition(pair.sel, newX, newY)
    }

    function moveMonitorLeft(gap) {
        const pair = _selectedAndReference(); if (!pair) return
        const s = monitorConfig.monitors[pair.sel], r = monitorConfig.monitors[pair.ref]
        const sw = monitorConfig.logicalWidth(s)
        const rw = monitorConfig.logicalWidth(r)
        // Top edges align, selected monitor sits left of reference
        const newX = r.x - sw - gap
        const newY = r.y
        commitPosition(pair.sel, newX, newY)
    }

    function moveMonitorRight(gap) {
        const pair = _selectedAndReference(); if (!pair) return
        const s = monitorConfig.monitors[pair.sel], r = monitorConfig.monitors[pair.ref]
        const rw = monitorConfig.logicalWidth(r)
        // Top edges align, selected monitor sits right of reference
        const newX = r.x + rw + gap
        const newY = r.y
        commitPosition(pair.sel, newX, newY)
    }

    // Alignment — only one axis, keep the other from the reference monitor.
    function alignHorizontal(mode) {
        // mode: "left" | "center" | "right"
        const pair = _selectedAndReference(); if (!pair) return
        const s = monitorConfig.monitors[pair.sel], r = monitorConfig.monitors[pair.ref]
        const sw = monitorConfig.logicalWidth(s), rw = monitorConfig.logicalWidth(r)
        let newX
        if (mode === "left")   newX = r.x
        if (mode === "center") newX = r.x + Math.round((rw - sw) / 2)
        if (mode === "right")  newX = r.x + rw - sw
        commitPosition(pair.sel, newX, s.y)
    }

    function alignVertical(mode) {
        // mode: "top" | "middle" | "bottom"
        const pair = _selectedAndReference(); if (!pair) return
        const s = monitorConfig.monitors[pair.sel], r = monitorConfig.monitors[pair.ref]
        const sh = monitorConfig.logicalHeight(s), rh = monitorConfig.logicalHeight(r)
        let newY
        if (mode === "top")    newY = r.y
        if (mode === "middle") newY = r.y + Math.round((rh - sh) / 2)
        if (mode === "bottom") newY = r.y + rh - sh
        commitPosition(pair.sel, s.x, newY)
    }

    function swapMonitors() {
        const pair = _selectedAndReference(); if (!pair) return
        const a = monitorConfig.monitors[pair.sel], b = monitorConfig.monitors[pair.ref]
        const ax = a.x, ay = a.y
        const newPositions = monitorConfig.monitors.map((mon, i) => {
            if (i === pair.sel) return { name: mon.name, x: b.x, y: b.y }
            if (i === pair.ref) return { name: mon.name, x: ax, ay }
            return { name: mon.name, x: mon.x, y: mon.y }
        })
        _applyAll(newPositions)
        selectedIndex = pair.ref
    }

    function centerLayout() {
        const enabled = _enabledMonitors()
        if (enabled.length === 0) return
        let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity
        for (const e of enabled) {
            const w = monitorConfig.logicalWidth(e.m), h = monitorConfig.logicalHeight(e.m)
            minX = Math.min(minX, e.m.x); minY = Math.min(minY, e.m.y)
            maxX = Math.max(maxX, e.m.x + w); maxY = Math.max(maxY, e.m.y + h)
        }
        // Shift everything so the whole arrangement starts at (0,0)
        const offX = minX < 0 ? -minX : 0
        const offY = minY < 0 ? -minY : 0
        if (offX === 0 && offY === 0) return
        const newPositions = monitorConfig.monitors.map(mon => ({
            name: mon.name, x: mon.x + offX, y: mon.y + offY
        }))
        _applyAll(newPositions)
    }

    function resetLayout() {
        // Re-fetch from Hyprland
        monitorConfig.reload()
        root._layoutRevision++
    }

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer1
        border.width: 1
        border.color: Appearance.colors.colLayer0Border

        Item {
            id: canvas
            anchors.fill: parent

            Repeater {
                model: root.monitorConfig.monitors.length
                delegate: MonitorRect {
                    required property int index
                    monitor: root.monitorConfig.monitors[index]
                    monitorIndex: index
                    monitorConfig: root.monitorConfig
                    scaleFactor: root.scaleFactor
                    canvasOffset: root.offset
                    allMonitors: root.monitorConfig.monitors
                    isSelected: index === root.selectedIndex
                    previewPositions: root.previewPositions
                    hasOverlap: root.dragHasOverlap && isDragging

                    onMonitorClicked: (idx) => root.selectedIndex = idx
                    onPositionDragging: (idx, x, y) => root.updatePreview(idx, x, y)
                    onPositionCommitted: (idx, x, y) => {
                        const hadOverlap = root.dragHasOverlap
                        root.previewPositions = {}
                        root.dragHasOverlap = false
                        if (!hadOverlap) {
                            root.commitPosition(idx, x, y)
                        }
                        root._layoutRevision++
                    }
                }
            }
        }
    }
}
