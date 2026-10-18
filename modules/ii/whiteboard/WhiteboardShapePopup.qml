import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Rectangle {
    id: root

    property string selectedShape: "rectangle" // line, arrow, rectangle, ellipse
    signal shapeChosen(string s)

    implicitWidth: col.implicitWidth + 20
    implicitHeight: col.implicitHeight + 20
    radius: Appearance.rounding.normal
    color: Appearance.colors.colUiBackground
    border.width: 1
    border.color: Appearance.colors.colLayer0Border

    readonly property var shapes: [
        { id: "line",      icon: "horizontal_rule", name: Translation.tr("Line") },
        { id: "arrow",     icon: "arrow_right_alt",  name: Translation.tr("Arrow") },
        { id: "rectangle", icon: "crop_square",      name: Translation.tr("Rectangle") },
        { id: "ellipse",   icon: "circle",           name: Translation.tr("Ellipse") }
    ]

    ColumnLayout {
        id: col
        anchors.centerIn: parent
        spacing: 6

        StyledText {
            text: Translation.tr("Shapes")
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnSurfaceVariant
        }

        RowLayout {
            spacing: 6

            Repeater {
                model: root.shapes
                delegate: Rectangle {
                    required property var modelData
                    width: 36
                    height: 36
                    radius: 8
                    color: root.selectedShape === modelData.id
                        ? (Appearance.colors.colSecondaryContainer ?? "#3b82f6")
                        : (shapeHover.containsMouse ? Appearance.colors.colLayer1 : "transparent")
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: modelData.icon
                        iconSize: 20
                        color: root.selectedShape === modelData.id
                            ? Appearance.colors.colOnSecondaryContainer
                            : Appearance.colors.colOnSurface
                    }

                    MouseArea {
                        id: shapeHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.shapeChosen(modelData.id)
                    }
                }
            }
        }
    }
}
