pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "customImage"
    hoverEnabled: true

    // Which image index this widget renders (-1 = legacy single image)
    property int imageIndex: -1

    // Resolve the image config: if imageIndex >= 0, use images array; else legacy single
    readonly property var imageConfig: {
        if (imageIndex >= 0 && Config.options.background.widgets.customImage.images.length > imageIndex) {
            return Config.options.background.widgets.customImage.images[imageIndex]
        }
        // Legacy single image mode
        return {
            path: Config.options.background.widgets.customImage.path ?? "",
            shape: Config.options.background.widgets.customImage.shape ?? "Cookie4Sided",
            size: Config.options.background.widgets.customImage.size ?? 200,
            x: Config.options.background.widgets.customImage.x ?? 400,
            y: Config.options.background.widgets.customImage.y ?? 100,
        }
    }

    property string imagePath: imageConfig.path ?? ""
    property bool dropHover: false
    property int shapeType: ShapeUtils.getShape(root.imageConfig.shape ?? "Cookie4Sided")
    property real widgetSize: imageConfig.size ?? 200
    property bool resizing: false

    // Animate size changes EXCEPT during active resize drag
    Behavior on widgetSize {
        enabled: !root.resizing
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }

    // Override position bindings from AbstractBackgroundWidget to use
    // per-image x/y instead of the shared configEntry.x/y
    targetX: {
        const ix = imageConfig.x ?? 400
        return Math.max(0, Math.min(ix, scaledScreenWidth - width))
    }
    targetY: {
        const iy = imageConfig.y ?? 100
        return Math.max(0, Math.min(iy, scaledScreenHeight - height))
    }

    implicitWidth: contentItem.implicitWidth
    implicitHeight: contentItem.implicitHeight

    visible: opacity > 0 && (root.imageIndex >= 0 || !Config.options.background.widgets.customImage.images || Config.options.background.widgets.customImage.images.length === 0)

    Process {
        id: imagePickerProc
        command: ["python3", `${Directories.scriptPath}/images/pick-image.py`]
        stdout: SplitParser {
            onRead: data => {
                var path = data.trim()
                if (path.length > 0) {
                    root.setImagePath(path)
                }
            }
        }
    }

    CustomImageContextMenu {
        id: contextMenu
        targetWidget: root
    }

    function openPicker() {
        imagePickerProc.command = ["python3", `${Directories.scriptPath}/images/pick-image.py`]
        imagePickerProc.running = true
    }

    // Click handler. Left-click opens picker (empty) or selects widget (loaded).
    // Right-click opens the context menu (Select/Change Image, Delete Image, Delete Widget, Lock).
    onClicked: (mouse) => {
        if (mouse.button === Qt.RightButton) {
            contextMenu.popup()
            return
        }
        if (mouse.button !== Qt.LeftButton) return
        if (root.imagePath === "") {
            root.openPicker()
        } else {
            var canvas = findCanvas(root.parent)
            if (canvas) canvas.clearSelection()
            root.selected = true
        }
    }

    Item {
        id: contentItem
        implicitWidth: root.widgetSize
        implicitHeight: root.widgetSize

        // Disable resize animation during active resize drag — real-time follow
        Behavior on implicitWidth {
            enabled: !root.resizing
            animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
        }
        Behavior on implicitHeight {
            enabled: !root.resizing
            animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
        }

        MaterialShape {
            id: shadowShape
            anchors.fill: parent
            color: Appearance.colors.colPrimaryContainer
            shape: root.shapeType
            visible: false
        }

        StyledDropShadow {
            target: shadowShape
            z: -1
            visible: Config.options.background.widgets.shadow
        }

        MaterialShape {
            id: imageShape
            anchors.fill: parent
            z: 0
            color: Appearance.colors.colPrimaryContainer
            shape: root.shapeType

            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: MaterialShape {
                    width: imageShape.width
                    height: imageShape.height
                    shape: root.shapeType
                }
            }

            StyledImage {
                anchors.fill: parent
                source: {
                    if (root.imagePath === "") return ""
                    if (root.imagePath.startsWith("file://") || root.imagePath.startsWith("http://") || root.imagePath.startsWith("https://")) {
                        return root.imagePath
                    }
                    return "file://" + root.imagePath
                }
                fillMode: Image.PreserveAspectCrop
                cache: false
                antialiasing: true
                sourceSize.width: parent.width
                sourceSize.height: parent.height
                visible: root.imagePath !== ""
            }

            // Placeholder + hover hint
            MaterialSymbol {
                anchors.centerIn: parent
                iconSize: contentItem.implicitWidth / 3
                text: root.dropHover ? "download" : "image"
                fill: root.dropHover ? 1 : 0
                color: root.dropHover
                    ? Appearance.colors.colPrimary
                    : Appearance.colors.colOnPrimaryContainer
                visible: root.imagePath === ""
                Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
            }

            DropArea {
                anchors.fill: parent
                keys: ["text/uri-list"]
                onEntered: (drag) => {
                    drag.accept(Qt.CopyAction)
                    root.dropHover = true
                }
                onExited: {
                    root.dropHover = false
                }
                onDropped: (drop) => {
                    if (drop.hasUrls && drop.urls.length > 0) {
                        var cleanPath = drop.urls[0].toString().replace(/^file:\/\//, "")
                        var ext = cleanPath.split(".").pop().toLowerCase()
                        var accepted = ["png","jpg","jpeg","webp","avif","bmp","gif","tiff","tif"]
                        if (accepted.indexOf(ext) !== -1) {
                            root.setImagePath(cleanPath)
                        }
                    }
                    root.dropHover = false
                }
            }
        }

        // Resize handle (bottom-right corner)
        Rectangle {
            id: resizeHandle
            width: 16
            height: 16
            radius: 4
            color: Appearance.colors.colOnPrimaryContainer
            anchors {
                right: imageShape.right
                bottom: imageShape.bottom
                margins: 6
            }
            opacity: (root.containsMouse || resizeArea.containsMouse || resizeArea.pressed) ? 0.5 : 0
            visible: opacity > 0 && !Config.options.background.widgetsLocked
            z: 2

            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }

            MouseArea {
                id: resizeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.SizeFDiagCursor

                property real startSize: 0
                property real startX: 0
                property real startY: 0

                onPressed: (mouse) => {
                    root.resizing = true
                    startSize = root.widgetSize
                    var globalPos = mapToItem(null, mouse.x, mouse.y)
                    startX = globalPos.x
                    startY = globalPos.y
                }
                onPositionChanged: (mouse) => {
                    if (!pressed) return
                    var globalPos = mapToItem(null, mouse.x, mouse.y)
                    var delta = Math.max(globalPos.x - startX, globalPos.y - startY)
                    root.widgetSize = Math.max(80, startSize + delta)
                }
                onReleased: {
                    root.resizing = false
                    root.setImageSize(root.widgetSize)
                }
            }
        }

        // Delete button (top-right corner)
        Rectangle {
            id: deleteHandle
            width: 22
            height: 22
            radius: width / 2
            color: Appearance.m3colors.m3error
            anchors {
                top: imageShape.top
                right: imageShape.right
                margins: 6
            }
            opacity: (root.containsMouse || deleteArea.containsMouse) ? 0.9 : 0
            visible: opacity > 0 && !Config.options.background.widgetsLocked && (root.imageIndex >= 0 || root.imagePath !== "")
            z: 2

            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }

            MouseArea {
                id: deleteArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    root.requestDelete()
                }
            }

            MaterialSymbol {
                anchors.centerIn: parent
                text: "close"
                iconSize: 14
                color: Appearance.colors.colOnError
            }
        }
    }

    // ── Helpers: update config ──
    function setImagePath(path) {
        if (root.imageIndex >= 0) {
            root.updateArrayImage(root.imageIndex, "path", path)
        } else {
            Config.options.background.widgets.customImage.path = path
        }
    }

    function setImageSize(size) {
        if (root.imageIndex >= 0) {
            root.updateArrayImage(root.imageIndex, "size", size)
        } else {
            Config.options.background.widgets.customImage.size = size
        }
    }

    function deleteImageMedia() {
        root.setImagePath("")
    }

    function requestDelete() {
        if (root.imageIndex >= 0) {
            root.deleteThisImage()
        } else {
            Config.options.background.widgets.customImage.enable = false
        }
    }

    function deleteThisImage() {
        if (root.imageIndex < 0) return
        let list = []
        const imgs = Config.options.background.widgets.customImage.images
        for (let i = 0; i < imgs.length; i++) {
            if (i === root.imageIndex) continue
            let o = imgs[i]
            list.push({
                path: o.path ?? "",
                shape: o.shape ?? "Cookie4Sided",
                size: o.size ?? 200,
                x: o.x ?? 400,
                y: o.y ?? 100,
            })
        }
        Config.options.background.widgets.customImage.images = list
        if (list.length === 0) {
            Config.options.background.widgets.customImage.enable = false
        }
    }

    function updateArrayImage(idx, key, value) {
        let list = []
        const imgs = Config.options.background.widgets.customImage.images
        for (let i = 0; i < imgs.length; i++) {
            let o = imgs[i]
            list.push({
                path: o.path ?? "",
                shape: o.shape ?? "Cookie4Sided",
                size: o.size ?? 200,
                x: o.x ?? 400,
                y: o.y ?? 100,
            })
        }
        if (idx < list.length) {
            list[idx][key] = value
        }
        Config.options.background.widgets.customImage.images = list
    }

    function updateArrayImagePosition(idx, newX, newY) {
        let list = []
        const imgs = Config.options.background.widgets.customImage.images
        for (let i = 0; i < imgs.length; i++) {
            let o = imgs[i]
            list.push({
                path: o.path ?? "",
                shape: o.shape ?? "Cookie4Sided",
                size: o.size ?? 200,
                x: i === idx ? newX : (o.x ?? 400),
                y: i === idx ? newY : (o.y ?? 100),
            })
        }
        Config.options.background.widgets.customImage.images = list
    }

    function commitPosition() {
        if (root.imageIndex >= 0) {
            root.updateArrayImagePosition(root.imageIndex, root.x, root.y)
        } else {
            configEntry.x = root.x
            configEntry.y = root.y
            root.targetX = Qt.binding(() => Math.max(0, Math.min(configEntry.x, scaledScreenWidth - width)))
            root.targetY = Qt.binding(() => Math.max(0, Math.min(configEntry.y, scaledScreenHeight - height)))
            root.restoreXYBinding()
        }
    }

    onReleased: {
        var p = root.parent
        while (p) {
            if (p.isWidgetCanvas === true) {
                p.setDragging(false)
                break
            }
            p = p.parent
        }
        root.commitPosition()
    }
}
