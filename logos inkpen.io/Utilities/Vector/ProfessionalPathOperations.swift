//
//  ProfessionalPathOperations.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI

// MARK: - PROFESSIONAL PATHFINDER OPERATIONS

extension ProfessionalPathOperations {
    
    /// PROFESSIONAL UNION: Combines exactly two paths into a single path (Professional "Union")
    static func professionalUnion(_ paths: [CGPath]) -> CGPath? {
        guard paths.count == 2 else { return nil }
        
        let validPaths = paths.filter { !$0.isEmpty }
        guard validPaths.count == 2 else { return nil }
        
        Log.info("🔨 PROFESSIONAL UNION (2 paths): Using CoreGraphics...", category: .general)
        
        if let coreGraphicsResult = CoreGraphicsPathOperations.union(validPaths[0], validPaths[1], using: .winding) {
            Log.info("✅ PROFESSIONAL UNION: CoreGraphics success (preserves smooth curves)", category: .fileOperations)
            return coreGraphicsResult
        } else {
            Log.error("❌ PROFESSIONAL UNION: CoreGraphics operation failed", category: .error)
            return nil
        }
    }
    

    
    /// PROFESSIONAL PUNCH: Front subtracts from back (Professional "Punch", formerly "Minus Front")
    static func professionalMinusFront(_ frontPath: CGPath, from backPath: CGPath) -> CGPath? {
        guard !frontPath.isEmpty && !backPath.isEmpty else { return backPath }
        
        Log.info("🔨 PROFESSIONAL PUNCH: Using CoreGraphics...", category: .general)
        
        // Use CoreGraphics (much faster and preserves curves)
        if let coreGraphicsResult = CoreGraphicsPathOperations.subtract(frontPath, from: backPath, using: .winding) {
            Log.info("✅ PROFESSIONAL PUNCH: CoreGraphics success (preserves smooth curves)", category: .fileOperations)
            return coreGraphicsResult
        }
        
        Log.fileOperation("⚠️ PROFESSIONAL PUNCH: CoreGraphics operation failed", level: .info)
        return nil
    }
    
    /// PROFESSIONAL INTERSECT: Only overlapping areas (Professional "Intersect")
    static func professionalIntersect(_ path1: CGPath, _ path2: CGPath) -> CGPath? {
        guard !path1.isEmpty && !path2.isEmpty else { return nil }
        
        Log.info("🔨 PROFESSIONAL INTERSECT: Using CoreGraphics...", category: .general)
        
        // Use CoreGraphics (much faster and preserves curves)
        if let coreGraphicsResult = CoreGraphicsPathOperations.intersection(path1, path2, using: .winding) {
            Log.info("✅ PROFESSIONAL INTERSECT: CoreGraphics success (preserves smooth curves)", category: .fileOperations)
            return coreGraphicsResult
        }
        
        Log.fileOperation("⚠️ PROFESSIONAL INTERSECT: CoreGraphics operation failed", level: .info)
        return nil
    }
    
    /// PROFESSIONAL EXCLUDE: Remove overlapping areas (Professional "Exclude")
    /// Returns areas that are in either path but not both (symmetric difference)
    static func professionalExclude(_ path1: CGPath, _ path2: CGPath) -> [CGPath] {
        guard !path1.isEmpty && !path2.isEmpty else {
            // If one path is empty, return the other (professional behavior)
            let nonEmptyPath = path1.isEmpty ? path2 : path1
            return nonEmptyPath.isEmpty ? [] : [nonEmptyPath]
        }
        
        Log.info("🔨 PROFESSIONAL EXCLUDE: Using CoreGraphics...", category: .general)
        
        // Use CoreGraphics Symmetric Difference (exactly what Exclude does!)
        if let coreGraphicsResult = CoreGraphicsPathOperations.symmetricDifference(path1, path2, using: .winding) {
            Log.info("✅ PROFESSIONAL EXCLUDE: CoreGraphics success (preserves smooth curves)", category: .fileOperations)
            
            // CoreGraphics returns a single path, but we need to return as array
            // Check if result has multiple components and separate them
            let components = CoreGraphicsPathOperations.componentsSeparated(coreGraphicsResult, using: .winding)
            if !components.isEmpty {
                Log.info("   → Separated into \(components.count) components", category: .general)
                return components
            } else {
                // Single path result
                return [coreGraphicsResult]
            }
        }
        
        Log.fileOperation("⚠️ PROFESSIONAL EXCLUDE: CoreGraphics operation failed", level: .info)
        return []
    }
    
    /// PROFESSIONAL KICK: Back subtracts from front (Professional "Kick", formerly "Minus Back")
    
    // MARK: - PROFESSIONAL DIVIDE & SPLIT OPERATIONS
    
    /// PROFESSIONAL MOSAIC: True stained glass effect - preserves ALL visible areas, no subtraction
    /// Uses native CoreGraphics boolean operations instead of tessellated ClipperPath
    static func professionalMosaic(_ paths: [CGPath]) -> [CGPath] {
        guard paths.count >= 2 else { return paths }
        
        Log.info("🔨 PROFESSIONAL MOSAIC: True stained glass - preserving ALL visible areas...", category: .general)
        
        // Use the new CoreGraphics split operation
        let result = CoreGraphicsPathOperations.split(paths, using: .winding)
        
        if !result.isEmpty {
            Log.info("✅ PROFESSIONAL MOSAIC: SUCCESS - \(result.count) pieces (ALL areas preserved)", category: .fileOperations)
            return result
        } else {
            Log.fileOperation("⚠️ CoreGraphics mosaic returned empty result", level: .info)
            return []
            }
        }
        
    /// PROFESSIONAL CUT: CoreGraphics-based alternative to Trim with curve preservation (NEW!)
    /// Uses native CoreGraphics boolean operations instead of tessellated ClipperPath
    static func professionalCut(_ paths: [CGPath]) -> [CGPath] {
        guard paths.count >= 2 else { return paths }
        
        Log.info("🔨 PROFESSIONAL CUT: Using CoreGraphics with curve preservation...", category: .general)
        
        // Use the new CoreGraphics cut operation  
        let result = CoreGraphicsPathOperations.cut(paths, using: .winding)
        
        if !result.isEmpty {
            Log.info("✅ PROFESSIONAL CUT: CoreGraphics success - \(result.count) pieces (curves preserved)", category: .fileOperations)
            return result
                } else {
            Log.fileOperation("⚠️ CoreGraphics cut returned empty result", level: .info)
            return []
            }
        }
        
    
    // MARK: - FALLBACK OPERATIONS
    
    private static func convexHull(_ points: [CGPoint]) -> [CGPoint] {
        guard points.count > 2 else { return points }
        
        let sortedPoints = points.sorted { point1, point2 in
            if abs(point1.x - point2.x) < 1e-9 {
                return point1.y < point2.y
            }
            return point1.x < point2.x
        }
        
        // Build lower hull
        var lower: [CGPoint] = []
        for point in sortedPoints {
            while lower.count >= 2 && cross(lower[lower.count-2], lower[lower.count-1], point) <= 0 {
                lower.removeLast()
            }
            lower.append(point)
        }
        
        // Build upper hull
        var upper: [CGPoint] = []
        for point in sortedPoints.reversed() {
            while upper.count >= 2 && cross(upper[upper.count-2], upper[upper.count-1], point) <= 0 {
                upper.removeLast()
            }
            upper.append(point)
        }
        
        // Remove last point of each half because it's repeated
        lower.removeLast()
        upper.removeLast()
        
        return lower + upper
    }
    
    private static func cross(_ O: CGPoint, _ A: CGPoint, _ B: CGPoint) -> CGFloat {
        return (A.x - O.x) * (B.y - O.y) - (A.y - O.y) * (B.x - O.x)
    }
    
    // MARK: - ClipperPaths Conversion Helpers
    
    /// Extract individual subpaths from a CGPath
    static func extractSubpaths(from cgPath: CGPath) -> [CGPath] {
        var subpaths: [CGPath] = []
        var currentPath = CGMutablePath()
        
        cgPath.applyWithBlock { elementPtr in
            let element = elementPtr.pointee
            
            switch element.type {
            case .moveToPoint:
                // If we have a current path, save it and start a new one
                if !currentPath.isEmpty {
                    subpaths.append(currentPath)
                    currentPath = CGMutablePath()
                }
                currentPath.move(to: element.points[0])
                
            case .addLineToPoint:
                currentPath.addLine(to: element.points[0])
                
            case .addQuadCurveToPoint:
                currentPath.addQuadCurve(to: element.points[1], control: element.points[0])
                
            case .addCurveToPoint:
                currentPath.addCurve(to: element.points[2], control1: element.points[0], control2: element.points[1])
                
            case .closeSubpath:
                currentPath.closeSubpath()
                
            @unknown default:
                break
            }
        }
        
        // Add the last path if it's not empty
        if !currentPath.isEmpty {
            subpaths.append(currentPath)
        }
        
        return subpaths
    }
    

    

    
    /// PROFESSIONAL MERGE: Maintains composite appearance then merges same colors (Professional "Merge")  
    /// Two-step process: 1) Cut all shapes (maintain appearance), 2) Union same colors
    static func professionalMergeWithShapeTracking(_ paths: [CGPath], colors: [VectorColor]) -> [(CGPath, Int)] {
        guard paths.count >= 2 && colors.count == paths.count else { 
            return paths.enumerated().map { (index, path) in (path, index) }
        }
        
        Log.info("🔨 PROFESSIONAL MERGE: Using CoreGraphics with cut-first, merge-colors approach...", category: .general)
        
        // Use the new CoreGraphics merge operation with color tracking
        let result = CoreGraphicsPathOperations.mergeWithShapeTracking(paths, colors: colors, using: .winding)
        
        if !result.isEmpty {
            Log.info("✅ PROFESSIONAL MERGE: CoreGraphics success - \(result.count) color-unified shapes", category: .fileOperations)
            return result
        } else {
            Log.fileOperation("⚠️ CoreGraphics merge returned empty result", level: .info)
            return paths.enumerated().map { (index, path) in (path, index) }
        }
    }
    
    /// PROFESSIONAL MERGE: Legacy wrapper that returns only paths (for compatibility)
    static func professionalMerge(_ paths: [CGPath]) -> [CGPath] {
        // This legacy version can't do color-based merging without color information
        // Just do a simple union of all paths as fallback
        guard paths.count >= 2 else { return paths }
        
        let validPaths = paths.filter { !$0.isEmpty }
        guard validPaths.count >= 2 else { return paths }
        
        Log.fileOperation("⚠️ PROFESSIONAL MERGE: Legacy mode - no color information, merging all paths", level: .info)
        
        var result = validPaths[0]
        for i in 1..<validPaths.count {
            if let unionResult = CoreGraphicsPathOperations.union(result, validPaths[i], using: .winding) {
                result = unionResult
            }
        }
        
        return [result]
    }
    
    /// PROFESSIONAL CROP: Uses top shape to crop shapes beneath it (Professional "Crop")
    /// Now uses CoreGraphics for curve preservation (like Cut and Trim operations)
    /// Returns an array of tuples: (croppedPath, originalShapeIndex, isInvisibleCropShape)
    static func professionalCropWithShapeTracking(_ paths: [CGPath]) -> [(CGPath, Int, Bool)] {
        guard paths.count >= 2 else { 
            return paths.enumerated().map { (index, path) in (path, index, false) }
        }
        
        Log.info("🔨 PROFESSIONAL CROP: Using CoreGraphics with curve preservation...", category: .general)
        
        // Use the new CoreGraphics crop operation
        let result = CoreGraphicsPathOperations.cropWithShapeTracking(paths, using: .winding)
        
        if !result.isEmpty {
            Log.info("✅ PROFESSIONAL CROP: CoreGraphics success - \(result.count) shapes (curves preserved)", category: .fileOperations)
            return result
        } else {
            Log.fileOperation("⚠️ CoreGraphics crop returned empty result", level: .info)
            return []
        }
    }
    
    /// PROFESSIONAL CROP: Legacy wrapper that returns only paths (for compatibility)
    static func professionalCrop(_ paths: [CGPath]) -> [CGPath] {
        return professionalCropWithShapeTracking(paths).map { $0.0 }
    }
    
    /// PROFESSIONAL DIELINE: Applies Mosaic then converts all results to 1px black strokes with no fill
    /// This is much more useful than Adobe's outline - it combines mosaic power with dieline visualization
    static func professionalDieline(_ paths: [CGPath]) -> [CGPath] {
        guard !paths.isEmpty else { return [] }
        
        Log.info("🔨 PROFESSIONAL DIELINE: Processing \(paths.count) paths", category: .general)
        
        // Step 1: Apply Mosaic operation to cut everything at intersections (with curve preservation)
        let splitPaths = professionalMosaic(paths)
        
        Log.info("✅ PROFESSIONAL DIELINE: Created \(splitPaths.count) mosaic shapes ready for dieline conversion", category: .fileOperations)
        return splitPaths
    }
    
    /// PROFESSIONAL SEPARATE: Separates compound paths into individual components
    static func professionalSeparate(_ paths: [CGPath]) -> [CGPath] {
        guard !paths.isEmpty else { return [] }
        
        Log.info("🔨 PROFESSIONAL SEPARATE: Processing \(paths.count) paths", category: .general)
        
        var separatedPaths: [CGPath] = []
        
        for (index, path) in paths.enumerated() {
            let components = CoreGraphicsPathOperations.componentsSeparated(path, using: .winding)
            
            if components.count <= 1 {
                // No separation needed, keep original
                separatedPaths.append(path)
                Log.info("   Path \(index + 1): No components to separate", category: .general)
            } else {
                // Add all components
                separatedPaths.append(contentsOf: components.filter { !$0.isEmpty })
                Log.info("   Path \(index + 1): Separated into \(components.count) components", category: .general)
            }
        }
        
        Log.info("✅ PROFESSIONAL SEPARATE: Created \(separatedPaths.count) individual paths from \(paths.count) compound paths", category: .fileOperations)
        return separatedPaths
    }
} 
