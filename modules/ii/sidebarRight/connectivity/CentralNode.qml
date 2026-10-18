import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root

    property string icon: "wifi"
    property string title: "Network"
    property string subtitle: "Connected"
    property color accentColor: Appearance.colors.colPrimary
    property bool active: true
    property bool connecting: false
    property real hubDiameter: 136

    implicitWidth: hubDiameter + 50
    implicitHeight: hubDiameter + 50

    readonly property real hubCenterX: x + width / 2
    readonly property real hubCenterY: y + height / 2
    readonly property real hubRadius: hubDiameter / 2

    // Outer concentric ripple ring 2
    Rectangle {
        id: rippleRing2
        anchors.centerIn: parent
        width: root.hubDiameter + 42
        height: root.hubDiameter + 42
        radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: ColorUtils.transparentize(root.accentColor, root.active ? 0.85 : 0.95)
        scale: 1.0

        SequentialAnimation on scale {
            running: root.active || root.connecting
            loops: Animation.Infinite
            NumberAnimation { to: 1.05; duration: 2400; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 2400; easing.type: Easing.InOutSine }
        }

        SequentialAnimation on opacity {
            running: root.active || root.connecting
            loops: Animation.Infinite
            NumberAnimation { to: 0.35; duration: 2400; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.70; duration: 2400; easing.type: Easing.InOutSine }
        }
    }

    // Outer concentric ripple ring 1
    Rectangle {
        id: rippleRing1
        anchors.centerIn: parent
        width: root.hubDiameter + 20
        height: root.hubDiameter + 20
        radius: width / 2
        color: "transparent"
        border.width: 1.5
        border.color: ColorUtils.transparentize(root.accentColor, root.active ? 0.72 : 0.92)

        SequentialAnimation on opacity {
            running: root.active || root.connecting
            loops: Animation.Infinite
            NumberAnimation { to: 0.85; duration: 1800; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.45; duration: 1800; easing.type: Easing.InOutSine }
        }
    }

    // Central circular hub
    Rectangle {
        id: hubCircle
        anchors.centerIn: parent
        width: root.hubDiameter
        height: root.hubDiameter
        radius: width / 2
        color: root.active
            ? ColorUtils.mix(Appearance.colors.colLayer1, root.accentColor, 0.22)
            : Appearance.colors.colLayer1
        border.width: 2
        border.color: root.active
            ? ColorUtils.mix(root.accentColor, Appearance.colors.colOnSurface, 0.15)
            : Appearance.colors.colLayer0Border

        Behavior on color { ColorAnimation { duration: 250 } }
        Behavior on border.color { ColorAnimation { duration: 250 } }

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - 24
            spacing: 3

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                iconSize: 36
                text: root.icon
                color: root.active ? root.accentColor : Appearance.colors.colSubtext

                Behavior on color { ColorAnimation { duration: 250 } }

                // Pulse icon if connecting
                SequentialAnimation on opacity {
                    running: root.connecting
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 600; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                text: root.title
                font.pixelSize: Appearance.font.pixelSize.smallie ?? 13
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnSurface
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                text: root.subtitle
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colSubtext
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }
    }
}
