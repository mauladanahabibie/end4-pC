import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root

    required property var monitor
    required property int monitorIndex
    required property var monitorConfig
    required property real scaleFactor
    required property point canvasOffset
    required property var allMonitors
    property bool isSelected: false
    property var previewPositions: ({})
    property bool hasOverlap: false

    signal positionCommitted(int index, int x, int y)
    signal monitorClicked(int index)
    signal positionDragging(int index, int x, int y)

    property bool isDragging: false
    property real dragGrabOffsetX: 0
    property real dragGrabOffsetY: 0
    property real dragCanvasX: 0
    property real dragCanvasY: 0
    property int snappedX: 0
    property int snappedY: 0

    // ─── Magnetic docking state ───────────────────────────────────
    // The gap to maintain while attached (in real/unscaled coordinates).
    property int dockGap: 0
    // Attach radius (logical px) — how close to snap in.
    property real attachRadius: 20
    // Detach radius (logical px) — how far to pull away before releasing.
    // Hysteresis: detach > attach prevents flicker at the threshold.
    property real detachRadius: 40

    // Active dock state. When attached, one axis is locked to the
    // reference monitor's edge; only the other axis follows the mouse.
    //   attachedEdge values: "left" | "right" | "top" | "bottom"
    //   "left"  = my right edge docked to their left edge  (I'm to the LEFT)
    //   "right" = my left edge docked to their right edge  (I'm to the RIGHT)
    //   "top"   = my bottom edge docked to their top edge  (I'm ABOVE)
    //   "bottom"= my top edge docked to their bottom edge  (I'm BELOW)
    property bool edgeAttached: false
    property int attachedMonitor: -1
    property string attachedEdge: ""
    // The signed gap (in real coords) to maintain. For "left"/"top" this is
    // subtracted from the reference edge; for "right"/"bottom" it's added.
    // We store the *signed* offset so the math is uniform.
    property int _dockOffsetX: 0
    property int _dockOffsetY: 0

    property int logW: monitorConfig?.logicalWidth(monitor) ?? 0
    property int logH: monitorConfig?.logicalHeight(monitor) ?? 0

    x: isDragging ? dragCanvasX : (previewPositions[monitor.name]?.x ?? monitor.x) * scaleFactor + canvasOffset.x
    y: isDragging ? dragCanvasY : (previewPositions[monitor.name]?.y ?? monitor.y) * scaleFactor + canvasOffset.y
    width:  logW * scaleFactor
    height: logH * scaleFactor

    radius: Appearance.rounding.small
    z: isDragging ? 100 : isSelected ? 2 : 1

    color: {
        if (monitor.disabled)             return Appearance.colors.colLayer2
        if (isDragging && hasOverlap)     return Qt.alpha(Appearance.m3colors.m3error, 0.5)
        if (isDragging)                   return Qt.alpha(Appearance.colors.colPrimaryContainer, 0.7)
        if (isSelected)                   return Appearance.colors.colPrimaryContainer
        if (hoverArea.containsMouse)      return Appearance.colors.colSecondaryContainerHover
        return Appearance.colors.colSecondaryContainer
    }

    border.color: (isDragging && hasOverlap) ? Appearance.m3colors.m3error
        : (isDragging || isSelected) ? Appearance.colors.colPrimary
        : Appearance.colors.colLayer0Border
    border.width: (isDragging || isSelected) ? 2 : 1

    Behavior on x { enabled: !isDragging; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    Behavior on y { enabled: !isDragging; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: 150 } }

    // Snap preview outline — shows where the monitor will land.
    Rectangle {
        visible: root.isDragging && !root.hasOverlap
        x: root.snappedX * root.scaleFactor + root.canvasOffset.x - root.x
        y: root.snappedY * root.scaleFactor + root.canvasOffset.y - root.y
        width: root.width
        height: root.height
        radius: root.radius
        color: "transparent"
        border.color: root.edgeAttached ? Appearance.colors.colPrimary : Appearance.colors.colPrimary
        border.width: root.edgeAttached ? 3 : 2
        opacity: root.edgeAttached ? 0.8 : 0.6

        Behavior on opacity { NumberAnimation { duration: 100 } }
        Behavior on border.width { NumberAnimation { duration: 100 } }
    }

    Column {
        anchors.centerIn: parent
        spacing: 2

        MaterialSymbol {
            anchors.horizontalCenter: parent.horizontalCenter
            text: monitor.disabled ? "desktop_access_disabled" : "desktop_windows"
            iconSize: Math.min(20, Math.min(root.width * 0.25, root.height * 0.25))
            color: monitor.disabled ? Appearance.colors.colSubtext
                : isSelected ? Appearance.colors.colOnPrimaryContainer
                : Appearance.colors.colPrimary
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: monitor?.name ?? ""
            font.pixelSize: Math.max(9, Math.min(13, root.width * 0.1))
            font.weight: Font.Medium
            color: monitor.disabled ? Appearance.colors.colSubtext
                : isSelected ? Appearance.colors.colOnPrimaryContainer
                : Appearance.colors.colOnSecondaryContainer
            elide: Text.ElideMiddle
            width: Math.min(implicitWidth, root.width - 8)
            horizontalAlignment: Text.AlignHCenter
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: `${root.logW}x${root.logH}`
            font.pixelSize: Math.max(8, Math.min(10, root.width * 0.08))
            color: Appearance.colors.colSubtext
            horizontalAlignment: Text.AlignHCenter
        }
    }

    /**
     * Try to find the best magnetic dock candidate for the current free
     * position (realX, realY). Returns null if nothing is within attachRadius.
     *
     * A "dock" means one axis is flush (my edge touches their edge + gap)
     * and the monitor overlaps the reference on the perpendicular axis.
     * We pick the candidate with the smallest flush distance.
     */
    function _findDockCandidate(realX, realY) {
        const gap = dockGap
        const myLeft = realX, myRight = realX + logW
        const myTop = realY, myBottom = realY + logH
        let best = null
        let bestDist = attachRadius + 1

        for (let i = 0; i < allMonitors.length; i++) {
            if (i === monitorIndex) continue
            const other = allMonitors[i]
            if (other.disabled) continue
            const ow = monitorConfig.logicalWidth(other)
            const oh = monitorConfig.logicalHeight(other)
            const oLeft = other.x, oRight = other.x + ow
            const oTop = other.y, oBottom = other.y + oh

            // ── Horizontal docks (lock X, slide Y) ──
            // My right → their left (I'm to the LEFT of them)
            if (myBottom > oTop && myTop < oBottom) { // vertical overlap
                const dist = Math.abs(myRight + gap - oLeft)
                if (dist < bestDist) {
                    bestDist = dist
                    best = { monitor: i, edge: "left", lockX: oLeft - gap - logW, lockAxis: "x" }
                }
            }
            // My left → their right (I'm to the RIGHT of them)
            if (myBottom > oTop && myTop < oBottom) {
                const dist = Math.abs(myLeft - gap - oRight)
                if (dist < bestDist) {
                    bestDist = dist
                    best = { monitor: i, edge: "right", lockX: oRight + gap, lockAxis: "x" }
                }
            }
            // ── Vertical docks (lock Y, slide X) ──
            // My bottom → their top (I'm ABOVE them)
            if (myRight > oLeft && myLeft < oRight) { // horizontal overlap
                const dist = Math.abs(myBottom + gap - oTop)
                if (dist < bestDist) {
                    bestDist = dist
                    best = { monitor: i, edge: "top", lockY: oTop - gap - logH, lockAxis: "y" }
                }
            }
            // My top → their bottom (I'm BELOW them)
            if (myRight > oLeft && myLeft < oRight) {
                const dist = Math.abs(myTop - gap - oBottom)
                if (dist < bestDist) {
                    bestDist = dist
                    best = { monitor: i, edge: "bottom", lockY: oBottom + gap, lockAxis: "y" }
                }
            }
        }
        return best
    }

    /**
     * Given the current dock state, compute the docked position for the
     * free mouse position (realX, realY). The locked axis is clamped to
     * the reference edge; the free axis follows the mouse EXACTLY.
     * No edge alignment snapping on the free axis — preserve user placement.
     * Returns { x, y } in real coordinates.
     */
    function _dockedPosition(realX, realY) {
        const other = allMonitors[attachedMonitor]
        if (!other || other.disabled) return { x: realX, y: realY }
        const ow = monitorConfig.logicalWidth(other)
        const oh = monitorConfig.logicalHeight(other)
        const gap = dockGap

        if (attachedEdge === "left") {
            // My right edge flush to their left edge. Lock X, Y follows mouse.
            return { x: other.x - gap - logW, y: realY }
        } else if (attachedEdge === "right") {
            // My left edge flush to their right edge. Lock X, Y follows mouse.
            return { x: other.x + ow + gap, y: realY }
        } else if (attachedEdge === "top") {
            // My bottom edge flush to their top edge. Lock Y, X follows mouse.
            return { x: realX, y: other.y - gap - logH }
        } else if (attachedEdge === "bottom") {
            // My top edge flush to their bottom edge. Lock Y, X follows mouse.
            return { x: realX, y: other.y + oh + gap }
        }
        return { x: realX, y: realY }
    }

    /**
     * Check if we should detach from the current dock.
     * Hysteresis: require the mouse to move detachRadius away from the
     * locked edge before releasing.
     */
    function _shouldDetach(realX, realY) {
        const other = allMonitors[attachedMonitor]
        if (!other || other.disabled) return true
        const ow = monitorConfig.logicalWidth(other)
        const oh = monitorConfig.logicalHeight(other)
        const gap = dockGap
        if (attachedEdge === "left") {
            return Math.abs((realX + logW + gap) - other.x) > detachRadius
        } else if (attachedEdge === "right") {
            return Math.abs(realX - (other.x + ow + gap)) > detachRadius
        } else if (attachedEdge === "top") {
            return Math.abs((realY + logH + gap) - other.y) > detachRadius
        } else if (attachedEdge === "bottom") {
            return Math.abs(realY - (other.y + oh + gap)) > detachRadius
        }
        return true
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: !monitor.disabled
        cursorShape: monitor.disabled ? Qt.ArrowCursor
            : (root.isDragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
        drag.target: root
        drag.axis: Drag.XAndYAxis
        drag.threshold: 4

        onPressed: (event) => {
            const grabCanvasX = root.mapToItem(canvas.parent, event.x, event.y).x
            const grabCanvasY = root.mapToItem(canvas.parent, event.x, event.y).y
            root.dragGrabOffsetX = grabCanvasX - root.x
            root.dragGrabOffsetY = grabCanvasY - root.y
            root.dragCanvasX = root.x
            root.dragCanvasY = root.y
            root.snappedX = monitor.x
            root.snappedY = monitor.y
            // Reset dock state on new drag
            root.edgeAttached = false
            root.attachedMonitor = -1
            root.attachedEdge = ""
            root.isDragging = true
        }

        onPositionChanged: (event) => {
            if (!root.isDragging) return
            const mouseCanvas = root.mapToItem(canvas.parent, event.x, event.y)
            root.dragCanvasX = mouseCanvas.x - root.dragGrabOffsetX
            root.dragCanvasY = mouseCanvas.y - root.dragGrabOffsetY
            // Free mouse position in real monitor coordinates
            const freeX = Math.round((root.dragCanvasX - root.canvasOffset.x) / root.scaleFactor)
            const freeY = Math.round((root.dragCanvasY - root.canvasOffset.y) / root.scaleFactor)

            let resultX = freeX, resultY = freeY

            if (root.edgeAttached) {
                // ── Currently docked ──
                if (root._shouldDetach(freeX, freeY)) {
                    // Mouse pulled far enough — release the dock
                    root.edgeAttached = false
                    root.attachedMonitor = -1
                    root.attachedEdge = ""
                    resultX = freeX
                    resultY = freeY
                } else {
                    // Stay docked: lock the attachment axis, free axis follows mouse exactly
                    const docked = root._dockedPosition(freeX, freeY)
                    resultX = docked.x
                    resultY = docked.y
                }
            }

            if (!root.edgeAttached) {
                // ── Free movement — check for magnetic attach ──
                const candidate = root._findDockCandidate(freeX, freeY)
                if (candidate) {
                    // Attach!
                    root.edgeAttached = true
                    root.attachedMonitor = candidate.monitor
                    root.attachedEdge = candidate.edge
                    // Compute docked position immediately
                    const docked = root._dockedPosition(freeX, freeY)
                    resultX = docked.x
                    resultY = docked.y
                } else {
                    resultX = freeX
                    resultY = freeY
                }
            }

            root.snappedX = resultX
            root.snappedY = resultY
            root.positionDragging(root.monitorIndex, root.snappedX, root.snappedY)
        }

        onReleased: {
            root.isDragging = false

            // ── Always snap on release ──
            // No threshold — always find the nearest edge of the nearest
            // monitor and dempet (flush). Only the attachment axis changes;
            // the other axis preserves the user's mouse placement exactly.
            {
                const gap = dockGap
                let bestDist = Infinity
                let bestEdge = null
                let bestMonitor = -1

                const myLeft = root.snappedX, myRight = root.snappedX + logW
                const myTop = root.snappedY, myBottom = root.snappedY + logH

                for (let i = 0; i < allMonitors.length; i++) {
                    if (i === monitorIndex) continue
                    const other = allMonitors[i]
                    if (other.disabled) continue
                    const ow = monitorConfig.logicalWidth(other)
                    const oh = monitorConfig.logicalHeight(other)
                    const oLeft = other.x, oRight = other.x + ow
                    const oTop = other.y, oBottom = other.y + oh

                    const d_rl = Math.abs(myRight + gap - oLeft)
                    if (d_rl < bestDist) { bestDist = d_rl; bestEdge = "left"; bestMonitor = i }
                    const d_lr = Math.abs(myLeft - gap - oRight)
                    if (d_lr < bestDist) { bestDist = d_lr; bestEdge = "right"; bestMonitor = i }
                    const d_bt = Math.abs(myBottom + gap - oTop)
                    if (d_bt < bestDist) { bestDist = d_bt; bestEdge = "top"; bestMonitor = i }
                    const d_tb = Math.abs(myTop - gap - oBottom)
                    if (d_tb < bestDist) { bestDist = d_tb; bestEdge = "bottom"; bestMonitor = i }
                }

                if (bestEdge && bestMonitor >= 0) {
                    const other = allMonitors[bestMonitor]
                    const ow = monitorConfig.logicalWidth(other)
                    const oh = monitorConfig.logicalHeight(other)
                    if (bestEdge === "left")        root.snappedX = other.x - gap - logW
                    else if (bestEdge === "right")  root.snappedX = other.x + ow + gap
                    else if (bestEdge === "top")     root.snappedY = other.y - gap - logH
                    else if (bestEdge === "bottom") root.snappedY = other.y + oh + gap
                }
            }

            root.edgeAttached = false
            root.attachedMonitor = -1
            root.attachedEdge = ""

            if (root.snappedX === monitor.x && root.snappedY === monitor.y) {
                root.monitorClicked(root.monitorIndex)
                return
            }
            root.positionCommitted(root.monitorIndex, root.snappedX, root.snappedY)
        }
    }
}
