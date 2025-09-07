//
//  DrawingCanvas+PathClosing.swift
//  logos inkpen.io
//
//  Path closing functionality
//

import SwiftUI

extension DrawingCanvas {
    internal func closeSelectedPaths() {
        // Get unique shape IDs from selected points
        let selectedShapeIDs = Set(selectedPoints.map { $0.shapeID })
        
        for shapeID in selectedShapeIDs {
            // Find the shape and close its path if it's open
            for layerIndex in document.layers.indices {
                let shapes = document.getShapesForLayer(layerIndex)
                if let shapeIndex = shapes.firstIndex(where: { $0.id == shapeID }) {
                    guard var shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { continue }
                    
                    // Check if path is already closed
                    let hasCloseElement = shape.path.elements.contains { element in
                        if case .close = element { return true }
                        return false
                    }
                    
                    if !hasCloseElement && shape.path.elements.count > 2 {
                        // Add close element
                        var newElements = shape.path.elements
                        newElements.append(.close)
                        
                        let newPath = VectorPath(elements: newElements, isClosed: true)
                        shape.path = newPath
                        shape.updateBounds()
                        
                        // Update using unified setter
                        document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: shape)
                        
                        Log.info("Closed path for shape \(shape.name)", category: .general)
                    }
                }
            }
        }
        
        // Force UI update
        document.objectWillChange.send()
    }
} 