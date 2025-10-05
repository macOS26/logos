//
//  ProfessionalLayerRow.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI

struct ProfessionalLayerRow: View {
    let layerIndex: Int
    let layer: VectorLayer
    @ObservedObject var document: VectorDocument
    @State private var isExpanded: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Layer Header with Modern Design
            HStack(spacing: 8) {
                // Disclosure Triangle
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(0))
                        .animation(.easeInOut(duration: 0.15), value: isExpanded)
                        .frame(width: 12, height: 12)
                }
                .buttonStyle(BorderlessButtonStyle())
                
                // Layer Color Indicator (Professional Color Strip)
                RoundedRectangle(cornerRadius: 2)
                    .fill(layerColor(for: layerIndex))
                    .frame(width: 4, height: 16)
                
                // Layer Name and Info
                VStack(alignment: .leading, spacing: 1) {
                    // Primary name
                    Text(layer.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                    
                    // Object count info (Professional Detail)
                    let objectCount = document.unifiedObjects.filter { $0.layerIndex == layerIndex }.count
                    Text("\(objectCount) objects")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                
                Spacer()
                
                // Layer Tools (Professional Compact Icons)
                HStack(spacing: 4) {
                    // Visibility Toggle
                    Button(action: {
                        document.saveToUndoStack()
                        document.layers[layerIndex].isVisible.toggle()
                    }) {
                        Image(systemName: layer.isVisible ? "eye" : "eye.slash")
                            .font(.system(size: 10))
                            .foregroundColor(layer.isVisible ? .secondary : .secondary.opacity(0.5))
                            .frame(width: 14, height: 14)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .help(layer.isVisible ? "Hide Layer" : "Show Layer")
                    
                    // Lock Toggle  
                    Button(action: {
                        document.saveToUndoStack()
                        document.layers[layerIndex].isLocked.toggle()
                    }) {
                        Image(systemName: layer.isLocked ? "lock.fill" : "lock.open")
                            .font(.system(size: 10))
                            .foregroundColor(layer.isLocked ? .orange : .secondary.opacity(0.5))
                            .frame(width: 14, height: 14)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .help(layer.isLocked ? "Unlock Layer" : "Lock Layer")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(document.selectedLayerIndex == layerIndex ? 
                          Color.accentColor.opacity(0.08) : 
                          Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(document.selectedLayerIndex == layerIndex ? 
                                   Color.accentColor.opacity(0.2) : 
                                   Color.clear, lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
            .onTapGesture {
                document.selectedLayerIndex = layerIndex
                // Clear shape selection when selecting layer
                document.selectedShapeIDs.removeAll()
                document.selectedObjectIDs.removeAll()
                // Clear text selection when selecting layer  
                document.selectedTextIDs.removeAll()
                document.syncSelectionArrays()
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
                            if shape.isTextObject {
                                // Handle text objects (VectorShape with isTextObject = true)
                                ObjectRow(
                                    objectType: .text,
                                    objectId: shape.id,
                                    name: shape.textContent?.isEmpty != false ? "Text" : (shape.textContent ?? "Text"),
                                    isSelected: document.selectedObjectIDs.contains(unifiedObject.id),
                                    isVisible: shape.isVisible,
                                    isLocked: shape.isLocked,
                                    onSelect: { isShiftPressed, isCommandPressed in
                                        handleObjectSelection(unifiedObject.id, layerIndex: layerIndex, isShiftPressed: isShiftPressed, isCommandPressed: isCommandPressed)
                                    },
                                    layerIndex: layerIndex,
                                    document: document
                                )
                            } else {
                                // Handle regular shapes
                                ObjectRow(
                                    objectType: .shape,
                                    objectId: shape.id,
                                    name: shape.name,
                                    isSelected: document.selectedObjectIDs.contains(unifiedObject.id),
                                    isVisible: shape.isVisible,
                                    isLocked: shape.isLocked,
                                    onSelect: { isShiftPressed, isCommandPressed in
                                        handleObjectSelection(unifiedObject.id, layerIndex: layerIndex, isShiftPressed: isShiftPressed, isCommandPressed: isCommandPressed)
                                    },
                                    layerIndex: layerIndex,
                                    document: document
                                )
                            }
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
    
    private func handleObjectSelection(_ objectID: UUID, layerIndex: Int, isShiftPressed: Bool, isCommandPressed: Bool) {
        // CRITICAL: Determine which unified object this is
        guard document.findObject(by: objectID) != nil else { return }
        
        // Set the layer as selected first
        document.selectedLayerIndex = layerIndex
        
        if isCommandPressed {
            // Command+click: toggle individual selection
            if document.selectedObjectIDs.contains(objectID) {
                document.selectedObjectIDs.remove(objectID)
            } else {
                document.selectedObjectIDs.insert(objectID)
            }
        } else if isShiftPressed {
            // Shift+click: extend selection (add to selection)
            document.selectedObjectIDs.insert(objectID)
        } else {
            // Regular click: select only this object
            document.selectedObjectIDs = [objectID]
        }
        
        // CRITICAL: Keep legacy arrays in sync with unified selection
        document.syncSelectionArrays()
        
        Log.fileOperation("🎯 LAYERS: Selected object \(objectID.uuidString.prefix(8)) in layer \(layerIndex)", level: .info)
    }
}
