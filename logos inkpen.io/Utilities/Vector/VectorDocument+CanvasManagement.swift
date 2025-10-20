import SwiftUI
import Combine

extension VectorDocument {
    internal func createCanvasAndWorkingLayers() {
        layers.removeAll()

        var pasteboardLayer = VectorLayer(name: "Pasteboard", color: .gray)
        pasteboardLayer.isLocked = true
        layers.append(pasteboardLayer)

        var canvasLayer = VectorLayer(name: "Canvas", color: .blue)
        canvasLayer.isLocked = true
        layers.append(canvasLayer)

        layers.append(VectorLayer(name: "Layer 1", color: .green))

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
}
