import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

StyledPopup {
    id: root

    function formatKB(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB"
    }

    function formatSpeed(bytesPerSec) {
        if (bytesPerSec < 1024) return Math.round(bytesPerSec) + " B/s"
        if (bytesPerSec < 1024 * 1024) return (bytesPerSec / 1024).toFixed(1) + " KB/s"
        return (bytesPerSec / (1024 * 1024)).toFixed(1) + " MB/s"
    }

    function formatSpeedShort(bytesPerSec) {
        if (bytesPerSec < 1024) return Math.round(bytesPerSec) + " B/s"
        if (bytesPerSec < 1024 * 1024) return (bytesPerSec / 1024).toFixed(0) + " KB/s"
        return (bytesPerSec / (1024 * 1024)).toFixed(1) + " MB/s"
    }

    Column {
        spacing: 5

        Row {
            spacing: 5

            Column {
                spacing: 5

                ResourceCard {
                    label: "RAM"
                    iconText: "memory"
                    iconShape: MaterialShape.Shape.Clover4Leaf
                    value: ResourceUsage.memoryUsed / ResourceUsage.memoryTotal
                    sublabel: root.formatKB(ResourceUsage.memoryUsed) + " / " + root.formatKB(ResourceUsage.memoryTotal)
                }

                ResourceCard {
                    label: "CPU"
                    iconText: "planner_review"
                    iconShape: MaterialShape.Shape.Gem
                    value: ResourceUsage.cpuUsage
                    sublabel: `${Math.round(ResourceUsage.cpuTemp)}°C`
                    sublabelColor: ResourceUsage.cpuTemp > 80 ? Appearance.colors.colError
                        : ResourceUsage.cpuTemp > 60 ? Appearance.m3colors.m3tertiary
                        : Appearance.colors.colOnLayer1
                }
            }

            Column {
                spacing: 5

                ResourceCard {
                    label: "Swap"
                    iconText: "swap_horiz"
                    iconShape: MaterialShape.Shape.Bun
                    value: ResourceUsage.swapUsedPercentage
                    sublabel: root.formatKB(ResourceUsage.swapUsed) + " / " + root.formatKB(ResourceUsage.swapTotal)
                }

                ResourceCard {
                    label: "Disk"
                    iconText: "hard_drive"
                    iconShape: MaterialShape.Shape.Circle
                    value: ResourceUsage.diskUsedPercentage
                    sublabel: root.formatKB(ResourceUsage.diskUsed) + " / " + root.formatKB(ResourceUsage.diskTotal)
                }
            }
        }

        // Network card — full width, matches ResourceCard design
        Rectangle {
            width: 305
            height: networkContent.implicitHeight + 24
            radius: 16
            color: Appearance.colors.colSurfaceContainerLow

            ColumnLayout {
                id: networkContent
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6

                // Header: icon + label + download/upload speed
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    MaterialShapeWrappedMaterialSymbol {
                        shape: MaterialShape.Shape.Pentagon
                        text: "wifi"
                        iconSize: Appearance.font.pixelSize.huge
                        implicitSize: 28
                        color: "transparent"
                        colSymbol: ResourceUsage.networkDownloadSpeed > 0 || ResourceUsage.networkUploadSpeed > 0
                            ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                        Layout.alignment: Qt.AlignVCenter
                    }

                    StyledText {
                        text: "Network"
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnSurface
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Item { Layout.fillWidth: true }

                    // Download
                    RowLayout {
                        spacing: 2
                        MaterialSymbol {
                            text: "arrow_downward"
                            iconSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            text: root.formatSpeedShort(ResourceUsage.networkDownloadSpeed)
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.features: { "tnum": 1 }
                            color: Appearance.colors.colPrimary
                        }
                    }

                    // Upload
                    RowLayout {
                        spacing: 2
                        MaterialSymbol {
                            text: "arrow_upward"
                            iconSize: Appearance.font.pixelSize.small
                            color: Appearance.m3colors.m3tertiary
                        }
                        StyledText {
                            text: root.formatSpeedShort(ResourceUsage.networkUploadSpeed)
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.features: { "tnum": 1 }
                            color: Appearance.m3colors.m3tertiary
                        }
                    }
                }

                // IP addresses
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    // Local IP
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        MaterialSymbol {
                            text: "lan"
                            iconSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnSurfaceVariant
                        }
                        StyledText {
                            text: "Local"
                            font.pixelSize: Appearance.font.pixelSize.smallest || 10
                            color: Appearance.colors.colOnSurfaceVariant
                            Layout.preferredWidth: 50
                        }
                        StyledText {
                            text: ResourceUsage.localIp || "—"
                            font.pixelSize: Appearance.font.pixelSize.smallest || 10
                            font.features: { "tnum": 1 }
                            color: Appearance.colors.colOnSurface
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }

                    // Public IP
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        MaterialSymbol {
                            text: "public"
                            iconSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnSurfaceVariant
                        }
                        StyledText {
                            text: "Public"
                            font.pixelSize: Appearance.font.pixelSize.smallest || 10
                            color: Appearance.colors.colOnSurfaceVariant
                            Layout.preferredWidth: 50
                        }
                        StyledText {
                            text: ResourceUsage.publicIp || "—"
                            font.pixelSize: Appearance.font.pixelSize.smallest || 10
                            font.features: { "tnum": 1 }
                            color: ResourceUsage.warpStatus.length > 0 && ResourceUsage.warpStatus !== "Disconnected"
                                ? Appearance.colors.colPrimary : Appearance.colors.colOnSurface
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }

                    // Tailscale
                    RowLayout {
                        Layout.fillWidth: true
                        visible: ResourceUsage.tailscaleIp.length > 0
                        spacing: 6
                        MaterialSymbol {
                            text: "vpn_key"
                            iconSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnSurfaceVariant
                        }
                        StyledText {
                            text: "Tailscale"
                            font.pixelSize: Appearance.font.pixelSize.smallest || 10
                            color: Appearance.colors.colOnSurfaceVariant
                            Layout.preferredWidth: 50
                        }
                        StyledText {
                            text: ResourceUsage.tailscaleIp
                            font.pixelSize: Appearance.font.pixelSize.smallest || 10
                            font.features: { "tnum": 1 }
                            color: Appearance.colors.colOnSurface
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }

                    // WARP status
                    RowLayout {
                        Layout.fillWidth: true
                        visible: ResourceUsage.warpStatus.length > 0
                        spacing: 6
                        MaterialSymbol {
                            text: "shield"
                            iconSize: Appearance.font.pixelSize.small
                            color: ResourceUsage.warpStatus === "Connected"
                                ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                        }
                        StyledText {
                            text: "WARP"
                            font.pixelSize: Appearance.font.pixelSize.smallest || 10
                            color: Appearance.colors.colOnSurfaceVariant
                            Layout.preferredWidth: 50
                        }
                        StyledText {
                            text: ResourceUsage.warpStatus
                            font.pixelSize: Appearance.font.pixelSize.smallest || 10
                            color: ResourceUsage.warpStatus === "Connected"
                                ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }

                    // Interface
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        MaterialSymbol {
                            text: "cable"
                            iconSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnSurfaceVariant
                        }
                        StyledText {
                            text: "Iface"
                            font.pixelSize: Appearance.font.pixelSize.smallest || 10
                            color: Appearance.colors.colOnSurfaceVariant
                            Layout.preferredWidth: 50
                        }
                        StyledText {
                            text: ResourceUsage.activeInterface || "—"
                            font.pixelSize: Appearance.font.pixelSize.smallest || 10
                            font.features: { "tnum": 1 }
                            color: Appearance.colors.colOnSurface
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}