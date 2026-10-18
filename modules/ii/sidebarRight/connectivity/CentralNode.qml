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
    property real circleDiameter: 60
    property real topGap: 22

    implicitWidth: 280
    implicitHeight: hubCircle.y + hubCircle.height + 4 + titleColumn.implicitHeight

    readonly property real hubCenterX: x + width / 2
    readonly property real hubCenterY: y + hubCircle.y + hubCircle.height / 2
    readonly property real hubBottomY: y + hubCircle.y + hubCircle.height + 4 + titleColumn.implicitHeight
    readonly property real hubRadius: circleDiameter / 2

    // Outer concentric ripple ring 2
    Rectangle {
        id: rippleRing2
        anchors.centerIn: hubCircle
        width: root.circleDiameter + 28
        height: root.circleDiameter + 28
        radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: ColorUtils.transparentize(root.accentColor, root.active ? 0.85 : 0.95)
        scale: 1.0

        SequentialAnimation on scale {
            running: root.active || root.connecting
            loops: Animation.Infinite
            NumberAnimation { to: 1.06; duration: 2400; easing.type: Easing.InOutSine }
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
        anchors.centerIn: hubCircle
        width: root.circleDiameter + 14
        height: root.circleDiameter + 14
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
        anchors.top: parent.top
        anchors.topMargin: root.topGap
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.circleDiameter
        height: root.circleDiameter
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

        MaterialSymbol {
            anchors.centerIn: parent
            iconSize: 26
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
    }

    // Title and Subtitle Status pill below circle
    ColumnLayout {
        id: titleColumn
        anchors.top: hubCircle.bottom
        anchors.topMargin: 4
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        spacing: 1

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: root.title
            font.pixelSize: Appearance.font.pixelSize.smallie ?? 13
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnSurface
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 5

            Rectangle {
                Layout.preferredWidth: 6
                Layout.preferredHeight: 6
                radius: 3
                color: root.active
                    ? root.accentColor
                    : (root.connecting ? "#E5A93C" : Appearance.colors.colSubtext)

                SequentialAnimation on opacity {
                    running: root.connecting
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 500 }
                    NumberAnimation { to: 1.0; duration: 500 }
                }
            }

            StyledText {
                text: root.subtitle
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colSubtext
                elide: Text.ElideRight
            }
        }
    }
}
