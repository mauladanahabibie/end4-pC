import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Rectangle {
    id: root

    property string filePath: Directories.calculatorHistoryPath
    property var historyList: []

    signal itemSelected(string expression, string result)
    signal closeRequested()

    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer1
    border.width: 1
    border.color: Appearance.colors.colLayer0Border

    Component.onCompleted: {
        historyFileView.reload();
    }

    function addEntry(expr, res) {
        const item = {
            "expression": expr,
            "result": String(res),
            "timestamp": Date.now()
        };
        const updated = [item].concat(root.historyList.slice(0, 49)); // keep last 50
        root.historyList = updated;
        saveHistory();
    }

    function clearAll() {
        root.historyList = [];
        saveHistory();
    }

    function saveHistory() {
        if (historyFileView) {
            try {
                historyFileView.setText(JSON.stringify(root.historyList));
            } catch (e) {
                console.warn("[CalculatorHistory] Save error:", e);
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        // Header
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            spacing: 6

            StyledText {
                text: Translation.tr("Calculation History")
                font.bold: true
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnSurface
            }

            Item { Layout.fillWidth: true }

            RippleButton {
                visible: root.historyList.length > 0
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                buttonRadius: 13
                colBackground: "transparent"
                StyledToolTip {
                    text: Translation.tr("Clear history")
                }
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "delete_sweep"
                    iconSize: 16
                    color: Appearance.colors.colError
                }
                onClicked: root.clearAll()
            }

            RippleButton {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                buttonRadius: 13
                colBackground: "transparent"
                StyledToolTip {
                    text: Translation.tr("Close")
                }
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "close"
                    iconSize: 16
                    color: Appearance.colors.colOnLayer1
                }
                onClicked: root.closeRequested()
            }
        }

        // History List
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            StyledListView {
                id: listView
                anchors.fill: parent
                spacing: 6
                clip: true
                animateAppearance: false

                model: ScriptModel {
                    values: root.historyList
                }

                delegate: Rectangle {
                    id: historyCard
                    required property var modelData
                    width: ListView.view.width
                    implicitHeight: cardLayout.implicitHeight + 12
                    radius: Appearance.rounding.small
                    color: itemMouseArea.containsMouse ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2

                    PointingHandInteraction {}

                    MouseArea {
                        id: itemMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            root.itemSelected(historyCard.modelData.expression, historyCard.modelData.result);
                        }
                    }

                    ColumnLayout {
                        id: cardLayout
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 6
                        spacing: 2

                        StyledText {
                            Layout.fillWidth: true
                            text: historyCard.modelData.expression ?? ""
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer1
                            opacity: 0.7
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: "= " + (historyCard.modelData.result ?? "")
                            font.bold: true
                            font.pixelSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colPrimary
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            // Empty state
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 6
                visible: root.historyList.length === 0

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: "history_toggle_off"
                    iconSize: 32
                    color: Appearance.colors.colOnLayer1
                    opacity: 0.4
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("No history yet")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer1
                    opacity: 0.6
                }
            }
        }
    }

    FileView {
        id: historyFileView
        path: Qt.resolvedUrl(root.filePath)
        onLoaded: {
            const raw = historyFileView.text();
            if (!raw || raw.trim().length === 0) {
                root.historyList = [];
                return;
            }
            try {
                const parsed = JSON.parse(raw);
                if (Array.isArray(parsed)) {
                    root.historyList = parsed;
                }
            } catch (e) {
                root.historyList = [];
            }
        }
        onLoadFailed: error => {
            root.historyList = [];
            if (error === FileViewError.FileNotFound) {
                historyFileView.setText("[]");
            }
        }
    }
}
