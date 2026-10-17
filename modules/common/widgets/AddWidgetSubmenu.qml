pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    implicitHeight: col.implicitHeight + 16

    signal addImageClicked()
    signal addVideoClicked()

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.verylarge
        color: Appearance.colors.colUiBackground
    }

    ColumnLayout {
        id: col
        anchors { fill: parent; margins: 8 }
        spacing: 2

        RippleButton {
            Layout.fillWidth: true
            implicitHeight: 40
            buttonRadius: Appearance.rounding.normal
            colBackground: "transparent"
            colBackgroundHover: Appearance.colors.colLayer2
            contentItem: RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                spacing: 12
                MaterialSymbol {
                    text: "image"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colOnLayer1
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Custom Image")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer1
                }
            }
            onClicked: root.addImageClicked()
        }

        RippleButton {
            Layout.fillWidth: true
            implicitHeight: 40
            buttonRadius: Appearance.rounding.normal
            colBackground: "transparent"
            colBackgroundHover: Appearance.colors.colLayer2
            contentItem: RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                spacing: 12
                MaterialSymbol {
                    text: "movie"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colOnLayer1
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Custom Video")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer1
                }
            }
            onClicked: root.addVideoClicked()
        }
    }
}
