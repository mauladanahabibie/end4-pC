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

    property var focusedScreen: Quickshell.screens.find(s => s.name === (WM.focusedMonitor?.name ?? Hyprland.focusedMonitor?.name ?? ""))
        ?? Quickshell.screens[0]
    property var activeScreen: focusedScreen

    property int savedWindowX: -1
    property int savedWindowY: -1
    property bool preservePositionOnSwitch: false

    function getNextScreen() {
        const screens = Quickshell.screens;
        if (!screens || screens.length <= 1) return null;
        const curName = root.activeScreen?.name ?? "";
        let curIdx = -1;
        for (let i = 0; i < screens.length; i++) {
            if (screens[i] && screens[i].name === curName) {
                curIdx = i;
                break;
            }
        }
        if (curIdx === -1) curIdx = 0;
        const nextIdx = (curIdx + 1) % screens.length;
        return screens[nextIdx];
    }

    function switchScreen(targetScreen, relX, relY) {
        if (!targetScreen) return;
        if (root.activeScreen && targetScreen.name === root.activeScreen.name) return;

        if (relX !== undefined && relY !== undefined) {
            root.savedWindowX = relX;
            root.savedWindowY = relY;
            root.preservePositionOnSwitch = true;
        } else {
            root.preservePositionOnSwitch = false;
        }

        // Step 1: Deactivate loader to cleanly unmap old layer surface from Wayland
        windowLoader.active = false;
        root.activeScreen = targetScreen;
        GlobalStates.whiteboardScreen = targetScreen;

        // Step 2: Reactivate on target screen on next event loop tick
        Qt.callLater(() => {
            windowLoader.active = true;
        });
    }

    function checkWindowMonitorDrop(winX, winY, winWidth, winHeight) {
        const currentScreen = root.activeScreen;
        if (!currentScreen) return;

        const curScreenX = currentScreen.x ?? 0;
        const curScreenY = currentScreen.y ?? 0;
        const curScreenW = currentScreen.width ?? 1920;
        const curScreenH = currentScreen.height ?? 1080;

        const globalX = curScreenX + winX + (winWidth / 2);
        const globalY = curScreenY + winY + 22; // titlebar center

        const screens = Quickshell.screens;
        let targetScreen = null;
        for (let i = 0; i < screens.length; i++) {
            const s = screens[i];
            if (!s) continue;
            const sx = s.x ?? 0;
            const sy = s.y ?? 0;
            const sw = s.width ?? 1920;
            const sh = s.height ?? 1080;
            if (globalX >= sx && globalX < sx + sw && globalY >= sy && globalY < sy + sh) {
                targetScreen = s;
                break;
            }
        }

        // Fallback boundary detection if window dragged past screen edges
        if (!targetScreen && screens.length > 1) {
            for (let i = 0; i < screens.length; i++) {
                const s = screens[i];
                if (!s || s.name === currentScreen.name) continue;
                targetScreen = s;
                break;
            }
        }

        if (targetScreen && targetScreen.name !== currentScreen.name) {
            const targetX = targetScreen.x ?? 0;
            const targetY = targetScreen.y ?? 0;
            const targetW = targetScreen.width ?? 1920;
            const targetH = targetScreen.height ?? 1080;

            let targetRelX = globalX - targetX - (winWidth / 2);
            let targetRelY = globalY - targetY - 22;

            targetRelX = Math.max(12, Math.min(targetW - winWidth - 12, targetRelX));
            targetRelY = Math.max(12, Math.min(targetH - winHeight - 12, targetRelY));

            root.switchScreen(targetScreen, targetRelX, targetRelY);
        } else {
            // Stayed on same screen: clamp within visible area so window cannot be lost
            if (windowLoader.item && windowLoader.item.whiteboardWindowRef) {
                const win = windowLoader.item.whiteboardWindowRef;
                win.x = Math.max(12, Math.min(curScreenW - winWidth - 12, win.x));
                win.y = Math.max(12, Math.min(curScreenH - winHeight - 12, win.y));
            }
        }
    }

    Connections {
        target: GlobalStates
        function onWhiteboardOpenChanged() {
            if (GlobalStates.whiteboardOpen) {
                const target = GlobalStates.whiteboardScreen ?? root.focusedScreen;
                root.activeScreen = target;
                GlobalStates.whiteboardScreen = target;
            }
        }
        function onWhiteboardScreenChanged() {
            if (GlobalStates.whiteboardOpen && GlobalStates.whiteboardScreen) {
                if (!root.activeScreen || root.activeScreen.name !== GlobalStates.whiteboardScreen.name) {
                    root.switchScreen(GlobalStates.whiteboardScreen);
                }
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

            readonly property var whiteboardWindowRef: whiteboardWindow

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

                property bool userMoved: root.preservePositionOnSwitch
                anchors.centerIn: userMoved ? undefined : parent

                Component.onCompleted: {
                    if (root.preservePositionOnSwitch) {
                        userMoved = true;
                        x = Math.max(12, Math.min(parent.width - width - 12, root.savedWindowX));
                        y = Math.max(12, Math.min(parent.height - height - 12, root.savedWindowY));
                        root.preservePositionOnSwitch = false;
                    }
                }

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
                    anchors.rightMargin: 190
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
                    onReleased: {
                        root.checkWindowMonitorDrop(whiteboardWindow.x, whiteboardWindow.y, whiteboardWindow.width, whiteboardWindow.height);
                    }
                    onDoubleClicked: whiteboardContent.isMaximized = !whiteboardContent.isMaximized
                }

                WhiteboardContent {
                    id: whiteboardContent
                    anchors.fill: parent
                    doc: sharedDoc
                    nextScreenName: root.getNextScreen()?.name ?? ""
                    onCloseRequested: panelWindow.hide()
                    onSwitchScreenRequested: {
                        const nextSc = root.getNextScreen();
                        if (nextSc) root.switchScreen(nextSc);
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "whiteboard"
        function toggle(): void {
            const focused = root.focusedScreen;
            GlobalStates.toggleWhiteboard(focused);
        }
        function open(): void {
            const focused = root.focusedScreen;
            GlobalStates.openWhiteboard(focused);
        }
        function close(): void {
            GlobalStates.whiteboardOpen = false;
        }
        function moveToScreen(screenName: string): void {
            const sc = Quickshell.screens.find(s => s.name === screenName);
            if (sc) root.switchScreen(sc);
        }
        function nextScreen(): void {
            const n = root.getNextScreen();
            if (n) root.switchScreen(n);
        }
    }

    CompositorGlobalShortcut {
        name: "whiteboardToggle"
        description: "Toggles interactive whiteboard"
        onPressed: {
            const focused = root.focusedScreen;
            GlobalStates.toggleWhiteboard(focused);
        }
    }
}
