//
//  Defines.swift
//  
//
//  Created by Luo,Huanyu on 2019/10/13.
//

import Foundation
//import CoreGraphics

/// A polygon represented as an array of CGPoint vertices
public typealias ClipperPath = [CGPoint]

/// A collection of polygons
public typealias ClipperPaths = [[CGPoint]]

/// The type of boolean operation to perform on polygons
public enum ClipType {
    /// Returns the overlapping regions of two polygons
    case intersection
    /// Returns the combined area of two polygons
    case union
    /// Returns the area of the subject polygon minus the clip polygon
    case difference
    /// Returns the areas in either polygon but not in both (symmetric difference)
    case xor
}

/// Identifies the role of a polygon in a clipping operation
public enum PolyType {
    /// The primary polygon(s) being operated on
    case subject
    /// The polygon(s) used to clip the subject
    case clip
}

/// Determines how polygon interiors are calculated
public enum PolyFillType {
    /// Interior is determined by drawing a ray and counting edge crossings (odd = inside)
    case evenOdd
    /// Interior is determined by the winding number (non-zero = inside)
    case nonZero
    /// Interior includes all areas with positive winding numbers
    case positive
    /// Interior includes all areas with negative winding numbers
    case negative
}

/// Specifies how corners are rendered when offsetting polygons
public enum JoinType {
    /// Sharp corners with no limit (can create very long points)
    case square
    /// Rounded corners with arc segments
    case round
    /// Sharp corners limited by miter limit
    case miter
    /// Corners are beveled (cut off)
    case bevel
}

/// Specifies how path ends are rendered when offsetting open paths
public enum EndType {
    /// Path forms a closed polygon
    case closedPolygon
    /// Path forms a closed line (both sides are offset)
    case closedLine
    /// Path ends are squared off
    case openButt
    /// Path ends are extended with square caps
    case openSquare
    /// Path ends are extended with rounded caps
    case openRound
}

enum EdgeSide {
    case left, right
}

enum Direction {
    case rightToLeft, leftToRight
}

enum PointSideType: Int {
    case outside = 0
    case inside = 1
    case onBoundary = -1
}
