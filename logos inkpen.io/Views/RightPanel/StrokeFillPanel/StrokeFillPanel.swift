//
//  StrokeFillPanel.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI
import Combine

// MARK: - Main Stroke and Fill Panel

struct StrokeFillPanel: View {
    @ObservedObject var document: VectorDocument
    @Environment(AppState.self) private var appState

    // REFACTORED: Use unified objects system for current stroke/fill colors
    private var selectedStrokeColor: VectorColor {
        // Get the first selected object from unified system
        if let firstSelectedObjectID = document.selectedObjectIDs.first,
           let unifiedObject = document.findObject(by: firstSelectedObjectID) {
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
           let unifiedObject = document.findObject(by: firstSelectedObjectID) {
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
           let unifiedObject = document.findObject(by: firstSelectedObjectID) {
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
           let unifiedObject = document.findObject(by: firstSelectedObjectID) {
            switch unifiedObject.objectType {
            case .shape(let shape):
                if shape.isTextObject {
                    return document.defaultStrokePlacement // Text objects use default
                } else {
                    return shape.strokeStyle?.placement ?? document.defaultStrokePlacement
                }
            }
        }
        return document.defaultStrokePlacement // Return default when no selection
    }

    private var fillOpacity: Double {
        // REFACTORED: Use unified objects system for fill opacity
        if let firstSelectedObjectID = document.selectedObjectIDs.first,
           let unifiedObject = document.findObject(by: firstSelectedObjectID) {
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
           let unifiedObject = document.findObject(by: firstSelectedObjectID) {
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
           let unifiedObject = document.findObject(by: firstSelectedObjectID) {
            switch unifiedObject.objectType {
            case .shape(let shape):
                if shape.isTextObject {
                    return document.defaultStrokeLineJoin // Text objects don't have line join - use default
                } else {
                    return shape.strokeStyle?.lineJoin.cgLineJoin ?? document.defaultStrokeLineJoin
                }
            }
        }
        return document.defaultStrokeLineJoin
    }

    // PROFESSIONAL ENDCAP SUPPORT (Professional Standard)
    private var strokeLineCap: CGLineCap {
        // REFACTORED: Use unified objects system for stroke line cap
        if let firstSelectedObjectID = document.selectedObjectIDs.first,
           let unifiedObject = document.findObject(by: firstSelectedObjectID) {
            switch unifiedObject.objectType {
            case .shape(let shape):
                if shape.isTextObject {
                    return document.defaultStrokeLineCap // Text objects don't have line cap - use default
                } else {
                    return shape.strokeStyle?.lineCap.cgLineCap ?? document.defaultStrokeLineCap
                }
            }
        }
        return document.defaultStrokeLineCap
    }

    // PROFESSIONAL MITER LIMIT SUPPORT (Professional Standard)
    private var strokeMiterLimit: Double {
        // REFACTORED: Use unified objects system for stroke miter limit
        if let firstSelectedObjectID = document.selectedObjectIDs.first,
           let unifiedObject = document.findObject(by: firstSelectedObjectID) {
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
            if let unifiedObject = document.findObject(by: objectID) {
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
            if let unifiedObject = document.findObject(by: objectID) {
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
                        fillOpacity: fillOpacity,
                        onApplyFill: applyFillToSelectedShapes,
                        onUpdateFillOpacity: { value in
                            // ALWAYS update defaults immediately, no conditions
                            document.defaultFillOpacity = value
                            document.objectWillChange.send() // Force UI update
                            updateFillOpacity(value)
                        }
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
                        strokeWidth: strokeWidth,
                        strokePlacement: strokePlacement,
                        strokeOpacity: strokeOpacity,
                        strokeLineJoin: strokeLineJoin,
                        strokeLineCap: strokeLineCap,
                        strokeMiterLimit: strokeMiterLimit,
                        onUpdateStrokeWidth: { value in
                            // ALWAYS update defaults immediately, no conditions
                            document.defaultStrokeWidth = value
                            document.objectWillChange.send() // Force UI update
                            updateStrokeWidth(value)
                        },
                        onUpdateStrokePlacement: { value in
                            // ALWAYS allow placement changes
                            document.objectWillChange.send() // Force UI update
                            updateStrokePlacement(value)
                        },
                        onUpdateStrokeOpacity: { value in
                            // ALWAYS update defaults immediately, no conditions
                            document.defaultStrokeOpacity = value
                            document.objectWillChange.send() // Force UI update
                            updateStrokeOpacity(value)
                        },
                        onUpdateLineJoin: { value in
                            // ALWAYS update defaults immediately, no conditions
                            document.defaultStrokeLineJoin = value
                            document.objectWillChange.send() // Force UI update
                            updateStrokeLineJoin(value)
                        },
                        onUpdateLineCap: { value in
                            // ALWAYS update defaults immediately, no conditions
                            document.defaultStrokeLineCap = value
                            document.objectWillChange.send() // Force UI update
                            updateStrokeLineCap(value)
                        },
                        onUpdateMiterLimit: { value in
                            // ALWAYS update defaults immediately, no conditions
                            document.defaultStrokeMiterLimit = value
                            document.objectWillChange.send() // Force UI update
                            updateStrokeMiterLimit(value)
                        }
                    )

                    // Expand Stroke and Duplicate Buttons - Side by Side
                    HStack(spacing: 8) {
                        // Expand Stroke Button
                        Button {
                            document.outlineSelectedStrokes()
                        } label: {
                            Text("Expand Stroke")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                )
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .onTapGesture { // Luna Display compatibility
                            document.outlineSelectedStrokes()
                        }
                        .help("Convert stroke to filled path (Cmd+Shift+O)")
                        .keyboardShortcut("o", modifiers: [.command, .shift])

                        // Duplicate Button
                        Button {
                            document.duplicateSelectedShapes()
                        } label: {
                            Text("Duplicate")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                )
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .onTapGesture { // Luna Display compatibility
                            document.duplicateSelectedShapes()
                        }
                        .help("Duplicate selected shapes (Cmd+D)")
                        .keyboardShortcut("d", modifiers: .command)
                    }
                    .padding(.horizontal, 12)

                    // Tool-specific settings sections
                    switch document.currentTool {
                    case .freehand:
                        FreehandSettingsSection(document: document)
                    case .marker:
                        MarkerSettingsSection(document: document)
                    default:
                        EmptyView()
                    }

                Spacer()
            }
            .padding()
        }
    }

    // REFACTORED: Update methods - use unified objects system
    private func updateFillOpacity(_ opacity: Double) {
        // ALWAYS update the default opacity for new shapes
        document.defaultFillOpacity = opacity
        //Log.fileOperation("🎨 Set default fill opacity: \(Int(opacity * 100))%", level: .info)

        // REFACTORED: Use unified objects system for opacity application
        var hasChanges = false

        // Apply to selected objects from unified system
        for objectID in document.selectedObjectIDs {
            if let unifiedObject = document.findObject(by: objectID) {
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

    private func updateStrokeWidth(_ width: Double) {
        // ALWAYS update the default stroke width - NO RESTRICTIONS, NO CHECKS
        document.defaultStrokeWidth = width
        //Log.fileOperation("🎨 Set default stroke width: \(width)pt", level: .info)

        // REFACTORED: Use unified objects system for stroke width application
        var hasChanges = false

        // Apply to selected objects from unified system
        for objectID in document.selectedObjectIDs {
            if let unifiedObject = document.findObject(by: objectID) {
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
        // ALWAYS update default placement first - NO RESTRICTIONS
        document.defaultStrokePlacement = placement
        document.objectWillChange.send() // Force immediate UI update

        let activeShapeIDs = document.getActiveShapeIDs()
        if activeShapeIDs.isEmpty {
            // No shapes selected, but default has been updated
            return
        }

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

}
