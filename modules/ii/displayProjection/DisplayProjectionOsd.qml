import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

/**
 * Display Projection OSD — Windows + P style, Material Design 3.
 * Floating centered panel with 4 mode buttons, keyboard nav, auto-close.
 */
Scope {
    id: root

    // ── Global shortcut: Super+P cycling ──
    GlobalShortcut {
        name: "displayProjectionToggle"
        description: "Opens/cycles display projection OSD"

        onPressed: {
            const modes = ["primary", "secondary", "extend", "mirror"]
            if (!GlobalStates.displayProjectionOpen) {
                DisplayProjection.fetchMonitors()
                const idx = modes.indexOf(DisplayProjection.currentMode)
                GlobalStates.displayProjectionCycleIndex = idx >= 0 ? idx : 2
                GlobalStates.displayProjectionOpen = true
                // Prevent searchToggleRelease from opening overview on Super release
                GlobalStates.superReleaseMightTrigger = false
            } else {
                GlobalStates.displayProjectionCycleIndex = (GlobalStates.displayProjectionCycleIndex + 1) % modes.length
                // Keep preventing overview on each cycle
                GlobalStates.superReleaseMightTrigger = false
            }
        }
    }

    property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
    property var modeList: [
        { id: "primary",   label: "Primary Only",   icon: "laptop_windows" },
        { id: "secondary", label: "Secondary Only",  icon: "connected_tv" },
        { id: "extend",    label: "Extend",          icon: "horizontal_split" },
        { id: "mirror",    label: "Mirror",           icon: "desktop_portrait" },
    ]
    readonly property int selectedModeIndex: GlobalStates.displayProjectionCycleIndex

    // Sync cycle index to current mode (sets GlobalStates property, not local)
    function _syncSelectedMode() {
        const modes = ["primary", "secondary", "extend", "mirror"]
        const idx = modes.indexOf(DisplayProjection.currentMode)
        GlobalStates.displayProjectionCycleIndex = idx >= 0 ? idx : 2
    }

    function _applySelected() {
        const mode = modeList[root.selectedModeIndex].id
        DisplayProjection.applyMode(mode)
        GlobalStates.displayProjectionOpen = false
    }

    function _close() {
        GlobalStates.displayProjectionOpen = false
    }

    Loader {
        id: osdLoader
        active: GlobalStates.displayProjectionOpen

        sourceComponent: PanelWindow {
            id: osdRoot
            color: "transparent"

            WlrLayershell.namespace: "quickshell:displayProjection"
            WlrLayershell.layer: WlrLayer.Overlay

            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0

            implicitWidth: 340
            implicitHeight: osdContent.height

            visible: osdLoader.active

            // ── Auto-close timeout ──
            Timer {
                id: autoCloseTimer
                interval: 5000
                repeat: false
                running: true
                onTriggered: GlobalStates.displayProjectionOpen = false
            }

            // ── Restart timer on interaction ──
            Connections {
                target: root
                function onSelectedModeIndexChanged() { autoCloseTimer.restart() }
            }

            // ── Keyboard navigation ──
            Item {
                focus: true
                Keys.onPressed: (event) => {
                    autoCloseTimer.restart()
                    if (event.key === Qt.Key_Escape) {
                        root._close()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root._applySelected()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Up) {
                        GlobalStates.displayProjectionCycleIndex = (GlobalStates.displayProjectionCycleIndex - 1 + root.modeList.length) % root.modeList.length
                        event.accepted = true
                    } else if (event.key === Qt.Key_Down) {
                        GlobalStates.displayProjectionCycleIndex = (GlobalStates.displayProjectionCycleIndex + 1) % root.modeList.length
                        event.accepted = true
                    }
                }
                Component.onCompleted: forceActiveFocus()
            }

            // ── Animated container ──
            Rectangle {
                id: osdContent
                width: 340
                height: contentColumn.implicitHeight + 32
                x: (osdRoot.width - width) / 2
                y: (osdRoot.height - height) / 2
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer1

                // Entrance animation
                scale: osdLoader.active ? 1 : 0.85
                opacity: osdLoader.active ? 1 : 0

                Behavior on scale {
                    animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                }
                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }

                // Shadow
                StyledRectangularShadow {
                    target: osdContent
                }

                // ── Content ──
                ColumnLayout {
                    id: contentColumn
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        MaterialSymbol {
                            text: "desktop_windows"
                            iconSize: Appearance.font.pixelSize.large
                            color: Appearance.colors.colOnSurface
                        }

                        StyledText {
                            text: "Display Projection"
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnSurface
                            Layout.fillWidth: true
                        }

                        // Close button
                        RippleButton {
                            implicitWidth: 28
                            implicitHeight: 28
                            buttonRadius: height / 2
                            colBackground: "transparent"
                            colBackgroundHover: Appearance.colors.colSurfaceContainerHigh
                            onClicked: root._close()
                            contentItem: MaterialSymbol {
                                text: "close"
                                iconSize: Appearance.font.pixelSize.normal
                                color: Appearance.colors.colOnSurfaceVariant
                            }
                        }
                    }

                    // ── Current config ──
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: configRow.implicitHeight + 12
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colSurfaceContainerLow

                        RowLayout {
                            id: configRow
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 8

                            StyledText {
                                text: "Primary:"
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.colors.colOnSurfaceVariant
                            }
                            StyledText {
                                text: DisplayProjection.primaryMonitor || "—"
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.features: { "tnum": 1 }
                                color: Appearance.colors.colOnSurface
                            }
                            Item { Layout.fillWidth: true }
                            StyledText {
                                text: "External:"
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.colors.colOnSurfaceVariant
                            }
                            StyledText {
                                text: DisplayProjection.secondaryMonitor || "—"
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.features: { "tnum": 1 }
                                color: Appearance.colors.colOnSurface
                                visible: DisplayProjection.secondaryMonitor.length > 0
                            }
                            StyledText {
                                text: "None"
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.colors.colOnSurfaceVariant
                                visible: DisplayProjection.secondaryMonitor.length === 0
                            }
                        }
                    }

                    // ── Mode buttons ──
                    Repeater {
                        model: root.modeList
                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            implicitHeight: modeRow.implicitHeight + 16
                            radius: Appearance.rounding.small
                            color: index === root.selectedModeIndex
                                ? Appearance.colors.colPrimary
                                : Appearance.colors.colSurfaceContainerLow

                            Behavior on color {
                                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                            }

                            RowLayout {
                                id: modeRow
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 10

                                // Radio indicator
                                Item {
                                    Layout.alignment: Qt.AlignVCenter
                                    implicitWidth: 20
                                    implicitHeight: 20

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: index === root.selectedModeIndex ? 10 : 16
                                        height: width
                                        radius: width / 2
                                        color: index === root.selectedModeIndex
                                            ? Appearance.colors.colOnPrimary
                                            : "transparent"
                                        border.width: index === root.selectedModeIndex ? 0 : 2
                                        border.color: Appearance.colors.colOnSurfaceVariant

                                        Behavior on width {
                                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                                        }
                                        Behavior on color {
                                            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                                        }
                                    }
                                }

                                MaterialSymbol {
                                    text: modelData.icon
                                    iconSize: Appearance.font.pixelSize.large
                                    color: index === root.selectedModeIndex
                                        ? Appearance.colors.colOnPrimary
                                        : Appearance.colors.colOnSurfaceVariant

                                    Behavior on color {
                                        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                                    }
                                }

                                StyledText {
                                    text: modelData.label
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: index === root.selectedModeIndex ? Font.DemiBold : Font.Normal
                                    color: index === root.selectedModeIndex
                                        ? Appearance.colors.colOnPrimary
                                        : Appearance.colors.colOnSurface
                                    Layout.fillWidth: true

                                    Behavior on color {
                                        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                                    }
                                }

                                // Check mark for current mode
                                MaterialSymbol {
                                    text: "check"
                                    iconSize: Appearance.font.pixelSize.normal
                                    color: Appearance.colors.colOnPrimary
                                    visible: index === root.selectedModeIndex
                                    opacity: visible ? 1 : 0

                                    Behavior on opacity {
                                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                                    }
                                }
                            }

                            // Mouse interaction
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: {
                                    autoCloseTimer.restart()
                                    GlobalStates.displayProjectionCycleIndex = index
                                }
                                onClicked: root._applySelected()
                            }
                        }
                    }
                }
            }

            Component.onCompleted: {
                DisplayProjection.fetchMonitors()
                root._syncSelectedMode()
            }
        }
    }

    Connections {
        target: GlobalStates
        function onDisplayProjectionOpenChanged() {
            if (GlobalStates.displayProjectionOpen) {
                DisplayProjection.fetchMonitors()
                root._syncSelectedMode()
            }
        }
    }
}
