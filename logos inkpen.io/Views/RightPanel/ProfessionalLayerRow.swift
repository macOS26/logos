//
//  ProfessionalLayerRow.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

// PROFESSIONAL LAYER ROW (Professional Style)
struct ProfessionalLayerRow: View {
    @ObservedObject var document: VectorDocument
    let layerIndex: Int
    let isExpanded: Bool
    let isRenaming: Bool
    @Binding var newLayerName: String
    let onToggleExpanded: () -> Void
    let onStartRename: () -> Void
    let onFinishRename: () -> Void
    let onCancelRename: () -> Void
    
    @State private var isDropTargeted = false
    
    private var layer: VectorLayer {
        // SAFE LAYER ACCESS: Prevent crash during SVG import or layer changes
        guard layerIndex >= 0 && layerIndex < document.layers.count else {
            // Return a dummy layer if index is out of bounds
            return VectorLayer(name: "Invalid Layer")
        }
        return document.layers[layerIndex]
    }
    
    private var isSelected: Bool {
        document.selectedLayerIndex == layerIndex
    }
    
    private var isCanvasLayer: Bool {
        return layerIndex == 1 && layer.name == "Canvas"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Layer Header
            HStack(spacing: 6) {
                // Expand/Collapse Triangle
                Button {
                    onToggleExpanded()
                } label: {
                    Image(systemName: isExpanded ? "arrowtriangle.down.fill" : "arrowtriangle.right.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                
            // Visibility Toggle
            Button {
                // SAFE LAYER ACCESS: Check bounds before toggling
                if layerIndex >= 0 && layerIndex < document.layers.count {
                    document.layers[layerIndex].isVisible.toggle()
                }
            } label: {
                    Image(systemName: layer.isVisible ? "eye.fill" : "eye.slash.fill")
                        .font(.system(size: 11))
                        .foregroundColor(layer.isVisible ? .blue : .secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Toggle Visibility")
            
            // Lock Toggle
            Button {
                // SAFE LAYER ACCESS: Check bounds before toggling
                if layerIndex >= 0 && layerIndex < document.layers.count {
                    document.layers[layerIndex].isLocked.toggle()
                }
            } label: {
                    Image(systemName: layer.isLocked ? "lock.fill" : "lock.open.fill")
                        .font(.system(size: 11))
                        .foregroundColor(layer.isLocked ? .orange : .secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Toggle Lock")
            
                // Layer Color Indicator
                Circle()
                    .fill(layerColor(for: layerIndex))
                    .frame(width: 12, height: 12)
            
            
            if isRenaming {
                TextField("Layer Name", text: $newLayerName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onSubmit {
                        onFinishRename()
                    }
                    .onKeyPress(.escape) {
                        onCancelRename()
                        return .handled
                    }
            } else {
                Text(layer.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isCanvasLayer ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture(count: 2) {
                        // Double-click to rename (only if not Canvas)
                        if !isCanvasLayer {
                            onStartRename()
                        }
                    }
            }
            
                // Object Count (shapes + text objects for this layer)
                let textObjectsInLayer = document.textObjects.filter { $0.layerIndex == layerIndex }.count
                let totalObjects = layer.shapes.count + textObjectsInLayer
                Text("\(totalObjects)")
                    .font(.system(size: 9))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                .background(Color.gray.opacity(0.2))
                    .cornerRadius(6)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Group {
                    if isSelected {
                        Color.blue.opacity(0.15)
                    } else if isDropTargeted {
                        Color.green.opacity(0.2)
                    } else {
                        Color.clear
                    }
                }
            )
            .scaleEffect(isDropTargeted ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isDropTargeted)
            .onTapGesture {
                // SAFE LAYER ACCESS: Check bounds before selection
                guard layerIndex >= 0 && layerIndex < document.layers.count else { return }
                
                // PROTECT CANVAS LAYER: Don't allow selection of Canvas layer when locked
                if isCanvasLayer && layer.isLocked {
                    Log.info("🚫 Cannot select locked Canvas layer", category: .general)
                    return
                }
                
                document.selectedLayerIndex = layerIndex
            }
            .dropDestination(for: DraggableVectorObject.self) { droppedObjects, location in
                for droppedObject in droppedObjects {
                    document.handleObjectDrop(droppedObject, ontoLayerIndex: layerIndex)
                }
                return true
            } isTargeted: { isTargeted in
                isDropTargeted = isTargeted
            }
            .contextMenu {
                // Context menu for layer operations
                if !isCanvasLayer {
                    Button("Rename Layer") {
                        onStartRename()
                    }
                    
                    Divider()
                    
                    Button("Duplicate Layer") {
                        document.duplicateLayer(at: layerIndex)
                    }
                    
                    Button("Delete Layer") {
                        document.removeLayer(at: layerIndex)
                    }
                    .disabled(document.layers.count <= 1)
                }
                
                Divider()
                
                Button(layer.isVisible ? "Hide Layer" : "Show Layer") {
                    document.layers[layerIndex].isVisible.toggle()
                }
                
                Button(layer.isLocked ? "Unlock Layer" : "Lock Layer") {
                    document.layers[layerIndex].isLocked.toggle()
                }
            }
            
            // Expanded Object List (Professional Style)
            if isExpanded {
                VStack(spacing: 0) {
                    // CRITICAL FIX: Use unified objects to show true intermixed order
                    let layerObjects = document.unifiedObjects
                        .filter { $0.layerIndex == layerIndex }
                        .sorted { $0.orderID > $1.orderID } // Front to back order (higher orderID = front, lower orderID = back)
                    
                    ForEach(layerObjects, id: \.id) { unifiedObject in
                        switch unifiedObject.objectType {
                        case .shape(let shape):
                            ObjectRow(
                                objectType: .shape,
                                objectId: shape.id,
                                name: shape.name,
                                isSelected: document.selectedObjectIDs.contains(unifiedObject.id),
                                isVisible: shape.isVisible,
                                isLocked: shape.isLocked,
                                onSelect: {
                                    document.selectedObjectIDs = [unifiedObject.id]
                                    document.syncSelectionArrays()
                                    document.selectedLayerIndex = layerIndex
                                },
                                layerIndex: layerIndex,
                                document: document
                            )
                        case .text(let text):
                            ObjectRow(
                                objectType: .text,
                                objectId: text.id,
                                name: text.content.isEmpty ? "Text" : text.content,
                                isSelected: document.selectedObjectIDs.contains(unifiedObject.id),
                                isVisible: text.isVisible,
                                isLocked: text.isLocked,
                                onSelect: {
                                    document.selectedObjectIDs = [unifiedObject.id]
                                    document.syncSelectionArrays()
                                    document.selectedLayerIndex = layerIndex
                                },
                                layerIndex: layerIndex,
                                document: document
                            )
                        }
                    }
                }
                .padding(.leading, 20) // Indent objects under layer
            }
        }
        .background(Color.clear)
    }
    
    private func layerColor(for index: Int) -> Color {
        let colors: [Color] = [.gray, .blue, .green, .orange, .purple, .red, .pink, .yellow, .cyan]
        return colors[index % colors.count]
    }
    
    // TEXT OBJECT COUNTING REMOVED
} 
