import Foundation

func getPointPositionExternal(_ pointID: PointID, in document: VectorDocument) -> VectorPoint? {
    for object in document.snapshot.objects.values {
        if case .shape(let shape) = object.objectType,
           shape.id == pointID.shapeID {
            guard pointID.elementIndex < shape.path.elements.count else { return nil }
            let element = shape.path.elements[pointID.elementIndex]

            switch element {
            case .move(let to):
                return to
            case .line(let to, _):
                return to
            case .curve(let to, _, _, _):
                return to
            case .quadCurve(let to, _, _):
                return to
            case .close:
                return nil
            }
        }
    }
    return nil
}
