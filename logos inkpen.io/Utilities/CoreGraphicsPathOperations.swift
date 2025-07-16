import CoreGraphics
import Foundation

/// CoreGraphics-based path operations using native boolean operations (macOS 14+)
/// 
/// This provides modern, hardware-accelerated path operations that preserve smooth curves
/// unlike ClipperPath which tessellates curves into line segments.
@available(macOS 14.0, iOS 17.0, *)
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
    /// - Returns: Path representing areas in either path but not both
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
    
    /// Normalizes a path using the specified fill rule
    /// - Parameters:
    ///   - path: Path to normalize
    ///   - fillRule: Fill rule to use (.winding or .evenOdd)
    /// - Returns: Normalized path
    public static func normalized(_ path: CGPath, using fillRule: CGPathFillRule = .winding) -> CGPath? {
        guard !path.isEmpty else { return nil }
        
        let result = path.normalized(using: fillRule)
        return result.isEmpty ? nil : result
    }
    
    /// Separates a path into individual connected components
    /// - Parameters:
    ///   - path: Path to separate
    ///   - fillRule: Fill rule to use (.winding or .evenOdd)
    /// - Returns: Array of individual path components
    public static func componentsSeparated(_ path: CGPath, using fillRule: CGPathFillRule = .winding) -> [CGPath] {
        guard !path.isEmpty else { return [] }
        
        return path.componentsSeparated(using: fillRule)
    }
    
    // MARK: - Integration with Existing VectorPath System
    
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
    
    // MARK: - Integration Support
    

    
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
}

 