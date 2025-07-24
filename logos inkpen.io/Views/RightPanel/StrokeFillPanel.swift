//
//  StrokeFillPanel.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

struct StrokeFillPanel: View {
    @ObservedObject var document: VectorDocument
    @State private var showingStrokeColorPicker = false
    @State private var showingFillColorPicker = false
    
    // FIXED: Show current colors - from selected shapes or defaults for new shapes
    private var selectedStrokeColor: VectorColor {
        // FIXED: Support both text and shapes  
        // If text objects are selected, show their stroke color
        if let firstSelectedTextID = document.selectedTextIDs.first,
           let textObject = document.textObjects.first(where: { $0.id == firstSelectedTextID }) {
            return textObject.typography.strokeColor
        }
        
        // If shapes are selected, show their color, otherwise show default
        if let layerIndex = document.selectedLayerIndex,
           let firstSelectedID = document.selectedShapeIDs.first,
           let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }),
           let strokeColor = shape.strokeStyle?.color {
            return strokeColor
        }
        return document.defaultStrokeColor  // Show default color for new shapes
    }
    
    private var selectedFillColor: VectorColor {
        // FIXED: Support both text and shapes
        // If text objects are selected, show their fill color
        if let firstSelectedTextID = document.selectedTextIDs.first,
           let textObject = document.textObjects.first(where: { $0.id == firstSelectedTextID }) {
            return textObject.typography.fillColor
        }
        
        // If shapes are selected, show their color, otherwise show default
        if let layerIndex = document.selectedLayerIndex,
           let firstSelectedID = document.selectedShapeIDs.first,
           let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }),
           let fillColor = shape.fillStyle?.color {
            return fillColor
        }
        return document.defaultFillColor  // Show default color for new shapes
    }
    
    private var strokeWidth: Double {
        guard let layerIndex = document.selectedLayerIndex,
              let firstSelectedID = document.selectedShapeIDs.first,
              let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }) else {
            return 1.0
        }
        return shape.strokeStyle?.width ?? 1.0
    }
    
    private var strokePlacement: StrokePlacement {
        guard let layerIndex = document.selectedLayerIndex,
              let firstSelectedID = document.selectedShapeIDs.first,
              let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }) else {
            return .center
        }
        return shape.strokeStyle?.placement ?? .center
    }
    
    private var fillOpacity: Double {
        // If shapes are selected, show their opacity, otherwise show default
        if let layerIndex = document.selectedLayerIndex,
           let firstSelectedID = document.selectedShapeIDs.first,
           let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }),
           let opacity = shape.fillStyle?.opacity {
            return opacity
        }
        return document.defaultFillOpacity  // Show default opacity for new shapes
    }
    
    // PROFESSIONAL STROKE TRANSPARENCY (Adobe Illustrator Standard)
    private var strokeOpacity: Double {
        // If shapes are selected, show their opacity, otherwise show default
        if let layerIndex = document.selectedLayerIndex,
           let firstSelectedID = document.selectedShapeIDs.first,
           let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }),
           let opacity = shape.strokeStyle?.opacity {
            return opacity
        }
        return document.defaultStrokeOpacity  // Show default opacity for new shapes
    }
    
    // PROFESSIONAL DASH PATTERN SUPPORT (Adobe Illustrator Standard)
    private var strokeDashPattern: [Double] {
        guard let layerIndex = document.selectedLayerIndex,
              let firstSelectedID = document.selectedShapeIDs.first,
              let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }) else {
            return []
        }
        return shape.strokeStyle?.dashPattern ?? []
    }
    
    // PROFESSIONAL JOIN TYPE SUPPORT (Adobe Illustrator Standard)
    private var strokeLineJoin: CGLineJoin {
        guard let layerIndex = document.selectedLayerIndex,
              let firstSelectedID = document.selectedShapeIDs.first,
              let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }) else {
            return .miter
        }
        return shape.strokeStyle?.lineJoin ?? .miter
    }
    
    // PROFESSIONAL ENDCAP SUPPORT (Adobe Illustrator Standard)
    private var strokeLineCap: CGLineCap {
        guard let layerIndex = document.selectedLayerIndex,
              let firstSelectedID = document.selectedShapeIDs.first,
              let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }) else {
            return .butt
        }
        return shape.strokeStyle?.lineCap ?? .butt
    }
    
    // PROFESSIONAL MITER LIMIT SUPPORT (Adobe Illustrator Standard)
    private var strokeMiterLimit: Double {
        guard let layerIndex = document.selectedLayerIndex,
              let firstSelectedID = document.selectedShapeIDs.first,
              let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }) else {
            return 10.0
        }
        return shape.strokeStyle?.miterLimit ?? 10.0
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
                        onStrokeColorTap: { showingStrokeColorPicker = true },
                        onFillColorTap: { showingFillColorPicker = true }
                    )
                    
                    // Fill Properties
                    FillPropertiesSection(
                        fillColor: selectedFillColor,
                        fillOpacity: fillOpacity,
                        onApplyFill: applyFillToSelectedShapes,
                        onUpdateFillColor: updateFillColor,
                        onUpdateFillOpacity: updateFillOpacity
                    )
                    
                    // Stroke Properties
                    StrokePropertiesSection(
                        strokeColor: selectedStrokeColor,
                        strokeWidth: strokeWidth,
                        strokePlacement: strokePlacement,
                        strokeOpacity: strokeOpacity, // PROFESSIONAL STROKE TRANSPARENCY
                        strokeDashPattern: strokeDashPattern, // PROFESSIONAL DASH PATTERNS
                        strokeLineJoin: strokeLineJoin, // PROFESSIONAL JOIN TYPES
                        strokeLineCap: strokeLineCap, // PROFESSIONAL ENDCAPS
                        strokeMiterLimit: strokeMiterLimit, // PROFESSIONAL MITER LIMIT
                        onApplyStroke: applyStrokeToSelectedShapes,
                        onUpdateStrokeColor: updateStrokeColor,
                        onUpdateStrokeWidth: updateStrokeWidth,
                        onUpdateStrokePlacement: updateStrokePlacement,
                        onUpdateStrokeOpacity: updateStrokeOpacity, // PROFESSIONAL STROKE TRANSPARENCY
                        onUpdateDashPattern: updateStrokeDashPattern, // PROFESSIONAL DASH PATTERNS
                        onUpdateLineJoin: updateStrokeLineJoin, // PROFESSIONAL JOIN TYPES
                        onUpdateLineCap: updateStrokeLineCap, // PROFESSIONAL ENDCAPS
                        onUpdateMiterLimit: updateStrokeMiterLimit // PROFESSIONAL MITER LIMIT
                    )
                    
                    // PROFESSIONAL STROKE OUTLINING (Adobe Illustrator Standard) - Only show when shapes selected
                    if !document.selectedShapeIDs.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Stroke Operations")
                                .font(.headline)
                                .fontWeight(.medium)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Button("Outline Stroke") {
                                    document.outlineSelectedStrokes()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.regular)
                                .disabled(!document.canOutlineStrokes)
                                .help("Convert stroke to filled path (Cmd+Shift+O)")
                                .keyboardShortcut("o", modifiers: [.command, .shift])
                                
                                if document.outlineableStrokesCount > 0 {
                                    Text("\(document.outlineableStrokesCount) stroke\(document.outlineableStrokesCount == 1 ? "" : "s") can be outlined")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else if !document.selectedShapeIDs.isEmpty {
                                    Text("No strokes available to outline")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(12)
                    }
                    
                    // Preset Styles
                    PresetStylesSection(
                        onApplyPreset: applyPresetStyle
                    )
                    
                    // Gradient Fill
                    GradientFillSection(document: document)
                
                Spacer()
            }
            .padding()
        }
        .sheet(isPresented: $showingStrokeColorPicker) {
            ColorPickerModal(
                document: document,
                title: "Stroke Color",
                onColorSelected: { color in
                    updateStrokeColor(color)
                    // Only add to swatches if not already present
                    if !document.currentSwatches.contains(color) {
                        document.addColorSwatch(color)
                    }
                }
            )
        }
        .sheet(isPresented: $showingFillColorPicker) {
            ColorPickerModal(
                document: document,
                title: "Fill Color",
                onColorSelected: { color in
                    updateFillColor(color)
                    // Only add to swatches if not already present
                    if !document.currentSwatches.contains(color) {
                        document.addColorSwatch(color)
                    }
                }
            )
        }
    }
    
    // FIXED: Update methods - update selected shapes AND set default for new shapes
    private func updateFillColor(_ color: VectorColor) {
        // ALWAYS update the default color for new shapes
        document.defaultFillColor = color
        print("🎨 Set default fill color: \(color)")
        
        // FIXED: Update selected text objects first
        if !document.selectedTextIDs.isEmpty {
            document.saveToUndoStack()
            
            for textID in document.selectedTextIDs {
                if let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) {
                    document.textObjects[textIndex].typography.fillColor = color
                    // CRITICAL FIX: Don't call updateBounds() - text canvas manages bounds now
                    // document.textObjects[textIndex].updateBounds() - REMOVED
                }
            }
        }
        
        // If there are selected shapes, update them too
        if let layerIndex = document.selectedLayerIndex, !document.selectedShapeIDs.isEmpty {
            if document.selectedTextIDs.isEmpty {
                // Only save to undo stack if we didn't already save for text
                document.saveToUndoStack()
            }
            
            for shapeID in document.selectedShapeIDs {
                if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                    if document.layers[layerIndex].shapes[shapeIndex].fillStyle == nil {
                        document.layers[layerIndex].shapes[shapeIndex].fillStyle = FillStyle(color: color, opacity: 1.0)
                    } else {
                        document.layers[layerIndex].shapes[shapeIndex].fillStyle?.color = color
                    }
                }
            }
        }
    }
    
    private func updateFillOpacity(_ opacity: Double) {
        // ALWAYS update the default opacity for new shapes
        document.defaultFillOpacity = opacity
        print("🎨 Set default fill opacity: \(Int(opacity * 100))%")
        
        // If there are selected shapes, update them too
        if let layerIndex = document.selectedLayerIndex, !document.selectedShapeIDs.isEmpty {
            document.saveToUndoStack()
            
            for shapeID in document.selectedShapeIDs {
                if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                    if document.layers[layerIndex].shapes[shapeIndex].fillStyle == nil {
                        document.layers[layerIndex].shapes[shapeIndex].fillStyle = FillStyle(color: document.defaultFillColor, opacity: opacity)
                    } else {
                        document.layers[layerIndex].shapes[shapeIndex].fillStyle?.opacity = opacity
                    }
                }
            }
        }
    }
    
    private func updateStrokeColor(_ color: VectorColor) {
        // ALWAYS update the default color for new shapes
        document.defaultStrokeColor = color
        print("🎨 Set default stroke color: \(color)")
        
        // FIXED: Update selected text objects first  
        if !document.selectedTextIDs.isEmpty {
            document.saveToUndoStack()
            
            for textID in document.selectedTextIDs {
                if let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) {
                    document.textObjects[textIndex].typography.hasStroke = true
                    document.textObjects[textIndex].typography.strokeColor = color
                    // CRITICAL FIX: Don't call updateBounds() - text canvas manages bounds now
                    // document.textObjects[textIndex].updateBounds() - REMOVED
                }
            }
        }
        
        // If there are selected shapes, update them too
        if let layerIndex = document.selectedLayerIndex, !document.selectedShapeIDs.isEmpty {
            if document.selectedTextIDs.isEmpty {
                // Only save to undo stack if we didn't already save for text
                document.saveToUndoStack()
            }
            
            for shapeID in document.selectedShapeIDs {
                if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                    if document.layers[layerIndex].shapes[shapeIndex].strokeStyle == nil {
                        document.layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(color: color, width: 1.0, opacity: 1.0)
                    } else {
                        document.layers[layerIndex].shapes[shapeIndex].strokeStyle?.color = color
                    }
                }
            }
        }
    }
    
    private func updateStrokeWidth(_ width: Double) {
        guard let layerIndex = document.selectedLayerIndex else { return }
        document.saveToUndoStack()
        
        for shapeID in document.selectedShapeIDs {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                if document.layers[layerIndex].shapes[shapeIndex].strokeStyle == nil {
                    document.layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(color: .black, width: width, opacity: 1.0)
                } else {
                    document.layers[layerIndex].shapes[shapeIndex].strokeStyle?.width = width
                }
            }
        }
    }
    
    private func updateStrokePlacement(_ placement: StrokePlacement) {
        guard let layerIndex = document.selectedLayerIndex else { return }
        document.saveToUndoStack()
        
        for shapeID in document.selectedShapeIDs {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                if document.layers[layerIndex].shapes[shapeIndex].strokeStyle == nil {
                    document.layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(color: .black, width: 1.0, placement: placement, opacity: 1.0)
                } else {
                    document.layers[layerIndex].shapes[shapeIndex].strokeStyle?.placement = placement
                }
            }
        }
    }
    
    // PROFESSIONAL STROKE TRANSPARENCY (Adobe Illustrator Standard)
    private func updateStrokeOpacity(_ opacity: Double) {
        // ALWAYS update the default opacity for new shapes
        document.defaultStrokeOpacity = opacity
        print("🎨 Set default stroke opacity: \(Int(opacity * 100))%")
        
        // If there are selected shapes, update them too
        if let layerIndex = document.selectedLayerIndex, !document.selectedShapeIDs.isEmpty {
            document.saveToUndoStack()
            
            for shapeID in document.selectedShapeIDs {
                if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                    if document.layers[layerIndex].shapes[shapeIndex].strokeStyle == nil {
                        document.layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(color: document.defaultStrokeColor, width: 1.0, opacity: opacity)
                    } else {
                        document.layers[layerIndex].shapes[shapeIndex].strokeStyle?.opacity = opacity
                    }
                }
            }
        }
    }
    
    // PROFESSIONAL DASH PATTERN SUPPORT (Adobe Illustrator Standard)
    private func updateStrokeDashPattern(_ dashPattern: [Double]) {
        guard let layerIndex = document.selectedLayerIndex else { return }
        document.saveToUndoStack()
        
        for shapeID in document.selectedShapeIDs {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                if document.layers[layerIndex].shapes[shapeIndex].strokeStyle == nil {
                    document.layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(color: .black, width: 1.0, dashPattern: dashPattern)
                } else {
                    document.layers[layerIndex].shapes[shapeIndex].strokeStyle?.dashPattern = dashPattern
                }
            }
        }
    }
    
    // PROFESSIONAL JOIN TYPE SUPPORT (Adobe Illustrator Standard)
    private func updateStrokeLineJoin(_ lineJoin: CGLineJoin) {
        guard let layerIndex = document.selectedLayerIndex else { return }
        document.saveToUndoStack()
        
        for shapeID in document.selectedShapeIDs {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                if document.layers[layerIndex].shapes[shapeIndex].strokeStyle == nil {
                    document.layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(color: document.defaultStrokeColor, width: 1.0, lineJoin: lineJoin)
                } else {
                    document.layers[layerIndex].shapes[shapeIndex].strokeStyle?.lineJoin = lineJoin
                }
            }
        }
    }
    
    // PROFESSIONAL ENDCAP SUPPORT (Adobe Illustrator Standard)
    private func updateStrokeLineCap(_ lineCap: CGLineCap) {
        guard let layerIndex = document.selectedLayerIndex else { return }
        document.saveToUndoStack()
        
        for shapeID in document.selectedShapeIDs {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                if document.layers[layerIndex].shapes[shapeIndex].strokeStyle == nil {
                    document.layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(color: document.defaultStrokeColor, width: 1.0, lineCap: lineCap)
                } else {
                    document.layers[layerIndex].shapes[shapeIndex].strokeStyle?.lineCap = lineCap
                }
            }
        }
    }
    
    // PROFESSIONAL MITER LIMIT SUPPORT (Adobe Illustrator Standard)
    private func updateStrokeMiterLimit(_ miterLimit: Double) {
        guard let layerIndex = document.selectedLayerIndex else { return }
        document.saveToUndoStack()
        
        for shapeID in document.selectedShapeIDs {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                if document.layers[layerIndex].shapes[shapeIndex].strokeStyle == nil {
                    document.layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(color: document.defaultStrokeColor, width: 1.0, miterLimit: miterLimit)
                } else {
                    document.layers[layerIndex].shapes[shapeIndex].strokeStyle?.miterLimit = miterLimit
                }
            }
        }
    }
    
    private func applyFillToSelectedShapes() {
        guard let layerIndex = document.selectedLayerIndex else { return }
        document.saveToUndoStack()
        
        for shapeID in document.selectedShapeIDs {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                document.layers[layerIndex].shapes[shapeIndex].fillStyle = FillStyle(
                    color: selectedFillColor,
                    opacity: fillOpacity
                )
            }
        }
    }
    
    private func applyStrokeToSelectedShapes() {
        guard let layerIndex = document.selectedLayerIndex else { return }
        document.saveToUndoStack()
        
        for shapeID in document.selectedShapeIDs {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                document.layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(
                    color: selectedStrokeColor,
                    width: strokeWidth,
                    placement: strokePlacement,
                    dashPattern: strokeDashPattern, // PROFESSIONAL DASH PATTERNS
                    opacity: strokeOpacity // PROFESSIONAL STROKE TRANSPARENCY
                )
            }
        }
    }
    
    private func applyPresetStyle(_ preset: StylePreset) {
        guard let layerIndex = document.selectedLayerIndex else { return }
        document.saveToUndoStack()
        
        for shapeID in document.selectedShapeIDs {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                document.layers[layerIndex].shapes[shapeIndex].strokeStyle = preset.strokeStyle
                document.layers[layerIndex].shapes[shapeIndex].fillStyle = preset.fillStyle
            }
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
                    .foregroundColor(.secondary)
            }
            
            // Stroke Color
            VStack(spacing: 4) {  // Compact spacing
                Button(action: onStrokeColorTap) {
                    renderColorSwatchRightPanel(strokeColor, width: 30, height: 30, cornerRadius: 0, borderWidth: 1, opacity: strokeOpacity)
                }
                .buttonStyle(PlainButtonStyle())
                
                Text("Stroke")
                    .font(.caption2)  // Smaller font to match ColorPanel
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)  // Compact padding
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
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
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(fillOpacity * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
    }
}

struct StrokePropertiesSection: View {
    let strokeColor: VectorColor
    let strokeWidth: Double
    let strokePlacement: StrokePlacement
    let strokeOpacity: Double // PROFESSIONAL STROKE TRANSPARENCY
    let strokeDashPattern: [Double] // PROFESSIONAL DASH PATTERNS
    let strokeLineJoin: CGLineJoin // PROFESSIONAL JOIN TYPES
    let strokeLineCap: CGLineCap // PROFESSIONAL ENDCAPS
    let strokeMiterLimit: Double // PROFESSIONAL MITER LIMIT
    let onApplyStroke: () -> Void
    let onUpdateStrokeColor: (VectorColor) -> Void
    let onUpdateStrokeWidth: (Double) -> Void
    let onUpdateStrokePlacement: (StrokePlacement) -> Void
    let onUpdateStrokeOpacity: (Double) -> Void // PROFESSIONAL STROKE TRANSPARENCY
    let onUpdateDashPattern: ([Double]) -> Void // PROFESSIONAL DASH PATTERNS
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
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(String(format: "%.1f", strokeWidth)) pt")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Slider(value: Binding(
                    get: { strokeWidth },
                    set: { onUpdateStrokeWidth($0) }
                ), in: 0...20)
                .controlSize(.small)
            }
            
            // PROFESSIONAL STROKE TRANSPARENCY (Adobe Illustrator Standard)
            VStack(spacing: 8) {
                HStack {
                    Text("Opacity")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(strokeOpacity * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                    .foregroundColor(.secondary)
                
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
            
            // PROFESSIONAL JOIN TYPE CONTROL (Adobe Illustrator Standard)
            VStack(alignment: .leading, spacing: 4) {
                Text("Joins")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
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
            
            // PROFESSIONAL ENDCAP CONTROL (Adobe Illustrator Standard)
            VStack(alignment: .leading, spacing: 4) {
                Text("End Caps")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
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
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(String(format: "%.1f", strokeMiterLimit))")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
            
            // PROFESSIONAL DASH PATTERN CONTROL (Adobe Illustrator Standard)
            VStack(alignment: .leading, spacing: 4) {
                Text("Dash Pattern")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        // SOLID STROKE
                        Button("Solid") {
                            onUpdateDashPattern([]) // Empty array = solid
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .background(strokeDashPattern.isEmpty ? Color.blue.opacity(0.2) : Color.clear)
                        .cornerRadius(4)
                        
                        // DASHED STROKE (Adobe Illustrator style: 5pt dash, 5pt gap)
                        Button("Dash") {
                            onUpdateDashPattern([5, 5]) // Classic dash pattern
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .background(strokeDashPattern == [5, 5] ? Color.blue.opacity(0.2) : Color.clear)
                        .cornerRadius(4)
                        
                        // DOTTED STROKE (Adobe Illustrator style: 1pt dot, 3pt gap)
                        Button("Dot") {
                            onUpdateDashPattern([1, 3]) // Classic dot pattern
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .background(strokeDashPattern == [1, 3] ? Color.blue.opacity(0.2) : Color.clear)
                        .cornerRadius(4)
                    }
                }
                
                // PROFESSIONAL PATTERN DISPLAY & CUSTOM EDITOR
                if !strokeDashPattern.isEmpty {
                    HStack {
                        Text("Pattern:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(strokeDashPattern.map { String(format: "%.0f", $0) }.joined(separator: ", "))")
                            .font(.caption2)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 4)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(2)
                        Spacer()
                    }
                    .padding(.top, 2)
                }
                
                // ADVANCED CUSTOM PATTERNS (Adobe Illustrator Style)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Button("Chain") {
                            onUpdateDashPattern([8, 3, 2, 3]) // Chain pattern
                        }
                        .buttonStyle(.borderless)
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(strokeDashPattern == [8, 3, 2, 3] ? Color.blue.opacity(0.2) : Color.clear)
                        .cornerRadius(3)
                        
                        Button("Double") {
                            onUpdateDashPattern([6, 2, 6, 8]) // Double dash
                        }
                        .buttonStyle(.borderless)
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(strokeDashPattern == [6, 2, 6, 8] ? Color.blue.opacity(0.2) : Color.clear)
                        .cornerRadius(3)
                    }
                    
                    HStack(spacing: 4) {
                        Button("Morse") {
                            onUpdateDashPattern([10, 3, 3, 3, 3, 3]) // Morse code style
                        }
                        .buttonStyle(.borderless)
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(strokeDashPattern == [10, 3, 3, 3, 3, 3] ? Color.blue.opacity(0.2) : Color.clear)
                        .cornerRadius(3)
                        
                        Spacer()
                    }
                }
            }
            
            HStack {
                Spacer()
                
                Button("Apply Stroke") {
                    onApplyStroke()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
    }
}

struct PresetStylesSection: View {
    let onApplyPreset: (StylePreset) -> Void
    
    private let presets = StylePreset.defaults
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preset Styles")
                .font(.headline)
                .fontWeight(.medium)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(presets.indices, id: \.self) { index in
                    PresetStyleButton(
                        preset: presets[index],
                        onApply: { onApplyPreset(presets[index]) }
                    )
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
    }
}

struct PresetStyleButton: View {
    let preset: StylePreset
    let onApply: () -> Void
    
    var body: some View {
        Button(action: onApply) {
            VStack(spacing: 4) {
                // Preview
                Circle()
                    .fill(preset.fillStyle?.color.color ?? Color.clear)
                    .stroke(
                        preset.strokeStyle?.color.color ?? Color.clear,
                        lineWidth: (preset.strokeStyle?.width ?? 0) / 2
                    )
                    .frame(width: 30, height: 30)
                
                Text(preset.name)
                    .font(.caption2)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct GradientFillSection: View {
    @ObservedObject var document: VectorDocument
    @Environment(AppState.self) private var appState
    @State private var gradientType: GradientType = .linear
    @State private var currentGradient: VectorGradient? = nil
    @State private var gradientId: UUID = UUID() // Unique ID for this gradient editing session
    
    enum GradientType: String, CaseIterable {
        case linear = "Linear"
        case radial = "Radial"
    }
    
    init(document: VectorDocument) {
        self.document = document
        
        // Initialize with existing gradient if selected shape has one
        if let selectedGradient = Self.getSelectedShapeGradient(document: document) {
            _currentGradient = State(initialValue: selectedGradient)
            switch selectedGradient {
            case .linear(_):
                _gradientType = State(initialValue: .linear)
            case .radial(_):
                _gradientType = State(initialValue: .radial)
            }
        } else {
            // Create default gradient
            _currentGradient = State(initialValue: Self.createDefaultGradient(type: .linear))
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Gradient Fill")
                .font(.headline)
                .fontWeight(.medium)
            
            // Gradient Type Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Type")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("Gradient Type", selection: $gradientType) {
                    ForEach(GradientType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: gradientType) { oldValue, newValue in
                    if oldValue != newValue {
                        // Preserve existing color stops when switching gradient types
                        if let existingGradient = currentGradient {
                            let existingStops = getGradientStops(existingGradient)
                            currentGradient = Self.createGradientWithStops(type: newValue, stops: existingStops)
                        } else {
                            currentGradient = Self.createDefaultGradient(type: newValue)
                        }
                        gradientId = UUID() // Generate new ID for new gradient
                    }
                }
            }
            
            // Gradient Angle (for Linear gradients only)
            if gradientType == .linear, let gradient = currentGradient, case .linear(let linear) = gradient {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Angle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(linear.angle))°")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: Binding(
                        get: { linear.angle },
                        set: { newAngle in
                            updateGradientAngle(newAngle)
                        }
                    ), in: -360...360)
                    .controlSize(.small)
                    .disabled(false) // NEVER disable the angle slider
                }
            }
            
            // Gradient Preview
            if let gradient = currentGradient {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preview")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Gradient preview strip
                    RoundedRectangle(cornerRadius: 4)
                        .fill(createSwiftUIGradient(from: gradient))
                        .frame(height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                
                // Color Stops Editor
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Color Stops")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(action: addColorStop) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Add Color Stop")
                    }
                    
                    // Color stops list - AUTO REORDER by position (0% to 100%)
                    let stops = getGradientStops(gradient).sorted { $0.position < $1.position }
                    ForEach(stops, id: \.id) { stop in
                        HStack(spacing: 8) {
                            // Color swatch
                            Button(action: {
                                // Use AppState to start gradient editing and switch to color panel
                                appState.startGradientStopEditing(
                                    gradientId: gradientId,
                                    stopIndex: 0 // Not used anymore, but keeping for compatibility
                                ) { selectedColor in
                                    updateStopColor(stopId: stop.id, color: selectedColor)
                                    appState.finishGradientStopEditing()
                                }
                            }) {
                                renderColorSwatchRightPanel(stop.color, width: 20, height: 20, cornerRadius: 4, borderWidth: 1, opacity: stop.opacity)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Position slider - moves independently
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Position: \(Int(stop.position * 100))%")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Slider(value: Binding(
                                    get: { stop.position },
                                    set: { newPosition in
                                        updateStopPosition(stopId: stop.id, position: newPosition)
                                    }
                                ), in: 0...1)
                                .controlSize(.small)
                            }
                            
                            // Delete button (if more than 2 stops)
                            if stops.count > 2 {
                                Button(action: {
                                    removeColorStop(stopId: stop.id)
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .help("Remove Color Stop")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            // Apply Gradient Button
            HStack {
                Spacer()
                Button("Apply Gradient") {
                    applyGradientToSelectedShapes()
                }
                .buttonStyle(.borderedProminent)
                .disabled(currentGradient == nil)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .onChange(of: document.selectedShapeIDs) { oldIDs, newIDs in
            // Update gradient editor when selection changes
            updateSelectedGradient()
        }
        .onChange(of: document.selectedLayerIndex) { oldIndex, newIndex in
            // Update gradient editor when layer changes
            updateSelectedGradient()
        }
    }
    
    // MARK: - Selection and Angle Management
    
    private func updateSelectedGradient() {
        if let selectedGradient = Self.getSelectedShapeGradient(document: document) {
            currentGradient = selectedGradient
            switch selectedGradient {
            case .linear(_):
                gradientType = .linear
            case .radial(_):
                gradientType = .radial
            }
            gradientId = UUID() // Generate new ID for loaded gradient
            print("🎨 Loaded gradient from selected object: \(selectedGradient)")
        }
    }
    
    private func updateGradientAngle(_ newAngle: Double) {
        guard var gradient = currentGradient else { return }
        
        switch gradient {
        case .linear(var linear):
            linear.angle = newAngle
            currentGradient = .linear(linear)
            print("🔄 Updated gradient angle to \(Int(newAngle))°")
        case .radial(_):
            // Radial gradients don't have angles
            break
        }
    }
    
    // MARK: - Helper Functions
    
    private func createSwiftUIGradient(from vectorGradient: VectorGradient) -> AnyShapeStyle {
        let stops = getGradientStops(vectorGradient)
        let gradientStops = stops.map { stop in
            SwiftUI.Gradient.Stop(color: stop.color.color.opacity(stop.opacity), location: stop.position)
        }
        let gradient = SwiftUI.Gradient(stops: gradientStops)
        
        switch vectorGradient {
        case .linear(_):
            return AnyShapeStyle(SwiftUI.LinearGradient(gradient: gradient, startPoint: .leading, endPoint: .trailing))
        case .radial(_):
            return AnyShapeStyle(SwiftUI.RadialGradient(gradient: gradient, center: .center, startRadius: 0, endRadius: 50))
        }
    }
    
    private func getGradientStops(_ gradient: VectorGradient) -> [GradientStop] {
        switch gradient {
        case .linear(let linear):
            return linear.stops
        case .radial(let radial):
            return radial.stops
        }
    }
    
    private func updateStopPosition(stopId: UUID, position: Double) {
        guard var gradient = currentGradient else { return }
        
        switch gradient {
        case .linear(var linear):
            if let index = linear.stops.firstIndex(where: { $0.id == stopId }) {
                linear.stops[index].position = position
                // AUTO SORT after position change to maintain visual order
                linear.stops.sort { $0.position < $1.position }
                currentGradient = .linear(linear)
            }
        case .radial(var radial):
            if let index = radial.stops.firstIndex(where: { $0.id == stopId }) {
                radial.stops[index].position = position
                // AUTO SORT after position change to maintain visual order
                radial.stops.sort { $0.position < $1.position }
                currentGradient = .radial(radial)
            }
        }
    }
    
    private func updateStopColor(stopId: UUID, color: VectorColor) {
        guard var gradient = currentGradient else { return }
        
        switch gradient {
        case .linear(var linear):
            if let index = linear.stops.firstIndex(where: { $0.id == stopId }) {
                linear.stops[index].color = color
                currentGradient = .linear(linear)
            }
        case .radial(var radial):
            if let index = radial.stops.firstIndex(where: { $0.id == stopId }) {
                radial.stops[index].color = color
                currentGradient = .radial(radial)
            }
        }
    }
    
    private func addColorStop() {
        guard var gradient = currentGradient else { return }
        
        // Find a good position for the new stop - between the last two stops
        let stops = getGradientStops(gradient)
        let newPosition = stops.count > 1 ? (stops[stops.count-2].position + stops[stops.count-1].position) / 2 : 0.5
        let newStop = GradientStop(position: newPosition, color: .black, opacity: 1.0)
        
        switch gradient {
        case .linear(var linear):
            linear.stops.append(newStop)
            // AUTO SORT after adding new stop to maintain position order
            linear.stops.sort { $0.position < $1.position }
            currentGradient = .linear(linear)
        case .radial(var radial):
            radial.stops.append(newStop)
            // AUTO SORT after adding new stop to maintain position order
            radial.stops.sort { $0.position < $1.position }
            currentGradient = .radial(radial)
        }
    }
    
    private func removeColorStop(stopId: UUID) {
        guard var gradient = currentGradient else { return }
        
        switch gradient {
        case .linear(var linear):
            guard linear.stops.count > 2 else { return }
            if let index = linear.stops.firstIndex(where: { $0.id == stopId }) {
                linear.stops.remove(at: index)
                currentGradient = .linear(linear)
            }
        case .radial(var radial):
            guard radial.stops.count > 2 else { return }
            if let index = radial.stops.firstIndex(where: { $0.id == stopId }) {
                radial.stops.remove(at: index)
                currentGradient = .radial(radial)
            }
        }
    }
    
    private func applyGradientToSelectedShapes() {
        guard let gradient = currentGradient,
              let layerIndex = document.selectedLayerIndex,
              !document.selectedShapeIDs.isEmpty else { return }
        
        document.saveToUndoStack()
        
        for shapeID in document.selectedShapeIDs {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                document.layers[layerIndex].shapes[shapeIndex].fillStyle = FillStyle(gradient: gradient, opacity: 1.0)
            }
        }
    }
    
    // MARK: - Static Helper Functions
    
    static func getSelectedShapeGradient(document: VectorDocument) -> VectorGradient? {
        guard let layerIndex = document.selectedLayerIndex,
              let firstSelectedID = document.selectedShapeIDs.first,
              let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }),
              let fillStyle = shape.fillStyle,
              case .gradient(let gradient) = fillStyle.color else {
            return nil
        }
        return gradient
    }
    
    static func createDefaultGradient(type: GradientType) -> VectorGradient {
        let stops = [
            GradientStop(position: 0.0, color: .black, opacity: 1.0),
            GradientStop(position: 1.0, color: .white, opacity: 1.0)
        ]
        
        return createGradientWithStops(type: type, stops: stops)
    }
    
    static func createGradientWithStops(type: GradientType, stops: [GradientStop]) -> VectorGradient {
        // Ensure we have at least 2 stops for a valid gradient
        let validStops = stops.isEmpty ? [
            GradientStop(position: 0.0, color: .black, opacity: 1.0),
            GradientStop(position: 1.0, color: .white, opacity: 1.0)
        ] : stops
        
        switch type {
        case .linear:
            let linear = LinearGradient(
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 1, y: 0),
                stops: validStops,
                spreadMethod: .pad,
                units: .objectBoundingBox
            )
            return .linear(linear)
        case .radial:
            let radial = RadialGradient(
                centerPoint: CGPoint(x: 0.5, y: 0.5),
                radius: 0.5,
                stops: validStops,
                focalPoint: nil,
                spreadMethod: .pad,
                units: .objectBoundingBox
            )
            return .radial(radial)
        }
    }
}

// REMOVED: ColorPickerSheet - replaced with ColorPickerModal from RightPanel
/*
struct ColorPickerSheet: View {
    let selectedColor: VectorColor
    @ObservedObject var document: VectorDocument
    let title: String
    let onColorChanged: (VectorColor) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    @State private var rgbColor = Color.black
    @State private var colorMode: ColorMode = .rgb
    @State private var cyanValue: String = "0"
    @State private var magentaValue: String = "0"
    @State private var yellowValue: String = "0"
    @State private var blackValue: String = "0"
    @State private var cmykPreview: CMYKColor = CMYKColor(cyan: 0, magenta: 0, yellow: 0, black: 0)
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Color Input Section
                if colorMode == .cmyk {
                    // CMYK Input
                    VStack(spacing: 12) {
                        Text("CMYK Process Color Input")
                            .font(.headline)
                        
                        Text("Enter values from 0-100%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // CMYK Input Grid
                        HStack(spacing: 12) {
                            VStack(spacing: 8) {
                                CMYKInputField(label: "C", value: $cyanValue, color: .cyan, onChange: updateCMYKPreview)
                                CMYKInputField(label: "M", value: $magentaValue, color: .pink, onChange: updateCMYKPreview)
                            }
                            
                            VStack(spacing: 8) {
                                CMYKInputField(label: "Y", value: $yellowValue, color: .yellow, onChange: updateCMYKPreview)
                                CMYKInputField(label: "K", value: $blackValue, color: .black, onChange: updateCMYKPreview)
                            }
                        }
                        
                        // CMYK Color Preview
                        HStack {
                            Rectangle()
                                .fill(cmykPreview.color)
                                .frame(width: 80, height: 40)
                                .overlay(
                                    Rectangle()
                                        .stroke(Color.gray, lineWidth: 1)
                                )
                                .cornerRadius(6)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("CMYK(\(Int((cmykPreview.cyan * 100).isFinite ? cmykPreview.cyan * 100 : 0)), \(Int((cmykPreview.magenta * 100).isFinite ? cmykPreview.magenta * 100 : 0)), \(Int((cmykPreview.yellow * 100).isFinite ? cmykPreview.yellow * 100 : 0)), \(Int((cmykPreview.black * 100).isFinite ? cmykPreview.black * 100 : 0)))")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                
                                let rgbEquivalent = cmykPreview.rgbColor
                                Text("RGB(\(Int(rgbEquivalent.red * 255)), \(Int(rgbEquivalent.green * 255)), \(Int(rgbEquivalent.blue * 255)))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .frame(height: 200)
                } else {
                    // RGB Color Picker
                    ColorPicker("Color", selection: $rgbColor)
                        .labelsHidden()
                        .scaleEffect(2.0)
                        .frame(height: 200)
                }
                
                // Color Mode
                Picker("Mode", selection: $colorMode) {
                    ForEach(ColorMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: colorMode) { oldValue, newValue in
                    // Convert current color when switching modes
                    if newValue == .cmyk && oldValue != .cmyk {
                        let cmyk = ColorManagement.rgbToCMYK(RGBColor(
                            red: rgbColor.components.red,
                            green: rgbColor.components.green,
                            blue: rgbColor.components.blue,
                            alpha: rgbColor.components.alpha
                        ))
                        cyanValue = String(Int((cmyk.cyan * 100).isFinite ? cmyk.cyan * 100 : 0))
                        magentaValue = String(Int((cmyk.magenta * 100).isFinite ? cmyk.magenta * 100 : 0))
                        yellowValue = String(Int((cmyk.yellow * 100).isFinite ? cmyk.yellow * 100 : 0))
                        blackValue = String(Int((cmyk.black * 100).isFinite ? cmyk.black * 100 : 0))
                        updateCMYKPreview()
                    }
                }
                
                // Current Swatches
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(40)), count: 6), spacing: 8) {
                    ForEach(Array(document.colorSwatches.enumerated()), id: \.offset) { index, color in
                        Button {
                            onColorChanged(color)
                            rgbColor = color.color
                            // Update CMYK values if switching to CMYK mode
                            if colorMode == .cmyk, case .cmyk(let cmyk) = color {
                                cyanValue = String(Int((cmyk.cyan * 100).isFinite ? cmyk.cyan * 100 : 0))
                                magentaValue = String(Int((cmyk.magenta * 100).isFinite ? cmyk.magenta * 100 : 0))
                                yellowValue = String(Int((cmyk.yellow * 100).isFinite ? cmyk.yellow * 100 : 0))
                                blackValue = String(Int((cmyk.black * 100).isFinite ? cmyk.black * 100 : 0))
                                updateCMYKPreview()
                            }
                        } label: {
                            Rectangle()
                                .fill(color.color)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Rectangle()
                                        .stroke(selectedColor == color ? Color.blue : Color.gray, lineWidth: selectedColor == color ? 2 : 1)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let newColor: VectorColor
                        
                        if colorMode == .cmyk {
                            newColor = VectorColor.cmyk(cmykPreview)
                        } else {
                            let components = rgbColor.components
                            newColor = VectorColor.rgb(RGBColor(
                                red: components.red,
                                green: components.green,
                                blue: components.blue,
                                alpha: components.alpha
                            ))
                        }
                        
                        onColorChanged(newColor)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .frame(width: 450, height: 550)
        .onAppear {
            colorMode = document.settings.colorMode
            rgbColor = selectedColor.color
            
            // Initialize CMYK values if appropriate
            if case .cmyk(let cmyk) = selectedColor {
                cyanValue = String(Int((cmyk.cyan * 100).isFinite ? cmyk.cyan * 100 : 0))
                magentaValue = String(Int((cmyk.magenta * 100).isFinite ? cmyk.magenta * 100 : 0))
                yellowValue = String(Int((cmyk.yellow * 100).isFinite ? cmyk.yellow * 100 : 0))
                blackValue = String(Int((cmyk.black * 100).isFinite ? cmyk.black * 100 : 0))
                updateCMYKPreview()
            }
        }
    }
    
    private func updateCMYKPreview() {
        let c = (Double(cyanValue) ?? 0) / 100.0
        let m = (Double(magentaValue) ?? 0) / 100.0
        let y = (Double(yellowValue) ?? 0) / 100.0
        let k = (Double(blackValue) ?? 0) / 100.0
        
        cmykPreview = CMYKColor(
            cyan: max(0, min(1, c)),
            magenta: max(0, min(1, m)),
            yellow: max(0, min(1, y)),
            black: max(0, min(1, k))
        )
    }
}
*/

// Style Presets
struct StylePreset {
    let name: String
    let strokeStyle: StrokeStyle?
    let fillStyle: FillStyle?
    
    static let defaults: [StylePreset] = [
        StylePreset(
            name: "None",
            strokeStyle: nil,
            fillStyle: nil
        ),
        StylePreset(
            name: "Black Fill",
            strokeStyle: nil,
            fillStyle: FillStyle(color: .black)
        ),
        StylePreset(
            name: "White Fill",
            strokeStyle: nil,
            fillStyle: FillStyle(color: .white)
        ),
        StylePreset(
            name: "Black Stroke",
            strokeStyle: StrokeStyle(color: .black, width: 1, opacity: 1.0),
            fillStyle: nil
        ),
        StylePreset(
            name: "Thick Stroke",
            strokeStyle: StrokeStyle(color: .black, width: 3, opacity: 1.0),
            fillStyle: nil
        ),
        StylePreset(
            name: "Dashed",
            strokeStyle: StrokeStyle(color: .black, width: 1, dashPattern: [5, 5], opacity: 1.0),
            fillStyle: nil
        ),
        StylePreset(
            name: "Dotted",
            strokeStyle: StrokeStyle(color: .black, width: 1, dashPattern: [1, 3], opacity: 1.0),
            fillStyle: nil
        ),
        StylePreset(
            name: "Long Dash",
            strokeStyle: StrokeStyle(color: .black, width: 1, dashPattern: [10, 5], opacity: 1.0),
            fillStyle: nil
        ),
        StylePreset(
            name: "Chain",
            strokeStyle: StrokeStyle(color: .black, width: 1, dashPattern: [8, 3, 2, 3], opacity: 1.0),
            fillStyle: nil
        ),
        StylePreset(
            name: "Double Dash",
            strokeStyle: StrokeStyle(color: .black, width: 1, dashPattern: [6, 2, 6, 8], opacity: 1.0),
            fillStyle: nil
        ),
        StylePreset(
            name: "Red Fill",
            strokeStyle: nil,
            fillStyle: FillStyle(color: .rgb(RGBColor(red: 1, green: 0, blue: 0)))
        ),
        StylePreset(
            name: "Blue Fill",
            strokeStyle: nil,
            fillStyle: FillStyle(color: .rgb(RGBColor(red: 0, green: 0, blue: 1)))
        ),
        StylePreset(
            name: "Green Fill",
            strokeStyle: nil,
            fillStyle: FillStyle(color: .rgb(RGBColor(red: 0, green: 1, blue: 0)))
        )
    ]
}



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
        case .miter: return "Sharp pointed corners (Adobe Illustrator default)"
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

// MARK: - Clear Color Rendering
// Note: ClearColorView removed - using renderColorSwatchRightPanel for consistency

// MARK: - Color Rendering Helper
// Note: Using renderColorSwatchRightPanel from RightPanel.swift for consistency

// Preview
struct StrokeFillPanel_Previews: PreviewProvider {
    static var previews: some View {
        StrokeFillPanel(document: VectorDocument())
            .frame(width: 300, height: 600)
    }
}
