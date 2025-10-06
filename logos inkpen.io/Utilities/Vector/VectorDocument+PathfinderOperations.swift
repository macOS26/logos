//
//  VectorDocument+PathfinderOperations.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI

// MARK: - Pathfinder Operations
extension VectorDocument {

    // MARK: - Pathfinder Operations

    /// Returns true if the operation was successful, false otherwise
    func performPathfinderOperation(_ operation: PathfinderOperation) -> Bool {
        
        // Get selected shapes in correct STACKING ORDER
        let selectedShapes = getSelectedShapesInStackingOrder()
        guard !selectedShapes.isEmpty else {
            Log.error("❌ No shapes selected for pathfinder operation", category: .error)
            return false
        }
        
        // Log.info("📚 STACKING ORDER: Processing \(selectedShapes.count) shapes", category: .general)
        for (_, _) in selectedShapes.enumerated() {
            // Log.info("  \(index): \(shape.name) (bottom→top)", category: .general)
        }
        
        // Convert shapes to CGPaths
        let paths = selectedShapes.map { $0.path.cgPath }
        
        // Validate operation can be performed
        guard ProfessionalPathOperations.canPerformOperation(operation, on: paths) else {
            Log.error("❌ Cannot perform \(operation.rawValue) on selected shapes", category: .error)
            return false
        }
        
        // Save to undo stack before making changes
        saveToUndoStack()
        
        // Perform the operation
        var resultShapes: [VectorShape] = []
        
        switch operation {
        // SHAPE MODES
        case .union:
            // UNION: Combines exactly two shapes, result takes color of TOPMOST object
            if let unionPath = ProfessionalPathOperations.union(paths) {
                guard let topmostShape = selectedShapes.last else {
                    Log.error("❌ UNION: No topmost shape found", category: .general)
                    return false
                } // Last in array = topmost in stacking order
                let unionShape = VectorShape(
                    name: "Union Shape",
                    path: VectorPath(cgPath: unionPath),
                    strokeStyle: topmostShape.strokeStyle,
                    fillStyle: topmostShape.fillStyle,
                    transform: .identity,
                    opacity: topmostShape.opacity
                )
                resultShapes = [unionShape]
                // Log.info("✅ UNION: Created unified shape with topmost object's color", category: .fileOperations)
            }
            
        case .minusFront:
            // PUNCH: Front objects subtract from back object, result takes color of BACK object
            guard selectedShapes.count >= 2 else { 
                Log.error("❌ PUNCH requires at least 2 shapes", category: .error)
                return false 
            }
            
            guard let backShape = selectedShapes.first else {
                Log.error("❌ PUNCH: No back shape found", category: .general)
                return false
            }    // First in array = bottommost = back
            let frontShapes = Array(selectedShapes.dropFirst()) // All others = front
            
            // Log.info("🔪 PUNCH: Back shape '\(backShape.name)' - Front shapes: \(frontShapes.map { $0.name })", category: .general)
            
            var resultPath = backShape.path.cgPath
            
            // Subtract each front shape from the result
            for frontShape in frontShapes {
                if let subtractedPath = ProfessionalPathOperations.minusFront(frontShape.path.cgPath, from: resultPath) {
                    resultPath = subtractedPath
                    // Log.info("  ⚡ Subtracted '\(frontShape.name)' from result", category: .general)
                }
            }
            
            // Result takes style of BACK object
            let resultShape = VectorShape(
                name: "Punch Result",
                path: VectorPath(cgPath: resultPath),
                strokeStyle: backShape.strokeStyle,
                fillStyle: backShape.fillStyle,
                transform: .identity,
                opacity: backShape.opacity
            )
            resultShapes = [resultShape]
            // Log.info("✅ PUNCH: Result takes back object's color (\(backShape.name))", category: .fileOperations)
            
        case .intersect:
            // INTERSECT: Keep only overlapping areas, result takes color of TOPMOST object
            guard selectedShapes.count == 2 else {
                Log.error("❌ INTERSECT requires exactly 2 shapes", category: .error)
                return false
            }
            
            if let intersectedPath = ProfessionalPathOperations.intersect(paths[0], paths[1]) {
                guard let topmostShape = selectedShapes.last else {
                    Log.error("❌ No topmost shape found", category: .general)
                    return false
                } // Last = topmost
                let intersectedShape = VectorShape(
                    name: "Intersected Shape",
                    path: VectorPath(cgPath: intersectedPath),
                    strokeStyle: topmostShape.strokeStyle,
                    fillStyle: topmostShape.fillStyle,
                    transform: .identity,
                    opacity: topmostShape.opacity
                )
                resultShapes = [intersectedShape]
                // Log.info("✅ INTERSECT: Result takes topmost object's color (\(topmostShape.name))", category: .fileOperations)
            }
            
        case .exclude:
            // EXCLUDE: Remove overlapping areas, result takes color of TOPMOST object
            guard selectedShapes.count == 2 else {
                Log.error("❌ EXCLUDE requires exactly 2 shapes", category: .error)
                return false
            }
            
            let excludedPaths = ProfessionalPathOperations.exclude(paths[0], paths[1])
            guard let topmostShape = selectedShapes.last else {
                Log.error("❌ No topmost shape found", category: .error)
                return false
            }
            
            for (index, excludedPath) in excludedPaths.enumerated() {
                let excludedShape = VectorShape(
                    name: "Excluded Shape \(index + 1)",
                    path: VectorPath(cgPath: excludedPath),
                    strokeStyle: topmostShape.strokeStyle,
                    fillStyle: topmostShape.fillStyle,
                    transform: .identity,
                    opacity: topmostShape.opacity
                )
                resultShapes.append(excludedShape)
            }
            // Log.info("✅ EXCLUDE: Created \(resultShapes.count) pieces with topmost object's color (\(topmostShape.name))", category: .fileOperations)
        
        // PATHFINDER EFFECTS - These retain original colors
        case .mosaic:
            // MOSAIC: CoreGraphics-based alternative to Divide with curve preservation and perfect color fidelity
            let mosaicResults = CoreGraphicsPathOperations.splitWithShapeTracking(paths, using: .winding)
            
            // Mosaic: Each resulting piece maintains the color of its original shape (like stained glass)
            var shapeCounters: [Int: Int] = [:]
            
            for (mosaicPath, originalShapeIndex) in mosaicResults {
                guard originalShapeIndex < selectedShapes.count else { continue }
                
                let originalShape = selectedShapes[originalShapeIndex]
                
                // Track how many pieces we've created from this original shape
                shapeCounters[originalShapeIndex] = (shapeCounters[originalShapeIndex] ?? 0) + 1
                let pieceNumber = shapeCounters[originalShapeIndex] ?? 1
                
                let mosaicShape = VectorShape(
                    name: pieceNumber > 1 ? "Mosaic \(originalShape.name) (\(pieceNumber))" : "Mosaic \(originalShape.name)",
                    path: VectorPath(cgPath: mosaicPath),
                    strokeStyle: originalShape.strokeStyle,
                    fillStyle: originalShape.fillStyle,
                    transform: .identity,
                    opacity: originalShape.opacity
                )
                resultShapes.append(mosaicShape)
            }
            // Log.info("✅ MOSAIC: Created \(resultShapes.count) pieces - TRUE stained glass effect (ALL visible areas preserved)", category: .fileOperations)
            
        case .cut:
            // CUT: CoreGraphics-based alternative to Trim with curve preservation
            let cutResults = CoreGraphicsPathOperations.cutWithShapeTracking(paths, using: .winding)
            
            // Cut: Each resulting piece maintains the color of its original shape (with curves preserved)
            var shapeCounters: [Int: Int] = [:]
            
            for (cutPath, originalShapeIndex) in cutResults {
                guard originalShapeIndex < selectedShapes.count else { continue }
                
                let originalShape = selectedShapes[originalShapeIndex]
                
                // Track how many pieces we've created from this original shape
                shapeCounters[originalShapeIndex] = (shapeCounters[originalShapeIndex] ?? 0) + 1
                let pieceNumber = shapeCounters[originalShapeIndex] ?? 1
                
                let cutShape = VectorShape(
                    name: pieceNumber > 1 ? "Cut \(originalShape.name) (\(pieceNumber))" : "Cut \(originalShape.name)",
                    path: VectorPath(cgPath: cutPath),
                    strokeStyle: nil, // CUT removes strokes
                    fillStyle: originalShape.fillStyle,
                    transform: .identity,
                    opacity: originalShape.opacity
                )
                resultShapes.append(cutShape)
            }
            
            // Log.info("✅ CUT: Created \(resultShapes.count) cut shapes with curves preserved, removed strokes", category: .fileOperations)
            
        case .merge:
            // MERGE: Merge - cut all shapes first (maintain appearance), then merge same colors
            let colors = selectedShapes.compactMap { $0.fillStyle?.color ?? .clear }
            
            guard colors.count == selectedShapes.count else {
                Log.error("❌ MERGE: Could not extract colors from all shapes", category: .error)
                return false
            }
            
            let mergeResults = ProfessionalPathOperations.professionalMergeWithShapeTracking(paths, colors: colors)
            
            // Merge: Cut-first approach maintains appearance, then same colors get unified, removes strokes
            var shapeCounters: [Int: Int] = [:]
            
            for (mergedPath, originalShapeIndex) in mergeResults {
                guard originalShapeIndex < selectedShapes.count else { continue }
                
                let originalShape = selectedShapes[originalShapeIndex]
                
                // Track how many pieces we've created from this original shape
                shapeCounters[originalShapeIndex] = (shapeCounters[originalShapeIndex] ?? 0) + 1
                let pieceNumber = shapeCounters[originalShapeIndex] ?? 1
                
                let mergedShape = VectorShape(
                    name: pieceNumber > 1 ? "Merged \(originalShape.name) (\(pieceNumber))" : "Merged \(originalShape.name)",
                    path: VectorPath(cgPath: mergedPath),
                    strokeStyle: nil, // MERGE removes strokes
                    fillStyle: originalShape.fillStyle,
                    transform: .identity,
                    opacity: originalShape.opacity
                )
                resultShapes.append(mergedShape)
            }
            // Log.info("✅ MERGE: Created \(resultShapes.count) color-unified shapes with maintained appearance, removed strokes", category: .fileOperations)
            
        case .crop:
            // CROP: Use topmost shape to crop others, then trim. Top shape becomes invisible.
            let cropResults = ProfessionalPathOperations.professionalCropWithShapeTracking(paths)
            
            // Crop: Each resulting piece maintains the color of its original shape
            var shapeCounters: [Int: Int] = [:]
            
            for (croppedPath, originalShapeIndex, isInvisibleCropShape) in cropResults {
                guard originalShapeIndex < selectedShapes.count else { continue }
                
                let originalShape = selectedShapes[originalShapeIndex]
                
                if isInvisibleCropShape {
                    // Top shape becomes invisible (no fill, no stroke)
                    let invisibleCropShape = VectorShape(
                        name: "Crop Boundary (\(originalShape.name))",
                        path: VectorPath(cgPath: croppedPath),
                        strokeStyle: nil, // No stroke
                        fillStyle: nil,   // No fill - invisible
                        transform: .identity,
                        opacity: originalShape.opacity
                    )
                    resultShapes.append(invisibleCropShape)
                    // Log.info("   ✅ Created invisible crop boundary from \(originalShape.name)", category: .general)
                } else {
                    // Track how many pieces we've created from this original shape
                    shapeCounters[originalShapeIndex] = (shapeCounters[originalShapeIndex] ?? 0) + 1
                    let pieceNumber = shapeCounters[originalShapeIndex] ?? 1
                    
                    let croppedShape = VectorShape(
                        name: pieceNumber > 1 ? "Cropped \(originalShape.name) (\(pieceNumber))" : "Cropped \(originalShape.name)",
                        path: VectorPath(cgPath: croppedPath),
                        strokeStyle: nil, // CROP removes strokes
                        fillStyle: originalShape.fillStyle,
                        transform: .identity,
                        opacity: originalShape.opacity
                    )
                    resultShapes.append(croppedShape)
                }
            }
            
            // Log.info("✅ CROP: Created \(resultShapes.count) shapes (includes invisible crop boundary), removed strokes", category: .fileOperations)
            
        case .dieline:
            // DIELINE: Apply Divide then convert all results to 1px black strokes with no fill
            let dielinePaths = ProfessionalPathOperations.dieline(paths)
            
            for (index, dielinePath) in dielinePaths.enumerated() {
                let dielineShape = VectorShape(
                    name: "Dieline \(index + 1)",
                    path: VectorPath(cgPath: dielinePath),
                    strokeStyle: StrokeStyle(
                        color: .black,
                        width: 1.0,
                        placement: .center,
                        lineCap: .round,
                        lineJoin: .round
                    ),
                    fillStyle: nil, // DIELINE has no fill - only 1px black stroke
                    transform: .identity,
                    opacity: 1.0
                )
                resultShapes.append(dielineShape)
            }
            // Log.info("✅ DIELINE: Created \(resultShapes.count) dieline shapes", category: .fileOperations)
            
        case .separate:
            // SEPARATE: Break compound paths into individual components
            var separatedShapes: [VectorShape] = []
            
            for (_, shape) in selectedShapes.enumerated() {
                let components = CoreGraphicsPathOperations.componentsSeparated(shape.path.cgPath, using: .winding)
                
                if components.count <= 1 {
                    // No separation needed, keep original
                    separatedShapes.append(shape)
                    // Log.info("   Shape \(shapeIndex + 1): No components to separate", category: .general)
                } else {
                    // Create separate shapes for each component
                    for (componentIndex, component) in components.enumerated() {
                        let separatedShape = VectorShape(
                            name: components.count > 1 ? "\(shape.name) Component \(componentIndex + 1)" : shape.name,
                            path: VectorPath(cgPath: component),
                            strokeStyle: shape.strokeStyle,
                            fillStyle: shape.fillStyle,
                            transform: shape.transform,
                            opacity: shape.opacity
                        )
                        separatedShapes.append(separatedShape)
                    }
                    // Log.info("   Shape \(shapeIndex + 1): Separated into \(components.count) components", category: .general)
                }
            }
            
            resultShapes = separatedShapes
            // Log.info("✅ SEPARATE: Created \(resultShapes.count) individual shapes from \(selectedShapes.count) compound paths", category: .fileOperations)
            
        case .kick:
            // KICK: Back objects subtract from front object, result takes color of FRONT object
            guard selectedShapes.count >= 2 else {
                Log.error("❌ KICK requires at least 2 shapes", category: .error)
                return false
            }
            
            guard let frontShape = selectedShapes.last else {
                Log.error("❌ KICK: No front shape found", category: .general)
                return false
            }     // Last in array = topmost = front
            let backShapes = Array(selectedShapes.dropLast()) // All others = back
            
            // Log.info("🔪 KICK: Front shape '\(frontShape.name)' - Back shapes: \(backShapes.map { $0.name })", category: .general)
            
            var resultPath = frontShape.path.cgPath
            
            // Subtract each back shape from the result
            for backShape in backShapes {
                if let subtractedPath = ProfessionalPathOperations.kick(resultPath, from: backShape.path.cgPath) {
                    resultPath = subtractedPath
                    // Log.info("  ⚡ Subtracted '\(backShape.name)' from result", category: .general)
                }
            }
            
            // Result takes style of FRONT object
            let resultShape = VectorShape(
                name: "Kick Result",
                path: VectorPath(cgPath: resultPath),
                strokeStyle: frontShape.strokeStyle,
                fillStyle: frontShape.fillStyle,
                transform: .identity,
                opacity: frontShape.opacity
            )
            resultShapes = [resultShape]
            // Log.info("✅ KICK: Result takes front object's color (\(frontShape.name))", category: .fileOperations)
        }
        
        guard !resultShapes.isEmpty else {
            Log.error("❌ Pathfinder operation \(operation.rawValue) produced no results", category: .error)
            return false
        }
        
        // Remove original selected shapes
        removeSelectedShapes()
        
        // Add new result shapes and select them
        for resultShape in resultShapes {
            addShape(resultShape)
            selectedShapeIDs.insert(resultShape.id)
        }
        
        return true
    }
}
