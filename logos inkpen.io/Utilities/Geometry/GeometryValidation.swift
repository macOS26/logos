//
//  GeometryValidation.swift
//  logos inkpen.io
//
//  Geometry validation and detection utilities
//

import CoreGraphics

/// Check if a rectangle-based shape (by checking if it has 4 curve elements forming a rectangle)
func isRectangleBasedShape(_ shape: VectorShape) -> Bool {
    // Rectangle-based shapes have exactly 5 elements: move + 4 lines/curves + close
    // Or 4 elements without close
    let elementCount = shape.path.elements.count
    return elementCount == 4 || elementCount == 5 || elementCount == 6
}