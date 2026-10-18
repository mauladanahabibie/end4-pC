import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property int currentIndex: 0
    property bool expanded: false
    property color colToggled: Appearance.colors.colSecondaryContainer
    default property alias data: tabBarColumn.data  
    implicitHeight: tabBarColumn.implicitHeight
    implicitWidth: tabBarColumn.implicitWidth
    Layout.topMargin: 25

    Rectangle {
        property real itemHeight: {
            for (let i = 0; i < tabBarColumn.children.length; i++) {
                const c = tabBarColumn.children[i];
                if (c && c.baseSize !== undefined) return c.baseSize;
            }
            return 56;
        }
        property real baseHighlightHeight: {
            for (let i = 0; i < tabBarColumn.children.length; i++) {
                const c = tabBarColumn.children[i];
                if (c && c.baseHighlightHeight !== undefined) return c.baseHighlightHeight;
            }
            return 56;
        }
        anchors {
            top: tabBarColumn.top
            left: tabBarColumn.left
            topMargin: itemHeight * root.currentIndex + (root.expanded ? 0 : ((itemHeight - baseHighlightHeight) / 2))
        }
        radius: Config.options.settings.style === "minimal" ? Appearance.rounding.small : Appearance.rounding.full
        color: root.colToggled
        implicitHeight: root.expanded ? itemHeight : baseHighlightHeight
        implicitWidth: {
            for (let i = 0; i < tabBarColumn.children.length; i++) {
                const c = tabBarColumn.children[i];
                if (c && c.visualWidth !== undefined) return c.visualWidth;
            }
            return 100;
        }

        Behavior on anchors.topMargin {
            NumberAnimation {
                duration: Appearance.animationCurves.expressiveFastSpatialDuration
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
            }
        }
    }

    ColumnLayout {
        id: tabBarColumn
        anchors.fill: parent
        spacing: 0
    }
}
