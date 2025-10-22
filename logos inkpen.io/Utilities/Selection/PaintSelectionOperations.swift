import SwiftUI
import Foundation

/// Paint operations that can be performed on the current selection without needing document reference
class PaintSelectionOperations {
    static let shared = PaintSelectionOperations()

    private init() {}

    // MARK: - Helper methods for editing callbacks with undo/redo

    /// Handle fill opacity editing completion with undo/redo
    func handleFillOpacityEditingComplete(_ opacity: Double, document: VectorDocument) {
        var oldShapes: [UUID: VectorShape] = [:]
        var objectIDs: [UUID] = []
        let activeShapeIDs = document.getActiveShapeIDs()

        for shapeID in activeShapeIDs {
            if let shape = document.findShape(by: shapeID) {
                oldShapes[shapeID] = shape
                objectIDs.append(shapeID)
            }
        }

        document.defaultFillOpacity = opacity
        updateFillOpacityLive(opacity, document: document, isEditing: false)

        for objectID in document.viewState.selectedObjectIDs {
            document.clearTextPreviewTypography(id: objectID)
        }

        var newShapes: [UUID: VectorShape] = [:]
        for shapeID in objectIDs {
            if let shape = document.findShape(by: shapeID) {
                newShapes[shapeID] = shape
            }
        }

        if !objectIDs.isEmpty {
            let command = ShapeModificationCommand(objectIDs: objectIDs, oldShapes: oldShapes, newShapes: newShapes)
            document.commandManager.execute(command)
        }
    }

    /// Handle stroke width editing completion with undo/redo
    func handleStrokeWidthEditingComplete(_ width: Double, document: VectorDocument) {
        var oldShapes: [UUID: VectorShape] = [:]
        var objectIDs: [UUID] = []
        let activeShapeIDs = document.getActiveShapeIDs()

        for shapeID in activeShapeIDs {
            if let shape = document.findShape(by: shapeID) {
                oldShapes[shapeID] = shape
                objectIDs.append(shapeID)
            }
        }

        document.defaultStrokeWidth = width
        updateStrokeWidthLive(width, document: document, isEditing: false)

        var newShapes: [UUID: VectorShape] = [:]
        for shapeID in objectIDs {
            if let shape = document.findShape(by: shapeID) {
                newShapes[shapeID] = shape
            }
        }

        if !objectIDs.isEmpty {
            let command = ShapeModificationCommand(objectIDs: objectIDs, oldShapes: oldShapes, newShapes: newShapes)
            document.commandManager.execute(command)
        }
    }

    /// Handle stroke opacity editing completion with undo/redo
    func handleStrokeOpacityEditingComplete(_ opacity: Double, document: VectorDocument) {
        var oldShapes: [UUID: VectorShape] = [:]
        var objectIDs: [UUID] = []
        let activeShapeIDs = document.getActiveShapeIDs()

        for shapeID in activeShapeIDs {
            if let shape = document.findShape(by: shapeID) {
                oldShapes[shapeID] = shape
                objectIDs.append(shapeID)
            }
        }

        document.defaultStrokeOpacity = opacity
        updateStrokeOpacityLive(opacity, document: document, isEditing: false)

        var newShapes: [UUID: VectorShape] = [:]
        for shapeID in objectIDs {
            if let shape = document.findShape(by: shapeID) {
                newShapes[shapeID] = shape
            }
        }

        if !objectIDs.isEmpty {
            let command = ShapeModificationCommand(objectIDs: objectIDs, oldShapes: oldShapes, newShapes: newShapes)
            document.commandManager.execute(command)
        }
    }

    /// Handle miter limit editing completion with undo/redo
    func handleMiterLimitEditingComplete(_ miterLimit: Double, document: VectorDocument) {
        var oldShapes: [UUID: VectorShape] = [:]
        var objectIDs: [UUID] = []
        let activeShapeIDs = document.getActiveShapeIDs()

        for shapeID in activeShapeIDs {
            if let shape = document.findShape(by: shapeID) {
                oldShapes[shapeID] = shape
                objectIDs.append(shapeID)
            }
        }

        document.strokeDefaults.miterLimit = miterLimit
        updateStrokeMiterLimit(miterLimit, document: document)

        var newShapes: [UUID: VectorShape] = [:]
        for shapeID in objectIDs {
            if let shape = document.findShape(by: shapeID) {
                newShapes[shapeID] = shape
            }
        }

        if !objectIDs.isEmpty {
            let command = ShapeModificationCommand(objectIDs: objectIDs, oldShapes: oldShapes, newShapes: newShapes)
            document.commandManager.execute(command)
        }
    }

    // MARK: - Fill Operations

    /// Update fill opacity for selected objects (live update during dragging)
    func updateFillOpacityLive(_ opacity: Double, document: VectorDocument, isEditing: Bool) {
        for objectID in document.viewState.selectedObjectIDs {
            guard let object = document.snapshot.objects[objectID] else { continue }
            switch object.objectType {
            case .text(let shape):
                document.updateTextFillOpacityInUnified(id: shape.id, opacity: opacity)
            case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                document.updateShapeFillOpacityInUnified(id: shape.id, opacity: opacity)
            }
        }
    }

    /// Update fill opacity for selected objects with undo/redo support
    func updateFillOpacity(_ opacity: Double, document: VectorDocument) {
        document.defaultFillOpacity = opacity

        var oldOpacities: [UUID: Double] = [:]
        var newOpacities: [UUID: Double] = [:]

        for objectID in document.viewState.selectedObjectIDs {
            if let obj = document.snapshot.objects[objectID] {
                switch obj.objectType {
                case .text(let shape):
                    oldOpacities[objectID] = shape.typography?.fillOpacity ?? 1.0
                    document.updateTextFillOpacityInUnified(id: shape.id, opacity: opacity)
                    newOpacities[objectID] = opacity
                case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                    oldOpacities[objectID] = shape.fillStyle?.opacity ?? 1.0
                    if let layerIndex = obj.layerIndex < document.layers.count ? obj.layerIndex : nil,
                       document.getShapesForLayer(layerIndex).contains(where: { $0.id == shape.id }) {
                        document.updateShapeFillOpacityInUnified(id: shape.id, opacity: opacity)
                    }
                    newOpacities[objectID] = opacity
                }
            }
        }

        if !oldOpacities.isEmpty {
            let command = OpacityCommand(
                objectIDs: Array(document.viewState.selectedObjectIDs),
                target: .fill,
                oldOpacities: oldOpacities,
                newOpacities: newOpacities
            )
            document.executeCommand(command)
        }
    }

    /// Update fill color for selected objects
    func updateFillColor(_ color: VectorColor, opacity: Double? = nil) {
        let selection = CurrentSelection.shared
        let selectedObjects = selection.getSelectedObjects()

        for (_, object) in selectedObjects {
            switch object.objectType {
            case .text(var shape):
                if shape.typography == nil {
                    shape.typography = TypographyProperties(strokeColor: .black, fillColor: color)
                }
                shape.typography?.fillColor = color
                if let opacity = opacity {
                    shape.typography?.fillOpacity = opacity
                }

            case .shape(var shape),
                 .warp(var shape),
                 .group(var shape),
                 .clipGroup(var shape),
                 .clipMask(var shape):
                if shape.fillStyle == nil {
                    shape.fillStyle = FillStyle(color: color)
                } else {
                    shape.fillStyle?.color = color
                }
                if let opacity = opacity {
                    shape.fillStyle?.opacity = opacity
                }
            }
        }
    }

    // MARK: - Stroke Operations

    /// Update stroke width for selected objects (live update during dragging)
    func updateStrokeWidthLive(_ width: Double, document: VectorDocument, isEditing: Bool) {
        for objectID in document.viewState.selectedObjectIDs {
            guard let object = document.snapshot.objects[objectID] else { continue }
            switch object.objectType {
            case .text(let shape):
                if shape.typography?.hasStroke == true {
                    document.updateTextStrokeWidthInUnified(id: shape.id, width: width)
                }
            case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                document.updateShapeStrokeWidthInUnified(id: shape.id, width: width)
            }
        }
    }

    /// Update stroke opacity for selected objects (live update during dragging)
    func updateStrokeOpacityLive(_ opacity: Double, document: VectorDocument, isEditing: Bool) {
        for objectID in document.viewState.selectedObjectIDs {
            guard let object = document.snapshot.objects[objectID] else { continue }
            switch object.objectType {
            case .text:
                break
            case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                document.updateShapeStrokeOpacityInUnified(id: shape.id, opacity: opacity)
            }
        }
    }

    /// Update stroke placement for selected objects
    func updateStrokePlacement(_ placement: StrokePlacement, document: VectorDocument) {
        document.strokeDefaults.placement = placement
        let activeShapeIDs = document.getActiveShapeIDs()
        if activeShapeIDs.isEmpty { return }

        var oldPlacements: [UUID: StrokePlacement] = [:]
        var newPlacements: [UUID: StrokePlacement] = [:]

        for shapeID in activeShapeIDs {
            if let obj = document.snapshot.objects[shapeID] {
                switch obj.objectType {
                case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                    oldPlacements[shapeID] = shape.strokeStyle?.placement ?? .center
                    newPlacements[shapeID] = placement
                case .text:
                    continue
                }
            }
        }

        if !oldPlacements.isEmpty {
            let command = StrokePropertiesCommand(
                objectIDs: Array(activeShapeIDs),
                placement: oldPlacements,
                new: newPlacements
            )
            document.executeCommand(command)
        }

        for shapeID in activeShapeIDs {
            document.updateShapeStrokePlacementInUnified(id: shapeID, placement: placement)
        }
    }

    /// Update stroke line join for selected objects
    func updateStrokeLineJoin(_ lineJoin: CGLineJoin, document: VectorDocument) {
        document.strokeDefaults.lineJoin = lineJoin

        let activeShapeIDs = document.getActiveShapeIDs()
        if !activeShapeIDs.isEmpty {
            var oldLineJoins: [UUID: CGLineJoin] = [:]
            var newLineJoins: [UUID: CGLineJoin] = [:]

            for shapeID in activeShapeIDs {
                if let obj = document.snapshot.objects[shapeID] {
                    switch obj.objectType {
                    case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                        oldLineJoins[shapeID] = shape.strokeStyle?.lineJoin.cgLineJoin ?? .miter
                        newLineJoins[shapeID] = lineJoin
                    case .text:
                        continue
                    }
                }
            }

            if !oldLineJoins.isEmpty {
                let command = StrokePropertiesCommand(
                    objectIDs: Array(activeShapeIDs),
                    lineJoin: oldLineJoins,
                    new: newLineJoins
                )
                document.executeCommand(command)
            }

            for shapeID in activeShapeIDs {
                document.updateShapeStrokeLineJoinInUnified(id: shapeID, lineJoin: lineJoin)
            }
        }
    }

    /// Update stroke line cap for selected objects
    func updateStrokeLineCap(_ lineCap: CGLineCap, document: VectorDocument) {
        document.strokeDefaults.lineCap = lineCap

        let activeShapeIDs = document.getActiveShapeIDs()
        if !activeShapeIDs.isEmpty {
            var oldLineCaps: [UUID: CGLineCap] = [:]
            var newLineCaps: [UUID: CGLineCap] = [:]

            for shapeID in activeShapeIDs {
                if let obj = document.snapshot.objects[shapeID] {
                    switch obj.objectType {
                    case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                        oldLineCaps[shapeID] = shape.strokeStyle?.lineCap.cgLineCap ?? .butt
                        newLineCaps[shapeID] = lineCap
                    case .text:
                        continue
                    }
                }
            }

            if !oldLineCaps.isEmpty {
                let command = StrokePropertiesCommand(
                    objectIDs: Array(activeShapeIDs),
                    lineCap: oldLineCaps,
                    new: newLineCaps
                )
                document.executeCommand(command)
            }

            for shapeID in activeShapeIDs {
                document.updateShapeStrokeLineCapInUnified(id: shapeID, lineCap: lineCap)
            }
        }
    }

    /// Update stroke miter limit for selected objects (live update)
    func updateStrokeMiterLimitDirectNoUndo(_ miterLimit: Double, document: VectorDocument) {
        for objectID in document.viewState.selectedObjectIDs {
            guard let object = document.snapshot.objects[objectID] else { continue }
            switch object.objectType {
            case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                document.updateShapeStrokeMiterLimitInUnified(id: shape.id, miterLimit: miterLimit)
            case .text:
                continue
            }
        }
    }

    /// Update stroke miter limit for selected objects
    func updateStrokeMiterLimit(_ miterLimit: Double, document: VectorDocument) {
        document.strokeDefaults.miterLimit = miterLimit

        let activeShapeIDs = document.getActiveShapeIDs()
        if !activeShapeIDs.isEmpty {
            var oldMiterLimits: [UUID: Double] = [:]
            var newMiterLimits: [UUID: Double] = [:]

            for shapeID in activeShapeIDs {
                if let obj = document.snapshot.objects[shapeID] {
                    switch obj.objectType {
                    case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                        oldMiterLimits[shapeID] = shape.strokeStyle?.miterLimit ?? 10.0
                        newMiterLimits[shapeID] = miterLimit
                    case .text:
                        continue
                    }
                }
            }

            if !oldMiterLimits.isEmpty {
                let command = StrokePropertiesCommand(
                    objectIDs: Array(activeShapeIDs),
                    miterLimit: oldMiterLimits,
                    new: newMiterLimits
                )
                document.executeCommand(command)
            }

            for shapeID in activeShapeIDs {
                document.updateShapeStrokeMiterLimitInUnified(id: shapeID, miterLimit: miterLimit)
            }
        }
    }

    // MARK: - Image Operations

    /// Update opacity for selected images
    func updateImageOpacity(_ opacity: Double, document: VectorDocument) {
        guard let layerIndex = document.selectedLayerIndex else { return }

        var oldOpacities: [UUID: Double] = [:]
        var newOpacities: [UUID: Double] = [:]

        for shapeID in document.viewState.selectedObjectIDs {
            if let obj = document.snapshot.objects[shapeID] {
                switch obj.objectType {
                case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                    oldOpacities[shapeID] = shape.opacity
                    newOpacities[shapeID] = opacity
                case .text:
                    continue
                }
            }
        }

        if !oldOpacities.isEmpty {
            let command = StrokePropertiesCommand(
                objectIDs: Array(document.viewState.selectedObjectIDs),
                imageOpacity: oldOpacities,
                new: newOpacities
            )
            document.executeCommand(command)
        }

        for shapeID in document.viewState.selectedObjectIDs {
            let shapes = document.getShapesForLayer(layerIndex)
            if let shapeIndex = shapes.firstIndex(where: { $0.id == shapeID }),
               let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {
                if ImageContentRegistry.containsImage(shape, in: document) || shape.linkedImagePath != nil || shape.embeddedImageData != nil {
                    document.updateShapeOpacityInUnified(id: shape.id, opacity: opacity)
                }
            }
        }
    }

    /// Apply fill to selected shapes
    func applyFillToSelectedShapes(fillColor: VectorColor, fillOpacity: Double, document: VectorDocument) {
        let activeShapeIDs = document.getActiveShapeIDs()
        if activeShapeIDs.isEmpty { return }

        var oldColors: [UUID: VectorColor] = [:]
        var newColors: [UUID: VectorColor] = [:]
        var oldOpacities: [UUID: Double] = [:]
        var newOpacities: [UUID: Double] = [:]

        for shapeID in activeShapeIDs {
            if let obj = document.snapshot.objects[shapeID] {
                switch obj.objectType {
                case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                    oldColors[shapeID] = shape.fillStyle?.color ?? .black
                    newColors[shapeID] = fillColor
                    oldOpacities[shapeID] = shape.fillStyle?.opacity ?? 1.0
                    newOpacities[shapeID] = fillOpacity
                case .text:
                    continue
                }
            }
        }

        if !oldColors.isEmpty {
            let command = ChangeColorCommand(
                objectIDs: Array(activeShapeIDs),
                target: .fill,
                oldColors: oldColors,
                newColors: newColors,
                oldOpacities: oldOpacities,
                newOpacities: newOpacities
            )
            document.executeCommand(command)
        }

        for shapeID in activeShapeIDs {
            document.createFillStyleInUnified(id: shapeID, color: fillColor, opacity: fillOpacity)
        }
    }

    // MARK: - Shape Operations

    /// Outline selected strokes (convert strokes to filled paths)
    func outlineSelectedStrokes() {
        let selection = CurrentSelection.shared
        let selectedObjects = selection.getSelectedObjects()

        for (_, object) in selectedObjects {
            switch object.objectType {
            case .text:
                break // Text doesn't support outline stroke

            case .shape(var shape),
                 .warp(var shape),
                 .group(var shape),
                 .clipGroup(var shape),
                 .clipMask(var shape):
                // TODO: Implement stroke to path conversion
                // This would typically involve converting the stroke to a filled shape
                // For now, just remove the stroke and make it a fill
                if let strokeStyle = shape.strokeStyle {
                    // Convert stroke to fill
                    shape.fillStyle = FillStyle(color: strokeStyle.color, opacity: strokeStyle.opacity)
                    shape.strokeStyle = nil
                }
            }
        }
    }

    /// Duplicate selected shapes
    func duplicateSelectedShapes() {
        let selection = CurrentSelection.shared
        let selectedObjects = selection.getSelectedObjects()

        var duplicatedObjects: [UUID: VectorObject] = [:]

        for (_, object) in selectedObjects {
            // Create a new UUID for the duplicate
            let newID = UUID()

            // Create a copy of the shape with new ID
            var duplicatedShape = object.shape
            duplicatedShape.id = newID

            // Offset the transform slightly so it's visible
            duplicatedShape.transform = duplicatedShape.transform.translatedBy(x: 20, y: 20)

            // Create new VectorObject with duplicated shape
            let duplicatedObject = VectorObject(shape: duplicatedShape, layerIndex: object.layerIndex)

            // Add to snapshot
            selection.snapshot.objects[newID] = duplicatedObject
            duplicatedObjects[newID] = duplicatedObject
        }

        // Update selection to the new duplicates
        selection.viewState.selectedObjectIDs = Set(duplicatedObjects.keys)
    }

    // MARK: - Default Values Storage
    // These would normally come from document defaults

    var defaultStrokeWidth: Double = 1.0
    var defaultStrokeOpacity: Double = 1.0
    var defaultFillOpacity: Double = 1.0
    var defaultStrokeColor: VectorColor = .black
    var defaultFillColor: VectorColor = .white
    var defaultStrokePlacement: StrokePlacement = .center
    var defaultStrokeLineJoin: CGLineJoin = .miter
    var defaultStrokeLineCap: CGLineCap = .butt
    var defaultStrokeMiterLimit: Double = 10.0
}
