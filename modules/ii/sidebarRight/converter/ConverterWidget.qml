import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "ConverterEngine.js" as ConverterEngine

Item {
    id: root

    property string currentCategoryId: "length"
    readonly property var currentCategory: ConverterEngine.CATEGORIES.find(c => c.id === root.currentCategoryId) ?? ConverterEngine.CATEGORIES[0]

    property string fromUnitId: "m"
    property string toUnitId: "km"
    property string inputValue: "100"
    readonly property string convertedResult: ConverterEngine.convert(root.currentCategoryId, root.fromUnitId, root.toUnitId, root.inputValue)

    property bool pickingFrom: false
    property bool showUnitPicker: false
    property bool copiedFeedback: false

    function selectCategory(catId) {
        root.currentCategoryId = catId;
        const cat = ConverterEngine.CATEGORIES.find(c => c.id === catId);
        if (cat && cat.units && cat.units.length >= 2) {
            root.fromUnitId = cat.units[0].id;
            root.toUnitId = cat.units[1].id;
        }
    }

    onCurrentCategoryIdChanged: {
        const cat = ConverterEngine.CATEGORIES.find(c => c.id === root.currentCategoryId);
        if (cat && cat.units && cat.units.length >= 2) {
            const hasFrom = cat.units.some(u => u.id === root.fromUnitId);
            const hasTo = cat.units.some(u => u.id === root.toUnitId);
            if (!hasFrom || !hasTo) {
                root.fromUnitId = cat.units[0].id;
                root.toUnitId = cat.units[1].id;
            }
        }
    }

    Timer {
        id: copyFeedbackTimer
        interval: 1500
        repeat: false
        onTriggered: root.copiedFeedback = false
    }

    function swapUnits() {
        const tmp = root.fromUnitId;
        root.fromUnitId = root.toUnitId;
        root.toUnitId = tmp;
    }

    function getUnitName(catId, uId) {
        const cat = ConverterEngine.CATEGORIES.find(c => c.id === catId);
        if (!cat) return uId;
        const u = cat.units.find(item => item.id === uId);
        return u ? u.name : uId;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        // Category Pills Row
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 34

            StyledFlickable {
                anchors.fill: parent
                contentWidth: categoryRow.implicitWidth
                contentHeight: height
                flickableDirection: Flickable.HorizontalFlick
                clip: true

                RowLayout {
                    id: categoryRow
                    height: parent.height
                    spacing: 6

                    Repeater {
                        model: ConverterEngine.CATEGORIES
                        RippleButton {
                            id: catBtn
                            required property var modelData
                            Layout.preferredHeight: 28
                            Layout.preferredWidth: catBtnLayout.implicitWidth + 16
                            buttonRadius: 14

                            colBackground: root.currentCategoryId === catBtn.modelData.id
                                ? Appearance.colors.colSecondaryContainer
                                : Appearance.colors.colLayer2

                            contentItem: RowLayout {
                                id: catBtnLayout
                                anchors.centerIn: parent
                                spacing: 4

                                MaterialSymbol {
                                    text: catBtn.modelData.icon
                                    iconSize: 14
                                    color: root.currentCategoryId === catBtn.modelData.id
                                        ? Appearance.colors.colOnSecondaryContainer
                                        : Appearance.colors.colOnLayer1
                                }

                                StyledText {
                                    text: Translation.tr(catBtn.modelData.name)
                                    font.bold: root.currentCategoryId === catBtn.modelData.id
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: root.currentCategoryId === catBtn.modelData.id
                                        ? Appearance.colors.colOnSecondaryContainer
                                        : Appearance.colors.colOnLayer1
                                }
                            }

                            onClicked: {
                                root.selectCategory(catBtn.modelData.id);
                            }
                        }
                    }
                }
            }
        }

        // "From" Input Card
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Appearance.colors.colLayer2
            radius: Appearance.rounding.small

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 4

                // Unit selection button
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    StyledText {
                        text: Translation.tr("From")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer1
                        opacity: 0.6
                    }

                    Item { Layout.fillWidth: true }

                    RippleButton {
                        Layout.preferredHeight: 24
                        Layout.preferredWidth: fromBtnLayout.implicitWidth + 12
                        buttonRadius: 12
                        colBackground: Appearance.colors.colLayer1

                        contentItem: RowLayout {
                            id: fromBtnLayout
                            anchors.centerIn: parent
                            spacing: 4

                            StyledText {
                                text: root.getUnitName(root.currentCategoryId, root.fromUnitId)
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnSurface
                            }

                            MaterialSymbol {
                                text: "expand_more"
                                iconSize: 14
                                color: Appearance.colors.colOnLayer1
                            }
                        }

                        onClicked: {
                            root.pickingFrom = true;
                            root.showUnitPicker = true;
                        }
                    }
                }

                // Numeric input
                TextInput {
                    id: valInput
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    text: root.inputValue
                    font.bold: true
                    font.pixelSize: 22
                    font.family: Appearance.font.family.main
                    color: Appearance.colors.colOnSurface
                    selectByMouse: true
                    verticalAlignment: Text.AlignVCenter
                    onTextChanged: root.inputValue = text

                    StyledText {
                        anchors.fill: parent
                        text: "0"
                        font.bold: true
                        font.pixelSize: 22
                        font.family: Appearance.font.family.main
                        color: Appearance.colors.colOnLayer1
                        opacity: 0.3
                        visible: valInput.text.length === 0
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        // Swap Units Row
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 28

            RippleButton {
                anchors.centerIn: parent
                width: 28
                height: 28
                buttonRadius: 14
                colBackground: Appearance.colors.colSecondaryContainer
                StyledToolTip {
                    text: Translation.tr("Swap units")
                }
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "swap_vert"
                    iconSize: 16
                    color: Appearance.colors.colOnSecondaryContainer
                }
                onClicked: root.swapUnits()
            }
        }

        // "To" Result Card
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Appearance.colors.colLayer2
            radius: Appearance.rounding.small

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 4

                // Unit selection button & Copy
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    StyledText {
                        text: Translation.tr("To")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer1
                        opacity: 0.6
                    }

                    Item { Layout.fillWidth: true }

                    RippleButton {
                        Layout.preferredHeight: 24
                        Layout.preferredWidth: toBtnLayout.implicitWidth + 12
                        buttonRadius: 12
                        colBackground: Appearance.colors.colLayer1

                        contentItem: RowLayout {
                            id: toBtnLayout
                            anchors.centerIn: parent
                            spacing: 4

                            StyledText {
                                text: root.getUnitName(root.currentCategoryId, root.toUnitId)
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnSurface
                            }

                            MaterialSymbol {
                                text: "expand_more"
                                iconSize: 14
                                color: Appearance.colors.colOnLayer1
                            }
                        }

                        onClicked: {
                            root.pickingFrom = false;
                            root.showUnitPicker = true;
                        }
                    }

                    RippleButton {
                        visible: root.convertedResult.length > 0
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
                            iconSize: 15
                            color: root.copiedFeedback ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
                        }
                        onClicked: {
                            Quickshell.clipboardText = root.convertedResult;
                            root.copiedFeedback = true;
                            copyFeedbackTimer.restart();
                        }
                    }
                }

                // Result display
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    StyledText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.convertedResult.length > 0 ? root.convertedResult : "0"
                        font.bold: true
                        font.pixelSize: 22
                        color: Appearance.colors.colPrimary
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    // Unit Picker Modal Overlay
    Item {
        anchors.fill: parent
        z: 99
        visible: opacity > 0
        opacity: root.showUnitPicker ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.55)
            radius: Appearance.rounding.normal

            MouseArea {
                anchors.fill: parent
                onClicked: root.showUnitPicker = false
            }

            Rectangle {
                anchors.centerIn: parent
                width: parent.width - 24
                height: Math.min(parent.height - 24, 260)
                color: Appearance.colors.colLayer1
                radius: Appearance.rounding.normal
                border.width: 1
                border.color: Appearance.colors.colLayer0Border

                MouseArea {
                    anchors.fill: parent // prevent event bubbling
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28

                        StyledText {
                            text: root.pickingFrom ? Translation.tr("Select 'From' Unit") : Translation.tr("Select 'To' Unit")
                            font.bold: true
                            font.pixelSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnSurface
                        }

                        Item { Layout.fillWidth: true }

                        RippleButton {
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
                            onClicked: root.showUnitPicker = false
                        }
                    }

                    StyledListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 4
                        clip: true

                        model: ScriptModel {
                            values: root.currentCategory.units
                        }

                        delegate: Rectangle {
                            id: unitItem
                            required property var modelData
                            width: ListView.view.width
                            implicitHeight: 34
                            radius: Appearance.rounding.small
                            color: {
                                const selected = (root.pickingFrom ? root.fromUnitId : root.toUnitId) === unitItem.modelData.id;
                                if (selected) return Appearance.colors.colSecondaryContainer;
                                return itemMA.containsMouse ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2;
                            }

                            PointingHandInteraction {}

                            MouseArea {
                                id: itemMA
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    if (root.pickingFrom) {
                                        root.fromUnitId = unitItem.modelData.id;
                                    } else {
                                        root.toUnitId = unitItem.modelData.id;
                                    }
                                    root.showUnitPicker = false;
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 6

                                StyledText {
                                    Layout.fillWidth: true
                                    text: unitItem.modelData.name
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    color: (root.pickingFrom ? root.fromUnitId : root.toUnitId) === unitItem.modelData.id
                                        ? Appearance.colors.colOnSecondaryContainer
                                        : Appearance.colors.colOnSurface
                                }

                                MaterialSymbol {
                                    visible: (root.pickingFrom ? root.fromUnitId : root.toUnitId) === unitItem.modelData.id
                                    text: "check"
                                    iconSize: 16
                                    color: Appearance.colors.colPrimary
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
