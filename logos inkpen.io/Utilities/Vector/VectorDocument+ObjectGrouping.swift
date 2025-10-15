import SwiftUI

extension VectorDocument {
    func groupSelectedObjects() {
        let allSelectedIDs = selectedShapeIDs.union(selectedTextIDs)

        guard let layerIndex = selectedLayerIndex,
              allSelectedIDs.count > 1 else {
            return
        }

        // Capture old state for undo
        var removedShapes: [UUID: VectorShape] = [:]
        var removedOrderIDs: [UUID: Int] = [:]
        let objectsToRemove = unifiedObjects.filter { allSelectedIDs.contains($0.id) }
        for obj in objectsToRemove {
            if case .shape(let shape) = obj.objectType {
                removedShapes[obj.id] = shape
                removedOrderIDs[obj.id] = obj.orderID
            }
        }

        let selectedShapes = getShapesForLayer(layerIndex).filter { allSelectedIDs.contains($0.id) }
        let groupShape = VectorShape.group(from: selectedShapes, name: "Group")

        // Calculate new orderID for group (use highest orderID from removed objects)
        let maxOrderID = objectsToRemove.map { $0.orderID }.max() ?? 0

        // Apply changes
        removeShapesUnified(layerIndex: layerIndex, where: { allSelectedIDs.contains($0.id) })
        appendShapeToLayerUnified(layerIndex: layerIndex, shape: groupShape)

        let newSelectedIDs: Set<UUID> = [groupShape.id]

        // Create command
        let command = GroupCommand(
            operation: .group,
            layerIndex: layerIndex,
            removedObjectIDs: Array(allSelectedIDs),
            removedShapes: removedShapes,
            removedOrderIDs: removedOrderIDs,
            addedObjectIDs: [groupShape.id],
            addedShapes: [groupShape.id: groupShape],
            addedOrderIDs: [groupShape.id: maxOrderID],
            oldSelectedObjectIDs: selectedObjectIDs,
            newSelectedObjectIDs: newSelectedIDs
        )

        selectedShapeIDs = [groupShape.id]
        selectedTextIDs.removeAll()
        populateUnifiedObjectsFromLayersPreservingOrder()
        selectedObjectIDs = [groupShape.id]

        executeCommand(command)
    }
    
    func flattenSelectedObjects() {
        guard let layerIndex = selectedLayerIndex,
              selectedShapeIDs.count > 1 else { return }

        // Capture old state
        var removedShapes: [UUID: VectorShape] = [:]
        var removedOrderIDs: [UUID: Int] = [:]
        let objectsToRemove = unifiedObjects.filter { selectedObjectIDs.contains($0.id) }
        for obj in objectsToRemove {
            if case .shape(let shape) = obj.objectType {
                removedShapes[obj.id] = shape
                removedOrderIDs[obj.id] = obj.orderID
            }
        }

        let selectedShapes = getSelectedShapesInStackingOrder()

        var combinedBounds = CGRect.zero
        for shape in selectedShapes {
            let shapeBounds = shape.bounds
            if combinedBounds == .zero {
                combinedBounds = shapeBounds
            } else {
                combinedBounds = combinedBounds.union(shapeBounds)
            }
        }

        let flattenedShape = VectorShape(
            name: "Flattened Group",
            path: VectorPath(cgPath: CGPath(rect: combinedBounds, transform: nil)),
            strokeStyle: nil,
            fillStyle: nil,
            transform: .identity,
            isGroup: true,
            groupedShapes: selectedShapes,
            isCompoundPath: false
        )

        let maxOrderID = objectsToRemove.map { $0.orderID }.max() ?? 0

        removeSelectedShapes()
        appendShapeToLayerUnified(layerIndex: layerIndex, shape: flattenedShape)

        let newSelectedIDs: Set<UUID> = [flattenedShape.id]

        // Create command
        let command = GroupCommand(
            operation: .flatten,
            layerIndex: layerIndex,
            removedObjectIDs: Array(selectedObjectIDs),
            removedShapes: removedShapes,
            removedOrderIDs: removedOrderIDs,
            addedObjectIDs: [flattenedShape.id],
            addedShapes: [flattenedShape.id: flattenedShape],
            addedOrderIDs: [flattenedShape.id: maxOrderID],
            oldSelectedObjectIDs: selectedObjectIDs,
            newSelectedObjectIDs: newSelectedIDs
        )

        selectedShapeIDs = [flattenedShape.id]
        populateUnifiedObjectsFromLayersPreservingOrder()
        selectedObjectIDs = [flattenedShape.id]

        executeCommand(command)
    }
    
    func ungroupSelectedObjects() {
        guard let layerIndex = selectedLayerIndex,
              !selectedShapeIDs.isEmpty else { return }

        var newSelectedShapeIDs: Set<UUID> = []
        var shapesToRemove: [UUID] = []
        var shapesToAdd: [VectorShape] = []

        // Capture old state
        var removedShapes: [UUID: VectorShape] = [:]
        var removedOrderIDs: [UUID: Int] = [:]

        for shapeID in selectedShapeIDs {
            let shapes = getShapesForLayer(layerIndex)
            if let shapeIndex = shapes.firstIndex(where: { $0.id == shapeID }),
               let shape = getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {

                if shape.isGroupContainer {
                    // Capture group before removal
                    if let obj = unifiedObjects.first(where: { $0.id == shapeID }) {
                        removedShapes[shapeID] = shape
                        removedOrderIDs[shapeID] = obj.orderID
                    }

                    for groupedShape in shape.groupedShapes {
                        shapesToAdd.append(groupedShape)
                        newSelectedShapeIDs.insert(groupedShape.id)
                    }

                    shapesToRemove.append(shapeID)

                } else {
                    newSelectedShapeIDs.insert(shapeID)
                }
            }
        }

        // Apply changes
        removeShapesUnified(layerIndex: layerIndex, where: { shapesToRemove.contains($0.id) })

        for shape in shapesToAdd {
            appendShapeToLayerUnified(layerIndex: layerIndex, shape: shape)
        }

        // Capture new state
        var addedShapes: [UUID: VectorShape] = [:]
        var addedOrderIDs: [UUID: Int] = [:]
        for shape in shapesToAdd {
            if let obj = unifiedObjects.first(where: { $0.id == shape.id }) {
                addedShapes[shape.id] = shape
                addedOrderIDs[shape.id] = obj.orderID
            }
        }

        // Create command
        let command = GroupCommand(
            operation: .ungroup,
            layerIndex: layerIndex,
            removedObjectIDs: shapesToRemove,
            removedShapes: removedShapes,
            removedOrderIDs: removedOrderIDs,
            addedObjectIDs: Array(newSelectedShapeIDs),
            addedShapes: addedShapes,
            addedOrderIDs: addedOrderIDs,
            oldSelectedObjectIDs: selectedObjectIDs,
            newSelectedObjectIDs: newSelectedShapeIDs
        )

        selectedShapeIDs = newSelectedShapeIDs
        populateUnifiedObjectsFromLayersPreservingOrder()
        selectedObjectIDs = newSelectedShapeIDs

        executeCommand(command)
    }
    
    func unflattenSelectedObjects() {
        guard let layerIndex = selectedLayerIndex,
              selectedShapeIDs.count == 1,
              let selectedShapeID = selectedShapeIDs.first else { return }

        let shapes = getShapesForLayer(layerIndex)
        guard let shapeIndex = shapes.firstIndex(where: { $0.id == selectedShapeID }) else { return }

        guard let flattenedGroup = getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { return }

        guard flattenedGroup.isGroup && !flattenedGroup.groupedShapes.isEmpty else { return }

        // Capture old state
        var removedShapes: [UUID: VectorShape] = [:]
        var removedOrderIDs: [UUID: Int] = [:]
        if let obj = unifiedObjects.first(where: { $0.id == selectedShapeID }) {
            removedShapes[selectedShapeID] = flattenedGroup
            removedOrderIDs[selectedShapeID] = obj.orderID
        }

        let restoredShapes = flattenedGroup.groupedShapes
        var newSelectedIDs: Set<UUID> = []

        var shapesToAdd: [VectorShape] = []
        for originalShape in restoredShapes {
            var restoredShape = originalShape
            restoredShape.id = UUID()
            shapesToAdd.append(restoredShape)
            newSelectedIDs.insert(restoredShape.id)
        }

        removeShapeAtIndexUnified(layerIndex: layerIndex, shapeIndex: shapeIndex)

        for shape in shapesToAdd {
            appendShapeToLayerUnified(layerIndex: layerIndex, shape: shape)
        }

        // Capture new state
        var addedShapes: [UUID: VectorShape] = [:]
        var addedOrderIDs: [UUID: Int] = [:]
        for shape in shapesToAdd {
            if let obj = unifiedObjects.first(where: { $0.id == shape.id }) {
                addedShapes[shape.id] = shape
                addedOrderIDs[shape.id] = obj.orderID
            }
        }

        // Create command
        let command = GroupCommand(
            operation: .unflatten,
            layerIndex: layerIndex,
            removedObjectIDs: [selectedShapeID],
            removedShapes: removedShapes,
            removedOrderIDs: removedOrderIDs,
            addedObjectIDs: Array(newSelectedIDs),
            addedShapes: addedShapes,
            addedOrderIDs: addedOrderIDs,
            oldSelectedObjectIDs: selectedObjectIDs,
            newSelectedObjectIDs: newSelectedIDs
        )

        selectedShapeIDs = newSelectedIDs
        populateUnifiedObjectsFromLayersPreservingOrder()
        selectedObjectIDs = newSelectedIDs

        executeCommand(command)
    }
    
    func makeCompoundPath() {
        guard let layerIndex = selectedLayerIndex,
              selectedShapeIDs.count > 1 else { return }

        // Capture old state
        var removedShapes: [UUID: VectorShape] = [:]
        var removedOrderIDs: [UUID: Int] = [:]
        let objectsToRemove = unifiedObjects.filter { selectedObjectIDs.contains($0.id) }
        for obj in objectsToRemove {
            if case .shape(let shape) = obj.objectType {
                removedShapes[obj.id] = shape
                removedOrderIDs[obj.id] = obj.orderID
            }
        }

        let selectedShapes = getSelectedShapesInStackingOrder()
        let compoundPath = CGMutablePath()
        for shape in selectedShapes {
            compoundPath.addPath(shape.path.cgPath)
        }

        let compoundShape = VectorShape(
            name: "Compound Path",
            path: VectorPath(cgPath: compoundPath, fillRule: .evenOdd),
            strokeStyle: selectedShapes.last?.strokeStyle,
            fillStyle: selectedShapes.last?.fillStyle,
            transform: .identity,
            isCompoundPath: true
        )

        let maxOrderID = objectsToRemove.map { $0.orderID }.max() ?? 0

        removeSelectedShapes()
        appendShapeToLayerUnified(layerIndex: layerIndex, shape: compoundShape)

        let newSelectedIDs: Set<UUID> = [compoundShape.id]

        // Create command
        let command = GroupCommand(
            operation: .makeCompound,
            layerIndex: layerIndex,
            removedObjectIDs: Array(selectedObjectIDs),
            removedShapes: removedShapes,
            removedOrderIDs: removedOrderIDs,
            addedObjectIDs: [compoundShape.id],
            addedShapes: [compoundShape.id: compoundShape],
            addedOrderIDs: [compoundShape.id: maxOrderID],
            oldSelectedObjectIDs: selectedObjectIDs,
            newSelectedObjectIDs: newSelectedIDs
        )

        selectedShapeIDs = [compoundShape.id]
        populateUnifiedObjectsFromLayersPreservingOrder()
        selectedObjectIDs = [compoundShape.id]

        executeCommand(command)
    }
    
    func makeLoopingPath() {
        guard let layerIndex = selectedLayerIndex,
              selectedShapeIDs.count > 1 else { return }

        // Capture old state
        var removedShapes: [UUID: VectorShape] = [:]
        var removedOrderIDs: [UUID: Int] = [:]
        let objectsToRemove = unifiedObjects.filter { selectedObjectIDs.contains($0.id) }
        for obj in objectsToRemove {
            if case .shape(let shape) = obj.objectType {
                removedShapes[obj.id] = shape
                removedOrderIDs[obj.id] = obj.orderID
            }
        }

        let selectedShapes = getSelectedShapesInStackingOrder()

        let loopingPath = CGMutablePath()
        for shape in selectedShapes {
            loopingPath.addPath(shape.path.cgPath)
        }

        let loopingShape = VectorShape(
            name: "Looping Path",
            path: VectorPath(cgPath: loopingPath, fillRule: .winding),
            strokeStyle: selectedShapes.last?.strokeStyle,
            fillStyle: selectedShapes.last?.fillStyle,
            transform: .identity,
            isCompoundPath: true
        )

        let maxOrderID = objectsToRemove.map { $0.orderID }.max() ?? 0

        removeSelectedShapes()
        appendShapeToLayerUnified(layerIndex: layerIndex, shape: loopingShape)

        let newSelectedIDs: Set<UUID> = [loopingShape.id]

        // Create command
        let command = GroupCommand(
            operation: .makeLooping,
            layerIndex: layerIndex,
            removedObjectIDs: Array(selectedObjectIDs),
            removedShapes: removedShapes,
            removedOrderIDs: removedOrderIDs,
            addedObjectIDs: [loopingShape.id],
            addedShapes: [loopingShape.id: loopingShape],
            addedOrderIDs: [loopingShape.id: maxOrderID],
            oldSelectedObjectIDs: selectedObjectIDs,
            newSelectedObjectIDs: newSelectedIDs
        )

        selectedShapeIDs = [loopingShape.id]
        populateUnifiedObjectsFromLayersPreservingOrder()
        selectedObjectIDs = [loopingShape.id]

        executeCommand(command)
    }
    
    func releaseCompoundPath() {
        guard let layerIndex = selectedLayerIndex,
              selectedShapeIDs.count == 1,
              let selectedShapeID = selectedShapeIDs.first else { return }

        let shapes = getShapesForLayer(layerIndex)
        guard let shapeIndex = shapes.firstIndex(where: { $0.id == selectedShapeID }),
              let compoundShape = getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex),
              compoundShape.isTrueCompoundPath else { return }

        // Capture old state
        var removedShapes: [UUID: VectorShape] = [:]
        var removedOrderIDs: [UUID: Int] = [:]
        if let obj = unifiedObjects.first(where: { $0.id == selectedShapeID }) {
            removedShapes[selectedShapeID] = compoundShape
            removedOrderIDs[selectedShapeID] = obj.orderID
        }

        let subpaths = extractSubpaths(from: compoundShape.path.cgPath)
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

        removeShapeAtIndexUnified(layerIndex: layerIndex, shapeIndex: shapeIndex)

        for shape in newShapes {
            appendShapeToLayerUnified(layerIndex: layerIndex, shape: shape)
        }

        // Capture new state
        var addedShapes: [UUID: VectorShape] = [:]
        var addedOrderIDs: [UUID: Int] = [:]
        for shape in newShapes {
            if let obj = unifiedObjects.first(where: { $0.id == shape.id }) {
                addedShapes[shape.id] = shape
                addedOrderIDs[shape.id] = obj.orderID
            }
        }

        // Create command
        let command = GroupCommand(
            operation: .releaseCompound,
            layerIndex: layerIndex,
            removedObjectIDs: [selectedShapeID],
            removedShapes: removedShapes,
            removedOrderIDs: removedOrderIDs,
            addedObjectIDs: Array(newSelectedIDs),
            addedShapes: addedShapes,
            addedOrderIDs: addedOrderIDs,
            oldSelectedObjectIDs: selectedObjectIDs,
            newSelectedObjectIDs: newSelectedIDs
        )

        selectedShapeIDs = newSelectedIDs
        populateUnifiedObjectsFromLayersPreservingOrder()
        selectedObjectIDs = newSelectedIDs

        executeCommand(command)
    }
    
    func releaseLoopingPath() {
        guard let layerIndex = selectedLayerIndex,
              selectedShapeIDs.count == 1,
              let selectedShapeID = selectedShapeIDs.first else { return }

        let shapes = getShapesForLayer(layerIndex)
        guard let shapeIndex = shapes.firstIndex(where: { $0.id == selectedShapeID }),
              let loopingShape = getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex),
              loopingShape.isTrueLoopingPath else { return }

        // Capture old state
        var removedShapes: [UUID: VectorShape] = [:]
        var removedOrderIDs: [UUID: Int] = [:]
        if let obj = unifiedObjects.first(where: { $0.id == selectedShapeID }) {
            removedShapes[selectedShapeID] = loopingShape
            removedOrderIDs[selectedShapeID] = obj.orderID
        }

        let subpaths = extractSubpaths(from: loopingShape.path.cgPath)

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

        removeShapeAtIndexUnified(layerIndex: layerIndex, shapeIndex: shapeIndex)

        for shape in newShapes {
            appendShapeToLayerUnified(layerIndex: layerIndex, shape: shape)
        }

        // Capture new state
        var addedShapes: [UUID: VectorShape] = [:]
        var addedOrderIDs: [UUID: Int] = [:]
        for shape in newShapes {
            if let obj = unifiedObjects.first(where: { $0.id == shape.id }) {
                addedShapes[shape.id] = shape
                addedOrderIDs[shape.id] = obj.orderID
            }
        }

        // Create command
        let command = GroupCommand(
            operation: .releaseLooping,
            layerIndex: layerIndex,
            removedObjectIDs: [selectedShapeID],
            removedShapes: removedShapes,
            removedOrderIDs: removedOrderIDs,
            addedObjectIDs: Array(newSelectedIDs),
            addedShapes: addedShapes,
            addedOrderIDs: addedOrderIDs,
            oldSelectedObjectIDs: selectedObjectIDs,
            newSelectedObjectIDs: newSelectedIDs
        )

        selectedShapeIDs = newSelectedIDs
        populateUnifiedObjectsFromLayersPreservingOrder()
        selectedObjectIDs = newSelectedIDs

        executeCommand(command)
    }
    
    private func extractSubpaths(from cgPath: CGPath) -> [CGPath] {
        var subpaths: [CGPath] = []
        var currentPath = CGMutablePath()
        
        cgPath.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            
            switch element.type {
            case .moveToPoint:
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
        
        if !currentPath.isEmpty {
            subpaths.append(currentPath)
        }
        
        return subpaths
    }
}
