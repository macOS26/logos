import SwiftUI

extension VectorDocument {
    func groupSelectedObjects() {
        guard let layerIndex = selectedLayerIndex,
              selectedObjectIDs.count > 1 else {
            return
        }

        print("🔴 GROUP: selectedObjectIDs = \(selectedObjectIDs)")
        print("🔴 GROUP: selectedShapeIDs = \(selectedShapeIDs)")
        print("🔴 GROUP: selectedTextIDs = \(selectedTextIDs)")

        var removedShapes: [UUID: VectorShape] = [:]
        let objectsToRemove = unifiedObjects.filter { selectedObjectIDs.contains($0.id) }

        print("🔴 GROUP: objectsToRemove count = \(objectsToRemove.count)")
        for (index, obj) in objectsToRemove.enumerated() {
            let typeName: String
            switch obj.objectType {
            case .text: typeName = "TEXT"
            case .shape: typeName = "SHAPE"
            case .warp: typeName = "WARP"
            case .group: typeName = "GROUP"
            case .clipGroup: typeName = "CLIPGROUP"
            case .clipMask: typeName = "CLIPMASK"
            }
            print("🔴 GROUP: objectsToRemove[\(index)] = \(typeName) id=\(obj.id)")
        }

        for obj in objectsToRemove {
            switch obj.objectType {
            case .text(let shape),
                 .shape(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                removedShapes[obj.id] = shape
            }
        }

        let selectedShapes = getSelectedShapesInStackingOrder()

        print("🔴 GROUP: selectedShapes count = \(selectedShapes.count)")
        for (index, shape) in selectedShapes.enumerated() {
            let typeName = shape.typography != nil ? "TEXT" : "SHAPE"
            print("🔴 GROUP: selectedShapes[\(index)] = \(typeName) name=\(shape.name) id=\(shape.id)")
        }

        let groupShape = VectorShape.group(from: selectedShapes, name: "Group")

        let newSelectedIDs: Set<UUID> = [groupShape.id]

        let command = GroupCommand(
            operation: .group,
            layerIndex: layerIndex,
            removedObjectIDs: Array(selectedObjectIDs),
            removedShapes: removedShapes,
            addedObjectIDs: [groupShape.id],
            addedShapes: [groupShape.id: groupShape],
            oldSelectedObjectIDs: selectedObjectIDs,
            newSelectedObjectIDs: newSelectedIDs
        )

        commandManager.execute(command)

        selectedShapeIDs = [groupShape.id]
        selectedTextIDs.removeAll()
        selectedObjectIDs = [groupShape.id]
    }

    func flattenSelectedObjects() {
        guard let layerIndex = selectedLayerIndex,
              selectedShapeIDs.count > 1 else { return }

        var removedShapes: [UUID: VectorShape] = [:]
        let objectsToRemove = unifiedObjects.filter { selectedObjectIDs.contains($0.id) }
        for obj in objectsToRemove {
            switch obj.objectType {
            case .text(let shape),
                 .shape(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                removedShapes[obj.id] = shape
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
        
        let newSelectedIDs: Set<UUID> = [flattenedShape.id]

        let command = GroupCommand(
            operation: .flatten,
            layerIndex: layerIndex,
            removedObjectIDs: Array(selectedObjectIDs),
            removedShapes: removedShapes,
            addedObjectIDs: [flattenedShape.id],
            addedShapes: [flattenedShape.id: flattenedShape],
            oldSelectedObjectIDs: selectedObjectIDs,
            newSelectedObjectIDs: newSelectedIDs
        )

        commandManager.execute(command)

        selectedShapeIDs = [flattenedShape.id]
        selectedObjectIDs = [flattenedShape.id]
    }

    func ungroupSelectedObjects() {
        print("🟡 UNGROUP: Starting, selectedObjectIDs=\(selectedObjectIDs)")
        guard let layerIndex = selectedLayerIndex,
              !selectedObjectIDs.isEmpty else {
            print("🔴 UNGROUP: FAILED - layerIndex=\(selectedLayerIndex as Any), isEmpty=\(selectedObjectIDs.isEmpty)")
            return
        }

        var newSelectedShapeIDs: Set<UUID> = []
        var shapesToRemove: [UUID] = []
        var shapesToAdd: [VectorShape] = []

        var removedShapes: [UUID: VectorShape] = [:]

        for objectID in selectedObjectIDs {
            print("🟡 UNGROUP: Processing objectID=\(objectID)")

            if let unifiedObject = findObject(by: objectID) {
                switch unifiedObject.objectType {
                case .group(let shape), .clipGroup(let shape):
                    print("🟡 UNGROUP: Found group, isGroupContainer=\(shape.isGroupContainer), groupedShapes.count=\(shape.groupedShapes.count)")

                    if shape.isGroupContainer {
                        removedShapes[objectID] = shape

                        let shapesToUngroup = shape.isClippingGroup ? shape.groupedShapes.reversed() : shape.groupedShapes

                        for groupedShape in shapesToUngroup {
                            print("🟡 UNGROUP: Adding grouped shape id=\(groupedShape.id)")
                            shapesToAdd.append(groupedShape)
                            newSelectedShapeIDs.insert(groupedShape.id)
                        }

                        shapesToRemove.append(objectID)
                    } else {
                        newSelectedShapeIDs.insert(objectID)
                    }
                case .shape, .warp, .clipMask, .text:
                    print("🟡 UNGROUP: Not a group, keeping selected")
                    newSelectedShapeIDs.insert(objectID)
                }
            } else {
                print("🔴 UNGROUP: Could not find object \(objectID)")
            }
        }

        var addedShapes: [UUID: VectorShape] = [:]

        for shape in shapesToAdd {
            addedShapes[shape.id] = shape
        }

        let command = GroupCommand(
            operation: .ungroup,
            layerIndex: layerIndex,
            removedObjectIDs: shapesToRemove,
            removedShapes: removedShapes,
            addedObjectIDs: Array(newSelectedShapeIDs),
            addedShapes: addedShapes,
            oldSelectedObjectIDs: selectedObjectIDs,
            newSelectedObjectIDs: newSelectedShapeIDs
        )

        commandManager.execute(command)

        selectedObjectIDs = newSelectedShapeIDs
        syncSelectionArrays()
    }

    func unflattenSelectedObjects() {
        guard let layerIndex = selectedLayerIndex,
              selectedShapeIDs.count == 1,
              let selectedShapeID = selectedShapeIDs.first else { return }
        let shapes = getShapesForLayer(layerIndex)
        guard let shapeIndex = shapes.firstIndex(where: { $0.id == selectedShapeID }) else { return }

        guard let flattenedGroup = getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { return }

        guard flattenedGroup.isGroup && !flattenedGroup.groupedShapes.isEmpty else { return }

        var removedShapes: [UUID: VectorShape] = [:]
        if unifiedObjects.contains(where: { $0.id == selectedShapeID }) {
            removedShapes[selectedShapeID] = flattenedGroup
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

        var addedShapes: [UUID: VectorShape] = [:]


        for shape in shapesToAdd {
            addedShapes[shape.id] = shape
        }

        let command = GroupCommand(
            operation: .unflatten,
            layerIndex: layerIndex,
            removedObjectIDs: [selectedShapeID],
            removedShapes: removedShapes,
            addedObjectIDs: Array(newSelectedIDs),
            addedShapes: addedShapes,
            oldSelectedObjectIDs: selectedObjectIDs,
            newSelectedObjectIDs: newSelectedIDs
        )

        commandManager.execute(command)

        selectedShapeIDs = newSelectedIDs
        selectedObjectIDs = newSelectedIDs
    }

    func makeCompoundPath() {
        guard let layerIndex = selectedLayerIndex,
              selectedShapeIDs.count > 1 else { return }

        var removedShapes: [UUID: VectorShape] = [:]
        let objectsToRemove = unifiedObjects.filter { selectedObjectIDs.contains($0.id) }
        for obj in objectsToRemove {
            switch obj.objectType {
            case .text(let shape),
                 .shape(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                removedShapes[obj.id] = shape
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

        let newSelectedIDs: Set<UUID> = [compoundShape.id]

        let command = GroupCommand(
            operation: .makeCompound,
            layerIndex: layerIndex,
            removedObjectIDs: Array(selectedObjectIDs),
            removedShapes: removedShapes,
            addedObjectIDs: [compoundShape.id],
            addedShapes: [compoundShape.id: compoundShape],
            oldSelectedObjectIDs: selectedObjectIDs,
            newSelectedObjectIDs: newSelectedIDs
        )

        commandManager.execute(command)

        selectedShapeIDs = [compoundShape.id]
        selectedObjectIDs = [compoundShape.id]
    }

    func makeLoopingPath() {
        guard let layerIndex = selectedLayerIndex,
              selectedShapeIDs.count > 1 else { return }

        var removedShapes: [UUID: VectorShape] = [:]
        let objectsToRemove = unifiedObjects.filter { selectedObjectIDs.contains($0.id) }
        for obj in objectsToRemove {
            switch obj.objectType {
            case .text(let shape),
                 .shape(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                removedShapes[obj.id] = shape
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
        
        let newSelectedIDs: Set<UUID> = [loopingShape.id]

        let command = GroupCommand(
            operation: .makeLooping,
            layerIndex: layerIndex,
            removedObjectIDs: Array(selectedObjectIDs),
            removedShapes: removedShapes,
            addedObjectIDs: [loopingShape.id],
            addedShapes: [loopingShape.id: loopingShape],
            oldSelectedObjectIDs: selectedObjectIDs,
            newSelectedObjectIDs: newSelectedIDs
        )

        commandManager.execute(command)

        selectedShapeIDs = [loopingShape.id]
        selectedObjectIDs = [loopingShape.id]
    }

    func releaseCompoundPath() {
        guard let layerIndex = selectedLayerIndex,
              selectedShapeIDs.count == 1,
              let selectedShapeID = selectedShapeIDs.first else { return }
        let shapes = getShapesForLayer(layerIndex)
        guard let shapeIndex = shapes.firstIndex(where: { $0.id == selectedShapeID }),
              let compoundShape = getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex),
              compoundShape.isTrueCompoundPath else { return }

        var removedShapes: [UUID: VectorShape] = [:]
        if unifiedObjects.contains(where: { $0.id == selectedShapeID }) {
            removedShapes[selectedShapeID] = compoundShape
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

        var addedShapes: [UUID: VectorShape] = [:]


        for shape in newShapes {
            addedShapes[shape.id] = shape
        }

        let command = GroupCommand(
            operation: .releaseCompound,
            layerIndex: layerIndex,
            removedObjectIDs: [selectedShapeID],
            removedShapes: removedShapes,
            addedObjectIDs: Array(newSelectedIDs),
            addedShapes: addedShapes,
            oldSelectedObjectIDs: selectedObjectIDs,
            newSelectedObjectIDs: newSelectedIDs
        )

        commandManager.execute(command)

        selectedShapeIDs = newSelectedIDs
        selectedObjectIDs = newSelectedIDs
    }

    func releaseLoopingPath() {
        guard let layerIndex = selectedLayerIndex,
              selectedShapeIDs.count == 1,
              let selectedShapeID = selectedShapeIDs.first else { return }
        let shapes = getShapesForLayer(layerIndex)
        guard let shapeIndex = shapes.firstIndex(where: { $0.id == selectedShapeID }),
              let loopingShape = getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex),
              loopingShape.isTrueLoopingPath else { return }

        var removedShapes: [UUID: VectorShape] = [:]
        if unifiedObjects.contains(where: { $0.id == selectedShapeID }) {
            removedShapes[selectedShapeID] = loopingShape
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

        var addedShapes: [UUID: VectorShape] = [:]


        for shape in newShapes {
            addedShapes[shape.id] = shape
        }

        let command = GroupCommand(
            operation: .releaseLooping,
            layerIndex: layerIndex,
            removedObjectIDs: [selectedShapeID],
            removedShapes: removedShapes,
            addedObjectIDs: Array(newSelectedIDs),
            addedShapes: addedShapes,
            oldSelectedObjectIDs: selectedObjectIDs,
            newSelectedObjectIDs: newSelectedIDs
        )

        commandManager.execute(command)

        selectedShapeIDs = newSelectedIDs
        selectedObjectIDs = newSelectedIDs
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
                if !currentPath.isEmpty {
                    currentPath.closeSubpath()
                }
                
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
