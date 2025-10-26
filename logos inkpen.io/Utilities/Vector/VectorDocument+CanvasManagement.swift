import SwiftUI
import Combine

extension VectorDocument {
    internal func createCanvasAndWorkingLayers() {
        // Clear both arrays
        layers.removeAll()
        snapshot.layers.removeAll()

        // Create Pasteboard layer
        var pasteboardLayer = VectorLayer(name: "Pasteboard", color: .gray)
        pasteboardLayer.isLocked = true
        layers.append(pasteboardLayer)
        snapshot.layers.append(Layer(
            id: pasteboardLayer.id,
            name: pasteboardLayer.name,
            objectIDs: [],
            isVisible: pasteboardLayer.isVisible,
            isLocked: pasteboardLayer.isLocked,
            opacity: pasteboardLayer.opacity,
            blendMode: pasteboardLayer.blendMode,
            color: .gray
        ))

        // Create Canvas layer
        var canvasLayer = VectorLayer(name: "Canvas", color: .blue)
        canvasLayer.isLocked = true
        layers.append(canvasLayer)
        snapshot.layers.append(Layer(
            id: canvasLayer.id,
            name: canvasLayer.name,
            objectIDs: [],
            isVisible: canvasLayer.isVisible,
            isLocked: canvasLayer.isLocked,
            opacity: canvasLayer.opacity,
            blendMode: canvasLayer.blendMode,
            color: .blue
        ))

        // Create default working layer
        let workingLayer = VectorLayer(name: "Layer 1", color: .green)
        layers.append(workingLayer)
        snapshot.layers.append(Layer(
            id: workingLayer.id,
            name: workingLayer.name,
            objectIDs: [],
            isVisible: workingLayer.isVisible,
            isLocked: workingLayer.isLocked,
            opacity: workingLayer.opacity,
            blendMode: workingLayer.blendMode,
            color: .green
        ))

        debugLayerOrder()
    }

    func debugLayerOrder() {
    }

    var documentBounds: CGRect {
        return CGRect(origin: .zero, size: settings.sizeInPoints)
    }

    func debugCurrentState() {
    }

    func translateAllContent(by delta: CGPoint, includeBackgrounds: Bool = false) {
        guard delta != .zero else { return }

        for layerIndex in layers.indices {
            let shapes = getShapesForLayer(layerIndex)
            for (shapeIndex, _) in shapes.enumerated() {
                var updatedShape = shapes[shapeIndex]
                updatedShape.transform = updatedShape.transform.translatedBy(x: delta.x, y: delta.y)
                setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
                applyTransformToShapeCoordinates(layerIndex: layerIndex, shapeIndex: shapeIndex)
            }
        }

        translateAllTextInUnified(delta: delta)
    }

    func onSettingsChanged() {
        // Background layers now rendered via SwiftUI Canvas - no update needed
    }

    /// Migrate old documents that have background shapes to new Canvas-based rendering
    func migrateBackgroundShapesToCanvas() {
        var needsMigration = false

        // Check if Pasteboard layer (index 0) has a background shape
        if layers.count > 0 && layers[0].name == "Pasteboard" {
            let pasteboardShapes = getShapesForLayer(0)
            if let bgShape = pasteboardShapes.first(where: { $0.name == "Pasteboard Background" }) {
                needsMigration = true
                Log.info("🔄 Found old Pasteboard Background shape - removing for Canvas migration", category: .general)
                removeShapeFromUnifiedSystem(id: bgShape.id)
            }
        }

        // Check if Canvas layer (index 1) has a background shape
        if layers.count > 1 && layers[1].name == "Canvas" {
            let canvasShapes = getShapesForLayer(1)
            if let bgShape = canvasShapes.first(where: { $0.name == "Canvas Background" }) {
                needsMigration = true
                Log.info("🔄 Found old Canvas Background shape - removing for Canvas migration", category: .general)
                removeShapeFromUnifiedSystem(id: bgShape.id)
            }
        }

        if needsMigration {
            Log.info("✅ Document migrated to SwiftUI Canvas-based backgrounds", category: .general)
        }
    }
}
