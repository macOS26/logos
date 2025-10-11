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
                    // Calculate exact positions based on layout
                    let iconSize: CGFloat = 20
                    let iconSpacing: CGFloat = 2
                    let rowPadding: CGFloat = 4  // Horizontal padding from edge

                    // Eye icon is first in the HStack
                    let eyeIconX = rowPadding + (iconSize / 2)  // Center X of eye icon
                    // Lock icon is second (eye width + spacing)
                    let lockIconX = rowPadding + iconSize + iconSpacing + (iconSize / 2)  // Center X of lock icon

                    // Compound overlay of individual squares for eye icons
                    ZStack {
                        ForEach(0..<document.layers.count, id: \.self) { index in
                            // Calculate Y position - center of each row
                            let rowY = CGFloat(document.layers.count - 1 - index) * layerRowHeight
                            let iconCenterY = rowY + (layerRowHeight / 2)

                            // Individual square hit area for each eye icon
                            Color.red.opacity(0.0)  // 30% red overlay for visualization
                                .frame(width: iconSize, height: iconSize)
                                .contentShape(Rectangle())
                                .position(x: eyeIconX, y: iconCenterY)
                        }
                    }
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 0)
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
                    .padding(.horizontal, 4)
                    
                    // Compound overlay of individual squares for lock icons
                    ZStack {
                        ForEach(0..<document.layers.count, id: \.self) { index in
                            // Calculate Y position - center of each row
                            let rowY = CGFloat(document.layers.count - 1 - index) * layerRowHeight
                            let iconCenterY = rowY + (layerRowHeight / 2)

                            // Individual square hit area for each lock icon
                            Color.red.opacity(0.0)  // 30% red overlay for visualization
                                .frame(width: iconSize, height: iconSize)
                                .contentShape(Rectangle())
                                .position(x: lockIconX, y: iconCenterY)
                        }
                    }
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
                    .padding(.horizontal, 4)
                    .zIndex(200) // High z-index to be in front
                }
            }
        }
    }

    // REMOVED: layerColor function - now using persistent layer.color property

    private func availableLayerColors() -> [(name: String, color: Color)] {
        return [
            // 16 distinct colors in P3 color space - optimized for clarity and separation
            ("Red", Color(.displayP3, red: 0.75, green: 0.2, blue: 0.2)),             // Muted red - KEEP
            ("Vermillion", Color(.displayP3, red: 0.8, green: 0.38, blue: 0.2)),      // Red-orange - slightly less saturated
            ("Orange", Color(.displayP3, red: 0.85, green: 0.5, blue: 0.15)),         // Pure orange - reduced saturation
            ("Amber", Color(.displayP3, red: 0.82, green: 0.62, blue: 0.2)),          // Yellow-orange - slightly muted
            ("Chartreuse", Color(.displayP3, red: 0.55, green: 0.72, blue: 0.2)),     // Yellow-green - reduced saturation
            ("Lime", Color(.displayP3, red: 0.4, green: 0.68, blue: 0.28)),           // Bright lime - less intense
            ("Green", Color(.displayP3, red: 0.2, green: 0.65, blue: 0.3)),           // Forest green - KEEP
            ("Spring", Color(.displayP3, red: 0.2, green: 0.68, blue: 0.5)),          // Blue-green - slightly muted
            ("Cyan", Color(.displayP3, red: 0.15, green: 0.65, blue: 0.72)),          // Proper cyan - less saturated
            ("Sky", Color(.displayP3, red: 0.32, green: 0.58, blue: 0.82)),           // Sky blue - reduced saturation
            ("Azure", Color(.displayP3, red: 0.18, green: 0.4, blue: 0.78)),          // Deep azure - slightly muted
            ("Blue", Color(.displayP3, red: 0.2, green: 0.25, blue: 0.75)),           // Pure blue - KEEP
            ("Violet", Color(.displayP3, red: 0.4, green: 0.25, blue: 0.7)),          // Blue-purple - KEEP
            ("Purple", Color(.displayP3, red: 0.55, green: 0.25, blue: 0.65)),        // True purple - KEEP
            ("Magenta", Color(.displayP3, red: 0.7, green: 0.2, blue: 0.5)),          // Muted magenta - KEEP
            ("Rose", Color(.displayP3, red: 0.8, green: 0.3, blue: 0.4))              // Dusty rose - KEEP
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
                            RoundedRectangle(cornerRadius: 7)
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
