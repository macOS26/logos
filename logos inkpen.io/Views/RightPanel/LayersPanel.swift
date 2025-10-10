//
//  LayersPanel.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI
import UniformTypeIdentifiers
import Combine

        // PROFESSIONAL LAYERS PANEL (Professional Style)
struct LayersPanel: View {
    @ObservedObject var document: VectorDocument
    @State private var expandedLayers: Set<Int> = []
    @State private var renamingLayerIndex: Int?
    @State private var newLayerName: String = ""
    @State private var draggedLayerIndex: Int? = nil
    @State private var dragOffset: CGSize = .zero
    @State private var targetLayerIndex: Int? = nil
    @State private var showColorPicker: Bool = false

    // Consistent row height variable used throughout
    private let layerRowHeight: CGFloat = 32  // Actual height of layer rows

    // Check if all layers have the same effective height (overlay works when uniform)
    private var allLayersHaveUniformHeight: Bool {
        // Check each layer to see if it would have content when expanded
        for (index, layer) in document.layers.enumerated() {
            // Check expansion state based on layer index
            let isExpanded = if index <= 1 {
                document.settings.layerExpansionState[layer.id] ?? false
            } else {
                document.settings.layerExpansionState[layer.id] ?? true
            }

            if isExpanded {
                let hasObjects = document.unifiedObjects.contains { $0.layerIndex == index }
                if hasObjects {
                    return false // Expanded with objects = not uniform
                }
            }
        }
        // All layers are either collapsed or expanded with no objects = uniform height
        return true
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            layersHeader
            Divider().padding(.horizontal, 8)

            // Layer controls (opacity and blend mode) - shown when a layer is selected
            if let selectedIndex = document.selectedLayerIndex, selectedIndex < document.layers.count {
                layerControlsSection(for: selectedIndex)
                Divider().padding(.horizontal, 8)
            }

            layersScrollContent
            Spacer()
        }
    }
    
    private var layersHeader: some View {
        HStack {
            Text("Layer")
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
            Button(action: {
                document.addLayer(name: "New Layer")
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(BorderlessButtonStyle())
            .help("Add New Layer")
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private func layerControlsSection(for layerIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Opacity slider
            HStack(spacing: 8) {
                Text("Opacity")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .leading)

                Slider(
                    value: Binding(
                        get: { document.layers[layerIndex].opacity },
                        set: { newValue in
                            var updatedLayer = document.layers[layerIndex]
                            updatedLayer.opacity = newValue
                            document.layers[layerIndex] = updatedLayer
                        }
                    ),
                    in: 0...1,
                    onEditingChanged: { editing in
                        if !editing {
                            document.saveToUndoStack()
                        }
                    }
                )
                .frame(maxWidth: .infinity)

                Text("\(Int(document.layers[layerIndex].opacity * 100))%")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(width: 35, alignment: .trailing)
            }

            // Blend mode picker with color swatch
            HStack(spacing: 8) {
                Text("Blend")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .leading)

                Picker("", selection: Binding(
                    get: { document.layers[layerIndex].blendMode },
                    set: { newValue in
                        var updatedLayer = document.layers[layerIndex]
                        updatedLayer.blendMode = newValue
                        document.layers[layerIndex] = updatedLayer
                        document.saveToUndoStack()
                    }
                )) {
                    ForEach(BlendMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)

                Spacer()
                    .frame(width: 0)

                // Layer Color Swatch - Square, clickable with color picker (with proper binding)
                ColorSwatchButton(
                    color: Binding(
                        get: { document.layers[layerIndex].color },
                        set: { newColor in
                            document.saveToUndoStack()
                            document.layers[layerIndex].color = newColor
                        }
                    ),
                    availableColors: availableLayerColors()
                )

                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    private var layersScrollContent: some View {
        ScrollView(.vertical, showsIndicators: true) {
            ZStack(alignment: .topLeading) {
                // Main layer rows
                VStack(spacing: 0) {
                    ForEach(Array((0..<document.layers.count).reversed().enumerated()), id: \.element) { (index, layerIndex) in
                        // Layer row content
                        layerRowContent(for: layerIndex)
                            .offset(draggedLayerIndex == layerIndex ? dragOffset : .zero)
                            .opacity(draggedLayerIndex == layerIndex ? 0.9 : 1.0)
                            .zIndex(draggedLayerIndex == layerIndex ? 100 : 0)
                            .gesture(
                                layerIndex > 1 ? // Only draggable if not Canvas/Pasteboard
                                DragGesture(minimumDistance: 5)
                                    .onChanged { value in
                                        if draggedLayerIndex == nil {
                                            draggedLayerIndex = layerIndex
                                            document.selectedLayerIndex = layerIndex
                                        }

                                        dragOffset = value.translation

                                        let dragDistance = value.translation.height

                                        if abs(dragDistance) < layerRowHeight / 2 {
                                            targetLayerIndex = nil
                                        } else if dragDistance < 0 {
                                            // Dragging UP (visually) = higher index
                                            let slots = Int(abs(dragDistance) / layerRowHeight)
                                            targetLayerIndex = max(2, layerIndex + slots + 1)
                                        } else {
                                            // Dragging DOWN (visually) = lower index
                                            let slots = Int(abs(dragDistance) / layerRowHeight)
                                            targetLayerIndex = max(2, layerIndex - slots)
                                        }
                                    }
                                    .onEnded { value in
                                        dragOffset = .zero

                                        if let target = targetLayerIndex,
                                           let source = draggedLayerIndex,
                                           target != source && target >= 2 {
                                            document.moveLayer(from: source, to: target)
                                        }

                                        draggedLayerIndex = nil
                                        targetLayerIndex = nil
                                    }
                                : nil
                            )
                    }
                }
                .padding(.horizontal, 4)

                // Overlay columns for drag-through (present when all layers have same height)
                if allLayersHaveUniformHeight {
                    VStack {
                        HStack(spacing: 0) {
                        // Eye column overlay (using consistent row height)
                        Color.red.opacity(0.3) // Debug: 30% red to visualize overlay
                            .frame(width: 23, height: CGFloat(document.layers.count) * layerRowHeight)
                            .contentShape(Rectangle())
                            .highPriorityGesture(
                                DragGesture(minimumDistance: 0) // Match lock overlay behavior
                                    .onChanged { value in
                                        // Start drag if not already started
                                        if !document.isDraggingVisibility {
                                            document.isDraggingVisibility = true
                                            document.processedLayersDuringDrag.removeAll()
                                            document.saveToUndoStack()

                                            // Process initial position
                                            let startY = value.startLocation.y
                                            let layerIndex = Int(startY / layerRowHeight)
                                            let reversedIndex = document.layers.count - 1 - layerIndex

                                            if reversedIndex >= 0 && reversedIndex < document.layers.count {
                                                document.layers[reversedIndex].isVisible.toggle()
                                                document.processedLayersDuringDrag.insert(reversedIndex)
                                            }
                                        }

                                        // Process current position during drag
                                        let currentY = value.location.y
                                        let layerIndex = Int(currentY / layerRowHeight)
                                        let reversedIndex = document.layers.count - 1 - layerIndex

                                        if reversedIndex >= 0 && reversedIndex < document.layers.count {
                                            if !document.processedLayersDuringDrag.contains(reversedIndex) {
                                                // Toggle this layer's visibility
                                                document.layers[reversedIndex].isVisible.toggle()
                                                document.processedLayersDuringDrag.insert(reversedIndex)
                                            }
                                        }
                                    }
                                    .onEnded { _ in
                                        document.isDraggingVisibility = false
                                        document.processedLayersDuringDrag.removeAll()
                                    }
                            )

                        // Spacer to create dead space between overlays
                        Color.clear
                            .frame(width: 2, height: CGFloat(document.layers.count) * layerRowHeight)

                        // Lock column overlay (using consistent row height)
                        Color.red.opacity(0.3) // Debug: 30% red to visualize overlay
                            .frame(width: 23, height: CGFloat(document.layers.count) * layerRowHeight)
                            .contentShape(Rectangle())
                            .highPriorityGesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        // Start drag if not already started
                                        if !document.isDraggingLock {
                                            document.isDraggingLock = true
                                            document.processedLayersDuringDrag.removeAll()
                                            document.saveToUndoStack()

                                            // Process initial position
                                            let startY = value.startLocation.y
                                            let layerIndex = Int(startY / layerRowHeight)
                                            let reversedIndex = document.layers.count - 1 - layerIndex

                                            if reversedIndex >= 0 && reversedIndex < document.layers.count {
                                                document.layers[reversedIndex].isLocked.toggle()
                                                document.processedLayersDuringDrag.insert(reversedIndex)
                                            }
                                        }

                                        // Process current position during drag
                                        let currentY = value.location.y
                                        let layerIndex = Int(currentY / layerRowHeight)
                                        let reversedIndex = document.layers.count - 1 - layerIndex

                                        if reversedIndex >= 0 && reversedIndex < document.layers.count {
                                            if !document.processedLayersDuringDrag.contains(reversedIndex) {
                                                // Toggle this layer's lock
                                                document.layers[reversedIndex].isLocked.toggle()
                                                document.processedLayersDuringDrag.insert(reversedIndex)
                                            }
                                        }
                                    }
                                    .onEnded { _ in
                                        document.isDraggingLock = false
                                        document.processedLayersDuringDrag.removeAll()
                                    }
                            )

                        Spacer()
                    }
                    .padding(.horizontal, 4)
                        Spacer()
                    }
                    .zIndex(200) // High z-index to be in front
                }
            }
        }
    }

    // REMOVED: layerColor function - now using persistent layer.color property

    private func availableLayerColors() -> [(name: String, color: Color)] {
        return [
            // 16 perfectly evenly-spaced rainbow colors (HSB-based, exact 22.5° intervals)
            // Hue: 0° - 360° (360/16 = 22.5° spacing), Saturation: 100%, Brightness: 90-100%
            ("Red", Color(hue: 0/360, saturation: 1.0, brightness: 1.0)),              // 0°
            ("Vermillion", Color(hue: 22.5/360, saturation: 1.0, brightness: 1.0)),    // 22.5°
            ("Orange", Color(hue: 45/360, saturation: 1.0, brightness: 1.0)),          // 45°
            ("Amber", Color(hue: 67.5/360, saturation: 1.0, brightness: 1.0)),         // 67.5°
            ("Chartreuse", Color(hue: 90/360, saturation: 1.0, brightness: 1.0)),      // 90°
            ("Lime", Color(hue: 112.5/360, saturation: 0.8, brightness: 0.75)),        // 112.5°
            ("Green", Color(hue: 135/360, saturation: 0.7, brightness: 0.65)),         // 135°
            ("Spring", Color(hue: 165/360, saturation: 0.6, brightness: 0.6)),         // 165° (shifted towards blue)
            ("Cyan", Color(hue: 190/360, saturation: 0.7, brightness: 0.85)),          // 190° (shifted towards blue)
            ("Sky", Color(hue: 202.5/360, saturation: 0.85, brightness: 0.85)),        // 202.5°
            ("Azure", Color(hue: 225/360, saturation: 0.9, brightness: 0.9)),          // 225°
            ("Blue", Color(hue: 240/360, saturation: 0.8, brightness: 0.95)),          // 240° (true blue)
            ("Violet", Color(hue: 270/360, saturation: 0.75, brightness: 0.75)),       // 270°
            ("Purple", Color(hue: 292.5/360, saturation: 0.85, brightness: 0.85)),     // 292.5°
            ("Magenta", Color(hue: 315/360, saturation: 1.0, brightness: 1.0)),        // 315°
            ("Rose", Color(hue: 337.5/360, saturation: 1.0, brightness: 1.0))          // 337.5°
        ]
    }

    private func layerRowContent(for layerIndex: Int) -> some View {
        ProfessionalLayerRow(
            layerIndex: layerIndex,
            layer: layerIndex < document.layers.count ? document.layers[layerIndex] : document.layers[0],
            document: document
        )
    }
}

// MARK: - Color Swatch Button Component
struct ColorSwatchButton: View {
    @Binding var color: Color
    let availableColors: [(name: String, color: Color)]
    @State private var showColorPicker: Bool = false

    var body: some View {
        Button(action: {
            showColorPicker = true
        }) {
            RoundedRectangle(cornerRadius: 20)
                .fill(color)
                .padding(.horizontal, -3)
                .frame(width: 14, height: 16)
        }
        .buttonStyle(PlainButtonStyle())
        .popover(isPresented: $showColorPicker, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(availableColors, id: \.name) { colorOption in
                    Button(action: {
                        color = colorOption.color
                        showColorPicker = false
                    }) {
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(colorOption.color)
                                .frame(width: 14, height: 14)
                            Text(colorOption.name)
                                .font(.system(size: 11))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(6)
        }
    }
} 