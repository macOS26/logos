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
    @State private var isProportionalScale = true
    
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
            
            GradientTypePickerView(
                gradientType: $gradientType,
                currentGradient: $currentGradient,
                gradientId: $gradientId,
                getGradientStops: getGradientStops,
                createGradientPreservingProperties: Self.createGradientPreservingProperties,
                createDefaultGradient: Self.createDefaultGradient,
                onGradientChange: applyGradientToSelectedShapes
            )
            
            GradientAngleControlView(
                gradientType: gradientType,
                currentGradient: currentGradient,
                document: document,
                onAngleChange: updateGradientAngle
            )
            
            GradientOriginControlView(
                currentGradient: currentGradient,
                document: document,
                getOriginX: getGradientOriginX,
                getOriginY: getGradientOriginY,
                updateOriginX: updateGradientOriginX,
                updateOriginY: updateGradientOriginY
            )
            
            GradientScaleControlView(
                currentGradient: currentGradient,
                isProportionalScale: $isProportionalScale,
                document: document,
                getScaleX: getGradientScaleX,
                getScaleY: getGradientScaleY,
                updateScaleX: updateGradientScaleX,
                updateScaleY: updateGradientScaleY
            )
            
            RadialGradientControlsView(
                currentGradient: currentGradient,
                document: document,
                getRadialAngle: getRadialGradientAngle,
                getRadialAspectRatio: getRadialGradientAspectRatio,
                updateRadialAngle: updateRadialGradientAngle,
                updateRadialAspectRatio: updateRadialGradientAspectRatio
            )
            
            GradientPreviewAndStopsView(
                currentGradient: currentGradient,
                document: document,
                editingGradientStopId: $editingGradientStopId,
                editingGradientStopColor: $editingGradientStopColor,
                showingGradientColorPicker: $showingGradientColorPicker,
                createGradient: createSwiftUIGradient,
                getGradientStops: getGradientStops,
                getOriginX: getGradientOriginX,
                getOriginY: getGradientOriginY,
                updateOriginX: updateGradientOriginX,
                updateOriginY: updateGradientOriginY,
                addColorStop: addColorStop,
                updateStopPosition: updateStopPosition,
                removeColorStop: removeColorStop
            )
            
            GradientApplyButtonView(
                currentGradient: currentGradient,
                onApply: applyGradientToSelectedShapes
            )
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .onChange(of: document.selectedShapeIDs) { _, _ in updateSelectedGradient() }
        .onChange(of: document.selectedLayerIndex) { _, _ in updateSelectedGradient() }
        .sheet(isPresented: $showingGradientColorPicker) {
            GradientColorPickerSheet(
                document: document,
                editingGradientStopId: editingGradientStopId,
                showingColorPicker: $showingGradientColorPicker,
                updateStopColor: updateStopColor
            )
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
    
    // NEW: Scale X & Y Controls
    private func getGradientScaleX(_ gradient: VectorGradient) -> Double {
        switch gradient {
        case .linear(let linear):
            return linear.scaleX ?? linear.scale ?? 1.0
        case .radial(let radial):
            return radial.scaleX ?? radial.scale ?? 1.0
        }
    }
    
    private func getGradientScaleY(_ gradient: VectorGradient) -> Double {
        switch gradient {
        case .linear(let linear):
            return linear.scaleY ?? linear.scale ?? 1.0
        case .radial(let radial):
            return radial.scaleY ?? radial.scale ?? 1.0
        }
    }
    
    private func updateGradientScaleX(_ newScaleX: Double) {
        guard let gradient = currentGradient else { return }
        
        switch gradient {
        case .linear(var linear):
            linear.scaleX = newScaleX
            currentGradient = .linear(linear)
            print("🔄 Updated gradient scale X to \(Int(newScaleX * 100))%")
        case .radial(var radial):
            radial.scaleX = newScaleX
            currentGradient = .radial(radial)
            print("🔄 Updated gradient scale X to \(Int(newScaleX * 100))%")
        }
        // Apply live to selected shapes
        applyGradientToSelectedShapes()
    }
    
    private func updateGradientScaleY(_ newScaleY: Double) {
        guard let gradient = currentGradient else { return }
        
        switch gradient {
        case .linear(var linear):
            linear.scaleY = newScaleY
            currentGradient = .linear(linear)
            print("🔄 Updated gradient scale Y to \(Int(newScaleY * 100))%")
        case .radial(var radial):
            radial.scaleY = newScaleY
            currentGradient = .radial(radial)
            print("🔄 Updated gradient scale Y to \(Int(newScaleY * 100))%")
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
    
    func createSwiftUIGradient(from vectorGradient: VectorGradient) -> AnyShapeStyle {
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
            
            // Apply truly independent X and Y scale
            let scaleX = linear.scaleX ?? linear.scale
            let scaleY = linear.scaleY ?? linear.scale
            
            // Calculate gradient vector
            let gradientVectorX = adjustedEndX - adjustedStartX
            let gradientVectorY = adjustedEndY - adjustedStartY
            
            // Apply independent scaling to the gradient vector components
            let scaledVectorX = gradientVectorX * CGFloat(scaleX)
            let scaledVectorY = gradientVectorY * CGFloat(scaleY)
            
            // Calculate center point
            let centerX = (adjustedStartX + adjustedEndX) / 2
            let centerY = (adjustedStartY + adjustedEndY) / 2
            
            // Create new start and end points from scaled vector
            let scaledStartX = centerX - scaledVectorX / 2
            let scaledStartY = centerY - scaledVectorY / 2
            let scaledEndX = centerX + scaledVectorX / 2
            let scaledEndY = centerY + scaledVectorY / 2
            
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
            
            // Apply independent X and Y scale to radius
            let scaleX = radial.scaleX ?? radial.scale
            let scaleY = radial.scaleY ?? radial.scale
            
            // For truly independent scaling, use the maximum scale for the base radius
            // This ensures the gradient fills the space properly with independent X/Y scaling
            let maxScale = max(abs(scaleX), abs(scaleY))
            let scaledRadius = 50 * CGFloat(maxScale)
            
            return AnyShapeStyle(SwiftUI.RadialGradient(gradient: gradient, center: center, startRadius: 0, endRadius: scaledRadius))
        }
    }
    
    func getGradientStops(_ gradient: VectorGradient) -> [GradientStop] {
        switch gradient {
        case .linear(let linear):
            return linear.stops
        case .radial(let radial):
            return radial.stops
        }
    }
    
    func updateStopPosition(stopId: UUID, position: Double) {
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
    
    func updateStopColor(stopId: UUID, color: VectorColor) {
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
    
    func addColorStop() {
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
    
    func removeColorStop(stopId: UUID) {
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
    
    func applyGradientToSelectedShapes() {
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
            var linear = LinearGradient(
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 1, y: 0),
                stops: validStops,
                spreadMethod: .pad,
                units: .objectBoundingBox
            )
            // Keep default originPoint for new gradients - will be preserved when switching types
            return .linear(linear)
        case .radial:
            var radial = RadialGradient(
                centerPoint: CGPoint(x: 0.5, y: 0.5),
                radius: 0.5,
                stops: validStops,
                focalPoint: nil,
                spreadMethod: .pad,
                units: .objectBoundingBox
            )
            // Keep default originPoint for new gradients - will be preserved when switching types
            return .radial(radial)
        }
    }
    
    // NEW: Create gradient while preserving properties from existing gradient
    static func createGradientPreservingProperties(type: GradientType, stops: [GradientStop], from existingGradient: VectorGradient) -> VectorGradient {
        // Ensure we have at least 2 stops for a valid gradient
        let validStops = stops.isEmpty ? [
            GradientStop(position: 0.0, color: .black, opacity: 1.0),
            GradientStop(position: 1.0, color: .white, opacity: 1.0)
        ] : stops
        
        switch type {
        case .linear:
            var linear = LinearGradient(
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 1, y: 0),
                stops: validStops,
                spreadMethod: .pad,
                units: .objectBoundingBox
            )
            
            // Preserve properties from existing gradient
            switch existingGradient {
            case .linear(let existingLinear):
                // Preserve all properties from existing linear gradient
                linear.originPoint = existingLinear.originPoint
                linear.scale = existingLinear.scale
                linear.scaleX = existingLinear.scaleX
                linear.scaleY = existingLinear.scaleY
                linear.units = existingLinear.units
                linear.spreadMethod = existingLinear.spreadMethod
            case .radial(let existingRadial):
                // Convert radial properties to linear where applicable
                linear.originPoint = existingRadial.originPoint
                linear.scale = existingRadial.scale
                linear.scaleX = existingRadial.scaleX
                linear.scaleY = existingRadial.scaleY
                linear.units = existingRadial.units
                linear.spreadMethod = existingRadial.spreadMethod
            }
            
            return .linear(linear)
            
        case .radial:
            // Start with smart defaults based on existing gradient
            let (centerPoint, radius, focalPoint) = {
                switch existingGradient {
                case .radial(let existingRadial):
                    return (existingRadial.centerPoint, existingRadial.radius, existingRadial.focalPoint)
                case .linear(_):
                    // Default values for conversion from linear
                    return (CGPoint(x: 0.5, y: 0.5), 0.5, nil as CGPoint?)
                }
            }()
            
            var radial = RadialGradient(
                centerPoint: centerPoint,
                radius: radius,
                stops: validStops,
                focalPoint: focalPoint,
                spreadMethod: .pad,
                units: .objectBoundingBox
            )
            
            // Preserve properties from existing gradient
            switch existingGradient {
            case .linear(let existingLinear):
                // Convert linear properties to radial where applicable
                radial.originPoint = existingLinear.originPoint
                radial.scale = existingLinear.scale
                radial.scaleX = existingLinear.scaleX
                radial.scaleY = existingLinear.scaleY
                radial.units = existingLinear.units
                radial.spreadMethod = existingLinear.spreadMethod
            case .radial(let existingRadial):
                // Preserve all properties from existing radial gradient
                radial.originPoint = existingRadial.originPoint
                radial.scale = existingRadial.scale
                radial.scaleX = existingRadial.scaleX
                radial.scaleY = existingRadial.scaleY
                radial.angle = existingRadial.angle
                radial.aspectRatio = existingRadial.aspectRatio
                radial.units = existingRadial.units
                radial.spreadMethod = existingRadial.spreadMethod
            }
            
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

// MARK: - Gradient Section Sub-Views

struct GradientTypePickerView: View {
    @Binding var gradientType: GradientFillSection.GradientType
    @Binding var currentGradient: VectorGradient?
    @Binding var gradientId: UUID
    let getGradientStops: (VectorGradient) -> [GradientStop]
    let createGradientPreservingProperties: (GradientFillSection.GradientType, [GradientStop], VectorGradient) -> VectorGradient
    let createDefaultGradient: (GradientFillSection.GradientType) -> VectorGradient
    let onGradientChange: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Type")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Picker("Gradient Type", selection: $gradientType) {
                ForEach(GradientFillSection.GradientType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: gradientType) { _, newValue in
                if let existingGradient = currentGradient {
                    let existingStops = getGradientStops(existingGradient)
                    currentGradient = createGradientPreservingProperties(newValue, existingStops, existingGradient)
                } else {
                    currentGradient = createDefaultGradient(newValue)
                }
                gradientId = UUID()
                onGradientChange()
            }
        }
    }
}

struct GradientAngleControlView: View {
    let gradientType: GradientFillSection.GradientType
    let currentGradient: VectorGradient?
    let document: VectorDocument
    let onAngleChange: (Double) -> Void
    
    var body: some View {
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
                    set: onAngleChange
                ), in: -180...180, onEditingChanged: { editing in
                    if !editing { document.saveToUndoStack() }
                })
                .controlSize(.small)
            }
        }
    }
}

struct GradientOriginControlView: View {
    let currentGradient: VectorGradient?
    let document: VectorDocument
    let getOriginX: (VectorGradient) -> Double
    let getOriginY: (VectorGradient) -> Double
    let updateOriginX: (Double) -> Void
    let updateOriginY: (Double) -> Void
    
    var body: some View {
        if currentGradient != nil {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Origin Point (Cartesian: 0,0 = center, -100% to +100%)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Clamped")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 4)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(3)
                }
                
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("X: \(currentGradient != nil ? Int((getOriginX(currentGradient!) - 0.5) * 200) : 0)%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Slider(value: Binding(
                            get: { currentGradient != nil ? getOriginX(currentGradient!) : 0.5 },
                            set: updateOriginX
                        ), in: 0.0...1.0, onEditingChanged: { editing in
                            if !editing { document.saveToUndoStack() }
                        })
                        .controlSize(.small)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Y: \(currentGradient != nil ? Int((getOriginY(currentGradient!) - 0.5) * 200) : 0)%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Slider(value: Binding(
                            get: { currentGradient != nil ? getOriginY(currentGradient!) : 0.5 },
                            set: updateOriginY
                        ), in: 0.0...1.0, onEditingChanged: { editing in
                            if !editing { document.saveToUndoStack() }
                        })
                        .controlSize(.small)
                    }
                }
            }
        }
    }
}

struct GradientScaleControlView: View {
    let currentGradient: VectorGradient?
    @Binding var isProportionalScale: Bool
    let document: VectorDocument
    let getScaleX: (VectorGradient) -> Double
    let getScaleY: (VectorGradient) -> Double
    let updateScaleX: (Double) -> Void
    let updateScaleY: (Double) -> Void
    
    var body: some View {
        if currentGradient != nil {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scale X: \(currentGradient != nil ? Int(getScaleX(currentGradient!) * 100) : 100)%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Slider(value: Binding(
                            get: { currentGradient != nil ? getScaleX(currentGradient!) : 1.0 },
                            set: { newScaleX in
                                if isProportionalScale {
                                    updateScaleX(newScaleX)
                                    updateScaleY(newScaleX)
                                } else {
                                    updateScaleX(newScaleX)
                                }
                            }
                        ), in: 0.01...8.0, onEditingChanged: { editing in
                            if !editing { document.saveToUndoStack() }
                        })
                        .controlSize(.small)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scale Y: \(currentGradient != nil ? Int(getScaleY(currentGradient!) * 100) : 100)%\(isProportionalScale ? " (Locked)" : "")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Slider(value: Binding(
                            get: { currentGradient != nil ? getScaleY(currentGradient!) : 1.0 },
                            set: { newScaleY in
                                if isProportionalScale {
                                    updateScaleX(newScaleY)
                                    updateScaleY(newScaleY)
                                } else {
                                    updateScaleY(newScaleY)
                                }
                            }
                        ), in: 0.01...8.0, onEditingChanged: { editing in
                            if !editing { document.saveToUndoStack() }
                        })
                        .controlSize(.small)
                        .disabled(isProportionalScale)
                        .opacity(isProportionalScale ? 0.5 : 1.0)
                    }
                    
                    VStack(alignment: .center, spacing: 2) {
                        Image(systemName: isProportionalScale ? "link" : "link.slash")
                            .font(.system(size: 12))
                            .foregroundColor(isProportionalScale ? .accentColor : .secondary)
                        
                        Text("Lock")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Toggle("", isOn: $isProportionalScale)
                            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                            .scaleEffect(0.8)
                            .frame(width: 40)
                    }
                }
            }
        }
    }
}

struct RadialGradientControlsView: View {
    let currentGradient: VectorGradient?
    let document: VectorDocument
    let getRadialAngle: (VectorGradient) -> Double
    let getRadialAspectRatio: (VectorGradient) -> Double
    let updateRadialAngle: (Double) -> Void
    let updateRadialAspectRatio: (Double) -> Void
    
    var body: some View {
        if case .radial = currentGradient {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Angle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(currentGradient != nil ? String(format: "%.2f", getRadialAngle(currentGradient!)) : "0.00")°")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: Binding(
                        get: { currentGradient != nil ? getRadialAngle(currentGradient!) : 0.0 },
                        set: updateRadialAngle
                    ), in: -180.0...180.0, onEditingChanged: { editing in
                        if !editing { document.saveToUndoStack() }
                    })
                    .controlSize(.small)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Aspect Ratio")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(currentGradient != nil ? String(format: "%.4f", getRadialAspectRatio(currentGradient!) * 100) : "100.0000")%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: Binding(
                        get: { currentGradient != nil ? getRadialAspectRatio(currentGradient!) : 1.0 },
                        set: updateRadialAspectRatio
                    ), in: -2.0...2.0, onEditingChanged: { editing in
                        if !editing { document.saveToUndoStack() }
                    })
                    .controlSize(.small)
                }
            }
        }
    }
}

struct GradientPreviewAndStopsView: View {
    let currentGradient: VectorGradient?
    let document: VectorDocument
    @Binding var editingGradientStopId: UUID?
    @Binding var editingGradientStopColor: VectorColor
    @Binding var showingGradientColorPicker: Bool
    let createGradient: (VectorGradient) -> AnyShapeStyle
    let getGradientStops: (VectorGradient) -> [GradientStop]
    let getOriginX: (VectorGradient) -> Double
    let getOriginY: (VectorGradient) -> Double
    let updateOriginX: (Double) -> Void
    let updateOriginY: (Double) -> Void
    let addColorStop: () -> Void
    let updateStopPosition: (UUID, Double) -> Void
    let removeColorStop: (UUID) -> Void
    
    var body: some View {
        if currentGradient != nil {
            VStack(alignment: .leading, spacing: 8) {
                Text("Preview")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(createGradient(currentGradient!))
                        .frame(height: 60)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        .overlay(CartesianGrid(width: geometry.size.width, height: 60))
                        .overlay(
                            Circle()
                                .fill(Color.gray.opacity(0.8))
                                .frame(width: 3, height: 3)
                                .position(x: geometry.size.width * 0.5, y: 30)
                        )
                        .onTapGesture { location in
                            document.saveToUndoStack()
                            let normalizedX = max(0.0, min(1.0, location.x / geometry.size.width))
                            let normalizedY = max(0.0, min(1.0, location.y / 60))
                            updateOriginX(normalizedX)
                            updateOriginY(normalizedY)
                        }
                        .overlay(
                            Circle()
                                .fill(Color.white)
                                .frame(width: 8, height: 8)
                                .overlay(Circle().stroke(Color.black, lineWidth: 1))
                                .position(
                                    x: max(0, min(geometry.size.width, getOriginX(currentGradient!) * geometry.size.width)),
                                    y: max(0, min(60, getOriginY(currentGradient!) * 60))
                                )
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            let normalizedX = max(0.0, min(1.0, value.location.x / geometry.size.width))
                                            let normalizedY = max(0.0, min(1.0, value.location.y / 60))
                                            updateOriginX(normalizedX)
                                            updateOriginY(normalizedY)
                                        }
                                        .onEnded { _ in document.saveToUndoStack() }
                                )
                        )
                }
                .frame(height: 60)
                
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
                    }
                    
                    let stops = getGradientStops(currentGradient!).sorted { $0.position < $1.position }
                    ForEach(stops, id: \.id) { stop in
                        HStack(spacing: 8) {
                            Button(action: {
                                editingGradientStopId = stop.id
                                editingGradientStopColor = stop.color
                                showingGradientColorPicker = true
                            }) {
                                renderColorSwatchRightPanel(stop.color, width: 20, height: 20, cornerRadius: 4, borderWidth: 1, opacity: stop.opacity)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Position: \(Int(stop.position * 100))%")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Slider(value: Binding(
                                    get: { stop.position },
                                    set: { updateStopPosition(stop.id, $0) }
                                ), in: 0...1)
                                .controlSize(.small)
                            }
                            
                            if stops.count > 2 {
                                Button(action: { removeColorStop(stop.id) }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
}

struct GradientApplyButtonView: View {
    let currentGradient: VectorGradient?
    let onApply: () -> Void
    
    var body: some View {
        HStack {
            Spacer()
            Button("Apply Gradient", action: onApply)
                .buttonStyle(.borderedProminent)
                .disabled(currentGradient == nil)
        }
    }
}

struct GradientColorPickerSheet: View {
    let document: VectorDocument
    let editingGradientStopId: UUID?
    @Binding var showingColorPicker: Bool
    let updateStopColor: (UUID, VectorColor) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Select Gradient Color")
                    .font(.headline)
                Spacer()
                Button("Done") { showingColorPicker = false }
                    .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            ColorPanel(document: document) { newColor in
                if let stopId = editingGradientStopId {
                    updateStopColor(stopId, newColor)
                }
            }
            .frame(width: 300, height: 400)
        }
        .frame(width: 300, height: 450)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Cartesian Grid for Gradient Preview

struct CartesianGrid: View {
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        ZStack {
            // Vertical grid lines (X-axis markers)
            ForEach(0..<11) { index in
                let position = CGFloat(index) / 10.0  // 0.0 to 1.0
                let xPosition = position * width
                let percentage = Int((position - 0.5) * 200)  // Convert to -100% to +100%
                
                VStack(spacing: 0) {
                    // Top hash mark
                    Rectangle()
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 0.5, height: index % 5 == 0 ? 4 : 2)
                    
                    // Vertical line (lighter for non-center lines)
                    Rectangle()
                        .fill(Color.gray.opacity(position == 0.5 ? 0.6 : 0.2))
                        .frame(width: position == 0.5 ? 1 : 0.5, height: height - 8)
                    
                    // Bottom hash mark
                    Rectangle()
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 0.5, height: index % 5 == 0 ? 4 : 2)
                }
                .position(x: xPosition, y: height / 2)
            }
            
            // Horizontal grid lines (Y-axis markers)
            ForEach(0..<6) { index in
                let position = CGFloat(index) / 5.0  // 0.0 to 1.0 (every 20%)
                let yPosition = position * height
                let percentage = Int((position - 0.5) * 200)  // Convert to -100% to +100%
                
                HStack(spacing: 0) {
                    // Left hash mark
                    Rectangle()
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: index % 2 == 0 ? 4 : 2, height: 0.5)
                    
                    // Horizontal line (lighter for non-center lines)
                    Rectangle()
                        .fill(Color.gray.opacity(position == 0.5 ? 0.6 : 0.2))
                        .frame(width: width - 8, height: position == 0.5 ? 1 : 0.5)
                    
                    // Right hash mark
                    Rectangle()
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: index % 2 == 0 ? 4 : 2, height: 0.5)
                }
                .position(x: width / 2, y: yPosition)
            }
            
            // Percentage labels at key positions
            VStack {
                HStack {
                    Text("-100%")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .offset(x: 2, y: 2)
                    Spacer()
                    Text("0%")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .offset(y: 2)
                    Spacer()
                    Text("+100%")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .offset(x: -2, y: 2)
                }
                .padding(.horizontal, 4)
                Spacer()
                HStack {
                    Text("-100%")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .offset(x: 2, y: -2)
                    Spacer()
                    Text("0%")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .offset(y: -2)
                    Spacer()
                    Text("+100%")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .offset(x: -2, y: -2)
                }
                .padding(.horizontal, 4)
            }
        }
        .allowsHitTesting(false)  // Allow clicks to pass through to the gradient
    }
}

// Preview
struct StrokeFillPanel_Previews: PreviewProvider {
    static var previews: some View {
        StrokeFillPanel(document: VectorDocument())
            .frame(width: 300, height: 600)
    }
}
