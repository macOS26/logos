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
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if !document.selectedShapeIDs.isEmpty {
                    // Current Fill and Stroke Display
                    CurrentColorsView(
                        strokeColor: selectedStrokeColor,
                        fillColor: selectedFillColor,
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
                        onApplyStroke: applyStrokeToSelectedShapes,
                        onUpdateStrokeColor: updateStrokeColor,
                        onUpdateStrokeWidth: updateStrokeWidth,
                        onUpdateStrokePlacement: updateStrokePlacement,
                        onUpdateStrokeOpacity: updateStrokeOpacity, // PROFESSIONAL STROKE TRANSPARENCY
                        onUpdateDashPattern: updateStrokeDashPattern // PROFESSIONAL DASH PATTERNS
                    )
                    
                    // PROFESSIONAL STROKE OUTLINING (Adobe Illustrator Standard)
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
                    
                    // Gradient Fill (Future Enhancement)
                    GradientFillSection()
                } else {
                    // No selection message
                    VStack(spacing: 16) {
                        Image(systemName: "paintbrush")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No shapes selected")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Select a shape to edit its stroke and fill properties")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
                
                Spacer()
            }
            .padding()
        }
        .sheet(isPresented: $showingStrokeColorPicker) {
            ColorPickerSheet(
                selectedColor: selectedStrokeColor,
                document: document,
                title: "Stroke Color",
                onColorChanged: updateStrokeColor
            )
        }
        .sheet(isPresented: $showingFillColorPicker) {
            ColorPickerSheet(
                selectedColor: selectedFillColor,
                document: document,
                title: "Fill Color",
                onColorChanged: updateFillColor
            )
        }
    }
    
    // FIXED: Update methods - update selected shapes AND set default for new shapes
    private func updateFillColor(_ color: VectorColor) {
        // ALWAYS update the default color for new shapes
        document.defaultFillColor = color
        print("🎨 Set default fill color: \(color)")
        
        // If there are selected shapes, update them too
        if let layerIndex = document.selectedLayerIndex, !document.selectedShapeIDs.isEmpty {
            document.saveToUndoStack()
            
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
        
        // If there are selected shapes, update them too
        if let layerIndex = document.selectedLayerIndex, !document.selectedShapeIDs.isEmpty {
            document.saveToUndoStack()
            
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
    let onStrokeColorTap: () -> Void
    let onFillColorTap: () -> Void
    
    var body: some View {
        HStack(spacing: 30) {  // Increased spacing for better separation
            // Fill Color
            VStack(spacing: 12) {  // Increased spacing between swatch and label
                Button(action: onFillColorTap) {
                    RoundedRectangle(cornerRadius: 4)  // Reduced radius for more square appearance
                        .fill(fillColor.color)
                        .frame(width: 60, height: 60)  // Larger, more square
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray, lineWidth: 1.5)  // Slightly thicker border
                        )
                }
                .buttonStyle(PlainButtonStyle())
                
                Text("Fill")
                    .font(.caption)  // Slightly larger font
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            // Stroke Color
            VStack(spacing: 12) {  // Increased spacing between swatch and label
                Button(action: onStrokeColorTap) {
                    RoundedRectangle(cornerRadius: 4)  // Reduced radius for more square appearance
                        .fill(strokeColor.color)
                        .frame(width: 60, height: 60)  // Larger, more square
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray, lineWidth: 1.5)  // Slightly thicker border
                        )
                }
                .buttonStyle(PlainButtonStyle())
                
                Text("Stroke")
                    .font(.caption)  // Slightly larger font
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)  // Increased padding for better breathing room
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
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
    let onApplyStroke: () -> Void
    let onUpdateStrokeColor: (VectorColor) -> Void
    let onUpdateStrokeWidth: (Double) -> Void
    let onUpdateStrokePlacement: (StrokePlacement) -> Void
    let onUpdateStrokeOpacity: (Double) -> Void // PROFESSIONAL STROKE TRANSPARENCY
    let onUpdateDashPattern: ([Double]) -> Void // PROFESSIONAL DASH PATTERNS
    
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
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Gradient Fill")
                .font(.headline)
                .fontWeight(.medium)
            
            Text("Coming Soon...")
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
            
            // Placeholder for gradient controls
            HStack {
                Button("Linear") {
                    // Future implementation
                }
                .buttonStyle(.bordered)
                .disabled(true)
                
                Button("Radial") {
                    // Future implementation
                }
                .buttonStyle(.bordered)
                .disabled(true)
                
                Button("Conical") {
                    // Future implementation
                }
                .buttonStyle(.bordered)
                .disabled(true)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
    }
}

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
                                Text("CMYK(\(Int(cmykPreview.cyan * 100)), \(Int(cmykPreview.magenta * 100)), \(Int(cmykPreview.yellow * 100)), \(Int(cmykPreview.black * 100)))")
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
                        cyanValue = String(Int(cmyk.cyan * 100))
                        magentaValue = String(Int(cmyk.magenta * 100))
                        yellowValue = String(Int(cmyk.yellow * 100))
                        blackValue = String(Int(cmyk.black * 100))
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
                                cyanValue = String(Int(cmyk.cyan * 100))
                                magentaValue = String(Int(cmyk.magenta * 100))
                                yellowValue = String(Int(cmyk.yellow * 100))
                                blackValue = String(Int(cmyk.black * 100))
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
                cyanValue = String(Int(cmyk.cyan * 100))
                magentaValue = String(Int(cmyk.magenta * 100))
                yellowValue = String(Int(cmyk.yellow * 100))
                blackValue = String(Int(cmyk.black * 100))
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

// Preview
struct StrokeFillPanel_Previews: PreviewProvider {
    static var previews: some View {
        StrokeFillPanel(document: VectorDocument())
            .frame(width: 300, height: 600)
    }
}