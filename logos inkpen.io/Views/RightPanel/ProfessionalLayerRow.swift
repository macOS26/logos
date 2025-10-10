//
//  ProfessionalLayerRow.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI
import Combine

struct ProfessionalLayerRow: View {
    let layerIndex: Int
    let layer: VectorLayer
    @ObservedObject var document: VectorDocument
    @State private var isEditingName: Bool = false
    @State private var editedName: String = ""
    @State private var showColorPicker: Bool = false


    // CRITICAL: Use document settings for layer expansion state (persists across tab switches)
    private var isExpanded: Bool {
        document.settings.layerExpansionState[layer.id] ?? true // Default to expanded
    }

    private func setExpanded(_ value: Bool) {
        document.settings.layerExpansionState[layer.id] = value
        document.onSettingsChanged()
    }

    // CRITICAL: Computed binding for layer color to ensure SwiftUI reactivity
    private var layerColor: Binding<Color> {
        Binding(
            get: { document.layers[layerIndex].color },
            set: { newColor in
                document.saveToUndoStack()
                document.layers[layerIndex].color = newColor
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Layer Header with Adobe Illustrator Layout - Icons OUTSIDE main button
            HStack(spacing: 2) {
                // First Column: Visibility Toggle (Eye Icon) - Simple button
                Button(action: {
                    document.saveToUndoStack()
                    document.layers[layerIndex].isVisible.toggle()
                }) {
                    Image(systemName: layer.isVisible ? "eye" : "eye.slash")
                        .font(.system(size: 11))
                        .foregroundColor(layer.isVisible ? .primary : .secondary.opacity(0.3))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(BorderlessButtonStyle())
                .help(layer.isVisible ? "Hide Layer" : "Show Layer")

                // Second Column: Lock Toggle - Simple button
                Button(action: {
                    document.saveToUndoStack()
                    document.layers[layerIndex].isLocked.toggle()
                }) {
                    Image(systemName: layer.isLocked ? "lock.fill" : "lock.open")
                        .font(.system(size: 10))
                        .foregroundColor(layer.isLocked ? .orange : .secondary.opacity(0.3))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(BorderlessButtonStyle())
                .help(layer.isLocked ? "Unlock Layer" : "Lock Layer")

                // MAIN LAYER BUTTON - Separate from eye/lock icons
                HStack(spacing: 4) {
                    // Disclosure Triangle
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            setExpanded(!isExpanded)
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

                // Layer Color Indicator (Professional Color Strip) - Clickable with color picker
                Button(action: {
                    showColorPicker = true
                }) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(layerColor.wrappedValue) // Use binding for SwiftUI reactivity
                        .frame(width: 4, height: 16)
                }
                .buttonStyle(PlainButtonStyle())
                .popover(isPresented: $showColorPicker, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(availableLayerColors(), id: \.name) { colorOption in
                            Button(action: {
                                layerColor.wrappedValue = colorOption.color // Use binding setter
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

                // Layer Name and Info
                VStack(alignment: .leading, spacing: 1) {
                    // Primary name - editable on double-click
                    if isEditingName {
                        TextField("Layer Name", text: $editedName, onCommit: {
                            // Save the new name
                            if !editedName.isEmpty {
                                document.saveToUndoStack()
                                document.layers[layerIndex].name = editedName
                            }
                            isEditingName = false
                        })
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                        .onAppear {
                            editedName = layer.name
                        }
                    } else {
                        Text(layer.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.primary)
                            .onTapGesture(count: 2) {
                                isEditingName = true
                                editedName = layer.name
                            }
                    }

                    // Object count info (Professional Detail)
                    let objectCount = document.unifiedObjects.filter { $0.layerIndex == layerIndex }.count
                    Text("\(objectCount) objects")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.8))
                }

                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
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
            }
            .padding(.horizontal, 4)
            .dropDestination(for: DraggableVectorObject.self) { items, location in
                // Handle dropping objects onto this layer
                guard let droppedObject = items.first else { return false }

                // Don't allow dropping on the same layer
                if droppedObject.sourceLayerIndex == layerIndex {
                    return false
                }

                // Move the object to this layer
                document.moveObjectToLayer(objectId: droppedObject.objectId, targetLayerIndex: layerIndex)
                return true
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
                            } else if shape.isGroupContainer {
                                // Handle groups
                                ObjectRow(
                                    objectType: .group,
                                    objectId: shape.id,
                                    name: shape.name,
                                    isSelected: document.selectedObjectIDs.contains(unifiedObject.id),
                                    isVisible: shape.isVisible,
                                    isLocked: shape.isLocked,
                                    onSelect: { isShiftPressed, isCommandPressed in
                                        handleObjectSelection(unifiedObject.id, layerIndex: layerIndex, isShiftPressed: isShiftPressed, isCommandPressed: isCommandPressed)
                                    },
                                    layerIndex: layerIndex,
                                    document: document,
                                    groupedShapes: shape.groupedShapes
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

                    // Drop zone at bottom of layer for reordering to the end
                    BottomDropZone(layerIndex: layerIndex, document: document)
                }
                .padding(.leading, 20) // Indent objects under layer
            }
        }
        .background(Color.clear)
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
        
    }
}

// MARK: - Bottom Drop Zone for Layer Object Reordering
struct BottomDropZone: View {
    let layerIndex: Int
    @ObservedObject var document: VectorDocument
    @State private var isDropTarget = false

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: 8)
            .dropDestination(for: DraggableVectorObject.self) { items, location in
                // Handle dropping objects at the end of the layer
                guard let droppedObject = items.first else { return false }

                // Only allow reordering within the same layer
                if droppedObject.sourceLayerIndex != layerIndex {
                    return false
                }

                // Find the object with the lowest orderID in this layer
                let layerObjects = document.unifiedObjects.filter { $0.layerIndex == layerIndex }
                guard let lowestOrderID = layerObjects.map({ $0.orderID }).min() else { return false }

                // Move the dropped object to the bottom (one below the current lowest)
                if let objectIndex = document.unifiedObjects.firstIndex(where: { $0.id == droppedObject.objectId }) {
                    let object = document.unifiedObjects[objectIndex]
                    let newOrderID = lowestOrderID - 1

                    // Update the object with new orderID
                    if case .shape(let shape) = object.objectType {
                        document.unifiedObjects[objectIndex] = VectorObject(
                            shape: shape,
                            layerIndex: layerIndex,
                            orderID: newOrderID
                        )
                    }

                    document.objectWillChange.send()
                    return true
                }

                return false
            } isTargeted: { isTargeted in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isDropTarget = isTargeted
                }
            }
            .overlay(alignment: .top) {
                // Drop indicator line
                if isDropTarget {
                    Rectangle()
                        .fill(Color.blue)
                        .frame(height: 2)
                        .transition(.opacity)
                }
            }
    }
}
