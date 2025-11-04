import Foundation

extension VectorDocument {
    /// Updates the anchor point type for a specific point in a shape
    func updatePointAnchorType(pointID: PointID, newType: AnchorPointType) {
        updateShapeByID(pointID.shapeID) { shape in
            // Get the element at the specified index
            guard pointID.elementIndex < shape.path.elements.count else { return }

            // Update the point type
            shape.path.elements[pointID.elementIndex].setPointType(newType)
            shape.updateBounds()
        }
    }

    /// Updates anchor point type for multiple coincident points
    func updateCoincidentPointsAnchorType(pointIDs: Set<PointID>, newType: AnchorPointType) {
        for pointID in pointIDs {
            updatePointAnchorType(pointID: pointID, newType: newType)
        }
    }

    /// Gets the anchor point type for a specific point
    func getPointAnchorType(pointID: PointID) -> AnchorPointType? {
        guard let object = snapshot.objects[pointID.shapeID] else { return nil }

        switch object.objectType {
        case .shape(let shape):
            guard pointID.elementIndex < shape.path.elements.count else { return nil }
            return shape.path.elements[pointID.elementIndex].pointType

        default:
            return nil
        }
    }
}
