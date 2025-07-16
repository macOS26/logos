//
//  ClipperError.swift
//  logos inkpen.io
//
//  Created by Refactoring on 2025
//

import Foundation

/// Errors that can occur during Clipper operations
public enum ClipperError: LocalizedError {
    case openPathsRequirePolyTree
    case executionLocked
    case invalidMaximaConfiguration
    case intersectionProcessingFailed
    case emptyPath
    case invalidPolygonSize
    case unknownError(String)
    
    public var errorDescription: String? {
        switch self {
        case .openPathsRequirePolyTree:
            return "Error: PolyTree struct is needed for open path clipping."
        case .executionLocked:
            return "Error: Clipper execution is already in progress."
        case .invalidMaximaConfiguration:
            return "Error: Invalid maxima configuration in doMaxima."
        case .intersectionProcessingFailed:
            return "Error: Failed to process intersections."
        case .emptyPath:
            return "Error: Empty path provided."
        case .invalidPolygonSize:
            return "Error: Polygon has insufficient points."
        case .unknownError(let message):
            return "Error: \(message)"
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .openPathsRequirePolyTree:
            return "Open paths cannot be processed without using a PolyTree structure."
        case .executionLocked:
            return "Another operation is currently executing."
        case .invalidMaximaConfiguration:
            return "The edge configuration at a local maximum is invalid."
        case .intersectionProcessingFailed:
            return "Unable to properly order or process edge intersections."
        case .emptyPath:
            return "The provided path contains no points."
        case .invalidPolygonSize:
            return "The polygon does not have enough points to form a valid shape."
        case .unknownError:
            return nil
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .openPathsRequirePolyTree:
            return "Use the PolyTree version of execute() when processing open paths."
        case .executionLocked:
            return "Wait for the current operation to complete before starting a new one."
        case .invalidMaximaConfiguration:
            return "Check the input polygon for self-intersections or invalid geometry."
        case .intersectionProcessingFailed:
            return "Simplify the input polygons or check for numerical precision issues."
        case .emptyPath:
            return "Ensure the path contains at least one point before processing."
        case .invalidPolygonSize:
            return "Ensure closed polygons have at least 3 points and open paths have at least 2 points."
        case .unknownError:
            return "Check the input data and try again."
        }
    }
} 