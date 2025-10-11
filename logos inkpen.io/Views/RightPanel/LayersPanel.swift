import SwiftUI
import UniformTypeIdentifiers
import Combine

// MARK: - Style Modifiers
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

// MARK: - View Extensions
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

// MARK: - Main View
struct LayersPanel: View {
    @ObservedObject var document: VectorDocument
    @State private var expandedLayers: Set<Int> = []
    @State private var renamingLayerIndex: Int?
    @State private var newLayerName: String = ""
    @State private var draggedLayerIndex: Int? = nil
    @State private var dragOffset: CGSize = .zero
    @State private var targetLayerIndex: Int? = nil
    @State private var showColorPicker: Bool = false

    private let layerRowHeight: CGFloat = 32

    private var allLayersHaveUniformHeight: Bool {
        for (index, layer) in document.layers.enumerated() {
            let isExpanded = if index <= 1 {
                document.settings.layerExpansionState[layer.id] ?? false
            } else {
                document.settings.layerExpansionState[layer.id] ?? true
            }

            if isExpanded {
                let hasObjects = document.unifiedObjects.contains { $0.layerIndex == index }
                if hasObjects {
                    return false
                }
            }
        }
        return true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            layersHeader
            Divider().padding(.horizontal, 8)

            if let selectedIndex = document.selectedLayerIndex, selectedIndex < document.layers.count {
                layerControlsSection(for: selectedIndex)
                Divider().padding(.horizontal, 8)
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
                .labelsHidden()
                .pickerStyle(.menu)

                Spacer()
                    .frame(width: 0)

                ColorSwatchButton(
                    color: Binding(
                        get: { document.layers[layerIndex].color },
                        set: { newColor in
                            document.saveToUndoStack()
                            document.layers[layerIndex].color = newColor
                        }
                    ),
                    availableColors: availableLayerColors()
                )

                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var layersScrollContent: some View {
        ScrollView(.vertical, showsIndicators: true) {
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ForEach(Array((0..<document.layers.count).reversed().enumerated()), id: \.element) { (index, layerIndex) in
                        layerRowContent(for: layerIndex)
                            .offset(draggedLayerIndex == layerIndex ? dragOffset : .zero)
                            .opacity(draggedLayerIndex == layerIndex ? 0.9 : 1.0)
                            .zIndex(draggedLayerIndex == layerIndex ? 100 : 0)
                            .gesture(
                                layerIndex > 1 ?
                                DragGesture(minimumDistance: 5)
                                    .onChanged { value in
                                        if draggedLayerIndex == nil {
                                            draggedLayerIndex = layerIndex
                                            document.selectedLayerIndex = layerIndex
                                        }

                                        dragOffset = value.translation

                                        let dragDistance = value.translation.height

                                        if abs(dragDistance) < layerRowHeight / 2 {
                                            targetLayerIndex = nil
                                        } else if dragDistance < 0 {
                                            let slots = Int(abs(dragDistance) / layerRowHeight)
                                            targetLayerIndex = max(2, layerIndex + slots + 1)
                                        } else {
                                            let slots = Int(abs(dragDistance) / layerRowHeight)
                                            targetLayerIndex = max(2, layerIndex - slots)
                                        }
                                    }
                                    .onEnded { value in
                                        dragOffset = .zero

                                        if let target = targetLayerIndex,
                                           let source = draggedLayerIndex,
                                           target != source && target >= 2 {
                                            document.moveLayer(from: source, to: target)
                                        }

                                        draggedLayerIndex = nil
                                        targetLayerIndex = nil
                                    }
                                : nil
                            )
                    }
                }
                .padding(.horizontal, 4)

                if allLayersHaveUniformHeight {
                    let iconSize: CGFloat = 20
                    let iconSpacing: CGFloat = 2
                    let rowPadding: CGFloat = 4

                    let eyeIconX = rowPadding + (iconSize / 2)
                    let lockIconX = rowPadding + iconSize + iconSpacing + (iconSize / 2)

                    ZStack {
                        ForEach(0..<document.layers.count, id: \.self) { index in
                            let rowY = CGFloat(document.layers.count - 1 - index) * layerRowHeight
                            let iconCenterY = rowY + (layerRowHeight / 2)

                            Color.red.opacity(0.0)
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
                                    document.saveToUndoStack()

                                    let startY = value.startLocation.y
                                    let layerIndex = Int(startY / layerRowHeight)
                                    let reversedIndex = document.layers.count - 1 - layerIndex

                                    if reversedIndex >= 0 && reversedIndex < document.layers.count {
                                        document.layers[reversedIndex].isVisible.toggle()
                                        document.processedLayersDuringDrag.insert(reversedIndex)
                                    }
                                }

                                let currentY = value.location.y
                                let layerIndex = Int(currentY / layerRowHeight)
                                let reversedIndex = document.layers.count - 1 - layerIndex

                                if reversedIndex >= 0 && reversedIndex < document.layers.count {
                                    if !document.processedLayersDuringDrag.contains(reversedIndex) {
                                        document.layers[reversedIndex].isVisible.toggle()
                                        document.processedLayersDuringDrag.insert(reversedIndex)
                                    }
                                }
                            }
                            .onEnded { _ in
                                document.isDraggingVisibility = false
                                document.processedLayersDuringDrag.removeAll()
                            }
                    )
                    .padding(.horizontal, 4)

                    ZStack {
                        ForEach(0..<document.layers.count, id: \.self) { index in
                            let rowY = CGFloat(document.layers.count - 1 - index) * layerRowHeight
                            let iconCenterY = rowY + (layerRowHeight / 2)

                            Color.red.opacity(0.0)
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
                                    document.saveToUndoStack()

                                    let startY = value.startLocation.y
                                    let layerIndex = Int(startY / layerRowHeight)
                                    let reversedIndex = document.layers.count - 1 - layerIndex

                                    if reversedIndex >= 0 && reversedIndex < document.layers.count {
                                        document.layers[reversedIndex].isLocked.toggle()
                                        document.processedLayersDuringDrag.insert(reversedIndex)
                                    }
                                }

                                let currentY = value.location.y
                                let layerIndex = Int(currentY / layerRowHeight)
                                let reversedIndex = document.layers.count - 1 - layerIndex

                                if reversedIndex >= 0 && reversedIndex < document.layers.count {
                                    if !document.processedLayersDuringDrag.contains(reversedIndex) {
                                        document.layers[reversedIndex].isLocked.toggle()
                                        document.processedLayersDuringDrag.insert(reversedIndex)
                                    }
                                }
                            }
                            .onEnded { _ in
                                document.isDraggingLock = false
                                document.processedLayersDuringDrag.removeAll()
                            }
                    )
                    .padding(.horizontal, 4)
                    .zIndex(200)
                }
            }
        }
    }


    private func availableLayerColors() -> [(name: String, color: Color)] {
        return [
            ("Red", Color(.displayP3, red: 0.75, green: 0.2, blue: 0.2)),
            ("Vermillion", Color(.displayP3, red: 0.8, green: 0.38, blue: 0.2)),
            ("Orange", Color(.displayP3, red: 0.85, green: 0.5, blue: 0.15)),
            ("Amber", Color(.displayP3, red: 0.82, green: 0.62, blue: 0.2)),
            ("Chartreuse", Color(.displayP3, red: 0.55, green: 0.72, blue: 0.2)),
            ("Lime", Color(.displayP3, red: 0.4, green: 0.68, blue: 0.28)),
            ("Green", Color(.displayP3, red: 0.2, green: 0.65, blue: 0.3)),
            ("Spring", Color(.displayP3, red: 0.2, green: 0.68, blue: 0.5)),
            ("Cyan", Color(.displayP3, red: 0.15, green: 0.65, blue: 0.72)),
            ("Sky", Color(.displayP3, red: 0.32, green: 0.58, blue: 0.82)),
            ("Azure", Color(.displayP3, red: 0.18, green: 0.4, blue: 0.78)),
            ("Blue", Color(.displayP3, red: 0.2, green: 0.25, blue: 0.75)),
            ("Violet", Color(.displayP3, red: 0.4, green: 0.25, blue: 0.7)),
            ("Purple", Color(.displayP3, red: 0.55, green: 0.25, blue: 0.65)),
            ("Magenta", Color(.displayP3, red: 0.7, green: 0.2, blue: 0.5)),
            ("Rose", Color(.displayP3, red: 0.8, green: 0.3, blue: 0.4))
        ]
    }

    private func layerRowContent(for layerIndex: Int) -> some View {
        ProfessionalLayerRow(
            layerIndex: layerIndex,
            layer: layerIndex < document.layers.count ? document.layers[layerIndex] : document.layers[0],
            document: document
        )
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