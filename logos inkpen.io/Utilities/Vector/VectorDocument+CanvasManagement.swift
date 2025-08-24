//
//  VectorDocument+CanvasManagement.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation
import CoreGraphics

// MARK: - Canvas Management
extension VectorDocument {
    /// Creates Pasteboard, Canvas, and working layers in correct order (pasteboard behind everything)
    internal func createCanvasAndWorkingLayers() {
        // CRITICAL DEBUG: Clear any existing layers first to ensure proper order
        layers.removeAll()
        
        // Create Pasteboard layer FIRST (index 0) - working area behind everything
        var pasteboardLayer = VectorLayer(name: "Pasteboard")
        pasteboardLayer.isLocked = true  // Pasteboard should be LOCKED to prevent interference
        
        // Calculate pasteboard size (10x larger than canvas, same aspect ratio)
        let canvasSize = settings.sizeInPoints
        let pasteboardSize = CGSize(width: canvasSize.width * 10, height: canvasSize.height * 10)
        
        // Calculate pasteboard position (centered on canvas)
        let pasteboardOrigin = CGPoint(
            x: (canvasSize.width - pasteboardSize.width) / 2,
            y: (canvasSize.height - pasteboardSize.height) / 2
        )
        
        let pasteboardRect = VectorShape.rectangle(
            at: pasteboardOrigin,
            size: pasteboardSize
        )
        var pasteboardShape = pasteboardRect
        pasteboardShape.fillStyle = FillStyle(color: .black, opacity: 0.2)  // 20% black
        pasteboardShape.strokeStyle = nil
        pasteboardShape.name = "Pasteboard Background"
        pasteboardLayer.addShape(pasteboardShape)
        layers.append(pasteboardLayer)
        // Logging removed
        
        // Create Canvas layer SECOND (index 1) - canvas layer, LOCKED by default
        var canvasLayer = VectorLayer(name: "Canvas")
        canvasLayer.isLocked = true  // Canvas should be locked by default
        let canvasRect = VectorShape.rectangle(
            at: CGPoint(x: 0, y: 0),
            size: settings.sizeInPoints
        )
        var backgroundShape = canvasRect
        backgroundShape.fillStyle = FillStyle(color: settings.backgroundColor, opacity: 1.0)
        backgroundShape.strokeStyle = nil
        backgroundShape.name = "Canvas Background"
        canvasLayer.addShape(backgroundShape)
        layers.append(canvasLayer)
        // Logging removed
        
        // Create working layer THIRD (index 2) - for actual drawing
        layers.append(VectorLayer(name: "Layer 1"))
        // Logging removed
        
        // DEBUG: Print actual layer order to verify
        debugLayerOrder()
    }
    
    /// Debug function to print current layer order
    func debugLayerOrder() {
        // Logging removed
    }
    
    /// Update pasteboard layer to match canvas size and center it
    func updatePasteboardLayer() {
        guard layers.count > 0,
              layers[0].name == "Pasteboard",
              let pasteboardShape = layers[0].shapes.first(where: { $0.name == "Pasteboard Background" }) else {
            // Logging removed
            return
        }
        
        let canvasSize = settings.sizeInPoints
        let pasteboardSize = CGSize(width: canvasSize.width * 10, height: canvasSize.height * 10)
        
        // Calculate pasteboard position (centered on canvas)
        let pasteboardOrigin = CGPoint(
            x: (canvasSize.width - pasteboardSize.width) / 2,
            y: (canvasSize.height - pasteboardSize.height) / 2
        )
        
        // Find the pasteboard shape and update it
        if let pasteboardIndex = layers[0].shapes.firstIndex(where: { $0.name == "Pasteboard Background" }) {
            let newPasteboardRect = VectorShape.rectangle(
                at: pasteboardOrigin,
                size: pasteboardSize
            )
            var updatedPasteboardShape = newPasteboardRect
            updatedPasteboardShape.fillStyle = FillStyle(color: .black, opacity: 0.2)  // 20% black
            updatedPasteboardShape.strokeStyle = nil
            updatedPasteboardShape.name = "Pasteboard Background"
            updatedPasteboardShape.id = pasteboardShape.id  // Keep the same ID
            
            layers[0].shapes[pasteboardIndex] = updatedPasteboardShape
            
            Log.fileOperation("📐 Updated pasteboard: \(pasteboardSize) at \(pasteboardOrigin)", level: .info)
        }
    }
    
    /// Gets document bounds using standard document size (no Canvas-specific logic)
    var documentBounds: CGRect {
        return CGRect(origin: .zero, size: settings.sizeInPoints)
    }
    
    /// Debug function to print current document state
    func debugCurrentState() {

        Log.info("   Total layers: \(layers.count)", category: .general)
        Log.info("   Selected layer index: \(selectedLayerIndex ?? -1)", category: .general)
        for (index, layer) in layers.enumerated() {
            let marker = (selectedLayerIndex == index) ? "👈" : "  "
            Log.info("   \(marker) Layer \(index): '\(layer.name)' - locked: \(layer.isLocked), visible: \(layer.isVisible), shapes: \(layer.shapes.count)", category: .general)
        }
        Log.info("   Selected shapes: \(selectedShapeIDs.count)", category: .general)
        Log.info("   Current tool: \(currentTool)", category: .general)
    }
    
    /// Update canvas layer rectangle to match current `settings.sizeInPoints`
    func updateCanvasLayer() {
        guard layers.count > 1,
              layers[1].name == "Canvas",
              let canvasIndex = layers[1].shapes.firstIndex(where: { $0.name == "Canvas Background" }) else {
            Log.fileOperation("⚠️ Cannot update canvas - canvas layer not found", level: .info)
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
        updatedCanvasShape.id = layers[1].shapes[canvasIndex].id
        layers[1].shapes[canvasIndex] = updatedCanvasShape
        Log.fileOperation("📐 Updated canvas layer to size: \(settings.sizeInPoints)", level: .info)
    }
    
    /// Translate all content in the document by a delta. Skips background shapes by default.
    func translateAllContent(by delta: CGPoint, includeBackgrounds: Bool = false) {
        guard delta != .zero else { return }
        let backgroundNames: Set<String> = ["Canvas Background", "Pasteboard Background"]

        // Translate shapes across all layers
        for layerIndex in layers.indices {
            for shapeIndex in layers[layerIndex].shapes.indices {
                let shapeName = layers[layerIndex].shapes[shapeIndex].name
                if !includeBackgrounds && backgroundNames.contains(shapeName) { continue }

                // Apply translation via transform, then bake into coordinates
                layers[layerIndex].shapes[shapeIndex].transform = layers[layerIndex].shapes[shapeIndex].transform
                    .translatedBy(x: delta.x, y: delta.y)
                applyTransformToShapeCoordinates(layerIndex: layerIndex, shapeIndex: shapeIndex)
            }
        }

        // Translate text objects' positions
        for i in textObjects.indices {
            textObjects[i].position.x += delta.x
            textObjects[i].position.y += delta.y
        }

        objectWillChange.send()
    }
    
    /// Set up observation for settings changes to update pasteboard
    internal func setupSettingsObservation() {
        // Since settings is a struct, we can't directly observe individual properties
        // Instead, we'll provide a method that should be called when settings change
        Log.fileOperation("🔧 Settings observation setup complete", level: .info)
    }
    
    /// Call this method whenever document settings change to update pasteboard
    func onSettingsChanged() {
        // Update pasteboard when canvas size changes
        updatePasteboardLayer()
        // Update canvas layer to match new document size
        updateCanvasLayer()
        
        // Update any other dependent elements
        objectWillChange.send()
        
        Log.fileOperation("🔄 Settings changed - updated pasteboard layer", level: .info)
    }
}