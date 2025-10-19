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
    @State private var isExpanded: Bool
    @State private var layerObjects: [VectorObject] = []
    @State private var previewOpacity: Double? = nil
    @State private var selectionAnchorID: UUID? = nil
    @State private var selectionRangeMin: Int? = nil
    @State private var selectionRangeMax: Int? = nil

    private var isVisibleBinding: Binding<Bool> {
        Binding(
            get: { document.layers[layerIndex].isVisible },
            set: { newValue in
                if document.layers[layerIndex].isVisible != newValue {
                    document.layers[layerIndex].isVisible = newValue
                    document.changeNotifier.notifyLayersChanged()
                }
            }
        )
    }

    private var isLockedBinding: Binding<Bool> {
        Binding(
            get: { document.layers[layerIndex].isLocked },
            set: { newValue in
                if document.layers[layerIndex].isLocked != newValue {
                    document.layers[layerIndex].isLocked = newValue
                    document.changeNotifier.notifyLayersChanged()
                }
            }
        )
    }

    init(layerIndex: Int, layer: VectorLayer, document: VectorDocument) {
        self.layerIndex = layerIndex
        self.layer = layer
        self.document = document

        if layerIndex <= 1 {
            _isExpanded = State(initialValue: document.settings.layerExpansionState[layer.id] ?? false)
        } else {
            _isExpanded = State(initialValue: document.settings.layerExpansionState[layer.id] ?? true)
        }

        _layerObjects = State(initialValue: Array(document.unifiedObjects
            .filter { $0.layerIndex == layerIndex }
            .reversed()))
    }

    private func setExpanded(_ value: Bool) {
        isExpanded = value
        var updatedSettings = document.settings
        updatedSettings.layerExpansionState[layer.id] = value
        document.settings = updatedSettings
    }

    private var layerColor: Binding<Color> {
        Binding(
            get: { document.layers[layerIndex].color },
            set: { newColor in
                document.layers[layerIndex].color = newColor
                document.changeNotifier.notifyLayersChanged()
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
                                if !document.viewState.isDraggingVisibility {
                                    document.viewState.isDraggingVisibility = true
                                    document.processedLayersDuringDrag.removeAll()
                                    document.layers[layerIndex].isVisible.toggle()
                                    document.processedLayersDuringDrag.insert(layerIndex)
                                    document.changeNotifier.notifyLayersChanged()
                                }
                            }
                            .onEnded { _ in
                                document.viewState.isDraggingVisibility = false
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
                                if !document.viewState.isDraggingLock {
                                    document.viewState.isDraggingLock = true
                                    document.processedLayersDuringDrag.removeAll()
                                    document.layers[layerIndex].isLocked.toggle()
                                    document.processedLayersDuringDrag.insert(layerIndex)
                                    document.changeNotifier.notifyLayersChanged()
                                }
                            }
                            .onEnded { _ in
                                document.viewState.isDraggingLock = false
                                document.processedLayersDuringDrag.removeAll()
                            }
                    )
                    
                    HStack(spacing: 4) {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                if NSEvent.modifierFlags.contains(.option) {
                                    var updatedSettings = document.settings
                                    let shouldExpand = !isExpanded
                                    for layer in document.layers {
                                        updatedSettings.layerExpansionState[layer.id] = shouldExpand
                                    }
                                    document.settings = updatedSettings
                                } else {
                                    setExpanded(!isExpanded)
                                }
                            }
                        }) {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                                .rotationEffect(.degrees(0))
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
                                        DispatchQueue.main.async {
                                            showColorPicker = false
                                        }
                                    }) {
                                        HStack(spacing: 6) {
                                            RoundedRectangle(cornerRadius: 20)
                                                .fill(colorOption.color)
                                                .padding(.horizontal, -3)
                                                .frame(width: 14, height: 16)
                                            Text(colorOption.name)
                                                .layerLabel()
                                        }
                                        .offset(x: 1)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 15)
                            .padding(.vertical, 10)
                        }
                        
                        HStack(spacing: 0) {
                            if isEditingName {
                                TextField("Layer Name", text: $editedName, onCommit: {
                                    if !editedName.isEmpty {
                                        document.layers[layerIndex].name = editedName
                                        document.changeNotifier.notifyLayersChanged()
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
                        document.viewState.selectedObjectIDs.removeAll()
                    }
                }
                .padding(.horizontal, 4)
            }

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(layerObjects, id: \.id) { unifiedObject in
                        let index = layerObjects.firstIndex(where: { $0.id == unifiedObject.id }) ?? 0
                        let isLast = index == layerObjects.count - 1
                        switch unifiedObject.objectType {
                        case .text(let shape):
                            ObjectRow(
                                objectType: .text,
                                objectId: shape.id,
                                name: shape.textContent?.isEmpty != false ? "Text" : (shape.textContent ?? "Text"),
                                isSelected: document.viewState.selectedObjectIDs.contains(unifiedObject.id),
                                onSelect: { isShiftPressed, isCommandPressed in
                                    handleObjectSelection(unifiedObject.id, layerIndex: layerIndex, isShiftPressed: isShiftPressed, isCommandPressed: isCommandPressed)
                                },
                                layerIndex: layerIndex,
                                document: document,
                                showBottomIndicator: isLast
                            )
                            .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .move(edge: .top).combined(with: .opacity)))
                        case .group(let shape),
                             .clipGroup(let shape):
                            ObjectRow(
                                objectType: .group,
                                objectId: shape.id,
                                name: shape.name,
                                isSelected: document.viewState.selectedObjectIDs.contains(unifiedObject.id),
                                onSelect: { isShiftPressed, isCommandPressed in
                                    handleObjectSelection(unifiedObject.id, layerIndex: layerIndex, isShiftPressed: isShiftPressed, isCommandPressed: isCommandPressed)
                                },
                                layerIndex: layerIndex,
                                document: document,
                                groupedShapes: shape.groupedShapes,
                                showBottomIndicator: isLast
                            )
                            .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .move(edge: .top).combined(with: .opacity)))
                        case .shape(let shape),
                             .warp(let shape),
                             .clipMask(let shape):
                            ObjectRow(
                                objectType: .shape,
                                objectId: shape.id,
                                name: shape.name,
                                isSelected: document.viewState.selectedObjectIDs.contains(unifiedObject.id),
                                onSelect: { isShiftPressed, isCommandPressed in
                                    handleObjectSelection(unifiedObject.id, layerIndex: layerIndex, isShiftPressed: isShiftPressed, isCommandPressed: isCommandPressed)
                                },
                                layerIndex: layerIndex,
                                document: document,
                                showBottomIndicator: isLast
                            )
                            .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .move(edge: .top).combined(with: .opacity)))
                        }
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.9), value: layerObjects.map { $0.id })
            }
        }
        .onAppear {
            layerObjects = Array(document.unifiedObjects
                .filter { $0.layerIndex == layerIndex }
                .reversed())
        }
        .onChange(of: document.changeNotifier.changeToken) { _, _ in
            layerObjects = Array(document.unifiedObjects
                .filter { $0.layerIndex == layerIndex }
                .reversed())
        }
        .background(
            Group {
                if document.selectedLayerIndex == layerIndex {
                    Color.clear.onReceive(NotificationCenter.default.publisher(for: Notification.Name("LayerOpacityUpdate"))) { notification in
                        print("📥 RECEIVE: Layer \(layer.name)")
                        guard let userInfo = notification.userInfo,
                              let layerID = userInfo["layerID"] as? UUID,
                              layerID == layer.id else {
                            print("   ❌ Layer ID mismatch")
                            return
                        }

                        if let opacity = userInfo["opacity"] as? Double {
                            print("   ✅ Setting layer opacity to \(opacity)")
                            document.layers[layerIndex].opacity = opacity
                        }
                    }
                }
            }
        )
        .if(layer.name != "Canvas" && layer.name != "Pasteboard") { view in
            view.draggable(DraggableItem.layer(
                DraggableLayer(
                    layerIndex: layerIndex,
                    layerId: layer.id
                )
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
            case .layer(let draggableLayer):
                let droppedLayerId = draggableLayer.layerId

                if droppedLayerId == layer.id {
                    return false
                }

                let targetLayerId: UUID
                if layerIndex <= 1 {
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

            case .vectorObject(let vectorObj):
                if document.viewState.selectedObjectIDs.contains(vectorObj.objectId) && document.viewState.selectedObjectIDs.count > 1 {
                    document.moveObjectsToLayer(objectIds: Array(document.viewState.selectedObjectIDs), targetLayerIndex: layerIndex)
                } else {
                    document.moveObjectToLayer(objectId: vectorObj.objectId, targetLayerIndex: layerIndex)
                }
                return true
            }
        }
        .background(Color.clear)
    }

    private func handleObjectSelection(_ objectID: UUID, layerIndex: Int, isShiftPressed: Bool, isCommandPressed: Bool) {
        guard document.findObject(by: objectID) != nil else { return }

        document.selectedLayerIndex = layerIndex

        if isCommandPressed {
            if document.viewState.selectedObjectIDs.contains(objectID) {
                document.viewState.selectedObjectIDs.remove(objectID)
            } else {
                document.viewState.selectedObjectIDs.insert(objectID)
            }
        } else if isShiftPressed {
            if let anchorID = selectionAnchorID {
                let currentLayerObjects = Array(document.unifiedObjects
                    .filter { $0.layerIndex == layerIndex }
                    .reversed())

                if let anchorIndex = currentLayerObjects.firstIndex(where: { $0.id == anchorID }),
                   let clickedIndex = currentLayerObjects.firstIndex(where: { $0.id == objectID }) {

                    let currentMin = selectionRangeMin ?? anchorIndex
                    let currentMax = selectionRangeMax ?? anchorIndex

                    let newMin = min(currentMin, clickedIndex)
                    let newMax = max(currentMax, clickedIndex)

                    selectionRangeMin = newMin
                    selectionRangeMax = newMax

                    let rangeObjects = currentLayerObjects[newMin...newMax]
                    let rangeIDs = Set(rangeObjects.map { $0.id })

                    document.viewState.selectedObjectIDs = rangeIDs
                } else {
                    document.viewState.selectedObjectIDs.insert(objectID)
                }
            } else {
                document.viewState.selectedObjectIDs.insert(objectID)
                selectionAnchorID = objectID
            }
        } else {
            document.viewState.selectedObjectIDs = [objectID]
            selectionAnchorID = objectID
            selectionRangeMin = nil
            selectionRangeMax = nil
        }
    }
}
