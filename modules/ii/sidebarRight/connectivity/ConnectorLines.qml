import QtQuick
import QtQuick.Shapes
import qs.modules.common
import qs.modules.common.functions

Shape {
    id: root

    property real hubX: 0
    property real hubY: 0
    property real hubRadius: 30
    property color strokeColor: ColorUtils.transparentize(Appearance.colors.colLayer0Border, 0.35)
    property real strokeWidth: 1.5

    // Satellite card items to connect
    property Item cardTopLeft: null
    property Item cardBottomLeft: null
    property Item cardTopRight: null
    property Item cardBottomRight: null
    property Item cardBottomCenter: null

    layer.enabled: true
    layer.smooth: true
    layer.samples: 4
    preferredRendererType: Shape.CurveRenderer

    readonly property bool hasTopRow: cardTopLeft && cardTopRight && cardTopLeft.visible && cardTopRight.visible
    readonly property bool hasBottomRow: cardBottomLeft && cardBottomRight && cardBottomLeft.visible && cardBottomRight.visible
    readonly property bool hasSummary: cardBottomCenter && cardBottomCenter.visible

    readonly property real row1Y: hasTopRow ? cardTopLeft.connectionPointY : 0
    readonly property real row2Y: hasBottomRow ? cardBottomLeft.connectionPointY : 0
    readonly property real summaryY: hasSummary ? cardBottomCenter.connectionPointY : 0

    // Central Backbone Spine (Vertical)
    ShapePath {
        strokeColor: (root.hasTopRow || root.hasSummary) ? root.strokeColor : "transparent"
        strokeWidth: root.strokeWidth
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        startX: root.hubX
        startY: root.hubY

        PathLine {
            x: root.hubX
            y: root.hasSummary ? root.summaryY : (root.hasBottomRow ? root.row2Y : (root.hasTopRow ? root.row1Y : root.hubY))
        }
    }

    // Top-Left Horizontal Branch
    ShapePath {
        strokeColor: root.hasTopRow ? root.strokeColor : "transparent"
        strokeWidth: root.strokeWidth
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        startX: root.hubX
        startY: root.row1Y

        PathLine {
            x: root.hasTopRow ? root.cardTopLeft.connectionPointX : root.hubX
            y: root.row1Y
        }
    }

    // Top-Right Horizontal Branch
    ShapePath {
        strokeColor: root.hasTopRow ? root.strokeColor : "transparent"
        strokeWidth: root.strokeWidth
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        startX: root.hubX
        startY: root.row1Y

        PathLine {
            x: root.hasTopRow ? root.cardTopRight.connectionPointX : root.hubX
            y: root.row1Y
        }
    }

    // Bottom-Left Horizontal Branch
    ShapePath {
        strokeColor: root.hasBottomRow ? root.strokeColor : "transparent"
        strokeWidth: root.strokeWidth
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        startX: root.hubX
        startY: root.row2Y

        PathLine {
            x: root.hasBottomRow ? root.cardBottomLeft.connectionPointX : root.hubX
            y: root.row2Y
        }
    }

    // Bottom-Right Horizontal Branch
    ShapePath {
        strokeColor: root.hasBottomRow ? root.strokeColor : "transparent"
        strokeWidth: root.strokeWidth
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        startX: root.hubX
        startY: root.row2Y

        PathLine {
            x: root.hasBottomRow ? root.cardBottomRight.connectionPointX : root.hubX
            y: root.row2Y
        }
    }
}
