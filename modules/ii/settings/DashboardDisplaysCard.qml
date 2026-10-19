import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.models.hyprland

DashboardCard {
    id: root

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
                spacing: 0

                StyledText {
                    text: root.title
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                }
                StyledText {
                    text: monitorConfig.monitors.length > 0
                        ? `${monitorConfig.monitors.length} ${Translation.tr("displays connected · Drag to arrange")}`
                        : Translation.tr("No displays detected")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }

            Item { Layout.fillWidth: true }

            // Quick arrangement presets
            RowLayout {
                spacing: 6
                visible: monitorConfig.monitors.length > 1

                RippleButton {
                    implicitWidth: 32
                    implicitHeight: 32
                    buttonRadius: 8
                    colBackground: Appearance.colors.colLayer2
                    colRipple: Appearance.colors.colPrimary
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "arrow_left_alt"
                        iconSize: 18
                        color: Appearance.colors.colOnLayer2
                    }
                    ToolTip.visible: hovered
                    ToolTip.text: Translation.tr("Place Selected Left")
                    onClicked: monitorCanvas.moveMonitorLeft(0)
                }

                RippleButton {
                    implicitWidth: 32
                    implicitHeight: 32
                    buttonRadius: 8
                    colBackground: Appearance.colors.colLayer2
                    colRipple: Appearance.colors.colPrimary
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "arrow_right_alt"
                        iconSize: 18
                        color: Appearance.colors.colOnLayer2
                    }
                    ToolTip.visible: hovered
                    ToolTip.text: Translation.tr("Place Selected Right")
                    onClicked: monitorCanvas.moveMonitorRight(0)
                }

                RippleButton {
                    implicitWidth: 32
                    implicitHeight: 32
                    buttonRadius: 8
                    colBackground: Appearance.colors.colLayer2
                    colRipple: Appearance.colors.colPrimary
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "arrow_upward"
                        iconSize: 18
                        color: Appearance.colors.colOnLayer2
                    }
                    ToolTip.visible: hovered
                    ToolTip.text: Translation.tr("Place Selected Above")
                    onClicked: monitorCanvas.moveMonitorAbove(0)
                }

                RippleButton {
                    implicitWidth: 32
                    implicitHeight: 32
                    buttonRadius: 8
                    colBackground: Appearance.colors.colLayer2
                    colRipple: Appearance.colors.colPrimary
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "arrow_downward"
                        iconSize: 18
                        color: Appearance.colors.colOnLayer2
                    }
                    ToolTip.visible: hovered
                    ToolTip.text: Translation.tr("Place Selected Below")
                    onClicked: monitorCanvas.moveMonitorBelow(0)
                }

                RippleButton {
                    implicitWidth: 32
                    implicitHeight: 32
                    buttonRadius: 8
                    colBackground: Appearance.colors.colLayer2
                    colRipple: Appearance.colors.colPrimary
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "swap_horiz"
                        iconSize: 18
                        color: Appearance.colors.colOnLayer2
                    }
                    ToolTip.visible: hovered
                    ToolTip.text: Translation.tr("Swap Positions")
                    onClicked: monitorCanvas.swapMonitors()
                }

                RippleButton {
                    implicitWidth: 32
                    implicitHeight: 32
                    buttonRadius: 8
                    colBackground: Appearance.colors.colLayer2
                    colRipple: Appearance.colors.colPrimary
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "refresh"
                        iconSize: 18
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
            monitorConfig: monitorConfig
        }

        // Selected monitor quick config bar
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            visible: root.currentMon !== null

            Rectangle {
                implicitHeight: 34
                implicitWidth: monitorBadge.implicitWidth + 24
                radius: 17
                color: Appearance.colors.colPrimaryContainer

                RowLayout {
                    id: monitorBadge
                    anchors.centerIn: parent
                    spacing: 6

                    MaterialSymbol {
                        text: (root.currentMon?.disabled ?? false) ? "desktop_access_disabled" : "desktop_windows"
                        iconSize: 16
                        color: Appearance.colors.colOnPrimaryContainer
                    }
                    StyledText {
                        text: root.currentMon?.name ?? ""
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnPrimaryContainer
                    }
                }
            }

            ConfigSwitch {
                buttonIcon: "tv_off"
                text: Translation.tr("Enabled")
                enabled: monitorConfig.monitors.length > 1
                checked: !(root.currentMon?.disabled ?? false)
                onCheckedChanged: {
                    if (checked === !(root.currentMon?.disabled ?? false)) return
                    monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { disabled: !checked })
                    monitorConfig.applyAndSave(monitorCanvas.selectedIndex)
                }
            }

            ConfigComboBox {
                Layout.fillWidth: true
                buttonIcon: "aspect_ratio"
                text: Translation.tr("Mode")
                textRole: "display"
                model: (root.currentMon?.availableModes ?? [])
                    .map(mode => ({ display: mode, value: mode }))
                currentValue: root.currentMon?.currentMode ?? ""
                onSelected: newValue => {
                    const mode = newValue
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

            ConfigSpinBox {
                icon: "zoom_in"
                text: Translation.tr("Scale")
                value: Math.round((root.currentMon?.scale ?? 1.0) * 100)
                from: 50; to: 300; stepSize: 25
                onValueChanged: {
                    const newVal = value / 100.0
                    if (newVal === (root.currentMon?.scale ?? 1.0)) return
                    monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { scale: newVal })
                    monitorConfig.applyAndSave(monitorCanvas.selectedIndex)
                }
            }

            ConfigSelectionArray {
                text: Translation.tr("Rotate")
                icon: "mobile_rotate"
                currentValue: root.currentMon?.transform ?? 0
                onSelected: newValue => {
                    monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { transform: newValue })
                    monitorConfig.applyAndSave(monitorCanvas.selectedIndex)
                }
                options: [
                    { displayName: "0°",   icon: "screen_rotation_alt", value: 0 },
                    { displayName: "90°",  icon: "rotate_90_degrees_cw",  value: 1 },
                    { displayName: "180°", icon: "screen_rotation",       value: 2 },
                    { displayName: "270°", icon: "rotate_90_degrees_ccw", value: 3 },
                ]
            }
        }
    }
}
