pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

/*
 * Fullscreen viewer for the custom background video widget.
 * Opened by clicking the widget (or its expand button) when a video is set.
 * Esc / click outside controls closes; drag & drop replaces the video.
 */
Scope {
    id: root

    readonly property var videoConfig: Config.options.background.widgets.customVideo

    property string focusedScreenName: WM.compositor === "niri"
        ? (NiriBackend.focusedMonitor?.name ?? "")
        : (Hyprland.focusedMonitor?.name ?? "")

    property var focusedScreen: Quickshell.screens.find(s => s.name === root.focusedScreenName)
        ?? Quickshell.screens[0]

    function close() {
        GlobalStates.customVideoFullscreenOpen = false
        // Reset target index so a stale value can't point at a removed entry
        GlobalStates.customVideoFullscreenIndex = -1
    }

    function setVideoPath(path) {
        root.updateActiveEntry("path", path)
    }

    // ── Per-instance resolution ──
    // When opened from a videos[] instance (index >= 0) the viewer reads/writes
    // that array entry; otherwise it falls back to the legacy singleton fields.
    readonly property var activeEntry: {
        const idx = GlobalStates.customVideoFullscreenIndex
        const vids = Config.options.background.widgets.customVideo.videos
        return (idx >= 0 && idx < vids.length) ? vids[idx] : null
    }
    readonly property string resolvedPath: root.activeEntry
        ? (root.activeEntry.path ?? "")
        : (Config.options.background.widgets.customVideo.path ?? "")
    readonly property bool resolvedMuted: root.activeEntry
        ? (root.activeEntry.muted ?? true)
        : (Config.options.background.widgets.customVideo.muted ?? true)
    readonly property bool resolvedLoop: root.activeEntry
        ? (root.activeEntry.loop ?? true)
        : (Config.options.background.widgets.customVideo.loop ?? true)

    // Rebuild+reassign write for the active entry (list<var> persistence idiom)
    function updateActiveEntry(key, value) {
        const idx = GlobalStates.customVideoFullscreenIndex
        const vids = Config.options.background.widgets.customVideo.videos
        if (idx >= 0 && idx < vids.length) {
            let list = []
            for (let i = 0; i < vids.length; i++) {
                const o = vids[i]
                list.push({
                    path: o.path ?? "",
                    shape: o.shape ?? "Cookie4Sided",
                    size: o.size ?? 200,
                    x: o.x ?? 400,
                    y: o.y ??100,
                    autoplay: o.autoplay ?? true,
                    loop: o.loop ?? true,
                    muted: o.muted ?? true,
                    playWhenCharging: o.playWhenCharging ?? true,
                    playWhenOnBattery: o.playWhenOnBattery ?? true
                })
            }
            list[idx][key] = value
            Config.options.background.widgets.customVideo.videos = list
        } else {
            Config.options.background.widgets.customVideo[key] = value
        }
    }

    // ── File picker (same mechanism as widget / settings) ──
    Process {
        id: videoPickerProc
        command: ["python3", Quickshell.shellPath("scripts/images/pick-video.py")]
        stdout: SplitParser {
            onRead: data => {
                if (data.trim().length > 0)
                    root.setVideoPath(data.trim())
            }
        }
    }

    Loader {
        id: viewerLoader
        active: GlobalStates.customVideoFullscreenOpen && root.resolvedPath !== ""

        sourceComponent: PanelWindow {
            id: viewerWindow
            screen: root.focusedScreen
            visible: viewerLoader.active

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:fullscreenvideo"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "#000000"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            implicitWidth: screen?.width ?? 0
            implicitHeight: screen?.height ?? 0

            // ── Playback engine (independent instance from the widget) ──
            AudioOutput {
                id: fsAudio
                muted: root.resolvedMuted
                volume:1.0
            }

            MediaPlayer {
                id: fsPlayer
                source: root.resolvedPath !== "" ? "file://" + root.resolvedPath : ""
                videoOutput: fsVideoOut
                audioOutput: fsAudio
                loops: root.resolvedLoop ? MediaPlayer.Infinite : 1
                autoPlay: true
            }

            // ── Keyboard: Esc closes, Space toggles play/pause ──
            Item {
                id: keyHandler
                anchors.fill: parent
                focus: viewerWindow.visible

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) {
                        root.close()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Space) {
                        if (fsPlayer.playbackState === MediaPlayer.PlayingState)
                            fsPlayer.pause()
                        else
                            fsPlayer.play()
                        event.accepted = true
                    }
                }

                VideoOutput {
                    id: fsVideoOut
                    anchors.fill: parent
                    fillMode: VideoOutput.PreserveAspectFit
                }

                // ── Close on click anywhere outside the controls bar ──
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.close()
                }

                // ── Drag & drop to replace the video ──
                DropArea {
                    anchors.fill: parent
                    keys: ["text/uri-list"]
                    onDropped: (drop) => {
                        if (drop.hasUrls && drop.urls.length > 0) {
                            var cleanPath = decodeURIComponent(drop.urls[0].toString()).replace(/^file:\/\//, "")
                            var ext = cleanPath.split(".").pop().toLowerCase()
                            var accepted = ["mp4", "webm", "mkv", "mov", "avi", "m4v", "ogv"]
                            if (accepted.indexOf(ext) !== -1) {
                                root.setVideoPath(cleanPath)
                                fsPlayer.play()
                            }
                        }
                    }
                }

                // ── Controls bar (bottom center, auto-hides) ──
                Rectangle {
                    id: controlsBar
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        bottom: parent.bottom
                        bottomMargin:24
                    }
                    z: 3
                    width: controlsRow.implicitWidth + 16
                    height: controlsRow.implicitHeight + 12
                    radius: height / 2
                    color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.2)
                    opacity: controlsHideTimer.running ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    RowLayout {
                        id: controlsRow
                        anchors.centerIn: parent
                        spacing: 8

                        component ViewerButton: RippleButton {
                            id: viewerBtn
                            required property string symbol
                            Layout.preferredWidth: 40
                            Layout.preferredHeight:40
                            buttonRadius: width / 2
                            colBackground: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.35)
                            colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.15)
                            colRipple: ColorUtils.transparentize(Appearance.colors.colPrimary,0.5)
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                                text: viewerBtn.symbol
                                iconSize: 22
                                color: Appearance.colors.colOnLayer0
                            }
                        }

                        ViewerButton {
                            symbol: fsPlayer.playbackState === MediaPlayer.PlayingState ? "pause" : "play_arrow"
                            onClicked: {
                                if (fsPlayer.playbackState === MediaPlayer.PlayingState)
                                    fsPlayer.pause()
                                else
                                    fsPlayer.play()
                                controlsHideTimer.restart()
                            }
                        }
                        ViewerButton {
                            symbol: "replay"
                            onClicked: {
                                fsPlayer.position = 0
                                fsPlayer.play()
                                controlsHideTimer.restart()
                            }
                        }
                        ViewerButton {
                            symbol: root.resolvedMuted ? "volume_off" : "volume_up"
                            onClicked: {
                                root.updateActiveEntry("muted", !root.resolvedMuted)
                                controlsHideTimer.restart()
                            }
                        }
                        ViewerButton {
                            symbol: "video_library"
                            onClicked: {
                                videoPickerProc.running = true
                                controlsHideTimer.restart()
                            }
                        }
                        ViewerButton {
                            symbol: "close"
                            onClicked: root.close()
                        }
                    }
                }

                // ── Mouse tracking: show controls on move, auto-hide after 2.5s ──
                MouseArea {
                    id: hoverTracker
                    anchors.fill: parent
                    hoverEnabled: true
                    z: -1
                    acceptedButtons: Qt.NoButton
                    onMouseXChanged: controlsHideTimer.restart()
                    onMouseYChanged: controlsHideTimer.restart()
                }

                Timer {
                    id: controlsHideTimer
                    interval: 2500
                    running: true
                }
            }
        }
    }
}
