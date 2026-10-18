import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    signal buttonPressed(string action, string value)

    readonly property var keypadRows: [
        [
            { label: "C", action: "clear", value: "C", type: "clear" },
            { label: "(", action: "append", value: "(", type: "op" },
            { label: ")", action: "append", value: ")", type: "op" },
            { label: "÷", action: "append", value: "÷", type: "op" }
        ],
        [
            { label: "7", action: "append", value: "7", type: "num" },
            { label: "8", action: "append", value: "8", type: "num" },
            { label: "9", action: "append", value: "9", type: "num" },
            { label: "×", action: "append", value: "×", type: "op" }
        ],
        [
            { label: "4", action: "append", value: "4", type: "num" },
            { label: "5", action: "append", value: "5", type: "num" },
            { label: "6", action: "append", value: "6", type: "num" },
            { label: "-", action: "append", value: "-", type: "op" }
        ],
        [
            { label: "1", action: "append", value: "1", type: "num" },
            { label: "2", action: "append", value: "2", type: "num" },
            { label: "3", action: "append", value: "3", type: "num" },
            { label: "+", action: "append", value: "+", type: "op" }
        ],
        [
            { label: "±", action: "negate", value: "±", type: "num" },
            { label: "0", action: "append", value: "0", type: "num" },
            { label: ".", action: "append", value: ".", type: "num" },
            { label: "=", action: "calculate", value: "=", type: "equals" }
        ]
    ]

    ColumnLayout {
        anchors.fill: parent
        spacing: 5

        Repeater {
            model: root.keypadRows
            RowLayout {
                id: rowLayout
                required property var modelData
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 5

                Repeater {
                    model: rowLayout.modelData
                    RippleButton {
                        id: btn
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        buttonRadius: Appearance.rounding.small

                        colBackground: {
                            if (btn.modelData.type === "equals") return Appearance.colors.colPrimary;
                            if (btn.modelData.type === "op") return Appearance.colors.colSecondaryContainer;
                            return Appearance.colors.colLayer2;
                        }

                        contentItem: StyledText {
                            anchors.centerIn: parent
                            text: btn.modelData.label
                            font.bold: btn.modelData.type === "equals" || btn.modelData.type === "clear"
                            font.pixelSize: Appearance.font.pixelSize.large
                            color: {
                                if (btn.modelData.type === "equals") return Appearance.colors.colOnPrimary;
                                if (btn.modelData.type === "clear") return Appearance.colors.colError;
                                if (btn.modelData.type === "op") return Appearance.colors.colOnSecondaryContainer;
                                return Appearance.colors.colOnSurface;
                            }
                        }

                        onClicked: {
                            root.buttonPressed(btn.modelData.action, btn.modelData.value);
                        }
                    }
                }
            }
        }
    }
}
