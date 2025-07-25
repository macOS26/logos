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
    
    // NEW: State for gradient color stop popup
    @State private var showingGradientColorPicker = false
    @State private var editingGradientStopId: UUID?
    @State private var editingGradientStopColor: VectorColor = .black
    
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
    
    // NEW: State for gradient color stop popup
    @State private var showingGradientColorPicker = false
    @State private var editingGradientStopId: UUID?
    @State private var editingGradientStopColor: VectorColor = .black
    
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
                        // Apply live to selected shapes
                        applyGradientToSelectedShapes()
                    }
                }
            }
            
            // Gradient Angle (for Linear gradients only) - 0-360° NO CONSTRAINTS
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
                    ), in: -180...180, onEditingChanged: { editing in
                        if !editing {
                            // Save to undo stack when slider editing ends
                            document.saveToUndoStack()
                        }
                    })
                    .controlSize(.small)
                }
            }
            
            // NEW: Origin Point Control (for positioning gradient)
            if currentGradient != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Origin Point")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("X: \(currentGradient != nil ? Int(getGradientOriginX(currentGradient!) * 100) : 0)%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Slider(value: Binding(
                                get: { 
                                    guard let current = currentGradient else { return 0.0 }
                                    return getGradientOriginX(current) 
                                },
                                set: { newX in
                                    updateGradientOriginX(newX)
                                }
                            ), in: -2.0...2.0, onEditingChanged: { editing in
                                if !editing {
                                    // Save to undo stack when slider editing ends
                                    document.saveToUndoStack()
                                }
                            })
                            .controlSize(.small)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Y: \(currentGradient != nil ? Int(getGradientOriginY(currentGradient!) * 100) : 0)%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Slider(value: Binding(
                                get: { 
                                    guard let current = currentGradient else { return 0.0 }
                                    return getGradientOriginY(current) 
                                },
                                set: { newY in
                                    updateGradientOriginY(newY)
                                }
                            ), in: -2.0...2.0, onEditingChanged: { editing in
                                if !editing {
                                    // Save to undo stack when slider editing ends
                                    document.saveToUndoStack()
                                }
                            })
                            .controlSize(.small)
                        }
                    }
                }
            }
            
            // NEW: Scale Control (-200% to 200%)
            if currentGradient != nil {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Scale")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(currentGradient != nil ? Int(getGradientScale(currentGradient!) * 100) : 0)%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: Binding(
                        get: { 
                            guard let current = currentGradient else { return 1.0 }
                            return getGradientScale(current) 
                        },
                        set: { newScale in
                            updateGradientScale(newScale)
                        }
                    ), in: -2.0...2.0, onEditingChanged: { editing in
                        if !editing {
                            // Save to undo stack when slider editing ends
                            document.saveToUndoStack()
                        }
                    })
                    .controlSize(.small)
                }
            }
            
            // NEW: Radial Gradient Angle Control (-180° to 180°)
            if case .radial = currentGradient {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Angle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(currentGradient != nil ? String(format: "%.2f", getRadialGradientAngle(currentGradient!)) : "0.00")°")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: Binding(
                        get: { 
                            guard let current = currentGradient else { return 0.0 }
                            return getRadialGradientAngle(current) 
                        },
                        set: { newAngle in
                            updateRadialGradientAngle(newAngle)
                        }
                    ), in: -180.0...180.0, onEditingChanged: { editing in
                        if !editing {
                            // Save to undo stack when slider editing ends
                            document.saveToUndoStack()
                        }
                    })
                    .controlSize(.small)
                }
            }
            
            // NEW: Radial Gradient Aspect Ratio Control (-200% to 200%)
            if case .radial = currentGradient {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Aspect Ratio")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(currentGradient != nil ? String(format: "%.4f", getRadialGradientAspectRatio(currentGradient!) * 100) : "100.0000")%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: Binding(
                        get: { 
                            guard let current = currentGradient else { return 1.0 }
                            return getRadialGradientAspectRatio(current) 
                        },
                        set: { newRatio in
                            updateRadialGradientAspectRatio(newRatio)
                        }
                    ), in: -2.0...2.0, onEditingChanged: { editing in
                        if !editing {
                            // Save to undo stack when slider editing ends
                            document.saveToUndoStack()
                        }
                    })
                    .controlSize(.small)
                }
            }
            
            // Gradient Preview with Interactive Origin Point
            if currentGradient != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preview")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Enhanced gradient preview with origin point control
                    GeometryReader { geometry in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(createSwiftUIGradient(from: currentGradient!))
                            .frame(height: 60)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .onTapGesture { location in
                                // Save to undo stack before making changes
                                document.saveToUndoStack()
                                // Move origin point to clicked location
                                let newX = max(0, min(1, location.x / geometry.size.width))
                                let newY = max(0, min(1, location.y / 60))
                                updateGradientOriginX(newX)
                                updateGradientOriginY(newY)
                            }
                            .overlay(
                                // Origin point indicator (draggable)
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 8, height: 8)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.black, lineWidth: 1)
                                    )
                                    .position(
                                        x: currentGradient != nil ? getGradientOriginX(currentGradient!) * geometry.size.width : 0,
                                        y: currentGradient != nil ? getGradientOriginY(currentGradient!) * 60 : 0
                                    )
                                    .gesture(
                                        DragGesture()
                                            .onChanged { value in
                                                let newX = max(0, min(1, value.location.x / geometry.size.width))
                                                let newY = max(0, min(1, value.location.y / 60))
                                                updateGradientOriginX(newX)
                                                updateGradientOriginY(newY)
                                            }
                                            .onEnded { _ in
                                                // Save to undo stack on mouse up
                                                document.saveToUndoStack()
                                            }
                                    )
                            )
                    }
                    .frame(height: 60)
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
                    let stops = currentGradient != nil ? getGradientStops(currentGradient!).sorted { $0.position < $1.position } : []
                    ForEach(stops, id: \.id) { stop in
                        HStack(spacing: 8) {
                            // Color swatch - OPENS COLOR PANEL AS POPUP!
                            Button(action: {
                                // SET UP FOR POPUP COLOR PICKER
                                editingGradientStopId = stop.id
                                editingGradientStopColor = stop.color
                                showingGradientColorPicker = true
                            }) {
                                renderColorSwatchRightPanel(stop.color, width: 20, height: 20, cornerRadius: 4, borderWidth: 1, opacity: stop.opacity)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help("Click to change color")
                            
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
        // GRADIENT COLOR POPUP - Uses ColorPanel as a SHEET!
        .sheet(isPresented: $showingGradientColorPicker) {
            VStack(spacing: 0) {
                // Title bar
                HStack {
                    Text("Select Gradient Color")
                        .font(.headline)
                    Spacer()
                    Button("Done") {
                        showingGradientColorPicker = false
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color(NSColor.windowBackgroundColor))
                
                // COLOR PANEL WITH RGB/CMYK/HSB TABS
                ColorPanel(
                    document: document,
                    onColorSelected: { newColor in
                        // Update the gradient stop color in real-time
                        if let stopId = editingGradientStopId {
                            updateStopColor(stopId: stopId, color: newColor)
                        }
                        editingGradientStopColor = newColor
                    }
                )
                .frame(width: 300, height: 400)
            }
            .frame(width: 300, height: 450)
            .background(Color(NSColor.windowBackgroundColor))
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
        guard let gradient = currentGradient else { return }
        
        switch gradient {
        case .linear(var linear):
            linear.angle = newAngle
            currentGradient = .linear(linear)
            print("🔄 Updated gradient angle to \(Int(newAngle))°")
            // Apply live to selected shapes
            applyGradientToSelectedShapes()
        case .radial(_):
            // Radial gradients don't have angles
            break
        }
    }
    
    // NEW: Origin Point Controls
    private func getGradientOriginX(_ gradient: VectorGradient) -> Double {
        switch gradient {
        case .linear(let linear):
            return linear.originPoint.x
        case .radial(let radial):
            return radial.originPoint.x
        }
    }
    
    private func getGradientOriginY(_ gradient: VectorGradient) -> Double {
        switch gradient {
        case .linear(let linear):
            return linear.originPoint.y
        case .radial(let radial):
            return radial.originPoint.y
        }
    }
    
    private func updateGradientOriginX(_ newX: Double) {
        guard let gradient = currentGradient else { return }
        
        switch gradient {
        case .linear(var linear):
            linear.originPoint.x = newX
            currentGradient = .linear(linear)
            print("🔄 Updated gradient origin X to \(Int(newX * 100))%")
        case .radial(var radial):
            radial.originPoint.x = newX
            currentGradient = .radial(radial)
            print("🔄 Updated gradient origin X to \(Int(newX * 100))%")
        }
        // Apply live to selected shapes
        applyGradientToSelectedShapes()
    }
    
    private func updateGradientOriginY(_ newY: Double) {
        guard let gradient = currentGradient else { return }
        
        switch gradient {
        case .linear(var linear):
            linear.originPoint.y = newY
            currentGradient = .linear(linear)
            print("🔄 Updated gradient origin Y to \(Int(newY * 100))%")
        case .radial(var radial):
            radial.originPoint.y = newY
            currentGradient = .radial(radial)
            print("🔄 Updated gradient origin Y to \(Int(newY * 100))%")
        }
        // Apply live to selected shapes
        applyGradientToSelectedShapes()
    }
    
    // NEW: Scale Control
    private func getGradientScale(_ gradient: VectorGradient) -> Double {
        switch gradient {
        case .linear(let linear):
            return linear.scale
        case .radial(let radial):
            return radial.scale
        }
    }
    
    private func updateGradientScale(_ newScale: Double) {
        guard let gradient = currentGradient else { return }
        
        switch gradient {
        case .linear(var linear):
            linear.scale = newScale
            currentGradient = .linear(linear)
            print("🔄 Updated gradient scale to \(Int(newScale * 100))%")
        case .radial(var radial):
            radial.scale = newScale
            currentGradient = .radial(radial)
            print("🔄 Updated gradient scale to \(Int(newScale * 100))%")
        }
        // Apply live to selected shapes
        applyGradientToSelectedShapes()
    }
    
    // NEW: Radial Gradient Angle Control
    private func getRadialGradientAngle(_ gradient: VectorGradient) -> Double {
        switch gradient {
        case .linear(_):
            return 0.0
        case .radial(let radial):
            return radial.angle
        }
    }
    
    private func updateRadialGradientAngle(_ newAngle: Double) {
        guard let gradient = currentGradient else { return }
        
        switch gradient {
        case .linear(_):
            // Linear gradients use different angle logic
            break
        case .radial(var radial):
            radial.angle = newAngle
            currentGradient = .radial(radial)
            print("🔄 Updated radial gradient angle to \(String(format: "%.2f", newAngle))°")
        }
        // Apply live to selected shapes
        applyGradientToSelectedShapes()
    }
    
    // NEW: Radial Gradient Aspect Ratio Control
    private func getRadialGradientAspectRatio(_ gradient: VectorGradient) -> Double {
        switch gradient {
        case .linear(_):
            return 1.0
        case .radial(let radial):
            return radial.aspectRatio
        }
    }
    
    private func updateRadialGradientAspectRatio(_ newRatio: Double) {
        guard let gradient = currentGradient else { return }
        
        switch gradient {
        case .linear(_):
            // Linear gradients don't have aspect ratios
            break
        case .radial(var radial):
            radial.aspectRatio = newRatio
            currentGradient = .radial(radial)
            print("🔄 Updated radial gradient aspect ratio to \(String(format: "%.4f", newRatio * 100))%")
        }
        // Apply live to selected shapes
        applyGradientToSelectedShapes()
    }
    
    // MARK: - Helper Functions
    
    private func createSwiftUIGradient(from vectorGradient: VectorGradient) -> AnyShapeStyle {
        let stops = getGradientStops(vectorGradient)
        let gradientStops = stops.map { stop in
            SwiftUI.Gradient.Stop(color: stop.color.color.opacity(stop.opacity), location: stop.position)
        }
        let gradient = SwiftUI.Gradient(stops: gradientStops)
        
        switch vectorGradient {
        case .linear(let linear):
            // Apply origin point offset
            let originOffsetX = linear.originPoint.x - 0.5
            let originOffsetY = linear.originPoint.y - 0.5
            
            // Calculate adjusted start and end points
            let adjustedStartX = linear.startPoint.x + originOffsetX
            let adjustedStartY = linear.startPoint.y + originOffsetY
            let adjustedEndX = linear.endPoint.x + originOffsetX
            let adjustedEndY = linear.endPoint.y + originOffsetY
            
            // Apply scale
            let centerX = (adjustedStartX + adjustedEndX) / 2
            let centerY = (adjustedStartY + adjustedEndY) / 2
            let scaledStartX = centerX + (adjustedStartX - centerX) * CGFloat(linear.scale)
            let scaledStartY = centerY + (adjustedStartY - centerY) * CGFloat(linear.scale)
            let scaledEndX = centerX + (adjustedEndX - centerX) * CGFloat(linear.scale)
            let scaledEndY = centerY + (adjustedEndY - centerY) * CGFloat(linear.scale)
            
            // Convert to SwiftUI UnitPoint
            let startPoint = UnitPoint(x: scaledStartX, y: scaledStartY)
            let endPoint = UnitPoint(x: scaledEndX, y: scaledEndY)
            
            return AnyShapeStyle(SwiftUI.LinearGradient(gradient: gradient, startPoint: startPoint, endPoint: endPoint))
            
        case .radial(let radial):
            // Apply origin point offset
            let originOffsetX = radial.originPoint.x - 0.5
            let originOffsetY = radial.originPoint.y - 0.5
            
            // Calculate adjusted center
            let adjustedCenterX = radial.centerPoint.x + originOffsetX
            let adjustedCenterY = radial.centerPoint.y + originOffsetY
            let center = UnitPoint(x: adjustedCenterX, y: adjustedCenterY)
            
            // Scale affects the radius
            let scaledRadius = 50 * CGFloat(abs(radial.scale))
            
            return AnyShapeStyle(SwiftUI.RadialGradient(gradient: gradient, center: center, startRadius: 0, endRadius: scaledRadius))
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
        guard let gradient = currentGradient else { return }
        
        switch gradient {
        case .linear(var linear):
            if let index = linear.stops.firstIndex(where: { $0.id == stopId }) {
                linear.stops[index].position = position
                // AUTO SORT after position change to maintain visual order
                linear.stops.sort { $0.position < $1.position }
                currentGradient = .linear(linear)
                // Apply live to selected shapes
                applyGradientToSelectedShapes()
            }
        case .radial(var radial):
            if let index = radial.stops.firstIndex(where: { $0.id == stopId }) {
                radial.stops[index].position = position
                // AUTO SORT after position change to maintain visual order
                radial.stops.sort { $0.position < $1.position }
                currentGradient = .radial(radial)
                // Apply live to selected shapes
                applyGradientToSelectedShapes()
            }
        }
    }
    
    private func updateStopColor(stopId: UUID, color: VectorColor) {
        guard let gradient = currentGradient else { return }
        
        switch gradient {
        case .linear(var linear):
            if let index = linear.stops.firstIndex(where: { $0.id == stopId }) {
                linear.stops[index].color = color
                currentGradient = .linear(linear)
                // Apply live to selected shapes
                applyGradientToSelectedShapes()
            }
        case .radial(var radial):
            if let index = radial.stops.firstIndex(where: { $0.id == stopId }) {
                radial.stops[index].color = color
                currentGradient = .radial(radial)
                // Apply live to selected shapes
                applyGradientToSelectedShapes()
            }
        }
    }
    
    private func addColorStop() {
        guard let gradient = currentGradient else { return }
        
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
            // Apply live to selected shapes
            applyGradientToSelectedShapes()
        case .radial(var radial):
            radial.stops.append(newStop)
            // AUTO SORT after adding new stop to maintain position order
            radial.stops.sort { $0.position < $1.position }
            currentGradient = .radial(radial)
            // Apply live to selected shapes
            applyGradientToSelectedShapes()
        }
    }
    
    private func removeColorStop(stopId: UUID) {
        guard let gradient = currentGradient else { return }
        
        switch gradient {
        case .linear(var linear):
            guard linear.stops.count > 2 else { return }
            if let index = linear.stops.firstIndex(where: { $0.id == stopId }) {
                linear.stops.remove(at: index)
                currentGradient = .linear(linear)
                // Apply live to selected shapes
                applyGradientToSelectedShapes()
            }
        case .radial(var radial):
            guard radial.stops.count > 2 else { return }
            if let index = radial.stops.firstIndex(where: { $0.id == stopId }) {
                radial.stops.remove(at: index)
                currentGradient = .radial(radial)
                // Apply live to selected shapes
                applyGradientToSelectedShapes()
            }
        }
    }
    
    private func applyGradientToSelectedShapes() {
        guard let gradient = currentGradient,
              let layerIndex = document.selectedLayerIndex,
              !document.selectedShapeIDs.isEmpty else { return }
        
        // Note: Undo stack saving is now handled by individual controls on mouse up/editing end
        
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
