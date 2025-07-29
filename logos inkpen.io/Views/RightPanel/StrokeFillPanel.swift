//
//  StrokeFillPanel.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI
import AppKit

// MARK: - Helper Structs

struct GradientStopItem: Identifiable {
    let id: UUID
    let color: VectorColor
}

// MARK: - Main Stroke and Fill Panel

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
                    if !document.selectedShapeIDs.isEmpty {
                        Button("Expand Stroke") {
                            document.outlineSelectedStrokes()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .disabled(!document.canOutlineStrokes)
                        .help("Convert stroke to filled path (Cmd+Shift+O)")
                        .keyboardShortcut("o", modifiers: [.command, .shift])
                    }
                    
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
                    opacity: strokeOpacity // PROFESSIONAL STROKE TRANSPARENCY
                )
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
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
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
    @State private var gradientColorWindow: NSWindow?
    
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
                currentGradient: currentGradient,
                document: document,
                onAngleChange: updateGradientAngle
            )
            
            GradientOriginControlView(
                currentGradient: currentGradient,
                document: document,
                getOriginX: getGradientOriginX,
                getOriginY: getGradientOriginY,
                updateOriginX: { updateGradientOriginX($0, applyToShapes: true) },
                updateOriginY: { updateGradientOriginY($0, applyToShapes: true) }
            )
            
            GradientScaleControlView(
                currentGradient: currentGradient,
                document: document,
                getScale: getGradientScale,
                updateScale: updateGradientScale,
                getAspectRatio: getGradientAspectRatio,
                updateAspectRatio: updateGradientAspectRatio,
                getRadius: getGradientRadius,
                updateRadius: updateGradientRadius
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
                getScale: getGradientScale,
                getAspectRatio: getGradientAspectRatio,
                updateOriginX: { updateGradientOriginX($0, applyToShapes: $1) },
                updateOriginY: { updateGradientOriginY($0, applyToShapes: $1) },
                addColorStop: addColorStop,
                updateStopPosition: updateStopPosition,
                updateStopOpacity: updateStopOpacity,
                removeColorStop: removeColorStop,
                applyGradientToSelectedShapes: applyGradientToSelectedShapes
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
        .onReceive(document.objectWillChange) { _ in
            // Force refresh when document changes (including gradient updates)
            updateSelectedGradient()
        }
        .onChange(of: editingGradientStopId) { _, newStopId in
            if let stopId = newStopId {
                showGradientColorWindow(stopId: stopId)
            } else {
                closeGradientColorWindow()
            }
        }
        .onDisappear {
            // DON'T clean up gradient editing state to prevent SwiftUI crashes
            print("🎨 GRADIENT SHEET: View disappearing, keeping state intact")
        }
    }
    
    private func showGradientColorWindow(stopId: UUID) {
        // CRITICAL: Clear any existing gradient editing state first
        appState.finishGradientStopEditing()
        
        // Close existing window if any
        closeGradientColorWindow()
        
        // Find the actual color of this gradient stop
        let actualColor = findGradientStopColor(stopId: stopId)
        
        // Create the content view with AppState environment
        let contentView = GradientColorPickerSheet(
            document: document,
            editingGradientStopId: stopId,
            editingGradientStopColor: actualColor,
            currentGradient: currentGradient,
            showingColorPicker: .constant(true),
            updateStopColor: { [self] targetStopId, color in
                self.updateStopColor(stopId: targetStopId, color: color)
            },
            turnOffEditingState: { [self] in
                self.turnOffEditingState()
            },
            onClose: {
                self.closeGradientColorWindowWithoutStateCleanup()
            }
        )
        .environment(appState) // Pass the AppState environment object
        
        // Create HUD window (no title bar, no close/minimize buttons)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 550),
            styleMask: [.borderless],  // HUD style - no title bar or buttons
            backing: .buffered,
            defer: false
        )
        
        window.title = "Select Gradient Color"  // Keep title for identification
        window.toolbar = nil  // Explicitly remove any toolbar
        window.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95)  // HUD background
        window.isOpaque = false  // Allow transparency
        window.hasShadow = true  // Add shadow for HUD effect
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        
        // Store reference
        gradientColorWindow = window
        
        // Add window delegate to handle closing
        window.delegate = GradientWindowDelegate { [self] in
            DispatchQueue.main.async {
                self.turnOffEditingState()
            }
        }
    }
    
    // Function to close window while keeping state intact
    private func closeGradientColorWindowWithoutStateCleanup() {
        gradientColorWindow?.close()
        // CRITICAL: DO NOT set gradientColorWindow = nil - this causes the crash!
        // Keep ALL state intact - don't clear editingGradientStopId or call finishGradientStopEditing()
        // The window will be deallocated automatically when closed
    }
    
    private func closeGradientColorWindow() {
        gradientColorWindow?.close()
        // Don't set gradientColorWindow = nil here to avoid crash
        // The window will be deallocated automatically when closed
    }
    
    private func turnOffEditingState() {
        editingGradientStopId = nil
    }
    
    // MARK: - Selection and Angle Management
    
    private func updateSelectedGradient() {
        if let selectedGradient = Self.getSelectedShapeGradient(document: document) {
            let originPoint: CGPoint
            switch selectedGradient {
            case .linear(let linear):
                originPoint = linear.originPoint
            case .radial(let radial):
                originPoint = radial.originPoint
            }
            print("🔄 Updating gradient in panel - Origin: (\(originPoint.x), \(originPoint.y))")
            currentGradient = selectedGradient
            switch selectedGradient {
            case .linear(_):
                gradientType = .linear
            case .radial(_):
                gradientType = .radial
            }
            gradientId = UUID() // Generate new ID for loaded gradient
        }
    }
    
    private func updateGradientAngle(_ newAngle: Double) {
        guard let gradient = currentGradient else { return }
        
        switch gradient {
        case .linear(var linear):
            linear.angle = newAngle
            currentGradient = .linear(linear)
            // Apply live to selected shapes
            applyGradientToSelectedShapes()
        case .radial(var radial):
            radial.angle = newAngle
            currentGradient = .radial(radial)
            // Apply live to selected shapes
            applyGradientToSelectedShapes()
        }
    }
    
    // NEW: Origin Point Controls
    private func getGradientOriginX(_ gradient: VectorGradient) -> Double {
        switch gradient {
        case .linear(let linear):
            return linear.originPoint.x
        case .radial(let radial):
            let originX = radial.originPoint.x
            //print("🔍 getGradientOriginX: \(originX) (radial.originPoint.x)")
            return originX
        }
    }
    
    private func getGradientOriginY(_ gradient: VectorGradient) -> Double {
        switch gradient {
        case .linear(let linear):
            return linear.originPoint.y
        case .radial(let radial):
            let originY = radial.originPoint.y
            //print("// print("🔍 getGradientOriginY: \(originY) (radial.originPoint.y)")
            return originY
        }
    }
    
    private func updateGradientOriginX(_ newX: Double, applyToShapes: Bool = true) {
        guard let gradient = currentGradient else { return }
        
        switch gradient {
        case .linear(var linear):
            linear.originPoint.x = newX
            currentGradient = .linear(linear)
        case .radial(var radial):
            radial.originPoint.x = newX
            // Set focal point to match origin point
            radial.focalPoint = CGPoint(x: newX, y: radial.originPoint.y)
            currentGradient = .radial(radial)
        }
        // Only apply to shapes if requested (for performance during drag)
        if applyToShapes {
            applyGradientToSelectedShapes()
        }
    }
    
    private func updateGradientOriginY(_ newY: Double, applyToShapes: Bool = true) {
        guard let gradient = currentGradient else { return }
        
        switch gradient {
        case .linear(var linear):
            linear.originPoint.y = newY
            currentGradient = .linear(linear)
        case .radial(var radial):
            radial.originPoint.y = newY
            // Set focal point to match origin point
            radial.focalPoint = CGPoint(x: radial.originPoint.x, y: newY)
            currentGradient = .radial(radial)
        }
        // Only apply to shapes if requested (for performance during drag)
        if applyToShapes {
            applyGradientToSelectedShapes()
        }
    }
    
    // NEW: Unified Scale Controls
    private func getGradientScale(_ gradient: VectorGradient) -> Double {
        switch gradient {
        case .linear(let linear):
            return linear.scaleX // Use scaleX as the primary scale
        case .radial(let radial):
            return radial.scaleX // Use scaleX as the primary scale
        }
    }
    
    private func getGradientAspectRatio(_ gradient: VectorGradient) -> Double {
        switch gradient {
        case .linear(let linear):
            // Avoid division by zero, return 1.0 if scaleX is 0
            return linear.scaleX != 0 ? linear.scaleY / linear.scaleX : 1.0
        case .radial(let radial):
            // Avoid division by zero, return 1.0 if scaleX is 0
            return radial.scaleX != 0 ? radial.scaleY / radial.scaleX : 1.0
        }
    }
    
    private func updateGradientScale(_ newScale: Double) {
        guard let gradient = currentGradient else { return }
        
        switch gradient {
        case .linear(var linear):
            // Store current aspect ratio before changing scaleX
            let currentAspectRatio = linear.scaleX != 0 ? linear.scaleY / linear.scaleX : 1.0
            linear.scaleX = newScale
            // Apply the same aspect ratio to the new scale
            linear.scaleY = newScale * currentAspectRatio
            currentGradient = .linear(linear)
        case .radial(var radial):
            // Store current aspect ratio before changing scaleX
            let currentAspectRatio = radial.scaleX != 0 ? radial.scaleY / radial.scaleX : 1.0
            radial.scaleX = newScale
            // Apply the same aspect ratio to the new scale
            radial.scaleY = newScale * currentAspectRatio
            currentGradient = .radial(radial)
        }
        // Apply live to selected shapes
        applyGradientToSelectedShapes()
    }
    
    private func updateGradientAspectRatio(_ newAspectRatio: Double) {
        guard let gradient = currentGradient else { return }
        
        // Aspect ratio only works for radial gradients
        switch gradient {
        case .linear(_):
            // Aspect ratio is disabled for linear gradients
            return
        case .radial(var radial):
            // Keep scaleX constant, adjust scaleY based on aspect ratio
            radial.scaleY = radial.scaleX * newAspectRatio
            currentGradient = .radial(radial)
            // Apply live to selected shapes
            applyGradientToSelectedShapes()
        }
    }
    
    // NEW: Radius Controls
    private func getGradientRadius(_ gradient: VectorGradient) -> Double {
        switch gradient {
        case .linear(_):
            return 0.5 // Not applicable for linear gradients
        case .radial(let radial):
            return radial.radius
        }
    }
    
    private func updateGradientRadius(_ newRadius: Double) {
        guard let gradient = currentGradient else { return }
        
        // Radius only works for radial gradients
        switch gradient {
        case .linear(_):
            // Radius is disabled for linear gradients
            return
        case .radial(var radial):
            radial.radius = newRadius
            currentGradient = .radial(radial)
            // Apply live to selected shapes
            applyGradientToSelectedShapes()
        }
    }
    

    

    
    // MARK: - Helper Functions
    
    func createSwiftUIGradient(from vectorGradient: VectorGradient) -> AnyShapeStyle {
        let stops = getGradientStops(vectorGradient)
        let gradientStops = stops.map { stop in
            // Handle clear colors properly for SwiftUI gradients
            let swiftUIColor: Color
            if case .clear = stop.color {
                // For clear colors, don't apply opacity (it's already transparent)
                swiftUIColor = Color.clear
            } else {
                // For non-clear colors, apply the stop opacity
                swiftUIColor = stop.color.color.opacity(stop.opacity)
            }
            return SwiftUI.Gradient.Stop(color: swiftUIColor, location: stop.position)
        }
        let gradient = SwiftUI.Gradient(stops: gradientStops)
        
        switch vectorGradient {
        case .linear(let linear):
            // SIMPLE FIX: Scale origin point by scale factor
            let scale = linear.scaleX // Use scaleX as the single scale value
            let scaledOriginX = linear.originPoint.x * scale
            let scaledOriginY = linear.originPoint.y * scale
            
            // Calculate adjusted start and end points with scaled origin
            let adjustedStartX = linear.startPoint.x + (scaledOriginX - 0.5)
            let adjustedStartY = linear.startPoint.y + (scaledOriginY - 0.5)
            let adjustedEndX = linear.endPoint.x + (scaledOriginX - 0.5)
            let adjustedEndY = linear.endPoint.y + (scaledOriginY - 0.5)
            
            // Apply scale to gradient length
            let gradientVectorX = adjustedEndX - adjustedStartX
            let gradientVectorY = adjustedEndY - adjustedStartY
            let gradientLength = sqrt(gradientVectorX * gradientVectorX + gradientVectorY * gradientVectorY)
            let gradientAngle = atan2(gradientVectorY, gradientVectorX)
            
            let scaledLength = gradientLength * CGFloat(scale)
            let centerX = (adjustedStartX + adjustedEndX) / 2
            let centerY = (adjustedStartY + adjustedEndY) / 2
            
            let scaledStartX = centerX - cos(gradientAngle) * scaledLength / 2
            let scaledStartY = centerY - sin(gradientAngle) * scaledLength / 2
            let scaledEndX = centerX + cos(gradientAngle) * scaledLength / 2
            let scaledEndY = centerY + sin(gradientAngle) * scaledLength / 2
            
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
            
            // Apply truly independent X and Y scale - EXACTLY like aspect ratio did
            let scaleX = radial.scaleX
            let scaleY = radial.scaleY
            
            // For elliptical gradients, we need to use a custom approach
            // SwiftUI RadialGradient doesn't support elliptical, so we create an elliptical effect
            let baseRadius = 50.0
            
            // For elliptical gradients, use a scaled radial as approximation for ShapeStyle
            // The actual elliptical rendering happens in the custom preview view
            let maxScale = max(abs(scaleX), abs(scaleY))
            let scaledRadius = baseRadius * CGFloat(maxScale)
            
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
    
    func updateStopOpacity(stopId: UUID, opacity: Double) {
        guard let gradient = currentGradient else { return }
        
        switch gradient {
        case .linear(var linear):
            if let index = linear.stops.firstIndex(where: { $0.id == stopId }) {
                linear.stops[index].opacity = opacity
                currentGradient = .linear(linear)
                // Apply live to selected shapes
                applyGradientToSelectedShapes()
            }
        case .radial(var radial):
            if let index = radial.stops.firstIndex(where: { $0.id == stopId }) {
                radial.stops[index].opacity = opacity
                currentGradient = .radial(radial)
                // Apply live to selected shapes
                applyGradientToSelectedShapes()
            }
        }
    }
    
    func updateStopColor(stopId: UUID, color: VectorColor) {
        guard let gradient = currentGradient else { 
            return 
        }
        
        // Validate that we're updating the correct stop
        if let editingId = editingGradientStopId, editingId != stopId {
            // Warning: Attempting to update wrong stop
        }
        
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
                startPoint: CGPoint(x: -0.5, y: 0),
                endPoint: CGPoint(x: 0.5, y: 0),
                stops: validStops,
                spreadMethod: .pad,
                units: .objectBoundingBox
            )
            // Set default origin point to center (0,0)
            linear.originPoint = CGPoint(x: 0, y: 0)
            // Set default scale values for new gradients
            linear.scaleX = 1.0
            linear.scaleY = 1.0
            return .linear(linear)
        case .radial:
            var radial = RadialGradient(
                centerPoint: CGPoint(x: 0, y: 0),
                radius: 0.5,
                stops: validStops,
                focalPoint: CGPoint(x: 0, y: 0), // Set focal point to match center point
                spreadMethod: .pad,
                units: .objectBoundingBox
            )
            // Set default origin point to center (0,0)
            radial.originPoint = CGPoint(x: 0, y: 0)
            // Set default scale values for new gradients
            radial.scaleX = 1.0
            radial.scaleY = 1.0
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
                focalPoint: centerPoint, // Set focal point to match center point
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
                // Note: aspectRatio removed - using independent scaleX/scaleY instead
                radial.units = existingRadial.units
                radial.spreadMethod = existingRadial.spreadMethod
            }
            
            return .radial(radial)
        }
    }
    
    private func findGradientStopColor(stopId: UUID) -> VectorColor {
        // First try to find color in current gradient state
        if let gradient = currentGradient {
            let stops: [GradientStop]
            switch gradient {
            case .linear(let linear):
                stops = linear.stops
            case .radial(let radial):
                stops = radial.stops
            }
            
            if let stop = stops.first(where: { $0.id == stopId }) {
                return stop.color
            }
        }
        
        // Fallback: try to find in selected shape's gradient
        guard let layerIndex = document.selectedLayerIndex,
              let firstSelectedID = document.selectedShapeIDs.first,
              let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }),
              let fillStyle = shape.fillStyle else {
            return .black
        }
        
        switch fillStyle.color {
        case .gradient(let gradient):
            if let stop = gradient.stops.first(where: { $0.id == stopId }) {
                return stop.color
            } else {
                return .black
            }
        default:
            return .black
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
                                Text("CMYK(\(Int((cmykPreview.cyan * 100).isFinite ? cmykPreview.cyan * 100 : 0)), \(Int((cmykPreview.magenta * 100).isFinite ? cmyk.magenta * 100 : 0)), \(Int((cmykPreview.yellow * 100).isFinite ? cmyk.yellow * 100 : 0)), \(Int((cmykPreview.black * 100).isFinite ? cmyk.black * 100 : 0)))")
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
                    // RGB Color Picker with Clear Option
                    VStack(spacing: 16) {
                        // Clear Color Button
                        Button {
                            onColorChanged(.clear)
                            presentationMode.wrappedValue.dismiss()
                        } label: {
                            HStack {
                                renderColorSwatchRightPanel(.clear, width: 30, height: 30, cornerRadius: 0, borderWidth: 1)
                                Text("Clear Color")
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Standard Color Picker
                        ColorPicker("Color", selection: $rgbColor)
                            .labelsHidden()
                            .scaleEffect(2.0)
                    }
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
                if let currentGradient = currentGradient {
                    let preservedStops = getGradientStops(currentGradient)
                    self.currentGradient = createGradientPreservingProperties(newValue, preservedStops, currentGradient)
                } else {
                    // Create default gradient if none exists
                    currentGradient = createDefaultGradient(newValue)
                }
                gradientId = UUID()
                onGradientChange()
            }
        }
    }
}

struct GradientAngleControlView: View {
    let currentGradient: VectorGradient?
    let document: VectorDocument
    let onAngleChange: (Double) -> Void
    
    var body: some View {
        if let gradient = currentGradient {
            let angle: Double = {
                switch gradient {
                case .linear(let linear):
                    return linear.angle
                case .radial(let radial):
                    return radial.angle
                }
            }()
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Angle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(String(format: "%.1f", angle))°")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 8) {
                    Slider(value: Binding(
                        get: { angle },
                        set: onAngleChange
                    ), in: -180...180, onEditingChanged: { editing in
                        if !editing { document.saveToUndoStack() }
                    })
                    .controlSize(.small)
                    
                    TextField("", text: Binding(
                        get: { String(format: "%.1f", angle) },
                        set: { newValue in
                            if let doubleValue = Double(newValue) {
                                onAngleChange(doubleValue)
                            }
                        }
                    ))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 60)
                    .font(.system(size: 11))
                }
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
                    Text("Origin Point (0,0 = center, -1 to 1 = scaled range)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("-8 to 8")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(3)
                }
                
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("X: \(currentGradient != nil ? String(format: "%.2f", getOriginX(currentGradient!)) : "0.00")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            Slider(value: Binding(
                                get: { currentGradient != nil ? getOriginX(currentGradient!) : 0.0 },
                                set: updateOriginX
                            ), in: -8.0...8.0, onEditingChanged: { editing in
                                if !editing { document.saveToUndoStack() }
                            })
                            .controlSize(.small)
                            
                            TextField("", text: Binding(
                                get: { currentGradient != nil ? String(format: "%.2f", getOriginX(currentGradient!)) : "0.00" },
                                set: { newValue in
                                    if let doubleValue = Double(newValue) {
                                        updateOriginX(doubleValue)
                                    }
                                }
                            ))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 50)
                            .font(.system(size: 11))
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Y: \(currentGradient != nil ? String(format: "%.2f", getOriginY(currentGradient!)) : "0.00")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            Slider(value: Binding(
                                get: { currentGradient != nil ? getOriginY(currentGradient!) : 0.0 },
                                set: updateOriginY
                            ), in: -8.0...8.0, onEditingChanged: { editing in
                                if !editing { document.saveToUndoStack() }
                            })
                            .controlSize(.small)
                            
                            TextField("", text: Binding(
                                get: { currentGradient != nil ? String(format: "%.2f", getOriginY(currentGradient!)) : "0.00" },
                                set: { newValue in
                                    if let doubleValue = Double(newValue) {
                                        updateOriginY(doubleValue)
                                    }
                                }
                            ))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 50)
                            .font(.system(size: 11))
                        }
                    }
                }
            }
        }
    }
}

struct GradientScaleControlView: View {
    let currentGradient: VectorGradient?
    let document: VectorDocument
    let getScale: (VectorGradient) -> Double
    let updateScale: (Double) -> Void
    let getAspectRatio: (VectorGradient) -> Double
    let updateAspectRatio: (Double) -> Void
    let getRadius: (VectorGradient) -> Double
    let updateRadius: (Double) -> Void
    
    var body: some View {
        if currentGradient != nil {
            VStack(alignment: .leading, spacing: 8) {
                // Uniform Scale Control
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scale: \(currentGradient != nil ? Int(getScale(currentGradient!) * 100) : 100)%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Slider(value: Binding(
                            get: { currentGradient != nil ? getScale(currentGradient!) : 1.0 },
                            set: { newScale in
                                updateScale(newScale)
                            }
                        ), in: 0.01...8.0, onEditingChanged: { editing in
                            if !editing { document.saveToUndoStack() }
                        })
                        .controlSize(.small)
                        
                        TextField("", text: Binding(
                            get: { currentGradient != nil ? String(format: "%.2f", getScale(currentGradient!)) : "1.00" },
                            set: { newValue in
                                if let doubleValue = Double(newValue) {
                                    updateScale(doubleValue)
                                }
                            }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 50)
                        .font(.system(size: 11))
                    }
                }
                
                // Aspect Ratio Control (X=1, Y=0 to 1) - ONLY for Radial Gradients
                if case .radial = currentGradient {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Aspect Ratio: \(currentGradient != nil ? String(format: "%.2f", getAspectRatio(currentGradient!)) : "1.00")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            Slider(value: Binding(
                                get: { currentGradient != nil ? getAspectRatio(currentGradient!) : 1.0 },
                                set: { newAspectRatio in
                                    updateAspectRatio(newAspectRatio)
                                }
                            ), in: 0.01...2.0, onEditingChanged: { editing in
                                if !editing { document.saveToUndoStack() }
                            })
                            .controlSize(.small)
                            
                            TextField("", text: Binding(
                                get: { currentGradient != nil ? String(format: "%.2f", getAspectRatio(currentGradient!)) : "1.00" },
                                set: { newValue in
                                    if let doubleValue = Double(newValue) {
                                        updateAspectRatio(doubleValue)
                                    }
                                }
                            ))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 50)
                            .font(.system(size: 11))
                        }
                    }
                    
                    // Radius Control - ONLY for Radial Gradients
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Radius: \(currentGradient != nil ? String(format: "%.2f", getRadius(currentGradient!)) : "0.50")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            Slider(value: Binding(
                                get: { currentGradient != nil ? getRadius(currentGradient!) : 0.5 },
                                set: { newRadius in
                                    updateRadius(newRadius)
                                }
                            ), in: 0.1...2.0, onEditingChanged: { editing in
                                if !editing { document.saveToUndoStack() }
                            })
                            .controlSize(.small)
                            
                            TextField("", text: Binding(
                                get: { currentGradient != nil ? String(format: "%.2f", getRadius(currentGradient!)) : "0.50" },
                                set: { newValue in
                                    if let doubleValue = Double(newValue) {
                                        updateRadius(doubleValue)
                                    }
                                }
                            ))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 50)
                            .font(.system(size: 11))
                        }
                    }
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
    let getScale: (VectorGradient) -> Double
    let getAspectRatio: (VectorGradient) -> Double
    let updateOriginX: (Double, Bool) -> Void
    let updateOriginY: (Double, Bool) -> Void
    let addColorStop: () -> Void
    let updateStopPosition: (UUID, Double) -> Void
    let updateStopOpacity: (UUID, Double) -> Void
    let removeColorStop: (UUID) -> Void
    let applyGradientToSelectedShapes: () -> Void
    
    private func calculateDotPosition(geometry: GeometryProxy, squareSize: CGFloat, centerX: CGFloat, centerY: CGFloat) -> CGPoint {
        guard let gradient = currentGradient else { return CGPoint(x: centerX, y: centerY) }
        let originX = getOriginX(gradient)
        let originY = getOriginY(gradient)
        
        // Clamp the dot position to stay within preview bounds (0,0 to 1,1)
        let clampedX = max(0.0, min(1.0, originX))
        let clampedY = max(0.0, min(1.0, originY))
        
        return CGPoint(
            x: clampedX * squareSize,
            y: clampedY * squareSize
        )
    }
    
    private func createGradientPreview(geometry: GeometryProxy, squareSize: CGFloat) -> some View {
        return Group {
            if case .radial(let radial) = currentGradient {
                let scale = getScale(currentGradient!)
                let aspectRatio = getAspectRatio(currentGradient!)
                let originX = getOriginX(currentGradient!)
                let originY = getOriginY(currentGradient!)
                let angle = radial.angle
                
                let gradientStops = getGradientStops(currentGradient!).map { stop in
                    // Handle clear colors properly for SwiftUI gradients
                    let swiftUIColor: Color
                    if case .clear = stop.color {
                        swiftUIColor = Color.clear
                    } else {
                        swiftUIColor = stop.color.color.opacity(stop.opacity)
                    }
                    return SwiftUI.Gradient.Stop(color: swiftUIColor, location: stop.position)
                }
                let gradient = SwiftUI.Gradient(stops: gradientStops)
                
                // FIXED: Radial gradient coordinate system - ensure coordinates are properly mapped to the preview area
                let centerX = originX
                let centerY = originY
                
                EllipticalGradient(
                    gradient: gradient,
                    center: UnitPoint(x: centerX, y: centerY),
                    startRadiusX: 0,
                    startRadiusY: 0,
                    endRadiusX: 50.0 * CGFloat(abs(scale * radial.radius)),
                    endRadiusY: 50.0 * CGFloat(abs(scale * aspectRatio * radial.radius)),
                    angle: angle
                )
                .frame(width: squareSize, height: squareSize)
                .overlay(Rectangle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                .overlay(CartesianGrid(width: squareSize, height: squareSize) { x, y in
                    // Clamp preview to 0,0 to 1,1 bounds for visual clarity
                    let clampedX = max(0.0, min(1.0, x))
                    let clampedY = max(0.0, min(1.0, y))
                    updateOriginX(clampedX, true)
                    updateOriginY(clampedY, true)
                    document.saveToUndoStack()
                })

            } else if case .linear(let linear) = currentGradient {
                // FIXED: Create linear gradient with proper scale support
                let scale = getScale(currentGradient!)
                let originX = getOriginX(currentGradient!)
                let originY = getOriginY(currentGradient!)
                
                let gradientStops = getGradientStops(currentGradient!).map { stop in
                    // Handle clear colors properly for SwiftUI gradients
                    let swiftUIColor: Color
                    if case .clear = stop.color {
                        swiftUIColor = Color.clear
                    } else {
                        swiftUIColor = stop.color.color.opacity(stop.opacity)
                    }
                    return SwiftUI.Gradient.Stop(color: swiftUIColor, location: stop.position)
                }
                let gradient = SwiftUI.Gradient(stops: gradientStops)
                
                // FIXED: Apply scale (single value) to gradient length
                let startPoint = UnitPoint(x: linear.startPoint.x, y: linear.startPoint.y)
                let endPoint = UnitPoint(x: linear.endPoint.x, y: linear.endPoint.y)
                
                // Apply origin offset
                let adjustedStart = UnitPoint(x: startPoint.x + (originX - 0.5), y: startPoint.y + (originY - 0.5))
                let adjustedEnd = UnitPoint(x: endPoint.x + (originX - 0.5), y: endPoint.y + (originY - 0.5))
                
                // Apply scale to gradient length
                let gradientVector = CGPoint(x: adjustedEnd.x - adjustedStart.x, y: adjustedEnd.y - adjustedStart.y)
                let gradientLength = sqrt(gradientVector.x * gradientVector.x + gradientVector.y * gradientVector.y)
                let gradientAngle = atan2(gradientVector.y, gradientVector.x)
                
                let scaledLength = gradientLength * CGFloat(scale)
                let centerX = (adjustedStart.x + adjustedEnd.x) / 2
                let centerY = (adjustedStart.y + adjustedEnd.y) / 2
                
                let scaledStartX = centerX - cos(gradientAngle) * scaledLength / 2
                let scaledStartY = centerY - sin(gradientAngle) * scaledLength / 2
                let scaledEndX = centerX + cos(gradientAngle) * scaledLength / 2
                let scaledEndY = centerY + sin(gradientAngle) * scaledLength / 2
                
                let finalStart = UnitPoint(x: scaledStartX, y: scaledStartY)
                let finalEnd = UnitPoint(x: scaledEndX, y: scaledEndY)
                
                SwiftUI.LinearGradient(gradient: gradient, startPoint: finalStart, endPoint: finalEnd)
                    .frame(width: squareSize, height: squareSize)
                    .overlay(Rectangle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                    .overlay(CartesianGrid(width: squareSize, height: squareSize) { x, y in
                        updateOriginX(x, true)
                        updateOriginY(y, true)
                        document.saveToUndoStack()
                    })
            } else {
                let gradient = createGradient(currentGradient!)
                Rectangle()
                    .fill(gradient)
                    .frame(width: squareSize, height: squareSize)
                    .overlay(Rectangle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                    .overlay(CartesianGrid(width: squareSize, height: squareSize) { x, y in
                        // Clamp preview to 0,0 to 1,1 bounds for visual clarity
                        let clampedX = max(0.0, min(1.0, x))
                        let clampedY = max(0.0, min(1.0, y))
                        updateOriginX(clampedX, true)
                        updateOriginY(clampedY, true)
                        document.saveToUndoStack()
                    })
            }
        }
    }
    
    private func createDraggableDot(geometry: GeometryProxy, squareSize: CGFloat, centerX: CGFloat, centerY: CGFloat) -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: 8, height: 8)
            .overlay(Circle().stroke(Color.black, lineWidth: 1))
            .position(calculateDotPosition(geometry: geometry, squareSize: squareSize, centerX: centerX, centerY: centerY))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Clamp preview to 0,0 to 1,1 bounds for visual clarity
                        let normalizedX = max(0.0, min(1.0, value.location.x / squareSize))
                        let normalizedY = max(0.0, min(1.0, value.location.y / squareSize))
                        updateOriginX(normalizedX, true) // Enable live preview on shapes
                        updateOriginY(normalizedY, true) // Enable live preview on shapes
                    }
                    .onEnded { _ in 
                        document.saveToUndoStack() 
                    }
            )
    }
    
    private func createPreviewContent(geometry: GeometryProxy) -> some View {
        let fullWidth = geometry.size.width
        let squareSize = fullWidth // Use full width
        let centerX: CGFloat = fullWidth / 2
        let centerY: CGFloat = fullWidth / 2 // Center vertically too for perfect square
        
        return createGradientPreview(geometry: geometry, squareSize: squareSize)
            .onTapGesture { location in
                // Clamp preview to 0,0 to 1,1 bounds for visual clarity
                let normalizedX = max(0.0, min(1.0, location.x / fullWidth))
                let normalizedY = max(0.0, min(1.0, location.y / fullWidth))
                updateOriginX(normalizedX, true)
                updateOriginY(normalizedY, true)
                document.saveToUndoStack()
            }
            .overlay(createDraggableDot(geometry: geometry, squareSize: squareSize, centerX: centerX, centerY: centerY))
    }
    
    var body: some View {
        if currentGradient != nil {
            VStack(alignment: .leading, spacing: 8) {
                Text("Preview")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                GeometryReader { geometry in
                    createPreviewContent(geometry: geometry)
                }
                .aspectRatio(1, contentMode: .fit) // Perfect square
                
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
                    
                    // Memoize gradient stops calculation for performance
                    let stops = getGradientStops(currentGradient!).sorted { $0.position < $1.position }
                    ForEach(stops, id: \.id) { stop in
                        HStack(spacing: 8) {
                            Button(action: {
                                editingGradientStopId = stop.id
                                editingGradientStopColor = stop.color
                            }) {
                                renderColorSwatchRightPanel(stop.color, width: 20, height: 20, cornerRadius: 0, borderWidth: 1, opacity: stop.opacity)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .overlay(
                                // Visual indicator for currently editing stop
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(Color.blue, lineWidth: editingGradientStopId == stop.id ? 3 : 0)
                            )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    // Show "EDITING" indicator for the selected stop
                                    if editingGradientStopId == stop.id {
                                        Text("EDITING")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                            .fontWeight(.bold)
                                    }
                                    Spacer()
                                }
                                
                                // Position and Opacity on same line
                                HStack(spacing: 8) {
                                    // Position slider
                                    Slider(value: Binding(
                                        get: { stop.position },
                                        set: { updateStopPosition(stop.id, $0) }
                                    ), in: 0...1)
                                    .controlSize(.small)
                                    
                                    // Position text field
                                    TextField("", text: Binding(
                                        get: { String(format: "%.0f", stop.position * 100) },
                                        set: { newValue in
                                            if let doubleValue = Double(newValue) {
                                                updateStopPosition(stop.id, doubleValue / 100.0)
                                            }
                                        }
                                    ))
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 40)
                                    .font(.system(size: 11))
                                    
                                    // Opacity text field
                                    TextField("", text: Binding(
                                        get: { String(format: "%.0f", stop.opacity * 100) },
                                        set: { newValue in
                                            if let doubleValue = Double(newValue) {
                                                updateStopOpacity(stop.id, doubleValue / 100.0)
                                            }
                                        }
                                    ))
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 40)
                                    .font(.system(size: 11))
                                }
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
                        .background(
                            // Background highlight for currently editing stop
                            RoundedRectangle(cornerRadius: 6)
                                .fill(editingGradientStopId == stop.id ? Color.blue.opacity(0.1) : Color.clear)
                        )
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
    let editingGradientStopColor: VectorColor
    let currentGradient: VectorGradient? // Add current gradient reference
    @Binding var showingColorPicker: Bool
    let updateStopColor: (UUID, VectorColor) -> Void
    let turnOffEditingState: () -> Void
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    // Create a local document wrapper with the correct initial color
    @State private var localDocument: VectorDocument
    
    // Add close callback for the window
    var onClose: (() -> Void)?
    
    init(document: VectorDocument, editingGradientStopId: UUID?, editingGradientStopColor: VectorColor, currentGradient: VectorGradient?, showingColorPicker: Binding<Bool>, updateStopColor: @escaping (UUID, VectorColor) -> Void, turnOffEditingState: @escaping () -> Void, onClose: (() -> Void)? = nil) {
        self.document = document
        self.editingGradientStopId = editingGradientStopId
        self.editingGradientStopColor = editingGradientStopColor
        self.currentGradient = currentGradient
        self._showingColorPicker = showingColorPicker
        self.updateStopColor = updateStopColor
        self.turnOffEditingState = turnOffEditingState
        self.onClose = onClose
        
        // Create a copy of the document with the correct initial color but preserve important properties
        let localDoc = VectorDocument()
        localDoc.defaultFillColor = editingGradientStopColor
        
        // Copy essential properties from the original document
        localDoc.settings = document.settings  // Includes colorMode, etc.
        
        // Copy color swatches based on current mode
        localDoc.rgbSwatches = document.rgbSwatches
        localDoc.cmykSwatches = document.cmykSwatches
        localDoc.hsbSwatches = document.hsbSwatches
        
        self._localDocument = State(initialValue: localDoc)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ColorPanel(document: localDocument, onColorSelected: { newColor in
                // When a color is selected, update the stop but DON'T close the window
                if let stopId = editingGradientStopId {
                    updateStopColor(stopId, newColor)
                }
                // Window stays open - user controls when to close
            }, showGradientEditing: true)
            .frame(width: 300, height: 500)  // Reduced height to make room for close button
            
            // Close button in lower right corner
            HStack {
                Spacer()
                Button("Close") {
                    // Turn off editing state
                    turnOffEditingState()
                    // Hide the window
                    if let window = NSApplication.shared.windows.first(where: { $0.title == "Select Gradient Color" }) {
                        window.orderOut(nil)
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
            .frame(height: 50)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .task {
            // Set up gradient editing state
            if let stopId = editingGradientStopId, let gradient = currentGradient {
                // Find the correct stop and its current color
                let stops: [GradientStop]
                switch gradient {
                case .linear(let linear):
                    stops = linear.stops
                case .radial(let radial):
                    stops = radial.stops
                }
                
                let stopIndex = stops.firstIndex { $0.id == stopId } ?? 0
                let stopColor = stops.first(where: { $0.id == stopId })?.color ?? .black
                
                // CRITICAL: Use the captured stopId to avoid closure issues
                let capturedStopId = stopId
                appState.gradientEditingState = GradientEditingState(
                    gradientId: capturedStopId,
                    stopIndex: stopIndex,
                    onColorSelected: { color in
                        updateStopColor(capturedStopId, color)
                        // Window stays open - user controls when to close
                    }
                )
            }
        }
        .onDisappear {
            // DON'T clean up gradient editing state to prevent SwiftUI crashes
        }
    }
}

// MARK: - Elliptical Gradient for Preview (since SwiftUI doesn't support elliptical radial gradients)

struct EllipticalGradient: View {
    let gradient: SwiftUI.Gradient
    let center: UnitPoint
    let startRadiusX: CGFloat
    let startRadiusY: CGFloat
    let endRadiusX: CGFloat
    let endRadiusY: CGFloat
    let angle: Double // Rotation angle in degrees
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // Create CoreGraphics gradient from SwiftUI gradient
                let cgColors = gradient.stops.map { stop in
                    stop.color.cgColor ?? CGColor(red: 0, green: 0, blue: 0, alpha: 0)
                }
                let locations = gradient.stops.map { CGFloat($0.location) }
                
                guard let cgGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                                  colors: cgColors as CFArray,
                                                  locations: locations) else { return }
                
                // Calculate center point
                let centerPoint = CGPoint(x: size.width * center.x, y: size.height * center.y)
                
                // Save context for transform
                context.withCGContext { cgContext in
                    cgContext.saveGState()
                    
                    // Translate to center for rotation and scaling
                    cgContext.translateBy(x: centerPoint.x, y: centerPoint.y)
                    
                    // Apply rotation BEFORE scaling - EXACTLY like the real gradient rendering
                    let angleInRadians = angle * .pi / 180.0
                    cgContext.rotate(by: CGFloat(angleInRadians))
                    
                    // Apply independent X/Y scaling - EXACTLY like the real gradient rendering
                    let scaleX = endRadiusX / max(endRadiusX, endRadiusY, 1.0)
                    let scaleY = endRadiusY / max(endRadiusX, endRadiusY, 1.0)
                    cgContext.scaleBy(x: scaleX, y: scaleY)
                    
                    // Draw circular gradient at origin (will be elliptical due to scaling)
                    let maxRadius = max(endRadiusX, endRadiusY, 1.0)
                    cgContext.drawRadialGradient(cgGradient, 
                                               startCenter: CGPoint.zero, 
                                               startRadius: 0, 
                                               endCenter: CGPoint.zero, 
                                               endRadius: maxRadius, 
                                               options: [.drawsAfterEndLocation])
                    
                    cgContext.restoreGState()
                }
            }
        }
    }
}

// MARK: - Cartesian Grid for Gradient Preview

struct CartesianGrid: View {
    let width: CGFloat
    let height: CGFloat
    let onCoordinateClick: ((Double, Double) -> Void)?
    
    init(width: CGFloat, height: CGFloat, onCoordinateClick: ((Double, Double) -> Void)? = nil) {
        self.width = width
        self.height = height
        self.onCoordinateClick = onCoordinateClick
    }
    
    var body: some View {
        ZStack {
            // Vertical grid lines (X-axis markers) - edge to edge
            ForEach(0..<5) { index in
                let position = CGFloat(index) / 4.0  // 0.0 to 1.0
                let xPosition = position * width
                
                // Full-height vertical line (edge to edge)
                Rectangle()
                    .fill(Color.white.opacity(position == 0.5 ? 0.9 : 0.3))
                    .frame(width: position == 0.5 ? 1 : 0.5, height: height)
                    .position(x: xPosition, y: height / 2)
            }
            
            // Horizontal grid lines (Y-axis markers) - edge to edge
            ForEach(0..<5) { index in
                let position = CGFloat(index) / 4.0  // 0.0 to 1.0
                let yPosition = position * height
                
                // Full-width horizontal line (edge to edge)
                Rectangle()
                    .fill(Color.white.opacity(position == 0.5 ? 0.9 : 0.3))
                    .frame(width: width, height: position == 0.5 ? 1 : 0.5)
                    .position(x: width / 2, y: yPosition)
            }
            
            // Coordinate labels at key positions
            VStack {
                HStack {
                    Text("(0,0)")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .offset(x: 2, y: 2)
                    Spacer()
                    Text("(0.5,0)")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .offset(y: 2)
                    Spacer()
                    Text("(1,0)")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .offset(x: -2, y: 2)
                }
                .padding(.horizontal, 4)
                Spacer()
                HStack {
                    Text("(0,1)")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .offset(x: 2, y: -2)
                    Spacer()
                    Text("(0.5,1)")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .offset(y: -2)
                    Spacer()
                    Text("(1,1)")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .offset(x: -2, y: -2)
                }
                .padding(.horizontal, 4)
            }
            
            // Clickable coordinate points
            if let onCoordinateClick = onCoordinateClick {
                // Corner points
                // Top-left (0,0)
                Circle()
                    .fill(Color.blue.opacity(0.6))
                    .frame(width: 12, height: 12)
                    .position(x: 0, y: 0)
                    .onTapGesture {
                        onCoordinateClick(0.0, 0.0)
                    }
                
                // Top-right (1,0)
                Circle()
                    .fill(Color.blue.opacity(0.6))
                    .frame(width: 12, height: 12)
                    .position(x: width, y: 0)
                    .onTapGesture {
                        onCoordinateClick(1.0, 0.0)
                    }
                
                // Bottom-left (0,1)
                Circle()
                    .fill(Color.blue.opacity(0.6))
                    .frame(width: 12, height: 12)
                    .position(x: 0, y: height)
                    .onTapGesture {
                        onCoordinateClick(0.0, 1.0)
                    }
                
                // Bottom-right (1,1)
                Circle()
                    .fill(Color.blue.opacity(0.6))
                    .frame(width: 12, height: 12)
                    .position(x: width, y: height)
                    .onTapGesture {
                        onCoordinateClick(1.0, 1.0)
                    }
                
                // Center (0.5,0.5)
                Circle()
                    .fill(Color.green.opacity(0.6))
                    .frame(width: 12, height: 12)
                    .position(x: width/2, y: height/2)
                    .onTapGesture {
                        onCoordinateClick(0.5, 0.5)
                    }
                
                // Edge midpoints
                // Top center (0.5,0)
                Circle()
                    .fill(Color.blue.opacity(0.6))
                    .frame(width: 12, height: 12)
                    .position(x: width/2, y: 0)
                    .onTapGesture {
                        onCoordinateClick(0.5, 0.0)
                    }
                
                // Bottom center (0.5,1)
                Circle()
                    .fill(Color.blue.opacity(0.6))
                    .frame(width: 12, height: 12)
                    .position(x: width/2, y: height)
                    .onTapGesture {
                        onCoordinateClick(0.5, 1.0)
                    }
                
                // Left center (0,0.5)
                Circle()
                    .fill(Color.blue.opacity(0.6))
                    .frame(width: 12, height: 12)
                    .position(x: 0, y: height/2)
                    .onTapGesture {
                        onCoordinateClick(0.0, 0.5)
                    }
                
                // Right center (1,0.5)
                Circle()
                    .fill(Color.blue.opacity(0.6))
                    .frame(width: 12, height: 12)
                    .position(x: width, y: height/2)
                    .onTapGesture {
                        onCoordinateClick(1.0, 0.5)
                    }
                
                // Grid intersections (8 additional points)
                // Top-left quadrant center (0.25,0.25)
                Circle()
                    .fill(Color.blue.opacity(0.6))
                    .frame(width: 12, height: 12)
                    .position(x: width * 0.25, y: height * 0.25)
                    .onTapGesture {
                        onCoordinateClick(0.25, 0.25)
                    }
                
                // Top-right quadrant center (0.75,0.25)
                Circle()
                    .fill(Color.blue.opacity(0.6))
                    .frame(width: 12, height: 12)
                    .position(x: width * 0.75, y: height * 0.25)
                    .onTapGesture {
                        onCoordinateClick(0.75, 0.25)
                    }
                
                // Bottom-left quadrant center (0.25,0.75)
                Circle()
                    .fill(Color.blue.opacity(0.6))
                    .frame(width: 12, height: 12)
                    .position(x: width * 0.25, y: height * 0.75)
                    .onTapGesture {
                        onCoordinateClick(0.25, 0.75)
                    }
                
                // Bottom-right quadrant center (0.75,0.75)
                Circle()
                    .fill(Color.blue.opacity(0.6))
                    .frame(width: 12, height: 12)
                    .position(x: width * 0.75, y: height * 0.75)
                    .onTapGesture {
                        onCoordinateClick(0.75, 0.75)
                    }
                
                // Left middle (0.25,0.5)
                Circle()
                    .fill(Color.blue.opacity(0.6))
                    .frame(width: 12, height: 12)
                    .position(x: width * 0.25, y: height * 0.5)
                    .onTapGesture {
                        onCoordinateClick(0.25, 0.5)
                    }
                
                // Right middle (0.75,0.5)
                Circle()
                    .fill(Color.blue.opacity(0.6))
                    .frame(width: 12, height: 12)
                    .position(x: width * 0.75, y: height * 0.5)
                    .onTapGesture {
                        onCoordinateClick(0.75, 0.5)
                    }
                
                // Top middle (0.5,0.25)
                Circle()
                    .fill(Color.blue.opacity(0.6))
                    .frame(width: 12, height: 12)
                    .position(x: width * 0.5, y: height * 0.25)
                    .onTapGesture {
                        onCoordinateClick(0.5, 0.25)
                    }
                
                // Bottom middle (0.5,0.75)
                Circle()
                    .fill(Color.blue.opacity(0.6))
                    .frame(width: 12, height: 12)
                    .position(x: width * 0.5, y: height * 0.75)
                    .onTapGesture {
                        onCoordinateClick(0.5, 0.75)
                    }
            }
        }
    }
}

// MARK: - Gradient Window Delegate

class GradientWindowDelegate: NSObject, NSWindowDelegate {
    let onWindowClose: () -> Void
    
    init(onWindowClose: @escaping () -> Void) {
        self.onWindowClose = onWindowClose
        super.init()
    }
    
    func windowWillClose(_ notification: Notification) {
        onWindowClose()
    }
}

// Preview
struct StrokeFillPanel_Previews: PreviewProvider {
    static var previews: some View {
        StrokeFillPanel(document: VectorDocument())
            .frame(width: 300, height: 600)
    }
}
