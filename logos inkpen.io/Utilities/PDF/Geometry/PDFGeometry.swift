//
//  PDFGeometry.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import SwiftUI

// MARK: - Geometry and Coordinate Transformation Utilities

/// Calculates bounds and dimensions for PDF content
struct PDFBoundsCalculator {
    
    /// Calculate the actual artwork bounds from a collection of shapes
    static func calculateArtworkBounds(from shapes: [VectorShape], pageSize: CGSize) -> CGRect {
        guard !shapes.isEmpty else { return CGRect(origin: .zero, size: pageSize) }
        
        var minX = Double.greatestFiniteMagnitude
        var minY = Double.greatestFiniteMagnitude
        var maxX = -Double.greatestFiniteMagnitude
        var maxY = -Double.greatestFiniteMagnitude
        
        for shape in shapes {
            let bounds = shape.bounds
            minX = min(minX, bounds.origin.x)
            minY = min(minY, bounds.origin.y)
            maxX = max(maxX, bounds.origin.x + bounds.size.width)
            maxY = max(maxY, bounds.origin.y + bounds.size.height)
        }
        
        return CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }
    
    /// Check if a rectangle represents a page boundary that should be filtered out
    static func isPageBoundaryRectangle(_ rect: CGRect, pageSize: CGSize, tolerance: CGFloat = 2.0) -> Bool {
        let width = rect.width
        let height = rect.height
        let x = rect.origin.x
        let y = rect.origin.y
        
        // Check if dimensions match page size
        if abs(width - pageSize.width) < tolerance && abs(height - pageSize.height) < tolerance {
            return true
        }
        
        // Check if positioned at page origin and matches page size
        if abs(x) < tolerance && abs(y) < tolerance &&
           abs(width - pageSize.width) < tolerance && abs(height - pageSize.height) < tolerance {
            return true
        }
        
        return false
    }
}
