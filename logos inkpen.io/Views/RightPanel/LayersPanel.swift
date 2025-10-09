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
                ForEach((0..<document.layers.count).reversed().map{$0}, id: \.self) { (layerIndex: Int) in
                    VStack(spacing: 0) {
                        // Layer row content
                        layerRowContent(for: layerIndex)
                        .offset(draggedLayerIndex == layerIndex ? dragOffset : .zero)
                        .opacity(draggedLayerIndex == layerIndex ? 0.8 : 1.0)
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

                                    let rowHeight: CGFloat = 45
                                    let dragDistance = value.translation.height

                                    if abs(dragDistance) < rowHeight/2 {
                                        targetLayerIndex = nil
                                    } else if dragDistance < 0 {
                                        // Dragging UP (visually) = higher index
                                        let slots = Int(abs(dragDistance) / rowHeight)
                                        targetLayerIndex = min(document.layers.count - 1, layerIndex + slots)
                                    } else {
                                        // Dragging DOWN (visually) = lower index
                                        let slots = Int(abs(dragDistance) / rowHeight)
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
