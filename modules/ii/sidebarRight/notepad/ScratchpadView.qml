import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string filePath: Directories.notesPath
    property bool isSaving: false
    property bool copiedFeedback: false

    Component.onCompleted: {
        scratchFileView.reload();
    }

    Component.onDestruction: {
        saveImmediate();
    }

    function saveImmediate() {
        saveTimer.stop();
        if (scratchFileView) {
            scratchFileView.setText(textInput.text);
        }
    }

    Timer {
        id: saveTimer
        interval: 350
        repeat: false
        onTriggered: {
            root.isSaving = true;
            if (scratchFileView) {
                scratchFileView.setText(textInput.text);
            }
            root.isSaving = false;
        }
    }

    Timer {
        id: copyFeedbackTimer
        interval: 1500
        repeat: false
        onTriggered: root.copiedFeedback = false
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        // Top Toolbar
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            spacing: 6

            StyledText {
                text: Translation.tr("Scratchpad")
                font.bold: true
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnSurface
            }

            StyledText {
                text: Translation.tr("(notes.txt)")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer1
                opacity: 0.5
            }

            Item { Layout.fillWidth: true }

            // Copy all button
            RippleButton {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                buttonRadius: 14
                colBackground: "transparent"
                StyledToolTip {
                    text: root.copiedFeedback ? Translation.tr("Copied!") : Translation.tr("Copy scratchpad to clipboard")
                }
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.copiedFeedback ? "check" : "content_copy"
                    iconSize: 16
                    color: root.copiedFeedback ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                }
                onClicked: {
                    Quickshell.clipboardText = textInput.text;
                    root.copiedFeedback = true;
                    copyFeedbackTimer.restart();
                }
            }

            // Clear button
            RippleButton {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                buttonRadius: 14
                colBackground: "transparent"
                StyledToolTip {
                    text: Translation.tr("Clear scratchpad")
                }
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "delete_sweep"
                    iconSize: 16
                    color: Appearance.colors.colOnLayer1
                }
                onClicked: {
                    textInput.text = "";
                    root.saveImmediate();
                }
            }
        }

        // Scratchpad Editor
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Appearance.colors.colLayer2
            radius: Appearance.rounding.small
            clip: true

            StyledFlickable {
                id: flickable
                anchors.fill: parent
                anchors.margins: 10
                contentWidth: width
                contentHeight: Math.max(height, textInput.implicitHeight)

                TextEdit {
                    id: textInput
                    width: flickable.width
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                    color: Appearance.colors.colOnSurface
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.family: Appearance.font.family.main
                    cursorVisible: true
                    onTextEdited: saveTimer.restart()

                    StyledText {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        text: Translation.tr("Quick scratchpad notes... Changes sync automatically to notes.txt")
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.family: Appearance.font.family.main
                        opacity: 0.4
                        visible: textInput.text.length === 0
                    }
                }
            }
        }

        // Footer
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 18

            StyledText {
                text: Translation.tr("%1 characters").arg(textInput.text.length)
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer1
                opacity: 0.5
            }

            Item { Layout.fillWidth: true }

            StyledText {
                text: root.isSaving ? Translation.tr("Saving...") : Translation.tr("Auto-saved")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer1
                opacity: 0.5
            }
        }
    }

    FileView {
        id: scratchFileView
        path: Qt.resolvedUrl(root.filePath)
        onLoaded: {
            textInput.text = scratchFileView.text() ?? "";
        }
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                textInput.text = "";
                scratchFileView.setText("");
            }
        }
    }
}
