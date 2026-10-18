import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    readonly property var tabButtonList: [
        { "name": Translation.tr("Notes"), "icon": "description" },
        { "name": Translation.tr("Scratchpad"), "icon": "edit_note" }
    ]

    NotesStore {
        id: notesStore
    }

    Keys.onPressed: event => {
        if ((event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp) && event.modifiers === Qt.NoModifier) {
            if (event.key === Qt.Key_PageDown) {
                tabBar.incrementCurrentIndex();
            } else if (event.key === Qt.Key_PageUp) {
                tabBar.decrementCurrentIndex();
            }
            event.accepted = true;
            return;
        }

        // Return from note editor on Escape (or dismiss delete dialog if open)
        if (event.key === Qt.Key_Escape && notesStore.activeNoteId !== -1 && swipeView.currentIndex === 0) {
            if (editorLoader.item && editorLoader.item.showDeleteDialog) {
                editorLoader.item.showDeleteDialog = false;
                event.accepted = true;
                return;
            }
            notesStore.flush();
            notesStore.activeNoteId = -1;
            event.accepted = true;
            return;
        }

        // Create new note on N when in list view
        if (event.key === Qt.Key_N && notesStore.activeNoteId === -1 && swipeView.currentIndex === 0) {
            notesStore.createNote("", "");
            event.accepted = true;
            return;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        SecondaryTabBar {
            id: tabBar
            currentIndex: swipeView.currentIndex

            Repeater {
                model: root.tabButtonList
                delegate: SecondaryTabButton {
                    buttonText: modelData.name
                    buttonIcon: modelData.icon
                }
            }
        }

        SwipeView {
            id: swipeView
            Layout.topMargin: 8
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10
            clip: true
            currentIndex: tabBar.currentIndex

            // Tab 0: Multi-note Manager (List / Editor)
            Item {
                id: notesTabContainer

                NoteListView {
                    anchors.fill: parent
                    visible: notesStore.activeNoteId === -1
                    store: notesStore
                    onNoteSelected: noteId => {
                        notesStore.activeNoteId = noteId;
                    }
                }

                Loader {
                    id: editorLoader
                    anchors.fill: parent
                    active: notesStore.activeNoteId !== -1
                    visible: active
                    sourceComponent: NoteEditorView {
                        store: notesStore
                        noteId: notesStore.activeNoteId
                        onBackRequested: {
                            notesStore.activeNoteId = -1;
                        }
                    }
                }
            }

            // Tab 1: Direct Scratchpad
            ScratchpadView {
                id: scratchpadTab
            }
        }
    }
}
