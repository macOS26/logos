import Foundation

func getPointPositionExternal(_ pointID: PointID, in document: VectorDocument) -> VectorPoint? {
    for unifiedObject in document.unifiedObjects {
        if case .shape(let shape) = unifiedObject.objectType,
           shape.id == pointID.shapeID {
            guard pointID.elementIndex < shape.path.elements.count else { return nil }
            let element = shape.path.elements[pointID.elementIndex]

            switch element {
            case .move(let to), .line(let to):
                return to
            case .curve(let to, _, _), .quadCurve(let to, _):
                return to
            case .close:
                return nil
            }
        }
    }
    return nil
}
