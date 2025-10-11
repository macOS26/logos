
import SwiftUI


extension VectorDocument {

    func getAllShapes() -> [VectorShape] {
        var allShapes: [VectorShape] = []
        for unifiedObject in unifiedObjects {
            if case .shape(let shape) = unifiedObject.objectType {
                allShapes.append(shape)
            }
        }
        return allShapes
    }

    func getTotalShapeCount() -> Int {
        return unifiedObjects.reduce(0) { count, unifiedObject in
            if case .shape(_) = unifiedObject.objectType {
                return count + 1
            }
            return count
        }
    }
}

