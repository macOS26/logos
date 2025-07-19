//
//  PathOperationsPanel.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

struct PathOperationsPanel: View {
    @ObservedObject var document: VectorDocument
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Pathfinder")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                
                // Info button
                Button {
                    // Show pathfinder help
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Adobe Illustrator Pathfinder Operations")
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            
            // Shape Modes Section (Adobe Illustrator standard)
                VStack(alignment: .leading, spacing: 8) {
                Text("Shape Modes")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                    ForEach([PathfinderOperation.union, .minusFront, .intersect, .exclude], id: \.self) { operation in
                        PathfinderOperationButton(
                            operation: operation,
                            isEnabled: canPerformOperation(operation)
                        ) {
                            performPathfinderOperation(operation)
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            
            // Pathfinder Effects Section (Adobe Illustrator standard)
            VStack(alignment: .leading, spacing: 8) {
                Text("Pathfinder Effects")
                        .font(.caption)
                    .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                                            ForEach([PathfinderOperation.split, .cut, .merge, .separate, .crop, .dieline, .minusBack], id: \.self) { operation in
                        PathfinderOperationButton(
                            operation: operation,
                            isEnabled: canPerformOperation(operation)
                        ) {
                            performPathfinderOperation(operation)
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            
            // PROFESSIONAL OFFSET PATH SECTION (Adobe Illustrator / FreeHand / CorelDRAW Standards)
            ProfessionalOffsetPathSection(document: document)
            
            // Path Cleanup Section (Professional Tools)
            VStack(alignment: .leading, spacing: 8) {
                Text("Path Cleanup")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                
                VStack(spacing: 6) {
                    Button("Clean Duplicate Points") {
                        if !document.selectedShapeIDs.isEmpty {
                            ProfessionalPathOperations.cleanupSelectedShapesDuplicates(document, tolerance: 5.0)
                        } else {
                            ProfessionalPathOperations.cleanupDocumentDuplicates(document, tolerance: 5.0)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .help("Remove overlapping points and merge their curve data smoothly (⌘⇧K)")
                    .disabled(document.layers.flatMap(\.shapes).isEmpty)
                    
                    Button("Clean All Paths") {
                        ProfessionalPathOperations.cleanupDocumentDuplicates(document, tolerance: 1.0)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Clean duplicate points in all shapes in the document (⌘⌥K)")
                    .disabled(document.layers.flatMap(\.shapes).isEmpty)
                }
                .padding(.horizontal, 12)
            }
            
            Spacer()
        }
    }
    
    private func canPerformOperation(_ operation: PathfinderOperation) -> Bool {
        let selectedShapes = document.getSelectedShapes()
        let paths = selectedShapes.map { $0.path.cgPath }
        return ProfessionalPathOperations.canPerformOperation(operation, on: paths)
    }
    
    private func performPathfinderOperation(_ operation: PathfinderOperation) {
        print("🎨 PROFESSIONAL ADOBE ILLUSTRATOR pathfinder operation: \(operation.rawValue)")
        
        // Get selected shapes in correct STACKING ORDER (Adobe Illustrator standard)
        let selectedShapes = document.getSelectedShapesInStackingOrder()
        guard !selectedShapes.isEmpty else {
            print("❌ No shapes selected for pathfinder operation")
            return
        }
        
        print("📚 STACKING ORDER: Processing \(selectedShapes.count) shapes")
        for (index, shape) in selectedShapes.enumerated() {
            print("  \(index): \(shape.name) (bottom→top)")
        }
        
        // Convert shapes to CGPaths
        let paths = selectedShapes.map { $0.path.cgPath }
        
        // Validate operation can be performed
        guard ProfessionalPathOperations.canPerformOperation(operation, on: paths) else {
            print("❌ Cannot perform \(operation.rawValue) on selected shapes")
            return
        }
        
        // Save to undo stack before making changes
        document.saveToUndoStack()
        
        // Perform the operation using EXACT ADOBE ILLUSTRATOR BEHAVIOR
        var resultShapes: [VectorShape] = []
        
        switch operation {
        // SHAPE MODES (Adobe Illustrator)
        case .union:
            // UNION: Combines exactly two shapes, result takes color of TOPMOST object
            if let unionPath = ProfessionalPathOperations.union(paths) {
                let topmostShape = selectedShapes.last! // Last in array = topmost in stacking order
                let unionShape = VectorShape(
                    name: "Union Shape",
                    path: VectorPath(cgPath: unionPath),
                    strokeStyle: topmostShape.strokeStyle,
                    fillStyle: topmostShape.fillStyle,
                    transform: .identity,
                    opacity: topmostShape.opacity
                )
                resultShapes = [unionShape]
                print("✅ UNION: Created unified shape with topmost object's color")
            }
            
        case .minusFront:
            // PUNCH: Front objects subtract from back object, result takes color of BACK object
            guard selectedShapes.count >= 2 else { 
                print("❌ PUNCH requires at least 2 shapes")
                return 
            }
            
            let backShape = selectedShapes.first!    // First in array = bottommost = back
            let frontShapes = Array(selectedShapes.dropFirst()) // All others = front
            
            print("🔪 PUNCH: Back shape '\(backShape.name)' - Front shapes: \(frontShapes.map { $0.name })")
            
            var resultPath = backShape.path.cgPath
            
            // Subtract each front shape from the result
            for frontShape in frontShapes {
                if let subtractedPath = ProfessionalPathOperations.minusFront(frontShape.path.cgPath, from: resultPath) {
                    resultPath = subtractedPath
                    print("  ⚡ Subtracted '\(frontShape.name)' from result")
                }
            }
            
            // Result takes style of BACK object (Adobe Illustrator standard)
            let resultShape = VectorShape(
                name: "Punch Result",
                path: VectorPath(cgPath: resultPath),
                strokeStyle: backShape.strokeStyle,
                fillStyle: backShape.fillStyle,
                transform: .identity,
                opacity: backShape.opacity
            )
            resultShapes = [resultShape]
            print("✅ PUNCH: Result takes back object's color (\(backShape.name))")
            
        case .intersect:
            // INTERSECT: Keep only overlapping areas, result takes color of TOPMOST object
            guard selectedShapes.count == 2 else {
                print("❌ INTERSECT requires exactly 2 shapes")
                return
            }
            
            if let intersectedPath = ProfessionalPathOperations.intersect(paths[0], paths[1]) {
                let topmostShape = selectedShapes.last! // Last = topmost
                let intersectedShape = VectorShape(
                    name: "Intersected Shape",
                    path: VectorPath(cgPath: intersectedPath),
                    strokeStyle: topmostShape.strokeStyle,
                    fillStyle: topmostShape.fillStyle,
                    transform: .identity,
                    opacity: topmostShape.opacity
                )
                resultShapes = [intersectedShape]
                print("✅ INTERSECT: Result takes topmost object's color (\(topmostShape.name))")
            }
            
        case .exclude:
            // EXCLUDE: Remove overlapping areas, result takes color of TOPMOST object
            guard selectedShapes.count == 2 else {
                print("❌ EXCLUDE requires exactly 2 shapes")
                return
            }
            
            let excludedPaths = ProfessionalPathOperations.exclude(paths[0], paths[1])
            let topmostShape = selectedShapes.last! // Last = topmost
            
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
            print("✅ EXCLUDE: Created \(resultShapes.count) pieces with topmost object's color (\(topmostShape.name))")
        
        // PATHFINDER EFFECTS (Adobe Illustrator) - These retain original colors
        case .split:
            // MOSAIC: CoreGraphics-based alternative to Divide with PERFECT stained glass effect
            let splitResults = CoreGraphicsPathOperations.splitWithShapeTracking(paths, using: .winding)
            
            for (index, (splitPath, originalShapeIndex)) in splitResults.enumerated() {
                // Use the exact original shape determined by stained glass tracking
                let originalShape = selectedShapes[originalShapeIndex]
                
                                let splitShape = VectorShape(
                name: "Mosaic Piece \(index + 1)",
                    path: VectorPath(cgPath: splitPath),
                    strokeStyle: originalShape.strokeStyle,
                    fillStyle: originalShape.fillStyle,
                    transform: .identity,
                    opacity: originalShape.opacity
                )
                resultShapes.append(splitShape)
            }
            print("✅ MOSAIC: Created \(resultShapes.count) pieces - TRUE stained glass effect (ALL visible areas preserved)")
            
        case .cut:
            // CUT: CoreGraphics-based alternative to Trim with curve preservation
            let cutResults = CoreGraphicsPathOperations.cutWithShapeTracking(paths, using: .winding)
            
            // Adobe Illustrator Cut: Each resulting piece maintains the color of its original shape (with curves preserved)
            var shapeCounters: [Int: Int] = [:]
            
            for (cutPath, originalShapeIndex) in cutResults {
                guard originalShapeIndex < selectedShapes.count else { continue }
                
                let originalShape = selectedShapes[originalShapeIndex]
                
                // Track how many pieces we've created from this original shape
                shapeCounters[originalShapeIndex] = (shapeCounters[originalShapeIndex] ?? 0) + 1
                let pieceNumber = shapeCounters[originalShapeIndex]!
                
                let cutShape = VectorShape(
                    name: pieceNumber > 1 ? "Cut \(originalShape.name) (\(pieceNumber))" : "Cut \(originalShape.name)",
                    path: VectorPath(cgPath: cutPath),
                    strokeStyle: nil, // CUT removes strokes (Adobe Illustrator standard)
                    fillStyle: originalShape.fillStyle,
                    transform: .identity,
                    opacity: originalShape.opacity
                )
                resultShapes.append(cutShape)
            }
            print("✅ CUT: Created \(resultShapes.count) cut shapes with curves preserved, removed strokes")
            
        case .merge:
            // MERGE: Adobe Illustrator Merge - cut all shapes first (maintain appearance), then merge same colors
            let colors = selectedShapes.compactMap { $0.fillStyle?.color ?? .clear }
            
            guard colors.count == selectedShapes.count else {
                print("❌ MERGE: Could not extract colors from all shapes")
                return
            }
            
            let mergeResults = ProfessionalPathOperations.professionalMergeWithShapeTracking(paths, colors: colors)
            
            // Adobe Illustrator Merge: Cut-first approach maintains appearance, then same colors get unified, removes strokes
            var shapeCounters: [Int: Int] = [:]
            
            for (mergedPath, originalShapeIndex) in mergeResults {
                guard originalShapeIndex < selectedShapes.count else { continue }
                
                let originalShape = selectedShapes[originalShapeIndex]
                
                // Track how many pieces we've created from this original shape
                shapeCounters[originalShapeIndex] = (shapeCounters[originalShapeIndex] ?? 0) + 1
                let pieceNumber = shapeCounters[originalShapeIndex]!
                
                let mergedShape = VectorShape(
                    name: pieceNumber > 1 ? "Merged \(originalShape.name) (\(pieceNumber))" : "Merged \(originalShape.name)",
                    path: VectorPath(cgPath: mergedPath),
                    strokeStyle: nil, // MERGE removes strokes (Adobe Illustrator standard)
                    fillStyle: originalShape.fillStyle,
                    transform: .identity,
                    opacity: originalShape.opacity
                )
                resultShapes.append(mergedShape)
            }
            print("✅ MERGE: Created \(resultShapes.count) color-unified shapes with maintained appearance, removed strokes")
            
        case .crop:
            // CROP: Use topmost shape to crop others, then trim. Top shape becomes invisible.
            let cropResults = ProfessionalPathOperations.professionalCropWithShapeTracking(paths)
            
            // Adobe Illustrator Crop: Each resulting piece maintains the color of its original shape
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
                    print("   ✅ Created invisible crop boundary from \(originalShape.name)")
                } else {
                    // Track how many pieces we've created from this original shape
                    shapeCounters[originalShapeIndex] = (shapeCounters[originalShapeIndex] ?? 0) + 1
                    let pieceNumber = shapeCounters[originalShapeIndex]!
                    
                    let croppedShape = VectorShape(
                        name: pieceNumber > 1 ? "Cropped \(originalShape.name) (\(pieceNumber))" : "Cropped \(originalShape.name)",
                        path: VectorPath(cgPath: croppedPath),
                        strokeStyle: nil, // CROP removes strokes (Adobe Illustrator standard)
                        fillStyle: originalShape.fillStyle,
                        transform: .identity,
                        opacity: originalShape.opacity
                    )
                    resultShapes.append(croppedShape)
                }
            }
            
            print("✅ CROP: Created \(resultShapes.count) shapes (includes invisible crop boundary), removed strokes")
            
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
                        lineCap: CGLineCap.round,
                        lineJoin: CGLineJoin.round
                    ),
                    fillStyle: nil, // DIELINE has no fill - only 1px black stroke
                    transform: .identity,
                    opacity: 1.0
                )
                resultShapes.append(dielineShape)
            }
            print("✅ DIELINE: Created \(resultShapes.count) dieline shapes")
            
        case .separate:
            // SEPARATE: Break compound paths into individual components
            var separatedShapes: [VectorShape] = []
            
            for (shapeIndex, shape) in selectedShapes.enumerated() {
                let components = CoreGraphicsPathOperations.componentsSeparated(shape.path.cgPath, using: .winding)
                
                if components.count <= 1 {
                    // No separation needed, keep original
                    separatedShapes.append(shape)
                    print("   Shape \(shapeIndex + 1): No components to separate")
                } else {
                    // Create separate shapes for each component
                    for (componentIndex, component) in components.enumerated() {
                        let separatedShape = VectorShape(
                            name: components.count > 1 ? "\(shape.name) Component \(componentIndex + 1)" : shape.name,
                            path: VectorPath(cgPath: component),
                            strokeStyle: shape.strokeStyle,
                            fillStyle: shape.fillStyle,
                            transform: .identity,
                            opacity: shape.opacity
                        )
                        separatedShapes.append(separatedShape)
                    }
                    print("   Shape \(shapeIndex + 1): Separated into \(components.count) components")
                }
            }
            
            resultShapes = separatedShapes
            print("✅ SEPARATE: Created \(resultShapes.count) individual shapes from \(selectedShapes.count) compound paths")
            
        case .minusBack:
            // KICK: Back objects subtract from front object, result takes color of FRONT object
            guard selectedShapes.count >= 2 else {
                print("❌ KICK requires at least 2 shapes")
                return
            }
            
            let frontShape = selectedShapes.last!     // Last in array = topmost = front
            let backShapes = Array(selectedShapes.dropLast()) // All others = back
            
            print("🔪 KICK: Front shape '\(frontShape.name)' - Back shapes: \(backShapes.map { $0.name })")
            
            var resultPath = frontShape.path.cgPath
            
            // Subtract each back shape from the result
            for backShape in backShapes {
                if let subtractedPath = ProfessionalPathOperations.minusBack(resultPath, from: backShape.path.cgPath) {
                    resultPath = subtractedPath
                    print("  ⚡ Subtracted '\(backShape.name)' from result")
                }
            }
            
            // Result takes style of FRONT object (Adobe Illustrator standard)
            let resultShape = VectorShape(
                name: "Kick Result",
                path: VectorPath(cgPath: resultPath),
                strokeStyle: frontShape.strokeStyle,
                fillStyle: frontShape.fillStyle,
                transform: .identity,
                opacity: frontShape.opacity
            )
            resultShapes = [resultShape]
            print("✅ KICK: Result takes front object's color (\(frontShape.name))")
        }
        
        guard !resultShapes.isEmpty else {
            print("❌ Pathfinder operation \(operation.rawValue) produced no results")
            return
        }
        
        // Remove original selected shapes
        document.removeSelectedShapes()
        
        // Add new result shapes and select them
        for resultShape in resultShapes {
            document.addShape(resultShape)
            document.selectShape(resultShape.id)
        }
        
        print("✅ PROFESSIONAL ADOBE ILLUSTRATOR pathfinder operation \(operation.rawValue) completed - created \(resultShapes.count) result shape(s)")
    }
    

} 