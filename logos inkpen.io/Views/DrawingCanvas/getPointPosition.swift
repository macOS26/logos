//
//  getPointPositionStatic.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/13/25.
//

/// Static utility to get point position for use in views
func getPointPositionExternal(_ pointID: PointID, in document: VectorDocument) -> VectorPoint? {
    for layer in document.layers {
        if let shape = layer.shapes.first(where: { $0.id == pointID.shapeID }) {
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
