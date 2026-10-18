import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Rectangle {
    id: root

    property string gridMode: "dots"
    property string backgroundMode: "dark"

    signal gridChosen(string g)
    signal backgroundChosen(string b)
    signal newBoardRequested()
    signal clearRequested()
    signal saveRequested()
    signal openRequested()
    signal exportRequested()

    implicitWidth: 230
    implicitHeight: col.implicitHeight + 20
    radius: Appearance.rounding.normal
    color: Appearance.colors.colUiBackground
    border.width: 1
    border.color: Appearance.colors.colLayer0Border

    ColumnLayout {
        id: col
        anchors { fill: parent; margins: 10 }
        spacing: 8

        // Canvas Background & Grid Section
        StyledText {
            text: Translation.tr("Canvas Settings")
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnSurfaceVariant
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            DialogButton {
                Layout.fillWidth: true
                buttonText: Translation.tr("Dark")
                colBackground: root.backgroundMode === "dark" ? Appearance.colors.colSecondaryContainer : "transparent"
                onClicked: root.backgroundChosen("dark")
            }
            DialogButton {
                Layout.fillWidth: true
                buttonText: Translation.tr("Light")
                colBackground: root.backgroundMode === "light" ? Appearance.colors.colSecondaryContainer : "transparent"
                onClicked: root.backgroundChosen("light")
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            DialogButton {
                Layout.fillWidth: true
                buttonText: Translation.tr("Dots")
                colBackground: root.gridMode === "dots" ? Appearance.colors.colSecondaryContainer : "transparent"
                onClicked: root.gridChosen("dots")
            }
            DialogButton {
                Layout.fillWidth: true
                buttonText: Translation.tr("Lines")
                colBackground: root.gridMode === "lines" ? Appearance.colors.colSecondaryContainer : "transparent"
                onClicked: root.gridChosen("lines")
            }
            DialogButton {
                Layout.fillWidth: true
                buttonText: Translation.tr("None")
                colBackground: root.gridMode === "none" ? Appearance.colors.colSecondaryContainer : "transparent"
                onClicked: root.gridChosen("none")
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Appearance.colors.colLayer0Border
            opacity: 0.6
        }

        // File & Action Section
        StyledText {
            text: Translation.tr("Board & File")
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnSurfaceVariant
        }

        RippleButtonWithIcon {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            materialIcon: "note_add"
            mainText: Translation.tr("New Board")
            buttonRadius: 6
            onClicked: root.newBoardRequested()
        }

        RippleButtonWithIcon {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            materialIcon: "folder_open"
            mainText: Translation.tr("Open Board...")
            buttonRadius: 6
            onClicked: root.openRequested()
        }

        RippleButtonWithIcon {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            materialIcon: "save"
            mainText: Translation.tr("Save Board As...")
            buttonRadius: 6
            onClicked: root.saveRequested()
        }

        RippleButtonWithIcon {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            materialIcon: "download"
            mainText: Translation.tr("Export as PNG...")
            buttonRadius: 6
            onClicked: root.exportRequested()
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Appearance.colors.colLayer0Border
            opacity: 0.6
        }

        RippleButtonWithIcon {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            materialIcon: "delete_sweep"
            mainText: Translation.tr("Clear Board")
            buttonRadius: 6
            onClicked: root.clearRequested()
        }
    }
}
