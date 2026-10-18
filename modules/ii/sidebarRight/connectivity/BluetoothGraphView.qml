import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services

Item {
    id: root

    property color accentColor: Appearance.colors.colPrimary
    property var selectedDevice: BluetoothStatus.primaryConnectedDevice ?? (BluetoothStatus.connectedDevices.length > 0 ? BluetoothStatus.connectedDevices[0] : null)

    implicitHeight: 336
    implicitWidth: 380

    readonly property bool isConnected: BluetoothStatus.isConnected(selectedDevice)
    readonly property real colCardWidth: Math.floor((width - 10) / 2)
    readonly property real gridTopY: multiDeviceRow.visible ? 134 : 124

    // Optional device selector row when multiple devices are connected
    Row {
        id: multiDeviceRow
        visible: BluetoothStatus.connectedDevices.length > 1
        z: 3
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        spacing: 6

        Repeater {
            model: BluetoothStatus.connectedDevices
            delegate: Rectangle {
                required property var modelData
                width: devText.implicitWidth + 20
                height: 22
                radius: 11
                color: root.selectedDevice?.address === modelData.address
                    ? Appearance.colors.colPrimaryContainer
                    : Appearance.colors.colLayer2
                border.width: 1
                border.color: Appearance.colors.colLayer0Border

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectedDevice = modelData
                }

                StyledText {
                    id: devText
                    anchors.centerIn: parent
                    text: modelData.name || modelData.deviceName || "Device"
                    font.pixelSize: Appearance.font.pixelSize.smallest - 1
                    color: root.selectedDevice?.address === modelData.address
                        ? Appearance.colors.colOnPrimaryContainer
                        : Appearance.colors.colSubtext
                }
            }
        }
    }

    // Vector connector lines rendered underneath cards and hub
    ConnectorLines {
        id: lines
        anchors.fill: parent
        z: 0
        hubX: centralHub.hubCenterX
        hubY: centralHub.hubBottomY
        hubRadius: centralHub.hubRadius
        strokeColor: ColorUtils.transparentize(root.accentColor, root.isConnected ? 0.40 : 0.85)
        strokeWidth: 1.5

        cardTopLeft: cardBattery
        cardTopRight: cardType
        cardBottomLeft: cardAudio
        cardBottomRight: cardTrust
        cardBottomCenter: cardMac
    }

    // Central Node (Hero Hub at top)
    CentralNode {
        id: centralHub
        z: 1
        anchors.top: multiDeviceRow.visible ? multiDeviceRow.bottom : parent.top
        anchors.topMargin: multiDeviceRow.visible ? 4 : 0
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        topGap: multiDeviceRow.visible ? 6 : 22
        accentColor: root.accentColor
        active: root.isConnected
        connecting: root.selectedDevice?.state === 3
        icon: root.selectedDevice ? Icons.getBluetoothDeviceMaterialSymbol(root.selectedDevice.icon) : "bluetooth"
        title: root.selectedDevice
            ? (root.selectedDevice.name || root.selectedDevice.deviceName || Translation.tr("Device"))
            : (BluetoothStatus.enabled ? Translation.tr("Bluetooth") : Translation.tr("Disabled"))
        subtitle: root.selectedDevice
            ? (root.isConnected
                ? Translation.tr("Connected")
                : Translation.tr("Paired"))
            : (BluetoothStatus.enabled
                ? Translation.tr("No Active Device")
                : Translation.tr("Bluetooth Off"))
    }

    // Grid Row 1 Left: Battery Level
    DetailCard {
        id: cardBattery
        z: 2
        x: 0
        y: root.gridTopY
        width: root.colCardWidth
        anchorSide: "right"
        icon: {
            if (!BluetoothStatus.hasBattery(root.selectedDevice)) return "battery_unknown";
            const b = root.selectedDevice.battery;
            if (b > 0.8) return "battery_full";
            if (b > 0.5) return "battery_5_bar";
            if (b > 0.2) return "battery_2_bar";
            return "battery_alert";
        }
        iconColor: root.accentColor
        label: Translation.tr("Battery")
        value: BluetoothStatus.hasBattery(root.selectedDevice)
            ? Math.round(root.selectedDevice.battery * 100) + "%"
            : Translation.tr("N/A")
        subtext: BluetoothStatus.hasBattery(root.selectedDevice)
            ? (root.selectedDevice.battery <= 0.2 ? Translation.tr("Low battery") : Translation.tr("Normal level"))
            : Translation.tr("No battery gauge")
        badge: BluetoothStatus.hasBattery(root.selectedDevice) ? "Level" : ""
        copyable: false
    }

    // Grid Row 1 Right: Device Category
    DetailCard {
        id: cardType
        z: 2
        x: parent.width - width
        y: root.gridTopY
        width: root.colCardWidth
        anchorSide: "left"
        icon: root.selectedDevice ? Icons.getBluetoothDeviceMaterialSymbol(root.selectedDevice.icon) : "devices_other"
        iconColor: root.accentColor
        label: Translation.tr("Category")
        value: root.selectedDevice?.icon
            ? (root.selectedDevice.icon.charAt(0).toUpperCase() + root.selectedDevice.icon.slice(1).replace(/-/g, " "))
            : (root.selectedDevice ? Translation.tr("Peripheral") : "—")
        subtext: root.selectedDevice?.paired ? Translation.tr("Paired device") : Translation.tr("Unpaired")
        badge: root.selectedDevice ? "Device" : ""
        copyable: false
    }

    // Grid Row 2 Left: Audio Route / Sink
    DetailCard {
        id: cardAudio
        z: 2
        x: 0
        y: root.gridTopY + 68
        width: root.colCardWidth
        anchorSide: "right"
        icon: "volume_up"
        iconColor: root.accentColor
        label: Translation.tr("Audio Output")
        value: Audio.sink?.nickname || Audio.sink?.description || Translation.tr("System Default")
        subtext: Audio.sink ? Translation.tr("PipeWire Sink Active") : Translation.tr("Default Sink")
        copyable: false
    }

    // Grid Row 2 Right: Security & Trust
    DetailCard {
        id: cardTrust
        z: 2
        x: parent.width - width
        y: root.gridTopY + 68
        width: root.colCardWidth
        anchorSide: "left"
        icon: "verified_user"
        iconColor: root.accentColor
        label: Translation.tr("Status & Trust")
        value: root.selectedDevice?.trusted
            ? Translation.tr("Trusted")
            : (root.selectedDevice?.paired ? Translation.tr("Paired") : Translation.tr("Available"))
        subtext: root.selectedDevice?.blocked ? Translation.tr("Blocked") : Translation.tr("Allowed")
        badge: root.selectedDevice?.trusted ? "Trusted" : ""
        copyable: false
    }

    // Summary Row: Full-width Hardware MAC & Adapter
    DetailCard {
        id: cardMac
        z: 2
        x: 0
        y: root.gridTopY + 136
        width: parent.width
        implicitHeight: 64
        anchorSide: "top"
        icon: "bluetooth"
        iconColor: root.accentColor
        label: Translation.tr("Hardware Address & Adapter")
        value: {
            let str = root.selectedDevice?.address || "—";
            if (Bluetooth.defaultAdapter) {
                str += " • " + (Bluetooth.defaultAdapter.name || "hci0");
            }
            return str;
        }
        subtext: root.selectedDevice?.address ? "MAC: " + root.selectedDevice.address : (Bluetooth.defaultAdapter ? "Adapter: " + (Bluetooth.defaultAdapter.name || "hci0") : "")
        badge: root.selectedDevice?.address ? "MAC" : ""
        copyable: !!root.selectedDevice?.address
        copyText: root.selectedDevice?.address ?? ""
    }
}
