//
//  StrokeFillPanel.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI
import AppKit

// MARK: - Helper Structs

// MARK: - Helper Functions

/// Formats a number for display, showing decimals only when needed
func formatNumberForDisplay(_ value: Double, maxDecimals: Int = 2) -> String {
    // If the value is a whole number, show it without decimals
    if value.truncatingRemainder(dividingBy: 1) == 0 {
        return String(format: "%.0f", value)
    }
    // Otherwise show with specified decimal places
    return String(format: "%.\(maxDecimals)f", value)
}

// MARK: - Main Stroke and Fill Panel

struct StrokeFillPanel: View {
    @ObservedObject var document: VectorDocument
    @Environment(AppState.self) private var appState
    
    // REFACTORED: Use unified objects system for current stroke/fill colors
    private var selectedStrokeColor: VectorColor {
        // Get the first selected object from unified system
        if let firstSelectedObjectID = document.selectedObjectIDs.first,
           let unifiedObject = document.unifiedObjects.first(where: { $0.id == firstSelectedObjectID }) {
            switch unifiedObject.objectType {
            case .shape(let shape):
                if shape.isTextObject {
                    return shape.typography?.hasStroke == true ? shape.typography?.strokeColor ?? .clear : .clear
                } else {
                    if let strokeColor = shape.strokeStyle?.color {
                        return strokeColor
                    } else {
                        return .clear  // Show clear/none when no stroke exists
                    }
                }
            }
        }
        return document.defaultStrokeColor  // Show default color for new shapes
    }
    
    private var selectedFillColor: VectorColor {
        // Get the first selected object from unified system
        if let firstSelectedObjectID = document.selectedObjectIDs.first,
           let unifiedObject = document.unifiedObjects.first(where: { $0.id == firstSelectedObjectID }) {
            switch unifiedObject.objectType {
            case .shape(let shape):
                if shape.isTextObject {
                    return shape.typography?.fillColor ?? .black
                } else {
                    if let fillStyle = shape.fillStyle {
                        return fillStyle.color
                    }
                }
            }
        }
        return document.defaultFillColor  // Show default color for new shapes
    }
    
    private var strokeWidth: Double {
        // REFACTORED: Use unified objects system for stroke width
        if let firstSelectedObjectID = document.selectedObjectIDs.first,
           let unifiedObject = document.unifiedObjects.first(where: { $0.id == firstSelectedObjectID }) {
            switch unifiedObject.objectType {
            case .shape(let shape):
                if shape.isTextObject {
                    return shape.typography?.strokeWidth ?? document.defaultStrokeWidth
                } else {
                    return shape.strokeStyle?.width ?? document.defaultStrokeWidth
                }
            }
        }
        return document.defaultStrokeWidth // Show default width for new shapes
    }
    
    private var strokePlacement: StrokePlacement {
        // REFACTORED: Use unified objects system for stroke placement
        if let firstSelectedObjectID = document.selectedObjectIDs.first,
           let unifiedObject = document.unifiedObjects.first(where: { $0.id == firstSelectedObjectID }) {
            switch unifiedObject.objectType {
            case .shape(let shape):
                if shape.isTextObject {
                    return .center // Text objects don't have stroke placement - use default
                } else {
                    return shape.strokeStyle?.placement ?? .center
                }
            }
        }
        return .center
    }
    
    private var fillOpacity: Double {
        // REFACTORED: Use unified objects system for fill opacity
        if let firstSelectedObjectID = document.selectedObjectIDs.first,
           let unifiedObject = document.unifiedObjects.first(where: { $0.id == firstSelectedObjectID }) {
            switch unifiedObject.objectType {
            case .shape(let shape):
                if shape.isTextObject {
                    return shape.typography?.fillOpacity ?? document.defaultFillOpacity
                } else {
                    if let opacity = shape.fillStyle?.opacity {
                        return opacity
                    }
                }
            }
        }
        return document.defaultFillOpacity  // Show default opacity for new shapes
    }
    
    // PROFESSIONAL STROKE TRANSPARENCY (Professional Standard)
    private var strokeOpacity: Double {
        // REFACTORED: Use unified objects system for stroke opacity
        if let firstSelectedObjectID = document.selectedObjectIDs.first,
           let unifiedObject = document.unifiedObjects.first(where: { $0.id == firstSelectedObjectID }) {
            switch unifiedObject.objectType {
            case .shape(let shape):
                if shape.isTextObject {
                    return shape.typography?.strokeOpacity ?? document.defaultStrokeOpacity
                } else {
                    if let opacity = shape.strokeStyle?.opacity {
                        return opacity
                    }
                }
            }
        }
        return document.defaultStrokeOpacity  // Show default opacity for new shapes
    }

    
    // PROFESSIONAL JOIN TYPE SUPPORT (Professional Standard)
    private var strokeLineJoin: CGLineJoin {
        // REFACTORED: Use unified objects system for stroke line join
        if let firstSelectedObjectID = document.selectedObjectIDs.first,
           let unifiedObject = document.unifiedObjects.first(where: { $0.id == firstSelectedObjectID }) {
            switch unifiedObject.objectType {
            case .shape(let shape):
                if shape.isTextObject {
                    return document.defaultStrokeLineJoin // Text objects don't have line join - use default
                } else {
                    return shape.strokeStyle?.lineJoin ?? document.defaultStrokeLineJoin
                }
            }
        }
        return document.defaultStrokeLineJoin
    }
    
    // PROFESSIONAL ENDCAP SUPPORT (Professional Standard)
    private var strokeLineCap: CGLineCap {
        // REFACTORED: Use unified objects system for stroke line cap
        if let firstSelectedObjectID = document.selectedObjectIDs.first,
           let unifiedObject = document.unifiedObjects.first(where: { $0.id == firstSelectedObjectID }) {
            switch unifiedObject.objectType {
            case .shape(let shape):
                if shape.isTextObject {
                    return document.defaultStrokeLineCap // Text objects don't have line cap - use default
                } else {
                    return shape.strokeStyle?.lineCap ?? document.defaultStrokeLineCap
                }
            }
        }
        return document.defaultStrokeLineCap
    }
    
    // PROFESSIONAL MITER LIMIT SUPPORT (Professional Standard)
    private var strokeMiterLimit: Double {
        // REFACTORED: Use unified objects system for stroke miter limit
        if let firstSelectedObjectID = document.selectedObjectIDs.first,
           let unifiedObject = document.unifiedObjects.first(where: { $0.id == firstSelectedObjectID }) {
            switch unifiedObject.objectType {
            case .shape(let shape):
                if shape.isTextObject {
                    return document.defaultStrokeMiterLimit // Text objects don't have miter limit - use default
                } else {
                    return shape.strokeStyle?.miterLimit ?? document.defaultStrokeMiterLimit
                }
            }
        }
        return document.defaultStrokeMiterLimit
    }
    
    // IMAGE OPACITY SUPPORT
    private var hasSelectedImages: Bool {
        // REFACTORED: Use unified objects system for image detection
        return document.selectedObjectIDs.contains { objectID in
            if let unifiedObject = document.unifiedObjects.first(where: { $0.id == objectID }) {
                switch unifiedObject.objectType {
                case .shape(let shape):
                    if shape.isTextObject {
                        return false // Text objects don't contain images
                    } else {
                        return ImageContentRegistry.containsImage(shape) || shape.linkedImagePath != nil || shape.embeddedImageData != nil
                    }
                }
            }
            return false
        }
    }
    
    private var selectedImageOpacity: Double {
        // REFACTORED: Use unified objects system for image opacity
        for objectID in document.selectedObjectIDs {
            if let unifiedObject = document.unifiedObjects.first(where: { $0.id == objectID }) {
                switch unifiedObject.objectType {
                case .shape(let shape):
                    if shape.isTextObject {
                        continue // Text objects don't contain images
                    } else {
                        if ImageContentRegistry.containsImage(shape) || shape.linkedImagePath != nil || shape.embeddedImageData != nil {
                            return shape.opacity
                        }
                    }
                }
            }
        }
        return 1.0
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                    // Current Fill and Stroke Display
                    CurrentColorsView(
                        strokeColor: selectedStrokeColor,
                        fillColor: selectedFillColor,
                        strokeOpacity: strokeOpacity,
                        fillOpacity: fillOpacity,
                        onStrokeColorTap: {
                            document.activeColorTarget = .stroke
                            appState.persistentInkHUD.show(document: document)
                        },
                        onFillColorTap: {
                            document.activeColorTarget = .fill
                            appState.persistentInkHUD.show(document: document)
                        }
                    )
                    
                    // Fill Properties
                    FillPropertiesSection(
                        fillColor: selectedFillColor,
                        fillOpacity: fillOpacity,
                        onApplyFill: applyFillToSelectedShapes,
                        onUpdateFillColor: updateFillColor,
                        onUpdateFillOpacity: updateFillOpacity
                    )
                    
                    // Image Properties - Only show when images are selected
                    if hasSelectedImages {
                        ImagePropertiesSection(
                            imageOpacity: selectedImageOpacity,
                            onUpdateImageOpacity: updateImageOpacity
                        )
                    }
                    
                    // Stroke Properties
                    StrokePropertiesSection(
                        strokeColor: selectedStrokeColor,
                        strokeWidth: strokeWidth,
                        strokePlacement: strokePlacement,
                        strokeOpacity: strokeOpacity, // PROFESSIONAL STROKE TRANSPARENCY
                        strokeLineJoin: strokeLineJoin, // PROFESSIONAL JOIN TYPES
                        strokeLineCap: strokeLineCap, // PROFESSIONAL ENDCAPS
                        strokeMiterLimit: strokeMiterLimit, // PROFESSIONAL MITER LIMIT
                        onUpdateStrokeColor: updateStrokeColor,
                        onUpdateStrokeWidth: updateStrokeWidth,
                        onUpdateStrokePlacement: updateStrokePlacement,
                        onUpdateStrokeOpacity: updateStrokeOpacity, // PROFESSIONAL STROKE TRANSPARENCY
                        onUpdateLineJoin: updateStrokeLineJoin, // PROFESSIONAL JOIN TYPES
                        onUpdateLineCap: updateStrokeLineCap, // PROFESSIONAL ENDCAPS
                        onUpdateMiterLimit: updateStrokeMiterLimit // PROFESSIONAL MITER LIMIT
                    )
                    
                    // Expand Stroke Button - Only show when shapes selected
                    if !document.selectedObjectIDs.isEmpty {
                        Button("Expand Stroke") {
                            document.outlineSelectedStrokes()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .disabled(!document.canOutlineStrokes)
                        .help("Convert stroke to filled path (Cmd+Shift+O)")
                        .keyboardShortcut("o", modifiers: [.command, .shift])
                    }
                    
                    // Variable Stroke Section - Only show when brush tool is selected
                    if document.currentTool == .brush {
                        VariableStrokeSection(document: document)
                    }
                    
                    // Marker Settings Section - Only show when marker tool is selected
                    if document.currentTool == .marker {
                        MarkerSettingsSection(document: document)
                    }
                
                Spacer()
            }
            .padding()
        }
    }
    
    // REFACTORED: Update methods - use unified objects system
    private func updateFillColor(_ color: VectorColor) {
        // ALWAYS update the default color for new shapes
        document.defaultFillColor = color
        //Log.fileOperation("🎨 Set default fill color: \(color)", level: .info)
        
        // REFACTORED: Use unified objects system for color application
        var hasChanges = false
        
        // Apply to selected objects from unified system
        for objectID in document.selectedObjectIDs {
            if let unifiedObject = document.unifiedObjects.first(where: { $0.id == objectID }) {
                switch unifiedObject.objectType {
                case .shape(let shape):
                    if shape.isTextObject {
                        // MIGRATION: Use unified helper instead of direct assignment
                        document.updateTextFillColorInUnified(id: shape.id, color: color)
                        hasChanges = true
                    } else {
                        // Find the shape in the layers array and update it
                        // Use unified helper instead of direct property access
                        document.updateShapeFillColorInUnified(id: shape.id, color: color)
                        hasChanges = true
                    }
                }
            }
        }
        
        // Save to undo stack if we made changes
        if hasChanges {
            document.saveToUndoStack()
            // The unified helpers already update the unified objects, so no manual refresh needed
            
            // Force immediate UI update for visual responsiveness
            document.objectWillChange.send()
        }
    }
    
    private func updateFillOpacity(_ opacity: Double) {
        // ALWAYS update the default opacity for new shapes
        document.defaultFillOpacity = opacity
        //Log.fileOperation("🎨 Set default fill opacity: \(Int(opacity * 100))%", level: .info)
        
        // REFACTORED: Use unified objects system for opacity application
        var hasChanges = false
        
        // Apply to selected objects from unified system
        for objectID in document.selectedObjectIDs {
            if let unifiedObject = document.unifiedObjects.first(where: { $0.id == objectID }) {
                switch unifiedObject.objectType {
                case .shape(let shape):
                    if shape.isTextObject {
                        // Use unified helper for fill opacity update
                        document.updateTextFillOpacityInUnified(id: shape.id, opacity: opacity)
                        hasChanges = true
                    } else {
                        // Find the shape in the layers array and update it
                        if let layerIndex = unifiedObject.layerIndex < document.layers.count ? unifiedObject.layerIndex : nil,
                           document.getShapesForLayer(layerIndex).contains(where: { $0.id == shape.id }) {
                            // Use unified helper instead of direct property access
                            document.updateShapeFillOpacityInUnified(id: shape.id, opacity: opacity)
                            hasChanges = true
                        }
                    }
                }
            }
        }
        
        // Save to undo stack if we made changes
        if hasChanges {
            document.saveToUndoStack()
            // The unified helpers already update the unified objects, so no manual refresh needed
            
            // Force immediate UI update for visual responsiveness
            document.objectWillChange.send()
        }
    }
    
    private func updateStrokeColor(_ color: VectorColor) {
        // ALWAYS update the default color for new shapes
        document.defaultStrokeColor = color
        //Log.fileOperation("🎨 Set default stroke color: \(color)", level: .info)
        
        // REFACTORED: Use unified objects system for stroke color application
        var hasChanges = false
        
        // Apply to selected objects from unified system
        for objectID in document.selectedObjectIDs {
            if let unifiedObject = document.unifiedObjects.first(where: { $0.id == objectID }) {
                switch unifiedObject.objectType {
                case .shape(let shape):
                    if shape.isTextObject {
                        // MIGRATION: Use unified helper instead of direct assignment
                        document.updateTextStrokeColorInUnified(id: shape.id, color: color)
                        hasChanges = true
                    } else {
                        // Find the shape in the layers array and update it
                        if let layerIndex = unifiedObject.layerIndex < document.layers.count ? unifiedObject.layerIndex : nil,
                           document.getShapesForLayer(layerIndex).contains(where: { $0.id == shape.id }) {
                            // Use unified helper instead of direct property access
                            document.updateShapeStrokeColorInUnified(id: shape.id, color: color)
                            hasChanges = true
                        }
                    }
                }
            }
        }
        
        // Save to undo stack if we made changes
        if hasChanges {
            document.saveToUndoStack()
            // The unified helpers already update the unified objects, so no manual refresh needed
            
            // Force immediate UI update for visual responsiveness
            document.objectWillChange.send()
        }
    }
    
    private func updateStrokeWidth(_ width: Double) {
        // ALWAYS update the default stroke width for new shapes
        document.defaultStrokeWidth = width
        //Log.fileOperation("🎨 Set default stroke width: \(width)pt", level: .info)
        
        // REFACTORED: Use unified objects system for stroke width application
        var hasChanges = false
        
        // Apply to selected objects from unified system
        for objectID in document.selectedObjectIDs {
            if let unifiedObject = document.unifiedObjects.first(where: { $0.id == objectID }) {
                switch unifiedObject.objectType {
                case .shape(let shape):
                    if shape.isTextObject {
                        // Use unified helper for stroke width update
                        document.updateTextStrokeWidthInUnified(id: shape.id, width: width)
                        hasChanges = true
                    } else {
                        // Find the shape in the layers array and update it
                        if let layerIndex = unifiedObject.layerIndex < document.layers.count ? unifiedObject.layerIndex : nil,
                           document.getShapesForLayer(layerIndex).contains(where: { $0.id == shape.id }) {
                            // Use unified helper instead of direct property access
                            document.updateShapeStrokeWidthInUnified(id: shape.id, width: width)
                            hasChanges = true
                        }
                    }
                }
            }
        }
        
        // Save to undo stack if we made changes
        if hasChanges {
            document.saveToUndoStack()
            // The unified helpers already update the unified objects, so no manual refresh needed
            
            // Force immediate UI update for visual responsiveness
            document.objectWillChange.send()
        }
    }
    
    private func updateStrokePlacement(_ placement: StrokePlacement) {
        let activeShapeIDs = document.getActiveShapeIDs()
        if activeShapeIDs.isEmpty { return }
        
        document.saveToUndoStack()
        
        for shapeID in activeShapeIDs {
            // Find the shape across all layers
            for layerIndex in document.layers.indices {
                let shapes = document.getShapesForLayer(layerIndex)
                if shapes.firstIndex(where: { $0.id == shapeID }) != nil {
                    // Use unified helper instead of direct property access
                    document.updateShapeStrokePlacementInUnified(id: shapeID, placement: placement)
                    break // Found the shape, no need to check other layers
                }
            }
        }
        
        // OPTIMIZED: Direct unified object updates for smooth performance
        for shapeID in activeShapeIDs {
            if let unifiedIndex = document.unifiedObjects.firstIndex(where: { unifiedObj in
                if case .shape(let unifiedShape) = unifiedObj.objectType {
                    return unifiedShape.id == shapeID
                }
                return false
            }) {
                // Find updated shape data
                for layerIndex in document.layers.indices {
                    let shapes = document.getShapesForLayer(layerIndex)
                    if let shapeIndex = shapes.firstIndex(where: { $0.id == shapeID }),
                       let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {
                        document.unifiedObjects[unifiedIndex] = VectorObject(shape: shape, layerIndex: layerIndex, orderID: document.unifiedObjects[unifiedIndex].orderID)
                        break
                    }
                }
            }
        }
        
        // Force immediate UI update for visual responsiveness
        document.objectWillChange.send()
    }
    
            // PROFESSIONAL STROKE TRANSPARENCY (Professional Standard)
    private func updateStrokeOpacity(_ opacity: Double) {
        // ALWAYS update the default opacity for new shapes
        document.defaultStrokeOpacity = opacity
        //Log.fileOperation("🎨 Set default stroke opacity: \(Int(opacity * 100))%", level: .info)
        
        // If there are active shapes (regular or direct selection), update them too
        let activeShapeIDs = document.getActiveShapeIDs()
        if !activeShapeIDs.isEmpty {
            document.saveToUndoStack()
            
            for shapeID in activeShapeIDs {
                // Find the shape across all layers
                for layerIndex in document.layers.indices {
                    if document.getShapesForLayer(layerIndex).contains(where: { $0.id == shapeID }) {
                        // Use unified helper instead of direct property access
                        document.updateShapeStrokeOpacityInUnified(id: shapeID, opacity: opacity)
                        break // Found the shape, no need to check other layers
                    }
                }
            }
            
            // OPTIMIZED: Direct unified object updates for smooth performance
            for shapeID in activeShapeIDs {
                if let unifiedIndex = document.unifiedObjects.firstIndex(where: { unifiedObj in
                    if case .shape(let unifiedShape) = unifiedObj.objectType {
                        return unifiedShape.id == shapeID
                    }
                    return false
                }) {
                    // Find updated shape data
                    for layerIndex in document.layers.indices {
                        let shapes = document.getShapesForLayer(layerIndex)
                        if let shapeIndex = shapes.firstIndex(where: { $0.id == shapeID }),
                           let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {
                            document.unifiedObjects[unifiedIndex] = VectorObject(shape: shape, layerIndex: layerIndex, orderID: document.unifiedObjects[unifiedIndex].orderID)
                            break
                        }
                    }
                }
            }
            
            // Force immediate UI update for visual responsiveness
            document.objectWillChange.send()
        }
        

    }
    

    
            // PROFESSIONAL JOIN TYPE SUPPORT (Professional Standard)
    private func updateStrokeLineJoin(_ lineJoin: CGLineJoin) {
        // ALWAYS update the default line join for new shapes
        document.defaultStrokeLineJoin = lineJoin
        //Log.fileOperation("🎨 Set default stroke line join: \(lineJoin.displayName)", level: .info)
        
        // If there are active shapes (regular or direct selection), update them too
        let activeShapeIDs = document.getActiveShapeIDs()
        if !activeShapeIDs.isEmpty {
            document.saveToUndoStack()
            
            for shapeID in activeShapeIDs {
                // Find the shape across all layers
                for layerIndex in document.layers.indices {
                    if document.getShapesForLayer(layerIndex).contains(where: { $0.id == shapeID }) {
                        // Use unified helper instead of direct property access
                        document.updateShapeStrokeLineJoinInUnified(id: shapeID, lineJoin: lineJoin)
                        break // Found the shape, no need to check other layers
                    }
                }
            }
            
            // OPTIMIZED: Direct unified object updates for smooth performance
            for shapeID in activeShapeIDs {
                if let unifiedIndex = document.unifiedObjects.firstIndex(where: { unifiedObj in
                    if case .shape(let unifiedShape) = unifiedObj.objectType {
                        return unifiedShape.id == shapeID
                    }
                    return false
                }) {
                    // Find updated shape data
                    for layerIndex in document.layers.indices {
                        let shapes = document.getShapesForLayer(layerIndex)
                        if let shapeIndex = shapes.firstIndex(where: { $0.id == shapeID }),
                           let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {
                            document.unifiedObjects[unifiedIndex] = VectorObject(shape: shape, layerIndex: layerIndex, orderID: document.unifiedObjects[unifiedIndex].orderID)
                            break
                        }
                    }
                }
            }
            
            // Force immediate UI update for visual responsiveness
            document.objectWillChange.send()
        }
    }
    
            // PROFESSIONAL ENDCAP SUPPORT (Professional Standard)
    private func updateStrokeLineCap(_ lineCap: CGLineCap) {
        // ALWAYS update the default line cap for new shapes
        document.defaultStrokeLineCap = lineCap
        //Log.fileOperation("🎨 Set default stroke line cap: \(lineCap.displayName)", level: .info)
        
        // If there are active shapes (regular or direct selection), update them too
        let activeShapeIDs = document.getActiveShapeIDs()
        if !activeShapeIDs.isEmpty {
            document.saveToUndoStack()
            
            for shapeID in activeShapeIDs {
                // Find the shape across all layers
                for layerIndex in document.layers.indices {
                    if document.getShapesForLayer(layerIndex).contains(where: { $0.id == shapeID }) {
                        // Use unified helper instead of direct property access
                        document.updateShapeStrokeLineCapInUnified(id: shapeID, lineCap: lineCap)
                        break // Found the shape, no need to check other layers
                    }
                }
            }
            
            // OPTIMIZED: Direct unified object updates for smooth performance
            for shapeID in activeShapeIDs {
                if let unifiedIndex = document.unifiedObjects.firstIndex(where: { unifiedObj in
                    if case .shape(let unifiedShape) = unifiedObj.objectType {
                        return unifiedShape.id == shapeID
                    }
                    return false
                }) {
                    // Find updated shape data
                    for layerIndex in document.layers.indices {
                        let shapes = document.getShapesForLayer(layerIndex)
                        if let shapeIndex = shapes.firstIndex(where: { $0.id == shapeID }),
                           let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {
                            document.unifiedObjects[unifiedIndex] = VectorObject(shape: shape, layerIndex: layerIndex, orderID: document.unifiedObjects[unifiedIndex].orderID)
                            break
                        }
                    }
                }
            }
            
            // Force immediate UI update for visual responsiveness
            document.objectWillChange.send()
        }
    }
    
            // PROFESSIONAL MITER LIMIT SUPPORT (Professional Standard)
    private func updateStrokeMiterLimit(_ miterLimit: Double) {
        // ALWAYS update the default miter limit for new shapes
        document.defaultStrokeMiterLimit = miterLimit
        //print("🎨 Set default stroke miter limit: \(String(format: "%.1f", miterLimit))")
        
        // If there are active shapes (regular or direct selection), update them too
        let activeShapeIDs = document.getActiveShapeIDs()
        if !activeShapeIDs.isEmpty {
            document.saveToUndoStack()
            
            for shapeID in activeShapeIDs {
                // Find the shape across all layers
                for layerIndex in document.layers.indices {
                    if document.getShapesForLayer(layerIndex).contains(where: { $0.id == shapeID }) {
                        // Use unified helper instead of direct property access
                        document.updateShapeStrokeMiterLimitInUnified(id: shapeID, miterLimit: miterLimit)
                        break // Found the shape, no need to check other layers
                    }
                }
            }
            
            // OPTIMIZED: Direct unified object updates for smooth performance
            for shapeID in activeShapeIDs {
                if let unifiedIndex = document.unifiedObjects.firstIndex(where: { unifiedObj in
                    if case .shape(let unifiedShape) = unifiedObj.objectType {
                        return unifiedShape.id == shapeID
                    }
                    return false
                }) {
                    // Find updated shape data
                    for layerIndex in document.layers.indices {
                        let shapes = document.getShapesForLayer(layerIndex)
                        if let shapeIndex = shapes.firstIndex(where: { $0.id == shapeID }),
                           let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {
                            document.unifiedObjects[unifiedIndex] = VectorObject(shape: shape, layerIndex: layerIndex, orderID: document.unifiedObjects[unifiedIndex].orderID)
                            break
                        }
                    }
                }
            }
            
            // Force immediate UI update for visual responsiveness
            document.objectWillChange.send()
        }
    }
    
    // IMAGE OPACITY UPDATE METHOD
    private func updateImageOpacity(_ opacity: Double) {
        guard let layerIndex = document.selectedLayerIndex else { return }
        
        document.saveToUndoStack()
        
        for shapeID in document.selectedShapeIDs {
            let shapes = document.getShapesForLayer(layerIndex)
            if let shapeIndex = shapes.firstIndex(where: { $0.id == shapeID }),
               let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {
                // Only update image shapes
                if ImageContentRegistry.containsImage(shape) || shape.linkedImagePath != nil || shape.embeddedImageData != nil {
                    // Use unified helper instead of direct property access
                    document.updateShapeOpacityInUnified(id: shape.id, opacity: opacity)
                }
            }
        }
    }
    
    private func applyFillToSelectedShapes() {
        let activeShapeIDs = document.getActiveShapeIDs()
        if activeShapeIDs.isEmpty { return }
        
        document.saveToUndoStack()
        
        for shapeID in activeShapeIDs {
            document.createFillStyleInUnified(id: shapeID, color: selectedFillColor, opacity: fillOpacity)
        }
    }
    
    private func applyStrokeToSelectedShapes() {
        let activeShapeIDs = document.getActiveShapeIDs()
        if activeShapeIDs.isEmpty { return }
        
        document.saveToUndoStack()
        
        for shapeID in activeShapeIDs {
            document.createStrokeStyleInUnified(id: shapeID, color: selectedStrokeColor, width: strokeWidth, placement: strokePlacement, lineCap: document.defaultStrokeLineCap, lineJoin: document.defaultStrokeLineJoin, miterLimit: document.defaultStrokeMiterLimit, opacity: strokeOpacity)
        }
    }
    

}

struct CurrentColorsView: View {
    let strokeColor: VectorColor
    let fillColor: VectorColor
    let strokeOpacity: Double
    let fillOpacity: Double
    let onStrokeColorTap: () -> Void
    let onFillColorTap: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {  // Match ColorPanel spacing
            // Fill Color
            VStack(spacing: 4) {  // Compact spacing
                Button(action: onFillColorTap) {
                    renderColorSwatchRightPanel(fillColor, width: 30, height: 30, cornerRadius: 0, borderWidth: 1, opacity: fillOpacity)
                }
                .buttonStyle(PlainButtonStyle())
                
                Text("Fill")
                    .font(.caption2)  // Smaller font to match ColorPanel
                    .foregroundColor(Color.ui.secondaryText)
            }
            
            // Stroke Color
            VStack(spacing: 4) {  // Compact spacing
                Button(action: onStrokeColorTap) {
                    renderColorSwatchRightPanel(strokeColor, width: 30, height: 30, cornerRadius: 0, borderWidth: 1, opacity: strokeOpacity)
                }
                .buttonStyle(PlainButtonStyle())
                
                Text("Stroke")
                    .font(.caption2)  // Smaller font to match ColorPanel
                    .foregroundColor(Color.ui.secondaryText)
            }
        }
        .padding(12)  // Compact padding
        .background(Color.ui.semiTransparentControlBackground)
        .cornerRadius(8)
    }
}

struct FillPropertiesSection: View {
    let fillColor: VectorColor
    let fillOpacity: Double
    let onApplyFill: () -> Void
    let onUpdateFillColor: (VectorColor) -> Void
    let onUpdateFillOpacity: (Double) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fill Properties")
                .font(.headline)
                .fontWeight(.medium)
            
            VStack(spacing: 8) {
                HStack {
                    Text("Opacity")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(Int(fillOpacity * 100))%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }
                
                Slider(value: Binding(
                    get: { fillOpacity },
                    set: { onUpdateFillOpacity($0) }
                ), in: 0...1)
                .controlSize(.small)
            }
            
            HStack {
                Spacer()
                
                Button("Apply Fill") {
                    onApplyFill()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color.ui.semiTransparentControlBackground)
        .cornerRadius(12)
    }
}

struct StrokePropertiesSection: View {
    let strokeColor: VectorColor
    let strokeWidth: Double
    let strokePlacement: StrokePlacement
    let strokeOpacity: Double // PROFESSIONAL STROKE TRANSPARENCY
    let strokeLineJoin: CGLineJoin // PROFESSIONAL JOIN TYPES
    let strokeLineCap: CGLineCap // PROFESSIONAL ENDCAPS
    let strokeMiterLimit: Double // PROFESSIONAL MITER LIMIT
    let onUpdateStrokeColor: (VectorColor) -> Void
    let onUpdateStrokeWidth: (Double) -> Void
    let onUpdateStrokePlacement: (StrokePlacement) -> Void
    let onUpdateStrokeOpacity: (Double) -> Void // PROFESSIONAL STROKE TRANSPARENCY
    let onUpdateLineJoin: (CGLineJoin) -> Void // PROFESSIONAL JOIN TYPES
    let onUpdateLineCap: (CGLineCap) -> Void // PROFESSIONAL ENDCAPS
    let onUpdateMiterLimit: (Double) -> Void // PROFESSIONAL MITER LIMIT
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stroke Properties")
                .font(.headline)
                .fontWeight(.medium)
            
            // Stroke Width
            VStack(spacing: 8) {
                HStack {
                    Text("Width")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(String(format: "%.1f", strokeWidth)) pt")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }
                
                Slider(value: Binding(
                    get: { strokeWidth },
                    set: { onUpdateStrokeWidth($0) }
                ), in: 0...20)
                .controlSize(.small)
            }
            
            // PROFESSIONAL STROKE TRANSPARENCY (Professional Standard)
            VStack(spacing: 8) {
                HStack {
                    Text("Opacity")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(Int(strokeOpacity * 100))%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }
                
                Slider(value: Binding(
                    get: { strokeOpacity },
                    set: { onUpdateStrokeOpacity($0) }
                ), in: 0...1)
                .controlSize(.small)
            }
            
            // Stroke Placement
            VStack(alignment: .leading, spacing: 4) {
                Text("Placement")
                    .font(.caption)
                    .foregroundColor(Color.ui.secondaryText)
                
                Picker("Placement", selection: Binding(
                    get: { strokePlacement },
                    set: { onUpdateStrokePlacement($0) }
                )) {
                    ForEach(StrokePlacement.allCases, id: \.self) { placement in
                        HStack {
                            Image(systemName: placement.iconName)
                            Text(placement.rawValue)
                        }
                        .tag(placement)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .font(.caption)
            }
            
            // PROFESSIONAL JOIN TYPE CONTROL (Professional Standard)
            VStack(alignment: .leading, spacing: 4) {
                Text("Joins")
                    .font(.caption)
                    .foregroundColor(Color.ui.secondaryText)
                
                HStack(spacing: 6) {
                    ForEach([CGLineJoin.round, .miter, .bevel], id: \.self) { joinType in
                        Button {
                            onUpdateLineJoin(joinType)
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: joinType.iconName)
                                    .font(.system(size: 12))
                                
                                Text(joinType.displayName)
                                    .font(.caption2)
                            }
                            .foregroundColor(strokeLineJoin == joinType ? .accentColor : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(strokeLineJoin == joinType ? Color.accentColor.opacity(0.1) : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(strokeLineJoin == joinType ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 0.5)
                                    )
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(joinType.description)
                    }
                }
            }
            
            // PROFESSIONAL ENDCAP CONTROL (Professional Standard)
            VStack(alignment: .leading, spacing: 4) {
                Text("End Caps")
                    .font(.caption)
                    .foregroundColor(Color.ui.secondaryText)
                
                HStack(spacing: 6) {
                    ForEach([CGLineCap.butt, .round, .square], id: \.self) { capType in
                        Button {
                            onUpdateLineCap(capType)
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: capType.iconName)
                                    .font(.system(size: 12))
                                
                                Text(capType.displayName)
                                    .font(.caption2)
                            }
                            .foregroundColor(strokeLineCap == capType ? .accentColor : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(strokeLineCap == capType ? Color.accentColor.opacity(0.1) : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(strokeLineCap == capType ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 0.5)
                                    )
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(capType.description)
                    }
                }
            }
            
            // Miter Limit (only show for miter joins)
            if strokeLineJoin == .miter {
                VStack(spacing: 8) {
                    HStack {
                        Text("Miter Limit")
                            .font(.caption)
                            .foregroundColor(Color.ui.secondaryText)
                        Spacer()
                        Text("\(String(format: "%.1f", strokeMiterLimit))")
                            .font(.caption)
                            .foregroundColor(Color.ui.secondaryText)
                    }
                    
                    Slider(value: Binding(
                        get: { strokeMiterLimit },
                        set: { onUpdateMiterLimit($0) }
                    ), in: 1...20)
                    .controlSize(.small)
                    .tint(.blue)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(Color.ui.semiTransparentControlBackground)
        .cornerRadius(12)
    }
}



// REMOVED: GradientFillSection moved to GradientPanel.swift

// MARK: - CGLineJoin Extensions for UI

extension CGLineJoin {
    var iconName: String {
        switch self {
        case .miter: return "triangle"
        case .round: return "circle"
        case .bevel: return "hexagon"
        @unknown default: return "triangle"
        }
    }
    
    var displayName: String {
        switch self {
        case .miter: return "Miter"
        case .round: return "Round"
        case .bevel: return "Bevel"
        @unknown default: return "Miter"
        }
    }
    
    var description: String {
        switch self {
                        case .miter: return "Sharp pointed corners (Professional default)"
        case .round: return "Smooth rounded corners"
        case .bevel: return "Chamfered corners (cuts off sharp points)"
        @unknown default: return "Sharp pointed corners"
        }
    }
}

// MARK: - CGLineCap Extensions for UI

extension CGLineCap {
    var iconName: String {
        switch self {
        case .butt: return "minus"
        case .round: return "circle"
        case .square: return "square"
        @unknown default: return "minus"
        }
    }
    
    var displayName: String {
        switch self {
        case .butt: return "Butt"
        case .round: return "Round"
        case .square: return "Square"
        @unknown default: return "Butt"
        }
    }
    
    var description: String {
        switch self {
        case .butt: return "Square end aligned with path endpoint"
        case .round: return "Rounded end extending beyond path endpoint"
        case .square: return "Square end extending beyond path endpoint"
        @unknown default: return "Square end aligned with path endpoint"
        }
    }
}

// MARK: - Variable Stroke Section

struct VariableStrokeSection: View {
    @ObservedObject var document: VectorDocument
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "scribble.variable")
                    .foregroundColor(.accentColor)
                Text("Variable Stroke")
                    .font(.headline)
                Spacer()
            }
            
            // Brush Thickness
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Thickness")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(formatNumberForDisplay(document.currentBrushThickness))pt")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.primaryText)
                        .monospacedDigit()
                }
                
                Slider(value: Binding(
                    get: { document.currentBrushThickness },
                    set: { document.currentBrushThickness = $0 }
                ), in: 1...100, step: 0.5) {
                    Text("Brush Thickness")
                } minimumValueLabel: {
                    Text("1")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                } maximumValueLabel: {
                    Text("100")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }
                .help("Adjust brush stroke thickness (1-100 points)")
            }
            
            // Pressure Sensitivity Toggle
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Pressure Sensitivity")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { appState.pressureSensitivityEnabled },
                        set: { appState.pressureSensitivityEnabled = $0 }
                    ))
                    .toggleStyle(SwitchToggleStyle())
                    .scaleEffect(0.8)
                }
                .help("Enable or disable pressure sensitivity for variable stroke")
            }
            
            // Pressure Sensitivity Slider (only show when enabled)
            if appState.pressureSensitivityEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Sensitivity")
                            .font(.subheadline)
                            .foregroundColor(Color.ui.secondaryText)
                        Spacer()
                        Text("\(Int(document.currentBrushPressureSensitivity * 100))%")
                            .font(.subheadline)
                            .foregroundColor(Color.ui.primaryText)
                            .monospacedDigit()
                    }
                
                Slider(value: Binding(
                    get: { document.currentBrushPressureSensitivity },
                    set: { document.currentBrushPressureSensitivity = $0 }
                ), in: 0...1, step: 0.05) {
                    Text("Pressure Sensitivity")
                } minimumValueLabel: {
                    Text("0%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                } maximumValueLabel: {
                    Text("100%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }
                .help("How much pressure affects thickness (simulated if no pressure input)")
            }
            }
            
            // Brush Taper
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Taper")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(Int(document.currentBrushTaper * 100))%")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.primaryText)
                        .monospacedDigit()
                }
                
                Slider(value: Binding(
                    get: { document.currentBrushTaper },
                    set: { document.currentBrushTaper = $0 }
                ), in: 0...1, step: 0.05) {
                    Text("Brush Taper")
                } minimumValueLabel: {
                    Text("0%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                } maximumValueLabel: {
                    Text("100%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }
                .help("Amount of tapering at start and end of stroke")
            }
            
            // Brush Smoothness
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Smoothness")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(formatNumberForDisplay(document.currentBrushSmoothingTolerance))")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.primaryText)
                        .monospacedDigit()
                }
                
                Slider(value: Binding(
                    get: { document.currentBrushSmoothingTolerance },
                    set: { document.currentBrushSmoothingTolerance = $0 }
                ), in: 0.5...10, step: 0.25) {
                    Text("Brush Smoothness")
                } minimumValueLabel: {
                    Text("0.5")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                } maximumValueLabel: {
                    Text("10")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }
                .help("Curve fitting tolerance - lower values preserve more detail, higher values create smoother curves")
            }
            
            // Brush Tool Options
            VStack(alignment: .leading, spacing: 12) {
                Divider()
                    .padding(.vertical, 4)
                
                // Apply No Stroke Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apply No Stroke")
                            .font(.subheadline)
                            .foregroundColor(Color.ui.primaryText)
                        Text("Remove stroke from brush shapes")
                            .font(.caption)
                            .foregroundColor(Color.ui.secondaryText)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { document.brushApplyNoStroke },
                        set: { document.brushApplyNoStroke = $0 }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    .help("When enabled, brush shapes will have no stroke regardless of current stroke settings")
                }
                
                // Remove Overlap Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Remove Overlap")
                            .font(.subheadline)
                            .foregroundColor(Color.ui.primaryText)
                        Text("Union overlapping parts of same shape")
                            .font(.caption)
                            .foregroundColor(Color.ui.secondaryText)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { document.brushRemoveOverlap },
                        set: { document.brushRemoveOverlap = $0 }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    .help("When enabled, overlapping parts of brush strokes will be merged using union operation")
                }
            }
            
            // Pressure Input Status
            HStack {
                Image(systemName: document.hasPressureInput ? "hand.point.up.braille" : "hand.tap")
                    .foregroundColor(document.hasPressureInput ? .green : .orange)
                Text(document.hasPressureInput ? "Pressure input detected" : "Using simulated pressure")
                    .font(.caption)
                    .foregroundColor(Color.ui.secondaryText)
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Marker Settings Section
struct MarkerSettingsSection: View {
    @ObservedObject var document: VectorDocument
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "pen")
                    .foregroundColor(.accentColor)
                Text("Marker Settings")
                    .font(.headline)
                    .foregroundColor(Color.ui.primaryText)
                Spacer()
            }
            
            // Marker Tip Size
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Tip Size")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(Int(document.currentMarkerTipSize))pt")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.primaryText)
                        .monospacedDigit()
                }
                
                Slider(value: Binding(
                    get: { document.currentMarkerTipSize },
                    set: { document.currentMarkerTipSize = $0 }
                ), in: 1...50, step: 1) {
                    Text("Marker Tip Size")
                } minimumValueLabel: {
                    Text("1")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                } maximumValueLabel: {
                    Text("50")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }
                .help("Adjust marker tip thickness (1-50 points)")
            }
            
            // Marker Opacity
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Opacity")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(Int(document.currentMarkerOpacity * 100))%")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.primaryText)
                        .monospacedDigit()
                }
                
                Slider(value: Binding(
                    get: { document.currentMarkerOpacity },
                    set: { document.currentMarkerOpacity = $0 }
                ), in: 0...1, step: 0.05) {
                    Text("Marker Opacity")
                } minimumValueLabel: {
                    Text("0%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                } maximumValueLabel: {
                    Text("100%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }
                .help("Adjust marker ink opacity (0-100%)")
            }
            
            // Pressure Sensitivity Toggle
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Pressure Sensitivity")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { appState.pressureSensitivityEnabled },
                        set: { appState.pressureSensitivityEnabled = $0 }
                    ))
                    .toggleStyle(SwitchToggleStyle())
                    .scaleEffect(0.8)
                }
                .help("Enable or disable pressure sensitivity for marker tool")
            }
            
            // Pressure Sensitivity Slider (only show when enabled)
            if appState.pressureSensitivityEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Sensitivity")
                            .font(.subheadline)
                            .foregroundColor(Color.ui.secondaryText)
                        Spacer()
                        Text("\(Int(document.currentMarkerPressureSensitivity * 100))%")
                            .font(.subheadline)
                            .foregroundColor(Color.ui.primaryText)
                            .monospacedDigit()
                    }
                
                Slider(value: Binding(
                    get: { document.currentMarkerPressureSensitivity },
                    set: { document.currentMarkerPressureSensitivity = $0 }
                ), in: 0...1, step: 0.05) {
                    Text("Marker Pressure Sensitivity")
                } minimumValueLabel: {
                    Text("0%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                } maximumValueLabel: {
                    Text("100%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }
                .help("How much pressure affects marker thickness (simulated if no pressure input)")
            }
            }
            
            // Smoothing Tolerance
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Smoothing")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(formatNumberForDisplay(document.currentMarkerSmoothingTolerance))")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.primaryText)
                        .monospacedDigit()
                }
                
                Slider(value: Binding(
                    get: { document.currentMarkerSmoothingTolerance },
                    set: { document.currentMarkerSmoothingTolerance = $0 }
                ), in: 0.5...10, step: 0.25) {
                    Text("Marker Smoothing")
                } minimumValueLabel: {
                    Text("0.5")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                } maximumValueLabel: {
                    Text("10")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }
                .help("Curve fitting tolerance - lower values preserve more detail, higher values create smoother curves")
            }
            
            // Feathering
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Feathering")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(Int(document.currentMarkerFeathering * 100))%")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.primaryText)
                        .monospacedDigit()
                }
                
                Slider(value: Binding(
                    get: { document.currentMarkerFeathering },
                    set: { document.currentMarkerFeathering = $0 }
                ), in: 0...1, step: 0.05) {
                    Text("Marker Feathering")
                } minimumValueLabel: {
                    Text("0%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                } maximumValueLabel: {
                    Text("100%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }
                .help("Edge softness for felt-tip marker appearance")
            }
            
            // Start Taper
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Start Taper")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(Int(document.currentMarkerTaperStart * 100))%")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.primaryText)
                        .monospacedDigit()
                }
                
                Slider(value: Binding(
                    get: { document.currentMarkerTaperStart },
                    set: { document.currentMarkerTaperStart = $0 }
                ), in: 0...0.5, step: 0.05) {
                    Text("Marker Start Taper")
                } minimumValueLabel: {
                    Text("0%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                } maximumValueLabel: {
                    Text("50%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }
                .help("Thickness tapering at the start of marker strokes")
            }
            
            // End Taper
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("End Taper")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(Int(document.currentMarkerTaperEnd * 100))%")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.primaryText)
                        .monospacedDigit()
                }
                
                Slider(value: Binding(
                    get: { document.currentMarkerTaperEnd },
                    set: { document.currentMarkerTaperEnd = $0 }
                ), in: 0...0.5, step: 0.05) {
                    Text("Marker End Taper")
                } minimumValueLabel: {
                    Text("0%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                } maximumValueLabel: {
                    Text("50%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }
                .help("Thickness tapering at the end of marker strokes")
            }
            
            // Marker Tool Options
            VStack(alignment: .leading, spacing: 12) {
                Divider()
                    .padding(.vertical, 4)
                
                // Use Fill Color for Stroke Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Use Fill Color for Stroke")
                            .font(.subheadline)
                            .foregroundColor(Color.ui.primaryText)
                        Text("Use fill color for both fill and stroke")
                            .font(.caption)
                            .foregroundColor(Color.ui.secondaryText)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { document.markerUseFillAsStroke },
                        set: { document.markerUseFillAsStroke = $0 }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    .help("When enabled, marker uses fill color for both fill and stroke. When disabled, uses stroke color for both.")
                }
                
                // Apply No Stroke Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apply No Stroke")
                            .font(.subheadline)
                            .foregroundColor(Color.ui.primaryText)
                        Text("Remove stroke from marker shapes")
                            .font(.caption)
                            .foregroundColor(Color.ui.secondaryText)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { document.markerApplyNoStroke },
                        set: { document.markerApplyNoStroke = $0 }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    .help("When enabled, marker shapes will have no stroke regardless of current stroke settings")
                }
                
                // Remove Overlap Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Remove Overlap")
                            .font(.subheadline)
                            .foregroundColor(Color.ui.primaryText)
                        Text("Union overlapping parts of same shape")
                            .font(.caption)
                            .foregroundColor(Color.ui.secondaryText)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { document.markerRemoveOverlap },
                        set: { document.markerRemoveOverlap = $0 }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    .help("When enabled, overlapping parts of marker strokes will be merged using union operation")
                }
            }
            
            // Marker Info
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(Color.ui.primaryBlue)
                Text("Felt-tip marker with variable width based on drawing speed")
                    .font(.caption)
                    .foregroundColor(Color.ui.secondaryText)
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Image Properties Section
struct ImagePropertiesSection: View {
    let imageOpacity: Double
    let onUpdateImageOpacity: (Double) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundColor(.accentColor)
                Text("Image Properties")
                    .font(.headline)
                    .fontWeight(.medium)
                Spacer()
            }
            
            // Image Opacity
            VStack(spacing: 8) {
                HStack {
                    Text("Opacity")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(Int(imageOpacity * 100))%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }
                
                Slider(value: Binding(
                    get: { imageOpacity },
                    set: { onUpdateImageOpacity($0) }
                ), in: 0...1)
                .controlSize(.small)
                .help("Adjust image opacity (0-100%)")
            }
        }
        .padding()
        .background(Color.ui.semiTransparentControlBackground)
        .cornerRadius(12)
    }
}

// Preview
struct StrokeFillPanel_Previews: PreviewProvider {
    static var previews: some View {
        StrokeFillPanel(document: VectorDocument())
            .frame(width: 300, height: 600)
    }
}