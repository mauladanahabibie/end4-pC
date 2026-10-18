import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services

Item {
    id: root

    property string currentTab: "wifi" // "wifi" or "bluetooth"
    signal tabSelected(string tab)
    signal openFullList()
    signal refreshRequested()

    property bool isWifiTab: currentTab === "wifi"
    property bool isPowered: isWifiTab ? Network.wifiEnabled : BluetoothStatus.enabled

    implicitHeight: 46
    implicitWidth: 380

    RowLayout {
        anchors.fill: parent
        spacing: 10

        // Segmented pill switcher
        Rectangle {
            id: segmentedPill
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            radius: height / 2
            color: Appearance.colors.colLayer2
            border.width: 1
            border.color: Appearance.colors.colLayer0Border

            readonly property real segmentWidth: (width - 6) / 2

            // Sliding selection indicator thumb
            Rectangle {
                id: thumb
                y: 3
                x: root.isWifiTab ? 3 : segmentedPill.segmentWidth + 3
                width: segmentedPill.segmentWidth
                height: parent.height - 6
                radius: height / 2
                color: Appearance.colors.colPrimaryContainer

                Behavior on x {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
                    }
                }
            }

            Row {
                anchors.fill: parent
                anchors.margins: 3

                // Wi-Fi Segment
                Item {
                    width: segmentedPill.segmentWidth
                    height: parent.height

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.currentTab = "wifi";
                            root.tabSelected("wifi");
                        }
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        MaterialSymbol {
                            iconSize: 18
                            text: "wifi"
                            color: root.isWifiTab ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }

                        StyledText {
                            text: Translation.tr("Wi-Fi")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: root.isWifiTab ? Font.DemiBold : Font.Normal
                            color: root.isWifiTab ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                    }
                }

                // Bluetooth Segment
                Item {
                    width: segmentedPill.segmentWidth
                    height: parent.height

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.currentTab = "bluetooth";
                            root.tabSelected("bluetooth");
                        }
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        MaterialSymbol {
                            iconSize: 18
                            text: "bluetooth"
                            color: !root.isWifiTab ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }

                        StyledText {
                            text: Translation.tr("Bluetooth")
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: !root.isWifiTab ? Font.DemiBold : Font.Normal
                            color: !root.isWifiTab ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colSubtext
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                    }
                }
            }
        }

        // Action: Rescan / Refresh
        Rectangle {
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44
            radius: height / 2
            color: refreshHover.containsMouse ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2
            border.width: 1
            border.color: refreshHover.containsMouse ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border

            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }

            MouseArea {
                id: refreshHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.isWifiTab) {
                        Network.rescanWifi();
                    } else {
                        if (BluetoothStatus.adapter) {
                            BluetoothStatus.adapter.discovering = true;
                        }
                    }
                    root.refreshRequested();
                }
            }

            MaterialSymbol {
                anchors.centerIn: parent
                iconSize: 20
                text: "refresh"
                color: (root.isWifiTab ? Network.wifiScanning : BluetoothStatus.discovering)
                    ? Appearance.colors.colPrimary
                    : Appearance.colors.colOnSurface

                RotationAnimation on rotation {
                    running: root.isWifiTab ? Network.wifiScanning : BluetoothStatus.discovering
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: 1000
                }
            }
        }

        // Action: Power Toggle
        Rectangle {
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44
            radius: height / 2
            color: root.isPowered
                ? (powerHover.containsMouse ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colPrimaryContainer)
                : (powerHover.containsMouse ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2)
            border.width: 1
            border.color: root.isPowered
                ? Appearance.colors.colPrimary
                : Appearance.colors.colLayer0Border

            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on border.color { ColorAnimation { duration: 180 } }

            MouseArea {
                id: powerHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.isWifiTab) {
                        Network.toggleWifi();
                    } else {
                        BluetoothStatus.togglePower();
                    }
                }
            }

            MaterialSymbol {
                anchors.centerIn: parent
                iconSize: 20
                text: "power_settings_new"
                color: root.isPowered
                    ? Appearance.colors.colOnPrimaryContainer
                    : Appearance.colors.colSubtext

                Behavior on color { ColorAnimation { duration: 180 } }
            }
        }

        // Action: Manage / View All Devices List
        Rectangle {
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44
            radius: height / 2
            color: listHover.containsMouse ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2
            border.width: 1
            border.color: listHover.containsMouse ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border

            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }

            MouseArea {
                id: listHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openFullList()
            }

            MaterialSymbol {
                anchors.centerIn: parent
                iconSize: 20
                text: "list"
                color: Appearance.colors.colOnSurface
            }
        }
    }
}
