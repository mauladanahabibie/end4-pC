import QtQuick
import QtQuick.Shapes
import qs.modules.common
import qs.modules.common.functions

Shape {
    id: root

    property real hubX: 0
    property real hubY: 0
    property real hubRadius: 68
    property color strokeColor: ColorUtils.transparentize(Appearance.colors.colLayer0Border, 0.25)
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

    function getPoints(card, isLeft) {
        if (!card || !card.visible) {
            return { valid: false, sx: 0, sy: 0, ex: 0, ey: 0, c1x: 0, c1y: 0, c2x: 0, c2y: 0 };
        }

        const sx = card.connectionPointX;
        const sy = card.connectionPointY;

        if (card.anchorSide === "top") {
            const ex = root.hubX;
            const ey = root.hubY + root.hubRadius;
            return {
                valid: true,
                sx: sx,
                sy: sy,
                ex: ex,
                ey: ey,
                c1x: sx,
                c1y: sy - 14,
                c2x: ex,
                c2y: ey + 14
            };
        }

        const angle = Math.atan2(sy - root.hubY, sx - root.hubX);
        const ex = root.hubX + root.hubRadius * Math.cos(angle);
        const ey = root.hubY + root.hubRadius * Math.sin(angle);

        const dx = ex - sx;
        const dy = ey - sy;

        // Smooth S-curve control points
        const c1x = sx + dx * 0.45;
        const c1y = sy;
        const c2x = ex - dx * 0.15;
        const c2y = ey;

        return {
            valid: true,
            sx: sx,
            sy: sy,
            ex: ex,
            ey: ey,
            c1x: c1x,
            c1y: c1y,
            c2x: c2x,
            c2y: c2y
        };
    }

    // Top-Left Line
    readonly property var ptTL: getPoints(cardTopLeft, true)
    ShapePath {
        strokeColor: root.ptTL.valid ? root.strokeColor : "transparent"
        strokeWidth: root.ptTL.valid ? root.strokeWidth : 0
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        startX: root.ptTL.sx
        startY: root.ptTL.sy

        PathCubic {
            x: root.ptTL.ex
            y: root.ptTL.ey
            control1X: root.ptTL.c1x
            control1Y: root.ptTL.c1y
            control2X: root.ptTL.c2x
            control2Y: root.ptTL.c2y
        }
    }

    // Bottom-Left Line
    readonly property var ptBL: getPoints(cardBottomLeft, true)
    ShapePath {
        strokeColor: root.ptBL.valid ? root.strokeColor : "transparent"
        strokeWidth: root.ptBL.valid ? root.strokeWidth : 0
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        startX: root.ptBL.sx
        startY: root.ptBL.sy

        PathCubic {
            x: root.ptBL.ex
            y: root.ptBL.ey
            control1X: root.ptBL.c1x
            control1Y: root.ptBL.c1y
            control2X: root.ptBL.c2x
            control2Y: root.ptBL.c2y
        }
    }

    // Top-Right Line
    readonly property var ptTR: getPoints(cardTopRight, false)
    ShapePath {
        strokeColor: root.ptTR.valid ? root.strokeColor : "transparent"
        strokeWidth: root.ptTR.valid ? root.strokeWidth : 0
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        startX: root.ptTR.sx
        startY: root.ptTR.sy

        PathCubic {
            x: root.ptTR.ex
            y: root.ptTR.ey
            control1X: root.ptTR.c1x
            control1Y: root.ptTR.c1y
            control2X: root.ptTR.c2x
            control2Y: root.ptTR.c2y
        }
    }

    // Bottom-Right Line
    readonly property var ptBR: getPoints(cardBottomRight, false)
    ShapePath {
        strokeColor: root.ptBR.valid ? root.strokeColor : "transparent"
        strokeWidth: root.ptBR.valid ? root.strokeWidth : 0
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        startX: root.ptBR.sx
        startY: root.ptBR.sy

        PathCubic {
            x: root.ptBR.ex
            y: root.ptBR.ey
            control1X: root.ptBR.c1x
            control1Y: root.ptBR.c1y
            control2X: root.ptBR.c2x
            control2Y: root.ptBR.c2y
        }
    }

    // Bottom-Center Line
    readonly property var ptBC: getPoints(cardBottomCenter, false)
    ShapePath {
        strokeColor: root.ptBC.valid ? root.strokeColor : "transparent"
        strokeWidth: root.ptBC.valid ? root.strokeWidth : 0
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        startX: root.ptBC.sx
        startY: root.ptBC.sy

        PathCubic {
            x: root.ptBC.ex
            y: root.ptBC.ey
            control1X: root.ptBC.c1x
            control1Y: root.ptBC.c1y
            control2X: root.ptBC.c2x
            control2Y: root.ptBC.c2y
        }
    }
}
