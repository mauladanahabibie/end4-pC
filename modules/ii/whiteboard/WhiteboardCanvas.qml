import QtQuick
import QtQuick.Controls
import qs.modules.common

Item {
    id: root

    required property var doc

    property string activeTool: "pen" // select, pen, highlighter, eraser, line, arrow, rectangle, ellipse, text, pan
    property color strokeColor: "#ffffff"
    property real strokeWidth: 3
    property color fillColor: "transparent"
    property bool isFilled: false
    property real fontSize: 22

    // Viewport transform
    property real zoom: 1.0
    property real panX: 0.0
    property real panY: 0.0
    property string backgroundMode: "dark" // dark, light, transparent
    property string gridMode: "dots" // dots, lines, none

    // Transient interaction state
    property var activeStroke: null
    property var activeShape: null
    property var selectionDragState: null
    property var marqueeState: null
    property bool isPanning: false
    property real panStartX: 0
    property real panStartY: 0
    property real initialPanX: 0
    property real initialPanY: 0

    // Text editing state
    property bool isEditingText: false
    property real textEditDocX: 0
    property real textEditDocY: 0
    property string editingTextId: ""

    clip: true

    function screenToDoc(sx, sy) {
        return {
            x: (sx - root.panX) / root.zoom,
            y: (sy - root.panY) / root.zoom
        };
    }

    function docToScreen(dx, dy) {
        return {
            x: dx * root.zoom + root.panX,
            y: dy * root.zoom + root.panY
        };
    }

    function resetView() {
        root.zoom = 1.0;
        root.panX = 0.0;
        root.panY = 0.0;
        requestRepaint();
    }

    function zoomIn() {
        setZoomCentered(Math.min(4.0, root.zoom * 1.25), width / 2, height / 2);
    }

    function zoomOut() {
        setZoomCentered(Math.max(0.25, root.zoom / 1.25), width / 2, height / 2);
    }

    function setZoomCentered(newZoom, centerX, centerY) {
        const oldZoom = root.zoom;
        if (Math.abs(newZoom - oldZoom) < 0.001) return;
        const docPt = screenToDoc(centerX, centerY);
        root.zoom = newZoom;
        root.panX = centerX - docPt.x * newZoom;
        root.panY = centerY - docPt.y * newZoom;
        requestRepaint();
    }

    function requestRepaint() {
        canvasBase.requestPaint();
        canvasPreview.requestPaint();
    }

    Connections {
        target: root.doc
        function onDocumentChanged() {
            canvasBase.requestPaint();
            canvasPreview.requestPaint();
        }
        function onSelectionChanged() {
            canvasPreview.requestPaint();
        }
    }

    onWidthChanged: requestRepaint()
    onHeightChanged: requestRepaint()

    // Background fill
    Rectangle {
        id: bgRect
        anchors.fill: parent
        color: {
            if (root.backgroundMode === "light") return "#f5f5f7";
            if (root.backgroundMode === "transparent") return "transparent";
            return "#18181b"; // sleek dark zinc surface
        }
    }

    // Grid rendering canvas
    Canvas {
        id: gridCanvas
        anchors.fill: parent
        renderStrategy: Canvas.Immediate

        onPaint: {
            var ctx = getContext("2d");
            ctx.resetTransform();
            ctx.clearRect(0, 0, width, height);

            if (root.gridMode === "none") return;

            const isLight = root.backgroundMode === "light";
            const baseGridSize = 32;
            const scaledGrid = baseGridSize * root.zoom;
            if (scaledGrid < 8) return; // avoid dense noise when zoomed out

            const offsetX = (root.panX % scaledGrid + scaledGrid) % scaledGrid;
            const offsetY = (root.panY % scaledGrid + scaledGrid) % scaledGrid;

            if (root.gridMode === "dots") {
                ctx.fillStyle = isLight ? "rgba(0, 0, 0, 0.18)" : "rgba(255, 255, 255, 0.14)";
                const dotRadius = Math.max(1, Math.min(2.2, 1.2 * Math.sqrt(root.zoom)));
                for (let x = offsetX; x < width; x += scaledGrid) {
                    for (let y = offsetY; y < height; y += scaledGrid) {
                        ctx.beginPath();
                        ctx.arc(x, y, dotRadius, 0, Math.PI * 2);
                        ctx.fill();
                    }
                }
            } else if (root.gridMode === "lines") {
                ctx.strokeStyle = isLight ? "rgba(0, 0, 0, 0.08)" : "rgba(255, 255, 255, 0.06)";
                ctx.lineWidth = 1;
                ctx.beginPath();
                for (let x = offsetX; x < width; x += scaledGrid) {
                    ctx.moveTo(Math.round(x) + 0.5, 0);
                    ctx.lineTo(Math.round(x) + 0.5, height);
                }
                for (let y = offsetY; y < height; y += scaledGrid) {
                    ctx.moveTo(0, Math.round(y) + 0.5);
                    ctx.lineTo(width, Math.round(y) + 0.5);
                }
                ctx.stroke();
            }
        }

        Connections {
            target: root
            function onPanXChanged() { gridCanvas.requestPaint(); }
            function onPanYChanged() { gridCanvas.requestPaint(); }
            function onZoomChanged() { gridCanvas.requestPaint(); }
            function onGridModeChanged() { gridCanvas.requestPaint(); }
            function onBackgroundModeChanged() { gridCanvas.requestPaint(); }
        }
    }

    // Base Canvas: renders committed vector objects
    Canvas {
        id: canvasBase
        anchors.fill: parent
        renderStrategy: Canvas.Immediate

        onPaint: {
            var ctx = getContext("2d");
            ctx.resetTransform();
            ctx.clearRect(0, 0, width, height);

            ctx.save();
            ctx.translate(root.panX, root.panY);
            ctx.scale(root.zoom, root.zoom);

            const objs = root.doc.objects;
            for (let i = 0; i < objs.length; i++) {
                drawObject(ctx, objs[i]);
            }

            ctx.restore();
        }
    }

    // Interactive Preview Canvas: renders active stroke, dragging shape, selection bounds
    Canvas {
        id: canvasPreview
        anchors.fill: parent
        renderStrategy: Canvas.Immediate

        onPaint: {
            var ctx = getContext("2d");
            ctx.resetTransform();
            ctx.clearRect(0, 0, width, height);

            ctx.save();
            ctx.translate(root.panX, root.panY);
            ctx.scale(root.zoom, root.zoom);

            // Draw active stroke if currently drawing freehand
            if (root.activeStroke) {
                drawObject(ctx, root.activeStroke);
            }

            // Draw active shape preview
            if (root.activeShape) {
                drawObject(ctx, root.activeShape);
            }

            // Draw selection outlines & handles for selected objects
            if (root.doc.selectedIds.length > 0) {
                ctx.save();
                ctx.strokeStyle = Appearance.colors.colPrimary ?? "#6750a4";
                ctx.lineWidth = 1.5 / root.zoom;
                ctx.setLineDash([4 / root.zoom, 3 / root.zoom]);

                for (let i = 0; i < root.doc.selectedIds.length; i++) {
                    const id = root.doc.selectedIds[i];
                    const obj = root.doc.objects.find(o => o.id === id);
                    if (obj) {
                        const box = root.doc.getBoundingBox(obj);
                        if (box) {
                            ctx.strokeRect(box.x, box.y, box.width, box.height);

                            // Draw subtle corner handles
                            const hSize = 6 / root.zoom;
                            ctx.fillStyle = Appearance.colors.colPrimary ?? "#6750a4";
                            ctx.fillRect(box.x - hSize / 2, box.y - hSize / 2, hSize, hSize);
                            ctx.fillRect(box.x + box.width - hSize / 2, box.y - hSize / 2, hSize, hSize);
                            ctx.fillRect(box.x - hSize / 2, box.y + box.height - hSize / 2, hSize, hSize);
                            ctx.fillRect(box.x + box.width - hSize / 2, box.y + box.height - hSize / 2, hSize, hSize);
                        }
                    }
                }
                ctx.restore();
            }

            // Draw active marquee selection rectangle
            if (root.marqueeState) {
                const mq = root.marqueeState;
                const mMinX = Math.min(mq.startX, mq.currentX);
                const mMaxX = Math.max(mq.startX, mq.currentX);
                const mMinY = Math.min(mq.startY, mq.currentY);
                const mMaxY = Math.max(mq.startY, mq.currentY);
                const mWidth = mMaxX - mMinX;
                const mHeight = mMaxY - mMinY;

                if (mWidth > 1 || mHeight > 1) {
                    const isCrossing = mq.currentX < mq.startX;
                    ctx.save();
                    if (isCrossing) {
                        // Crossing Selection (right-to-left): Green dashed border with translucent fill
                        ctx.fillStyle = "rgba(34, 197, 94, 0.12)";
                        ctx.strokeStyle = "rgba(34, 197, 94, 0.9)";
                        ctx.lineWidth = 1.5 / root.zoom;
                        ctx.setLineDash([5 / root.zoom, 3 / root.zoom]);
                    } else {
                        // Window Selection (left-to-right): Blue solid border with translucent fill
                        ctx.fillStyle = "rgba(59, 130, 246, 0.12)";
                        ctx.strokeStyle = "rgba(59, 130, 246, 0.9)";
                        ctx.lineWidth = 1.5 / root.zoom;
                        ctx.setLineDash([]);
                    }
                    ctx.fillRect(mMinX, mMinY, mWidth, mHeight);
                    ctx.strokeRect(mMinX, mMinY, mWidth, mHeight);
                    ctx.restore();
                }
            }

            ctx.restore();
        }
    }

    // Object Rendering Functions
    function drawObject(ctx, obj) {
        if (!obj) return;

        if (obj.type === "stroke") {
            const pts = obj.points;
            if (!pts || pts.length === 0) return;

            ctx.save();
            ctx.strokeStyle = obj.color || "#ffffff";
            ctx.lineWidth = obj.width || 3;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";

            if (obj.tool === "highlighter") {
                ctx.globalAlpha = 0.38;
                ctx.lineWidth = (obj.width || 8) * 2.2;
            } else {
                ctx.globalAlpha = obj.opacity ?? 1.0;
            }

            if (pts.length === 1) {
                ctx.beginPath();
                ctx.arc(pts[0].x, pts[0].y, (obj.width || 3) / 2, 0, Math.PI * 2);
                ctx.fillStyle = obj.color || "#ffffff";
                ctx.fill();
            } else {
                ctx.beginPath();
                ctx.moveTo(pts[0].x, pts[0].y);
                if (pts.length === 2) {
                    ctx.lineTo(pts[1].x, pts[1].y);
                } else {
                    for (let i = 1; i < pts.length - 1; i++) {
                        const midX = (pts[i].x + pts[i + 1].x) / 2;
                        const midY = (pts[i].y + pts[i + 1].y) / 2;
                        ctx.quadraticCurveTo(pts[i].x, pts[i].y, midX, midY);
                    }
                    ctx.lineTo(pts[pts.length - 1].x, pts[pts.length - 1].y);
                }
                ctx.stroke();
            }
            ctx.restore();
        } else if (obj.type === "line") {
            ctx.save();
            ctx.strokeStyle = obj.color || "#ffffff";
            ctx.lineWidth = obj.width || 3;
            ctx.lineCap = "round";
            ctx.beginPath();
            ctx.moveTo(obj.x1, obj.y1);
            ctx.lineTo(obj.x2, obj.y2);
            ctx.stroke();
            ctx.restore();
        } else if (obj.type === "arrow") {
            ctx.save();
            ctx.strokeStyle = obj.color || "#ffffff";
            ctx.fillStyle = obj.color || "#ffffff";
            ctx.lineWidth = obj.width || 3;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";

            const dx = obj.x2 - obj.x1;
            const dy = obj.y2 - obj.y1;
            const angle = Math.atan2(dy, dx);
            const lineLen = Math.sqrt(dx * dx + dy * dy);
            const headLength = Math.max(12, Math.min(28, (obj.width || 3) * 3.5));

            ctx.beginPath();
            ctx.moveTo(obj.x1, obj.y1);
            ctx.lineTo(obj.x2, obj.y2);
            ctx.stroke();

            if (lineLen > 4) {
                ctx.beginPath();
                ctx.moveTo(obj.x2, obj.y2);
                ctx.lineTo(
                    obj.x2 - headLength * Math.cos(angle - Math.PI / 6),
                    obj.y2 - headLength * Math.sin(angle - Math.PI / 6)
                );
                ctx.lineTo(
                    obj.x2 - headLength * Math.cos(angle + Math.PI / 6),
                    obj.y2 - headLength * Math.sin(angle + Math.PI / 6)
                );
                ctx.closePath();
                ctx.fill();
            }
            ctx.restore();
        } else if (obj.type === "rectangle") {
            ctx.save();
            ctx.strokeStyle = obj.color || "#ffffff";
            ctx.lineWidth = obj.strokeWidth ?? obj.borderWidth ?? 3;
            ctx.lineJoin = "round";

            if (obj.filled && obj.fillColor && obj.fillColor !== "transparent") {
                ctx.fillStyle = obj.fillColor;
                ctx.fillRect(obj.x, obj.y, obj.width, obj.height);
            }
            ctx.strokeRect(obj.x, obj.y, obj.width, obj.height);
            ctx.restore();
        } else if (obj.type === "ellipse") {
            ctx.save();
            ctx.strokeStyle = obj.color || "#ffffff";
            ctx.lineWidth = obj.strokeWidth ?? obj.borderWidth ?? 3;

            const cx = obj.x + obj.width / 2;
            const cy = obj.y + obj.height / 2;
            const rx = Math.max(0.1, Math.abs(obj.width / 2));
            const ry = Math.max(0.1, Math.abs(obj.height / 2));

            ctx.beginPath();
            ctx.ellipse(cx, cy, rx, ry, 0, 0, Math.PI * 2);
            if (obj.filled && obj.fillColor && obj.fillColor !== "transparent") {
                ctx.fillStyle = obj.fillColor;
                ctx.fill();
            }
            ctx.stroke();
            ctx.restore();
        } else if (obj.type === "text") {
            ctx.save();
            ctx.fillStyle = obj.color || "#ffffff";
            const fFamily = Appearance.font.family.main ? `"${Appearance.font.family.main}", sans-serif` : "sans-serif";
            ctx.font = `${obj.fontSize || 22}px ${fFamily}`;
            ctx.textBaseline = "top";
            const lines = (obj.text || "").split("\n");
            const lineHeight = (obj.fontSize || 22) * 1.35;
            for (let l = 0; l < lines.length; l++) {
                ctx.fillText(lines[l], obj.x, obj.y + l * lineHeight);
            }
            ctx.restore();
        }
    }

    // Inline Text Editor Item
    Item {
        id: textEditorContainer
        visible: root.isEditingText
        x: root.docToScreen(root.textEditDocX, root.textEditDocY).x
        y: root.docToScreen(root.textEditDocX, root.textEditDocY).y
        z: 10

        TextArea {
            id: inlineTextArea
            width: Math.max(160, implicitWidth + 24)
            height: Math.max(40, implicitHeight + 12)
            font.pixelSize: root.fontSize * root.zoom
            font.family: Appearance.font.family.main || "sans-serif"
            color: root.strokeColor
            wrapMode: TextEdit.NoWrap
            background: Rectangle {
                color: root.backgroundMode === "light" ? "#e6ffffff" : "#e61e1e22"
                border.width: 1.5
                border.color: Appearance.colors.colPrimary ?? "#6750a4"
                radius: 6
            }

            Keys.onEscapePressed: {
                root.finishTextEdit(false);
            }

            Keys.onReturnPressed: (event) => {
                if (event.modifiers & Qt.ShiftModifier) {
                    inlineTextArea.insert(inlineTextArea.cursorPosition, "\n");
                } else {
                    root.finishTextEdit(true);
                }
            }

            onActiveFocusChanged: {
                if (!activeFocus && root.isEditingText) {
                    root.finishTextEdit(true);
                }
            }
        }
    }

    function startTextEdit(docX, docY, existingObj = null) {
        root.isEditingText = true;
        if (existingObj) {
            root.editingTextId = existingObj.id;
            root.textEditDocX = existingObj.x;
            root.textEditDocY = existingObj.y;
            inlineTextArea.text = existingObj.text || "";
            root.strokeColor = existingObj.color || root.strokeColor;
            root.fontSize = existingObj.fontSize || root.fontSize;
        } else {
            root.editingTextId = "";
            root.textEditDocX = docX;
            root.textEditDocY = docY;
            inlineTextArea.text = "";
        }
        inlineTextArea.forceActiveFocus();
    }

    function finishTextEdit(commit = true) {
        if (!root.isEditingText) return;
        const textVal = inlineTextArea.text.trim();
        root.isEditingText = false;

        if (commit && textVal.length > 0) {
            if (root.editingTextId) {
                root.doc.updateObject(root.editingTextId, {
                    text: textVal,
                    color: root.strokeColor.toString(),
                    fontSize: root.fontSize
                });
            } else {
                root.doc.addObject({
                    type: "text",
                    x: root.textEditDocX,
                    y: root.textEditDocY,
                    text: textVal,
                    color: root.strokeColor.toString(),
                    fontSize: root.fontSize
                });
            }
        }
        root.editingTextId = "";
        canvasBase.requestPaint();
    }

    // Pointer Event Handler
    MouseArea {
        id: mouseHandler
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        hoverEnabled: true

        cursorShape: {
            if (root.isPanning) return Qt.ClosedHandCursor;
            if (root.activeTool === "pan") return Qt.OpenHandCursor;
            if (root.activeTool === "select") {
                if (root.selectionDragState) return Qt.SizeAllCursor;
                if (root.marqueeState) return Qt.CrossCursor;
                return Qt.ArrowCursor;
            }
            if (root.activeTool === "pen" || root.activeTool === "highlighter") return Qt.CrossCursor;
            if (root.activeTool === "eraser") return Qt.PointingHandCursor;
            if (root.activeTool === "line" || root.activeTool === "arrow" || root.activeTool === "rectangle" || root.activeTool === "ellipse") return Qt.CrossCursor;
            if (root.activeTool === "text") return Qt.IBeamCursor;
            return Qt.ArrowCursor;
        }

        onWheel: (wheel) => {
            const factor = wheel.angleDelta.y > 0 ? 1.15 : 0.87;
            const newZoom = Math.max(0.25, Math.min(4.0, root.zoom * factor));
            root.setZoomCentered(newZoom, wheel.x, wheel.y);
        }

        onPressed: (mouse) => {
            root.forceActiveFocus();
            if (root.isEditingText) {
                root.finishTextEdit(true);
            }

            // Middle button or Pan tool triggers viewport pan
            if (mouse.button === Qt.MiddleButton || root.activeTool === "pan") {
                root.isPanning = true;
                root.panStartX = mouse.x;
                root.panStartY = mouse.y;
                root.initialPanX = root.panX;
                root.initialPanY = root.panY;
                return;
            }

            if (mouse.button !== Qt.LeftButton) return;

            const docPt = root.screenToDoc(mouse.x, mouse.y);

            if (root.activeTool === "pen" || root.activeTool === "highlighter") {
                root.activeStroke = {
                    type: "stroke",
                    tool: root.activeTool,
                    color: root.strokeColor.toString(),
                    width: root.activeTool === "highlighter" ? Math.max(8, root.strokeWidth * 2) : root.strokeWidth,
                    opacity: root.activeTool === "highlighter" ? 0.38 : 1.0,
                    points: [{ x: docPt.x, y: docPt.y }]
                };
                canvasPreview.requestPaint();
            } else if (root.activeTool === "line" || root.activeTool === "arrow") {
                root.activeShape = {
                    type: root.activeTool,
                    x1: docPt.x,
                    y1: docPt.y,
                    x2: docPt.x,
                    y2: docPt.y,
                    color: root.strokeColor.toString(),
                    width: root.strokeWidth
                };
                canvasPreview.requestPaint();
            } else if (root.activeTool === "rectangle" || root.activeTool === "ellipse") {
                root.activeShape = {
                    type: root.activeTool,
                    x: docPt.x,
                    y: docPt.y,
                    width: 0,
                    height: 0,
                    startX: docPt.x,
                    startY: docPt.y,
                    color: root.strokeColor.toString(),
                    strokeWidth: root.strokeWidth,
                    filled: root.isFilled,
                    fillColor: root.fillColor.toString()
                };
                canvasPreview.requestPaint();
            } else if (root.activeTool === "eraser") {
                const hit = root.doc.findObjectAt(docPt.x, docPt.y, 10 / root.zoom);
                if (hit) {
                    root.doc.removeObject(hit.id);
                }
            } else if (root.activeTool === "select") {
                const isShift = (mouse.modifiers & Qt.ShiftModifier) !== 0;
                let hit = root.doc.findObjectAt(docPt.x, docPt.y, 8 / root.zoom);

                if (!hit && !isShift && root.doc.selectedIds.length > 0) {
                    for (let i = 0; i < root.doc.selectedIds.length; i++) {
                        const sObj = root.doc.objects.find(o => o.id === root.doc.selectedIds[i]);
                        if (sObj) {
                            const sBox = root.doc.getBoundingBox(sObj);
                            if (sBox && docPt.x >= sBox.x && docPt.x <= sBox.x + sBox.width &&
                                docPt.y >= sBox.y && docPt.y <= sBox.y + sBox.height) {
                                hit = sObj;
                                break;
                            }
                        }
                    }
                }

                if (hit) {
                    if (isShift) {
                        if (root.doc.selectedIds.includes(hit.id)) {
                            root.doc.selectedIds = root.doc.selectedIds.filter(id => id !== hit.id);
                        } else {
                            const next = root.doc.selectedIds.slice();
                            next.push(hit.id);
                            root.doc.selectedIds = next;
                        }
                        root.doc.selectionChanged();
                    } else {
                        if (!root.doc.selectedIds.includes(hit.id)) {
                            root.doc.selectedIds = [hit.id];
                            root.doc.selectionChanged();
                        }
                    }
                    root.selectionDragState = {
                        startX: docPt.x,
                        startY: docPt.y,
                        totalDeltaX: 0,
                        totalDeltaY: 0,
                        selectedIds: root.doc.selectedIds.slice()
                    };
                    root.marqueeState = null;
                } else {
                    if (!isShift) {
                        root.doc.selectedIds = [];
                        root.doc.selectionChanged();
                    }
                    root.selectionDragState = null;
                    root.marqueeState = {
                        startX: docPt.x,
                        startY: docPt.y,
                        currentX: docPt.x,
                        currentY: docPt.y,
                        isShift: isShift,
                        initialSelectedIds: root.doc.selectedIds.slice()
                    };
                }
                canvasPreview.requestPaint();
            } else if (root.activeTool === "text") {
                const hit = root.doc.findObjectAt(docPt.x, docPt.y, 6 / root.zoom);
                if (hit && hit.type === "text") {
                    root.startTextEdit(hit.x, hit.y, hit);
                } else {
                    root.startTextEdit(docPt.x, docPt.y, null);
                }
            }
        }

        onPositionChanged: (mouse) => {
            if (root.isPanning) {
                root.panX = root.initialPanX + (mouse.x - root.panStartX);
                root.panY = root.initialPanY + (mouse.y - root.panStartY);
                root.requestRepaint();
                return;
            }

            const docPt = root.screenToDoc(mouse.x, mouse.y);

            if (root.activeStroke) {
                const pts = root.activeStroke.points;
                const last = pts[pts.length - 1];
                const dx = docPt.x - last.x;
                const dy = docPt.y - last.y;
                if (dx * dx + dy * dy >= 2.0 / (root.zoom * root.zoom)) {
                    pts.push({ x: docPt.x, y: docPt.y });
                    canvasPreview.requestPaint();
                }
            } else if (root.activeShape) {
                const sh = root.activeShape;
                if (sh.type === "line" || sh.type === "arrow") {
                    sh.x2 = docPt.x;
                    sh.y2 = docPt.y;
                } else if (sh.type === "rectangle" || sh.type === "ellipse") {
                    sh.x = Math.min(sh.startX, docPt.x);
                    sh.y = Math.min(sh.startY, docPt.y);
                    sh.width = Math.abs(docPt.x - sh.startX);
                    sh.height = Math.abs(docPt.y - sh.startY);
                }
                canvasPreview.requestPaint();
            } else if (root.activeTool === "eraser" && mouse.buttons & Qt.LeftButton) {
                const hit = root.doc.findObjectAt(docPt.x, docPt.y, 10 / root.zoom);
                if (hit) {
                    root.doc.removeObject(hit.id);
                }
            } else if (root.selectionDragState && mouse.buttons & Qt.LeftButton) {
                const curDeltaX = docPt.x - root.selectionDragState.startX;
                const curDeltaY = docPt.y - root.selectionDragState.startY;
                const stepX = curDeltaX - root.selectionDragState.totalDeltaX;
                const stepY = curDeltaY - root.selectionDragState.totalDeltaY;
                root.selectionDragState.totalDeltaX = curDeltaX;
                root.selectionDragState.totalDeltaY = curDeltaY;
                root.doc.moveObjects(root.selectionDragState.selectedIds, stepX, stepY, false);
            } else if (root.marqueeState && mouse.buttons & Qt.LeftButton) {
                root.marqueeState.currentX = docPt.x;
                root.marqueeState.currentY = docPt.y;
                canvasPreview.requestPaint();
            }
        }

        onReleased: (mouse) => {
            if (root.isPanning) {
                root.isPanning = false;
                return;
            }

            if (root.activeStroke) {
                if (root.activeStroke.points.length > 0) {
                    root.doc.addObject(root.activeStroke);
                }
                root.activeStroke = null;
                canvasPreview.requestPaint();
            } else if (root.activeShape) {
                const sh = root.activeShape;
                let isValid = false;
                if (sh.type === "line" || sh.type === "arrow") {
                    const dx = sh.x2 - sh.x1;
                    const dy = sh.y2 - sh.y1;
                    isValid = (dx * dx + dy * dy) >= 9;
                } else if (sh.type === "rectangle" || sh.type === "ellipse") {
                    isValid = (sh.width >= 4 && sh.height >= 4);
                }
                if (isValid) {
                    delete sh.startX;
                    delete sh.startY;
                    root.doc.addObject(sh);
                }
                root.activeShape = null;
                canvasPreview.requestPaint();
            } else if (root.selectionDragState) {
                if (root.selectionDragState.totalDeltaX !== 0 || root.selectionDragState.totalDeltaY !== 0) {
                    // Push consolidated move command to history
                    root.doc.pushUndoCommand({
                        type: "moveBatch",
                        deltaX: root.selectionDragState.totalDeltaX,
                        deltaY: root.selectionDragState.totalDeltaY,
                        items: root.selectionDragState.selectedIds.map(id => {
                            const o = root.doc.objects.find(x => x.id === id);
                            const before = JSON.parse(JSON.stringify(o));
                            if (before.type === "stroke") {
                                for (let p = 0; p < before.points.length; p++) {
                                    before.points[p].x -= root.selectionDragState.totalDeltaX;
                                    before.points[p].y -= root.selectionDragState.totalDeltaY;
                                }
                            } else if (before.type === "line" || before.type === "arrow") {
                                before.x1 -= root.selectionDragState.totalDeltaX;
                                before.y1 -= root.selectionDragState.totalDeltaY;
                                before.x2 -= root.selectionDragState.totalDeltaX;
                                before.y2 -= root.selectionDragState.totalDeltaY;
                            } else {
                                before.x -= root.selectionDragState.totalDeltaX;
                                before.y -= root.selectionDragState.totalDeltaY;
                            }
                            return { id: id, before: before };
                        })
                    });
                }
                root.selectionDragState = null;
                canvasPreview.requestPaint();
            } else if (root.marqueeState) {
                const ms = root.marqueeState;
                const mMinX = Math.min(ms.startX, ms.currentX);
                const mMinY = Math.min(ms.startY, ms.currentY);
                const mMaxX = Math.max(ms.startX, ms.currentX);
                const mMaxY = Math.max(ms.startY, ms.currentY);
                const isCrossing = ms.currentX < ms.startX;

                const isDrag = Math.abs(ms.currentX - ms.startX) > 3 || Math.abs(ms.currentY - ms.startY) > 3;
                if (isDrag) {
                    const matchedIds = root.doc.findObjectsInMarquee(mMinX, mMinY, mMaxX, mMaxY, isCrossing);
                    if (ms.isShift) {
                        const set = new Set(ms.initialSelectedIds);
                        for (let k = 0; k < matchedIds.length; k++) {
                            set.add(matchedIds[k]);
                        }
                        root.doc.selectedIds = Array.from(set);
                    } else {
                        root.doc.selectedIds = matchedIds;
                    }
                } else if (!ms.isShift) {
                    root.doc.selectedIds = [];
                }
                root.doc.selectionChanged();
                root.marqueeState = null;
                canvasPreview.requestPaint();
                root.requestRepaint();
            }
        }
    }
}
