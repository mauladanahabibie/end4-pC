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
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.topMargin: 6
        anchors.bottomMargin: 6
        spacing: 2

        // Top Row: History button on left, Expression & Copy on right
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 24
            spacing: 6

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

            StyledText {
                visible: root.expression.length > 0 && (root.result.length > 0 ? root.expression !== root.result : true)
                text: root.expression
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1
                opacity: 0.7
                elide: Text.ElideLeft
                Layout.maximumWidth: parent.width - 70
            }

            RippleButton {
                visible: (root.result.length > 0 || root.expression.length > 0) && !root.isError
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                buttonRadius: 12
                colBackground: "transparent"
                StyledToolTip {
                    text: root.copiedFeedback ? Translation.tr("Copied!") : Translation.tr("Copy result")
                }
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.copiedFeedback ? "check" : "content_copy"
                    iconSize: 14
                    color: root.copiedFeedback ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                }
                onClicked: {
                    const textToCopy = root.result.length > 0 ? root.result : root.expression;
                    Quickshell.clipboardText = textToCopy;
                    root.copiedFeedback = true;
                    copyFeedbackTimer.restart();
                }
            }
        }

        // Bottom Row: Primary Result / Input / Error Display
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            StyledText {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    if (root.isError) return root.errorMessage;
                    if (root.result.length > 0) return root.result;
                    if (root.expression.length > 0) return root.expression;
                    return "0";
                }
                font.bold: true
                font.pixelSize: root.isError ? Appearance.font.pixelSize.normal : 24
                color: root.isError ? Appearance.colors.colError : Appearance.colors.colOnSurface
                elide: Text.ElideLeft
            }
        }
    }
}
