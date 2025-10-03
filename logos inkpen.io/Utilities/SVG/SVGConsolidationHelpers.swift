//
//  SVGConsolidationHelpers.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 9/3/25.
//

import SwiftUI

// MARK: - SVG Gradient Consolidation Helpers
struct SVGConsolidationHelpers {
    
    // MARK: - Fixed Gradient Consolidation (Order-Preserving)
    /// Fixed version that preserves the original order of shapes while consolidating gradients
    /// The original method put all non-gradient shapes first, then all gradient shapes
    /// This method maintains the original SVG order
    static func consolidateSharedGradientsFixed(in inputShapes: [VectorShape]) -> [VectorShape] {
        guard !inputShapes.isEmpty else { return inputShapes }
        
        struct GroupKey: Hashable {
            let blendMode: BlendMode
            let opacity: Double
            let gradientSig: String
        }
        
        var buckets: [GroupKey: [VectorShape]] = [:]
        var shapeToBucketMap: [VectorShape: GroupKey] = [:]
        
        // First pass: categorize shapes and build buckets
        for shape in inputShapes {
            guard let fill = shape.fillStyle,
                  case .gradient(let g) = fill.color,
                  !shape.isGroup,
                  !shape.isWarpObject,
                  !shape.isClippingPath else {
                continue
            }
            let key = GroupKey(blendMode: shape.blendMode, opacity: fill.opacity, gradientSig: g.signature)
            buckets[key, default: []].append(shape)
            shapeToBucketMap[shape] = key
        }
        
        // Create consolidated shapes for buckets with multiple shapes
        var consolidatedShapes: [GroupKey: VectorShape] = [:]
        for (key, shapes) in buckets {
            if shapes.count == 1 {
                consolidatedShapes[key] = shapes[0]
                continue
            }
            
            // Attempt to union paths. If union fails, fall back to multi-subpath compound without boolean union.
            let cgPaths: [CGPath] = shapes.map { $0.path.cgPath }
            
            // Try CoreGraphics union on pairs iteratively (best-effort; falls back on simple merge)
            var combined: CGPath? = cgPaths.first
            for p in cgPaths.dropFirst() {
                if let c = combined, let u = CoreGraphicsPathOperations.union(c, p, using: .winding) {
                    combined = u
                } else {
                    combined = nil
                    break
                }
            }
            
            let compoundPath: VectorPath
            if let unified = combined {
                compoundPath = VectorPath(cgPath: unified, fillRule: .winding)
            } else {
                // Build a compound-like path by concatenating subpaths
                var elements: [PathElement] = []
                for p in cgPaths {
                    let vp = VectorPath(cgPath: p)
                    elements.append(contentsOf: vp.elements)
                }
                compoundPath = VectorPath(elements: elements, isClosed: true, fillRule: .winding)
            }
            
            // Use first shape's style as canonical
            let base = shapes[0]
            var compound = VectorShape(
                name: "Compound Gradient",
                path: compoundPath,
                geometricType: nil,
                strokeStyle: nil,
                fillStyle: base.fillStyle,
                transform: .identity,
                isVisible: true,
                isLocked: false,
                opacity: base.opacity,
                blendMode: key.blendMode,
                isGroup: false,
                groupedShapes: [],
                groupTransform: .identity,
                isCompoundPath: true,
                isWarpObject: false,
                originalPath: nil,
                warpEnvelope: [],
                originalEnvelope: [],
                isRoundedRectangle: false,
                originalBounds: nil,
                cornerRadii: []
            )
            compound.updateBounds()
            consolidatedShapes[key] = compound
        }
        
        // Second pass: reconstruct the original order while using consolidated shapes
        var result: [VectorShape] = []
        for shape in inputShapes {
            if let key = shapeToBucketMap[shape] {
                // This is a gradient shape - use the consolidated version if it exists
                if let consolidatedShape = consolidatedShapes[key] {
                    // Only add the consolidated shape once (for the first occurrence)
                    if !result.contains(where: { $0.id == consolidatedShape.id }) {
                        result.append(consolidatedShape)
                    }
                } else {
                    // Single shape, add as-is
                    result.append(shape)
                }
            } else {
                // Non-gradient shape, add as-is
                result.append(shape)
            }
        }
        
        return result
    }
}
