import SwiftUI
import UniformTypeIdentifiers
import Combine

extension Color {
    static let layerColorPalette: [(name: String, color: Color)] = [
        (LayerColorName.maroon, Color(.displayP3, red: 0.75, green: 0.2, blue: 0.2)),
        (LayerColorName.red, Color.red),
        (LayerColorName.vermillion, Color(.displayP3, red: 0.8, green: 0.38, blue: 0.2)),
        (LayerColorName.rust, Color(.displayP3, red: 0.85, green: 0.5, blue: 0.15)),
        (LayerColorName.orange, Color.orange),
        (LayerColorName.amber, Color(.displayP3, red: 0.82, green: 0.62, blue: 0.2)),
        (LayerColorName.yellow, Color.yellow),
        (LayerColorName.chartreuse, Color(.displayP3, red: 0.55, green: 0.72, blue: 0.2)),
        (LayerColorName.lime, Color(.displayP3, red: 0.4, green: 0.68, blue: 0.28)),
        (LayerColorName.green, Color.green),
        (LayerColorName.emerald, Color(.displayP3, red: 0.2, green: 0.65, blue: 0.3)),
        (LayerColorName.spring, Color(.displayP3, red: 0.2, green: 0.68, blue: 0.5)),
        (LayerColorName.ocean, Color(.displayP3, red: 0.15, green: 0.65, blue: 0.72)),
        (LayerColorName.cyan, Color.cyan),
        (LayerColorName.sky, Color(.displayP3, red: 0.32, green: 0.58, blue: 0.82)),
        (LayerColorName.blue, Color.blue),
        (LayerColorName.azure, Color(.displayP3, red: 0.18, green: 0.4, blue: 0.78)),
        (LayerColorName.indigo, Color(.displayP3, red: 0.2, green: 0.25, blue: 0.75)),
        (LayerColorName.violet, Color(.displayP3, red: 0.4, green: 0.25, blue: 0.7)),
        (LayerColorName.orchid, Color(.displayP3, red: 0.55, green: 0.25, blue: 0.65)),
        (LayerColorName.purple, Color.purple),
        (LayerColorName.magenta, Color(.displayP3, red: 0.7, green: 0.2, blue: 0.5)),
        (LayerColorName.pink, Color.pink),
        (LayerColorName.rose, Color(.displayP3, red: 0.8, green: 0.3, blue: 0.4)),
        (LayerColorName.gray, Color.gray)
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

    func dragTarget() -> some View {
        modifier(DragTargetStyle())
    }
}

struct LayersPanel: View {
    @ObservedObject var document: VectorDocument
    @Binding var layerPreviewOpacities: [UUID: Double]
    @Binding var selectedLayerIndex: Int?  // DEPRECATED - kept for compatibility
    @Binding var processedLayersDuringDrag: Set<Int>
    @Binding var processedObjectsDuringDrag: Set<UUID>

    @State private var renamingLayerIndex: Int?
    @State private var newLayerName: String = ""
    @State private var showColorPicker: Bool = false
    @State private var overlaysEnabled: Bool = true
    @State private var rowHeights: [CGFloat] = []
    @State private var layerOpacityState: Double = 1.0
    @State private var lastSentPercentage: Int = 100
    @State private var computedSelectedIndex: Int? = nil

    // Get selected layer index from settings.selectedLayerId
    // Defaults to first editable layer (index 2, "Layer 1") if no layer is selected
    private var selectedIndex: Int? {
        if let selectedLayerId = document.settings.selectedLayerId {
            return document.snapshot.layers.firstIndex(where: { $0.id == selectedLayerId })
        }
        // Default to Layer 1 (index 2) when no layer is selected
        return document.snapshot.layers.count > 2 ? 2 : nil
    }

    private func updateSelectedIndex() {
        let newIndex = selectedIndex
        if computedSelectedIndex != newIndex {
            computedSelectedIndex = newIndex
            if let index = newIndex, index < document.snapshot.layers.count {
                layerOpacityState = document.snapshot.layers[index].opacity
            }
        }
    }

    private enum RowType: Hashable {
        case layer(index: Int)
        case object(layerIndex: Int, objectId: UUID)
        case childObject(layerIndex: Int, parentObjectId: UUID, childShapeId: UUID)
    }
    
    private var visibleRows: [RowType] {
        var rows: [RowType] = []
        
        for (layerIndex, layer) in document.snapshot.layers.enumerated().reversed() {
            rows.append(.layer(index: layerIndex))
            
            let isExpanded = if layerIndex <= 1 {
                document.settings.layerExpansionState[layer.id] ?? false
            } else {
                document.settings.layerExpansionState[layer.id] ?? true
            }
            
            if isExpanded {
                // Use the layer's objectIDs array from snapshot
                let objectIDs = document.snapshot.layers[layerIndex].objectIDs

                for objectID in objectIDs.reversed() {
                    if let object = document.snapshot.objects[objectID] {
                        rows.append(.object(layerIndex: layerIndex, objectId: object.id))

                        // Check if this is an expanded group or clipGroup
                        let isExpanded = document.settings.groupExpansionState[object.id] ?? false
                        if isExpanded {
                            switch object.objectType {
                            case .group(let shape), .clipGroup(let shape):
                                // Display reversed to match layer objectIDs display order
                                for childShape in shape.groupedShapes.reversed() {
                                    rows.append(.childObject(layerIndex: layerIndex, parentObjectId: object.id, childShapeId: childShape.id))
                                }
                            default:
                                break
                            }
                        }
                    }
                }
            }
        }
        
        return rows
    }

    private func validateOverlays() {
        let expectedRowCount = visibleRows.count
        let heightTolerance: CGFloat = 0.1

        var allHeightsSame = true
        let overlayRowCount = expectedRowCount

        if !rowHeights.isEmpty {
            let minHeight = rowHeights.min() ?? kLayerRowHeight
            let maxHeight = rowHeights.max() ?? kLayerRowHeight
            allHeightsSame = (maxHeight - minHeight) <= heightTolerance
        }

        let canDisplayOverlays = expectedRowCount > 0 && allHeightsSame && overlayRowCount == expectedRowCount

        DispatchQueue.main.async {
            if self.overlaysEnabled != canDisplayOverlays {
                self.overlaysEnabled = canDisplayOverlays
            }
        }
    }

    var body: some View {
        // Subscribe to layer changes to update selectedIndex
        let _ = document.snapshot.layers.count // Trigger view update when layers change
        let _ = document.viewState.layerUpdateTriggers // Subscribe to all layer updates
        let _ = document.changeNotifier.layerChangeToken // Subscribe to layer changes
        let _ = document.settings.selectedLayerId // Subscribe to selected layer changes

        VStack(alignment: .leading, spacing: 0) {
            layersHeader
            Divider().padding(.horizontal, 6.5)

            if let index = computedSelectedIndex {
                layerControlsSection(for: index)
                    .frame(maxWidth: .infinity)
                Divider().padding(.horizontal, 6.5)
            }

            layersScrollContent
            Spacer()
        }
        .background(
            KeyEventHandlerView(document: document, selectedLayerIndex: $selectedLayerIndex)
        )
        .onAppear {
            validateOverlays()
            updateSelectedIndex()
        }
        .onChange(of: document.snapshot.layers.map { $0.id }) { _, _ in
            validateOverlays()
            updateSelectedIndex()
        }
        .onChange(of: document.snapshot.layers.count) { _, _ in
            updateSelectedIndex()
        }
        .onChange(of: document.changeNotifier.changeToken) { _, _ in
            validateOverlays()
        }
        .onChange(of: document.settings.layerExpansionState) { _, _ in
            validateOverlays()
        }
        .onChange(of: document.settings.groupExpansionState) { _, _ in
            validateOverlays()
        }
        .onChange(of: document.settings.selectedLayerId) { _, _ in
            updateSelectedIndex()
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

                ZStack {
                    Capsule()
                        .fill(
                            SwiftUI.LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(white: 0.00),
                                    Color(white: 1.00)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 6)
                        .allowsHitTesting(false)
                    Slider(
                        value: $layerOpacityState,
                        in: 0...1,
                        onEditingChanged: { isEditing in
                            if !isEditing {
                                document.snapshot.layers[layerIndex].opacity = layerOpacityState
                                layerPreviewOpacities.removeValue(forKey: document.snapshot.layers[layerIndex].id)
                                document.triggerLayerUpdate(for: layerIndex)
                            }
                        }
                    )
                    .onChange(of: layerOpacityState) { _, newValue in
                        let currentPercentage = Int(newValue * 100)
                        if currentPercentage != lastSentPercentage {
                            lastSentPercentage = currentPercentage
                            layerPreviewOpacities[document.snapshot.layers[layerIndex].id] = newValue
                        }
                    }
                 
                    .controlSize(.regular)
                    .tint(Color.clear)
                }
                .frame(maxWidth: .infinity)

                Text("\(Int(layerOpacityState * 100))%")
                    .layerPercentage()
            }
            
            HStack(spacing: 8) {
                Text("Blend")
                    .layerControlLabel()
                
                Picker("", selection: Binding(
                    get: { document.snapshot.layers[layerIndex].blendMode },
                    set: { newValue in
                        var updatedLayer = document.snapshot.layers[layerIndex]
                        updatedLayer.blendMode = newValue
                        document.snapshot.layers[layerIndex] = updatedLayer
                        document.triggerLayerUpdate(for: layerIndex)
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
                        get: {
                            let colorName = document.snapshot.layers[layerIndex].color.name
                            return Color.layerColorPalette.first { $0.name == colorName }?.color ?? .blue
                        },
                        set: { newColor in
                            if let match = Color.layerColorPalette.first(where: { $0.color.description == newColor.description }) {
                                document.snapshot.layers[layerIndex].color = LayerColor(name: match.name)
                                document.triggerLayerUpdate(for: layerIndex)
                            }
                        }
                    ),
                    availableColors: Color.layerColorPalette
                )
                .offset(x:12)
                Text("Color")
                    .layerControlLabel()
                    .multilineTextAlignment(.trailing)
                    .offset(x:20)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    private var layersScrollContent: some View {
        return ScrollView(.vertical, showsIndicators: true) {
            ZStack(alignment: .topLeading) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(document.snapshot.layers.enumerated()).reversed(), id: \.element.id) { (layerIndex, layer) in
                        layerRowContent(for: layerIndex)
                            .id(layer.id) // Stable identity for efficient updates
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.9), value: document.snapshot.layers.map { $0.id })
                .padding(.horizontal, 4)

                if overlaysEnabled {
                    let iconSize: CGFloat = 20
                    let iconSpacing: CGFloat = 2
                    let rowPadding: CGFloat = 4
                    let eyeIconX = rowPadding + (iconSize / 2)
                    let lockIconX = rowPadding + iconSize + iconSpacing + (iconSize / 2)

                    ZStack {
                    ForEach(Array(visibleRows.enumerated()), id: \.offset) { rowIndex, rowType in
                        let rowY = CGFloat(rowIndex) * kLayerRowHeight
                        let iconCenterY = rowY + (kLayerRowHeight / 2)

                        Color.red.opacity(0.0000000)
                            .dragTarget()
                            .position(x: eyeIconX, y: iconCenterY)
                    }
                }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !document.viewState.isDraggingVisibility {
                                document.viewState.isDraggingVisibility = true
                                processedLayersDuringDrag.removeAll()
                                processedObjectsDuringDrag.removeAll()

                                let startY = value.startLocation.y
                                let rowIndex = Int(startY / kLayerRowHeight)

                                if rowIndex >= 0 && rowIndex < visibleRows.count {
                                    toggleVisibility(for: visibleRows[rowIndex])
                                }
                            }

                            let currentY = value.location.y
                            let rowIndex = Int(currentY / kLayerRowHeight)

                            if rowIndex >= 0 && rowIndex < visibleRows.count {
                                toggleVisibility(for: visibleRows[rowIndex])
                            }
                        }
                        .onEnded { _ in
                            document.viewState.isDraggingVisibility = false
                            processedLayersDuringDrag.removeAll()
                            processedObjectsDuringDrag.removeAll()
                        }
                )
                .padding(.horizontal, 4)
                
                ZStack {
                    ForEach(Array(visibleRows.enumerated()), id: \.offset) { rowIndex, rowType in
                        let rowY = CGFloat(rowIndex) * kLayerRowHeight
                        let iconCenterY = rowY + (kLayerRowHeight / 2)

                        Color.red.opacity(0.0000000)
                            .dragTarget()
                            .position(x: lockIconX, y: iconCenterY)
                    }
                }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !document.viewState.isDraggingLock {
                                document.viewState.isDraggingLock = true
                                processedLayersDuringDrag.removeAll()
                                processedObjectsDuringDrag.removeAll()

                                let startY = value.startLocation.y
                                let rowIndex = Int(startY / kLayerRowHeight)

                                if rowIndex >= 0 && rowIndex < visibleRows.count {
                                    toggleLock(for: visibleRows[rowIndex])
                                }
                            }

                            let currentY = value.location.y
                            let rowIndex = Int(currentY / kLayerRowHeight)

                            if rowIndex >= 0 && rowIndex < visibleRows.count {
                                toggleLock(for: visibleRows[rowIndex])
                            }
                        }
                        .onEnded { _ in
                            document.viewState.isDraggingLock = false
                            processedLayersDuringDrag.removeAll()
                            processedObjectsDuringDrag.removeAll()
                        }
                )
                .padding(.horizontal, 4)
                .zIndex(200)
                }
            }
        }
    }
    
    private func layerRowContent(for layerIndex: Int) -> some View {
        ProfessionalLayerRow(
            layerIndex: layerIndex,
            layer: layerIndex < document.snapshot.layers.count ? document.snapshot.layers[layerIndex] : Layer(name: "Invalid", objectIDs: []),
            document: document,
            selectedLayerIndex: $selectedLayerIndex
        )
    }
    
    private func toggleVisibility(for rowType: RowType) {
        switch rowType {
        case .layer(let index):
            if !processedLayersDuringDrag.contains(index) {
                document.snapshot.layers[index].isVisible.toggle()
                processedLayersDuringDrag.insert(index)
                document.triggerLayerUpdate(for: index)
            }
        case .object(let layerIndex, let objectId):
            if !processedObjectsDuringDrag.contains(objectId) {
                if let obj = document.snapshot.objects[objectId] {
                    var updatedShape: VectorShape?

                    switch obj.objectType {
                    case .shape(var shape), .text(var shape), .image(var shape), .group(var shape), .clipGroup(var shape), .warp(var shape), .clipMask(var shape):
                        shape.isVisible.toggle()
                        updatedShape = shape
                    }

                    if let shape = updatedShape {
                        let updatedObject = VectorObject(
                            shape: shape,
                            layerIndex: layerIndex
                        )
                        document.snapshot.objects[objectId] = updatedObject
                        processedObjectsDuringDrag.insert(objectId)
                        document.triggerLayerUpdate(for: layerIndex)
                    }
                }
            }
        case .childObject(let layerIndex, let parentObjectId, let childShapeId):
            if !processedObjectsDuringDrag.contains(childShapeId) {
                if let parentObj = document.snapshot.objects[parentObjectId] {
                    var updatedParentShape: VectorShape?

                    switch parentObj.objectType {
                    case .group(var parentShape), .clipGroup(var parentShape):
                        if let childIndex = parentShape.groupedShapes.firstIndex(where: { $0.id == childShapeId }) {
                            parentShape.groupedShapes[childIndex].isVisible.toggle()
                            updatedParentShape = parentShape
                        }
                    default:
                        break
                    }

                    if let parentShape = updatedParentShape {
                        let updatedObject = VectorObject(
                            id: parentObjectId,
                            layerIndex: layerIndex,
                            objectType: parentShape.isClippingGroup ? .clipGroup(parentShape) : .group(parentShape)
                        )
                        document.snapshot.objects[parentObjectId] = updatedObject
                        processedObjectsDuringDrag.insert(childShapeId)
                        document.triggerLayerUpdate(for: layerIndex)
                    }
                }
            }
        }
    }
    
    private func toggleLock(for rowType: RowType) {
        switch rowType {
        case .layer(let index):
            if !processedLayersDuringDrag.contains(index) {
                document.snapshot.layers[index].isLocked.toggle()
                processedLayersDuringDrag.insert(index)
                document.triggerLayerUpdate(for: index)
            }
        case .object(let layerIndex, let objectId):
            if !processedObjectsDuringDrag.contains(objectId) {
                if let obj = document.snapshot.objects[objectId] {
                    var updatedShape: VectorShape?

                    switch obj.objectType {
                    case .shape(var shape), .text(var shape), .image(var shape), .group(var shape), .clipGroup(var shape), .warp(var shape), .clipMask(var shape):
                        shape.isLocked.toggle()
                        updatedShape = shape
                    }

                    if let shape = updatedShape {
                        let updatedObject = VectorObject(
                            shape: shape,
                            layerIndex: layerIndex
                        )
                        document.snapshot.objects[objectId] = updatedObject
                        processedObjectsDuringDrag.insert(objectId)
                        document.triggerLayerUpdate(for: layerIndex)
                    }
                }
            }
        case .childObject(let layerIndex, let parentObjectId, let childShapeId):
            if !processedObjectsDuringDrag.contains(childShapeId) {
                if let parentObj = document.snapshot.objects[parentObjectId] {
                    if case .shape(var parentShape) = parentObj.objectType {
                        if let childIndex = parentShape.groupedShapes.firstIndex(where: { $0.id == childShapeId }) {
                            parentShape.groupedShapes[childIndex].isLocked.toggle()
                            let updatedObject = VectorObject(
                                shape: parentShape,
                                layerIndex: layerIndex,
                            )
                            document.snapshot.objects[parentObjectId] = updatedObject
                            processedObjectsDuringDrag.insert(childShapeId)
                            document.triggerLayerUpdate(for: layerIndex)
                        }
                    }
                }
            }
        }
    }
}

struct ColorSwatchButton<Content: View>: View {
    @Binding var color: Color
    let availableColors: [(name: String, color: Color)]
    let buttonContent: () -> Content
    @State private var showColorPicker: Bool = false

    init(
        color: Binding<Color>,
        availableColors: [(name: String, color: Color)],
        @ViewBuilder buttonContent: @escaping () -> Content
    ) {
        self._color = color
        self.availableColors = availableColors
        self.buttonContent = buttonContent
    }

    var body: some View {
        Button(action: {
            showColorPicker = true
        }) {
            buttonContent()
        }
        .buttonStyle(PlainButtonStyle())
        .popover(isPresented: $showColorPicker, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(availableColors, id: \.name) { colorOption in
                    Button(action: {
                        color = colorOption.color
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
    }
}

// Convenience extension for default swatch button style
extension ColorSwatchButton where Content == AnyView {
    init(color: Binding<Color>, availableColors: [(name: String, color: Color)]) {
        self._color = color
        self.availableColors = availableColors
        self.buttonContent = {
            AnyView(
                RoundedRectangle(cornerRadius: 20)
                    .fill(color.wrappedValue)
                    .padding(.horizontal, -3)
                    .frame(width: 14, height: 16)
            )
        }
    }
}

struct KeyEventHandlerView: NSViewRepresentable {
    @ObservedObject var document: VectorDocument
    @Binding var selectedLayerIndex: Int?

    func makeNSView(context: Context) -> NSView {
        let view = KeyEventHandlingNSView()
        view.document = document
        view.selectedLayerIndex = $selectedLayerIndex
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? KeyEventHandlingNSView {
            view.selectedLayerIndex = $selectedLayerIndex
        }
    }

    class KeyEventHandlingNSView: NSView {
        var document: VectorDocument?
        var selectedLayerIndex: Binding<Int?>?

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            guard let document = document else {
                super.keyDown(with: event)
                return
            }

            let modifiers = event.modifierFlags

            if modifiers.contains(.command) && !modifiers.contains(.option) {
if event.keyCode == 126 {
                    selectPreviousLayer(document: document)
                    return
} else if event.keyCode == 125 {
                    selectNextLayer(document: document)
                    return
                }
            }

            if modifiers.contains(.option) && !modifiers.contains(.command) {
if event.keyCode == 126 {
                    moveSelectedLayerUp(document: document)
                    return
} else if event.keyCode == 125 {
                    moveSelectedLayerDown(document: document)
                    return
                }
            }

            super.keyDown(with: event)
        }

        private func selectNextLayer(document: VectorDocument) {
            DispatchQueue.main.async {
                if !document.viewState.selectedObjectIDs.isEmpty {
                    self.selectNextObject(document: document)
                } else {
                    guard let currentIndex = self.selectedLayerIndex?.wrappedValue else {
                        if document.snapshot.layers.count > 2 {
                            self.selectedLayerIndex?.wrappedValue = 2
                        }
                        return
                    }

                    if currentIndex < document.snapshot.layers.count - 1 {
                        self.selectedLayerIndex?.wrappedValue = currentIndex + 1
                    }
                }
            }
        }

        private func selectPreviousLayer(document: VectorDocument) {
            DispatchQueue.main.async {
                if !document.viewState.selectedObjectIDs.isEmpty {
                    self.selectPreviousObject(document: document)
                } else {
                    guard let currentIndex = self.selectedLayerIndex?.wrappedValue else {
                        if document.snapshot.layers.count > 2 {
                            self.selectedLayerIndex?.wrappedValue = document.snapshot.layers.count - 1
                        }
                        return
                    }

                    if currentIndex > 2 {
                        self.selectedLayerIndex?.wrappedValue = currentIndex - 1
                    }
                }
            }
        }

        private func selectNextObject(document: VectorDocument) {
            guard let currentLayerIndex = self.selectedLayerIndex?.wrappedValue,
                  currentLayerIndex < document.snapshot.layers.count,
                  let firstSelectedId = document.viewState.selectedObjectIDs.first else { return }
            let objectIDs = document.snapshot.layers[currentLayerIndex].objectIDs
            let layerObjects = Array(objectIDs.compactMap { document.snapshot.objects[$0] }.reversed())

            if let currentIndex = layerObjects.firstIndex(where: { $0.id == firstSelectedId }) {
                if currentIndex < layerObjects.count - 1 {
                    let nextObject = layerObjects[currentIndex + 1]
                    document.viewState.selectedObjectIDs = [nextObject.id]
                }
            }
        }

        private func selectPreviousObject(document: VectorDocument) {
            guard let currentLayerIndex = self.selectedLayerIndex?.wrappedValue,
                  currentLayerIndex < document.snapshot.layers.count,
                  let firstSelectedId = document.viewState.selectedObjectIDs.first else { return }
            let objectIDs = document.snapshot.layers[currentLayerIndex].objectIDs
            let layerObjects = Array(objectIDs.compactMap { document.snapshot.objects[$0] }.reversed())

            if let currentIndex = layerObjects.firstIndex(where: { $0.id == firstSelectedId }) {
                if currentIndex > 0 {
                    let prevObject = layerObjects[currentIndex - 1]
                    document.viewState.selectedObjectIDs = [prevObject.id]
                }
            }
        }

        private func moveSelectedLayerUp(document: VectorDocument) {
            DispatchQueue.main.async {
                guard let currentIndex = self.selectedLayerIndex?.wrappedValue else { return }

                if currentIndex <= 1 { return }

                if currentIndex < document.snapshot.layers.count - 1 {
                    let targetIndex = currentIndex + 1
                    document.reorderLayer(sourceLayerId: document.snapshot.layers[currentIndex].id,
                                          targetLayerId: document.snapshot.layers[targetIndex].id)
                    self.selectedLayerIndex?.wrappedValue = targetIndex
                }
            }
        }

        private func moveSelectedLayerDown(document: VectorDocument) {
            DispatchQueue.main.async {
                guard let currentIndex = self.selectedLayerIndex?.wrappedValue else { return }

                if currentIndex <= 1 { return }

                if currentIndex > 2 {
                    let targetIndex = currentIndex - 1
                    document.reorderLayer(sourceLayerId: document.snapshot.layers[currentIndex].id,
                                          targetLayerId: document.snapshot.layers[targetIndex].id)
                    self.selectedLayerIndex?.wrappedValue = targetIndex
                }
            }
        }
    }
}
