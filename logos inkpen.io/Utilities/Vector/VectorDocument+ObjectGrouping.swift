//
//  VectorDocument+ObjectGrouping.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI

// MARK: - Object Grouping
extension VectorDocument {
    
    // MARK: - Object Grouping Methods
    
    /// Group selected objects
    func groupSelectedObjects() {
        guard let layerIndex = selectedLayerIndex,
              selectedShapeIDs.count > 1 else { return }
        
        saveToUndoStack()
        
        // Get selected shapes from unified objects
        let selectedShapes = getShapesForLayer(layerIndex).filter { selectedShapeIDs.contains($0.id) }
        
        // Create group from selected shapes
        let groupShape = VectorShape.group(from: selectedShapes, name: "Group")
        
        // Remove individual shapes
        removeShapesUnified(layerIndex: layerIndex, where: { selectedShapeIDs.contains($0.id) })
        
        // Add group
        appendShapeToLayerUnified(layerIndex: layerIndex, shape: groupShape)
        selectedShapeIDs = [groupShape.id]
        
        // CRITICAL FIX: Update unified objects system after grouping
        populateUnifiedObjectsFromLayersPreservingOrder()
        
        // CRITICAL FIX: Update unified selection to use the new group
        selectedObjectIDs = [groupShape.id]
        
    }
    
    /// Flatten selected objects (preserves individual colors, enables transform tools)
    func flattenSelectedObjects() {
        guard let layerIndex = selectedLayerIndex,
              selectedShapeIDs.count > 1 else { return }
        
        saveToUndoStack()
        
        // Get selected shapes in stacking order
        let selectedShapes = getSelectedShapesInStackingOrder()
        
        // Calculate overall bounding box for the flattened group
        var combinedBounds = CGRect.zero
        for shape in selectedShapes {
            let shapeBounds = shape.bounds
            if combinedBounds == .zero {
                combinedBounds = shapeBounds
            } else {
                combinedBounds = combinedBounds.union(shapeBounds)
            }
        }
        
        // Create flattened group - preserves all individual shapes and their colors
        // Uses isGroup=true so it transforms as a unit with Scale/Rotate/Shear tools
        // But stores individual shapes in groupedShapes to preserve colors during rendering
        let flattenedShape = VectorShape(
            name: "Flattened Group",
            path: VectorPath(cgPath: CGPath(rect: combinedBounds, transform: nil)), // Invisible container path
            strokeStyle: nil, // No stroke on container - individual shapes have their own
            fillStyle: nil,   // No fill on container - individual shapes have their own
            transform: .identity,
            isGroup: true,    // This makes it work with transform tools as a single unit
            groupedShapes: selectedShapes, // PRESERVE all individual shapes and their colors
            isCompoundPath: false
        )
        
        // Remove original shapes
        removeSelectedShapes()
        
        // Add flattened group
        appendShapeToLayerUnified(layerIndex: layerIndex, shape: flattenedShape)
        selectedShapeIDs = [flattenedShape.id]
        
        // CRITICAL FIX: Update unified objects system after flattening
        populateUnifiedObjectsFromLayersPreservingOrder()
        
        // CRITICAL FIX: Update unified selection to use the new flattened group
        selectedObjectIDs = [flattenedShape.id]
        
        Log.fileOperation("🎨 Flattened \(selectedShapes.count) objects - preserving all colors, enabling transform tools", level: .info)
    }
    
    /// Ungroup selected objects
    func ungroupSelectedObjects() {
        guard let layerIndex = selectedLayerIndex,
              !selectedShapeIDs.isEmpty else { return }
        
        saveToUndoStack()
        
        var newSelectedShapeIDs: Set<UUID> = []
        var shapesToRemove: [UUID] = []
        var shapesToAdd: [VectorShape] = []
        
        // Process each selected shape
        for shapeID in selectedShapeIDs {
            let shapes = getShapesForLayer(layerIndex)
            if let shapeIndex = shapes.firstIndex(where: { $0.id == shapeID }),
               let shape = getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {
                
                // Check if this shape is a group
                if shape.isGroupContainer {
                    // Extract grouped shapes
                    for groupedShape in shape.groupedShapes {
                        shapesToAdd.append(groupedShape)
                        newSelectedShapeIDs.insert(groupedShape.id)
                    }
                    
                    // Mark group for removal
                    shapesToRemove.append(shapeID)
                    
                } else {
                    // Not a group, keep it selected
                    newSelectedShapeIDs.insert(shapeID)
                }
            }
        }
        
        // Remove groups
        removeShapesUnified(layerIndex: layerIndex, where: { shapesToRemove.contains($0.id) })
        
        // Add ungrouped shapes
        for shape in shapesToAdd {
            appendShapeToLayerUnified(layerIndex: layerIndex, shape: shape)
        }
        
        // Update selection
        selectedShapeIDs = newSelectedShapeIDs
        
        // CRITICAL FIX: Update unified objects system after ungrouping
        populateUnifiedObjectsFromLayersPreservingOrder()
        
        // CRITICAL FIX: Update unified selection to use the ungrouped shapes
        selectedObjectIDs = newSelectedShapeIDs
        
        if !shapesToRemove.isEmpty {
        } else {
        }
    }
    
    /// Unflatten selected objects (restore flattened groups to individual shapes)
    func unflattenSelectedObjects() {
        guard let layerIndex = selectedLayerIndex,
              selectedShapeIDs.count == 1,
              let selectedShapeID = selectedShapeIDs.first else { return }
        
        let shapes = getShapesForLayer(layerIndex)
        guard let shapeIndex = shapes.firstIndex(where: { $0.id == selectedShapeID }) else { return }
        
        guard let flattenedGroup = getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { return }
        
        // Only unflatten actual groups (flattened shapes)
        guard flattenedGroup.isGroup && !flattenedGroup.groupedShapes.isEmpty else { return }
        
        saveToUndoStack()
        
        // Restore original individual shapes with all their colors preserved
        let restoredShapes = flattenedGroup.groupedShapes
        var newSelectedIDs: Set<UUID> = []
        
        // Generate new IDs for the restored shapes to avoid conflicts
        var shapesToAdd: [VectorShape] = []
        for originalShape in restoredShapes {
            var restoredShape = originalShape
            restoredShape.id = UUID() // New ID to avoid conflicts
            shapesToAdd.append(restoredShape)
            newSelectedIDs.insert(restoredShape.id)
        }
        
        // Remove flattened group
        removeShapeAtIndexUnified(layerIndex: layerIndex, shapeIndex: shapeIndex)
        
        // Add restored individual shapes
        for shape in shapesToAdd {
            appendShapeToLayerUnified(layerIndex: layerIndex, shape: shape)
        }
        selectedShapeIDs = newSelectedIDs
        
        // CRITICAL FIX: Update unified objects system after unflattening
        populateUnifiedObjectsFromLayersPreservingOrder()
        
        // CRITICAL FIX: Update unified selection to use the unflattened shapes
        selectedObjectIDs = newSelectedIDs
        
        Log.fileOperation("🎨 Unflattened group - restored \(shapesToAdd.count) individual shapes with original colors", level: .info)
    }
    
    // MARK: - Compound Path Methods
    
    /// Make compound path from selected objects  
    func makeCompoundPath() {
        guard let layerIndex = selectedLayerIndex,
              selectedShapeIDs.count > 1 else { return }
        
        saveToUndoStack()
        
        // Get selected shapes in stacking order
        let selectedShapes = getSelectedShapesInStackingOrder()
        
        // Combine all paths into a single compound path using even-odd fill rule
        let compoundPath = CGMutablePath()
        for shape in selectedShapes {
            compoundPath.addPath(shape.path.cgPath)
        }
        
        // Create compound path shape with even-odd fill rule to create holes
        let compoundShape = VectorShape(
            name: "Compound Path",
            path: VectorPath(cgPath: compoundPath, fillRule: .evenOdd), // CRITICAL: Even-odd fill rule for holes
            strokeStyle: selectedShapes.last?.strokeStyle, // Use topmost shape's stroke
            fillStyle: selectedShapes.last?.fillStyle,     // Use topmost shape's fill
            transform: .identity,
            isCompoundPath: true
        )
        
        // Remove original shapes
        removeSelectedShapes()
        
        // Add compound path
        appendShapeToLayerUnified(layerIndex: layerIndex, shape: compoundShape)
        selectedShapeIDs = [compoundShape.id]
        
        // CRITICAL FIX: Update unified objects system after creating compound path
        populateUnifiedObjectsFromLayersPreservingOrder()
        
        // CRITICAL FIX: Update unified selection to use the new compound path
        selectedObjectIDs = [compoundShape.id]
        
    }
    
    /// Make looping path from selected objects (uses winding fill rule instead of even-odd)
    func makeLoopingPath() {
        guard let layerIndex = selectedLayerIndex,
              selectedShapeIDs.count > 1 else { return }
        
        saveToUndoStack()
        
        // Get selected shapes in stacking order
        let selectedShapes = getSelectedShapesInStackingOrder()
        
        // Combine all paths into a single compound path using winding fill rule
        let loopingPath = CGMutablePath()
        for shape in selectedShapes {
            loopingPath.addPath(shape.path.cgPath)
        }
        
        // Create looping path shape with winding fill rule for overlapping fills
        let loopingShape = VectorShape(
            name: "Looping Path",
            path: VectorPath(cgPath: loopingPath, fillRule: .winding), // CRITICAL: Winding fill rule for overlapping fills
            strokeStyle: selectedShapes.last?.strokeStyle, // Use topmost shape's stroke
            fillStyle: selectedShapes.last?.fillStyle,     // Use topmost shape's fill
            transform: .identity,
            isCompoundPath: true // Use same flag as compound path for compatibility
        )
        
        // Remove original shapes
        removeSelectedShapes()
        
        // Add looping path
        appendShapeToLayerUnified(layerIndex: layerIndex, shape: loopingShape)
        selectedShapeIDs = [loopingShape.id]
        
        // CRITICAL FIX: Update unified objects system after creating looping path
        populateUnifiedObjectsFromLayersPreservingOrder()
        
        // CRITICAL FIX: Update unified selection to use the new looping path
        selectedObjectIDs = [loopingShape.id]
        
        Log.fileOperation("🔄 Made looping path from \(selectedShapes.count) objects using winding fill rule", level: .info)
    }
    
    /// Release compound path back to individual paths
    func releaseCompoundPath() {
        guard let layerIndex = selectedLayerIndex,
              selectedShapeIDs.count == 1,
              let selectedShapeID = selectedShapeIDs.first else { return }

        let shapes = getShapesForLayer(layerIndex)
        guard let shapeIndex = shapes.firstIndex(where: { $0.id == selectedShapeID }),
              let compoundShape = getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex),
              compoundShape.isTrueCompoundPath else { return }  // Check for true compound path (even-odd)
        
        saveToUndoStack()
        
        // Extract individual subpaths from compound path
        let subpaths = extractSubpaths(from: compoundShape.path.cgPath)
        
        // Create individual shapes from each subpath
        var newShapes: [VectorShape] = []
        var newSelectedIDs: Set<UUID> = []
        
        for (index, subpath) in subpaths.enumerated() {
            let individualShape = VectorShape(
                name: "Path \(index + 1)",
                path: VectorPath(cgPath: subpath),
                strokeStyle: compoundShape.strokeStyle,
                fillStyle: compoundShape.fillStyle,
                transform: compoundShape.transform,
                isCompoundPath: false
            )
            newShapes.append(individualShape)
            newSelectedIDs.insert(individualShape.id)
        }
        
        // Remove compound path
        removeShapeAtIndexUnified(layerIndex: layerIndex, shapeIndex: shapeIndex)
        
        // Add individual paths
        for shape in newShapes {
            appendShapeToLayerUnified(layerIndex: layerIndex, shape: shape)
        }
        selectedShapeIDs = newSelectedIDs
        
        // CRITICAL FIX: Update unified objects system after releasing compound path
        populateUnifiedObjectsFromLayersPreservingOrder()
        
        // CRITICAL FIX: Update unified selection to use the released paths
        selectedObjectIDs = newSelectedIDs
        
    }
    
    /// Release looping path back to individual paths
    func releaseLoopingPath() {
        guard let layerIndex = selectedLayerIndex,
              selectedShapeIDs.count == 1,
              let selectedShapeID = selectedShapeIDs.first else { return }

        let shapes = getShapesForLayer(layerIndex)
        guard let shapeIndex = shapes.firstIndex(where: { $0.id == selectedShapeID }),
              let loopingShape = getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex),
              loopingShape.isTrueLoopingPath else { return }  // Check for true looping path (winding)
        
        saveToUndoStack()
        
        // Extract individual subpaths from looping path
        let subpaths = extractSubpaths(from: loopingShape.path.cgPath)
        
        // Create individual shapes from each subpath
        var newShapes: [VectorShape] = []
        var newSelectedIDs: Set<UUID> = []
        
        for (index, subpath) in subpaths.enumerated() {
            let individualShape = VectorShape(
                name: "Path \(index + 1)",
                path: VectorPath(cgPath: subpath),
                strokeStyle: loopingShape.strokeStyle,
                fillStyle: loopingShape.fillStyle,
                transform: loopingShape.transform,
                isCompoundPath: false
            )
            newShapes.append(individualShape)
            newSelectedIDs.insert(individualShape.id)
        }
        
        // Remove looping path
        removeShapeAtIndexUnified(layerIndex: layerIndex, shapeIndex: shapeIndex)
        
        // Add individual paths
        for shape in newShapes {
            appendShapeToLayerUnified(layerIndex: layerIndex, shape: shape)
        }
        selectedShapeIDs = newSelectedIDs
        
        // CRITICAL FIX: Update unified objects system after releasing looping path
        populateUnifiedObjectsFromLayersPreservingOrder()
        
        // CRITICAL FIX: Update unified selection to use the released paths
        selectedObjectIDs = newSelectedIDs
        
        Log.fileOperation("🔄 Released looping path into \(newShapes.count) individual paths", level: .info)
    }
    
    // Helper function to extract individual subpaths from a compound CGPath
    private func extractSubpaths(from cgPath: CGPath) -> [CGPath] {
        var subpaths: [CGPath] = []
        var currentPath = CGMutablePath()
        
        cgPath.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            
            switch element.type {
            case .moveToPoint:
                // If we have a current path, save it and start a new one
                if !currentPath.isEmpty {
                    subpaths.append(currentPath)
                    currentPath = CGMutablePath()
                }
                currentPath.move(to: element.points[0])
                
            case .addLineToPoint:
                currentPath.addLine(to: element.points[0])
                
            case .addQuadCurveToPoint:
                currentPath.addQuadCurve(to: element.points[1], control: element.points[0])
                
            case .addCurveToPoint:
                currentPath.addCurve(to: element.points[2], control1: element.points[0], control2: element.points[1])
                
            case .closeSubpath:
                currentPath.closeSubpath()
                
            @unknown default:
                break
            }
        }
        
        // Don't forget the last path if it exists
        if !currentPath.isEmpty {
            subpaths.append(currentPath)
        }
        
        return subpaths
    }
}
