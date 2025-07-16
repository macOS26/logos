//
//  ClipperConstants.swift
//  logos inkpen.io
//
//  Created by Refactoring on 2025
//

import CoreGraphics

// MARK: - Numeric Constants

enum ClipperConstants {
    /// Horizontal line indicator
    static let horizontal = -CGFloat.greatestFiniteMagnitude
    
    /// Edge not currently 'owning' a solution
    static let unassigned = -1
    
    /// Edge that would otherwise close a path
    static let skip = -2
    
    /// Default arc tolerance for offset operations
    static let defaultArcTolerance: CGFloat = 0.25
    
    /// Default miter limit for offset operations
    static let defaultMiterLimit: CGFloat = 2.0
    
    /// Two PI constant for circular calculations
    static let twoPi = CGFloat.pi * 2
    
    /// Minimum polygon size for valid output
    static let minPolygonSize = 2
    
    /// Minimum closed polygon size
    static let minClosedPolygonSize = 3
    
    /// Default offset distance for bounds expansion
    static let defaultBoundsOffset: CGFloat = 10.0
    
    /// Epsilon for floating point comparisons
    static let epsilon: CGFloat = 0.01
    
    /// Maximum iterations for certain algorithms
    static let maxIterations = 64
    
    /// Minimum iterations for curve approximation
    static let minIterations = 8
}

// MARK: - Convenience Accessors

let Horizontal = ClipperConstants.horizontal
let Unassigned = ClipperConstants.unassigned
let Skip = ClipperConstants.skip 