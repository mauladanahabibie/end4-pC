pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Menu {
    id: root

    required property Item targetWidget

    padding: 6
    topPadding: 6
    bottomPadding: 6

    transformOrigin: Item.TopLeft

    enter: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "scale"
                from: 0.6
                to: 1
                duration: 500
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
            }
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: Appearance.animationCurves.expressiveEffectsDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveEffects
            }
        }
    }

    exit: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "scale"
                to: 0.85
                duration: 160
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.emphasizedAccel
            }
            NumberAnimation {
                property: "opacity"
                to: 0
                duration: 140
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.emphasizedAccel
            }
        }
    }

    background: Rectangle {
        implicitWidth: 220
        radius: Appearance.rounding.small + 4
        color: Appearance.colors.colUiPopupBackground
        border.width: 1
        border.color: Appearance.colors.colLayer0Border
    }

    component Entry: MenuItem {
        id: entry

        property string iconName: ""
        property color iconColor: Appearance.colors.colOnLayer1
        property color textColor: Appearance.colors.colOnLayer1

        visible: true
        height: visible ? implicitHeight : 0
        implicitHeight: visible ? 38 : 0
        leftPadding: 12
        rightPadding: 12
        topPadding: 0
        bottomPadding: 0

        background: Rectangle {
            radius: Appearance.rounding.small
            color: entry.highlighted && entry.enabled ? Appearance.colors.colLayer1Hover : "transparent"
        }

        contentItem: RowLayout {
            spacing: 12
            opacity: entry.enabled ? 1 : 0.38

            MaterialSymbol {
                text: entry.iconName
                iconSize: 20
                color: entry.iconColor
            }
            StyledText {
                Layout.fillWidth: true
                text: entry.text
                font.pixelSize: Appearance.font.pixelSize.small
                color: entry.textColor
                elide: Text.ElideRight
            }
        }
    }

    component Divider: MenuSeparator {
        topPadding: 4
        bottomPadding: 4
        contentItem: Rectangle {
            implicitHeight: 1
            color: Appearance.colors.colOutlineVariant
        }
    }

    Entry {
        text: (root.targetWidget && root.targetWidget.videoPath !== "" && root.targetWidget.videoValid)
            ? Translation.tr("Change Video")
            : Translation.tr("Select Video")
        iconName: "movie"
        onTriggered: {
            if (root.targetWidget) root.targetWidget.openPicker()
        }
    }

    Entry {
        text: Translation.tr("Delete Video")
        iconName: "videocam_off"
        visible: root.targetWidget && root.targetWidget.videoPath !== ""
        onTriggered: {
            if (root.targetWidget) root.targetWidget.deleteVideoMedia()
        }
    }

    Entry {
        text: Translation.tr("Delete Widget")
        iconName: "delete"
        iconColor: Appearance.m3colors.m3error
        textColor: Appearance.m3colors.m3error
        onTriggered: {
            if (root.targetWidget) root.targetWidget.requestDelete()
        }
    }

    Divider {}

    Entry {
        text: Config.options.background.widgetsLocked
            ? Translation.tr("Unlock widget positions")
            : Translation.tr("Lock widget positions")
        iconName: Config.options.background.widgetsLocked ? "lock_open" : "lock"
        onTriggered: {
            Config.options.background.widgetsLocked = !Config.options.background.widgetsLocked
        }
    }
}
