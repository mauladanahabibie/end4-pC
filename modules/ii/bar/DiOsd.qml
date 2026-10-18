import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

RowLayout {
    id: diOsdRoot
    required property Item di
    readonly property Item island: diOsdRoot.di
    anchors {
        fill: parent
        leftMargin: island?.isMaterial ? 0 : 4
        rightMargin: 10
    }
    spacing: 6

    readonly property var focusedScreen: WM.compositor === "hyprland"
        ? Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
        : Quickshell.screens.find(s => s.name === WM.focusedMonitor?.name)
    readonly property var brightnessMonitor: Brightness.getMonitorForScreen(focusedScreen)

    MaterialShapeWrappedMaterialSymbol {
        Layout.alignment: Qt.AlignVCenter
        wrappedShape: MaterialShape.Shape.Cookie12Sided
        color: Appearance.colors.colPrimary
        colSymbol: Appearance.colors.colOnPrimary
        text: island?.iconForProviderId("osd") ?? "volume_up"
        iconSize: island?.isMaterial ? 20 : 16
        fill: 1
        padding: 4
    }

    Item { Layout.fillWidth: true }

    StyledText {
        Layout.alignment: Qt.AlignVCenter
        text: {
            switch (GlobalStates.osdIndicatorType) {
                case "brightness": return `${Math.round((brightnessMonitor?.brightness ?? 0.5) * 100)}`
                case "gamma":      return `${Math.round((Hyprsunset.gamma ?? 50))}`
                default:           return `${Math.round((Audio.sink?.audio?.volume ?? 0) * 100)}`
            }
        }
        font.pixelSize: island?.isMaterial ? Appearance.font.pixelSize.normal : Appearance.font.pixelSize.small
        font.features: { "tnum": 1 }
        color: Appearance.colors.colOnLayer0
    }
}