import SwiftUI
import UniformTypeIdentifiers
import Combine

// Shared layer color palette
extension Color {
    static let layerColorPalette: [(name: String, color: Color)] = [
        ("Maroon", Color(.displayP3, red: 0.75, green: 0.2, blue: 0.2)),
        ("Red", Color.red),
        ("Vermillion", Color(.displayP3, red: 0.8, green: 0.38, blue: 0.2)),
        ("Rust", Color(.displayP3, red: 0.85, green: 0.5, blue: 0.15)),
        ("Orange", Color.orange),
        ("Amber", Color(.displayP3, red: 0.82, green: 0.62, blue: 0.2)),
        ("Yellow", Color.yellow),
        ("Chartreuse", Color(.displayP3, red: 0.55, green: 0.72, blue: 0.2)),
        ("Lime", Color(.displayP3, red: 0.4, green: 0.68, blue: 0.28)),
        ("Green", Color.green),
        ("Emerald", Color(.displayP3, red: 0.2, green: 0.65, blue: 0.3)),
        ("Spring", Color(.displayP3, red: 0.2, green: 0.68, blue: 0.5)),
        ("Ocean", Color(.displayP3, red: 0.15, green: 0.65, blue: 0.72)),
        ("Cyan", Color.cyan),
        ("Sky", Color(.displayP3, red: 0.32, green: 0.58, blue: 0.82)),
        ("Blue", Color.blue),
        ("Azure", Color(.displayP3, red: 0.18, green: 0.4, blue: 0.78)),
        ("Indigo", Color(.displayP3, red: 0.2, green: 0.25, blue: 0.75)),
        ("Violet", Color(.displayP3, red: 0.4, green: 0.25, blue: 0.7)),
        ("Orchid", Color(.displayP3, red: 0.55, green: 0.25, blue: 0.65)),
        ("Purple", Color.purple),
        ("Magenta", Color(.displayP3, red: 0.7, green: 0.2, blue: 0.5)),
        ("Pink", Color.pink),
        ("Rose", Color(.displayP3, red: 0.8, green: 0.3, blue: 0.4)),
        ("Gray", Color.gray)
    ]
}

struct LayerLabelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 11))
            .foregroundColor(.secondary)
    }
}

struct LayerControlLabelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .frame(width: 50, alignment: .leading)
    }
}

struct LayerPercentageStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .frame(width: 35, alignment: .trailing)
    }
}

struct DragTargetStyle: ViewModifier {
    let isActive: Bool
    
    func body(content: Content) -> some View {
        content
            .frame(width: 20, height: 20)
            .contentShape(Rectangle())
    }
}

extension View {
    func layerLabel() -> some View {
        modifier(LayerLabelStyle())
    }
    
    func layerControlLabel() -> some View {
        modifier(LayerControlLabelStyle())
    }
    
    func layerPercentage() -> some View {
        modifier(LayerPercentageStyle())
    }
    
    func dragTarget(isActive: Bool = false) -> some View {
        modifier(DragTargetStyle(isActive: isActive))
    }
}

struct LayersPanel: View {
    @ObservedObject var document: VectorDocument
    @State private var expandedLayers: Set<Int> = []
    @State private var renamingLayerIndex: Int?
    @State private var newLayerName: String = ""
    @State private var showColorPicker: Bool = false
    
    // Structure to represent each visible row in the layers panel
    private enum RowType: Hashable {
        case layer(index: Int)
        case object(layerIndex: Int, objectId: UUID)
        case childObject(layerIndex: Int, parentObjectId: UUID, childShapeId: UUID)
    }
    
    // Calculate all visible rows in display order (top to bottom)
    private var visibleRows: [RowType] {
        var rows: [RowType] = []
        
        // Iterate through layers in reverse order (as they appear in UI)
        for (layerIndex, layer) in document.layers.enumerated().reversed() {
            rows.append(.layer(index: layerIndex))
            
            // Check if layer is expanded
            let isExpanded = if layerIndex <= 1 {
                document.settings.layerExpansionState[layer.id] ?? false
            } else {
                document.settings.layerExpansionState[layer.id] ?? true
            }
            
            // Add object rows if expanded
            if isExpanded {
                let layerObjects = document.unifiedObjects
                    .filter { $0.layerIndex == layerIndex }
                    .sorted { $0.orderID > $1.orderID }

                for object in layerObjects {
                    rows.append(.object(layerIndex: layerIndex, objectId: object.id))

                    // Check if this is an expanded group and add its children
                    if case .shape(let shape) = object.objectType,
                       shape.isGroupContainer,
                       document.settings.groupExpansionState[object.id] ?? false {
                        for childShape in shape.groupedShapes {
                            rows.append(.childObject(layerIndex: layerIndex, parentObjectId: object.id, childShapeId: childShape.id))
                        }
                    }
                }
            }
        }
        
        return rows
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            layersHeader
            Divider().padding(.horizontal, 6.5)
            
            if let selectedIndex = document.selectedLayerIndex, selectedIndex < document.layers.count {
                layerControlsSection(for: selectedIndex)
                Divider().padding(.horizontal, 6.5)
                    .frame(width: 55)
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
            HStack(spacing: 8) {
                Text("Opacity")
                    .layerControlLabel()
                
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
                    .layerPercentage()
            }
            
            HStack(spacing: 8) {
                Text("Blend")
                    .layerControlLabel()
                
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
                .frame(width: 100)
                .labelsHidden()
                .pickerStyle(.menu)
                
                Spacer(minLength: 10)
                    .frame(width: 10)
                ColorSwatchButton(
                    color: Binding(
                        get: { document.layers[layerIndex].color },
                        set: { newColor in
                            document.saveToUndoStack()
                            document.layers[layerIndex].color = newColor
                        }
                    ),
                    availableColors: Color.layerColorPalette
                )
                .offset(x:12)
                //.padding(.trailing)
                Text("Color")
                    .layerControlLabel()
                    .multilineTextAlignment(.trailing)
                    //.padding(.leading)
                    .offset(x:20)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    private var layersScrollContent: some View {
        ScrollView(.vertical, showsIndicators: true) {
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ForEach(Array(document.layers.enumerated()).reversed(), id: \.element.id) { (layerIndex, layer) in
                        layerRowContent(for: layerIndex)
                    }
                }
                .padding(.horizontal, 4)
                
                // Overlay system for eye and lock icons
                let iconSize: CGFloat = 20
                let iconSpacing: CGFloat = 2
                let rowPadding: CGFloat = 4
                
                let eyeIconX = rowPadding + (iconSize / 2)
                let lockIconX = rowPadding + iconSize + iconSpacing + (iconSize / 2)
                let rows = visibleRows
                
                // Eye icon overlay
                ZStack {
                    ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, rowType in
                        let rowY = CGFloat(rowIndex) * kLayerRowHeight
                        let iconCenterY = rowY + (kLayerRowHeight / 2)
                        
                        Color.red.opacity(0.0000000) // do not remove
                            .dragTarget()
                            .position(x: eyeIconX, y: iconCenterY)
                    }
                }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !document.isDraggingVisibility {
                                document.isDraggingVisibility = true
                                document.processedLayersDuringDrag.removeAll()
                                document.processedObjectsDuringDrag.removeAll()
                                document.saveToUndoStack()
                                
                                let startY = value.startLocation.y
                                let rowIndex = Int(startY / kLayerRowHeight)
                                
                                if rowIndex >= 0 && rowIndex < rows.count {
                                    toggleVisibility(for: rows[rowIndex])
                                }
                            }
                            
                            let currentY = value.location.y
                            let rowIndex = Int(currentY / kLayerRowHeight)
                            
                            if rowIndex >= 0 && rowIndex < rows.count {
                                toggleVisibility(for: rows[rowIndex])
                            }
                        }
                        .onEnded { _ in
                            document.isDraggingVisibility = false
                            document.processedLayersDuringDrag.removeAll()
                            document.processedObjectsDuringDrag.removeAll()
                        }
                )
                .padding(.horizontal, 4)
                
                // Lock icon overlay
                ZStack {
                    ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, rowType in
                        let rowY = CGFloat(rowIndex) * kLayerRowHeight
                        let iconCenterY = rowY + (kLayerRowHeight / 2)
                        
                        Color.red.opacity(0.0000000) // do remove
                            .dragTarget()
                            .position(x: lockIconX, y: iconCenterY)
                    }
                }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !document.isDraggingLock {
                                document.isDraggingLock = true
                                document.processedLayersDuringDrag.removeAll()
                                document.processedObjectsDuringDrag.removeAll()
                                document.saveToUndoStack()
                                
                                let startY = value.startLocation.y
                                let rowIndex = Int(startY / kLayerRowHeight)
                                
                                if rowIndex >= 0 && rowIndex < rows.count {
                                    toggleLock(for: rows[rowIndex])
                                }
                            }
                            
                            let currentY = value.location.y
                            let rowIndex = Int(currentY / kLayerRowHeight)
                            
                            if rowIndex >= 0 && rowIndex < rows.count {
                                toggleLock(for: rows[rowIndex])
                            }
                        }
                        .onEnded { _ in
                            document.isDraggingLock = false
                            document.processedLayersDuringDrag.removeAll()
                            document.processedObjectsDuringDrag.removeAll()
                        }
                )
                .padding(.horizontal, 4)
                .zIndex(200)
            }
        }
    }
    
    private func layerRowContent(for layerIndex: Int) -> some View {
        ProfessionalLayerRow(
            layerIndex: layerIndex,
            layer: layerIndex < document.layers.count ? document.layers[layerIndex] : document.layers[0],
            document: document
        )
    }
    
    // Helper function to toggle visibility for a row (layer or object)
    private func toggleVisibility(for rowType: RowType) {
        switch rowType {
        case .layer(let index):
            if !document.processedLayersDuringDrag.contains(index) {
                document.layers[index].isVisible.toggle()
                document.processedLayersDuringDrag.insert(index)
            }
        case .object(let layerIndex, let objectId):
            if !document.processedObjectsDuringDrag.contains(objectId) {
                if let object = document.findObject(by: objectId) {
                    if case .shape(var shape) = object.objectType {
                        shape.isVisible.toggle()
                        if let objIndex = document.unifiedObjects.firstIndex(where: { $0.id == objectId }) {
                            document.unifiedObjects[objIndex] = VectorObject(
                                shape: shape,
                                layerIndex: layerIndex,
                                orderID: object.orderID
                            )
                        }
                        document.processedObjectsDuringDrag.insert(objectId)
                    }
                }
            }
        case .childObject(let layerIndex, let parentObjectId, let childShapeId):
            if !document.processedObjectsDuringDrag.contains(childShapeId) {
                if let parentObject = document.findObject(by: parentObjectId) {
                    if case .shape(var parentShape) = parentObject.objectType {
                        if let childIndex = parentShape.groupedShapes.firstIndex(where: { $0.id == childShapeId }) {
                            parentShape.groupedShapes[childIndex].isVisible.toggle()
                            if let objIndex = document.unifiedObjects.firstIndex(where: { $0.id == parentObjectId }) {
                                document.unifiedObjects[objIndex] = VectorObject(
                                    shape: parentShape,
                                    layerIndex: layerIndex,
                                    orderID: parentObject.orderID
                                )
                            }
                            document.processedObjectsDuringDrag.insert(childShapeId)
                        }
                    }
                }
            }
        }
    }
    
    // Helper function to toggle lock for a row (layer or object)
    private func toggleLock(for rowType: RowType) {
        switch rowType {
        case .layer(let index):
            if !document.processedLayersDuringDrag.contains(index) {
                document.layers[index].isLocked.toggle()
                document.processedLayersDuringDrag.insert(index)
            }
        case .object(let layerIndex, let objectId):
            if !document.processedObjectsDuringDrag.contains(objectId) {
                if let object = document.findObject(by: objectId) {
                    if case .shape(var shape) = object.objectType {
                        shape.isLocked.toggle()
                        if let objIndex = document.unifiedObjects.firstIndex(where: { $0.id == objectId }) {
                            document.unifiedObjects[objIndex] = VectorObject(
                                shape: shape,
                                layerIndex: layerIndex,
                                orderID: object.orderID
                            )
                        }
                        document.processedObjectsDuringDrag.insert(objectId)
                    }
                }
            }
        case .childObject(let layerIndex, let parentObjectId, let childShapeId):
            if !document.processedObjectsDuringDrag.contains(childShapeId) {
                if let parentObject = document.findObject(by: parentObjectId) {
                    if case .shape(var parentShape) = parentObject.objectType {
                        if let childIndex = parentShape.groupedShapes.firstIndex(where: { $0.id == childShapeId }) {
                            parentShape.groupedShapes[childIndex].isLocked.toggle()
                            if let objIndex = document.unifiedObjects.firstIndex(where: { $0.id == parentObjectId }) {
                                document.unifiedObjects[objIndex] = VectorObject(
                                    shape: parentShape,
                                    layerIndex: layerIndex,
                                    orderID: parentObject.orderID
                                )
                            }
                            document.processedObjectsDuringDrag.insert(childShapeId)
                        }
                    }
                }
            }
        }
    }
}

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
    }
}
