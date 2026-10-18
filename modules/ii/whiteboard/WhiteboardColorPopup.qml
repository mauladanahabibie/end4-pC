import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Rectangle {
    id: root

    property color selectedColor: "#ffffff"
    signal colorChosen(color c)

    implicitWidth: col.implicitWidth + 20
    implicitHeight: col.implicitHeight + 20
    radius: Appearance.rounding.normal
    color: Appearance.colors.colUiBackground
    border.width: 1
    border.color: Appearance.colors.colLayer0Border

    readonly property var colorPalette: [
        "#ffffff", "#d4d4d8", "#71717a", "#18181b",
        "#ef4444", "#f97316", "#f59e0b", "#10b981",
        "#06b6d4", "#3b82f6", "#8b5cf6", "#ec4899"
    ]

    ColumnLayout {
        id: col
        anchors.centerIn: parent
        spacing: 8

        StyledText {
            text: Translation.tr("Color")
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnSurfaceVariant
        }

        GridLayout {
            columns: 4
            rowSpacing: 8
            columnSpacing: 8

            Repeater {
                model: root.colorPalette
                delegate: Rectangle {
                    required property var modelData
                    width: 26
                    height: 26
                    radius: 13
                    color: modelData
                    border.width: root.selectedColor.toString() === modelData ? 2.5 : 1
                    border.color: root.selectedColor.toString() === modelData ? (Appearance.colors.colPrimary ?? "#ffffff") : "#33ffffff"

                    scale: mouseArea.containsMouse ? 1.15 : (root.selectedColor.toString() === modelData ? 1.08 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 120 } }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.colorChosen(modelData)
                    }
                }
            }
        }
    }
}
