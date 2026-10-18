import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services

Item {
    id: root

    property color accentColor: "#A97363" // Warm terracotta accent matching rice wallpaper/term2

    implicitHeight: 336
    implicitWidth: 380

    readonly property bool isConnected: Network.ethernet || (Network.wifiEnabled && Network.wifiStatus === "connected")
    readonly property bool isConnecting: Network.wifiStatus === "connecting"
    readonly property real colCardWidth: Math.floor((width - 10) / 2)

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

        cardTopLeft: cardIp
        cardTopRight: cardBand
        cardBottomLeft: cardGateway
        cardBottomRight: cardSignal
        cardBottomCenter: cardDetails
    }

    // Central Node (Hero Hub at top)
    CentralNode {
        id: centralHub
        z: 1
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        accentColor: root.accentColor
        active: root.isConnected
        connecting: root.isConnecting
        icon: Network.materialSymbol
        title: Network.networkName || (Network.ethernet ? Translation.tr("Wired") : (Network.wifiEnabled ? Translation.tr("Wi-Fi") : Translation.tr("Disabled")))
        subtitle: Network.ethernet
            ? Translation.tr("Wired Connection")
            : (root.isConnected
                ? Translation.tr("Connected")
                : (root.isConnecting
                    ? Translation.tr("Connecting...")
                    : (!Network.wifiEnabled
                        ? Translation.tr("Wi-Fi Disabled")
                        : Translation.tr("Not Connected"))))
    }

    // Grid Row 1 Left: IPv4 Address
    DetailCard {
        id: cardIp
        z: 2
        x: 0
        y: 124
        width: root.colCardWidth
        anchorSide: "right"
        icon: "lan"
        iconColor: root.accentColor
        label: Translation.tr("IPv4 Address")
        value: Network.ipAddress || (root.isConnected ? "—" : Translation.tr("Offline"))
        subtext: Network.publicIpAddress ? "WAN: " + Network.publicIpAddress : ""
        badge: Network.ipAddress ? "IPv4" : ""
        copyable: !!Network.ipAddress
        copyText: Network.ipAddress
    }

    // Grid Row 1 Right: Frequency / Band
    DetailCard {
        id: cardBand
        z: 2
        x: parent.width - width
        y: 124
        width: root.colCardWidth
        anchorSide: "left"
        icon: "wifi_channel"
        iconColor: root.accentColor
        label: Translation.tr("Frequency")
        value: Network.activeBand || (Network.ethernet ? Translation.tr("Wired (802.3)") : "—")
        subtext: Network.active?.frequency ? Network.active.frequency + " MHz" : (Network.ethernet ? Translation.tr("Gigabit Link") : "")
        badge: Network.activeBand ? Network.activeBand : ""
        copyable: false
    }

    // Grid Row 2 Left: Gateway & DNS
    DetailCard {
        id: cardGateway
        z: 2
        x: 0
        y: 192
        width: root.colCardWidth
        anchorSide: "right"
        icon: "dns"
        iconColor: root.accentColor
        label: Translation.tr("Gateway")
        value: Network.gateway || "—"
        subtext: Network.dns ? "DNS: " + Network.dns : ""
        copyable: !!Network.gateway
        copyText: Network.gateway
    }

    // Grid Row 2 Right: Signal Strength
    DetailCard {
        id: cardSignal
        z: 2
        x: parent.width - width
        y: 192
        width: root.colCardWidth
        anchorSide: "left"
        icon: "signal_wifi_4_bar"
        iconColor: root.accentColor
        label: Translation.tr("Signal")
        value: Network.ethernet
            ? Translation.tr("100% (Wired)")
            : (Network.networkStrength !== undefined
                ? Network.networkStrength + "%"
                : "—")
        subtext: Network.active?.bssid ? "AP: " + Network.active.bssid : (Network.ethernet ? Translation.tr("Ethernet Port Active") : "")
        copyable: !!Network.active?.bssid
        copyText: Network.active?.bssid ?? ""
    }

    // Summary Row: Full-width Physical Interface & Security
    DetailCard {
        id: cardDetails
        z: 2
        x: 0
        y: 260
        width: parent.width
        implicitHeight: 64
        anchorSide: "top"
        icon: "security"
        iconColor: root.accentColor
        label: Translation.tr("Interface & Security")
        value: {
            let str = "";
            if (Network.networkInterface) str += Network.networkInterface + " • ";
            str += Network.activeSecurity || (root.isConnected ? Translation.tr("Protected") : "—");
            return str;
        }
        subtext: Network.macAddress ? "MAC: " + Network.macAddress : ""
        badge: Network.networkInterface ? Network.networkInterface : ""
        copyable: !!Network.macAddress
        copyText: Network.macAddress
    }
}
