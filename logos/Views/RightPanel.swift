//
//  RightPanel.swift
//  logos inkpen.io
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
        .onAppear {
            // PROFESSIONAL PANEL SWITCHING (Adobe Illustrator Standards)
            NotificationCenter.default.addObserver(forName: .switchToPanel, object: nil, queue: .main) { notification in
                if let panelTab = notification.object as? PanelTab {
                    selectedTab = panelTab
                    print("🎨 Menu: Switched to panel: \(panelTab.rawValue)")
                }
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self)
        }
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

// SHARED STRUCTS FOR DRAG AND DROP
struct ObjectDropTarget {
    let layerIndex: Int
    let insertionIndex: Int // Index where object should be inserted
    let isValid: Bool
}

// PROFESSIONAL LAYERS PANEL (Adobe Illustrator Style)
struct LayersPanel: View {
    @ObservedObject var document: VectorDocument
    @State private var expandedLayers: Set<Int> = []
    @State private var draggedObject: DraggedObject?
    @State private var draggedLayer: DraggedLayer?
    @State private var dropTargetIndex: Int? = nil // Visual feedback for drop target
    @State private var draggedLayerIndex: Int? = nil // Track which layer is being dragged
    @State private var hoveredLayerIndex: Int? = nil // Track which layer is being hovered by objects
    @State private var isDraggingObject: Bool = false // Track when ANY object is being dragged
    @State private var objectDropTargetInfo: ObjectDropTarget? = nil // Track object drop target
    @State private var renamingLayerIndex: Int?
    @State private var newLayerName: String = ""
    
    // PROFESSIONAL LAYER DRAG PRECISION STATE (Same approach as hand tool, object dragging, and shape drawing)
    @State private var layerDragStart = CGPoint.zero         // Reference cursor position when layer drag started
    @State private var layerDragInitialPosition = CGPoint.zero // Reference layer position when drag started
    @State private var isLayerDragActive = false             // Track when precision layer drag is active
    
    // Custom UTType for layer drag and drop
    private static let layerUTType = "com.logos-inkpen-io.layer"
    
    struct DraggedObject {
        enum ObjectType: String {
            case shape = "shape"
            case text = "text"
        }
        
        let type: ObjectType
        let id: UUID
        let sourceLayerIndex: Int
    }
    
    struct DraggedLayer {
        let layerIndex: Int
        let layerName: String
    }
    
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
                // PROFESSIONAL LAYER PANEL: Improved drop zone structure
                // Top drop zone for dropping above all layers
                dropZone(targetIndex: document.layers.count, height: 8)
                
                // Layer rows with consistent drop zones
                ForEach(Array(document.layers.indices.reversed().enumerated()), id: \.element) { visualIndex, layerIndex in
                    VStack(spacing: 0) {
                        // The layer row itself
                        layerRowContent(for: layerIndex)
                        
                        // Drop zone after each layer (including the bottom-most layer)
                        dropZone(targetIndex: layerIndex, height: 6)
                    }
                }
                
                // CRITICAL: Special bottom drop zone for dropping below the last object
                // This ensures users can always drag objects to the very bottom position
                // Using -1 as a special target index to indicate bottom position
                VStack(spacing: 0) {
                    dropZone(targetIndex: -1, height: 12) // Special bottom drop zone with more height
                    Color.clear.frame(height: 20) // Extra space for easier scrolling
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    @ViewBuilder
    private func dropZone(targetIndex: Int, height: CGFloat) -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: height)
            .overlay(
                Group {
                    if dropTargetIndex == targetIndex {
                        // PROFESSIONAL DROP INDICATOR: Always visible during drag operations
                        Rectangle()
                            .fill(dropIndicatorColor)
                            .frame(height: 3) // Thicker for better visibility like Adobe Illustrator
                            .padding(.horizontal, 4)
                            .animation(.easeInOut(duration: 0.05), value: dropTargetIndex) // Very fast for responsiveness
                    } else if isDraggingObject || isLayerDragActive {
                        // SUBTLE HINT INDICATORS: Show potential drop zones during any drag
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                            .padding(.horizontal, 8)
                    }
                }
            )
            .dropDestination(for: LayerDragData.self) { items, location in
                guard let draggedData = items.first else { return false }
                let result = handleLayerDrop(draggedData: draggedData, targetIndex: targetIndex)
                clearDragState()
                return result
            } isTargeted: { isTargeted in
                // Only set drop target for layer drops, not object drops
                if draggedLayerIndex != nil {
                    dropTargetIndex = isTargeted ? targetIndex : nil
                }
            }
            .dropDestination(for: ObjectDragData.self) { items, location in
                guard let draggedData = items.first else { return false }
                
                // Determine the correct target layer for object drops
                let targetLayerIndex: Int
                if targetIndex == document.layers.count {
                    // Dropped above all layers - move to topmost layer (highest index)
                    targetLayerIndex = document.layers.count - 1
                } else if targetIndex == -1 {
                    // SPECIAL BOTTOM DROP ZONE: Move to the bottom-most layer (index 1, since Canvas is 0)
                    targetLayerIndex = max(1, 0) // Never drop to Canvas (index 0)
                } else {
                    // Dropped below a specific layer - move to that layer
                    targetLayerIndex = targetIndex
                }
                
                // Reduced logging for better performance
                // print("🎯 DIVIDER DROP: Object drop on divider, targeting layer \(targetLayerIndex)")
                let result = handleObjectDrop(draggedData: draggedData, targetLayerIndex: targetLayerIndex)
                clearDragState()
                return result
            } isTargeted: { isTargeted in
                if isTargeted {
                    // For object drops, highlight the target layer and show divider
                    if targetIndex == document.layers.count {
                        hoveredLayerIndex = document.layers.count - 1
                    } else if targetIndex == -1 {
                        // SPECIAL BOTTOM DROP ZONE: Highlight the bottom-most layer (index 1)
                        hoveredLayerIndex = max(1, 0)
                    } else {
                        hoveredLayerIndex = targetIndex
                    }
                    // Also show drop indicator for visual feedback
                    dropTargetIndex = targetIndex
                    // Reduced logging for better performance
                    // print("🎯 DIVIDER HOVER: Object hovering over divider, highlighting layer \(hoveredLayerIndex ?? -1)")
                } else {
                    // Clear hover states when not targeted
                    if draggedLayerIndex == nil { // Only clear if not dragging a layer
                        hoveredLayerIndex = nil
                        dropTargetIndex = nil
                    }
                }
            }
    }
    
    private func layerRowContent(for layerIndex: Int) -> some View {
        ProfessionalLayerRow(
            document: document,
            layerIndex: layerIndex,
            isExpanded: expandedLayers.contains(layerIndex),
            isRenaming: renamingLayerIndex == layerIndex,
            newLayerName: $newLayerName,
            isHovered: hoveredLayerIndex == layerIndex,
            isDraggingObject: isDraggingObject,
            objectDropTargetInfo: objectDropTargetInfo,
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
            },
            onObjectDrag: { objectType, objectId in
                draggedObject = DraggedObject(
                    type: objectType,
                    id: objectId,
                    sourceLayerIndex: layerIndex
                )
                isDraggingObject = true
            },
            onObjectHover: { isHovered in
                hoveredLayerIndex = isHovered ? layerIndex : nil
            },
            onObjectDropTargetChanged: { dropTarget in
                objectDropTargetInfo = dropTarget
            }
        )
        .draggable(LayerDragData(layerIndex: layerIndex)) {
            dragPreview(for: layerIndex)
        }
        .simultaneousGesture(
            // PROFESSIONAL LAYER DRAG: Perfect cursor-to-layer synchronization
            // Uses the same precision approach as hand tool, object dragging, and shape drawing
            // This eliminates floating-point accumulation errors from SwiftUI DragGesture
            DragGesture()
                .onChanged { value in
                    if !isLayerDragActive {
                        // CRITICAL: Only initialize state once per drag operation
                        isLayerDragActive = true
                        draggedLayerIndex = layerIndex
                        
                        // PRECISION REFERENCE POINTS: Capture exact cursor and layer positions
                        layerDragStart = value.startLocation
                        layerDragInitialPosition = CGPoint(x: 0, y: 0) // Layer visual position reference
                        
                        print("🎯 LAYER DRAG: Established reference positions for layer '\(document.layers[layerIndex].name)'")
                        print("   Reference cursor: (\(String(format: "%.1f", layerDragStart.x)), \(String(format: "%.1f", layerDragStart.y)))")
                    }
                    
                    // PRECISION CURSOR TRACKING: Calculate exact cursor delta like hand tool
                    let cursorDelta = CGPoint(
                        x: value.location.x - layerDragStart.x,
                        y: value.location.y - layerDragStart.y
                    )
                    
                    // UPDATE DROP ZONE INDICATORS: Use cursor position for precise drop targeting
                    updateDropZoneIndicators(cursorPosition: value.location, cursorDelta: cursorDelta)
                }
                .onEnded { value in
                    if isLayerDragActive {
                        print("🎯 LAYER DRAG: Completed successfully - moved layer '\(document.layers[layerIndex].name)'")
                        print("   State reset - ready for next drag operation")
                    }
                    clearPrecisionDragState()
                }
        )
    }
    
    private func clearDragState() {
        // PROFESSIONAL DRAG STATE MANAGEMENT: Immediate cleanup for better UX
        // No delay to prevent flickering and inconsistent visual feedback
        draggedLayerIndex = nil
        dropTargetIndex = nil
        hoveredLayerIndex = nil
        isDraggingObject = false
        objectDropTargetInfo = nil
        
        // Only log significant state changes to reduce console noise
        // print("🏁 Finished dragging - cleared all drag states")
    }
    
    private func clearPrecisionDragState() {
        // PROFESSIONAL PRECISION DRAG STATE MANAGEMENT: Clean reset for next operation
        isLayerDragActive = false
        layerDragStart = CGPoint.zero
        layerDragInitialPosition = CGPoint.zero
        clearDragState()
    }
    
    private func updateDropZoneIndicators(cursorPosition: CGPoint, cursorDelta: CGPoint) {
        // PROFESSIONAL DROP ZONE INDICATORS: Use precise cursor position for drop targeting
        // This ensures consistent drop zone highlighting based on actual mouse position
        // Following Adobe Illustrator, FreeHand, CorelDraw, and Inkscape precision standards
        
        guard let draggedIndex = draggedLayerIndex else { return }
        
        // Calculate drag magnitude for minimum movement threshold
        let dragMagnitude = sqrt(cursorDelta.x * cursorDelta.x + cursorDelta.y * cursorDelta.y)
        
        // Only show indicators for significant movement (prevents jittery behavior)
        if dragMagnitude > 5 { // Lowered threshold for better responsiveness
            // PRECISION CURSOR TRACKING: Use vertical delta for more precise drop zone detection
            let verticalDelta = cursorDelta.y
            
            if verticalDelta < -30 {
                // Dragging UP: Move to higher index (above current position)
                dropTargetIndex = min(draggedIndex + 1, document.layers.count)
            } else if verticalDelta > 30 {
                // Dragging DOWN: Move to lower index or special bottom position
                let targetIndex = max(draggedIndex - 1, 1) // Never go below index 1 (Canvas protection)
                if targetIndex == 1 && draggedIndex > 1 {
                    // If trying to move to bottom position, use special bottom drop zone
                    dropTargetIndex = -1
                } else {
                    dropTargetIndex = targetIndex
                }
            } else {
                // Small movements: Clear drop target to prevent flickering
                dropTargetIndex = nil
            }
        } else {
            // Very small movements: Clear drop target
            dropTargetIndex = nil
        }
    }
    
    private func dragPreview(for layerIndex: Int) -> some View {
        HStack {
            Image(systemName: "square.stack.3d.down.right")
            Text(document.layers[layerIndex].name)
                .font(.system(size: 12, weight: .medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.8))
        .foregroundColor(.white)
        .cornerRadius(4)
    }
    
    // PROFESSIONAL DROP INDICATOR COLOR (Adobe Illustrator Style)
    private var dropIndicatorColor: Color {
        guard let targetIndex = dropTargetIndex else { return .clear }
        
        // LAYER DROP INDICATORS
        if draggedLayerIndex != nil {
            // Validate layer drop
            let isValid = isDropAllowed(targetIndex: targetIndex)
            return isValid ? .blue : .red // Blue for valid, red for invalid
        }
        
        // OBJECT DROP INDICATORS  
        // For object drops, use consistent blue color for valid drops
        return .blue
    }
    
    // Check if layer drop is allowed at target index
    private func isDropAllowed(targetIndex: Int) -> Bool {
        guard let draggedIndex = draggedLayerIndex else { return true }
        
        // PROTECT CANVAS LAYER: Never allow Canvas layer (index 0) to be moved
        if draggedIndex == 0 {
            return false // Red indicator - Canvas cannot be moved
        }
        
        // PROTECT CANVAS LAYER: Never allow any layer to be moved to Canvas position (index 0)
        if targetIndex == 0 {
            return false // Red indicator - cannot drop below Canvas
        }
        
        // SPECIAL BOTTOM DROP ZONE: Allow dropping to bottom position (except Canvas)
        if targetIndex == -1 {
            return draggedIndex != 0 // Valid unless trying to move Canvas
        }
        
        // Don't allow dropping on the same position (except for "move to top" case)
        if draggedIndex == targetIndex && targetIndex != document.layers.count {
            return false // Red indicator - same position
        }
        
        // All other drops are valid
        return true // Blue indicator
    }
    
    private func handleLayerDrop(draggedData: LayerDragData, targetIndex: Int) -> Bool {
        let sourceIndex = draggedData.layerIndex
        
        // Reduced logging for better performance
        // print("🔄 LAYER DROP: Moving layer from index \(sourceIndex) to \(targetIndex)")
        
        // SPECIAL BOTTOM DROP ZONE: Convert -1 to proper target index
        let actualTargetIndex: Int
        if targetIndex == -1 {
            // Move to bottom position (index 1, since Canvas is always at index 0)
            actualTargetIndex = 1
        } else {
            actualTargetIndex = targetIndex
        }
        
        // Don't drop on same layer (but allow dropping above all layers even if source is top layer)
        if sourceIndex == actualTargetIndex && actualTargetIndex != document.layers.count {
            // print("🚫 Source and target are the same")
            return false
        }
        
        // PROTECT CANVAS LAYER: Never allow Canvas layer (index 0) to be moved
        if sourceIndex == 0 {
            // print("🚫 Cannot move Canvas layer - it must remain at the bottom")
            return false
        }
        
        // PROTECT CANVAS LAYER: Never allow any layer to be moved to Canvas position (index 0)
        if actualTargetIndex == 0 {
            // print("🚫 Cannot move layers below Canvas layer")
            return false
        }
        
        // Perform the layer move - let moveLayer handle all index logic
        document.saveToUndoStack()
        document.moveLayer(from: sourceIndex, to: actualTargetIndex)
        
        // Only log successful moves
        print("✅ Successfully moved layer from \(sourceIndex) to \(actualTargetIndex)")
        document.debugLayerOrder()
        
        // Clear drop target
        dropTargetIndex = nil
        
        return true
    }
    
    private func handleObjectDrop(draggedData: ObjectDragData, targetLayerIndex: Int) -> Bool {
        let sourceLayerIndex = draggedData.sourceLayerIndex
        let objectId = draggedData.objectId
        let objectType = draggedData.objectType
        
        // Reduced logging for better performance
        // print("🔄 OBJECT DROP: Moving \(objectType) from layer \(sourceLayerIndex) to layer \(targetLayerIndex)")
        
        // PROTECT LOCKED LAYERS: Check if source layer is locked
        if sourceLayerIndex < document.layers.count && document.layers[sourceLayerIndex].isLocked {
            // print("🚫 Cannot move objects from locked layer '\(document.layers[sourceLayerIndex].name)'")
            return false
        }
        
        // PROTECT LOCKED LAYERS: Check if target layer is locked
        if targetLayerIndex < document.layers.count && document.layers[targetLayerIndex].isLocked {
            // print("🚫 Cannot move objects to locked layer '\(document.layers[targetLayerIndex].name)'")
            return false
        }
        
        // Don't drop on same layer if it's the same object
        if sourceLayerIndex == targetLayerIndex {
            // print("🚫 Object already in target layer")
            return false
        }
        
        // PROTECT CANVAS LAYER: Never allow objects to be moved to Canvas layer (index 0)
        if targetLayerIndex == 0 {
            // print("🚫 Cannot move objects to Canvas layer")
            return false
        }
        
        // Ensure target layer exists
        guard targetLayerIndex < document.layers.count else {
            // print("❌ Target layer index out of bounds")
            return false
        }
        
        document.saveToUndoStack()
        
        // Move the object based on its type
        if objectType == "shape" {
            // Find and move shape
            for layerIndex in document.layers.indices {
                if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == objectId }) {
                    let shape = document.layers[layerIndex].shapes.remove(at: shapeIndex)
                    document.layers[targetLayerIndex].shapes.append(shape)
                    
                    // Update selection to target layer
                    document.selectedLayerIndex = targetLayerIndex
                    document.selectedShapeIDs = [objectId]
                    
                    print("✅ Successfully moved shape '\(shape.name)' to layer '\(document.layers[targetLayerIndex].name)'")
                    return true
                }
            }
        } else if objectType == "text" {
            // For text objects, just associate with the target layer
            if document.textObjects.contains(where: { $0.id == objectId }) {
                // Update selection to target layer (text objects remain global)
                document.selectedLayerIndex = targetLayerIndex  
                document.selectedTextIDs = [objectId]
                
                print("✅ Successfully associated text object with layer '\(document.layers[targetLayerIndex].name)'")
                return true
            }
        }
        
        print("❌ Failed to find object to move")
        return false
    }
}

// DRAG DATA FOR LAYER REORDERING
struct LayerDragData: Transferable, Codable {
    let layerIndex: Int
    
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .data)
    }
}

// DRAG DATA FOR OBJECT REORDERING
struct ObjectDragData: Transferable, Codable {
    let objectType: String  // "shape" or "text"
    let objectId: UUID
    let sourceLayerIndex: Int
    
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .data)
    }
}

// PROFESSIONAL LAYER ROW (Adobe Illustrator Style)
struct ProfessionalLayerRow: View {
    @ObservedObject var document: VectorDocument
    let layerIndex: Int
    let isExpanded: Bool
    let isRenaming: Bool
    @Binding var newLayerName: String
    let isHovered: Bool
    let isDraggingObject: Bool
    let objectDropTargetInfo: ObjectDropTarget?
    let onToggleExpanded: () -> Void
    let onStartRename: () -> Void
    let onFinishRename: () -> Void
    let onCancelRename: () -> Void
    let onObjectDrag: (LayersPanel.DraggedObject.ObjectType, UUID) -> Void
    let onObjectHover: (Bool) -> Void
    let onObjectDropTargetChanged: (ObjectDropTarget?) -> Void
    
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
        return layerIndex == 0 && layer.name == "Canvas"
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
            
            // Layer Name - Editable or Static
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
            .background(
                Group {
                    if isSelected {
                        Color.blue.opacity(0.15)
                    } else if isHovered {
                        Color.green.opacity(0.2)  // Green highlight when objects are being dragged over
                    } else {
                        Color.clear
                    }
                }
            )
            .onTapGesture {
                // SAFE LAYER ACCESS: Check bounds before selection
                guard layerIndex >= 0 && layerIndex < document.layers.count else { return }
                
                // PROTECT CANVAS LAYER: Don't allow selection of Canvas layer when locked
                if isCanvasLayer && layer.isLocked {
                    print("🚫 Cannot select locked Canvas layer")
                    return
                }
                
                document.selectedLayerIndex = layerIndex
            }
            .dropDestination(for: ObjectDragData.self) { items, location in
                guard let draggedData = items.first else { return false }
                // Handle object drop onto layer header
                return handleObjectDropOntoLayer(draggedData: draggedData, targetLayerIndex: layerIndex)
            } isTargeted: { isTargeted in
                onObjectHover(isTargeted)
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
            
            // Expanded Object List (Adobe Illustrator Style)
            if isExpanded {
                VStack(spacing: 0) {
                    // TOP INSERTION ZONE - only visible during object drag
                    if isDraggingObject {
                        objectInsertionZone(
                            layerIndex: layerIndex, 
                            insertionIndex: layer.shapes.count, // Insert at end (top of visual list)
                            isHighlighted: objectDropTargetInfo?.layerIndex == layerIndex && 
                                          objectDropTargetInfo?.insertionIndex == layer.shapes.count
                        )
                    }
                    
                    // Shape Objects with insertion zones
                    ForEach(Array(layer.shapes.indices.reversed().enumerated()), id: \.element) { visualIndex, shapeIndex in
                        let shape = layer.shapes[shapeIndex]
                        
                        VStack(spacing: 0) {
                            // The object row
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
                                },
                                layerIndex: layerIndex,
                                document: document,
                                onInsertionTargetChanged: { insertionIndex in
                                    if let insertionIndex = insertionIndex {
                                        onObjectDropTargetChanged(ObjectDropTarget(
                                            layerIndex: layerIndex,
                                            insertionIndex: insertionIndex,
                                            isValid: true
                                        ))
                                    } else {
                                        onObjectDropTargetChanged(nil)
                                    }
                                }
                            )
                            
                            // INSERTION ZONE below this object - only visible during object drag
                            if isDraggingObject {
                                objectInsertionZone(
                                    layerIndex: layerIndex,
                                    insertionIndex: shapeIndex, // Insert at this index
                                    isHighlighted: objectDropTargetInfo?.layerIndex == layerIndex && 
                                                  objectDropTargetInfo?.insertionIndex == shapeIndex
                                )
                            }
                        }
                    }
                    
                    // Text Objects with insertion zones  
                    ForEach(document.textObjects.indices, id: \.self) { textIndex in
                        let textObject = document.textObjects[textIndex]
                        
                        VStack(spacing: 0) {
                            // The object row
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
                                },
                                layerIndex: layerIndex,
                                document: document,
                                onInsertionTargetChanged: { insertionIndex in
                                    if let insertionIndex = insertionIndex {
                                        onObjectDropTargetChanged(ObjectDropTarget(
                                            layerIndex: layerIndex,
                                            insertionIndex: insertionIndex,
                                            isValid: true
                                        ))
                                    } else {
                                        onObjectDropTargetChanged(nil)
                                    }
                                }
                            )
                        }
                    }
                }
                .padding(.leading, 20) // Indent objects under layer
            }
        }
        .background(Color.clear)
    }
    
    private func handleObjectDropOntoLayer(draggedData: ObjectDragData, targetLayerIndex: Int) -> Bool {
        let sourceLayerIndex = draggedData.sourceLayerIndex
        let objectId = draggedData.objectId
        let objectType = draggedData.objectType
        
        // PROTECT LOCKED LAYERS: Check if source layer is locked
        if sourceLayerIndex < document.layers.count && document.layers[sourceLayerIndex].isLocked {
            print("🚫 Cannot move objects from locked layer '\(document.layers[sourceLayerIndex].name)'")
            return false
        }
        
        // PROTECT LOCKED LAYERS: Check if target layer is locked
        if targetLayerIndex < document.layers.count && document.layers[targetLayerIndex].isLocked {
            print("🚫 Cannot move objects to locked layer '\(document.layers[targetLayerIndex].name)'")
            return false
        }
        
        // Don't drop on same layer if it's the same object
        if sourceLayerIndex == targetLayerIndex {
            return false
        }
        
        // PROTECT CANVAS LAYER: Never allow objects to be moved to Canvas layer (index 0)
        if targetLayerIndex == 0 {
            return false
        }
        
        // Ensure target layer exists
        guard targetLayerIndex < document.layers.count else {
            return false
        }
        
        document.saveToUndoStack()
        
        // Move the object based on its type
        if objectType == "shape" {
            // Find and move shape
            for layerIndex in document.layers.indices {
                if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == objectId }) {
                    let shape = document.layers[layerIndex].shapes.remove(at: shapeIndex)
                    document.layers[targetLayerIndex].shapes.append(shape)
                    
                    // Update selection to target layer
                    document.selectedLayerIndex = targetLayerIndex
                    document.selectedShapeIDs = [objectId]
                    
                    print("✅ Successfully moved shape '\(shape.name)' to layer '\(document.layers[targetLayerIndex].name)'")
                    return true
                }
            }
        } else if objectType == "text" {
            // For text objects, just associate with the target layer
            if document.textObjects.contains(where: { $0.id == objectId }) {
                // Update selection to target layer (text objects remain global)
                document.selectedLayerIndex = targetLayerIndex  
                document.selectedTextIDs = [objectId]
                
                print("✅ Successfully associated text object with layer '\(document.layers[targetLayerIndex].name)'")
                return true
            }
            
            print("❌ Could not find text object to move")
            return false
        }
        
        print("❌ Failed to find object to move")
        return false
    }
    
    private func layerColor(for index: Int) -> Color {
        let colors: [Color] = [.gray, .blue, .green, .orange, .purple, .red, .pink, .yellow, .cyan]
        return colors[index % colors.count]
    }
    
    private func objectCountInLayer(_ layerIndex: Int) -> Int {
        // Count text objects that conceptually belong to this layer
        return document.textObjects.filter { $0.isVisible }.count
    }
    
    @ViewBuilder
    private func objectInsertionZone(layerIndex: Int, insertionIndex: Int, isHighlighted: Bool) -> some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: 3)
            .overlay(
                Rectangle()
                    .fill(isHighlighted ? Color.blue : Color.clear)
                    .frame(height: 1)
                    .padding(.horizontal, 8)
            )
            .dropDestination(for: ObjectDragData.self) { items, location in
                guard let draggedData = items.first else { return false }
                return handleObjectInsertion(draggedData: draggedData, targetLayerIndex: layerIndex, insertionIndex: insertionIndex)
            } isTargeted: { isTargeted in
                if isTargeted {
                    onObjectDropTargetChanged(ObjectDropTarget(
                        layerIndex: layerIndex,
                        insertionIndex: insertionIndex,
                        isValid: true
                    ))
                } else {
                    onObjectDropTargetChanged(nil)
                }
            }
    }
    
    private func handleObjectInsertion(draggedData: ObjectDragData, targetLayerIndex: Int, insertionIndex: Int) -> Bool {
        let sourceLayerIndex = draggedData.sourceLayerIndex
        let objectId = draggedData.objectId
        let objectType = draggedData.objectType
        
        print("🎯 OBJECT INSERTION: Moving \(objectType) to layer \(targetLayerIndex) at index \(insertionIndex)")
        
        // PROTECT LOCKED LAYERS: Check if source layer is locked
        if sourceLayerIndex < document.layers.count && document.layers[sourceLayerIndex].isLocked {
            print("🚫 Cannot move objects from locked layer '\(document.layers[sourceLayerIndex].name)'")
            return false
        }
        
        // PROTECT LOCKED LAYERS: Check if target layer is locked
        if targetLayerIndex < document.layers.count && document.layers[targetLayerIndex].isLocked {
            print("🚫 Cannot move objects to locked layer '\(document.layers[targetLayerIndex].name)'")
            return false
        }
        
        // PROTECT CANVAS LAYER: Never allow objects to be moved to Canvas layer (index 0)
        if targetLayerIndex == 0 {
            print("🚫 Cannot move objects to Canvas layer")
            return false
        }
        
        // Ensure target layer exists
        guard targetLayerIndex < document.layers.count else {
            print("❌ Target layer index out of bounds")
            return false
        }
        
        document.saveToUndoStack()
        
        if objectType == "shape" {
            // Find and move shape
            for layerIdx in document.layers.indices {
                if let shapeIndex = document.layers[layerIdx].shapes.firstIndex(where: { $0.id == objectId }) {
                    let shape = document.layers[layerIdx].shapes.remove(at: shapeIndex)
                    
                    // FIXED: Handle insertion index calculation for same-layer vs cross-layer moves
                    let finalInsertionIndex: Int
                    
                    if layerIdx == targetLayerIndex {
                        // SAME LAYER: Adjust insertion index if we removed an object before the insertion point
                        if shapeIndex < insertionIndex {
                            // Removed object was before insertion point, so insertion index decreases by 1
                            finalInsertionIndex = max(0, insertionIndex - 1)
                        } else {
                            // Removed object was at or after insertion point, insertion index stays the same
                            finalInsertionIndex = min(insertionIndex, document.layers[targetLayerIndex].shapes.count)
                        }
                    } else {
                        // CROSS LAYER: Just ensure we don't exceed bounds
                        finalInsertionIndex = min(insertionIndex, document.layers[targetLayerIndex].shapes.count)
                    }
                    
                    // Insert at the calculated position
                    document.layers[targetLayerIndex].shapes.insert(shape, at: finalInsertionIndex)
                    
                    // Update selection to target layer
                    document.selectedLayerIndex = targetLayerIndex
                    document.selectedShapeIDs = [objectId]
                    
                    print("✅ Inserted shape '\(shape.name)' in layer '\(document.layers[targetLayerIndex].name)' at index \(finalInsertionIndex)")
                    return true
                }
            }
        } else if objectType == "text" {
            // For text objects, just associate with the target layer
            if document.textObjects.contains(where: { $0.id == objectId }) {
                document.selectedLayerIndex = targetLayerIndex  
                document.selectedTextIDs = [objectId]
                
                print("✅ Associated text object with layer '\(document.layers[targetLayerIndex].name)'")
                return true
            }
        }
        
        print("❌ Failed to find object to move")
        return false
    }
}

// CONDITIONAL DRAGGABLE MODIFIER FOR LOCKED OBJECT PROTECTION
struct ConditionalDraggableModifier<DragData: Transferable>: ViewModifier {
    let isEnabled: Bool
    let dragData: DragData
    let preview: AnyView
    
    func body(content: Content) -> some View {
        if isEnabled {
            content.draggable(dragData) {
                preview
            }
        } else {
            content
        }
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
    let layerIndex: Int
    let document: VectorDocument
    let onInsertionTargetChanged: (Int?) -> Void
    
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
            // PROTECT LOCKED LAYERS: Don't allow selection of objects on locked layers
            if layerIndex < document.layers.count && document.layers[layerIndex].isLocked {
                print("🚫 Cannot select objects on locked layer '\(document.layers[layerIndex].name)'")
                return
            }
            
            // PROTECT LOCKED OBJECTS: Don't allow selection of locked objects
            if isLocked {
                print("🚫 Cannot select locked object '\(name)'")
                return
            }
            
            onSelect()
        }
        .modifier(
            // CONDITIONAL DRAGGABLE: Only make draggable if layer and object are unlocked
            ConditionalDraggableModifier(
                isEnabled: !(layerIndex < document.layers.count && document.layers[layerIndex].isLocked) && !isLocked,
                dragData: ObjectDragData(objectType: objectType.rawValue, objectId: objectId, sourceLayerIndex: layerIndex),
                preview: AnyView(
                    Group {
                        if layerIndex < document.layers.count && document.layers[layerIndex].isLocked {
                            lockedLayerPreview
                        } else if isLocked {
                            lockedObjectPreview
                        } else {
                            objectDragPreview
                        }
                    }
                )
            )
        )
        .allowsHitTesting(!(layerIndex < document.layers.count && document.layers[layerIndex].isLocked) && !isLocked)
        .disabled(isLocked || (layerIndex < document.layers.count && document.layers[layerIndex].isLocked))
        .simultaneousGesture(
            DragGesture()
                .onChanged { _ in
                    // FIXED: Call onDrag to trigger isDraggingObject = true and show insertion zones
                    onDrag()
                }
                .onEnded { _ in
                    onInsertionTargetChanged(nil) // Clear insertion target when drag ends
                }
        )
        .dropDestination(for: ObjectDragData.self) { items, location in
            guard let draggedData = items.first else { return false }
            return handleObjectRearrange(draggedData: draggedData, targetObjectId: objectId, targetLayerIndex: layerIndex)
        } isTargeted: { isTargeted in
            if isTargeted {
                // Calculate insertion index for this object
                if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == objectId }) {
                    onInsertionTargetChanged(shapeIndex)
                } else {
                    onInsertionTargetChanged(nil)
                }
            } else {
                onInsertionTargetChanged(nil)
            }
        }
    }
    
    private var objectDragPreview: some View {
        HStack {
            Image(systemName: objectIcon)
                .font(.system(size: 10))
                .foregroundColor(objectIconColor)
            Text(name)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.blue.opacity(0.8))
        .foregroundColor(.white)
        .cornerRadius(3)
    }
    
    private func handleObjectRearrange(draggedData: ObjectDragData, targetObjectId: UUID, targetLayerIndex: Int) -> Bool {
        let sourceLayerIndex = draggedData.sourceLayerIndex
        let draggedObjectId = draggedData.objectId
        let objectType = draggedData.objectType
        
        // PROTECT LOCKED LAYERS: Check if source layer is locked
        if sourceLayerIndex < document.layers.count && document.layers[sourceLayerIndex].isLocked {
            print("🚫 Cannot move objects from locked layer '\(document.layers[sourceLayerIndex].name)'")
            return false
        }
        
        // PROTECT LOCKED LAYERS: Check if target layer is locked
        if targetLayerIndex < document.layers.count && document.layers[targetLayerIndex].isLocked {
            print("🚫 Cannot move objects to locked layer '\(document.layers[targetLayerIndex].name)'")
            return false
        }
        
        // PROTECT LOCKED OBJECTS: Check if dragged object is locked
        if objectType == "shape" {
            for layerIdx in document.layers.indices {
                if let shape = document.layers[layerIdx].shapes.first(where: { $0.id == draggedObjectId }) {
                    if shape.isLocked {
                        print("🚫 Cannot move locked shape '\(shape.name)'")
                        return false
                    }
                    break
                }
            }
        } else if objectType == "text" {
            if let textObject = document.textObjects.first(where: { $0.id == draggedObjectId }) {
                if textObject.isLocked {
                    print("🚫 Cannot move locked text object")
                    return false
                }
            }
        }
        
        // PROTECT LOCKED OBJECTS: Check if target object is locked
        if objectType == "shape" {
            if targetLayerIndex < document.layers.count {
                if let targetShape = document.layers[targetLayerIndex].shapes.first(where: { $0.id == targetObjectId }) {
                    if targetShape.isLocked {
                        print("🚫 Cannot drop onto locked target shape '\(targetShape.name)'")
                        return false
                    }
                }
            }
        }
        
        // PROTECT CANVAS LAYER: Never allow objects to be moved to Canvas layer (index 0)
        if targetLayerIndex == 0 {
            print("🚫 Cannot move objects to Canvas layer")
            return false
        }
        
        // Don't rearrange if it's the same object
        if draggedObjectId == targetObjectId {
            return false
        }
        
        document.saveToUndoStack()
        
        if objectType == "shape" {
            // Handle cross-layer movement or same-layer rearrangement
            if sourceLayerIndex == targetLayerIndex {
                // SAME LAYER: Rearrange objects within the layer
                guard let draggedShapeIndex = document.layers[sourceLayerIndex].shapes.firstIndex(where: { $0.id == draggedObjectId }),
                      let targetShapeIndex = document.layers[targetLayerIndex].shapes.firstIndex(where: { $0.id == targetObjectId }) else {
                    print("❌ Could not find dragged or target shape indices")
                    return false
                }
                
                print("🔄 SAME LAYER REORDER: Moving shape from index \(draggedShapeIndex) to position above index \(targetShapeIndex)")
                
                // Remove the dragged shape first
                let draggedShape = document.layers[sourceLayerIndex].shapes.remove(at: draggedShapeIndex)
                
                // FIXED: Calculate insertion index to place dragged object "above" target object in UI
                // Since UI shows objects in reverse order (highest index at top), 
                // placing "above" means inserting at targetIndex + 1 (after adjusting for removal)
                let newTargetIndex: Int
                if draggedShapeIndex < targetShapeIndex {
                    // Dragging from lower index to higher index area
                    // Target index shifts down by 1 after removal, but we want to insert ABOVE target
                    newTargetIndex = targetShapeIndex  // This puts it above the target in UI
                } else {
                    // Dragging from higher index to lower index area
                    // Target index unchanged after removal, insert above target
                    newTargetIndex = targetShapeIndex + 1  // This puts it above the target in UI
                }
                
                // Ensure we don't go out of bounds
                let finalIndex = min(newTargetIndex, document.layers[targetLayerIndex].shapes.count)
                
                // Insert at the calculated position
                document.layers[targetLayerIndex].shapes.insert(draggedShape, at: finalIndex)
                
                print("✅ Rearranged shape '\(draggedShape.name)' within layer '\(document.layers[targetLayerIndex].name)' to index \(finalIndex) (above target)")
                return true
            } else {
                // CROSS LAYER: Move object to different layer, place it near target object
                guard let targetShapeIndex = document.layers[targetLayerIndex].shapes.firstIndex(where: { $0.id == targetObjectId }) else {
                    print("❌ Could not find target shape index in target layer")
                    return false
                }
                
                // Find and remove shape from source layer
                for layerIdx in document.layers.indices {
                    if let shapeIndex = document.layers[layerIdx].shapes.firstIndex(where: { $0.id == draggedObjectId }) {
                        let shape = document.layers[layerIdx].shapes.remove(at: shapeIndex)
                        
                        // Insert above target object (higher index in UI means higher index in array)
                        let insertionIndex = min(targetShapeIndex + 1, document.layers[targetLayerIndex].shapes.count)
                        document.layers[targetLayerIndex].shapes.insert(shape, at: insertionIndex)
                        
                        // Update selection to target layer
                        document.selectedLayerIndex = targetLayerIndex
                        document.selectedShapeIDs = [draggedObjectId]
                        
                        print("✅ Moved shape '\(shape.name)' from '\(document.layers[layerIdx].name)' to '\(document.layers[targetLayerIndex].name)' at index \(insertionIndex)")
                        return true
                    }
                }
                
                print("❌ Could not find dragged shape in any layer")
                return false
            }
        } else if objectType == "text" {
            // For text objects, just associate with the target layer
            if document.textObjects.contains(where: { $0.id == draggedObjectId }) {
                document.selectedLayerIndex = targetLayerIndex  
                document.selectedTextIDs = [draggedObjectId]
                
                print("✅ Associated text object with layer '\(document.layers[targetLayerIndex].name)'")
                return true
            }
            
            print("❌ Could not find text object to move")
            return false
        }
        
        print("❌ Unknown object type: \(objectType)")
        return false
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
    
    private var lockedLayerPreview: some View {
        HStack {
            Image(systemName: "lock.fill")
                .font(.system(size: 10))
                .foregroundColor(.orange)
            Text("Layer Locked")
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.orange.opacity(0.8))
        .foregroundColor(.white)
        .cornerRadius(3)
    }
    
    private var lockedObjectPreview: some View {
        HStack {
            Image(systemName: "lock.fill")
                .font(.system(size: 10))
                .foregroundColor(.red)
            Text("Object Locked")
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.red.opacity(0.8))
        .foregroundColor(.white)
        .cornerRadius(3)
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