import QtQuick

QtObject {
    id: root

    property string title: "Untitled Board"
    property var objects: []
    property var selectedIds: []
    property var undoStack: []
    property var redoStack: []
    property int undoCount: 0
    property int redoCount: 0
    property bool isDirty: false

    property real viewZoom: 1.0
    property real viewPanX: 0
    property real viewPanY: 0
    property string viewBackground: "dark"
    property string viewGrid: "dots"

    readonly property bool canUndo: undoCount > 0
    readonly property bool canRedo: redoCount > 0
    readonly property int objectCount: objects.length

    signal documentChanged()
    signal selectionChanged()

    function syncHistoryCounts() {
        undoCount = undoStack.length;
        redoCount = redoStack.length;
    }

    function pushUndoCommand(cmd) {
        const nextUndo = undoStack.slice();
        nextUndo.push(cmd);
        undoStack = nextUndo;
        redoStack = [];
        syncHistoryCounts();
    }

    function generateId() {
        return "obj_" + Date.now().toString(36) + "_" + Math.random().toString(36).substr(2, 5);
    }

    function addObject(obj, pushUndo = true) {
        if (!obj.id) obj.id = generateId();
        const next = objects.slice();
        next.push(obj);
        objects = next;
        root.isDirty = true;

        if (pushUndo) {
            pushUndoCommand({ type: "add", object: JSON.parse(JSON.stringify(obj)) });
        }
        documentChanged();
        return obj.id;
    }

    function removeObject(id, pushUndo = true) {
        const idx = objects.findIndex(o => o.id === id);
        if (idx === -1) return;
        const obj = objects[idx];
        const next = objects.slice();
        next.splice(idx, 1);
        objects = next;
        root.isDirty = true;

        if (selectedIds.includes(id)) {
            selectedIds = selectedIds.filter(i => i !== id);
            selectionChanged();
        }

        if (pushUndo) {
            pushUndoCommand({ type: "remove", object: JSON.parse(JSON.stringify(obj)), index: idx });
        }
        documentChanged();
    }

    function removeObjects(ids, pushUndo = true) {
        if (!ids || ids.length === 0) return;
        const removed = [];
        const next = objects.slice();
        for (let i = next.length - 1; i >= 0; i--) {
            if (ids.includes(next[i].id)) {
                removed.push({ object: JSON.parse(JSON.stringify(next[i])), index: i });
                next.splice(i, 1);
            }
        }
        if (removed.length === 0) return;
        objects = next;
        root.isDirty = true;
        selectedIds = selectedIds.filter(id => !ids.includes(id));
        selectionChanged();

        if (pushUndo) {
            pushUndoCommand({ type: "removeBatch", items: removed });
        }
        documentChanged();
    }

    function updateObject(id, newProps, pushUndo = true) {
        const idx = objects.findIndex(o => o.id === id);
        if (idx === -1) return;
        const oldState = JSON.parse(JSON.stringify(objects[idx]));
        const updated = Object.assign({}, objects[idx], newProps);
        const next = objects.slice();
        next[idx] = updated;
        objects = next;
        root.isDirty = true;

        if (pushUndo) {
            pushUndoCommand({ type: "modify", id: id, before: oldState, after: JSON.parse(JSON.stringify(updated)) });
        }
        documentChanged();
    }

    function moveObjects(ids, deltaX, deltaY, pushUndo = true) {
        if (!ids || ids.length === 0 || (deltaX === 0 && deltaY === 0)) return;
        const beforeStates = [];
        const next = objects.slice();

        for (let i = 0; i < next.length; i++) {
            const o = next[i];
            if (ids.includes(o.id)) {
                beforeStates.push({ id: o.id, before: JSON.parse(JSON.stringify(o)) });
                const updated = JSON.parse(JSON.stringify(o));
                if (updated.type === "stroke") {
                    for (let p = 0; p < updated.points.length; p++) {
                        updated.points[p].x += deltaX;
                        updated.points[p].y += deltaY;
                    }
                } else if (updated.type === "line" || updated.type === "arrow") {
                    updated.x1 += deltaX;
                    updated.y1 += deltaY;
                    updated.x2 += deltaX;
                    updated.y2 += deltaY;
                } else if (updated.type === "rectangle" || updated.type === "ellipse" || updated.type === "text") {
                    updated.x += deltaX;
                    updated.y += deltaY;
                }
                next[i] = updated;
            }
        }

        objects = next;
        root.isDirty = true;

        if (pushUndo) {
            pushUndoCommand({
                type: "moveBatch",
                deltaX: deltaX,
                deltaY: deltaY,
                items: beforeStates
            });
        }
        documentChanged();
    }

    function clearBoard(pushUndo = true) {
        if (objects.length === 0) return;
        const prev = JSON.parse(JSON.stringify(objects));
        objects = [];
        selectedIds = [];
        root.isDirty = true;

        if (pushUndo) {
            pushUndoCommand({ type: "clear", previousObjects: prev });
        }
        selectionChanged();
        documentChanged();
    }

    function resetDocument() {
        title = "Untitled Board";
        objects = [];
        selectedIds = [];
        undoStack = [];
        redoStack = [];
        syncHistoryCounts();
        isDirty = false;
        selectionChanged();
        documentChanged();
    }

    function undo() {
        if (undoStack.length === 0) return;
        const curUndo = undoStack.slice();
        const cmd = curUndo.pop();
        undoStack = curUndo;

        const curRedo = redoStack.slice();

        if (cmd.type === "add") {
            const idx = objects.findIndex(o => o.id === cmd.object.id);
            if (idx !== -1) {
                const next = objects.slice();
                next.splice(idx, 1);
                objects = next;
            }
            curRedo.push(cmd);
        } else if (cmd.type === "remove") {
            const next = objects.slice();
            const insertIdx = Math.min(cmd.index, next.length);
            next.splice(insertIdx, 0, cmd.object);
            objects = next;
            curRedo.push(cmd);
        } else if (cmd.type === "removeBatch") {
            const next = objects.slice();
            const sorted = cmd.items.slice().sort((a, b) => a.index - b.index);
            for (let i = 0; i < sorted.length; i++) {
                const insertIdx = Math.min(sorted[i].index, next.length);
                next.splice(insertIdx, 0, sorted[i].object);
            }
            objects = next;
            curRedo.push(cmd);
        } else if (cmd.type === "modify") {
            const idx = objects.findIndex(o => o.id === cmd.id);
            if (idx !== -1) {
                const next = objects.slice();
                next[idx] = JSON.parse(JSON.stringify(cmd.before));
                objects = next;
            }
            curRedo.push(cmd);
        } else if (cmd.type === "moveBatch") {
            const next = objects.slice();
            for (let i = 0; i < cmd.items.length; i++) {
                const item = cmd.items[i];
                const idx = next.findIndex(o => o.id === item.id);
                if (idx !== -1) {
                    next[idx] = JSON.parse(JSON.stringify(item.before));
                }
            }
            objects = next;
            curRedo.push(cmd);
        } else if (cmd.type === "clear") {
            objects = JSON.parse(JSON.stringify(cmd.previousObjects));
            curRedo.push(cmd);
        }

        redoStack = curRedo;
        syncHistoryCounts();
        root.isDirty = true;
        documentChanged();
    }

    function redo() {
        if (redoStack.length === 0) return;
        const curRedo = redoStack.slice();
        const cmd = curRedo.pop();
        redoStack = curRedo;

        const curUndo = undoStack.slice();

        if (cmd.type === "add") {
            const next = objects.slice();
            next.push(JSON.parse(JSON.stringify(cmd.object)));
            objects = next;
            curUndo.push(cmd);
        } else if (cmd.type === "remove") {
            const idx = objects.findIndex(o => o.id === cmd.object.id);
            if (idx !== -1) {
                const next = objects.slice();
                next.splice(idx, 1);
                objects = next;
            }
            curUndo.push(cmd);
        } else if (cmd.type === "removeBatch") {
            const idsToRemove = cmd.items.map(it => it.object.id);
            objects = objects.filter(o => !idsToRemove.includes(o.id));
            curUndo.push(cmd);
        } else if (cmd.type === "modify") {
            const idx = objects.findIndex(o => o.id === cmd.id);
            if (idx !== -1) {
                const next = objects.slice();
                next[idx] = JSON.parse(JSON.stringify(cmd.after));
                objects = next;
            }
            curUndo.push(cmd);
        } else if (cmd.type === "moveBatch") {
            const idsToMove = cmd.items.map(it => it.id);
            root.moveObjects(idsToMove, cmd.deltaX, cmd.deltaY, false);
            curUndo.push(cmd);
        } else if (cmd.type === "clear") {
            objects = [];
            curUndo.push(cmd);
        }

        undoStack = curUndo;
        syncHistoryCounts();
        root.isDirty = true;
        documentChanged();
    }

    // Hit Testing & Geometry Helpers
    function distSq(p1, p2) {
        const dx = p1.x - p2.x;
        const dy = p1.y - p2.y;
        return dx * dx + dy * dy;
    }

    function distToSegmentSq(p, v, w) {
        const l2 = distSq(v, w);
        if (l2 === 0) return distSq(p, v);
        let t = ((p.x - v.x) * (w.x - v.x) + (p.y - v.y) * (w.y - v.y)) / l2;
        t = Math.max(0, Math.min(1, t));
        return distSq(p, { x: v.x + t * (w.x - v.x), y: v.y + t * (w.y - v.y) });
    }

    function hitTestObject(obj, x, y, tolerance = 8) {
        const sWidth = obj.strokeWidth ?? (obj.type === "rectangle" || obj.type === "ellipse" ? 3 : (obj.width || 3));
        const tolSq = (tolerance + sWidth / 2) * (tolerance + sWidth / 2);
        const p = { x: x, y: y };

        if (obj.type === "stroke") {
            const pts = obj.points;
            if (!pts || pts.length === 0) return false;
            if (pts.length === 1) return distSq(p, pts[0]) <= tolSq;
            for (let i = 0; i < pts.length - 1; i++) {
                if (distToSegmentSq(p, pts[i], pts[i + 1]) <= tolSq) return true;
            }
            return false;
        }

        if (obj.type === "line" || obj.type === "arrow") {
            return distToSegmentSq(p, { x: obj.x1, y: obj.y1 }, { x: obj.x2, y: obj.y2 }) <= tolSq;
        }

        if (obj.type === "rectangle") {
            const minX = Math.min(obj.x, obj.x + obj.width);
            const maxX = Math.max(obj.x, obj.x + obj.width);
            const minY = Math.min(obj.y, obj.y + obj.height);
            const maxY = Math.max(obj.y, obj.y + obj.height);

            if (obj.filled && obj.fillColor && obj.fillColor !== "transparent") {
                return (x >= minX - tolerance && x <= maxX + tolerance && y >= minY - tolerance && y <= maxY + tolerance);
            }
            const p1 = { x: minX, y: minY }, p2 = { x: maxX, y: minY };
            const p3 = { x: maxX, y: maxY }, p4 = { x: minX, y: maxY };
            return (distToSegmentSq(p, p1, p2) <= tolSq ||
                    distToSegmentSq(p, p2, p3) <= tolSq ||
                    distToSegmentSq(p, p3, p4) <= tolSq ||
                    distToSegmentSq(p, p4, p1) <= tolSq);
        }

        if (obj.type === "ellipse") {
            const cx = obj.x + obj.width / 2;
            const cy = obj.y + obj.height / 2;
            const rx = Math.max(1, Math.abs(obj.width / 2));
            const ry = Math.max(1, Math.abs(obj.height / 2));
            const normX = (x - cx) / rx;
            const normY = (y - cy) / ry;
            const val = normX * normX + normY * normY;

            if (obj.filled && obj.fillColor && obj.fillColor !== "transparent") {
                return val <= 1.05;
            }
            const tolNorm = tolerance / Math.min(rx, ry);
            return Math.abs(Math.sqrt(val) - 1.0) <= tolNorm;
        }

        if (obj.type === "text") {
            const fontSize = obj.fontSize || 20;
            const approxWidth = Math.max(40, (obj.text || "").length * (fontSize * 0.6));
            const approxHeight = fontSize * 1.4 * ((obj.text || "").split("\n").length);
            return (x >= obj.x - tolerance && x <= obj.x + approxWidth + tolerance &&
                    y >= obj.y - tolerance && y <= obj.y + approxHeight + tolerance);
        }

        return false;
    }

    function findObjectAt(x, y, tolerance = 8) {
        for (let i = objects.length - 1; i >= 0; i--) {
            if (hitTestObject(objects[i], x, y, tolerance)) {
                return objects[i];
            }
        }
        return null;
    }

    function getBoundingBox(obj) {
        if (!obj) return null;
        if (obj.type === "stroke") {
            const pts = obj.points || [];
            if (pts.length === 0) return null;
            let minX = pts[0].x, maxX = pts[0].x;
            let minY = pts[0].y, maxY = pts[0].y;
            for (let i = 1; i < pts.length; i++) {
                if (pts[i].x < minX) minX = pts[i].x;
                if (pts[i].x > maxX) maxX = pts[i].x;
                if (pts[i].y < minY) minY = pts[i].y;
                if (pts[i].y > maxY) maxY = pts[i].y;
            }
            const pad = (obj.width || 3) / 2;
            return { x: minX - pad, y: minY - pad, width: (maxX - minX) + pad * 2, height: (maxY - minY) + pad * 2 };
        }
        if (obj.type === "line" || obj.type === "arrow") {
            const minX = Math.min(obj.x1, obj.x2);
            const maxX = Math.max(obj.x1, obj.x2);
            const minY = Math.min(obj.y1, obj.y2);
            const maxY = Math.max(obj.y1, obj.y2);
            const pad = (obj.width || 3) / 2;
            return { x: minX - pad, y: minY - pad, width: (maxX - minX) + pad * 2, height: (maxY - minY) + pad * 2 };
        }
        if (obj.type === "rectangle" || obj.type === "ellipse") {
            const minX = Math.min(obj.x, obj.x + obj.width);
            const maxX = Math.max(obj.x, obj.x + obj.width);
            const minY = Math.min(obj.y, obj.y + obj.height);
            const maxY = Math.max(obj.y, obj.y + obj.height);
            const pad = (obj.strokeWidth ?? obj.borderWidth ?? 3) / 2;
            return { x: minX - pad, y: minY - pad, width: (maxX - minX) + pad * 2, height: (maxY - minY) + pad * 2 };
        }
        if (obj.type === "text") {
            const fontSize = obj.fontSize || 20;
            const approxWidth = Math.max(20, (obj.text || "").length * (fontSize * 0.6));
            const approxHeight = fontSize * 1.35 * ((obj.text || "").split("\n").length);
            return { x: obj.x, y: obj.y, width: approxWidth, height: approxHeight };
        }
        return null;
    }

    function linesIntersect(x1, y1, x2, y2, x3, y3, x4, y4) {
        const denom = (y4 - y3) * (x2 - x1) - (x4 - x3) * (y2 - y1);
        if (denom === 0) return false;
        const ua = ((x4 - x3) * (y1 - y3) - (y4 - y3) * (x1 - x3)) / denom;
        const ub = ((x2 - x1) * (y1 - y3) - (y2 - y1) * (x1 - x3)) / denom;
        return (ua >= 0 && ua <= 1 && ub >= 0 && ub <= 1);
    }

    function segmentIntersectsBox(x1, y1, x2, y2, minX, minY, maxX, maxY) {
        if (x1 >= minX && x1 <= maxX && y1 >= minY && y1 <= maxY) return true;
        if (x2 >= minX && x2 <= maxX && y2 >= minY && y2 <= maxY) return true;
        return (linesIntersect(x1, y1, x2, y2, minX, minY, maxX, minY) ||
                linesIntersect(x1, y1, x2, y2, minX, maxY, maxX, maxY) ||
                linesIntersect(x1, y1, x2, y2, minX, minY, minX, maxY) ||
                linesIntersect(x1, y1, x2, y2, maxX, minY, maxX, maxY));
    }

    function isObjectInMarquee(obj, minX, minY, maxX, maxY, isCrossing) {
        if (!obj) return false;
        const box = getBoundingBox(obj);
        if (!box) return false;

        const bMinX = box.x;
        const bMaxX = box.x + box.width;
        const bMinY = box.y;
        const bMaxY = box.y + box.height;

        // Window Selection (drag left-to-right): Object must be completely enclosed in marquee
        if (!isCrossing) {
            return (bMinX >= minX && bMaxX <= maxX && bMinY >= minY && bMaxY <= maxY);
        }

        // Crossing Selection (drag right-to-left): Object intersects or touches marquee
        // Fast rejection: bounding box does not overlap
        if (bMaxX < minX || bMinX > maxX || bMaxY < minY || bMinY > maxY) {
            return false;
        }

        // If bounding box is completely enclosed
        if (bMinX >= minX && bMaxX <= maxX && bMinY >= minY && bMaxY <= maxY) {
            return true;
        }

        // For shapes (rectangle, ellipse, text), overlapping bounding box is sufficient
        if (obj.type === "rectangle" || obj.type === "ellipse" || obj.type === "text") {
            return true;
        }

        // For line and arrow
        if (obj.type === "line" || obj.type === "arrow") {
            return segmentIntersectsBox(obj.x1, obj.y1, obj.x2, obj.y2, minX, minY, maxX, maxY);
        }

        // For freehand stroke: check each segment between consecutive points
        if (obj.type === "stroke") {
            const pts = obj.points || [];
            if (pts.length === 0) return false;
            if (pts.length === 1) {
                return (pts[0].x >= minX && pts[0].x <= maxX && pts[0].y >= minY && pts[0].y <= maxY);
            }
            for (let i = 0; i < pts.length - 1; i++) {
                if (segmentIntersectsBox(pts[i].x, pts[i].y, pts[i + 1].x, pts[i + 1].y, minX, minY, maxX, maxY)) {
                    return true;
                }
            }
            return false;
        }

        return false;
    }

    function findObjectsInMarquee(minX, minY, maxX, maxY, isCrossing) {
        const result = [];
        for (let i = 0; i < objects.length; i++) {
            if (isObjectInMarquee(objects[i], minX, minY, maxX, maxY, isCrossing)) {
                result.push(objects[i].id);
            }
        }
        return result;
    }

    // JSON Serialization
    function toJSON(viewState = {}) {
        return JSON.stringify({
            version: 1,
            title: root.title,
            updatedAt: new Date().toISOString(),
            view: {
                zoom: viewState.zoom ?? root.viewZoom,
                panX: viewState.panX ?? root.viewPanX,
                panY: viewState.panY ?? root.viewPanY,
                background: viewState.background ?? root.viewBackground,
                grid: viewState.grid ?? root.viewGrid
            },
            objects: root.objects
        }, null, 2);
    }

    function fromJSON(jsonString) {
        try {
            const parsed = JSON.parse(jsonString);
            if (!parsed || !Array.isArray(parsed.objects)) {
                console.warn("[WhiteboardDocument] Invalid document schema");
                return null;
            }
            root.title = parsed.title || "Untitled Board";
            root.objects = parsed.objects;
            root.selectedIds = [];
            root.undoStack = [];
            root.redoStack = [];
            root.syncHistoryCounts();
            root.isDirty = false;
            if (parsed.view) {
                root.viewZoom = parsed.view.zoom ?? 1.0;
                root.viewPanX = parsed.view.panX ?? 0;
                root.viewPanY = parsed.view.panY ?? 0;
                root.viewBackground = parsed.view.background ?? "dark";
                root.viewGrid = parsed.view.grid ?? "dots";
            }
            root.selectionChanged();
            root.documentChanged();
            return parsed.view || null;
        } catch (e) {
            console.error("[WhiteboardDocument] Failed to parse JSON: " + e);
            return null;
        }
    }
}
