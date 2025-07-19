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
        print("   🪟 Preserving ALL visible areas, using CUT-style algorithm with shape identity")
        
        // STEP 1: Get all pieces with their original shape identities preserved
        let allPiecesWithIdentity = getAllSplitPieces(paths, using: fillRule)
        
        // STEP 2: Handle overlapping pieces - topmost shape wins
        print("   🔄 Resolving overlapping pieces using stacking order...")
        let finalPieces = resolveOverlappingPieces(allPiecesWithIdentity, originalPaths: paths)
        
        print("✅ PROFESSIONAL MOSAIC: Created \(finalPieces.count) pieces - CUT-style with original colors preserved")
        return finalPieces
    }
    
    /// Gets all mosaic pieces using CUT-style algorithm that preserves original shape identity
    private static func getAllSplitPieces(_ paths: [CGPath], using fillRule: CGPathFillRule) -> [(CGPath, Int)] {
        guard !paths.isEmpty else { return [] }
        
        print("   🪟 MOSAIC ALGORITHM: Breaking shapes at intersections while preserving original identity")
        
        var resultPieces: [(CGPath, Int)] = []
        
        // Process each shape similar to CUT, but break at intersections instead of subtracting
        for i in 0..<paths.count {
            let currentPath = paths[i]
            guard !currentPath.isEmpty else { continue }
            
            print("   🎯 Processing shape \(i)")
            
            // Start with the complete shape
            var piecesToProcess = [currentPath]
            
            // Split this shape against all OTHER shapes (both in front and behind)
            for j in 0..<paths.count where j != i {
                let otherPath = paths[j]
                guard !otherPath.isEmpty else { continue }
                
                var newPieces: [CGPath] = []
                
                for piece in piecesToProcess {
                    // Find intersection between this piece and the other shape
                    if let intersection = intersection(piece, otherPath, using: fillRule),
                       !intersection.isEmpty {
                        
                        // Split the piece: keep non-overlapping part + intersection part
                        if let remainder = subtract(intersection, from: piece, using: fillRule),
                           !remainder.isEmpty {
                            let remainderComponents = componentsSeparated(remainder, using: fillRule)
                            newPieces.append(contentsOf: remainderComponents.filter { !$0.isEmpty })
                        }
                        
                        let intersectionComponents = componentsSeparated(intersection, using: fillRule)
                        newPieces.append(contentsOf: intersectionComponents.filter { !$0.isEmpty })
                    } else {
                        // No intersection, keep piece as-is
                        newPieces.append(piece)
                    }
                }
                
                piecesToProcess = newPieces
            }
            
            // All pieces from this shape keep the original shape index
            for piece in piecesToProcess {
                if !piece.isEmpty {
                    resultPieces.append((piece, i))
                }
            }
            
            print("   ✅ Shape \(i): Created \(piecesToProcess.count) pieces")
        }
        
        print("   ✅ MOSAIC PIECES: \(resultPieces.count) total pieces with original shape identity preserved")
        return resultPieces
    }
    

    
    /// Resolves overlapping pieces by keeping only the topmost shape's version in each area
    private static func resolveOverlappingPieces(_ pieces: [(CGPath, Int)], originalPaths: [CGPath]) -> [(CGPath, Int)] {
        var finalPieces: [(CGPath, Int)] = []
        
        // Group pieces by spatial location to find overlaps
        for (i, (currentPiece, currentShapeIndex)) in pieces.enumerated() {
            var keepPiece = true
            var conflictingPieces: [(Int, Int)] = [] // (pieceIndex, shapeIndex)
            
            // Check against all other pieces for overlaps
            for (j, (otherPiece, otherShapeIndex)) in pieces.enumerated() {
                guard i != j else { continue }
                
                // Check if pieces overlap significantly
                if let intersectionPath = intersection(currentPiece, otherPiece, using: .winding),
                   !intersectionPath.isEmpty {
                    let intersectionArea = intersectionPath.boundingBoxOfPath.width * intersectionPath.boundingBoxOfPath.height
                    let currentArea = currentPiece.boundingBoxOfPath.width * currentPiece.boundingBoxOfPath.height
                    
                    // If intersection is substantial (>50% of current piece), consider it overlapping
                    if intersectionArea > (currentArea * 0.5) {
                        conflictingPieces.append((j, otherShapeIndex))
                        
                        // If other piece is from a higher-indexed (topmost) shape, don't keep current piece
                        if otherShapeIndex > currentShapeIndex {
                            keepPiece = false
                        }
                    }
                }
            }
            
            if keepPiece {
                finalPieces.append((currentPiece, currentShapeIndex))
                if !conflictingPieces.isEmpty {
                    let conflictShapeIndices = conflictingPieces.map { $0.1 }
                    print("   🏆 Piece from shape \(currentShapeIndex) wins over shapes \(conflictShapeIndices) (higher stacking order)")
                }
            } else {
                let higherShapeIndices = conflictingPieces.compactMap { $0.1 > currentShapeIndex ? $0.1 : nil }
                print("   ❌ Piece from shape \(currentShapeIndex) hidden by higher shapes \(higherShapeIndices)")
            }
        }
        
        print("   🎯 Final result: \(finalPieces.count) pieces after resolving overlaps")
        return finalPieces
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
    
    /// Merge operation: Applies Cut to all shapes first, then merges same colors
    /// - Parameters:
    ///   - paths: Array of paths to merge
    ///   - colors: Array of fill colors (same order as paths)
    ///   - fillRule: Fill rule to use (.winding or .evenOdd)
    /// - Returns: Array of tuples: (mergedPath, originalShapeIndex)
    static func mergeWithShapeTracking(_ paths: [CGPath], colors: [VectorColor], using fillRule: CGPathFillRule = .winding) -> [(CGPath, Int)] {
        guard paths.count >= 2 && colors.count == paths.count else {
            return paths.enumerated().map { (index, path) in (path, index) }
        }
        
        print("🔨 PROFESSIONAL MERGE (CoreGraphics): Processing \(paths.count) paths with two-step process")
        
        // STEP 1: Apply Cut logic to ALL shapes to remove hidden overlaps and maintain visual appearance
        print("   🔨 STEP 1: Applying Cut to all shapes to maintain composite appearance...")
        let cutResults = cutWithShapeTracking(paths, using: fillRule)
        
        print("   ✅ Cut produced \(cutResults.count) pieces from \(paths.count) original shapes")
        
        // STEP 2: Group cut results by color and merge same colors
        print("   🎨 STEP 2: Grouping cut results by color and merging same colors...")
        
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
        
        // STEP 3: Union pieces within each color group
        for (color, group) in colorGroups {
            if group.count == 1 {
                // Single piece in this color group - keep as-is
                let (path, originalIndex) = group[0]
                resultPaths.append((path, originalIndex))
                print("   ✅ Color \(color): Single piece, keeping as-is")
            } else {
                // Multiple pieces in this color group - union them together
                print("   🔧 Color \(color): Unioning \(group.count) cut pieces...")
                
                var mergedPath = group[0].0  // Start with first piece
                let representativeIndex = group[0].1  // Use first piece's index as representative
                
                // Union all pieces in this color group
                for i in 1..<group.count {
                    let (pieceToMerge, _) = group[i]
                    
                    if let unionResult = union(mergedPath, pieceToMerge, using: fillRule) {
                        mergedPath = unionResult
                        print("     → Unioned piece \(i + 1) of \(group.count)")
                    } else {
                        print("     ⚠️ Failed to union piece \(i + 1), continuing...")
                    }
                }
                
                resultPaths.append((mergedPath, representativeIndex))
                print("   ✅ Color \(color): Merged \(group.count) pieces into 1 unified shape")
            }
        }
        
        print("✅ PROFESSIONAL MERGE (CoreGraphics): Created \(resultPaths.count) color-unified shapes with maintained appearance")
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

 



