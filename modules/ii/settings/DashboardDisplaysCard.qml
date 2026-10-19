import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.models.hyprland

DashboardCard {
    id: root
    clip: true

    property string title: Translation.tr("Displays")
    property string icon: "monitor"
    property var tileShape: MaterialShape.Shape.ClamShell

    tint: Appearance.colors.colLayer1

    MonitorConfigOption {
        id: monitorConfig
    }

    readonly property var currentMon: monitorConfig.monitors[monitorCanvas.selectedIndex] ?? null

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            MaterialShapeWrappedMaterialSymbol {
                shape: root.tileShape
                text: root.icon
                iconSize: 26
                fill: 1
                padding: 11
                color: Appearance.colors.colPrimary
                colSymbol: Appearance.colors.colOnPrimary
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: root.title
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    text: monitorConfig.monitors.length > 0
                        ? `${monitorConfig.monitors.length} ${Translation.tr("displays connected · Drag to arrange")}`
                        : Translation.tr("No displays detected")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }
            }

            // Quick arrangement presets
            RowLayout {
                spacing: 4
                visible: monitorConfig.monitors.length > 1
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                RippleButton {
                    implicitWidth: 30
                    implicitHeight: 30
                    buttonRadius: 6
                    colBackground: Appearance.colors.colLayer2
                    colRipple: Appearance.colors.colPrimary
                    contentItem: MaterialSymbol {
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: "arrow_left_alt"
                        iconSize: 16
                        color: Appearance.colors.colOnLayer2
                    }
                    ToolTip.visible: hovered
                    ToolTip.text: Translation.tr("Place Selected Left")
                    onClicked: monitorCanvas.moveMonitorLeft(0)
                }

                RippleButton {
                    implicitWidth: 30
                    implicitHeight: 30
                    buttonRadius: 6
                    colBackground: Appearance.colors.colLayer2
                    colRipple: Appearance.colors.colPrimary
                    contentItem: MaterialSymbol {
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: "arrow_right_alt"
                        iconSize: 16
                        color: Appearance.colors.colOnLayer2
                    }
                    ToolTip.visible: hovered
                    ToolTip.text: Translation.tr("Place Selected Right")
                    onClicked: monitorCanvas.moveMonitorRight(0)
                }

                RippleButton {
                    implicitWidth: 30
                    implicitHeight: 30
                    buttonRadius: 6
                    colBackground: Appearance.colors.colLayer2
                    colRipple: Appearance.colors.colPrimary
                    contentItem: MaterialSymbol {
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: "arrow_upward"
                        iconSize: 16
                        color: Appearance.colors.colOnLayer2
                    }
                    ToolTip.visible: hovered
                    ToolTip.text: Translation.tr("Place Selected Above")
                    onClicked: monitorCanvas.moveMonitorAbove(0)
                }

                RippleButton {
                    implicitWidth: 30
                    implicitHeight: 30
                    buttonRadius: 6
                    colBackground: Appearance.colors.colLayer2
                    colRipple: Appearance.colors.colPrimary
                    contentItem: MaterialSymbol {
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: "arrow_downward"
                        iconSize: 16
                        color: Appearance.colors.colOnLayer2
                    }
                    ToolTip.visible: hovered
                    ToolTip.text: Translation.tr("Place Selected Below")
                    onClicked: monitorCanvas.moveMonitorBelow(0)
                }

                RippleButton {
                    implicitWidth: 30
                    implicitHeight: 30
                    buttonRadius: 6
                    colBackground: Appearance.colors.colLayer2
                    colRipple: Appearance.colors.colPrimary
                    contentItem: MaterialSymbol {
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: "swap_horiz"
                        iconSize: 16
                        color: Appearance.colors.colOnLayer2
                    }
                    ToolTip.visible: hovered
                    ToolTip.text: Translation.tr("Swap Positions")
                    onClicked: monitorCanvas.swapMonitors()
                }

                RippleButton {
                    implicitWidth: 30
                    implicitHeight: 30
                    buttonRadius: 6
                    colBackground: Appearance.colors.colLayer2
                    colRipple: Appearance.colors.colPrimary
                    contentItem: MaterialSymbol {
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: "refresh"
                        iconSize: 16
                        color: Appearance.colors.colOnLayer2
                    }
                    ToolTip.visible: hovered
                    ToolTip.text: Translation.tr("Reload Layout")
                    onClicked: monitorCanvas.resetLayout()
                }
            }
        }

        // Canvas Item
        MonitorCanvas {
            id: monitorCanvas
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 120
            monitorConfig: monitorConfig
        }

        // Responsive control pills (Flow ensures wrapping without overlapping)
        Flow {
            Layout.fillWidth: true
            spacing: 8
            visible: root.currentMon !== null

            // 1. Monitor Selection Tabs
            RowLayout {
                spacing: 6

                Repeater {
                    model: monitorConfig.monitors.length

                    delegate: RippleButton {
                        id: monTabBtn
                        required property int index
                        readonly property var mon: monitorConfig.monitors[index]
                        readonly property bool isSelected: index === monitorCanvas.selectedIndex

                        implicitHeight: 32
                        implicitWidth: monBadgeRow.implicitWidth + 24
                        buttonRadius: 8
                        colBackground: isSelected ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
                        colRipple: isSelected ? Appearance.colors.colPrimary : Appearance.colors.colLayer3Hover

                        onClicked: {
                            monitorCanvas.selectedIndex = index
                        }

                        contentItem: RowLayout {
                            id: monBadgeRow
                            spacing: 6

                            MaterialSymbol {
                                text: (monTabBtn.mon?.disabled ?? false) ? "desktop_access_disabled" : "desktop_windows"
                                iconSize: 16
                                color: monTabBtn.isSelected ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                            }

                            StyledText {
                                text: monTabBtn.mon?.name ?? `Display ${monTabBtn.index + 1}`
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: monTabBtn.isSelected ? Font.DemiBold : Font.Normal
                                color: monTabBtn.isSelected ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
                            }
                        }
                    }
                }
            }

            // 2. Enabled Toggle Pill
            Rectangle {
                id: enabledPill
                implicitHeight: 32
                implicitWidth: enabledRow.implicitWidth + 20
                radius: 8
                color: (root.currentMon?.disabled ?? false)
                    ? Appearance.colors.colLayer2
                    : Appearance.colors.colPrimaryContainer
                opacity: monitorConfig.monitors.length > 1 ? 1 : 0.6

                RowLayout {
                    id: enabledRow
                    anchors.centerIn: parent
                    spacing: 8

                    MaterialSymbol {
                        text: (root.currentMon?.disabled ?? false) ? "tv_off" : "tv"
                        iconSize: 16
                        color: (root.currentMon?.disabled ?? false)
                            ? Appearance.colors.colOnLayer2
                            : Appearance.colors.colOnPrimaryContainer
                    }

                    StyledText {
                        text: (root.currentMon?.disabled ?? false) ? Translation.tr("Disabled") : Translation.tr("Enabled")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: (root.currentMon?.disabled ?? false)
                            ? Appearance.colors.colOnLayer2
                            : Appearance.colors.colOnPrimaryContainer
                    }

                    StyledSwitch {
                        id: enabledSwitch
                        scale: 0.65
                        enabled: monitorConfig.monitors.length > 1
                        checked: !(root.currentMon?.disabled ?? false)
                        onToggled: {
                            monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { disabled: !checked })
                            monitorConfig.applyAndSave(monitorCanvas.selectedIndex)
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.rightMargin: 40
                    enabled: monitorConfig.monitors.length > 1
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const nextDisabled = !(root.currentMon?.disabled ?? false)
                        monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { disabled: nextDisabled })
                        monitorConfig.applyAndSave(monitorCanvas.selectedIndex)
                    }
                }
            }

            // 3. Resolution / Mode ComboBox
            StyledComboBox {
                id: modeComboBox
                implicitHeight: 32
                implicitWidth: 185
                buttonRadius: 8
                buttonIcon: "aspect_ratio"
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover
                colBackgroundActive: Appearance.colors.colLayer2Active
                textRole: "display"
                valueRole: "value"
                model: (root.currentMon?.availableModes ?? []).map(m => ({ display: m, value: m }))
                currentIndex: {
                    const cur = root.currentMon?.currentMode ?? ""
                    if (!model || model.length === 0) return -1
                    const idx = model.findIndex(item => item.value === cur)
                    return idx !== -1 ? idx : 0
                }
                onActivated: index => {
                    if (index < 0 || index >= model.length) return
                    const mode = model[index].value
                    const parts = mode.match(/(\d+)x(\d+)@([\d.]+)Hz/)
                    if (!parts) return
                    monitorConfig.updateMonitor(monitorCanvas.selectedIndex, {
                        currentMode: mode,
                        width: parseInt(parts[1]),
                        height: parseInt(parts[2]),
                        refreshRate: parseFloat(parts[3])
                    })
                    monitorConfig.applyAndSave(monitorCanvas.selectedIndex)
                }
            }

            // 4. Scale Stepper Pill
            Rectangle {
                id: scalePill
                implicitHeight: 32
                implicitWidth: scaleRow.implicitWidth + 14
                radius: 8
                color: Appearance.colors.colLayer2

                RowLayout {
                    id: scaleRow
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialSymbol {
                        text: "zoom_in"
                        iconSize: 16
                        color: Appearance.colors.colOnLayer2
                    }

                    RippleButton {
                        implicitWidth: 24
                        implicitHeight: 24
                        buttonRadius: 6
                        colBackground: Appearance.colors.colLayer3
                        colRipple: Appearance.colors.colPrimary
                        enabled: (root.currentMon?.scale ?? 1.0) > 0.5
                        opacity: enabled ? 1 : 0.4
                        contentItem: MaterialSymbol {
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: "remove"
                            iconSize: 14
                            color: Appearance.colors.colOnLayer3
                        }
                        onClicked: {
                            const current = Math.round((root.currentMon?.scale ?? 1.0) * 100)
                            const nextVal = Math.max(50, current - 25) / 100.0
                            monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { scale: nextVal })
                            monitorConfig.applyAndSave(monitorCanvas.selectedIndex)
                        }
                    }

                    StyledText {
                        Layout.preferredWidth: 44
                        horizontalAlignment: Text.AlignHCenter
                        text: `${Math.round((root.currentMon?.scale ?? 1.0) * 100)}%`
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer2
                    }

                    RippleButton {
                        implicitWidth: 24
                        implicitHeight: 24
                        buttonRadius: 6
                        colBackground: Appearance.colors.colLayer3
                        colRipple: Appearance.colors.colPrimary
                        enabled: (root.currentMon?.scale ?? 1.0) < 3.0
                        opacity: enabled ? 1 : 0.4
                        contentItem: MaterialSymbol {
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: "add"
                            iconSize: 14
                            color: Appearance.colors.colOnLayer3
                        }
                        onClicked: {
                            const current = Math.round((root.currentMon?.scale ?? 1.0) * 100)
                            const nextVal = Math.min(300, current + 25) / 100.0
                            monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { scale: nextVal })
                            monitorConfig.applyAndSave(monitorCanvas.selectedIndex)
                        }
                    }
                }
            }

            // 5. Rotation Segmented Pill
            Rectangle {
                id: rotatePill
                implicitHeight: 32
                implicitWidth: rotateRow.implicitWidth + 14
                radius: 8
                color: Appearance.colors.colLayer2

                RowLayout {
                    id: rotateRow
                    anchors.centerIn: parent
                    spacing: 4

                    MaterialSymbol {
                        text: "screen_rotation"
                        iconSize: 16
                        color: Appearance.colors.colOnLayer2
                        Layout.rightMargin: 2
                    }

                    Repeater {
                        model: [
                            { label: "0°", val: 0 },
                            { label: "90°", val: 1 },
                            { label: "180°", val: 2 },
                            { label: "270°", val: 3 }
                        ]

                        delegate: RippleButton {
                            id: rotBtn
                            required property var modelData
                            implicitWidth: 36
                            implicitHeight: 24
                            buttonRadius: 6
                            readonly property bool isSelected: (root.currentMon?.transform ?? 0) === rotBtn.modelData.val
                            colBackground: isSelected ? Appearance.colors.colPrimary : "transparent"
                            colRipple: isSelected ? Appearance.colors.colPrimaryActive : Appearance.colors.colLayer3Hover

                            contentItem: StyledText {
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: rotBtn.modelData.label
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: rotBtn.isSelected ? Font.Bold : Font.Normal
                                color: rotBtn.isSelected ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
                            }

                            onClicked: {
                                monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { transform: rotBtn.modelData.val })
                                monitorConfig.applyAndSave(monitorCanvas.selectedIndex)
                            }
                        }
                    }
                }
            }
        }
    }
}
