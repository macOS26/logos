import SwiftUI

struct PointID: Hashable {
    let shapeID: UUID
    let pathIndex: Int
    let elementIndex: Int
}

struct HandleID: Hashable {
    let shapeID: UUID
    let pathIndex: Int
    let elementIndex: Int
    let handleType: HandleType
}

enum HandleType {
    case control1, control2
}

func findCoincidentPoints(to targetPointID: PointID, in document: VectorDocument, tolerance: Double = 1.0) -> Set<PointID> {
    guard let targetPosition = getPointPositionExternal(targetPointID, in: document) else { return [] }

    var coincidentPoints: Set<PointID> = []
    let targetPoint = CGPoint(x: targetPosition.x, y: targetPosition.y)

    for layerIndex in document.snapshot.layers.indices {
        let layer = document.snapshot.layers[layerIndex]
        if !layer.isVisible { continue }

        let shapes = document.getShapesForLayer(layerIndex)
        for shape in shapes {
            if !shape.isVisible { continue }

            for (elementIndex, element) in shape.path.elements.enumerated() {
                let pointID = PointID(
                    shapeID: shape.id,
                    pathIndex: 0,
                    elementIndex: elementIndex
                )

                if pointID == targetPointID { continue }

                let elementPoint: CGPoint?
                switch element {
                case .move(let to), .line(let to):
                    elementPoint = CGPoint(x: to.x, y: to.y)
                case .curve(let to, _, _), .quadCurve(let to, _):
                    elementPoint = CGPoint(x: to.x, y: to.y)
                case .close:
                    elementPoint = nil
                }

                if let checkPoint = elementPoint {
                    let distance = sqrt(pow(targetPoint.x - checkPoint.x, 2) + pow(targetPoint.y - checkPoint.y, 2))
                    if distance <= tolerance {
                        coincidentPoints.insert(pointID)
                    }
                }
            }
        }
    }

    return coincidentPoints
}
