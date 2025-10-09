//
//  LayersPanel.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI
import UniformTypeIdentifiers

        // PROFESSIONAL LAYERS PANEL (Professional Style)
struct LayersPanel: View {
    @ObservedObject var document: VectorDocument
    @State private var expandedLayers: Set<Int> = []
    @State private var renamingLayerIndex: Int?
    @State private var newLayerName: String = ""
    
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
                            document.saveToUndoStack()
                            document.layers[layerIndex].opacity = newValue
                        }
                    ),
                    in: 0...1
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
                        document.saveToUndoStack()
                        document.layers[layerIndex].blendMode = newValue
                    }
                )) {
                    ForEach(BlendMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    private var layersScrollContent: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 0) {
                // Layer rows with drag and drop
                ForEach(Array(document.layers.indices.reversed().enumerated()), id: \.element) { visualIndex, layerIndex in
                    layerRowContent(for: layerIndex)
                        .onDrag {
                            // Only allow dragging non-protected layers
                            if layerIndex > 1 { // Protect Pasteboard (0) and Canvas (1)
                                return NSItemProvider(object: String(layerIndex) as NSString)
                            }
                            return NSItemProvider()
                        }
                        .onDrop(of: [.text], delegate: LayerDropDelegate(
                            document: document,
                            targetLayerIndex: layerIndex,
                            layers: document.layers
                        ))
                }
            }
            .padding(.horizontal, 4)
        }
    }
    

    
    private func layerRowContent(for layerIndex: Int) -> some View {
        ProfessionalLayerRow(
            layerIndex: layerIndex,
            layer: layerIndex < document.layers.count ? document.layers[layerIndex] : document.layers[0],
            document: document
        )
    }
}

// MARK: - Layer Drop Delegate for Reordering
struct LayerDropDelegate: DropDelegate {
    let document: VectorDocument
    let targetLayerIndex: Int
    let layers: [VectorLayer]

    func performDrop(info: DropInfo) -> Bool {
        guard let item = info.itemProviders(for: [.text]).first else {
            return false
        }

        item.loadItem(forTypeIdentifier: "public.text", options: nil) { (data, error) in
            if let data = data as? Data,
               let sourceIndexString = String(data: data, encoding: .utf8),
               let sourceIndex = Int(sourceIndexString) {

                DispatchQueue.main.async {
                    // Don't allow moving protected layers
                    if sourceIndex <= 1 || targetLayerIndex <= 1 {
                        return
                    }

                    // Perform the layer move
                    document.moveLayer(from: sourceIndex, to: targetLayerIndex)
                }
            }
        }

        return true
    }

    func validateDrop(info: DropInfo) -> Bool {
        // Only allow dropping on non-protected layers
        return targetLayerIndex > 1 && info.hasItemsConforming(to: [.text])
    }
} 
