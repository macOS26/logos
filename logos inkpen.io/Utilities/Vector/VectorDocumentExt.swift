//
//  VectorDocumentExt.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation
import SwiftUI

// MARK: - Template Extensions

extension VectorDocument {
    
    /// Get all shapes from all layers
    func getAllShapes() -> [VectorShape] {
        var allShapes: [VectorShape] = []
        for layer in layers {
            allShapes.append(contentsOf: layer.shapes)
        }
        return allShapes
    }
    
    /// Get total shape count across all layers
    func getTotalShapeCount() -> Int {
        return layers.reduce(0) { $0 + $1.shapes.count }
    }
}

