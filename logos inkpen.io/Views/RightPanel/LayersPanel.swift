//
//  LayersPanel.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

// PROFESSIONAL LAYERS PANEL (Adobe Illustrator Style)
struct LayersPanel: View {
    @ObservedObject var document: VectorDocument
    @State private var expandedLayers: Set<Int> = []
    @State private var renamingLayerIndex: Int?
    @State private var newLayerName: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            layersHeader
            Divider().padding(.horizontal, 8)
            layersScrollContent
            Spacer()
        }
    }
    
    private var layersHeader: some View {
        HStack {
            Text("Layers")
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
            Button(action: {
                document.addLayer(name: "New Layer")
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(PlainButtonStyle())
            .help("Add New Layer")
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }
    
    private var layersScrollContent: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 0) {
                // Layer rows
                ForEach(Array(document.layers.indices.reversed().enumerated()), id: \.element) { visualIndex, layerIndex in
                    layerRowContent(for: layerIndex)
                }
            }
            .padding(.horizontal, 4)
        }
    }
    

    
    private func layerRowContent(for layerIndex: Int) -> some View {
        ProfessionalLayerRow(
            document: document,
            layerIndex: layerIndex,
            isExpanded: expandedLayers.contains(layerIndex),
            isRenaming: renamingLayerIndex == layerIndex,
            newLayerName: $newLayerName,
            onToggleExpanded: {
                if expandedLayers.contains(layerIndex) {
                    expandedLayers.remove(layerIndex)
                } else {
                    expandedLayers.insert(layerIndex)
                }
            },
            onStartRename: {
                renamingLayerIndex = layerIndex
                newLayerName = document.layers[layerIndex].name
            },
            onFinishRename: {
                if !newLayerName.isEmpty {
                    document.renameLayer(at: layerIndex, to: newLayerName)
                }
                renamingLayerIndex = nil
                newLayerName = ""
            },
            onCancelRename: {
                renamingLayerIndex = nil
                newLayerName = ""
            }
        )
    }
} 