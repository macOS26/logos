import CoreGraphics
import Foundation

/// CoreGraphics-based path operations using native boolean operations (macOS 14+)
/// 
/// This provides modern, hardware-accelerated path operations that preserve smooth curves
/// unlike ClipperPath which tessellates curves into line segments.
public class CoreGraphicsPathOperations {
    
    // MARK: - Boolean Operations
    
    /// Performs a union operation on two paths using CoreGraphics
    /// - Parameters:
    ///   - pathA: First path
    ///   - pathB: Second path
    ///   - fillRule: Fill rule to use (.winding or .evenOdd)
    /// - Returns: Combined path representing the union of both inputs
    public static func union(_ pathA: CGPath, _ pathB: CGPath, using fillRule: CGPathFillRule = .winding) -> CGPath? {
        guard !pathA.isEmpty && !pathB.isEmpty else {
            // Handle edge cases
            if pathA.isEmpty && pathB.isEmpty { return nil }
            return pathA.isEmpty ? pathB : pathA
        }
        
        let result = pathA.union(pathB, using: fillRule)
        return result.isEmpty ? nil : result
    }
    
    /// Performs an intersection operation on two paths using CoreGraphics
    /// - Parameters:
    ///   - pathA: First path
    ///   - pathB: Second path
    ///   - fillRule: Fill rule to use (.winding or .evenOdd)
    /// - Returns: Path representing the intersection of both inputs
    public static func intersection(_ pathA: CGPath, _ pathB: CGPath, using fillRule: CGPathFillRule = .winding) -> CGPath? {
        guard !pathA.isEmpty && !pathB.isEmpty else {
            return nil // No intersection possible with empty paths
        }
        
        let result = pathA.intersection(pathB, using: fillRule)
        return result.isEmpty ? nil : result
    }
    
    /// Performs a subtraction operation using CoreGraphics (basePath - subtractPath)
    /// - Parameters:
    ///   - subtractPath: Path to subtract (will be removed)
    ///   - basePath: Path to subtract from (the base shape)  
    ///   - fillRule: Fill rule to use (.winding or .evenOdd)
    /// - Returns: Path representing basePath with subtractPath removed
    public static func subtract(_ subtractPath: CGPath, from basePath: CGPath, using fillRule: CGPathFillRule = .winding) -> CGPath? {
        guard !subtractPath.isEmpty && !basePath.isEmpty else {
            return basePath // Return base path if subtract path is empty
        }
        
        let result = basePath.subtracting(subtractPath, using: fillRule)
        return result.isEmpty ? nil : result
    }
    
    /// Performs a symmetric difference operation using CoreGraphics
    /// - Parameters:
    ///   - pathA: First path
    ///   - pathB: Second path
    ///   - fillRule: Fill rule to use (.winding or .evenOdd)
    /// - Returns: Path representing areas in either path but not both (XOR)
    public static func symmetricDifference(_ pathA: CGPath, _ pathB: CGPath, using fillRule: CGPathFillRule = .winding) -> CGPath? {
        guard !pathA.isEmpty && !pathB.isEmpty else {
            // Symmetric difference with empty path is the other path
            if pathA.isEmpty && pathB.isEmpty { return nil }
            return pathA.isEmpty ? pathB : pathA
        }
        
        let result = pathA.symmetricDifference(pathB, using: fillRule)
        return result.isEmpty ? nil : result
    }
    
    // MARK: - Advanced Operations
    
    /// Checks if two paths intersect using CoreGraphics
    /// - Parameters:
    ///   - pathA: First path
    ///   - pathB: Second path
    ///   - fillRule: Fill rule to use (.winding or .evenOdd)
    /// - Returns: True if paths intersect, false otherwise
    public static func intersects(_ pathA: CGPath, _ pathB: CGPath, using fillRule: CGPathFillRule = .winding) -> Bool {
        guard !pathA.isEmpty && !pathB.isEmpty else {
            return false
        }
        
        return pathA.intersects(pathB, using: fillRule)
    }
    
    /// Flattens a path by converting curves to line segments
    /// - Parameters:
    ///   - path: Path to flatten
    ///   - threshold: Flatness threshold (smaller = more accurate, larger = fewer points)
    /// - Returns: Flattened path with only line segments
    public static func flattened(_ path: CGPath, threshold: CGFloat = 1.0) -> CGPath? {
        guard !path.isEmpty else { return nil }
        
        let result = path.flattened(threshold: threshold)
        return result.isEmpty ? nil : result
    }
    
    /// Normalizes a path to remove self-intersections
    /// - Parameters:
    ///   - path: Path to normalize
    ///   - fillRule: Fill rule to use (.winding or .evenOdd)
    /// - Returns: Normalized path with no self-intersections
    public static func normalized(_ path: CGPath, using fillRule: CGPathFillRule = .winding) -> CGPath? {
        guard !path.isEmpty else { return nil }
        
        let result = path.normalized(using: fillRule)
        return result.isEmpty ? nil : result
    }
    
    /// Separates a path into its visual components
    /// - Parameters:
    ///   - path: Path to separate
    ///   - fillRule: Fill rule to use (.winding or .evenOdd)
    /// - Returns: Array of separated path components
    public static func componentsSeparated(_ path: CGPath, using fillRule: CGPathFillRule = .winding) -> [CGPath] {
        guard !path.isEmpty else { return [] }
        
        return path.componentsSeparated(using: fillRule)
    }
    
    // MARK: - Line Operations (NEW!)
    
    /// Gets line portions that intersect with filled regions of another path
    /// - Parameters:
    ///   - linePath: Path with lines to intersect
    ///   - fillPath: Path with filled regions to intersect against
    ///   - fillRule: Fill rule to use (.winding or .evenOdd)
    /// - Returns: Line portions that overlap filled regions
    public static func lineIntersection(_ linePath: CGPath, with fillPath: CGPath, using fillRule: CGPathFillRule = .winding) -> CGPath? {
        guard !linePath.isEmpty && !fillPath.isEmpty else { return nil }
        
        let result = linePath.lineIntersection(fillPath, using: fillRule)
        return result.isEmpty ? nil : result
    }
    
    /// Gets line portions that don't intersect with filled regions of another path
    /// - Parameters:
    ///   - linePath: Path with lines to subtract from
    ///   - fillPath: Path with filled regions to subtract
    ///   - fillRule: Fill rule to use (.winding or .evenOdd)
    /// - Returns: Line portions that don't overlap filled regions
    public static func lineSubtracting(_ linePath: CGPath, from fillPath: CGPath, using fillRule: CGPathFillRule = .winding) -> CGPath? {
        guard !linePath.isEmpty && !fillPath.isEmpty else { return linePath }
        
        let result = linePath.lineSubtracting(fillPath, using: fillRule)
        return result.isEmpty ? nil : result
    }
    
    // MARK: - Split Operations (NEW! - CoreGraphics Alternative to Divide)
    
    /// PROFESSIONAL MOSAIC: True stained glass effect - preserves ALL visible areas, no subtraction
    /// Uses native line intersection/subtraction operations to split paths at their intersections
    /// - Parameters:
    ///   - paths: Array of paths to split
    ///   - fillRule: Fill rule to use (.winding or .evenOdd)
    /// - Returns: Array of split path components
    public static func split(_ paths: [CGPath], using fillRule: CGPathFillRule = .winding) -> [CGPath] {
        return splitWithShapeTracking(paths, using: fillRule).map { $0.0 }
    }
    
    /// PROFESSIONAL MOSAIC with Shape Tracking: True stained glass effect - preserves ALL visible areas
    /// Creates pieces for every unique visible region, maintains appearance, no subtraction
    /// - Parameters:
    ///   - paths: Array of paths to split
    ///   - fillRule: Fill rule to use (.winding or .evenOdd)
    /// - Returns: Array of tuples (splitPath, originalShapeIndex)
    public static func splitWithShapeTracking(_ paths: [CGPath], using fillRule: CGPathFillRule = .winding) -> [(CGPath, Int)] {
        guard paths.count >= 2 else {
            return paths.enumerated().map { (index, path) in (path, index) }
        }
        
        print("🔨 PROFESSIONAL MOSAIC (CoreGraphics): Processing \(paths.count) paths - TRUE stained glass")
        print("   🪟 Preserving ALL visible areas, breaking at intersections only")
        
        // Use same approach as CUT but break at intersections instead of subtracting
        let allPieces = getAllMosaicPieces(paths, using: fillRule)
        
        print("✅ PROFESSIONAL MOSAIC: Created \(allPieces.count) pieces - ALL areas preserved with correct colors")
        return allPieces
    }
    
    /// Gets all mosaic pieces - TRUE STAINED GLASS: Complete planar subdivision
    /// EVERY region becomes its own object - no large interior pieces remain
    private static func getAllMosaicPieces(_ paths: [CGPath], using fillRule: CGPathFillRule) -> [(CGPath, Int)] {
        guard !paths.isEmpty else { return [] }
        
        print("   🪟 MOSAIC: TRUE stained glass - complete planar subdivision")
        
        var allPieces: [(CGPath, Int)] = []
        
        // GENERATE ALL POSSIBLE INTERSECTION COMBINATIONS
        // For n shapes, we need to check 2^n - 1 possible combinations (excluding empty set)
        let shapeCount = paths.count
        
        for mask in 1..<(1 << shapeCount) {
            var intersectingIndices: [Int] = []
            
            // Find which shapes are in this combination
            for i in 0..<shapeCount {
                if (mask & (1 << i)) != 0 {
                    intersectingIndices.append(i)
                }
            }
            
            guard !intersectingIndices.isEmpty else { continue }
            
            if intersectingIndices.count == 1 {
                // Single shape - subtract all other shapes to get exclusive part
                let shapeIndex = intersectingIndices[0]
                let currentPath = paths[shapeIndex]
                var exclusivePath = currentPath
                
                // Subtract all OTHER shapes
                for otherIndex in 0..<shapeCount {
                    if otherIndex != shapeIndex {
                        if let subtracted = subtract(paths[otherIndex], from: exclusivePath, using: fillRule) {
                            exclusivePath = subtracted
                        }
                        if exclusivePath.isEmpty { break }
                    }
                }
                
                // Add exclusive parts
                if !exclusivePath.isEmpty {
                    let components = componentsSeparated(exclusivePath, using: fillRule)
                    for component in components {
                        if !component.isEmpty {
                            allPieces.append((component, shapeIndex))
                        }
                    }
                    print("   ✅ Shape \(shapeIndex): Added exclusive parts")
                }
                
            } else {
                // Multiple shapes - find intersection of ALL shapes in this combination
                var intersectionPath = paths[intersectingIndices[0]]
                
                for i in 1..<intersectingIndices.count {
                    let shapeIndex = intersectingIndices[i]
                    if let newIntersection = intersection(intersectionPath, paths[shapeIndex], using: fillRule) {
                        intersectionPath = newIntersection
                    } else {
                        intersectionPath = CGMutablePath() // Empty
                        break
                    }
                    if intersectionPath.isEmpty { break }
                }
                
                // Now subtract all shapes NOT in this combination to get the EXCLUSIVE intersection
                for excludeIndex in 0..<shapeCount {
                    if !intersectingIndices.contains(excludeIndex) {
                        if let subtracted = subtract(paths[excludeIndex], from: intersectionPath, using: fillRule) {
                            intersectionPath = subtracted
                        }
                        if intersectionPath.isEmpty { break }
                    }
                }
                
                // Add intersection pieces
                if !intersectionPath.isEmpty {
                    let components = componentsSeparated(intersectionPath, using: fillRule)
                    for component in components {
                        if !component.isEmpty {
                            // Use topmost shape's index for color
                            let topmostIndex = intersectingIndices.max() ?? intersectingIndices[0]
                            allPieces.append((component, topmostIndex))
                        }
                    }
                    
                    let shapeList = intersectingIndices.map { "\($0)" }.joined(separator: ",")
                    print("   🔗 Intersection [\(shapeList)]: Added as separate object")
                }
            }
        }
        
        // REMOVE DUPLICATES: Check for pieces that occupy the same geometric area
        print("   🧹 MOSAIC: Removing duplicates from \(allPieces.count) pieces...")
        
        var uniquePieces: [(CGPath, Int)] = []
        let tolerance: CGFloat = 0.1  // Small tolerance for floating point comparison
        
        for (candidate, candidateIndex) in allPieces {
            var isDuplicate = false
            
            // Check if this piece is a duplicate of any existing piece
            for (existing, _) in uniquePieces {
                if pathsAreEquivalent(candidate, existing, tolerance: tolerance) {
                    isDuplicate = true
                    break
                }
            }
            
            if !isDuplicate {
                uniquePieces.append((candidate, candidateIndex))
            }
        }
        
        print("   ✅ MOSAIC: \(uniquePieces.count) unique pieces (removed \(allPieces.count - uniquePieces.count) duplicates)")
        print("   🪟 COMPLETE planar subdivision - true stained glass effect!")
        return uniquePieces
    }
    
    /// Check if two paths represent the same geometric area (for duplicate detection)
    private static func pathsAreEquivalent(_ path1: CGPath, _ path2: CGPath, tolerance: CGFloat) -> Bool {
        // Quick checks first
        if path1.isEmpty && path2.isEmpty { return true }
        if path1.isEmpty || path2.isEmpty { return false }
        
        let bounds1 = path1.boundingBoxOfPath
        let bounds2 = path2.boundingBoxOfPath
        
        // Check if bounds are similar (within tolerance)
        let boundsEqual = abs(bounds1.minX - bounds2.minX) < tolerance &&
                         abs(bounds1.minY - bounds2.minY) < tolerance &&
                         abs(bounds1.maxX - bounds2.maxX) < tolerance &&
                         abs(bounds1.maxY - bounds2.maxY) < tolerance
        
        if !boundsEqual { return false }
        
        // For more precise comparison, check if one path contains the other and vice versa
        // This works because if A contains B and B contains A, then A == B geometrically
        let midPoint = CGPoint(x: bounds1.midX, y: bounds1.midY)
        
        let path1ContainsMid = path1.contains(midPoint, using: .winding)
        let path2ContainsMid = path2.contains(midPoint, using: .winding)
        
        // If both contain the midpoint or both don't contain it, and bounds are equal, likely the same
        return path1ContainsMid == path2ContainsMid
    }

    

    
    /// Helper function to get multi-way intersection using CoreGraphics
    private static func getMultiWayIntersectionCoreGraphics(_ paths: [CGPath], using fillRule: CGPathFillRule) -> CGPath {
        guard !paths.isEmpty else { return CGMutablePath() }
        guard paths.count > 1 else { return paths[0] }
        
        var result = paths[0]
        
        for i in 1..<paths.count {
            if let intersection = intersection(result, paths[i], using: fillRule) {
                result = intersection
            } else {
                return CGMutablePath() // Empty result
            }
        }
        
        return result
    }
    
    // MARK: - Integration Support
    
    /// Converts VectorPath to CGPath for CoreGraphics operations
    /// - Parameter vectorPath: VectorPath to convert
    /// - Returns: CGPath representation
    static func cgPath(from vectorPath: VectorPath) -> CGPath {
        return vectorPath.cgPath
    }
    
    /// Creates VectorPath from CGPath result
    /// - Parameter cgPath: CGPath to convert
    /// - Returns: VectorPath representation
    static func vectorPath(from cgPath: CGPath) -> VectorPath {
        return VectorPath(cgPath: cgPath)
    }
    
    // MARK: - Performance Analysis
    
    /// Measures performance of CoreGraphics operations
    /// - Parameters:
    ///   - pathA: First test path
    ///   - pathB: Second test path
    ///   - iterations: Number of iterations to run
    /// - Returns: Performance timing results
    public static func performanceTest(_ pathA: CGPath, _ pathB: CGPath, iterations: Int = 100) -> TimeInterval {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<iterations {
            let _ = union(pathA, pathB)
            let _ = intersection(pathA, pathB)
        }
        
        return CFAbsoluteTimeGetCurrent() - startTime
    }
    
    // MARK: - Cut Operations (CoreGraphics Alternative to Trim)
    
    /// Cut operation: CoreGraphics-based alternative to Trim with curve preservation
    /// Removes HIDDEN parts of shapes that are behind other shapes (like Trim, but preserves curves)
    /// - Parameters:
    ///   - paths: Array of paths in stacking order (first = back, last = front)
    ///   - fillRule: Fill rule to use (.winding or .evenOdd)
    /// - Returns: Array of tuples: (cutPath, originalShapeIndex)
    public static func cutWithShapeTracking(_ paths: [CGPath], using fillRule: CGPathFillRule = .winding) -> [(CGPath, Int)] {
        guard paths.count >= 2 else {
            return paths.enumerated().map { (index, path) in (path, index) }
        }
        
        print("🔨 PROFESSIONAL CUT (CoreGraphics): Processing \(paths.count) paths with curve preservation")
        
        var resultPaths: [(CGPath, Int)] = []
        
        // CoreGraphics Cut Algorithm:
        // Process shapes from BACK to FRONT (stacking order)
        // For each shape, subtract all shapes that are IN FRONT of it
        // This removes the HIDDEN parts while preserving smooth curves
        
        for i in 0..<paths.count {
            let currentPath = paths[i]
            guard !currentPath.isEmpty else {
                print("   ⚠️ Shape \(i): Empty path, skipping")
                continue
            }
            
            // Start with the current shape
            var visiblePath = currentPath
            var hasShapesInFront = false
            
            // Subtract all shapes that are IN FRONT of this shape
            // (shapes with higher index are in front in stacking order)
            for j in (i+1)..<paths.count {
                let frontPath = paths[j]
                guard !frontPath.isEmpty else { continue }
                
                hasShapesInFront = true
                
                // Use CoreGraphics subtract to remove the hidden parts
                if let subtracted = subtract(frontPath, from: visiblePath, using: fillRule) {
                    visiblePath = subtracted
                    print("   → Shape \(i): Subtracted shape \(j) (in front)")
                } else {
                    // If subtraction results in empty, this shape is completely hidden
                    visiblePath = CGMutablePath() // Empty path
                    print("   → Shape \(i): Completely hidden by shape \(j)")
                    break
                }
                
                // If path becomes empty, no need to continue
                if visiblePath.isEmpty {
                    break
                }
            }
            
            if hasShapesInFront {
                // Add the visible parts (with curves preserved!)
                if !visiblePath.isEmpty {
                    let components = componentsSeparated(visiblePath, using: fillRule)
                    for component in components {
                        if !component.isEmpty {
                            resultPaths.append((component, i))
                        }
                    }
                    print("   ✅ Shape \(i): Cut hidden parts, keeping visible area (curves preserved)")
                } else {
                    print("   ✅ Shape \(i): Completely hidden, removed")
                }
            } else {
                // No shapes in front, so keep the entire shape (nothing to cut)
                resultPaths.append((currentPath, i))
                print("   ✅ Shape \(i): No shapes in front, keeping entire shape")
            }
        }
        
        print("✅ PROFESSIONAL CUT (CoreGraphics): Created \(resultPaths.count) cut pieces with curves preserved")
        print("   Result should look identical to original, but with hidden paths removed")
        return resultPaths
    }
    
    /// Cut operation: Simplified version that returns only paths
    /// - Parameters:
    ///   - paths: Array of paths in stacking order (first = back, last = front)
    ///   - fillRule: Fill rule to use (.winding or .evenOdd)
    /// - Returns: Array of cut paths with hidden parts removed
    public static func cut(_ paths: [CGPath], using fillRule: CGPathFillRule = .winding) -> [CGPath] {
        return cutWithShapeTracking(paths, using: fillRule).map { $0.0 }
    }
    
    // MARK: - Merge Operations (CoreGraphics Alternative for Color-Based Merging)
    
    /// Merge operation: Applies Cut to all shapes first, keeps all pieces separate (no joining)
    /// - Parameters:
    ///   - paths: Array of paths to merge
    ///   - colors: Array of fill colors (same order as paths)
    ///   - fillRule: Fill rule to use (.winding or .evenOdd)
    /// - Returns: Array of tuples: (cutPath, originalShapeIndex)
    static func mergeWithShapeTracking(_ paths: [CGPath], colors: [VectorColor], using fillRule: CGPathFillRule = .winding) -> [(CGPath, Int)] {
        guard paths.count >= 2 && colors.count == paths.count else {
            return paths.enumerated().map { (index, path) in (path, index) }
        }
        
        print("🔨 PROFESSIONAL MERGE (CoreGraphics): Processing \(paths.count) paths with CUT - no joining")
        
        // STEP 1: Apply Cut logic to ALL shapes to remove hidden overlaps and maintain visual appearance
        print("   🔨 STEP 1: Applying Cut to all shapes to maintain composite appearance...")
        let cutResults = cutWithShapeTracking(paths, using: fillRule)
        
        print("   ✅ Cut produced \(cutResults.count) pieces from \(paths.count) original shapes")
        
        // STEP 2: Group cut results by color but keep all pieces separate
        print("   🎨 STEP 2: Grouping cut results by color (keeping all pieces separate)...")
        
        var colorGroups: [VectorColor: [(CGPath, Int)]] = [:]
        
        for (cutPath, originalIndex) in cutResults {
            let color = colors[originalIndex]
            if colorGroups[color] == nil {
                colorGroups[color] = []
            }
            colorGroups[color]?.append((cutPath, originalIndex))
        }
        
        print("   🎨 Found \(colorGroups.count) color groups in cut results:")
        for (color, group) in colorGroups {
            print("     Color \(color): \(group.count) pieces")
        }
        
        var resultPaths: [(CGPath, Int)] = []
        
        // STEP 3: Keep all pieces separate - DO NOT join elements together
        for (color, group) in colorGroups {
            // Add each piece separately - never merge/union them
            for (path, originalIndex) in group {
                resultPaths.append((path, originalIndex))
            }
            print("   ✅ Color \(color): Kept \(group.count) pieces separate (no joining)")
        }
        
        print("✅ PROFESSIONAL MERGE (CoreGraphics): Created \(resultPaths.count) separate pieces with maintained appearance (no joining)")
        return resultPaths
    }
    
    /// Merge operation: Simplified version that returns only paths  
    /// - Parameters:
    ///   - paths: Array of paths to merge
    ///   - colors: Array of fill colors (same order as paths)
    ///   - fillRule: Fill rule to use (.winding or .evenOdd)
    /// - Returns: Array of color-unified shapes with maintained composite appearance
    static func merge(_ paths: [CGPath], colors: [VectorColor], using fillRule: CGPathFillRule = .winding) -> [CGPath] {
        return mergeWithShapeTracking(paths, colors: colors, using: fillRule).map { $0.0 }
    }

    // MARK: - Crop Operations (CoreGraphics Alternative to ClipperPath)
    
    /// Crop operation: CoreGraphics-based alternative to ClipperPath with curve preservation
    /// Uses top shape to crop shapes beneath it (Adobe Illustrator "Crop")
    /// 1. Top shape becomes invisible (no fill, no stroke) - it's the crop boundary
    /// 2. All other shapes are cropped to only show parts within the crop boundary  
    /// 3. Then everything gets CUT - removing hidden overlapping parts
    /// - Parameters:
    ///   - paths: Array of paths in stacking order (first = back, last = front)
    ///   - fillRule: Fill rule to use (.winding or .evenOdd)
    /// - Returns: Array of tuples: (croppedPath, originalShapeIndex, isInvisibleCropShape)
    public static func cropWithShapeTracking(_ paths: [CGPath], using fillRule: CGPathFillRule = .winding) -> [(CGPath, Int, Bool)] {
        guard paths.count >= 2 else {
            return paths.enumerated().map { (index, path) in (path, index, false) }
        }
        
        print("🔨 PROFESSIONAL CROP (CoreGraphics): Processing \(paths.count) paths with curve preservation")
        
        let cropShape = paths.last!  // Top shape is the crop shape
        let shapesToCrop = Array(paths.dropLast())
        let cropShapeIndex = paths.count - 1
        
        var croppedPaths: [CGPath] = []
        var originalIndices: [Int] = []
        
        // STEP 1: Intersect each shape with the crop shape using CoreGraphics (crop to boundary)
        for (index, path) in shapesToCrop.enumerated() {
            guard !path.isEmpty && !cropShape.isEmpty else {
                print("   ⚠️ Shape \(index): Empty path, skipping")
                continue
            }
            
            // Use CoreGraphics intersection (preserves curves!)
            if let croppedPath = intersection(path, cropShape, using: fillRule) {
                if !croppedPath.isEmpty && !croppedPath.boundingBoxOfPath.isEmpty {
                    croppedPaths.append(croppedPath)
                    originalIndices.append(index)
                    print("   ✅ Shape \(index): Cropped to boundary (curves preserved)")
                } else {
                    print("   ⚠️ Shape \(index): Intersection result is empty")
                }
            } else {
                print("   ⚠️ Shape \(index): No intersection with crop boundary")
            }
        }
        
        print("   ✅ STEP 1: Cropped \(shapesToCrop.count) shapes to boundary, got \(croppedPaths.count) pieces")
        
        // STEP 2: Apply CUT to the cropped shapes to remove hidden overlapping parts
        if croppedPaths.count >= 2 {
            print("   🔨 STEP 2: Applying CoreGraphics CUT to remove hidden overlapping parts")
            let cutResults = cutWithShapeTracking(croppedPaths, using: fillRule)
            
            // Map the cut results back to their original shape indices
            var finalResults: [(CGPath, Int, Bool)] = []
            for (cutPath, cutIndex) in cutResults {
                // Map the cut index back to the original shape index
                if cutIndex < originalIndices.count {
                    let originalIndex = originalIndices[cutIndex]
                    finalResults.append((cutPath, originalIndex, false))
                } else {
                    // Fallback: use modulo to cycle through original indices
                    let originalIndex = cutIndex % shapesToCrop.count
                    finalResults.append((cutPath, originalIndex, false))
                }
            }
            
            // Add the invisible crop shape
            finalResults.append((cropShape, cropShapeIndex, true))
            
            print("✅ PROFESSIONAL CROP (CoreGraphics): Created \(finalResults.count) shapes (\(finalResults.count-1) cropped + 1 invisible)")
            return finalResults
        } else {
            // If we have fewer than 2 cropped shapes, no need to cut
            var finalResults: [(CGPath, Int, Bool)] = []
            for (index, path) in croppedPaths.enumerated() {
                if index < originalIndices.count {
                    let originalIndex = originalIndices[index]
                    finalResults.append((path, originalIndex, false))
                }
            }
            
            // Add the invisible crop shape
            finalResults.append((cropShape, cropShapeIndex, true))
            
            print("✅ PROFESSIONAL CROP (CoreGraphics): Created \(finalResults.count) shapes (\(finalResults.count-1) cropped + 1 invisible)")
            return finalResults
        }
    }
    
    /// Crop operation: Simplified version that returns only paths
    /// - Parameters:
    ///   - paths: Array of paths in stacking order (first = back, last = front)
    ///   - fillRule: Fill rule to use (.winding or .evenOdd)
    /// - Returns: Array of cropped paths with hidden parts removed
    public static func crop(_ paths: [CGPath], using fillRule: CGPathFillRule = .winding) -> [CGPath] {
        return cropWithShapeTracking(paths, using: fillRule).map { $0.0 }
    }
}

 



