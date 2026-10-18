import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Rectangle {
    id: root

    property real strokeWidth: 3
    signal widthChosen(real w)

    implicitWidth: 190
    implicitHeight: col.implicitHeight + 20
    radius: Appearance.rounding.normal
    color: Appearance.colors.colUiBackground
    border.width: 1
    border.color: Appearance.colors.colLayer0Border

    readonly property var presets: [
        { label: "Fine", width: 2 },
        { label: "Medium", width: 4 },
        { label: "Bold", width: 8 },
        { label: "Heavy", width: 14 }
    ]

    ColumnLayout {
        id: col
        anchors { fill: parent; margins: 10 }
        spacing: 8

        StyledText {
            text: Translation.tr("Stroke Width")
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnSurfaceVariant
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: root.presets
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    height: 28
                    radius: 6
                    color: Math.abs(root.strokeWidth - modelData.width) < 0.5
                        ? (Appearance.colors.colSecondaryContainer ?? "#3b82f6")
                        : (btnHover.containsMouse ? Appearance.colors.colLayer1 : "transparent")
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border

                    Rectangle {
                        anchors.centerIn: parent
                        width: 16
                        height: modelData.width
                        radius: modelData.width / 2
                        color: Math.abs(root.strokeWidth - modelData.width) < 0.5
                            ? Appearance.colors.colOnSecondaryContainer
                            : Appearance.colors.colOnSurface
                    }

                    MouseArea {
                        id: btnHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.widthChosen(modelData.width)
                    }
                }
            }
        }

        ConfigSlider {
            Layout.fillWidth: true
            Layout.leftMargin: 0
            Layout.rightMargin: 0
            text: `${Math.round(root.strokeWidth)}px`
            textWidth: 42
            usePercentTooltip: false
            from: 1
            to: 24
            stepSize: 1
            value: root.strokeWidth
            onMoved: root.widthChosen(Math.round(value))
        }
    }
}
