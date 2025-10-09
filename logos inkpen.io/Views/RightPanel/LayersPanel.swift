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

            // Blend mode picker
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
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    private var layersScrollContent: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 2) {
                ForEach(Array(document.layers.indices.reversed()), id: \.self) { layerIndex in
                    VStack(spacing: 0) {
                        // Drop zone indicator ABOVE this layer
                        // Show when target layer would be placed at this index
                        if let target = targetLayerIndex, target == layerIndex && draggedLayerIndex != layerIndex {
                            Rectangle()
                                .fill(Color.blue)
                                .frame(height: 3)
                                .padding(.horizontal, 8)
                        }

                        // Layer row content (ProfessionalLayerRow already includes color indicator)
                        layerRowContent(for: layerIndex)
                        .offset(draggedLayerIndex == layerIndex ? dragOffset : .zero)
                        .opacity(draggedLayerIndex == layerIndex ? 0.8 : 1.0)
                        .scaleEffect(draggedLayerIndex == layerIndex ? 0.98 : 1.0)
                        .zIndex(draggedLayerIndex == layerIndex ? 100 : 0)
                        .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.9), value: dragOffset)
                        .gesture(
                            layerIndex > 1 ? // Only draggable if not Canvas/Pasteboard
                            DragGesture(minimumDistance: 5)
                                .onChanged { value in
                                    if draggedLayerIndex == nil {
                                        draggedLayerIndex = layerIndex
                                        // Select the layer immediately when dragging starts
                                        document.selectedLayerIndex = layerIndex
                                        print("🎯 Started dragging layer \(layerIndex): \(document.layers[layerIndex].name)")
                                    }

                                    withAnimation(.interactiveSpring(response: 0.1, dampingFraction: 0.95)) {
                                        dragOffset = value.translation
                                    }

                                    // Calculate which layer we're hovering over
                                    let rowHeight: CGFloat = 45 // Actual row height
                                    let dragDistance = value.translation.height

                                    // Calculate target based on drag direction
                                    // NOTE: Layers are displayed REVERSED, so visual up = higher index
                                    if dragDistance < -rowHeight/2 {
                                        // Dragging up (visually toward front = higher index in reversed array)
                                        let slots = Int((-dragDistance + rowHeight/2) / rowHeight)
                                        let newTarget = min(document.layers.count - 1, layerIndex + slots)
                                        targetLayerIndex = newTarget
                                    } else if dragDistance > rowHeight/2 {
                                        // Dragging down (visually toward back = lower index in reversed array)
                                        let slots = Int((dragDistance + rowHeight/2) / rowHeight)
                                        let newTarget = max(2, layerIndex - slots)
                                        targetLayerIndex = newTarget
                                    } else {
                                        targetLayerIndex = nil
                                    }
                                }
                                .onEnded { value in
                                    withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8)) {
                                        dragOffset = .zero
                                    }

                                    // Use the targetLayerIndex that was calculated during drag
                                    if let target = targetLayerIndex,
                                       let source = draggedLayerIndex,
                                       target != source && target >= 2 {
                                        print("✅ Moving layer from \(source) to \(target)")
                                        document.moveLayer(from: source, to: target)
                                    }

                                    draggedLayerIndex = nil
                                    targetLayerIndex = nil
                                }
                            : nil
                        )
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func layerColor(for index: Int) -> Color {
        let colors: [Color] = [.gray, .blue, .green, .orange, .purple, .red, .pink, .yellow, .cyan]
        return colors[index % colors.count]
    }
    

    
    private func layerRowContent(for layerIndex: Int) -> some View {
        ProfessionalLayerRow(
            layerIndex: layerIndex,
            layer: layerIndex < document.layers.count ? document.layers[layerIndex] : document.layers[0],
            document: document
        )
    }
} 
