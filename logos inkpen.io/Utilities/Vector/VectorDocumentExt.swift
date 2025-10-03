//
//  VectorDocumentExt.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI

// MARK: - Template Extensions

extension VectorDocument {
    
    /// Get all shapes from all layers
    func getAllShapes() -> [VectorShape] {
        var allShapes: [VectorShape] = []
        // Use unified objects to get all shapes
        for unifiedObject in unifiedObjects {
            if case .shape(let shape) = unifiedObject.objectType {
                allShapes.append(shape)
            }
        }
        return allShapes
    }
    
    /// Get total shape count across all layers
    func getTotalShapeCount() -> Int {
        // Count shapes in unified objects
        return unifiedObjects.reduce(0) { count, unifiedObject in
            if case .shape(_) = unifiedObject.objectType {
                return count + 1
            }
            return count
        }
    }
}

