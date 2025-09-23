//
//  PointPositionUtility.swift
//  logos inkpen.io
//
//  Static utility to get point position for shapes
//

import Foundation

/// Static utility to get point position for use in views
func getPointPositionExternal(_ pointID: PointID, in document: VectorDocument) -> VectorPoint? {
    // Use unified objects to find the shape
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