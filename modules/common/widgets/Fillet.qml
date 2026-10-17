import QtQuick
import QtQuick.Shapes

Shape {
    id: fillet
    property real r: 0
    property bool flipH: false
    property bool flipV: false
    property color fillColor: "transparent"
    width: r
    height: r
    visible: r > 0
    layer.enabled: true
    layer.samples: 4
    transform: Scale {
        origin.x: fillet.width / 2
        origin.y: fillet.height / 2
        xScale: fillet.flipH ? -1 : 1
        yScale: fillet.flipV ? -1 : 1
    }
    ShapePath {
        fillColor: fillet.fillColor
        strokeWidth: -1
        startX: fillet.r
        startY: fillet.r
        PathLine { x: 0; y: fillet.r }
        PathArc {
            x: fillet.r
            y: 0
            radiusX: fillet.r
            radiusY: fillet.r
            direction: PathArc.Counterclockwise
        }
        PathLine { x: fillet.r; y: fillet.r }
    }
}
