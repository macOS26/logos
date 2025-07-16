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
    
    /// PROFESSIONAL SPLIT: CoreGraphics-based alternative to Divide that preserves curves
    /// Uses native line intersection/subtraction operations to split paths at their intersections
    /// - Parameters:
    ///   - paths: Array of paths to split
    ///   - fillRule: Fill rule to use (.winding or .evenOdd)
    /// - Returns: Array of split path components
    public static func split(_ paths: [CGPath], using fillRule: CGPathFillRule = .winding) -> [CGPath] {
        guard paths.count >= 2 else { return paths }
        
        print("🔨 PROFESSIONAL SPLIT (CoreGraphics): Processing \(paths.count) paths with curve preservation")
        
        var resultPaths: [CGPath] = []
        
        // STEP 1: Get unique (non-overlapping) parts of each path
        print("  → Finding unique parts of each path...")
        for i in 0..<paths.count {
            let currentPath = paths[i]
            guard !currentPath.isEmpty else { continue }
            
            // Start with the current path
            var remainingPath = currentPath
            
            // Subtract all other paths from it
            for j in 0..<paths.count where j != i {
                let otherPath = paths[j]
                guard !otherPath.isEmpty else { continue }
                
                if let subtracted = subtract(otherPath, from: remainingPath, using: fillRule) {
                    remainingPath = subtracted
                } else {
                    // If subtraction results in empty path, this part is completely overlapped
                    remainingPath = CGMutablePath() // Empty path
                    break
                }
            }
            
            // Add the unique parts as separate components
            if !remainingPath.isEmpty {
                let components = componentsSeparated(remainingPath, using: fillRule)
                resultPaths.append(contentsOf: components)
            }
        }
        
        // STEP 2: Get 2-way intersections using CoreGraphics
        print("  → Finding 2-way intersections...")
        for i in 0..<paths.count {
            for j in (i+1)..<paths.count {
                let pathA = paths[i]
                let pathB = paths[j]
                
                guard !pathA.isEmpty && !pathB.isEmpty else { continue }
                
                if let intersectionResult = intersection(pathA, pathB, using: fillRule) {
                    // Remove this intersection from higher-order overlaps by subtracting all other paths
                    var cleanedIntersection = intersectionResult
                    
                    for k in 0..<paths.count where k != i && k != j {
                        let otherPath = paths[k]
                        guard !otherPath.isEmpty else { continue }
                        
                        if let subtracted = subtract(otherPath, from: cleanedIntersection, using: fillRule) {
                            cleanedIntersection = subtracted
                        } else {
                            // This 2-way intersection is completely covered by other paths
                            cleanedIntersection = CGMutablePath() // Empty path
                            break
                        }
                    }
                    
                    if !cleanedIntersection.isEmpty {
                        let components = componentsSeparated(cleanedIntersection, using: fillRule)
                        resultPaths.append(contentsOf: components)
                    }
                }
            }
        }
        
        // STEP 3: Get 3-way intersections
        if paths.count >= 3 {
            print("  → Finding 3-way intersections...")
            for i in 0..<paths.count {
                for j in (i+1)..<paths.count {
                    for k in (j+1)..<paths.count {
                        let pathA = paths[i]
                        let pathB = paths[j]
                        let pathC = paths[k]
                        
                        guard !pathA.isEmpty && !pathB.isEmpty && !pathC.isEmpty else { continue }
                        
                        // Get intersection of all three
                        if let intersectionAB = intersection(pathA, pathB, using: fillRule),
                           let intersectionABC = intersection(intersectionAB, pathC, using: fillRule) {
                            
                            // Remove this intersection from higher-order overlaps
                            var cleanedIntersection = intersectionABC
                            
                            for l in 0..<paths.count where l != i && l != j && l != k {
                                let otherPath = paths[l]
                                guard !otherPath.isEmpty else { continue }
                                
                                if let subtracted = subtract(otherPath, from: cleanedIntersection, using: fillRule) {
                                    cleanedIntersection = subtracted
                                } else {
                                    cleanedIntersection = CGMutablePath() // Empty path
                                    break
                                }
                            }
                            
                            if !cleanedIntersection.isEmpty {
                                let components = componentsSeparated(cleanedIntersection, using: fillRule)
                                resultPaths.append(contentsOf: components)
                            }
                        }
                    }
                }
            }
        }
        
        // STEP 4: Get 4-way+ intersections
        if paths.count >= 4 {
            print("  → Finding 4-way+ intersections...")
            
            // For 4+ paths, we can continue with the same pattern
            // This gets computationally expensive, but CoreGraphics handles it efficiently
            let multiWayIntersection = getMultiWayIntersectionCoreGraphics(paths, using: fillRule)
            if !multiWayIntersection.isEmpty {
                let components = componentsSeparated(multiWayIntersection, using: fillRule)
                resultPaths.append(contentsOf: components)
            }
        }
        
        print("✅ PROFESSIONAL SPLIT (CoreGraphics): Created \(resultPaths.count) pieces from \(paths.count) originals (curves preserved)")
        return resultPaths
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
        print("   Adobe Illustrator Cut: Removing HIDDEN parts, keeping visible appearance")
        
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
}

 
