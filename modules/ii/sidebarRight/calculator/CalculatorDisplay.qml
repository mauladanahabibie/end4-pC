import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Rectangle {
    id: root

    property string expression: ""
    property string result: ""
    property string errorMessage: ""
    property bool isError: errorMessage.length > 0
    property bool copiedFeedback: false

    signal historyToggled()

    radius: Appearance.rounding.small
    color: Appearance.colors.colLayer2

    Timer {
        id: copyFeedbackTimer
        interval: 1500
        repeat: false
        onTriggered: root.copiedFeedback = false
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 4

        // Header controls (History & Copy)
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            spacing: 4

            RippleButton {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                buttonRadius: 13
                colBackground: "transparent"
                StyledToolTip {
                    text: Translation.tr("Calculation History")
                }
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "history"
                    iconSize: 16
                    color: Appearance.colors.colOnLayer1
                }
                onClicked: root.historyToggled()
            }

            Item { Layout.fillWidth: true }

            RippleButton {
                visible: root.result.length > 0 && !root.isError
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                buttonRadius: 13
                colBackground: "transparent"
                StyledToolTip {
                    text: root.copiedFeedback ? Translation.tr("Copied!") : Translation.tr("Copy result")
                }
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.copiedFeedback ? "check" : "content_copy"
                    iconSize: 15
                    color: root.copiedFeedback ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                }
                onClicked: {
                    Quickshell.clipboardText = root.result;
                    root.copiedFeedback = true;
                    copyFeedbackTimer.restart();
                }
            }
        }

        // Expression line
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 20
            clip: true

            StyledText {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.expression.length > 0 ? root.expression : "0"
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnLayer1
                opacity: 0.75
            }
        }

        // Result / Error line
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            StyledText {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.isError ? root.errorMessage : (root.result.length > 0 ? root.result : "0")
                font.bold: true
                font.pixelSize: root.isError ? Appearance.font.pixelSize.normal : 24
                color: root.isError ? Appearance.colors.colError : Appearance.colors.colOnSurface
            }
        }
    }
}
