import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Item {
    id: root

    property alias canvas: canvasItem
    readonly property var document: docItem
    property alias isMaximized: root.maximized

    property bool maximized: false
    property string nextScreenName: ""
    signal closeRequested()
    signal switchScreenRequested()

    property var doc: null
    readonly property var docItem: root.doc ?? internalDoc

    WhiteboardDocument {
        id: internalDoc
        onDocumentChanged: {
            autoSaveTimer.restart();
        }
    }

    Connections {
        target: root.doc
        function onDocumentChanged() {
            autoSaveTimer.restart();
        }
    }

    Connections {
        target: canvasItem
        function onZoomChanged() { if (canvasItem && docItem) docItem.viewZoom = canvasItem.zoom; }
        function onPanXChanged() { if (canvasItem && docItem) docItem.viewPanX = canvasItem.panX; }
        function onPanYChanged() { if (canvasItem && docItem) docItem.viewPanY = canvasItem.panY; }
        function onBackgroundModeChanged() { if (canvasItem && docItem) docItem.viewBackground = canvasItem.backgroundMode; }
        function onGridModeChanged() { if (canvasItem && docItem) docItem.viewGrid = canvasItem.gridMode; }
    }

    Component.onCompleted: {
        root.forceActiveFocus();
        if (docItem) {
            canvasItem.zoom = docItem.viewZoom;
            canvasItem.panX = docItem.viewPanX;
            canvasItem.panY = docItem.viewPanY;
            canvasItem.backgroundMode = docItem.viewBackground;
            canvasItem.gridMode = docItem.viewGrid;
            canvasItem.requestRepaint();
        }
    }

    // Auto-save active document (fallback when root.doc is null)
    Timer {
        id: autoSaveTimer
        interval: 600
        repeat: false
        onTriggered: {
            if (root.doc) return;
            const json = docItem.toJSON({
                zoom: canvasItem.zoom,
                panX: canvasItem.panX,
                panY: canvasItem.panY,
                background: canvasItem.backgroundMode,
                grid: canvasItem.gridMode
            });
            activeFile.setText(json);
            docItem.isDirty = false;
        }
    }

    FileView {
        id: activeFile
        path: root.doc ? "" : `${Directories.state}/user/whiteboard/active.json`
        watchChanges: true
        onFileChanged: activeFile.reload()
        onLoaded: {
            if (root.doc) return;
            const content = activeFile.text();
            if (content && content.trim().length > 0) {
                const view = docItem.fromJSON(content);
                if (view) {
                    canvasItem.zoom = view.zoom ?? docItem.viewZoom;
                    canvasItem.panX = view.panX ?? docItem.viewPanX;
                    canvasItem.panY = view.panY ?? docItem.viewPanY;
                    canvasItem.backgroundMode = view.background ?? docItem.viewBackground;
                    canvasItem.gridMode = view.grid ?? docItem.viewGrid;
                    canvasItem.requestRepaint();
                }
            }
        }
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                // Initial clean state: auto-save default blank board
                autoSaveTimer.restart();
            } else {
                console.log("[Whiteboard] Error loading active file: " + error);
            }
        }
    }

    // File Dialog Processes
    Process {
        id: openPickerProc
        command: ["python3", Quickshell.shellPath("scripts/whiteboard/pick-board.py")]
        stdout: SplitParser {
            onRead: data => {
                const path = data.trim();
                if (path.length > 0) {
                    externalReadFile.path = path;
                    externalReadFile.reload();
                }
            }
        }
    }

    FileView {
        id: externalReadFile
        onLoaded: {
            const content = externalReadFile.text();
            if (content && content.trim().length > 0) {
                const view = docItem.fromJSON(content);
                if (view) {
                    canvasItem.zoom = view.zoom ?? 1.0;
                    canvasItem.panX = view.panX ?? 0;
                    canvasItem.panY = view.panY ?? 0;
                    canvasItem.backgroundMode = view.background ?? "dark";
                    canvasItem.gridMode = view.grid ?? "dots";
                    canvasItem.requestRepaint();
                }
                autoSaveTimer.restart();
            }
        }
    }

    Process {
        id: savePickerProc
        command: ["python3", Quickshell.shellPath("scripts/whiteboard/pick-save-board.py")]
        stdout: SplitParser {
            onRead: data => {
                const path = data.trim();
                if (path.length > 0) {
                    const json = docItem.toJSON({
                        zoom: canvasItem.zoom,
                        panX: canvasItem.panX,
                        panY: canvasItem.panY,
                        background: canvasItem.backgroundMode,
                        grid: canvasItem.gridMode
                    });
                    externalWriteFile.path = path;
                    externalWriteFile.setText(json);
                }
            }
        }
    }

    FileView {
        id: externalWriteFile
    }

    Process {
        id: exportPickerProc
        command: ["python3", Quickshell.shellPath("scripts/whiteboard/pick-export-image.py")]
        stdout: SplitParser {
            onRead: data => {
                const path = data.trim();
                if (path.length > 0) {
                    canvasItem.grabToImage(result => {
                        result.saveToFile(path);
                    });
                }
            }
        }
    }

    function openBoard() {
        openPickerProc.running = true;
    }

    function saveBoardAs() {
        savePickerProc.running = true;
    }

    function exportImage() {
        exportPickerProc.running = true;
    }

    // Keyboard Shortcuts
    focus: true
    Keys.onPressed: (event) => {
        const isCtrl = event.modifiers & Qt.ControlModifier;
        const isShift = event.modifiers & Qt.ShiftModifier;

        if (isCtrl && event.key === Qt.Key_Z) {
            if (isShift) docItem.redo();
            else docItem.undo();
            event.accepted = true;
            return;
        }
        if (isCtrl && event.key === Qt.Key_Y) {
            docItem.redo();
            event.accepted = true;
            return;
        }
        if (isCtrl && event.key === Qt.Key_S) {
            root.saveBoardAs();
            event.accepted = true;
            return;
        }
        if (isCtrl && event.key === Qt.Key_O) {
            root.openBoard();
            event.accepted = true;
            return;
        }
        if (isCtrl && event.key === Qt.Key_N) {
            docItem.clearBoard(true);
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
            if (docItem.selectedIds.length > 0 && !canvasItem.isEditingText) {
                docItem.removeObjects(docItem.selectedIds, true);
                event.accepted = true;
                return;
            }
        }
        if (event.key === Qt.Key_Escape) {
            if (canvasItem.isEditingText) {
                canvasItem.finishTextEdit(false);
            } else if (docItem.selectedIds.length > 0) {
                docItem.selectedIds = [];
                docItem.selectionChanged();
            } else {
                toolbarItem.closeAllPopups();
            }
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) {
            canvasItem.zoomIn();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Minus) {
            canvasItem.zoomOut();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_0) {
            canvasItem.resetView();
            event.accepted = true;
            return;
        }
        if ((isCtrl && isShift && event.key === Qt.Key_M) || (event.modifiers & Qt.AltModifier && event.key === Qt.Key_M)) {
            root.switchScreenRequested();
            event.accepted = true;
            return;
        }
        // Tool shortcut keys (when not editing text)
        if (!canvasItem.isEditingText && !isCtrl) {
            if (event.key === Qt.Key_V) { canvasItem.activeTool = "select"; event.accepted = true; }
            else if (event.key === Qt.Key_H) { canvasItem.activeTool = "pan"; event.accepted = true; }
            else if (event.key === Qt.Key_P) { canvasItem.activeTool = "pen"; event.accepted = true; }
            else if (event.key === Qt.Key_E) { canvasItem.activeTool = "eraser"; event.accepted = true; }
            else if (event.key === Qt.Key_T) { canvasItem.activeTool = "text"; event.accepted = true; }
            else if (event.key === Qt.Key_R) { canvasItem.activeTool = "rectangle"; event.accepted = true; }
            else if (event.key === Qt.Key_C) { canvasItem.activeTool = "ellipse"; event.accepted = true; }
            else if (event.key === Qt.Key_L) { canvasItem.activeTool = "line"; event.accepted = true; }
            else if (event.key === Qt.Key_A) { canvasItem.activeTool = "arrow"; event.accepted = true; }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Titlebar / Window Header
        Rectangle {
            id: headerBar
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            color: Appearance.colors.colUiBackground
            radius: Appearance.rounding.windowRounding
            z: 10

            // Fill lower corners so header merges flush into canvas
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 12
                color: Appearance.colors.colUiBackground
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Appearance.colors.colLayer0Border
                opacity: 0.6
            }

            RowLayout {
                anchors { fill: parent; leftMargin: 14; rightMargin: 12 }
                spacing: 10

                // App Icon & Title
                MaterialSymbol {
                    text: "draw"
                    iconSize: 22
                    color: Appearance.colors.colPrimary ?? "#ffffff"
                }

                StyledText {
                    text: Translation.tr("Whiteboard")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnSurface
                }

                StyledText {
                    text: docItem.title
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnSurfaceVariant
                    opacity: 0.7
                }

                StyledText {
                    visible: autoSaveTimer.running
                    text: Translation.tr("Saving...")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colPrimary ?? "#3b82f6"
                    opacity: 0.8
                }

                Item { Layout.fillWidth: true }

                // Quick Header Actions
                RippleButton {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    buttonRadius: 16
                    colBackground: "transparent"
                    StyledToolTip { text: Translation.tr("Export as PNG") }
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "download"
                        iconSize: 18
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                    onClicked: root.exportImage()
                }

                RippleButton {
                    visible: Quickshell.screens.length > 1
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    buttonRadius: 16
                    colBackground: "transparent"
                    StyledToolTip {
                        text: root.nextScreenName.length > 0
                            ? Translation.tr("Move to %1").arg(root.nextScreenName)
                            : Translation.tr("Move to next monitor")
                    }
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "desktop_windows"
                        iconSize: 18
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                    onClicked: root.switchScreenRequested()
                }

                RippleButton {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    buttonRadius: 16
                    colBackground: "transparent"
                    StyledToolTip { text: root.maximized ? Translation.tr("Restore Window") : Translation.tr("Maximize Window") }
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: root.maximized ? "fullscreen_exit" : "fullscreen"
                        iconSize: 18
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                    onClicked: root.maximized = !root.maximized
                }

                RippleButton {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    buttonRadius: 16
                    colBackground: "transparent"
                    StyledToolTip { text: Translation.tr("Close (Esc)") }
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "close"
                        iconSize: 18
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                    onClicked: root.closeRequested()
                }
            }
        }

        // Main Drawing Area with Floating Toolbar
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            WhiteboardCanvas {
                id: canvasItem
                anchors.fill: parent
                doc: docItem
            }

            // Floating Toolbar centered at bottom
            WhiteboardToolbar {
                id: toolbarItem
                canvas: canvasItem
                doc: docItem
                anchors {
                    bottom: parent.bottom
                    bottomMargin: 16
                    horizontalCenter: parent.horizontalCenter
                }
                z: 20
                onSaveRequested: root.saveBoardAs()
                onOpenRequested: root.openBoard()
                onExportRequested: root.exportImage()
            }
        }
    }
}
