# Marquee Selection (Drag-to-Select) Architecture & Implementation Plan

## 1. Objectives
Extend the Whiteboard's `select` tool with full-featured drag-to-select (marquee selection) supporting:
1. Pointer drag on empty canvas to draw an active marquee box.
2. Dual selection modes:
   - **Window Selection** (left-to-right drag): selects objects completely contained within the rectangle.
   - **Crossing Selection** (right-to-left drag): selects objects that intersect or touch the rectangle.
3. Support for all object types:
   - Freehand strokes (accounting for stroke width and point-to-segment geometry).
   - Lines & Arrows (segment-to-box intersection).
   - Rectangles & Ellipses (box inclusion & overlap).
   - Text items (measured typographic bounding boxes).
4. Full coordinate correctness across arbitrary zoom levels (`0.25x` to `4.0x`) and pan offsets.
5. Additive selection via `Shift` key modifier.
6. Cohesive multi-object dragging with a single consolidated undo/redo command (`moveBatch`).
7. Multi-object deletion (`Delete` or `Backspace`) with a single consolidated undo/redo command (`removeBatch`).

---

## 2. Geometry & Intersection Logic

### Coordinate Transformation
- Pointer positions `(mouse.x, mouse.y)` on canvas are transformed to document coordinates:
  `docX = (screenX - panX) / zoom`
  `docY = (screenY - panY) / zoom`
- Normalized marquee box:
  `minX = Math.min(startX, currentX)`
  `maxX = Math.max(startX, currentX)`
  `minY = Math.min(startY, currentY)`
  `maxY = Math.max(startY, currentY)`

### Mode Detection
- `isCrossing = currentX < startX`:
  - `true`: Dragged right-to-left -> Crossing Selection.
    - Visual: Green dashed border (`#22c55e`), semi-transparent green fill (`rgba(34, 197, 94, 0.14)`).
  - `false`: Dragged left-to-right -> Window Selection.
    - Visual: Blue solid border (`#3b82f6`), semi-transparent blue fill (`rgba(59, 130, 246, 0.14)`).

### Object Containment & Intersection Rules
1. **Window Selection (`isCrossing === false`)**:
   - `stroke`: All points `p` satisfy `minX <= p.x <= maxX && minY <= p.y <= maxY`.
   - `line` / `arrow`: Both `(x1, y1)` and `(x2, y2)` are inside `[minX, maxX, minY, maxY]`.
   - `rectangle`: `obj.x >= minX && (obj.x + obj.width) <= maxX && obj.y >= minY && (obj.y + obj.height) <= maxY`.
   - `ellipse`: Bounding box completely enclosed.
   - `text`: Text bounding box completely enclosed.

2. **Crossing Selection (`isCrossing === true`)**:
   - Bounding box rejection: If `box.maxX < minX || box.minX > maxX || box.maxY < minY || box.minY > maxY`, return `false`.
   - If bounding box is fully contained, return `true`.
   - Segment-to-rectangle intersection: For any segment `(p1, p2)` (lines, arrows, or consecutive stroke points):
     - Return `true` if either point is inside the marquee.
     - Return `true` if `p1->p2` intersects any of the 4 edges of the marquee box:
       - `(minX, minY) -> (maxX, minY)` (top)
       - `(minX, maxY) -> (maxX, maxY)` (bottom)
       - `(minX, minY) -> (minX, maxY)` (left)
       - `(maxX, minY) -> (maxX, maxY)` (right)

---

## 3. Interaction State Machine in `WhiteboardCanvas.qml`
- `activeTool === "select"`:
  - `onPressed`:
    - Check hit object at `docPt`.
    - If hit object:
      - If `Shift`: Toggle selection for hit object.
      - Else if not already selected: set selection to `[hit.id]`.
      - Set `selectionDragState = { startX, startY, totalDeltaX: 0, totalDeltaY: 0, selectedIds: selectedIds.slice() }`.
      - `marqueeState = null`.
    - If empty canvas (no hit):
      - If not `Shift`: clear `selectedIds`.
      - Set `marqueeState = { startX: docPt.x, startY: docPt.y, currentX: docPt.x, currentY: docPt.y, isShift: isShift, initialSelectedIds: selectedIds.slice() }`.
      - `selectionDragState = null`.
  - `onPositionChanged`:
    - If `selectionDragState`: Move selected objects by delta `(stepX, stepY)`.
    - If `marqueeState`: Update `currentX, currentY`, trigger `canvasPreview.requestPaint()`.
  - `onReleased`:
    - If `selectionDragState`: Commit `moveBatch` to undo stack if moved.
    - If `marqueeState`:
      - If dragged (> 4px): find matching objects via geometry test and update `selectedIds`.
      - `marqueeState = null`.
      - `canvasPreview.requestPaint()`.
