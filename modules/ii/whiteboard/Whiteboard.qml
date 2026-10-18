import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions as CF

Scope {
    id: root

    Component.onCompleted: {
        GlobalStates.whiteboardOpen = false;
    }

    property var focusedScreen: Quickshell.screens.find(s => s.name === (Hyprland.focusedMonitor?.name ?? ""))
        ?? Quickshell.screens[0]
    property var activeScreen: focusedScreen

    Connections {
        target: GlobalStates
        function onWhiteboardOpenChanged() {
            if (GlobalStates.whiteboardOpen) {
                root.activeScreen = root.focusedScreen;
            }
        }
    }

    // Persistent in-memory document preserved across window toggles & workspace/screen changes
    WhiteboardDocument {
        id: sharedDoc
        onDocumentChanged: {
            autoSaveTimer.restart();
        }
    }

    // Auto-save active document at Scope root level
    Timer {
        id: autoSaveTimer
        interval: 600
        repeat: false
        onTriggered: {
            const json = sharedDoc.toJSON();
            activeFile.setText(json);
            sharedDoc.isDirty = false;
        }
    }

    FileView {
        id: activeFile
        path: `${Directories.state}/user/whiteboard/active.json`
        watchChanges: true
        onFileChanged: activeFile.reload()
        onLoaded: {
            const content = activeFile.text();
            if (content && content.trim().length > 0) {
                if (sharedDoc.objectCount === 0) {
                    sharedDoc.fromJSON(content);
                }
            }
        }
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                autoSaveTimer.restart();
            } else {
                console.log("[Whiteboard] Error loading active file: " + error);
            }
        }
    }

    Loader {
        id: windowLoader
        active: GlobalStates.whiteboardOpen

        sourceComponent: PanelWindow {
            id: panelWindow
            screen: root.activeScreen
            visible: true

            function hide() {
                GlobalStates.whiteboardOpen = false;
            }

            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:whiteboard"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            color: "transparent"

            mask: Region {
                item: whiteboardWindow
            }

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // Window Container
            Rectangle {
                id: whiteboardWindow
                width: whiteboardContent.isMaximized
                    ? Math.max(300, parent.width - 24)
                    : Math.min(Math.max(600, parent.width - 64), 1160)
                height: whiteboardContent.isMaximized
                    ? Math.max(200, parent.height - 24)
                    : Math.min(Math.max(400, parent.height - 64), 780)
                color: Appearance.colors.colUiBackground
                border.width: 1
                border.color: CF.ColorUtils.transparentize(Appearance.colors.colLayer0Border, 0.4)
                radius: Appearance.rounding.windowRounding
                clip: true
                z: 1

                property bool userMoved: false
                anchors.centerIn: userMoved ? undefined : parent

                Connections {
                    target: whiteboardContent
                    function onIsMaximizedChanged() {
                        if (whiteboardContent.isMaximized) {
                            whiteboardWindow.userMoved = false;
                        }
                    }
                }

                // Titlebar Drag Handle
                MouseArea {
                    id: dragHandle
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.rightMargin: 120
                    height: 44
                    z: 5
                    cursorShape: Qt.SizeAllCursor
                    drag.target: whiteboardWindow
                    drag.axis: Drag.XAndYAxis
                    onPressed: {
                        if (!whiteboardWindow.userMoved) {
                            const curX = whiteboardWindow.x;
                            const curY = whiteboardWindow.y;
                            whiteboardWindow.userMoved = true;
                            whiteboardWindow.x = curX;
                            whiteboardWindow.y = curY;
                        }
                    }
                    onDoubleClicked: whiteboardContent.isMaximized = !whiteboardContent.isMaximized
                }

                WhiteboardContent {
                    id: whiteboardContent
                    anchors.fill: parent
                    doc: sharedDoc
                    onCloseRequested: panelWindow.hide()
                }
            }
        }
    }

    IpcHandler {
        target: "whiteboard"
        function toggle(): void { GlobalStates.whiteboardOpen = !GlobalStates.whiteboardOpen; }
        function open(): void   { GlobalStates.whiteboardOpen = true; }
        function close(): void  { GlobalStates.whiteboardOpen = false; }
    }

    CompositorGlobalShortcut {
        name: "whiteboardToggle"
        description: "Toggles interactive whiteboard"
        onPressed: GlobalStates.whiteboardOpen = !GlobalStates.whiteboardOpen;
    }
}
