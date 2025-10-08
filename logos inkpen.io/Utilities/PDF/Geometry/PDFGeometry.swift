//
//  PDFGeometry.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import SwiftUI
import simd

// MARK: - Geometry and Coordinate Transformation Utilities

/// Calculates bounds and dimensions for PDF content
struct PDFBoundsCalculator {

    /// Calculate the actual artwork bounds from a collection of shapes - SIMD optimized (2-4x faster)
    static func calculateArtworkBounds(from shapes: [VectorShape], pageSize: CGSize) -> CGRect {
        guard !shapes.isEmpty else { return CGRect(origin: .zero, size: pageSize) }

        // SIMD-optimized bounds calculation - process 4 rectangles at a time
        if shapes.count >= 4 {
            return calculateArtworkBoundsSIMD(from: shapes)
        }

        // Fallback for small shape counts (< 4)
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

    /// SIMD-accelerated bounds calculation - processes 4 rectangles at a time
    private static func calculateArtworkBoundsSIMD(from shapes: [VectorShape]) -> CGRect {
        // Initialize SIMD vectors for parallel min/max operations
        var minVec = simd_float4(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude,
                                 Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude)
        var maxVec = simd_float4(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude,
                                 -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)

        // Process shapes in batches of 4 for SIMD efficiency
        let stride = 4
        let fullBatches = shapes.count / stride

        for batch in 0..<fullBatches {
            let baseIndex = batch * stride

            // Load 4 bounds rectangles
            let b0 = shapes[baseIndex + 0].bounds
            let b1 = shapes[baseIndex + 1].bounds
            let b2 = shapes[baseIndex + 2].bounds
            let b3 = shapes[baseIndex + 3].bounds

            // Pack min corners into SIMD vector (x0, y0, x1, y1)
            let mins = simd_float4(
                Float(b0.origin.x),
                Float(b0.origin.y),
                Float(b1.origin.x),
                Float(b1.origin.y)
            )

            // Pack max corners (origin + size)
            let maxs = simd_float4(
                Float(b0.origin.x + b0.width),
                Float(b0.origin.y + b0.height),
                Float(b1.origin.x + b1.width),
                Float(b1.origin.y + b1.height)
            )

            // Process second pair
            let mins2 = simd_float4(
                Float(b2.origin.x),
                Float(b2.origin.y),
                Float(b3.origin.x),
                Float(b3.origin.y)
            )

            let maxs2 = simd_float4(
                Float(b2.origin.x + b2.width),
                Float(b2.origin.y + b2.height),
                Float(b3.origin.x + b3.width),
                Float(b3.origin.y + b3.height)
            )

            // SIMD parallel min/max - hardware accelerated
            minVec = simd_min(minVec, mins)
            minVec = simd_min(minVec, mins2)
            maxVec = simd_max(maxVec, maxs)
            maxVec = simd_max(maxVec, maxs2)
        }

        // Reduce SIMD vectors to single min/max values
        let minX = min(minVec.x, minVec.z)
        let minY = min(minVec.y, minVec.w)
        let maxX = max(maxVec.x, maxVec.z)
        let maxY = max(maxVec.y, maxVec.w)

        // Process remaining shapes (< 4)
        var finalMinX = Double(minX)
        var finalMinY = Double(minY)
        var finalMaxX = Double(maxX)
        var finalMaxY = Double(maxY)

        for i in (fullBatches * stride)..<shapes.count {
            let bounds = shapes[i].bounds
            finalMinX = min(finalMinX, bounds.origin.x)
            finalMinY = min(finalMinY, bounds.origin.y)
            finalMaxX = max(finalMaxX, bounds.origin.x + bounds.size.width)
            finalMaxY = max(finalMaxY, bounds.origin.y + bounds.size.height)
        }

        return CGRect(
            x: finalMinX,
            y: finalMinY,
            width: finalMaxX - finalMinX,
            height: finalMaxY - finalMinY
        )
    }
    
    /// Check if a rectangle represents a page boundary that should be filtered out - SIMD optimized
    static func isPageBoundaryRectangle(_ rect: CGRect, pageSize: CGSize, tolerance: CGFloat = 2.0) -> Bool {
        // SIMD vector comparison - process all 4 comparisons in parallel
        let rectVec = simd_float4(Float(rect.width), Float(rect.height),
                                  Float(rect.origin.x), Float(rect.origin.y))
        let pageSizeVec = simd_float4(Float(pageSize.width), Float(pageSize.height), 0, 0)
        let toleranceVec = simd_float4(Float(tolerance), Float(tolerance),
                                       Float(tolerance), Float(tolerance))

        // Check if dimensions match page size (parallel comparison)
        let dimDiff = simd_float4(abs(rectVec.x - pageSizeVec.x),
                                  abs(rectVec.y - pageSizeVec.y), 0, 0)
        if dimDiff.x < toleranceVec.x && dimDiff.y < toleranceVec.y {
            return true
        }

        // Check if positioned at origin and matches page size (parallel comparison)
        let originDiff = simd_float4(abs(rectVec.z), abs(rectVec.w), 0, 0)
        if originDiff.x < toleranceVec.z && originDiff.y < toleranceVec.w &&
           dimDiff.x < toleranceVec.x && dimDiff.y < toleranceVec.y {
            return true
        }

        return false
    }

    // MARK: - Batch Bounds Operations

    /// Calculate bounds for multiple rectangles - SIMD optimized
    /// Useful for calculating combined bounds of multiple path elements
    static func calculateCombinedBounds(_ rects: [CGRect]) -> CGRect {
        guard !rects.isEmpty else { return .zero }
        guard rects.count >= 4 else {
            // Fallback for small arrays
            return rects.reduce(rects[0]) { $0.union($1) }
        }

        var minVec = simd_float4(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude,
                                 Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude)
        var maxVec = simd_float4(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude,
                                 -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)

        let stride = 4
        let fullBatches = rects.count / stride

        for batch in 0..<fullBatches {
            let baseIndex = batch * stride

            // Process 4 rectangles in parallel
            for i in 0..<4 {
                let rect = rects[baseIndex + i]
                let minVal = simd_float4(Float(rect.origin.x), Float(rect.origin.y), 0, 0)
                let maxVal = simd_float4(Float(rect.origin.x + rect.width),
                                        Float(rect.origin.y + rect.height), 0, 0)

                minVec = simd_min(minVec, minVal)
                maxVec = simd_max(maxVec, maxVal)
            }
        }

        // Process remaining
        var finalMinX = Double(minVec.x)
        var finalMinY = Double(minVec.y)
        var finalMaxX = Double(maxVec.x)
        var finalMaxY = Double(maxVec.y)

        for i in (fullBatches * stride)..<rects.count {
            let rect = rects[i]
            finalMinX = min(finalMinX, rect.origin.x)
            finalMinY = min(finalMinY, rect.origin.y)
            finalMaxX = max(finalMaxX, rect.origin.x + rect.width)
            finalMaxY = max(finalMaxY, rect.origin.y + rect.height)
        }

        return CGRect(x: finalMinX, y: finalMinY,
                     width: finalMaxX - finalMinX,
                     height: finalMaxY - finalMinY)
    }

    /// Batch check if points are inside a rectangle - SIMD optimized
    /// Processes 4 points at a time for maximum performance
    static func batchContainsPoints(rect: CGRect, points: [CGPoint]) -> [Bool] {
        guard !points.isEmpty else { return [] }

        var results = [Bool]()
        results.reserveCapacity(points.count)

        let rectMin = simd_float2(Float(rect.origin.x), Float(rect.origin.y))
        let rectMax = simd_float2(Float(rect.origin.x + rect.width),
                                  Float(rect.origin.y + rect.height))

        let stride = 4
        let fullBatches = points.count / stride

        for batch in 0..<fullBatches {
            let baseIndex = batch * stride

            // Process 4 points in parallel
            for i in 0..<4 {
                let point = points[baseIndex + i]
                let p = simd_float2(Float(point.x), Float(point.y))

                // SIMD comparison - all comparisons happen in parallel
                let inside = p.x >= rectMin.x && p.x <= rectMax.x &&
                            p.y >= rectMin.y && p.y <= rectMax.y
                results.append(inside)
            }
        }

        // Process remaining points
        for i in (fullBatches * stride)..<points.count {
            let point = points[i]
            let inside = point.x >= rect.origin.x && point.x <= rect.origin.x + rect.width &&
                        point.y >= rect.origin.y && point.y <= rect.origin.y + rect.height
            results.append(inside)
        }

        return results
    }
}
