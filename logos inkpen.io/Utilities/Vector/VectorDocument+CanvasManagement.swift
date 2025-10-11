import SwiftUI
import Combine

extension VectorDocument {
    internal func createCanvasAndWorkingLayers() {
        layers.removeAll()

        var pasteboardLayer = VectorLayer(name: "Pasteboard", color: .gray)
        pasteboardLayer.isLocked = true

        let canvasSize = settings.sizeInPoints
        let pasteboardSize = CGSize(width: canvasSize.width * 10, height: canvasSize.height * 10)

        let pasteboardOrigin = CGPoint(
            x: -(pasteboardSize.width - canvasSize.width) / 2,
            y: -(pasteboardSize.height - canvasSize.height) / 2
        )

        let pasteboardRect = VectorShape.rectangle(
            at: pasteboardOrigin,
            size: pasteboardSize
        )
        var pasteboardShape = pasteboardRect
        pasteboardShape.fillStyle = FillStyle(color: .black, opacity: 0.2)
        pasteboardShape.strokeStyle = nil
        pasteboardShape.name = "Pasteboard Background"
        layers.append(pasteboardLayer)
        addShapeToUnifiedSystem(pasteboardShape, layerIndex: 0)

        var canvasLayer = VectorLayer(name: "Canvas", color: .blue)
        canvasLayer.isLocked = true
        let canvasRect = VectorShape.rectangle(
            at: CGPoint(x: 0, y: 0),
            size: settings.sizeInPoints
        )
        var backgroundShape = canvasRect
        backgroundShape.fillStyle = FillStyle(color: settings.backgroundColor, opacity: 1.0)
        backgroundShape.strokeStyle = nil
        backgroundShape.name = "Canvas Background"
        layers.append(canvasLayer)
        addShapeToUnifiedSystem(backgroundShape, layerIndex: 1)

        layers.append(VectorLayer(name: "Layer 1", color: .green))

        debugLayerOrder()
    }

    func debugLayerOrder() {
    }

    func updatePasteboardLayer() {
        guard layers.count > 0,
              layers[0].name == "Pasteboard" else {
            return
        }

        let pasteboardShape = unifiedObjects
            .filter { $0.layerIndex == 0 }
            .compactMap { object -> VectorShape? in
                if case .shape(let shape) = object.objectType,
                   shape.name == "Pasteboard Background" {
                    return shape
                }
                return nil
            }
            .first

        guard let pasteboardShape = pasteboardShape else {
            return
        }

        let canvasSize = settings.sizeInPoints
        let pasteboardSize = CGSize(width: canvasSize.width * 10, height: canvasSize.height * 10)

        let pasteboardOrigin = CGPoint(
            x: -(pasteboardSize.width - canvasSize.width) / 2,
            y: -(pasteboardSize.height - canvasSize.height) / 2
        )

        if unifiedObjects.contains(where: { object in
            if case .shape(let shape) = object.objectType {
                return shape.name == "Pasteboard Background" && object.layerIndex == 0
            }
            return false
        }) {
            let shapesInLayer = getShapesForLayer(0)
            guard let pasteboardIndex = shapesInLayer.firstIndex(where: { $0.name == "Pasteboard Background" }) else { return }
            let newPasteboardRect = VectorShape.rectangle(
                at: pasteboardOrigin,
                size: pasteboardSize
            )
            var updatedPasteboardShape = newPasteboardRect
            updatedPasteboardShape.fillStyle = FillStyle(color: .black, opacity: 0.2)
            updatedPasteboardShape.strokeStyle = nil
            updatedPasteboardShape.name = "Pasteboard Background"
            updatedPasteboardShape.id = pasteboardShape.id

            setShapeAtIndex(layerIndex: 0, shapeIndex: pasteboardIndex, shape: updatedPasteboardShape)

        }
    }

    var documentBounds: CGRect {
        return CGRect(origin: .zero, size: settings.sizeInPoints)
    }

    func debugCurrentState() {
    }

    func updateCanvasLayer() {
        guard layers.count > 1,
              layers[1].name == "Canvas" else {
            return
        }

        let shapesInLayer = getShapesForLayer(1)
        guard let canvasIndex = shapesInLayer.firstIndex(where: { $0.name == "Canvas Background" }) else {
            return
        }
        let newCanvasRect = VectorShape.rectangle(
            at: CGPoint(x: 0, y: 0),
            size: settings.sizeInPoints
        )
        var updatedCanvasShape = newCanvasRect
        updatedCanvasShape.fillStyle = FillStyle(color: settings.backgroundColor, opacity: 1.0)
        updatedCanvasShape.strokeStyle = nil
        updatedCanvasShape.name = "Canvas Background"
        guard let existingCanvas = getShapeAtIndex(layerIndex: 1, shapeIndex: canvasIndex) else { return }
        updatedCanvasShape.id = existingCanvas.id
        setShapeAtIndex(layerIndex: 1, shapeIndex: canvasIndex, shape: updatedCanvasShape)
    }

    func translateAllContent(by delta: CGPoint, includeBackgrounds: Bool = false) {
        guard delta != .zero else { return }
        let backgroundNames: Set<String> = ["Canvas Background", "Pasteboard Background"]

        for layerIndex in layers.indices {
            let shapes = getShapesForLayer(layerIndex)
            for (shapeIndex, shape) in shapes.enumerated() {
                let shapeName = shape.name
                if !includeBackgrounds && backgroundNames.contains(shapeName) { continue }

                var updatedShape = shape
                updatedShape.transform = updatedShape.transform.translatedBy(x: delta.x, y: delta.y)
                setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
                applyTransformToShapeCoordinates(layerIndex: layerIndex, shapeIndex: shapeIndex)
            }
        }

        translateAllTextInUnified(delta: delta)

        objectWillChange.send()
    }

    internal func setupSettingsObservation() {
    }

    func onSettingsChanged() {
        updatePasteboardLayer()
        updateCanvasLayer()

        objectWillChange.send()

    }
}
