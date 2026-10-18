import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    required property var store
    signal noteSelected(int noteId)

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // Search Bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            radius: Appearance.rounding.small
            color: Appearance.colors.colLayer2

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 6
                spacing: 6

                MaterialSymbol {
                    text: "search"
                    iconSize: 18
                    color: Appearance.colors.colOnLayer1
                    opacity: 0.7
                }

                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    text: root.store.searchQuery
                    color: Appearance.colors.colOnSurface
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.family: Appearance.font.family.main
                    selectByMouse: true
                    clip: true
                    onTextChanged: {
                        root.store.searchQuery = text;
                    }

                    StyledText {
                        anchors.fill: parent
                        text: Translation.tr("Search notes...")
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.family: Appearance.font.family.main
                        opacity: 0.5
                        visible: searchInput.text.length === 0
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                RippleButton {
                    visible: searchInput.text.length > 0
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    buttonRadius: 12
                    colBackground: "transparent"
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "close"
                        iconSize: 16
                        color: Appearance.colors.colOnLayer1
                    }
                    onClicked: {
                        searchInput.text = "";
                        root.store.searchQuery = "";
                    }
                }
            }
        }

        // Note List
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            StyledListView {
                id: listView
                anchors.fill: parent
                spacing: 6
                clip: true
                animateAppearance: false

                readonly property var listData: root.store.filteredNotes()

                model: ScriptModel {
                    values: listView.listData
                }

                delegate: Rectangle {
                    id: noteCard
                    required property var modelData
                    required property int index

                    width: ListView.view.width
                    implicitHeight: cardLayout.implicitHeight + 14
                    radius: Appearance.rounding.small
                    color: cardMouseArea.containsMouse ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2

                    PointingHandInteraction {}

                    MouseArea {
                        id: cardMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            root.noteSelected(noteCard.modelData.id);
                        }
                    }

                    ColumnLayout {
                        id: cardLayout
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 8
                        spacing: 3

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            MaterialSymbol {
                                visible: !!noteCard.modelData.pinned
                                text: "push_pin"
                                iconSize: 14
                                color: Appearance.colors.colPrimary
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: noteCard.modelData.title && noteCard.modelData.title.length > 0
                                    ? noteCard.modelData.title
                                    : Translation.tr("Untitled Note")
                                font.bold: true
                                font.pixelSize: Appearance.font.pixelSize.normal
                                color: Appearance.colors.colOnSurface
                                elide: Text.ElideRight
                            }

                            StyledText {
                                text: {
                                    const d = new Date(noteCard.modelData.updatedAt ?? noteCard.modelData.createdAt ?? 0);
                                    return isNaN(d.getTime()) ? "" : d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
                                }
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnLayer1
                                opacity: 0.6
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: {
                                const c = noteCard.modelData.content ?? "";
                                const lines = c.split("\n").filter(l => l.trim().length > 0);
                                return lines.length > 0 ? lines[0] : Translation.tr("No additional text");
                            }
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer1
                            opacity: 0.75
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }
                }
            }

            // Empty state placeholder
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8
                visible: listView.listData.length === 0

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.store.searchQuery.length > 0 ? "search_off" : "description"
                    iconSize: 36
                    color: Appearance.colors.colOnLayer1
                    opacity: 0.4
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.store.searchQuery.length > 0
                        ? Translation.tr("No matching notes found")
                        : Translation.tr("No notes yet. Tap + to create one!")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer1
                    opacity: 0.6
                }
            }
        }
    }

    // Floating Action Button (+)
    StyledRectangularShadow {
        target: fab
        radius: fab.buttonRadius
        blur: 0.6 * Appearance.sizes.elevationMargin
    }

    FloatingActionButton {
        id: fab
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        iconText: "add"
        onClicked: {
            const newId = root.store.createNote("", "");
            root.noteSelected(newId);
        }
    }
}
