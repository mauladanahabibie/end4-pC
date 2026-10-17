import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.modules.common
import qs.modules.common.widgets

PanelWindow {
    id: cornerPanelWindow
    property var corner
    property real frameThickness: Config.options.bar.frameThickness
    property color frameColor: Appearance.getColorFromName(Config.options.bar.frameColor)

    visible: Config.options.bar.showFrame 
    exclusionMode: ExclusionMode.Ignore
    mask: Region {}
    WlrLayershell.namespace: "quickshell:screenframe-corner"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"

    anchors {
        top: cornerWidget.isTopLeft || cornerWidget.isTopRight
        left: cornerWidget.isBottomLeft || cornerWidget.isTopLeft
        bottom: cornerWidget.isBottomLeft || cornerWidget.isBottomRight
        right: cornerWidget.isTopRight || cornerWidget.isBottomRight
    }
    margins {
        left: cornerWidget.isLeft ? frameThickness : 0
        right: cornerWidget.isRight ? frameThickness : 0
        top: cornerWidget.isTop ? frameThickness : 0
        bottom: cornerWidget.isBottom ? frameThickness : 0
    }

    implicitWidth: cornerWidget.implicitWidth
    implicitHeight: cornerWidget.implicitHeight

    RoundCorner {
        id: cornerWidget
        anchors.fill: parent
        corner: cornerPanelWindow.corner
        implicitSize: Math.max(0, Appearance.rounding.screenRounding - frameThickness)
        color: frameColor
    }
}
