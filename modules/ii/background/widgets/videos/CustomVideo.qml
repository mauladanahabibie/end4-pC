pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import QtMultimedia
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "customVideo"
    hoverEnabled: true

    property int videoIndex: -1

    readonly property var videoConfig: {
        if (videoIndex >= 0) {
            const vids = Config.options.background.widgets.customVideo.videos
            if (vids.length > videoIndex)
                return vids[videoIndex]
        }
        return Config.options.background.widgets.customVideo
    }

    property string videoPath: videoConfig.path ?? ""
    property bool videoValid: videoPath !== ""
    property bool playIntent: videoConfig.autoplay ?? true
    property bool dropHover:false
    property real widgetSize: videoConfig.size ??200
    property bool resizing: false

    Behavior on widgetSize {
        enabled: !root.resizing
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }

    implicitWidth: contentItem.implicitWidth
    implicitHeight: contentItem.implicitHeight

    targetX: {
        const ix = root.videoConfig.x ??400
        return Math.max(0, Math.min(ix, scaledScreenWidth - width))
    }
    targetY: {
        const iy = root.videoConfig.y ?? 100
        return Math.max(0, Math.min(iy, scaledScreenHeight - height))
    }

    readonly property bool powerAllowsPlay: {
        if (!Battery.available)
            return true
        return Battery.isPluggedIn
            ? (root.videoConfig.playWhenCharging ?? true)
            : (root.videoConfig.playWhenOnBattery ?? true)
    }
    readonly property bool effectivePlay: root.playIntent && root.powerAllowsPlay && root.videoValid && root.videoPath !== ""

    // Picker process: captures stdout from zenity/kdialog script.
    // Uses scripts/images/pick-video.py (plain path output, not JSON).
    Process {
        id: videoPickerProc
        stdout: SplitParser {
            onRead: data => {
                var path = data.trim()
                if (path.length > 0) {
                    root.setVideoPath(path)
                }
            }
        }
    }

    // Click handler. Left-click opens picker (empty) or fullscreen (loaded).
    // Right-click toggles widgetsLocked (preserved from AbstractWidget).
    onClicked: (mouse) => {
        if (mouse.button === Qt.RightButton) {
            Config.options.background.widgetsLocked = !Config.options.background.widgetsLocked
            return
        }
        if (mouse.button !== Qt.LeftButton) return
        if (root.videoPath === "" || !root.videoValid) {
            videoPickerProc.command = ["python3", `${Directories.scriptPath}/images/pick-video.py`]
            videoPickerProc.running = true
        } else {
            GlobalStates.customVideoFullscreenIndex = root.videoIndex
            GlobalStates.customVideoFullscreenOpen = true
        }
    }

    function getShape(name) {
        switch (name) {
            case "Circle":        return MaterialShape.Shape.Circle
            case "Square":        return MaterialShape.Shape.Square
            case "Slanted":       return MaterialShape.Shape.Slanted
            case "Arch":          return MaterialShape.Shape.Arch
            case "Fan":           return MaterialShape.Shape.Fan
            case "Arrow":         return MaterialShape.Shape.Arrow
            case "SemiCircle":    return MaterialShape.Shape.SemiCircle
            case "Oval":          return MaterialShape.Shape.Oval
            case "Pill":          return MaterialShape.Shape.Pill
            case "Triangle":      return MaterialShape.Shape.Triangle
            default:              return MaterialShape.Shape.Cookie4Sided
        }
    }

    AudioOutput {
        id: audioOut
        muted: root.videoConfig.muted ?? true
        volume: 1.0
    }

    MediaPlayer {
        id: player
        source: root.videoPath !== "" ? "file://" + root.videoPath : ""
        videoOutput: videoOut
        audioOutput: audioOut
        loops: (root.videoConfig.loop ?? true) ? MediaPlayer.Infinite : 1
        autoPlay: false

        onMediaStatusChanged: root.syncPlayback()
        onErrorOccurred: (error, errorString) => {
            if (error !== MediaPlayer.NoError) {
                console.warn("[CustomVideo] media error:", error, errorString)
                root.videoValid = false
            }
        }
    }

    Component.onDestruction: player.stop()

    function syncPlayback() {
        if (player.source === "" || player.source === undefined) return
        const ms = player.mediaStatus
        const ready = ms > MediaPlayer.NoMedia && ms < MediaPlayer.EndOfMedia
        if (root.effectivePlay && ready) {
            if (player.playbackState !== MediaPlayer.PlayingState)
                player.play()
        } else {
            if (player.playbackState === MediaPlayer.PlayingState)
                player.pause()
        }
    }

    onEffectivePlayChanged: root.syncPlayback()

    onVideoPathChanged: {
        root.videoValid = root.videoPath !== ""
        root.playIntent = root.videoConfig.autoplay ?? true
    }

    Item {
        id: contentItem
        implicitWidth: root.widgetSize
        implicitHeight: root.widgetSize

        Behavior on implicitWidth {
            enabled: !root.resizing
            animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
        }
        Behavior on implicitHeight {
            enabled: !root.resizing
            animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
        }

        // No outer MouseArea - let AbstractBackgroundWidget handle dragging
        // All controls have their own MouseAreas with hoverEnabled and proper acceptedButtons

        MaterialShape {
            id: shadowShape
            anchors.fill: parent
            color: Appearance.colors.colPrimaryContainer
            shape: root.getShape(root.videoConfig.shape ?? "Cookie4Sided")
            visible:false
        }

        StyledDropShadow {
            target: shadowShape
            z: -1
        }

        MaterialShape {
            id: videoShape
            anchors.fill: parent
            z: 0
            color: Appearance.colors.colPrimaryContainer
            shape: root.getShape(root.videoConfig.shape ?? "Cookie4Sided")

            VideoOutput {
                id: videoOut
                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectCrop
                visible: false
                layer.enabled: root.videoPath !== "" && root.videoValid
            }

            MaterialShape {
                id: videoMaskShape
                anchors.fill: parent
                shape: videoShape.shape
                color: "white"
                visible: false
                layer.enabled: root.videoPath !== "" && root.videoValid
            }

            MaskMultiEffect {
                anchors.fill: parent
                source: videoOut
                maskSource: videoMaskShape
                autoPaddingEnabled: false
                visible: root.videoPath !== "" && root.videoValid
            }

            MaterialSymbol {
                anchors.centerIn: parent
                iconSize: contentItem.implicitWidth / 3
                text: root.dropHover ? "download" : "movie"
                fill: root.dropHover ? 1 : 0
                color: root.dropHover ? Appearance.colors.colPrimary : Appearance.colors.colOnPrimaryContainer
                visible: root.videoPath === "" || !root.videoValid
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
                        var accepted = ["mp4","webm","mkv","avi","mov","m4v","ogv"]
                        if (accepted.indexOf(ext) !== -1) {
                            root.setVideoPath(cleanPath)
                        }
                    }
                    root.dropHover = false
                }
            }
        }

        Rectangle {
            id: controlsBar
            anchors {
                horizontalCenter: videoShape.horizontalCenter
                bottom: videoShape.bottom
                bottomMargin: Math.max(8, contentItem.implicitWidth *0.06)
            }
            z: 3
            width: controlsRow.implicitWidth + 12
            height: controlsRow.implicitHeight + 8
            radius: height / 2
            color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.25)
            opacity: (root.containsMouse && root.videoPath !== "" && root.videoValid) ? 1 :0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration:150 } }

            RowLayout {
                id: controlsRow
                anchors.centerIn: parent
                spacing: 8

                component ControlButton: RippleButton {
                    id: ctrlBtn
                    required property string symbol
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    buttonRadius: width / 2
                    colBackground: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.35)
                    colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.15)
                    colRipple: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.5)
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: ctrlBtn.symbol
                        iconSize: 16
                        color: Appearance.colors.colOnLayer0
                    }
                }

                ControlButton {
                    symbol: player.playbackState === MediaPlayer.PlayingState ? "pause" : "play_arrow"
                    onClicked: {
                        root.playIntent = player.playbackState !== MediaPlayer.PlayingState
                        root.syncPlayback()
                    }
                }
                ControlButton {
                    symbol: "replay"
                    onClicked: {
                        player.position = 0
                        root.playIntent = true
                        root.syncPlayback()
                    }
                }
                ControlButton {
                    symbol: (root.videoConfig.muted ?? true) ? "volume_off" : "volume_up"
                    onClicked: {
                        root.setVideoMuted(!(root.videoConfig.muted ?? true))
                    }
                }
                ControlButton {
                    symbol: "open_in_full"
                    onClicked: {
                        GlobalStates.customVideoFullscreenIndex = root.videoIndex
                        GlobalStates.customVideoFullscreenOpen = true
                    }
                }
            }
        }

        Rectangle {
            id: resizeHandle
            width: 16
            height: 16
            radius: 4
            color: Appearance.colors.colOnPrimaryContainer
            anchors {
                right: videoShape.right
                bottom: videoShape.bottom
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
                hoverEnabled:true
                cursorShape: Qt.SizeFDiagCursor

                property real startSize: 0
                property real startX: 0
                property real startY: 0

                onPressed: (mouse) => {
                    root.resizing = true
                    root.draggable = false
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
                    root.resizing =false
                    root.draggable = root.placementStrategy === "free" && !Config.options.background.widgetsLocked
                    root.setVideoSize(root.widgetSize)
                }
            }
        }

        Rectangle {
            id: deleteHandle
            width:22
            height: 22
            radius: width / 2
            color: Appearance.m3colors.m3error
            anchors {
                top: videoShape.top
                right: videoShape.right
                margins: 6
            }
            opacity: (root.containsMouse || deleteArea.containsMouse) ? 0.9 : 0
            visible: opacity > 0 && (root.videoIndex >= 0 || root.videoPath !== "")
            z: 4

            Behavior on opacity {
                NumberAnimation { duration: 150 }
            }

            MouseArea {
                id: deleteArea
                anchors.fill: parent
                hoverEnabled:true
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    if (root.videoIndex >= 0) {
                        root.deleteThisVideo()
                    } else {
                        root.setVideoPath("")
                    }
                }
            }

            MaterialSymbol {
                anchors.centerIn: parent
                text: "close"
                iconSize:14
                color: Appearance.colors.colOnError
            }
        }
    }

    function setVideoPath(path) {
        if (path !== "") {
            root.videoValid = true
        }

        if (root.videoIndex >= 0) {
            root.updateArrayVideo(root.videoIndex, "path", path)
        } else {
            Config.options.background.widgets.customVideo.path = path
        }
    }

    function setVideoSize(size) {
        if (root.videoIndex >= 0) {
            root.updateArrayVideo(root.videoIndex, "size", size)
        } else {
            Config.options.background.widgets.customVideo.size = size
        }
    }

    function setVideoMuted(muted) {
        if (root.videoIndex >= 0) {
            root.updateArrayVideo(root.videoIndex, "muted", muted)
        } else {
            Config.options.background.widgets.customVideo.muted = muted
        }
    }

    function deleteThisVideo() {
        if (root.videoIndex < 0) return
        let list = []
        const vids = Config.options.background.widgets.customVideo.videos
        for (let i = 0; i < vids.length; i++) {
            if (i === root.videoIndex) continue
            let o = vids[i]
            list.push({
                path: o.path ?? "",
                shape: o.shape ?? "Cookie4Sided",
                size: o.size ?? 200,
                x: o.x ??400,
                y: o.y ?? 100,
                autoplay: o.autoplay ?? true,
                loop: o.loop ?? true,
                muted: o.muted ?? true,
                playWhenCharging: o.playWhenCharging ?? true,
                playWhenOnBattery: o.playWhenOnBattery ?? true,
            })
        }
        Config.options.background.widgets.customVideo.videos = list
    }

    function updateArrayVideo(idx, key, value) {
        let list = []
        const vids = Config.options.background.widgets.customVideo.videos
        for (let i = 0; i < vids.length; i++) {
            let o = vids[i]
            list.push({
                path: o.path ?? "",
                shape: o.shape ?? "Cookie4Sided",
                size: o.size ?? 200,
                x: o.x ?? 400,
                y: o.y ?? 100,
                autoplay: o.autoplay ?? true,
                loop: o.loop ??true,
                muted: o.muted ?? true,
                playWhenCharging: o.playWhenCharging ?? true,
                playWhenOnBattery: o.playWhenOnBattery ?? true,
            })
        }
        if (idx < list.length) {
            list[idx][key] = value
        }
        Config.options.background.widgets.customVideo.videos = list
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
        if (root.videoIndex >=0) {
            root.updateArrayVideo(root.videoIndex, "x", root.x)
            root.updateArrayVideo(root.videoIndex, "y", root.y)
        } else {
            configEntry.x = root.x
            configEntry.y = root.y
        }
        root.restoreXYBinding()
    }
}
