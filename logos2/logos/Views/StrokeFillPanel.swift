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
    
    // Get current properties from selected shapes
    private var selectedStrokeColor: VectorColor {
        guard let layerIndex = document.selectedLayerIndex,
              let firstSelectedID = document.selectedShapeIDs.first,
              let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }) else {
            return .black
        }
        return shape.strokeStyle?.color ?? .black
    }
    
    private var selectedFillColor: VectorColor {
        guard let layerIndex = document.selectedLayerIndex,
              let firstSelectedID = document.selectedShapeIDs.first,
              let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }) else {
            return .white
        }
        return shape.fillStyle?.color ?? .white
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
        guard let layerIndex = document.selectedLayerIndex,
              let firstSelectedID = document.selectedShapeIDs.first,
              let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }) else {
            return 1.0
        }
        return shape.fillStyle?.opacity ?? 1.0
    }
    
    // strokeOpacity removed - not supported by StrokeStyle
    
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
                                            onApplyStroke: applyStrokeToSelectedShapes,
                    onUpdateStrokeColor: updateStrokeColor,
                    onUpdateStrokeWidth: updateStrokeWidth,
                    onUpdateStrokePlacement: updateStrokePlacement
                    )
                    
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
    
    // Update methods
    private func updateFillColor(_ color: VectorColor) {
        guard let layerIndex = document.selectedLayerIndex else { return }
        document.saveToUndoStack()
        
        for shapeID in document.selectedShapeIDs {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                if document.layers[layerIndex].shapes[shapeIndex].fillStyle == nil {
                    document.layers[layerIndex].shapes[shapeIndex].fillStyle = FillStyle(color: color)
                } else {
                    document.layers[layerIndex].shapes[shapeIndex].fillStyle?.color = color
                }
            }
        }
    }
    
    private func updateFillOpacity(_ opacity: Double) {
        guard let layerIndex = document.selectedLayerIndex else { return }
        document.saveToUndoStack()
        
        for shapeID in document.selectedShapeIDs {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                if document.layers[layerIndex].shapes[shapeIndex].fillStyle == nil {
                    document.layers[layerIndex].shapes[shapeIndex].fillStyle = FillStyle(color: .white, opacity: opacity)
                } else {
                    document.layers[layerIndex].shapes[shapeIndex].fillStyle?.opacity = opacity
                }
            }
        }
    }
    
    private func updateStrokeColor(_ color: VectorColor) {
        guard let layerIndex = document.selectedLayerIndex else { return }
        document.saveToUndoStack()
        
        for shapeID in document.selectedShapeIDs {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                if document.layers[layerIndex].shapes[shapeIndex].strokeStyle == nil {
                    document.layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(color: color, width: 1.0)
                } else {
                    document.layers[layerIndex].shapes[shapeIndex].strokeStyle?.color = color
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
                    document.layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(color: .black, width: width)
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
                    document.layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(color: .black, width: 1.0, placement: placement)
                } else {
                    document.layers[layerIndex].shapes[shapeIndex].strokeStyle?.placement = placement
                }
            }
        }
    }
    
    // updateStrokeOpacity removed - not supported by StrokeStyle
    
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
                    placement: strokePlacement
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
        HStack(spacing: 20) {
            // Fill Color
            VStack(spacing: 8) {
                Button(action: onFillColorTap) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(fillColor.color)
                        .frame(width: 60, height: 60)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                
                Text("Fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Stroke Color
            VStack(spacing: 8) {
                Button(action: onStrokeColorTap) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(strokeColor.color)
                        .frame(width: 60, height: 60)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                
                Text("Stroke")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
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
    let onApplyStroke: () -> Void
    let onUpdateStrokeColor: (VectorColor) -> Void
    let onUpdateStrokeWidth: (Double) -> Void
    let onUpdateStrokePlacement: (StrokePlacement) -> Void
    
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
            
            // Dash Pattern (simplified)
            VStack(alignment: .leading, spacing: 4) {
                Text("Dash Pattern")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Button("Solid") {
                        // Apply solid stroke
                        onApplyStroke()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Dashed") {
                        // Apply dashed stroke - future implementation
                    }
                    .buttonStyle(.bordered)
                    .disabled(true)
                    
                    Button("Dotted") {
                        // Apply dotted stroke - future implementation
                    }
                    .buttonStyle(.bordered)
                    .disabled(true)
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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Color Picker
                ColorPicker("Color", selection: $rgbColor)
                    .labelsHidden()
                    .scaleEffect(2.0)
                    .frame(height: 200)
                
                // Color Mode
                Picker("Mode", selection: $colorMode) {
                    ForEach(ColorMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                
                // Swatches
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(40)), count: 6), spacing: 8) {
                    ForEach(Array(document.colorSwatches.enumerated()), id: \.offset) { index, color in
                        Button {
                            onColorChanged(color)
                            rgbColor = color.color
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
                        let components = rgbColor.components
                        let newColor = VectorColor.rgb(RGBColor(
                            red: components.red,
                            green: components.green,
                            blue: components.blue,
                            alpha: components.alpha
                        ))
                        onColorChanged(newColor)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .frame(width: 400, height: 500)
        .onAppear {
            rgbColor = selectedColor.color
        }
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
            strokeStyle: StrokeStyle(color: .black, width: 1),
            fillStyle: nil
        ),
        StylePreset(
            name: "Thick Stroke",
            strokeStyle: StrokeStyle(color: .black, width: 3),
            fillStyle: nil
        ),
        StylePreset(
            name: "Dashed",
            strokeStyle: StrokeStyle(color: .black, width: 1, dashPattern: [5, 5]),
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