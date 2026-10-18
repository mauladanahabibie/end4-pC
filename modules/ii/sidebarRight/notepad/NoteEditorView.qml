import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    required property var store
    property int noteId: -1
    signal backRequested()

    readonly property var currentNote: root.store.getNoteById(root.noteId)
    property bool showDeleteDialog: false

    onNoteIdChanged: {
        if (currentNote) {
            titleInput.text = currentNote.title ?? "";
            contentInput.text = currentNote.content ?? "";
        }
    }

    Component.onCompleted: {
        if (currentNote) {
            titleInput.text = currentNote.title ?? "";
            contentInput.text = currentNote.content ?? "";
            if (!currentNote.title || currentNote.title.length === 0) {
                titleInput.forceActiveFocus();
            } else {
                contentInput.forceActiveFocus();
            }
        }
    }

    Component.onDestruction: {
        syncChanges();
        root.store.flush();
    }

    function syncChanges() {
        if (root.noteId !== -1 && currentNote) {
            root.store.updateNote(root.noteId, titleInput.text, contentInput.text);
        }
    }

    readonly property bool isCurrentPinned: Boolean(root.currentNote && root.currentNote.pinned)

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        // Top Toolbar
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            spacing: 4

            RippleButton {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                buttonRadius: 16
                colBackground: "transparent"
                StyledToolTip {
                    text: Translation.tr("Back to notes")
                }
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "arrow_back"
                    iconSize: 18
                    color: Appearance.colors.colOnLayer1
                }
                onClicked: {
                    root.syncChanges();
                    root.store.flush();
                    root.backRequested();
                }
            }

            Item { Layout.fillWidth: true }

            // Pin button
            RippleButton {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                buttonRadius: 16
                colBackground: root.isCurrentPinned
                    ? Appearance.colors.colSecondaryContainer
                    : "transparent"
                StyledToolTip {
                    text: root.isCurrentPinned
                        ? Translation.tr("Unpin note")
                        : Translation.tr("Pin note")
                }
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "push_pin"
                    iconSize: 18
                    color: root.isCurrentPinned
                        ? Appearance.colors.colPrimary
                        : Appearance.colors.colOnLayer1
                }
                onClicked: {
                    root.store.togglePin(root.noteId);
                }
            }

            // Delete button
            RippleButton {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                buttonRadius: 16
                colBackground: "transparent"
                StyledToolTip {
                    text: Translation.tr("Delete note")
                }
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "delete"
                    iconSize: 18
                    color: Appearance.colors.colError
                }
                onClicked: {
                    root.showDeleteDialog = true;
                }
            }
        }

        // Title Input Field
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            color: Appearance.colors.colLayer2
            radius: Appearance.rounding.small

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10

                TextInput {
                    id: titleInput
                    Layout.fillWidth: true
                    font.bold: true
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.family: Appearance.font.family.main
                    color: Appearance.colors.colOnSurface
                    selectByMouse: true
                    clip: true
                    onTextEdited: root.syncChanges()

                    StyledText {
                        anchors.fill: parent
                        text: Translation.tr("Note title...")
                        color: Appearance.colors.colOnLayer1
                        font.bold: true
                        font.pixelSize: Appearance.font.pixelSize.large
                        font.family: Appearance.font.family.main
                        opacity: 0.4
                        visible: titleInput.text.length === 0
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        // Multiline Body Editor
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
                contentHeight: Math.max(height, contentInput.implicitHeight)

                TextEdit {
                    id: contentInput
                    width: flickable.width
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                    color: Appearance.colors.colOnSurface
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.family: Appearance.font.family.main
                    cursorVisible: true
                    onTextEdited: root.syncChanges()

                    StyledText {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        text: Translation.tr("Start typing note here...")
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.family: Appearance.font.family.main
                        opacity: 0.4
                        visible: contentInput.text.length === 0
                    }
                }
            }
        }

        // Bottom Stats Bar
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 20
            spacing: 8

            StyledText {
                text: {
                    const text = contentInput.text.trim();
                    const words = text.length === 0 ? 0 : text.split(/\s+/).length;
                    return Translation.tr("%1 words • %2 chars").arg(words).arg(contentInput.text.length);
                }
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer1
                opacity: 0.6
            }

            Item { Layout.fillWidth: true }

            StyledText {
                text: root.store.isSaving
                    ? Translation.tr("Saving...")
                    : (root.store.hasUnsavedChanges ? Translation.tr("Unsaved") : Translation.tr("Saved"))
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: root.store.hasUnsavedChanges ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                opacity: 0.7
            }
        }
    }

    // Delete Confirmation Dialog Overlay
    Item {
        anchors.fill: parent
        z: 999
        visible: opacity > 0
        opacity: root.showDeleteDialog ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.55)
            radius: Appearance.rounding.normal

            MouseArea {
                anchors.fill: parent
                onClicked: root.showDeleteDialog = false
            }

            Rectangle {
                anchors.centerIn: parent
                width: parent.width - 40
                implicitHeight: dialogLayout.implicitHeight + 24
                color: Appearance.colors.colLayer1
                radius: Appearance.rounding.normal
                border.width: 1
                border.color: Appearance.colors.colLayer0Border

                MouseArea {
                    anchors.fill: parent // prevent click bubbling to backdrop
                }

                ColumnLayout {
                    id: dialogLayout
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 16
                    spacing: 12

                    StyledText {
                        text: Translation.tr("Delete Note?")
                        font.bold: true
                        font.pixelSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colOnSurface
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Are you sure you want to delete \"%1\"? This cannot be undone.").arg(titleInput.text.length > 0 ? titleInput.text : Translation.tr("Untitled Note"))
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnLayer1
                        wrapMode: Text.Wrap
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        spacing: 8

                        Item { Layout.fillWidth: true }

                        DialogButton {
                            buttonText: Translation.tr("Cancel")
                            onClicked: root.showDeleteDialog = false
                        }

                        DialogButton {
                            buttonText: Translation.tr("Delete")
                            colBackground: ColorUtils.transparentize(Appearance.colors.colError, 0.8)
                            colEnabled: Appearance.colors.colError
                            onClicked: {
                                root.showDeleteDialog = false;
                                root.store.deleteNote(root.noteId);
                                root.backRequested();
                            }
                        }
                    }
                }
            }
        }
    }
}
