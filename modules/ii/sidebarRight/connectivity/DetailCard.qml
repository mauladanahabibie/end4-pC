import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property string value: ""
    property string subtext: ""
    property string badge: ""
    property bool copyable: true
    property string copyText: value
    property color iconColor: Appearance.colors.colPrimary
    property string anchorSide: "left" // "left", "right", "top", "bottom"

    // Anchor point coordinates for connecting lines (exposed relative to parent)
    readonly property real connectionPointX: {
        switch (anchorSide) {
            case "left": return x + width;
            case "right": return x;
            case "top": return x + width / 2;
            case "bottom": return x + width / 2;
            default: return x + width / 2;
        }
    }

    readonly property real connectionPointY: {
        switch (anchorSide) {
            case "left": return y + height / 2;
            case "right": return y + height / 2;
            case "top": return y + height;
            case "bottom": return y;
            default: return y + height / 2;
        }
    }

    property bool copiedRecently: false

    implicitHeight: 56
    implicitWidth: 136
    radius: Appearance.rounding?.normal ?? 17
    color: mouseArea.containsMouse ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2
    border.width: 1
    border.color: mouseArea.containsMouse ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border

    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }

    Timer {
        id: copyTimer
        interval: 1800
        onTriggered: root.copiedRecently = false
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.copyable && root.value.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (!root.copyable || !root.value) return;
            Quickshell.clipboardText = root.copyText || root.value;
            root.copiedRecently = true;
            copyTimer.restart();
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        // Icon container with soft circular/rounded backdrop
        Rectangle {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            radius: Appearance.rounding?.verysmall ?? 8
            color: ColorUtils.transparentize(root.iconColor, 0.88)
            border.width: 1
            border.color: ColorUtils.transparentize(root.iconColor, 0.70)

            MaterialSymbol {
                anchors.centerIn: parent
                iconSize: 17
                text: root.copiedRecently ? "check" : (root.icon || "info")
                color: root.copiedRecently ? Appearance.colors.colPrimary : root.iconColor

                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }

        // Texts column
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                StyledText {
                    Layout.fillWidth: true
                    text: root.copiedRecently ? Translation.tr("COPIED") : root.label.toUpperCase()
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.DemiBold
                    color: root.copiedRecently ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }

                Loader {
                    active: root.badge.length > 0 && !root.copiedRecently
                    visible: active
                    sourceComponent: Rectangle {
                        implicitWidth: badgeText.implicitWidth + 8
                        implicitHeight: badgeText.implicitHeight + 2
                        radius: Appearance.rounding?.unsharpenmore ?? 6
                        color: Appearance.colors.colPrimaryContainer

                        StyledText {
                            id: badgeText
                            anchors.centerIn: parent
                            text: root.badge
                            font.pixelSize: Appearance.font.pixelSize.smallest - 2
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: root.value.length > 0 ? root.value : "—"
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                color: Appearance.colors.colOnSurface
                elide: Text.ElideRight
            }

            Loader {
                active: root.subtext.length > 0 && !root.copiedRecently
                visible: active
                Layout.fillWidth: true
                sourceComponent: StyledText {
                    text: root.subtext
                    font.pixelSize: Appearance.font.pixelSize.smallest - 1
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }
            }
        }
    }
}
