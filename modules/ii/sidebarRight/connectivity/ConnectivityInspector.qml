import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services

WindowDialog {
    id: root

    property string initialTab: "wifi"
    property string activeTab: initialTab

    signal openWifiListRequested()
    signal openBluetoothListRequested()

    backgroundWidth: Math.min(parent ? parent.width - 24 : 430, 430)
    backgroundHeight: 430

    onShowChanged: {
        if (show) {
            root.activeTab = root.initialTab;
        }
    }

    // Title Row
    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            radius: Appearance.rounding?.small ?? 12
            color: ColorUtils.transparentize(root.activeTab === "wifi" ? "#A97363" : Appearance.colors.colPrimary, 0.85)

            MaterialSymbol {
                anchors.centerIn: parent
                iconSize: 18
                text: root.activeTab === "wifi" ? "wifi" : "bluetooth"
                color: root.activeTab === "wifi" ? "#A97363" : Appearance.colors.colPrimary

                Behavior on color { ColorAnimation { duration: 180 } }
            }
        }

        WindowDialogTitle {
            Layout.fillWidth: true
            text: root.activeTab === "wifi"
                ? Translation.tr("Network Inspector")
                : Translation.tr("Bluetooth Inspector")
        }

        // Close button
        RippleButton {
            implicitWidth: 32
            implicitHeight: 32
            buttonRadius: 16
            colBackground: "transparent"
            colBackgroundHover: Appearance.colors.colLayer3Hover
            onClicked: root.dismiss()

            MaterialSymbol {
                anchors.centerIn: parent
                iconSize: 20
                text: "close"
                color: Appearance.colors.colSubtext
            }
        }
    }

    WindowDialogSeparator {}

    // Main Graph Area
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 260
        clip: true

        NetworkGraphView {
            id: networkGraph
            anchors.fill: parent
            visible: opacity > 0
            opacity: root.activeTab === "wifi" ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
                }
            }
        }

        BluetoothGraphView {
            id: bluetoothGraph
            anchors.fill: parent
            visible: opacity > 0
            opacity: root.activeTab === "bluetooth" ? 1.0 : 0.0

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
                }
            }
        }
    }

    WindowDialogSeparator {}

    // Bottom Mode Switcher & Actions
    PillSwitcher {
        Layout.fillWidth: true
        currentTab: root.activeTab
        onTabSelected: (tab) => root.activeTab = tab
        onOpenFullList: {
            if (root.activeTab === "wifi") {
                root.openWifiListRequested();
            } else {
                root.openBluetoothListRequested();
            }
        }
    }
}
