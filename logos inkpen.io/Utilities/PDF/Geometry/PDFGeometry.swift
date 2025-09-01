//
//  PDFGeometry.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import Foundation
import SwiftUI
import CoreGraphics

// MARK: - Geometry and Coordinate Transformation Utilities

/// Handles coordinate system transformations between PDF and screen coordinates
struct PDFGeometryTransformer {
    let pageSize: CGSize
    
    /// Transform PDF coordinates (origin at bottom-left) to screen coordinates (origin at top-left)
    func transformPoint(_ point: CGPoint) -> VectorPoint {
        return VectorPoint(Double(point.x), Double(pageSize.height - point.y))
    }
    
    /// Transform multiple points efficiently
    func transformPoints(_ points: [CGPoint]) -> [VectorPoint] {
        return points.map { transformPoint($0) }
    }
    
    /// Transform a rectangle from PDF to screen coordinates
    func transformRect(_ rect: CGRect) -> CGRect {
        return CGRect(
            x: rect.origin.x,
            y: pageSize.height - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }
}

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

/// Handles matrix transformations for gradients and graphics state
struct PDFMatrixTransformer {
    var currentTransformMatrix: CGAffineTransform = .identity
    
    /// Apply a matrix concatenation
    mutating func applyMatrix(_ transform: CGAffineTransform) {
        currentTransformMatrix = currentTransformMatrix.concatenating(transform)
    }
    
    /// Extract rotation angle from current transformation matrix
    var rotationAngle: CGFloat {
        return atan2(currentTransformMatrix.b, currentTransformMatrix.a)
    }
    
    /// Get rotation angle in degrees
    var rotationAngleDegrees: CGFloat {
        return rotationAngle * 180.0 / .pi
    }
    
    /// Get Y-axis flipped angle for screen coordinates
    var screenCorrectedAngle: CGFloat {
        return -rotationAngleDegrees
    }
    
    /// Reset transformation matrix
    mutating func reset() {
        currentTransformMatrix = .identity
    }
}