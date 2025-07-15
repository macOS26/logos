//
//  Path+Offsetter.swift
//  
//
//  Created by LuoHuanyu on 2020/2/1.
//

import CoreGraphics

/// Professional Offset Path Options (Adobe Illustrator / FreeHand / CorelDRAW Standards)
/// Based on industry-standard vector graphics applications
public struct ProfessionalOffsetOptions {
    public let offset: CGFloat          // Offset distance (positive = outward, negative = inward)
    public let joinType: JoinType       // Corner treatment: .miter, .round, .square
    public let endType: EndType         // Path end treatment for open paths
    public let miterLimit: CGFloat      // Miter limit for sharp corners (Adobe Illustrator default: 4.0)
    public let arcTolerance: CGFloat    // Arc tolerance for rounded corners (smaller = smoother)
    
    /// Initialize with Adobe Illustrator defaults
    public init(
        offset: CGFloat,
        joinType: JoinType = .miter,
        endType: EndType = .closedPolygon,
        miterLimit: CGFloat = 4.0,
        arcTolerance: CGFloat = 0.25
    ) {
        self.offset = offset
        self.joinType = joinType
        self.endType = endType
        self.miterLimit = miterLimit
        self.arcTolerance = arcTolerance
    }
    
    /// Adobe Illustrator "Miter" preset
    public static func miterJoin(offset: CGFloat, miterLimit: CGFloat = 4.0) -> ProfessionalOffsetOptions {
        return ProfessionalOffsetOptions(
            offset: offset,
            joinType: .miter,
            endType: .closedPolygon,
            miterLimit: miterLimit,
            arcTolerance: 0.25
        )
    }
    
    /// Adobe Illustrator "Round" preset
    public static func roundJoin(offset: CGFloat, arcTolerance: CGFloat = 0.25) -> ProfessionalOffsetOptions {
        return ProfessionalOffsetOptions(
            offset: offset,
            joinType: .round,
            endType: .closedPolygon,
            miterLimit: 4.0,
            arcTolerance: arcTolerance
        )
    }
    
    /// Adobe Illustrator "Bevel" preset
    public static func bevelJoin(offset: CGFloat) -> ProfessionalOffsetOptions {
        return ProfessionalOffsetOptions(
            offset: offset,
            joinType: .square,
            endType: .closedPolygon,
            miterLimit: 4.0,
            arcTolerance: 0.25
        )
    }
}

extension ClipperPath {
    
    /// Simple offset with default settings (backward compatibility)
    public func offset(_ delta: CGFloat) -> ClipperPaths {
        let options = ProfessionalOffsetOptions(offset: delta)
        return professionalOffset(options)
    }
    
    /// Professional offset with full control (Adobe Illustrator / FreeHand / CorelDRAW style)
    public func professionalOffset(_ options: ProfessionalOffsetOptions) -> ClipperPaths {
        let offsetter = Offsetter(
            miterLimit: options.miterLimit,
            arcTolerance: options.arcTolerance
        )
        
        var solution = ClipperPaths()
        offsetter.addPath(self, joinType: options.joinType, endType: options.endType)
        
        do {
            try offsetter.execute(&solution, delta: options.offset)
            return solution
        } catch {
            print("❌ Professional offset failed: \(error)")
            return []
        }
    }
    
    /// Inset path (negative offset) - Adobe Illustrator style
    public func inset(_ distance: CGFloat, joinType: JoinType = .miter, miterLimit: CGFloat = 4.0) -> ClipperPaths {
        let options = ProfessionalOffsetOptions(
            offset: -abs(distance), // Ensure negative for inset
            joinType: joinType,
            endType: .closedPolygon,
            miterLimit: miterLimit,
            arcTolerance: 0.25
        )
        return professionalOffset(options)
    }
    
    /// Outset path (positive offset) - Adobe Illustrator style
    public func outset(_ distance: CGFloat, joinType: JoinType = .miter, miterLimit: CGFloat = 4.0) -> ClipperPaths {
        let options = ProfessionalOffsetOptions(
            offset: abs(distance), // Ensure positive for outset
            joinType: joinType,
            endType: .closedPolygon,
            miterLimit: miterLimit,
            arcTolerance: 0.25
        )
        return professionalOffset(options)
    }
    
    /// CorelDRAW-style contour (multiple offsets at once)
    public func contour(steps: Int, stepDistance: CGFloat, joinType: JoinType = .miter) -> [ClipperPaths] {
        var results: [ClipperPaths] = []
        
        for step in 1...steps {
            let distance = stepDistance * CGFloat(step)
            let options = ProfessionalOffsetOptions(
                offset: distance,
                joinType: joinType,
                endType: .closedPolygon,
                miterLimit: 4.0,
                arcTolerance: 0.25
            )
            let offsetPaths = professionalOffset(options)
            results.append(offsetPaths)
        }
        
        return results
    }
    
    /// Professional outline effect (like Adobe Illustrator's outline stroke)
    /// Creates both inner and outer offsets for outline effects
    public func createOutlineEffect(
        outerOffset: CGFloat,
        innerOffset: CGFloat,
        joinType: JoinType = .miter
    ) -> (outer: ClipperPaths, inner: ClipperPaths) {
        let outerOptions = ProfessionalOffsetOptions(
            offset: abs(outerOffset),
            joinType: joinType,
            endType: .closedPolygon,
            miterLimit: 4.0,
            arcTolerance: 0.25
        )
        
        let innerOptions = ProfessionalOffsetOptions(
            offset: -abs(innerOffset),
            joinType: joinType,
            endType: .closedPolygon,
            miterLimit: 4.0,
            arcTolerance: 0.25
        )
        
        let outer = professionalOffset(outerOptions)
        let inner = professionalOffset(innerOptions)
        
        return (outer: outer, inner: inner)
    }
}

/// Convenience methods for common offset operations
extension ClipperPaths {
    
    /// Apply offset to all paths in collection
    public func offset(_ options: ProfessionalOffsetOptions) -> ClipperPaths {
        var results = ClipperPaths()
        for path in self {
            let offsetPaths = path.professionalOffset(options)
            results.append(contentsOf: offsetPaths)
        }
        return results
    }
    
    /// Simple offset for all paths (backward compatibility)
    public func offset(_ delta: CGFloat) -> ClipperPaths {
        let options = ProfessionalOffsetOptions(offset: delta)
        return offset(options)
    }
}
