import QtQuick
import qs
import qs.modules.common
import qs.services

MouseArea {
    id: root
    required property string side
    required property string screenName
    property bool edgeNeedsInput: false
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
    enabled: edgeNeedsInput
    onContainsMouseChanged: GlobalStates.setFrameHover(screenName, side, containsMouse)
}
