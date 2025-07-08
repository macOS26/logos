//
//  RightPanel.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

struct RightPanel: View {
    @ObservedObject var document: VectorDocument
    @State private var selectedTab: PanelTab = .layers
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Bar
            PanelTabBar(selectedTab: $selectedTab)
            
            // Content
            Group {
                switch selectedTab {
                case .layers:
                LayersPanel(document: document)
                case .properties:
                    StrokeFillPanel(document: document)
                case .typography:
                    TypographyPanel(document: document)
                case .color:
                ColorPanel(document: document)
                case .pathOps:
                PathOperationsPanel(document: document)
            }
        }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5),
            alignment: .leading
        )
    }
}

enum PanelTab: String, CaseIterable {
    case layers = "Layers"
    case properties = "Stroke/Fill"
    case typography = "Typography"
    case color = "Color"
    case pathOps = "Path Ops"
    
    var iconName: String {
        switch self {
        case .layers: return "square.stack"
        case .properties: return "paintbrush"
        case .typography: return "textformat"
        case .color: return "paintpalette"
        case .pathOps: return "square.grid.2x2"
        }
    }
}

struct PanelTabBar: View {
    @Binding var selectedTab: PanelTab
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(PanelTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 14))
                        Text(tab.rawValue)
                            .font(.caption2)
                    }
                    .foregroundColor(selectedTab == tab ? .blue : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selectedTab == tab ? Color.blue.opacity(0.1) : Color.clear)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5),
            alignment: .bottom
        )
    }
}

struct LayersPanel: View {
    @ObservedObject var document: VectorDocument
    @State private var expandedLayers: Set<Int> = Set([0]) // Layer 1 expanded by default
    @State private var draggedObject: DraggedObject?
    
    struct DraggedObject {
        let type: ObjectType
        let id: UUID
        let sourceLayerIndex: Int
        
        enum ObjectType {
            case shape
            case text
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Layers")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button {
                    document.addLayer()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                }
                .buttonStyle(PlainButtonStyle())
                .help("Add Layer")
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            
            // Professional Layers List (Adobe Illustrator Style)
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(document.layers.indices.reversed(), id: \.self) { layerIndex in
                        ProfessionalLayerRow(
                            document: document,
                            layerIndex: layerIndex,
                            isExpanded: expandedLayers.contains(layerIndex),
                            onToggleExpanded: {
                                if expandedLayers.contains(layerIndex) {
                                    expandedLayers.remove(layerIndex)
                                } else {
                                    expandedLayers.insert(layerIndex)
                                }
                            },
                            onObjectDrag: { objectType, objectId in
                                draggedObject = DraggedObject(
                                    type: objectType,
                                    id: objectId,
                                    sourceLayerIndex: layerIndex
                                )
                            }
                        )
                        .onDrop(of: [.text], delegate: LayerDropDelegate(
                            document: document,
                            targetLayerIndex: layerIndex,
                            draggedObject: $draggedObject
                        ))
                    }
                }
                .padding(.horizontal, 4)
            }
            
            Spacer()
        }
    }
}

// PROFESSIONAL LAYER ROW (Adobe Illustrator Style)
struct ProfessionalLayerRow: View {
    @ObservedObject var document: VectorDocument
    let layerIndex: Int
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
    let onObjectDrag: (LayersPanel.DraggedObject.ObjectType, UUID) -> Void
    
    private var layer: VectorLayer {
        document.layers[layerIndex]
    }
    
    private var isSelected: Bool {
        document.selectedLayerIndex == layerIndex
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
                    document.layers[layerIndex].isVisible.toggle()
            } label: {
                    Image(systemName: layer.isVisible ? "eye.fill" : "eye.slash.fill")
                        .font(.system(size: 11))
                        .foregroundColor(layer.isVisible ? .blue : .secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Toggle Visibility")
            
            // Lock Toggle
            Button {
                    document.layers[layerIndex].isLocked.toggle()
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
            
            // Layer Name
            Text(layer.name)
                    .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
                // Object Count
                Text("\(layer.shapes.count + objectCountInLayer(layerIndex))")
                    .font(.system(size: 9))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                .background(Color.gray.opacity(0.2))
                    .cornerRadius(6)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? Color.blue.opacity(0.15) : Color.clear)
            .onTapGesture {
                // PREVENT SELECTING CANVAS LAYER: Canvas layer should not be selectable
                if layerIndex == 0 && document.layers[layerIndex].name == "Canvas" {
                    print("🚫 Cannot select Canvas layer - it's locked for editing")
                    return
                }
                document.selectedLayerIndex = layerIndex
            }
            
            // Expanded Object List (Adobe Illustrator Style)
            if isExpanded {
                VStack(spacing: 1) {
                    // Text Objects in this layer context
                    ForEach(document.textObjects.indices, id: \.self) { textIndex in
                        let textObject = document.textObjects[textIndex]
                        ObjectRow(
                            objectType: .text,
                            objectId: textObject.id,
                            name: textObject.content.isEmpty ? "Empty Text" : String(textObject.content.prefix(20)),
                            isSelected: document.selectedTextIDs.contains(textObject.id),
                            isVisible: textObject.isVisible,
                            isLocked: textObject.isLocked,
                            onSelect: {
                                document.selectedTextIDs = [textObject.id]
                                document.selectedShapeIDs.removeAll()
                                document.selectedLayerIndex = layerIndex
                            },
                            onDrag: {
                                onObjectDrag(.text, textObject.id)
                            }
                        )
                    }
                    
                    // Shape Objects
                    ForEach(layer.shapes.indices.reversed(), id: \.self) { shapeIndex in
                        let shape = layer.shapes[shapeIndex]
                        ObjectRow(
                            objectType: .shape,
                            objectId: shape.id,
                            name: shape.name,
                            isSelected: document.selectedShapeIDs.contains(shape.id),
                            isVisible: shape.isVisible,
                            isLocked: shape.isLocked,
                            onSelect: {
                                document.selectedShapeIDs = [shape.id]
                                document.selectedTextIDs.removeAll()
                                document.selectedLayerIndex = layerIndex
                            },
                            onDrag: {
                                onObjectDrag(.shape, shape.id)
                            }
                        )
                    }
                }
                .padding(.leading, 20) // Indent objects under layer
            }
        }
        .background(Color.clear)
    }
    
    private func layerColor(for index: Int) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .red, .pink, .yellow, .cyan]
        return colors[index % colors.count]
    }
    
    private func objectCountInLayer(_ layerIndex: Int) -> Int {
        // Count text objects that conceptually belong to this layer
        return document.textObjects.filter { $0.isVisible }.count
    }
}

// PROFESSIONAL OBJECT ROW (Individual objects within layers)
struct ObjectRow: View {
    let objectType: LayersPanel.DraggedObject.ObjectType
    let objectId: UUID
    let name: String
    let isSelected: Bool
    let isVisible: Bool
    let isLocked: Bool
    let onSelect: () -> Void
    let onDrag: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            // Object Type Icon
            Image(systemName: objectIcon)
                    .font(.system(size: 10))
                .foregroundColor(objectIconColor)
                .frame(width: 12)
            
            // Selection Indicator
            Circle()
                .fill(isSelected ? Color.blue : Color.clear)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                .frame(width: 8, height: 8)
            
            // Object Name
            Text(name)
                .font(.system(size: 11))
                .foregroundColor(isSelected ? .blue : .primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Visibility/Lock Indicators
            HStack(spacing: 2) {
                if !isVisible {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                if isLocked {
                    Image(systemName: "lock")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onDrag {
            onDrag()
            return NSItemProvider(object: objectId.uuidString as NSString)
        }
    }
    
    private var objectIcon: String {
        switch objectType {
        case .shape:
            return "square.on.circle"
        case .text:
            return "textformat"
        }
    }
    
    private var objectIconColor: Color {
        switch objectType {
        case .shape:
            return .blue
        case .text:
            return .green
        }
    }
}

// PROFESSIONAL DRAG-AND-DROP DELEGATE (Adobe Illustrator Style)
struct LayerDropDelegate: DropDelegate {
    @ObservedObject var document: VectorDocument
    let targetLayerIndex: Int
    @Binding var draggedObject: LayersPanel.DraggedObject?
    
    func performDrop(info: DropInfo) -> Bool {
        guard let draggedObj = draggedObject else { return false }
        
        // Don't drop on same layer
        if draggedObj.sourceLayerIndex == targetLayerIndex {
            draggedObject = nil
            return false
        }
        
        document.saveToUndoStack()
        
        switch draggedObj.type {
        case .shape:
            moveShapeBetweenLayers(
                shapeId: draggedObj.id,
                from: draggedObj.sourceLayerIndex,
                to: targetLayerIndex
            )
        case .text:
            moveTextBetweenLayers(
                textId: draggedObj.id,
                from: draggedObj.sourceLayerIndex,
                to: targetLayerIndex
            )
        }
        
        draggedObject = nil
        print("🔄 Moved \(draggedObj.type) object to layer \(targetLayerIndex)")
        return true
    }
    
    func dropEntered(info: DropInfo) {
        // Visual feedback could be added here
    }
    
    func dropExited(info: DropInfo) {
        // Visual feedback cleanup could be added here
    }
    
    private func moveShapeBetweenLayers(shapeId: UUID, from sourceIndex: Int, to targetIndex: Int) {
        // Find and remove the shape from source layer
        guard let shapeIndex = document.layers[sourceIndex].shapes.firstIndex(where: { $0.id == shapeId }) else {
            return
        }
        
        let shape = document.layers[sourceIndex].shapes.remove(at: shapeIndex)
        
        // Add shape to target layer
        document.layers[targetIndex].shapes.append(shape)
        
        // Update selection to target layer
        document.selectedLayerIndex = targetIndex
        document.selectedShapeIDs = [shapeId]
        
        print("✅ Moved shape '\(shape.name)' from layer \(sourceIndex) to layer \(targetIndex)")
    }
    
    private func moveTextBetweenLayers(textId: UUID, from sourceIndex: Int, to targetIndex: Int) {
        // Note: Text objects are global but we can conceptually associate them with layers
        // For now, just update the selected layer
        document.selectedLayerIndex = targetIndex
        document.selectedTextIDs = [textId]
        
        print("✅ Associated text object with layer \(targetIndex)")
    }
}

// PropertiesPanel removed - using StrokeFillPanel instead

// Old property structures removed - using StrokeFillPanel instead

struct ColorPanel: View {
    @ObservedObject var document: VectorDocument
    @State private var searchText = ""
    @State private var showingPantoneSearch = false
    
    var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                Text("Color")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                
            // Color Mode Picker
            VStack(alignment: .leading, spacing: 4) {
                Text("Color Mode")
                        .font(.caption)
                        .foregroundColor(.secondary)
                
                Picker("Color Mode", selection: Binding(
                    get: { document.settings.colorMode },
                    set: { newMode in
                        document.settings.colorMode = newMode
                        document.updateColorSwatchesForMode()
                    }
                )) {
                    ForEach(ColorMode.allCases, id: \.self) { mode in
                        HStack {
                            Image(systemName: mode.iconName)
                            Text(mode.rawValue)
                        }
                        .tag(mode)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .font(.caption)
            }
            .padding(.horizontal, 12)
            
            // Mode-specific input sections
            if document.settings.colorMode == .pantone {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Search Pantone Colors")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        TextField("Enter Pantone number (e.g. 032 C)", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.caption)
                        
                        Button("Search") {
                            searchPantoneColor(searchText)
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    }
                }
                .padding(.horizontal, 12)
            } else if document.settings.colorMode == .cmyk {
                CMYKInputSection(document: document)
                        .padding(.horizontal, 12)
                }
                
            // Color Mode Specific Information
            HStack {
                Text(colorModeDescription)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            
            // Color Swatches
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(30), spacing: 4), count: 8), spacing: 4) {
                    ForEach(Array(filteredColors.enumerated()), id: \.offset) { index, color in
                        Button {
                            selectColor(color)
                        } label: {
                            Rectangle()
                                .fill(color.color)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Rectangle()
                                        .stroke(Color.gray, lineWidth: 1)
                                )
                                .overlay(
                                    // Show Pantone number for Pantone colors
                                    overlayText(for: color)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(colorDescription(for: color))
                    }
                }
                .padding(.horizontal, 12)
            }
            
            // Add Color Button
            HStack {
                if document.settings.colorMode == .pantone {
                    Button("Browse Pantone Library") {
                        showingPantoneSearch = true
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                } else {
                    Button("Add Custom Color") {
                        showingPantoneSearch = true // Will be used for general color picker
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            
            Spacer()
        }
        .sheet(isPresented: $showingPantoneSearch) {
            PantoneColorPickerSheet(document: document)
        }
    }
    
    // MARK: - Helper Properties and Methods
    
    private var colorModeDescription: String {
        switch document.settings.colorMode {
        case .rgb:
            return "RGB colors for screen display"
        case .cmyk:
            return "CMYK colors for print production"
        case .pantone:
            return "Pantone spot colors for professional printing"
        }
    }
    
    private var filteredColors: [VectorColor] {
        if searchText.isEmpty {
            return document.colorSwatches
        } else {
            return document.colorSwatches.filter { color in
                colorDescription(for: color).localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private func selectColor(_ color: VectorColor) {
        // Apply color to selected objects
        if !document.selectedShapeIDs.isEmpty {
            // Apply to shapes
            guard let layerIndex = document.selectedLayerIndex else { return }
            
            for shapeID in document.selectedShapeIDs {
                if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                    if NSEvent.modifierFlags.contains(.option) {
                        // Option+Click = stroke color
                        if document.layers[layerIndex].shapes[shapeIndex].strokeStyle != nil {
                            document.layers[layerIndex].shapes[shapeIndex].strokeStyle?.color = color
                        } else {
                            document.layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(color: color, width: 1.0)
                        }
                    } else {
                        // Regular click = fill color
                        if document.layers[layerIndex].shapes[shapeIndex].fillStyle != nil {
                            document.layers[layerIndex].shapes[shapeIndex].fillStyle?.color = color
                        } else {
                            document.layers[layerIndex].shapes[shapeIndex].fillStyle = FillStyle(color: color)
                        }
                    }
                }
            }
        }
        
        if !document.selectedTextIDs.isEmpty {
            // Apply to text
            for textID in document.selectedTextIDs {
                if let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) {
                    document.textObjects[textIndex].typography.fillColor = color
                }
            }
        }
    }
    
    private func searchPantoneColor(_ searchQuery: String) {
        let allPantoneColors = ColorManagement.loadPantoneColors()
        
        if let foundColor = allPantoneColors.first(where: { 
            $0.number.localizedCaseInsensitiveContains(searchQuery) ||
            $0.name.localizedCaseInsensitiveContains(searchQuery)
        }) {
            let pantoneColor = VectorColor.pantone(foundColor)
            document.addColorSwatch(pantoneColor)
            searchText = ""
        }
    }
    
    private func colorDescription(for color: VectorColor) -> String {
        switch color {
        case .black: return "Black"
        case .white: return "White"
        case .clear: return "Clear"
        case .rgb(let rgb): 
            return "RGB(\(Int(rgb.red * 255)), \(Int(rgb.green * 255)), \(Int(rgb.blue * 255)))"
        case .cmyk(let cmyk): 
            return "CMYK(\(Int(cmyk.cyan * 100))%, \(Int(cmyk.magenta * 100))%, \(Int(cmyk.yellow * 100))%, \(Int(cmyk.black * 100))%)"
        case .pantone(let pantone): 
            return "PANTONE \(pantone.number) - \(pantone.name)"
        }
    }
    
    @ViewBuilder
    private func overlayText(for color: VectorColor) -> some View {
        if case .pantone(let pantone) = color {
            Text(pantone.number)
                .font(.system(size: 6))
                .foregroundColor(.white)
                .shadow(color: .black, radius: 1)
                .lineLimit(1)
        }
    }
}

struct PathOperationsPanel: View {
    @ObservedObject var document: VectorDocument
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Pathfinder")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                
                // Info button
                Button {
                    // Show pathfinder help
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Adobe Illustrator Pathfinder Operations")
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            
            // Shape Modes Section (Adobe Illustrator standard)
                VStack(alignment: .leading, spacing: 8) {
                Text("Shape Modes")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                    ForEach([PathfinderOperation.unite, .minusFront, .intersect, .exclude], id: \.self) { operation in
                        PathfinderOperationButton(
                            operation: operation,
                            isEnabled: canPerformOperation(operation)
                        ) {
                            performPathfinderOperation(operation)
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            
            // Pathfinder Effects Section (Adobe Illustrator standard)
            VStack(alignment: .leading, spacing: 8) {
                Text("Pathfinder Effects")
                        .font(.caption)
                    .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                    ForEach([PathfinderOperation.divide, .trim, .merge, .crop, .outline, .minusBack], id: \.self) { operation in
                        PathfinderOperationButton(
                            operation: operation,
                            isEnabled: canPerformOperation(operation)
                        ) {
                            performPathfinderOperation(operation)
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            
            Spacer()
        }
    }
    
    private func canPerformOperation(_ operation: PathfinderOperation) -> Bool {
        let selectedShapes = document.getSelectedShapes()
        let paths = selectedShapes.map { $0.path.cgPath }
        return ProfessionalPathOperations.canPerformOperation(operation, on: paths)
    }
    
    private func performPathfinderOperation(_ operation: PathfinderOperation) {
        print("🎨 PROFESSIONAL ADOBE ILLUSTRATOR pathfinder operation: \(operation.rawValue)")
        
        // Get selected shapes in correct STACKING ORDER (Adobe Illustrator standard)
        let selectedShapes = document.getSelectedShapesInStackingOrder()
        guard !selectedShapes.isEmpty else {
            print("❌ No shapes selected for pathfinder operation")
            return
        }
        
        print("📚 STACKING ORDER: Processing \(selectedShapes.count) shapes")
        for (index, shape) in selectedShapes.enumerated() {
            print("  \(index): \(shape.name) (bottom→top)")
        }
        
        // Convert shapes to CGPaths
        let paths = selectedShapes.map { $0.path.cgPath }
        
        // Validate operation can be performed
        guard ProfessionalPathOperations.canPerformOperation(operation, on: paths) else {
            print("❌ Cannot perform \(operation.rawValue) on selected shapes")
            return
        }
        
        // Save to undo stack before making changes
        document.saveToUndoStack()
        
        // Perform the operation using EXACT ADOBE ILLUSTRATOR BEHAVIOR
        var resultShapes: [VectorShape] = []
        
        switch operation {
        // SHAPE MODES (Adobe Illustrator)
        case .unite:
            // UNITE: Combines all shapes, result takes color of TOPMOST object
            if let unitedPath = ProfessionalPathOperations.unite(paths) {
                let topmostShape = selectedShapes.last! // Last in array = topmost in stacking order
                let unitedShape = VectorShape(
                    name: "United Shape",
                    path: VectorPath(cgPath: unitedPath),
                    strokeStyle: topmostShape.strokeStyle,
                    fillStyle: topmostShape.fillStyle,
                    transform: .identity,
                    opacity: topmostShape.opacity
                )
                resultShapes = [unitedShape]
                print("✅ UNITE: Created unified shape with topmost object's color")
            }
            
        case .minusFront:
            // MINUS FRONT: Front objects subtract from back object, result takes color of BACK object
            guard selectedShapes.count >= 2 else { 
                print("❌ MINUS FRONT requires at least 2 shapes")
                return 
            }
            
            let backShape = selectedShapes.first!    // First in array = bottommost = back
            let frontShapes = Array(selectedShapes.dropFirst()) // All others = front
            
            print("🔪 MINUS FRONT: Back shape '\(backShape.name)' - Front shapes: \(frontShapes.map { $0.name })")
            
            var resultPath = backShape.path.cgPath
            
            // Subtract each front shape from the result
            for frontShape in frontShapes {
                if let subtractedPath = ProfessionalPathOperations.minusFront(frontShape.path.cgPath, from: resultPath) {
                    resultPath = subtractedPath
                    print("  ⚡ Subtracted '\(frontShape.name)' from result")
                }
            }
            
            // Result takes style of BACK object (Adobe Illustrator standard)
            let resultShape = VectorShape(
                name: "Minus Front Result",
                path: VectorPath(cgPath: resultPath),
                strokeStyle: backShape.strokeStyle,
                fillStyle: backShape.fillStyle,
                transform: .identity,
                opacity: backShape.opacity
            )
            resultShapes = [resultShape]
            print("✅ MINUS FRONT: Result takes back object's color (\(backShape.name))")
            
        case .intersect:
            // INTERSECT: Keep only overlapping areas, result takes color of TOPMOST object
            guard selectedShapes.count == 2 else {
                print("❌ INTERSECT requires exactly 2 shapes")
                return
            }
            
            if let intersectedPath = ProfessionalPathOperations.intersect(paths[0], paths[1]) {
                let topmostShape = selectedShapes.last! // Last = topmost
                let intersectedShape = VectorShape(
                    name: "Intersected Shape",
                    path: VectorPath(cgPath: intersectedPath),
                    strokeStyle: topmostShape.strokeStyle,
                    fillStyle: topmostShape.fillStyle,
                    transform: .identity,
                    opacity: topmostShape.opacity
                )
                resultShapes = [intersectedShape]
                print("✅ INTERSECT: Result takes topmost object's color (\(topmostShape.name))")
            }
            
        case .exclude:
            // EXCLUDE: Remove overlapping areas, result takes color of TOPMOST object
            guard selectedShapes.count == 2 else {
                print("❌ EXCLUDE requires exactly 2 shapes")
                return
            }
            
            if let excludedPath = ProfessionalPathOperations.exclude(paths[0], paths[1]) {
                let topmostShape = selectedShapes.last! // Last = topmost
                let excludedShape = VectorShape(
                    name: "Excluded Shape",
                    path: VectorPath(cgPath: excludedPath),
                    strokeStyle: topmostShape.strokeStyle,
                    fillStyle: topmostShape.fillStyle,
                    transform: .identity,
                    opacity: topmostShape.opacity
                )
                resultShapes = [excludedShape]
                print("✅ EXCLUDE: Result takes topmost object's color (\(topmostShape.name))")
            }
        
        // PATHFINDER EFFECTS (Adobe Illustrator) - These retain original colors
        case .divide:
            // DIVIDE: Break into separate objects, each retains original color
            let dividedPaths = ProfessionalPathOperations.divide(paths)
            
            for (index, dividedPath) in dividedPaths.enumerated() {
                // Determine which original shape this divided piece belongs to
                let originalShape = determineOriginalShapeForDividedPiece(dividedPath, from: selectedShapes)
                
                let dividedShape = VectorShape(
                    name: "Divided Piece \(index + 1)",
                    path: VectorPath(cgPath: dividedPath),
                    strokeStyle: originalShape.strokeStyle,
                    fillStyle: originalShape.fillStyle,
                    transform: .identity,
                    opacity: originalShape.opacity
                )
                resultShapes.append(dividedShape)
            }
            print("✅ DIVIDE: Created \(resultShapes.count) pieces with original colors")
            
        case .trim:
            // TRIM: Remove hidden parts, objects retain original colors, removes strokes
            let trimmedPaths = ProfessionalPathOperations.trim(paths)
            
            for (index, trimmedPath) in trimmedPaths.enumerated() {
                guard index < selectedShapes.count else { break }
                let originalShape = selectedShapes[index]
                
                let trimmedShape = VectorShape(
                    name: "Trimmed \(originalShape.name)",
                    path: VectorPath(cgPath: trimmedPath),
                    strokeStyle: nil, // TRIM removes strokes (Adobe Illustrator standard)
                    fillStyle: originalShape.fillStyle,
                    transform: .identity,
                    opacity: originalShape.opacity
                )
                resultShapes.append(trimmedShape)
            }
            print("✅ TRIM: Created \(resultShapes.count) trimmed shapes, removed strokes")
            
        case .merge:
            // MERGE: Like trim but merges objects of same color, removes strokes
            let mergedPaths = ProfessionalPathOperations.merge(paths)
            
            for (index, mergedPath) in mergedPaths.enumerated() {
                // For merge, we assume same color objects get merged into one
                let representativeShape = selectedShapes.first!
                
                let mergedShape = VectorShape(
                    name: "Merged Shape \(index + 1)",
                    path: VectorPath(cgPath: mergedPath),
                    strokeStyle: nil, // MERGE removes strokes (Adobe Illustrator standard)
                    fillStyle: representativeShape.fillStyle,
                    transform: .identity,
                    opacity: representativeShape.opacity
                )
                resultShapes.append(mergedShape)
            }
            print("✅ MERGE: Created \(resultShapes.count) merged shapes, removed strokes")
            
        case .crop:
            // CROP: Use topmost shape to crop others, cropped objects retain original colors, removes strokes
            let croppedPaths = ProfessionalPathOperations.crop(paths)
            
            for (index, croppedPath) in croppedPaths.enumerated() {
                guard index < selectedShapes.count - 1 else { break } // Exclude topmost (crop shape)
                let originalShape = selectedShapes[index]
                
                let croppedShape = VectorShape(
                    name: "Cropped \(originalShape.name)",
                    path: VectorPath(cgPath: croppedPath),
                    strokeStyle: nil, // CROP removes strokes (Adobe Illustrator standard)
                    fillStyle: originalShape.fillStyle,
                    transform: .identity,
                    opacity: originalShape.opacity
                )
                resultShapes.append(croppedShape)
            }
            print("✅ CROP: Created \(resultShapes.count) cropped shapes, removed strokes")
            
        case .outline:
            // OUTLINE: Convert fills to strokes/outlines
            let outlinedPaths = ProfessionalPathOperations.outline(paths)
            
            for (index, outlinedPath) in outlinedPaths.enumerated() {
                guard index < selectedShapes.count else { break }
                let originalShape = selectedShapes[index]
                
                // Convert fill to stroke (Adobe Illustrator "Outline" behavior)
                var outlineStroke: StrokeStyle?
                if let fillStyle = originalShape.fillStyle, fillStyle.color != .clear {
                    outlineStroke = StrokeStyle(
                        color: fillStyle.color,
                        width: 1.0,
                        lineCap: CGLineCap.round,
                        lineJoin: CGLineJoin.round
                    )
                }
                
                let outlinedShape = VectorShape(
                    name: "Outlined \(originalShape.name)",
                    path: VectorPath(cgPath: outlinedPath),
                    strokeStyle: outlineStroke,
                    fillStyle: nil, // OUTLINE removes fills (Adobe Illustrator standard)
                    transform: .identity,
                    opacity: originalShape.opacity
                )
                resultShapes.append(outlinedShape)
            }
            print("✅ OUTLINE: Created \(resultShapes.count) outlined shapes")
            
        case .minusBack:
            // MINUS BACK: Back objects subtract from front object, result takes color of FRONT object
            guard selectedShapes.count >= 2 else {
                print("❌ MINUS BACK requires at least 2 shapes")
                return
            }
            
            let frontShape = selectedShapes.last!     // Last in array = topmost = front
            let backShapes = Array(selectedShapes.dropLast()) // All others = back
            
            print("🔪 MINUS BACK: Front shape '\(frontShape.name)' - Back shapes: \(backShapes.map { $0.name })")
            
            var resultPath = frontShape.path.cgPath
            
            // Subtract each back shape from the result
            for backShape in backShapes {
                if let subtractedPath = ProfessionalPathOperations.minusBack(resultPath, from: backShape.path.cgPath) {
                    resultPath = subtractedPath
                    print("  ⚡ Subtracted '\(backShape.name)' from result")
                }
            }
            
            // Result takes style of FRONT object (Adobe Illustrator standard)
            let resultShape = VectorShape(
                name: "Minus Back Result",
                path: VectorPath(cgPath: resultPath),
                strokeStyle: frontShape.strokeStyle,
                fillStyle: frontShape.fillStyle,
                transform: .identity,
                opacity: frontShape.opacity
            )
            resultShapes = [resultShape]
            print("✅ MINUS BACK: Result takes front object's color (\(frontShape.name))")
        }
        
        guard !resultShapes.isEmpty else {
            print("❌ Pathfinder operation \(operation.rawValue) produced no results")
            return
        }
        
        // Remove original selected shapes
        document.removeSelectedShapes()
        
        // Add new result shapes and select them
        for resultShape in resultShapes {
            document.addShape(resultShape)
            document.selectShape(resultShape.id)
        }
        
        print("✅ PROFESSIONAL ADOBE ILLUSTRATOR pathfinder operation \(operation.rawValue) completed - created \(resultShapes.count) result shape(s)")
    }
    
    /// Determine which original shape a divided piece belongs to (for color assignment)
    private func determineOriginalShapeForDividedPiece(_ piece: CGPath, from originalShapes: [VectorShape]) -> VectorShape {
        // Get the center point of the piece
        let pieceBounds = piece.boundingBoxOfPath
        let pieceCenter = CGPoint(x: pieceBounds.midX, y: pieceBounds.midY)
        
        // Find which original shape contains this center point
        for shape in originalShapes {
            if shape.path.cgPath.contains(pieceCenter) {
                return shape
            }
        }
        
        // Fallback: use the first shape
        return originalShapes.first!
    }
}

struct PathfinderOperationButton: View {
    let operation: PathfinderOperation
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: operation.iconName)
                    .font(.system(size: operation.isShapeMode ? 14 : 12))
                    .foregroundColor(isEnabled ? .accentColor : .secondary)
                
                Text(operation.rawValue)
                    .font(.caption2)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(isEnabled ? .primary : .secondary)
            }
            .frame(height: operation.isShapeMode ? 48 : 42)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isEnabled ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isEnabled ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
        .help(operation.description)
    }
}

// Legacy PathOperationButton for backward compatibility
struct PathOperationButton: View {
    let operation: PathOperation
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: operation.iconName)
                    .font(.system(size: 16))
                
                Text(operation.rawValue)
                    .font(.caption2)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .foregroundColor(isEnabled ? .primary : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isEnabled ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
        .help(operation.rawValue)
    }
}

// MARK: - Professional CMYK Input Section

struct CMYKInputSection: View {
    @ObservedObject var document: VectorDocument
    @State private var cyanValue: String = "0"
    @State private var magentaValue: String = "0"
    @State private var yellowValue: String = "0"
    @State private var blackValue: String = "0"
    @State private var previewColor: CMYKColor = CMYKColor(cyan: 0, magenta: 0, yellow: 0, black: 0)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CMYK Process Colors")
                    .font(.caption)
                .fontWeight(.medium)
                    .foregroundColor(.secondary)
            
            Text("Enter process color values (0-100%)")
                .font(.caption2)
                    .foregroundColor(.secondary)
            
            // CMYK Input Grid
            VStack(spacing: 6) {
                // Cyan and Magenta row
                HStack(spacing: 8) {
                    CMYKInputField(
                        label: "C",
                        value: $cyanValue,
                        color: .cyan,
                        onChange: updatePreview
                    )
                    
                    CMYKInputField(
                        label: "M",
                        value: $magentaValue,
                        color: .pink,
                        onChange: updatePreview
                    )
                }
                
                // Yellow and Black row
                HStack(spacing: 8) {
                    CMYKInputField(
                        label: "Y",
                        value: $yellowValue,
                        color: .yellow,
                        onChange: updatePreview
                    )
                    
                    CMYKInputField(
                        label: "K",
                        value: $blackValue,
                        color: .black,
                        onChange: updatePreview
                    )
                }
            }
            
            // Color Preview and Add Button
            HStack(spacing: 8) {
                // Preview
                Rectangle()
                    .fill(previewColor.color)
                    .frame(width: 40, height: 30)
                    .overlay(
                        Rectangle()
                            .stroke(Color.gray, lineWidth: 1)
                    )
                    .cornerRadius(4)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("CMYK(\(Int(previewColor.cyan * 100)), \(Int(previewColor.magenta * 100)), \(Int(previewColor.yellow * 100)), \(Int(previewColor.black * 100)))")
                        .font(.caption2)
                        .foregroundColor(.primary)
                    
                    Button("Add to Swatches") {
                        addCMYKColorToSwatches()
                    }
                    .buttonStyle(.bordered)
                    .font(.caption2)
                    .controlSize(.small)
                }
                
                Spacer()
            }
            
            // Quick CMYK Presets
        VStack(alignment: .leading, spacing: 4) {
                Text("Common Process Colors")
                    .font(.caption2)
                .foregroundColor(.secondary)
            
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 4) {
                    CMYKPresetButton(name: "Cyan", cmyk: (100, 0, 0, 0), action: applyCMYKPreset)
                    CMYKPresetButton(name: "Magenta", cmyk: (0, 100, 0, 0), action: applyCMYKPreset)
                    CMYKPresetButton(name: "Yellow", cmyk: (0, 0, 100, 0), action: applyCMYKPreset)
                    CMYKPresetButton(name: "Black", cmyk: (0, 0, 0, 100), action: applyCMYKPreset)
                    CMYKPresetButton(name: "Red", cmyk: (0, 100, 100, 0), action: applyCMYKPreset)
                    CMYKPresetButton(name: "Green", cmyk: (100, 0, 100, 0), action: applyCMYKPreset)
                    CMYKPresetButton(name: "Blue", cmyk: (100, 100, 0, 0), action: applyCMYKPreset)
                    CMYKPresetButton(name: "Rich Black", cmyk: (30, 30, 30, 100), action: applyCMYKPreset)
                }
            }
        }
        .onAppear {
            updatePreview()
        }
    }
    
    private func updatePreview() {
        let c = (Double(cyanValue) ?? 0) / 100.0
        let m = (Double(magentaValue) ?? 0) / 100.0
        let y = (Double(yellowValue) ?? 0) / 100.0
        let k = (Double(blackValue) ?? 0) / 100.0
        
        previewColor = CMYKColor(
            cyan: max(0, min(1, c)),
            magenta: max(0, min(1, m)),
            yellow: max(0, min(1, y)),
            black: max(0, min(1, k))
        )
    }
    
    private func addCMYKColorToSwatches() {
        let vectorColor = VectorColor.cmyk(previewColor)
        document.addColorSwatch(vectorColor)
    }
    
    private func applyCMYKPreset(_ cmyk: (Int, Int, Int, Int)) {
        cyanValue = String(cmyk.0)
        magentaValue = String(cmyk.1)
        yellowValue = String(cmyk.2)
        blackValue = String(cmyk.3)
        updatePreview()
    }
}

struct CMYKInputField: View {
    let label: String
    @Binding var value: String
    let color: Color
    let onChange: () -> Void
    
    var body: some View {
        VStack(spacing: 2) {
        HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            Text(label)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            TextField("0", text: $value)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.caption)
                .frame(height: 24)
                .onChange(of: value) { oldValue, newValue in
                    // Validate and clamp input to 0-100
                    if let numValue = Double(newValue) {
                        if numValue < 0 {
                            value = "0"
                        } else if numValue > 100 {
                            value = "100"
                        }
                    }
                    onChange()
                }
        }
        .frame(maxWidth: .infinity)
    }
}

struct CMYKPresetButton: View {
    let name: String
    let cmyk: (Int, Int, Int, Int)
    let action: ((Int, Int, Int, Int)) -> Void
    
    var body: some View {
        Button {
            action(cmyk)
        } label: {
            VStack(spacing: 2) {
                let cmykColor = CMYKColor(
                    cyan: Double(cmyk.0) / 100.0,
                    magenta: Double(cmyk.1) / 100.0,
                    yellow: Double(cmyk.2) / 100.0,
                    black: Double(cmyk.3) / 100.0
                )
                
                        Rectangle()
                    .fill(cmykColor.color)
                    .frame(height: 20)
                    .overlay(
                        Rectangle()
                            .stroke(Color.gray, lineWidth: 0.5)
                    )
                    .cornerRadius(3)
                
                Text(name)
                    .font(.system(size: 8))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .help("CMYK(\(cmyk.0), \(cmyk.1), \(cmyk.2), \(cmyk.3))")
    }
}

// MARK: - Professional Pantone Color Picker Sheet

struct PantoneColorPickerSheet: View {
    @ObservedObject var document: VectorDocument
    @Environment(\.presentationMode) var presentationMode
    
    @State private var searchText = ""
    @State private var selectedCategory: PantoneCategory = .all
    @State private var selectedColor: PantoneColor?
    
    enum PantoneCategory: String, CaseIterable {
        case all = "All Colors"
        case classics = "Classic Colors"
        case metallics = "Metallics"
        case colorOfYear = "Color of the Year"
        
        func filter(_ colors: [PantoneColor]) -> [PantoneColor] {
            switch self {
            case .all:
                return colors
            case .classics:
                return colors.filter { color in
                    color.number.contains("C") && 
                    !color.name.localizedCaseInsensitiveContains("metallic") &&
                    !color.name.localizedCaseInsensitiveContains("peach fuzz")
                }
            case .metallics:
                return colors.filter { $0.number.contains("871") || $0.number.contains("877") }
            case .colorOfYear:
                return colors.filter { $0.name.localizedCaseInsensitiveContains("peach fuzz") }
            }
        }
    }
    
    private var allPantoneColors: [PantoneColor] {
        ColorManagement.loadPantoneColors()
    }
    
    private var filteredColors: [PantoneColor] {
        let categoryFiltered = selectedCategory.filter(allPantoneColors)
        
        if searchText.isEmpty {
            return categoryFiltered
        } else {
            return categoryFiltered.filter { color in
                color.name.localizedCaseInsensitiveContains(searchText) ||
                color.number.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Search and Filter Section
                VStack(alignment: .leading, spacing: 12) {
                    // Search Bar
            HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search Pantone colors...", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Category Filter
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(PantoneCategory.allCases, id: \.self) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                .padding(.horizontal)
                
                // Selected Color Preview
                if let selectedColor = selectedColor {
                    VStack(spacing: 8) {
                        Rectangle()
                            .fill(selectedColor.color)
                            .frame(height: 60)
                            .overlay(
                                Rectangle()
                                    .stroke(Color.gray, lineWidth: 1)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("PANTONE \(selectedColor.number)")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            Text(selectedColor.name)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text("RGB: \(Int(selectedColor.rgbEquivalent.red * 255)), \(Int(selectedColor.rgbEquivalent.green * 255)), \(Int(selectedColor.rgbEquivalent.blue * 255))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
            Spacer()
                            }
                            
                            HStack {
                                Text("CMYK: \(Int(selectedColor.cmykEquivalent.cyan * 100))%, \(Int(selectedColor.cmykEquivalent.magenta * 100))%, \(Int(selectedColor.cmykEquivalent.yellow * 100))%, \(Int(selectedColor.cmykEquivalent.black * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
                
                // Color Grid
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(50), spacing: 8), count: 6), spacing: 8) {
                        ForEach(filteredColors, id: \.number) { color in
                            Button {
                                selectedColor = color
                            } label: {
            VStack(spacing: 4) {
                                    Rectangle()
                                        .fill(color.color)
                                        .frame(width: 50, height: 50)
                                        .overlay(
                                            Rectangle()
                                                .stroke(selectedColor?.number == color.number ? Color.blue : Color.gray, 
                                                       lineWidth: selectedColor?.number == color.number ? 2 : 1)
                                        )
                                    
                                    Text(color.number)
                                        .font(.system(size: 8))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                }
        }
        .buttonStyle(PlainButtonStyle())
                            .help("PANTONE \(color.number) - \(color.name)")
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("Pantone Colors")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add to Swatches") {
                        if let selectedColor = selectedColor {
                            let vectorColor = VectorColor.pantone(selectedColor)
                            document.addColorSwatch(vectorColor)
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    .disabled(selectedColor == nil)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(width: 500, height: 600)
        .onAppear {
            // Select first color by default
            selectedColor = filteredColors.first
        }
        .onChange(of: selectedCategory) { oldValue, newValue in
            selectedColor = filteredColors.first
        }
        .onChange(of: searchText) { oldValue, newValue in
            selectedColor = filteredColors.first
        }
    }
}

// Preview
struct RightPanel_Previews: PreviewProvider {
    static var previews: some View {
        RightPanel(document: VectorDocument())
            .frame(height: 600)
    }
}