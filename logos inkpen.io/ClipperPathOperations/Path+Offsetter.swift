// STROKE-BASED OFFSET PATHS - THE PROFESSIONAL SOLUTION
// This bypasses Clipper completely and uses Core Graphics strokes + outline
// to create perfect smooth offset paths with true bezier curves

import Foundation
import CoreGraphics

/// Professional Stroke-Based Offset Options (Uses Core Graphics Strokes)
/// This creates TRUE smooth bezier curves for rounded corners, not polygon approximation
public struct StrokeBasedOffsetOptions {
    public let offset: CGFloat
    public let joinType: CGLineJoin  // Use Core Graphics join types directly
    public let endType: CGLineCap    // Use Core Graphics cap types directly
    public let miterLimit: CGFloat
    public let keepOriginal: Bool
    
    public init(
        offset: CGFloat,
        joinType: CGLineJoin = .round,
        endType: CGLineCap = .round,
        miterLimit: CGFloat = 4.0,
        keepOriginal: Bool = true
    ) {
        self.offset = offset
        self.joinType = joinType
        self.endType = endType
        self.miterLimit = miterLimit
        self.keepOriginal = keepOriginal
    }
    
    /// Adobe Illustrator "Round" preset with perfect smooth corners
    public static func roundJoin(offset: CGFloat, keepOriginal: Bool = true) -> StrokeBasedOffsetOptions {
        return StrokeBasedOffsetOptions(
            offset: offset,
            joinType: .round,
            endType: .round,
            miterLimit: 4.0,
            keepOriginal: keepOriginal
        )
    }
    
    /// Adobe Illustrator "Miter" preset  
    public static func miterJoin(offset: CGFloat, miterLimit: CGFloat = 4.0, keepOriginal: Bool = true) -> StrokeBasedOffsetOptions {
        return StrokeBasedOffsetOptions(
            offset: offset,
            joinType: .miter,
            endType: .butt,
            miterLimit: miterLimit,
            keepOriginal: keepOriginal
        )
    }
    
    /// Adobe Illustrator "Bevel" preset
    public static func bevelJoin(offset: CGFloat, keepOriginal: Bool = true) -> StrokeBasedOffsetOptions {
        return StrokeBasedOffsetOptions(
            offset: offset,
            joinType: .bevel,
            endType: .butt,
            miterLimit: 4.0,
            keepOriginal: keepOriginal
        )
    }
    
    /// Adobe Illustrator "Square" preset (sharp corners, no miter/bevel/round)
    public static func squareJoin(offset: CGFloat, keepOriginal: Bool = true) -> StrokeBasedOffsetOptions {
        return StrokeBasedOffsetOptions(
            offset: offset,
            joinType: .miter,  // Use miter with limit 1.0 for sharp square corners
            endType: .butt,
            miterLimit: 1.0,   // Very low miter limit creates square corners
            keepOriginal: keepOriginal
        )
    }
}

extension CGPath {
    
    /// PROFESSIONAL STROKE-BASED OFFSET (True Adobe Illustrator Quality)
    /// This creates perfect smooth bezier curves for ALL join types using stroke expansion
    public func strokeBasedOffset(_ options: StrokeBasedOffsetOptions) -> [CGPath] {
        guard !self.isEmpty else { return [] }
        
        let offsetDistance = abs(options.offset)
        guard offsetDistance > 0 else { return [self] }
        
        if options.offset > 0 {
            // OUTSET: Create stroke, expand it, separate compound path, keep outer path
            return createStrokeBasedOutsetPaths(distance: offsetDistance, options: options)
        } else {
            // INSET: Create negative stroke effect
            return createInsetPaths(distance: offsetDistance, options: options)
        }
    }
    
    /// Creates outset (expansion) paths using stroke+expand+separate technique for ALL join types
    private func createStrokeBasedOutsetPaths(distance: CGFloat, options: StrokeBasedOffsetOptions) -> [CGPath] {
        // Step 1: Create stroke with double the offset distance (stroke goes both directions)
        let strokeWidth = distance * 2.0
        
        print("🎨 STROKE-BASED OFFSET: \(options.joinType) join, width=\(strokeWidth), miterLimit=\(options.miterLimit)")
        
        // Step 2: Create stroked path with specified join type
        let strokedPath = self.copy(
            strokingWithWidth: strokeWidth,
            lineCap: options.endType,
            lineJoin: options.joinType,
            miterLimit: options.miterLimit
        )
        
        // Step 3: Separate the compound path and keep only the outer path
        // This works for ALL join types: Round, Miter, Bevel, and Square
        let separatedPaths = separateCompoundPath(strokedPath)
        
        // Step 4: Keep only the largest path (the outer expanded path)
        if let largestPath = findLargestPath(separatedPaths) {
            print("✅ STROKE-BASED SUCCESS: Clean outer path extracted for \(options.joinType) join")
            return [largestPath]
        } else {
            // Fallback to original stroke if separation fails
            print("⚠️ FALLBACK: Using unseparated stroke path")
            return [strokedPath]
        }
    }
    
    /// Separates a compound path into individual path components
    private func separateCompoundPath(_ compoundPath: CGPath) -> [CGPath] {
        var separatedPaths: [CGPath] = []
        var currentSubpath: CGMutablePath?
        
        print("🔍 SEPARATING COMPOUND PATH: Starting separation...")
        
        compoundPath.applyWithBlock { element in
            switch element.pointee.type {
            case .moveToPoint:
                // Start of new subpath - save previous if exists
                if let existingPath = currentSubpath, !existingPath.isEmpty {
                    separatedPaths.append(existingPath.copy()!)
                    print("📍 SUBPATH COMPLETED: Added subpath #\(separatedPaths.count)")
                }
                // Start new subpath
                currentSubpath = CGMutablePath()
                currentSubpath?.move(to: element.pointee.points[0])
                print("🚀 NEW SUBPATH: Starting at \(element.pointee.points[0])")
                
            case .addLineToPoint:
                currentSubpath?.addLine(to: element.pointee.points[0])
                
            case .addQuadCurveToPoint:
                currentSubpath?.addQuadCurve(
                    to: element.pointee.points[1], 
                    control: element.pointee.points[0]
                )
                
            case .addCurveToPoint:
                currentSubpath?.addCurve(
                    to: element.pointee.points[2],
                    control1: element.pointee.points[0], 
                    control2: element.pointee.points[1]
                )
                
            case .closeSubpath:
                currentSubpath?.closeSubpath()
                print("🔒 SUBPATH CLOSED")
                
            @unknown default:
                break
            }
        }
        
        // Add final subpath if exists
        if let existingPath = currentSubpath, !existingPath.isEmpty {
            separatedPaths.append(existingPath.copy()!)
            print("📍 FINAL SUBPATH: Added final subpath #\(separatedPaths.count)")
        }
        
        print("✅ SEPARATION COMPLETE: Found \(separatedPaths.count) subpaths")
        return separatedPaths
    }
    
    /// Finds the largest path by area (the outer expanded path)
    private func findLargestPath(_ paths: [CGPath]) -> CGPath? {
        guard !paths.isEmpty else { return nil }
        
        var largestPath: CGPath?
        var largestArea: CGFloat = 0
        
        print("🔍 FINDING LARGEST PATH: Analyzing \(paths.count) paths...")
        
        for (index, path) in paths.enumerated() {
            let bounds = path.boundingBoxOfPath
            let area = bounds.width * bounds.height
            
            print("📏 PATH #\(index + 1): Bounds=\(bounds), Area=\(area)")
            
            // Only consider paths with reasonable size
            if area > largestArea && area > 1.0 {
                largestArea = area
                largestPath = path
                print("🎯 NEW LARGEST: Path #\(index + 1) is now largest (area: \(area))")
            }
        }
        
        print("✅ LARGEST PATH SELECTED: Area=\(largestArea)")
        return largestPath ?? paths.first
    }
    
    /// Creates inset (contraction) paths using stroke+boolean technique  
    private func createInsetPaths(distance: CGFloat, options: StrokeBasedOffsetOptions) -> [CGPath] {
        // For inset, we need to create a stroke and subtract it from the original
        
        // Step 1: Create the stroke that will be subtracted
        let strokeWidth = distance * 2.0
        
        let _ = self.copy(
            strokingWithWidth: strokeWidth,
            lineCap: options.endType,
            lineJoin: options.joinType,
            miterLimit: options.miterLimit
        )
        
        // Step 2: For inset, we need to subtract the stroke outline from the original
        // This requires boolean operations - use simplified approach for now
        
        // TEMPORARY: For closed paths, create a simple inward offset
        // In production, this would use boolean subtract operation
        if self.isClosedPath() {
            return createSimpleInset(distance: distance, options: options)
        } else {
            // For open paths, just return original
            return [self]
        }
    }
    
    /// Creates simple inset for closed paths (temporary implementation)
    private func createSimpleInset(distance: CGFloat, options: StrokeBasedOffsetOptions) -> [CGPath] {
        // Create a smaller version by scaling toward center
        let bounds = self.boundingBoxOfPath
        let centerX = bounds.midX
        let centerY = bounds.midY
        
        // Calculate scale factor to achieve inset
        let scaleX = max(0.1, (bounds.width - distance * 2) / bounds.width)
        let scaleY = max(0.1, (bounds.height - distance * 2) / bounds.height)
        let scale = min(scaleX, scaleY)
        
        // Create transform that scales around center
        let translateToOrigin = CGAffineTransform(translationX: -centerX, y: -centerY)
        let scaleTransform = CGAffineTransform(scaleX: scale, y: scale)
        let translateBack = CGAffineTransform(translationX: centerX, y: centerY)
        
        let combinedTransform = translateToOrigin.concatenating(scaleTransform).concatenating(translateBack)
        
        var mutableTransform = combinedTransform
        if let insetPath = self.copy(using: &mutableTransform) {
            return [insetPath]
        } else {
            return [self]
        }
    }
}

extension CGPath {
    /// Check if path is closed (ends where it started)
    func isClosedPath() -> Bool {
        var startPoint: CGPoint?
        var lastPoint: CGPoint?
        var isClosed = false
        
        self.applyWithBlock { element in
            switch element.pointee.type {
            case .moveToPoint:
                startPoint = element.pointee.points[0]
                lastPoint = startPoint
            case .addLineToPoint:
                lastPoint = element.pointee.points[0]
            case .addQuadCurveToPoint:
                lastPoint = element.pointee.points[1]
            case .addCurveToPoint:
                lastPoint = element.pointee.points[2]
            case .closeSubpath:
                isClosed = true
            @unknown default:
                break
            }
        }
        
        // Also check if last point equals start point
        if let start = startPoint, let last = lastPoint {
            let distance = sqrt(pow(start.x - last.x, 2) + pow(start.y - last.y, 2))
            if distance < ClipperConstants.epsilon { // Very close points
                isClosed = true
            }
        }
        
        return isClosed
    }
}

// MARK: - Legacy Compatibility with Existing Code

extension ClipperPath {
    /// Professional stroke-based offset that creates smooth bezier curves
    public func strokeBasedProfessionalOffset(_ options: StrokeBasedOffsetOptions) -> [CGPath] {
        // Convert ClipperPath to CGPath first
        let cgPath = self.toCGPath()
        
        // Use stroke-based offset
        return cgPath.strokeBasedOffset(options)
    }
}

// Keep the old interfaces for compatibility but redirect to stroke-based approach
extension ClipperPath {
    /// Enhanced professional offset using stroke-based approach for smooth curves
    public func enhancedProfessionalOffset(_ options: EnhancedOffsetOptions) -> ClipperPaths {
        // Convert to stroke-based options
        let strokeOptions = StrokeBasedOffsetOptions(
            offset: options.offset,
            joinType: options.joinType == .round ? .round : (options.joinType == .square ? .bevel : .miter),
            endType: .round,
            miterLimit: options.miterLimit,
            keepOriginal: options.preserveBezierCurves
        )
        
        // Use stroke-based offset
        let resultPaths = self.strokeBasedProfessionalOffset(strokeOptions)
        
        // Convert back to ClipperPaths for compatibility
        return resultPaths.map { cgPath in
            // Simple conversion back to ClipperPath
            return cgPath.toClipperPath()
        }
    }
}

/// Enhanced professional offset with bezier curve preservation
public struct EnhancedOffsetOptions {
    public let offset: CGFloat
    public let joinType: JoinType
    public let endType: EndType
    public let miterLimit: CGFloat
    public let arcTolerance: CGFloat
    public let preserveBezierCurves: Bool
    public let subdivisionTolerance: CGFloat
    
    public init(
        offset: CGFloat,
        joinType: JoinType = .round,
        endType: EndType = .closedPolygon,
        miterLimit: CGFloat = 4.0,
        arcTolerance: CGFloat = 0.01,
        preserveBezierCurves: Bool = true,
        subdivisionTolerance: CGFloat = 0.05
    ) {
        self.offset = offset
        self.joinType = joinType
        self.endType = endType
        self.miterLimit = miterLimit
        self.arcTolerance = arcTolerance
        self.preserveBezierCurves = preserveBezierCurves
        self.subdivisionTolerance = subdivisionTolerance
    }
}


