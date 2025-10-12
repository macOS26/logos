import SwiftUI
import Combine
import AppKit

struct ProfessionalLayerRow: View {
    let layerIndex: Int
    let layer: VectorLayer
    @ObservedObject var document: VectorDocument
    @State private var isEditingName: Bool = false
    @State private var editedName: String = ""
    @State private var showColorPicker: Bool = false

    private var isVisibleBinding: Binding<Bool> {
        Binding(
            get: { document.layers[layerIndex].isVisible },
            set: { newValue in
                if document.layers[layerIndex].isVisible != newValue {
                    document.saveToUndoStack()
                    document.layers[layerIndex].isVisible = newValue
                }
            }
        )
    }

    private var isLockedBinding: Binding<Bool> {
        Binding(
            get: { document.layers[layerIndex].isLocked },
            set: { newValue in
                if document.layers[layerIndex].isLocked != newValue {
                    document.saveToUndoStack()
                    document.layers[layerIndex].isLocked = newValue
                }
            }
        )
    }

    private var isExpanded: Bool {
        if layerIndex <= 1 {
            return document.settings.layerExpansionState[layer.id] ?? false
        }
        return document.settings.layerExpansionState[layer.id] ?? true
    }

    private func setExpanded(_ value: Bool) {
        document.settings.layerExpansionState[layer.id] = value
        document.onSettingsChanged()
    }

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
            ZStack(alignment: .bottom) {
                HStack(spacing: 2) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 21, height: 1)
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 19, height: 1)
                    
                    Spacer()
                }
                .padding(.leading, 2.5)
                .padding(.trailing, 4)
                
                HStack(spacing: 2) {
                    Button(action: {
                        isVisibleBinding.wrappedValue.toggle()
                    }) {
                        Image(systemName: isVisibleBinding.wrappedValue ? "eye" : "eye.slash")
                            .font(.system(size: 11))
                            .foregroundColor(isVisibleBinding.wrappedValue ? .primary : .secondary.opacity(0.3))
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .help(isVisibleBinding.wrappedValue ? "Hide Layer" : "Show Layer")
                    .gesture(
                        DragGesture(minimumDistance: 5)
                            .onChanged { _ in
                                if !document.isDraggingVisibility {
                                    document.isDraggingVisibility = true
                                    document.processedLayersDuringDrag.removeAll()
                                    document.saveToUndoStack()
                                    document.layers[layerIndex].isVisible.toggle()
                                    document.processedLayersDuringDrag.insert(layerIndex)
                                }
                            }
                            .onEnded { _ in
                                document.isDraggingVisibility = false
                                document.processedLayersDuringDrag.removeAll()
                            }
                    )
                    
                    Button(action: {
                        isLockedBinding.wrappedValue.toggle()
                    }) {
                        Image(systemName: isLockedBinding.wrappedValue ? "lock.fill" : "lock.open")
                            .font(.system(size: 10))
                            .foregroundColor(isLockedBinding.wrappedValue ? .orange : .secondary.opacity(0.3))
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .help(isLockedBinding.wrappedValue ? "Unlock Layer" : "Lock Layer")
                    .gesture(
                        DragGesture(minimumDistance: 5)
                            .onChanged { _ in
                                if !document.isDraggingLock {
                                    document.isDraggingLock = true
                                    document.processedLayersDuringDrag.removeAll()
                                    document.saveToUndoStack()
                                    document.layers[layerIndex].isLocked.toggle()
                                    document.processedLayersDuringDrag.insert(layerIndex)
                                }
                            }
                            .onEnded { _ in
                                document.isDraggingLock = false
                                document.processedLayersDuringDrag.removeAll()
                            }
                    )
                    
                    HStack(spacing: 4) {
                        Button(action: {
                            if NSEvent.modifierFlags.contains(.option) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    let shouldExpand = !isExpanded
                                    for layer in document.layers {
                                        document.settings.layerExpansionState[layer.id] = shouldExpand
                                    }
                                    document.onSettingsChanged()
                                }
                            } else {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    setExpanded(!isExpanded)
                                }
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
                        .help("Click to expand/collapse layer. Option-click to expand/collapse all layers.")
                        
                        Button(action: {
                            showColorPicker = true
                        }) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(layerColor.wrappedValue)
                                .frame(width: 4, height: 16)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .popover(isPresented: $showColorPicker, arrowEdge: .bottom) {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(Color.layerColorPalette, id: \.name) { colorOption in
                                    Button(action: {
                                        layerColor.wrappedValue = colorOption.color
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
                        
                        HStack(spacing: 0) {
                            if isEditingName {
                                TextField("Layer Name", text: $editedName, onCommit: {
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
                            
                            Spacer()
                            
                            let objectCount = document.unifiedObjects.filter { $0.layerIndex == layerIndex }.count
                            Text("\(objectCount)")
                                .font(.system(size: 9))
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(.secondary.opacity(0.8))
                                .padding(.trailing, 4)
                        }
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
                        document.selectedShapeIDs.removeAll()
                        document.selectedObjectIDs.removeAll()
                        document.selectedTextIDs.removeAll()
                        document.syncSelectionArrays()
                    }
                }
                .padding(.horizontal, 4)
            }
            
            let layerObjects = document.unifiedObjects
                .filter { $0.layerIndex == layerIndex }
                .sorted { $0.orderID > $1.orderID }
            
            if isExpanded && !layerObjects.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(layerObjects.enumerated()), id: \.element.id) { index, unifiedObject in
                        switch unifiedObject.objectType {
                        case .shape(let shape):
                            let isLast = index == layerObjects.count - 1
                            if shape.isTextObject {
                                ObjectRow(
                                    objectType: .text,
                                    objectId: shape.id,
                                    name: shape.textContent?.isEmpty != false ? "Text" : (shape.textContent ?? "Text"),
                                    isSelected: document.selectedObjectIDs.contains(unifiedObject.id),
                                    onSelect: { isShiftPressed, isCommandPressed in
                                        handleObjectSelection(unifiedObject.id, layerIndex: layerIndex, isShiftPressed: isShiftPressed, isCommandPressed: isCommandPressed)
                                    },
                                    layerIndex: layerIndex,
                                    document: document,
                                    showBottomIndicator: isLast
                                )
                            } else if shape.isGroupContainer {
                                ObjectRow(
                                    objectType: .group,
                                    objectId: shape.id,
                                    name: shape.name,
                                    isSelected: document.selectedObjectIDs.contains(unifiedObject.id),
                                    onSelect: { isShiftPressed, isCommandPressed in
                                        handleObjectSelection(unifiedObject.id, layerIndex: layerIndex, isShiftPressed: isShiftPressed, isCommandPressed: isCommandPressed)
                                    },
                                    layerIndex: layerIndex,
                                    document: document,
                                    groupedShapes: shape.groupedShapes,
                                    showBottomIndicator: isLast
                                )
                            } else {
                                ObjectRow(
                                    objectType: .shape,
                                    objectId: shape.id,
                                    name: shape.name,
                                    isSelected: document.selectedObjectIDs.contains(unifiedObject.id),
                                    onSelect: { isShiftPressed, isCommandPressed in
                                        handleObjectSelection(unifiedObject.id, layerIndex: layerIndex, isShiftPressed: isShiftPressed, isCommandPressed: isCommandPressed)
                                    },
                                    layerIndex: layerIndex,
                                    document: document,
                                    showBottomIndicator: isLast
                                )
                            }
                        }
                    }
                }
            }
        }
        .if(layer.name != "Canvas" && layer.name != "Pasteboard") { view in
            view.draggable(DraggableItem.layer(
                layerIndex: layerIndex,
                layerId: layer.id
            )) {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(layerColor.wrappedValue)
                        .frame(width: 4, height: 16)
                    Text(layer.name)
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(6)
                .opacity(0.9)
            }
        }
        .dropDestination(for: DraggableItem.self) { items, location in
            guard let droppedItem = items.first else { return false }

            switch droppedItem {
            case .layer(let droppedLayerIndex, let droppedLayerId):
                // Don't allow dropping on self
                if droppedLayerId == layer.id {
                    return false
                }

                // If trying to drop at indices 0 or 1, redirect to index 2 (first allowed position)
                let targetLayerId: UUID
                if layerIndex <= 1 {
                    // Place at index 2 (above Canvas/Pasteboard)
                    if document.layers.count > 2 {
                        targetLayerId = document.layers[2].id
                    } else {
                        return false
                    }
                } else {
                    targetLayerId = layer.id
                }

                document.reorderLayer(sourceLayerId: droppedLayerId, targetLayerId: targetLayerId)
                return true

            case .vectorObject(_, let objectId, _):
                // Move object to this layer
                document.moveObjectToLayer(objectId: objectId, targetLayerIndex: layerIndex)
                return true
            }
        }
        .background(Color.clear)
    }


    private func handleObjectSelection(_ objectID: UUID, layerIndex: Int, isShiftPressed: Bool, isCommandPressed: Bool) {
        guard document.findObject(by: objectID) != nil else { return }

        document.selectedLayerIndex = layerIndex

        if isCommandPressed {
            if document.selectedObjectIDs.contains(objectID) {
                document.selectedObjectIDs.remove(objectID)
            } else {
                document.selectedObjectIDs.insert(objectID)
            }
        } else if isShiftPressed {
            document.selectedObjectIDs.insert(objectID)
        } else {
            document.selectedObjectIDs = [objectID]
        }

        document.syncSelectionArrays()

    }
}
