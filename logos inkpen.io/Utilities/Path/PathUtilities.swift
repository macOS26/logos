//
//  PathUtilities.swift
//  logos inkpen.io
//
//  Path manipulation utility functions
//

import SwiftUI

/// Delete specific points from a path while maintaining path integrity
func deletePointsFromPath(_ path: VectorPath, selectedPoints: [PointID]) -> VectorPath {
    var elements = path.elements

    // Get element indices to delete (sorted in reverse order to avoid index shifting issues)
    let indicesToDelete = selectedPoints.compactMap { $0.elementIndex }.sorted(by: >)

    // Remove elements from back to front to maintain indices
    for index in indicesToDelete {
        if index < elements.count {
            // Check if this is a critical point for path integrity
            if canDeleteElement(at: index, in: elements) {
                elements.remove(at: index)
            }
        }
    }

    // Ensure path still has a valid structure
    let validatedElements = validatePathElements(elements)

    return VectorPath(elements: validatedElements, isClosed: path.isClosed)
}

/// Check if an element can be safely deleted without breaking the path
func canDeleteElement(at index: Int, in elements: [PathElement]) -> Bool {
    // Don't delete if it's the only move element
    if case .move = elements[index] {
        let moveCount = elements.compactMap { if case .move = $0 { return 1 } else { return nil } }.count
        return moveCount > 1
    }

    // Don't delete if it would result in too few elements
    let pointCount = elements.filter { element in
        switch element {
        case .move, .line, .curve, .quadCurve: return true
        case .close: return false
        }
    }.count

    return pointCount > 2 // Need at least 3 points for a valid path
}

/// Validate and fix path elements to maintain integrity
func validatePathElements(_ elements: [PathElement]) -> [PathElement] {
    var validElements: [PathElement] = []

    for element in elements {
        switch element {
        case .move(_):
            // Always keep move elements
            validElements.append(element)

        case .line(_):
            // Keep line elements if we have a starting point
            if !validElements.isEmpty {
                validElements.append(element)
            }

        case .curve(_, _, _):
            // Keep curve elements if we have a starting point
            if !validElements.isEmpty {
                validElements.append(element)
            }

        case .quadCurve(_, _):
            // Keep quadratic curve elements if we have a starting point
            if !validElements.isEmpty {
                validElements.append(element)
            }

        case .close:
            // Keep close elements if we have enough points
            let pointCount = validElements.filter { element in
                switch element {
                case .move, .line, .curve, .quadCurve: return true
                case .close: return false
                }
            }.count

            if pointCount >= 3 {
                validElements.append(element)
            }
        }
    }

    // Ensure we have at least a move element
    if validElements.isEmpty {
        validElements.append(.move(to: VectorPoint(0, 0)))
    }

    return validElements
}