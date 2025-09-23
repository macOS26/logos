//
//  Position.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/20/25.
//

// MARK: - Professional Text Transformation Helper Methods (old implementation, TODO: clean up)

import SwiftUI

func cornerPosition(for index: Int, in bounds: CGRect, center: CGPoint) -> CGPoint {
    // PROFESSIONAL COORDINATE SYSTEM: Use logical coordinates for text selection handles
    let positions = [
        CGPoint(x: bounds.minX, y: bounds.minY), // Top-left
        CGPoint(x: bounds.maxX, y: bounds.minY), // Top-right
        CGPoint(x: bounds.maxX, y: bounds.maxY), // Bottom-right
        CGPoint(x: bounds.minX, y: bounds.maxY)  // Bottom-left
    ]
    
    return positions[index]
}

func edgePosition(for index: Int, in bounds: CGRect, center: CGPoint) -> CGPoint {
    // PROFESSIONAL COORDINATE SYSTEM: Use logical coordinates for text edge handles
    let positions = [
        CGPoint(x: center.x, y: bounds.minY), // Top
        CGPoint(x: bounds.maxX, y: center.y), // Right
        CGPoint(x: center.x, y: bounds.maxY), // Bottom
        CGPoint(x: bounds.minX, y: center.y)  // Left
    ]
    
    return positions[index]
}
