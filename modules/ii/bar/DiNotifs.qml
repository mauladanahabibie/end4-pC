import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: diNotifsRoot
    required property Item di
    property var notif: di?.activeDynamicNotification ?? null
    readonly property bool isMaterial: di?.isMaterial ?? false
    anchors.fill: parent

    // App Icon or Avatar container
    Item {
        id: notifIconArea
        width: 24
        height: 24
        anchors {
            left: parent.left
            leftMargin: isMaterial ? 4 : 8
            verticalCenter: parent.verticalCenter
        }

        // 1. Notification image / avatar if provided
        Rectangle {
            id: notifImageContainer
            anchors.fill: parent
            radius: di?.calculateImageRadius ? di.calculateImageRadius(height) : (height / 2)
            color: Appearance.colors.colLayer1
            visible: (notif?.image ?? "") !== ""

            Behavior on radius {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
                }
            }

            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: notifImageContainer.width
                    height: notifImageContainer.height
                    radius: notifImageContainer.radius
                }
            }

            Image {
                anchors.fill: parent
                source: notif?.image ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }
        }

        // 2. App Icon via Quickshell IconImage
        IconImage {
            id: notifAppIcon
            anchors.centerIn: parent
            implicitWidth: 20
            implicitHeight: 20
            asynchronous: true
            source: (notif?.appIcon ?? "") !== "" ? SystemAppearance.iconPath(notif.appIcon, "image-missing") : ""
            visible: !notifImageContainer.visible && (notif?.appIcon ?? "") !== "" && source != ""
        }

        // 3. Fallback Material Symbol
        MaterialShapeWrappedMaterialSymbol {
            anchors.fill: parent
            wrappedShape: MaterialShape.Shape.Cookie12Sided
            color: Appearance.colors.colPrimary
            colSymbol: Appearance.colors.colOnPrimary
            text: NotificationUtils.findSuitableMaterialSymbol(notif?.summary || notif?.appName || "")
            iconSize: 14
            fill: 1
            padding: 4
            visible: !notifImageContainer.visible && !notifAppIcon.visible
        }
    }

    // Two-line notification content
    ColumnLayout {
        id: notifTextColumn
        anchors {
            left: notifIconArea.right
            leftMargin: 8
            right: rightSideRow.left
            rightMargin: 8
            verticalCenter: parent.verticalCenter
        }
        spacing: 1

        StyledText {
            Layout.fillWidth: true
            text: {
                const s = (notif?.summary ?? "").trim()
                if (s !== "") return s.replace(/[\r\n]+/g, " ")
                return notif?.appName ?? Translation.tr("Notification")
            }
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer0
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
            maximumLineCount: 1
        }

        StyledText {
            Layout.fillWidth: true
            visible: (notif?.body ?? "").trim() !== ""
            text: (notif?.body ?? "").replace(/[\r\n]+/g, " ")
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colOnLayer0
            opacity: 0.8
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
            maximumLineCount: 1
        }
    }

    // Right side: Timestamp & dismiss icon on hover
    RowLayout {
        id: rightSideRow
        anchors {
            right: parent.right
            rightMargin: 10
            verticalCenter: parent.verticalCenter
        }
        spacing: 4

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: DateTime.time
            font.pixelSize: Appearance.font.pixelSize.smallest
            font.features: { "tnum": 1 }
            color: Appearance.colors.colOnLayer0
            opacity: 0.7
        }

        MaterialSymbol {
            Layout.alignment: Qt.AlignVCenter
            text: "close"
            iconSize: 14
            color: Appearance.colors.colOnLayer0
            opacity: 0.6
            visible: notifHoverHandler.hovered
        }
    }

    HoverHandler {
        id: notifHoverHandler
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (di) di.activeDynamicNotification = null
            GlobalStates.sidebarRightOpen = true
        }
    }
}