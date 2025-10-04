import SwiftUI

/// CoreGraphics-based path operations using native boolean operations (macOS 14+)
/// 
/// This provides modern, hardware-accelerated path operations that preserve smooth curves
/// unlike ClipperPath which tessellates curves into line segments.
class CoreGraphicsPathOperations {
    
    
    
    /// Check if a CGRect has finite values (no infinity or NaN)
    private static func isFinite(_ rect: CGRect) -> Bool {
        return rect.origin.x.isFinite && rect.origin.y.isFinite && 
               rect.size.width.isFinite && rect.size.height.isFinite
    }
    
    // MARK: - Boolean Operations
    
    /// Performs a union operation on two paths using CoreGraphics
    /// - Parameters:
    ///   - pathA: First path
    ///   - pathB: Second path
    ///   - fillRule: Fill rule to use (.winding or .evenOdd)
    /// - Returns: Combined path representing the union of both inputs
    static func union(_ pathA: CGPath, _ pathB: CGPath, using fillRule: CGPathFillRule = .winding) -> CGPath? {
        guard !pathA.isEmpty && !pathB.isEmpty else {
            // Handle edge cases
            if pathA.isEmpty && pathB.isEmpty { return nil }
            return pathA.isEmpty ? pathB : pathA
        }
        
        // CRASH FIX: Special handling for self-union (same path with itself)
        if pathA === pathB {
            // For self-union, we can often just return the original path if it's already well-formed
            // or use a different approach that's more stable
            let pathBounds = pathA.boundingBox
            guard isFinite(pathBounds) && !pathBounds.isNull else {
                return nil
            }
            
            // Try the union operation with safety checks
            let result = pathA.union(pathA, using: fillRule)
            guard !result.isEmpty && isFinite(result.boundingBox) else {
                return pathA
            }
            return result
        }
        
        // Safety checks for path bounds
        let boundsA = pathA.boundingBox
        let boundsB = pathB.boundingBox
        guard isFinite(boundsA) && !boundsA.isNull && isFinite(boundsB) && !boundsB.isNull else {
            return nil
        }
        
        let result = pathA.union(pathB, using: fillRule)
        return result.isEmpty ? nil : result
    }
    
    /// Performs a union operation on multiple paths using CoreGraphics
    /// - Parameters:
    ///   - paths: Array of paths to union together
    ///   - fillRule: Fill rule to use (.winding or .evenOdd)
    /// - Returns: Combined path representing the union of all inputs
    private static func unionMultiplePaths(_ paths: [CGPath], using fillRule: CGPathFillRule = .winding) -> CGPath? {
        let validPaths = paths.filter { !$0.isEmpty }
        guard !validPaths.isEmpty else { return nil }
        guard validPaths.count > 1 else { return validPaths.first }
        
        // Iteratively union all paths together
        var result = validPaths[0]
        for i in 1..<validPaths.count {
            guard let unionResult = union(result, validPaths[i], using: fillRule) else {
                return result
            }
            result = unionResult
        }
        
        return result
    }
    
    
    /// Helper function to check if two paths could potentially be unioned
    /// (i.e., they're close enough that a union operation might connect them)
    private static func pathsCanPotentiallyUnion(_ pathA: CGPath, _ pathB: CGPath) -> Bool {
        let boundsA = pathA.boundingBox
        let boundsB = pathB.boundingBox
        
        // Check if bounding boxes are valid
        guard !boundsA.isNull && !boundsB.isNull && 
              !boundsA.isInfinite && !boundsB.isInfinite else {
            return false
        }
        
        // Check if bounding boxes overlap or are very close (within 1 point)
        let tolerance: CGFloat = 1.0
        let expandedBoundsA = boundsA.insetBy(dx: -tolerance, dy: -tolerance)
        
        return expandedBoundsA.intersects(boundsB)
    }
    
    /// Find connected components of paths, respecting stacking order
    /// Paths that touch/overlap AND are adjacent in stacking order get grouped together
    /// - Parameters:
    ///   - pathsWithIndices: Array of (path, originalIndex) tuples in stacking order
    ///   - fillRule: Fill rule to use for intersection testing
    /// - Returns: Array of connected groups, each group contains paths that should be unioned
    private static func findConnectedComponents(_ pathsWithIndices: [(CGPath, Int)], using fillRule: CGPathFillRule = .winding) -> [[(CGPath, Int)]] {
        guard pathsWithIndices.count > 1 else {
            return [pathsWithIndices]
        }
        
        
        var groups: [[(CGPath, Int)]] = []
        var processed: Set<Int> = []
        
        for i in 0..<pathsWithIndices.count {
            if processed.contains(i) { continue }
            
            // Start a new connected component group
            var currentGroup: [(CGPath, Int)] = [pathsWithIndices[i]]
            var groupIndices: Set<Int> = [i]
            processed.insert(i)
            
            // Use a queue to find all transitively connected paths
            var queue: [Int] = [i]
            
            while !queue.isEmpty {
                let currentIndex = queue.removeFirst()
                let currentPath = pathsWithIndices[currentIndex].0
                
                // Check all unprocessed paths to see if they're connected to current path
                for j in 0..<pathsWithIndices.count {
                    if processed.contains(j) || groupIndices.contains(j) { continue }
                    
                    let otherPath = pathsWithIndices[j].0
                    
                    // Check if paths are actually connected (overlapping or touching)
                    if pathsAreConnected(currentPath, otherPath, using: fillRule) {
                        currentGroup.append(pathsWithIndices[j])
                        groupIndices.insert(j)
                        processed.insert(j)
                        queue.append(j) // Add to queue to check its connections
                    }
                }
            }
            
            groups.append(currentGroup)
        }
        
        return groups
    }
    
    /// Check if two paths are actually connected (not just close bounding boxes)
    /// Uses intersection testing to determine if paths overlap or touch
    private static func pathsAreConnected(_ pathA: CGPath, _ pathB: CGPath, using fillRule: CGPathFillRule = .winding) -> Bool {
        // First check if bounding boxes are close enough
        if !pathsCanPotentiallyUnion(pathA, pathB) {
            return false
        }
        
        // Try actual intersection to see if paths overlap
        let intersection = pathA.intersection(pathB, using: fillRule)
        if !intersection.isEmpty {
            return true // Paths overlap
        }
        
        // Check if paths are touching by testing union
        let union = pathA.union(pathB, using: fillRule)
        if !union.isEmpty {
            // If union area is less than sum of individual areas, they're touching/overlapping
            let areaA = pathA.boundingBox.width * pathA.boundingBox.height
            let areaB = pathB.boundingBox.width * pathB.boundingBox.height
            let unionArea = union.boundingBox.width * union.boundingBox.height
            
            // If union is significantly smaller than sum, paths are connected
            let tolerance: CGFloat = 0.1
            return unionArea < (areaA + areaB) * (1.0 - tolerance)
        }
        
        return false
    }
    
    /// Performs an intersection operation on two paths using CoreGraphics
    /// - Parameters:
    ///   - pathA: First path
    ///   - pathB: Second path
    ///   - fillRule: Fill rule to use (.winding or .evenOdd)
    /// - Returns: Path representing the intersection of both inputs
    static func intersection(_ pathA: CGPath, _ pathB: CGPath, using fillRule: CGPathFillRule = .winding) -> CGPath? {
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
    static func subtract(_ subtractPath: CGPath, from basePath: CGPath, using fillRule: CGPathFillRule = .winding) -> CGPath? {
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
    static func symmetricDifference(_ pathA: CGPath, _ pathB: CGPath, using fillRule: CGPathFillRule = .winding) -> CGPath? {
        guard !pathA.isEmpty && !pathB.isEmpty else {
            // Symmetric difference with empty path is the other path
            if pathA.isEmpty && pathB.isEmpty { return nil }
            return pathA.isEmpty ? pathB : pathA
        }
        
        let result = pathA.symmetricDifference(pathB, using: fillRule)
        return result.isEmpty ? nil : result
    }
    
    // MARK: - Advanced Operations
    
    
    /// Normalizes a path to remove self-intersections
    /// - Parameters:
    ///   - path: Path to normalize
    ///   - fillRule: Fill rule to use (.winding or .evenOdd)
    /// - Returns: Normalized path with no self-intersections
    static func normalized(_ path: CGPath, using fillRule: CGPathFillRule = .winding) -> CGPath? {
        guard !path.isEmpty else { return nil }
        
        let result = path.normalized(using: fillRule)
        return result.isEmpty ? nil : result
    }
    
    /// Separates a path into its visual components
    /// - Parameters:
    ///   - path: Path to separate
    ///   - fillRule: Fill rule to use (.winding or .evenOdd)
    /// - Returns: Array of separated path components
    static func componentsSeparated(_ path: CGPath, using fillRule: CGPathFillRule = .winding) -> [CGPath] {
        guard !path.isEmpty else { return [] }
        
        return path.componentsSeparated(using: fillRule)
    }

    // MARK: - Line Operations (NEW!)
    
    // MARK: - Split Operations (NEW! - CoreGraphics Alternative to Divide)
    
    /// PROFESSIONAL MOSAIC: True stained glass effect - preserves ALL visible areas, no subtraction
    /// Uses native line intersection/subtraction operations to split paths at their intersections
    /// - Parameters:
    ///   - paths: Array of paths to split
    ///   - fillRule: Fill rule to use (.winding or .evenOdd)
    /// - Returns: Array of split path components
    static func split(_ paths: [CGPath], using fillRule: CGPathFillRule = .winding) -> [CGPath] {
        return splitWithShapeTracking(paths, using: fillRule).map { $0.0 }
    }
    
    /// PROFESSIONAL MOSAIC with Shape Tracking: True stained glass effect - preserves ALL visible areas
    /// Creates pieces for every unique visible region, maintains appearance, no subtraction
    /// - Parameters:
    ///   - paths: Array of paths to split
    ///   - fillRule: Fill rule to use (.winding or .evenOdd)
    /// - Returns: Array of tuples (splitPath, originalShapeIndex)
    static func splitWithShapeTracking(_ paths: [CGPath], using fillRule: CGPathFillRule = .winding) -> [(CGPath, Int)] {
        guard paths.count >= 2 else {
            return paths.enumerated().map { (index, path) in (path, index) }
        }
        
        
        // Use same approach as CUT but break at intersections instead of subtracting
        let allPieces = getAllMosaicPieces(paths, using: fillRule)
        
        return allPieces
    }
    
    /// Gets all mosaic pieces - TRUE STAINED GLASS: Complete planar subdivision
    /// EVERY region becomes its own object - no large interior pieces remain
    private static func getAllMosaicPieces(_ paths: [CGPath], using fillRule: CGPathFillRule) -> [(CGPath, Int)] {
        guard !paths.isEmpty else { return [] }
        
        let shapeCount = paths.count
        
        // SAFETY CHECK: Prevent integer overflow crash
        // Mosaic operation has exponential complexity (2^n combinations)
        // Limit to reasonable number of shapes to prevent crash
        guard shapeCount <= 20 else {
            // Return original paths as fallback
            return paths.enumerated().map { (index, path) in (path, index) }
        }
        
        
        var allPieces: [(CGPath, Int)] = []
        
        // GENERATE ALL POSSIBLE INTERSECTION COMBINATIONS
        // For n shapes, we need to check 2^n - 1 possible combinations (excluding empty set)
        
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
                }
            }
        }
        
        // REMOVE DUPLICATES: Check for pieces that occupy the same geometric area
        
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

    // MARK: - Integration Support
    
    // MARK: - Performance Analysis
    // MARK: - Cut Operations (CoreGraphics Alternative to Trim)
    
    /// Cut operation: CoreGraphics-based alternative to Trim with curve preservation
    /// Removes HIDDEN parts of shapes that are behind other shapes (like Trim, but preserves curves)
    /// - Parameters:
    ///   - paths: Array of paths in stacking order (first = back, last = front)
    ///   - fillRule: Fill rule to use (.winding or .evenOdd)
    /// - Returns: Array of tuples: (cutPath, originalShapeIndex)
    static func cutWithShapeTracking(_ paths: [CGPath], using fillRule: CGPathFillRule = .winding) -> [(CGPath, Int)] {
        guard paths.count >= 2 else {
            return paths.enumerated().map { (index, path) in (path, index) }
        }
        
        
        var resultPaths: [(CGPath, Int)] = []
        
        // CoreGraphics Cut Algorithm:
        // Process shapes from BACK to FRONT (stacking order)
        // For each shape, subtract all shapes that are IN FRONT of it
        // This removes the HIDDEN parts while preserving smooth curves
        
        for i in 0..<paths.count {
            let currentPath = paths[i]
            guard !currentPath.isEmpty else {
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
                } else {
                    // If subtraction results in empty, this shape is completely hidden
                    visiblePath = CGMutablePath() // Empty path
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
                } else {
                }
            } else {
                // No shapes in front, so keep the entire shape (nothing to cut)
                resultPaths.append((currentPath, i))
            }
        }
        
        return resultPaths
    }

    /// Cut operation: Simplified version that returns only paths
    /// - Parameters:
    ///   - paths: Array of paths in stacking order (first = back, last = front)
    ///   - fillRule: Fill rule to use (.winding or .evenOdd)
    /// - Returns: Array of cut paths with hidden parts removed
    static func cut(_ paths: [CGPath], using fillRule: CGPathFillRule = .winding) -> [CGPath] {
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
        
        
        // STEP 1: Apply Cut logic to ALL shapes to remove hidden overlaps and maintain visual appearance
        let cutResults = cutWithShapeTracking(paths, using: fillRule)
        
        
        // STEP 2: Group cut results by color (same colors only)
        
        var colorGroups: [VectorColor: [(CGPath, Int)]] = [:]
        
        for (cutPath, originalIndex) in cutResults {
            let color = colors[originalIndex]
            if colorGroups[color] == nil {
                colorGroups[color] = []
            }
            colorGroups[color]?.append((cutPath, originalIndex))
        }
        
        
        var resultPaths: [(CGPath, Int)] = []
        
        // STEP 3: For each color group, union ALL pieces of the same color together

        for (_, group) in colorGroups {
            if group.count == 1 {
                // Single piece of this color, no union needed
                let (path, originalIndex) = group[0]
                resultPaths.append((path, originalIndex))
            } else {
                // Multiple pieces of same color - union ALL of them together (not just connected ones)
                let pathsToUnion = group.map { $0.0 }
                let firstOriginalIndex = group[0].1

                if let unionedPath = Self.unionMultiplePaths(pathsToUnion, using: fillRule) {
                    resultPaths.append((unionedPath, firstOriginalIndex))
                } else {
                    // Union failed, keep pieces separate as fallback
                    for (path, originalIndex) in group {
                        resultPaths.append((path, originalIndex))
                    }
                }
            }
        }
        
        return resultPaths
    }
    
    // MARK: - Crop Operations (CoreGraphics Alternative to ClipperPath)
    
    /// Crop operation: CoreGraphics-based alternative to ClipperPath with curve preservation
    /// Uses top shape to crop shapes beneath it
    /// 1. Top shape becomes invisible (no fill, no stroke) - it's the crop boundary
    /// 2. All other shapes are cropped to only show parts within the crop boundary  
    /// 3. Then everything gets CUT - removing hidden overlapping parts
    /// - Parameters:
    ///   - paths: Array of paths in stacking order (first = back, last = front)
    ///   - fillRule: Fill rule to use (.winding or .evenOdd)
    /// - Returns: Array of tuples: (croppedPath, originalShapeIndex, isInvisibleCropShape)
    static func cropWithShapeTracking(_ paths: [CGPath], using fillRule: CGPathFillRule = .winding) -> [(CGPath, Int, Bool)] {
        guard paths.count >= 2 else {
            return paths.enumerated().map { (index, path) in (path, index, false) }
        }
        
        
        guard let cropShape = paths.last else {
            // Log.error("❌ CROP: No crop shape found", category: .general)
            return []
        }  // Top shape is the crop shape
        let shapesToCrop = Array(paths.dropLast())
        let cropShapeIndex = paths.count - 1
        
        var croppedPaths: [CGPath] = []
        var originalIndices: [Int] = []
        
        // STEP 1: Intersect each shape with the crop shape using CoreGraphics (crop to boundary)
        for (index, path) in shapesToCrop.enumerated() {
            guard !path.isEmpty && !cropShape.isEmpty else {
                continue
            }
            
            // Use CoreGraphics intersection (preserves curves!)
            if let croppedPath = intersection(path, cropShape, using: fillRule) {
                if !croppedPath.isEmpty && !croppedPath.boundingBoxOfPath.isEmpty {
                    croppedPaths.append(croppedPath)
                    originalIndices.append(index)
                } else {
                }
            } else {
            }
        }
        
        
        // STEP 2: Apply CUT to the cropped shapes to remove hidden overlapping parts
        if croppedPaths.count >= 2 {
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
            
            return finalResults
        }
    }
    
}
