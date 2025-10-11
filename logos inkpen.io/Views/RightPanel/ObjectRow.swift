import SwiftUI

struct ObjectRow: View {
    enum ObjectType: String {
        case shape = "shape"
        case text = "text"
        case group = "group"
    }

    let objectType: ObjectType
    let objectId: UUID
    let name: String
    let isSelected: Bool
    let isVisible: Bool
    let isLocked: Bool
    let onSelect: (_ isShiftPressed: Bool, _ isCommandPressed: Bool) -> Void
    let layerIndex: Int
    let document: VectorDocument
    let groupedShapes: [VectorShape]?

    @State private var isDragging = false
    @State private var isGroupExpanded = false
    @State private var isDropTarget = false

    init(objectType: ObjectType, objectId: UUID, name: String, isSelected: Bool, isVisible: Bool, isLocked: Bool, onSelect: @escaping (_: Bool, _: Bool) -> Void, layerIndex: Int, document: VectorDocument, groupedShapes: [VectorShape]? = nil) {
        self.objectType = objectType
        self.objectId = objectId
        self.name = name
        self.isSelected = isSelected
        self.isVisible = isVisible
        self.isLocked = isLocked
        self.onSelect = onSelect
        self.layerIndex = layerIndex
        self.document = document
        self.groupedShapes = groupedShapes
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                if objectType == .group {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isGroupExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isGroupExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 10, height: 10)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                } else {
                    Color.clear.frame(width: 10, height: 10)
                }

                Image(systemName: objectIcon)
                        .font(.system(size: 10))
                    .foregroundColor(objectIconColor)
                    .frame(width: 12)

                Circle()
                    .fill(isSelected ? Color.blue : Color.clear)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    .frame(width: 8, height: 8)

                Text(name)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .blue : .primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

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
            .opacity(isDragging ? 0.5 : 1.0)
            .scaleEffect(isDragging ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isDragging)
            .contentShape(Rectangle())
            .onTapGesture {
                let isShiftPressed = NSEvent.modifierFlags.contains(.shift)
                let isCommandPressed = NSEvent.modifierFlags.contains(.command)
                onSelect(isShiftPressed, isCommandPressed)
            }
        .draggable(DraggableVectorObject(
            objectType: objectType == .text ? .text : .shape,
            objectId: objectId,
            sourceLayerIndex: layerIndex
        )) {
            HStack(spacing: 4) {
                Image(systemName: objectIcon)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                Text(name)
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.8))
            .cornerRadius(6)
        }
        .onChange(of: isDragging) { oldValue, newValue in
        }
        .contextMenu {
            Button("Select") {
                onSelect(false, false)
            }

            Divider()

            if objectType == .shape {
                Button("Duplicate Shape") {
                }
                Button("Delete Shape") {
                    document.selectedShapeIDs = [objectId]
                    document.removeSelectedShapes()
                }
            } else {
                Button("Duplicate Text") {
                }
                Button("Delete Text") {
                    document.selectedTextIDs = [objectId]
                    document.removeSelectedText()
                }
            }

            Divider()

            Button(isVisible ? "Hide" : "Show") {
            }

            Button(isLocked ? "Unlock" : "Lock") {
            }
        }
        .dropDestination(for: DraggableVectorObject.self) { items, location in
            guard let droppedObject = items.first else { return false }

            if droppedObject.sourceLayerIndex != layerIndex {
                return false
            }

            if droppedObject.objectId == objectId {
                return false
            }

            document.reorderObject(objectId: droppedObject.objectId, targetObjectId: objectId)
            return true
        } isTargeted: { isTargeted in
            withAnimation(.easeInOut(duration: 0.15)) {
                isDropTarget = isTargeted
            }
        }
        .overlay(alignment: .top) {
            if isDropTarget {
                Rectangle()
                    .fill(Color.blue)
                    .frame(height: 2)
                    .transition(.opacity)
            }
        }

            if objectType == .group, isGroupExpanded, let shapes = groupedShapes {
                ForEach(shapes, id: \.id) { childShape in
                    let isChildSelected = document.selectedObjectIDs.contains(childShape.id)

                    HStack(spacing: 6) {
                        Color.clear.frame(width: 20)

                        Image(systemName: childShape.isTextObject ? "textformat" : "square")
                            .font(.system(size: 9))
                            .foregroundColor(childShape.isTextObject ? .green : .blue)
                            .frame(width: 12)

                        Circle()
                            .fill(isChildSelected ? Color.blue : Color.clear)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            .frame(width: 7, height: 7)

                        Text(childShape.isTextObject ? (childShape.textContent ?? "Text") : childShape.name)
                            .font(.system(size: 10))
                            .foregroundColor(isChildSelected ? .blue : .secondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(isChildSelected ? Color.blue.opacity(0.08) : Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        let isShiftPressed = NSEvent.modifierFlags.contains(.shift)
                        let isCommandPressed = NSEvent.modifierFlags.contains(.command)

                        if isCommandPressed {
                            if document.selectedObjectIDs.contains(childShape.id) {
                                document.selectedObjectIDs.remove(childShape.id)
                                if childShape.isTextObject {
                                    document.selectedTextIDs.remove(childShape.id)
                                } else {
                                    document.selectedShapeIDs.remove(childShape.id)
                                }
                            } else {
                                document.selectedObjectIDs.insert(childShape.id)
                                if childShape.isTextObject {
                                    document.selectedTextIDs.insert(childShape.id)
                                } else {
                                    document.selectedShapeIDs.insert(childShape.id)
                                }
                            }
                        } else if isShiftPressed {
                            document.selectedObjectIDs.insert(childShape.id)
                            if childShape.isTextObject {
                                document.selectedTextIDs.insert(childShape.id)
                            } else {
                                document.selectedShapeIDs.insert(childShape.id)
                            }
                        } else {
                            document.selectedObjectIDs = [childShape.id]
                            if childShape.isTextObject {
                                document.selectedTextIDs = [childShape.id]
                                document.selectedShapeIDs.removeAll()
                            } else {
                                document.selectedShapeIDs = [childShape.id]
                                document.selectedTextIDs.removeAll()
                            }
                        }
                        document.syncSelectionArrays()
                    }
                }
            }
        }
    }

    private var objectIcon: String {
        switch objectType {
        case .shape: return "square"
        case .text: return "textformat"
        case .group: return "square.stack"
        }
    }

    private var objectIconColor: Color {
        switch objectType {
        case .shape: return .blue
        case .text: return .green
        case .group: return .purple
        }
    }
}

struct PreferencesView: View {
    @Environment(AppState.self) private var appState
    @Environment(\._openURL) private var openURL
    @State private var pressureCurve: [CGPoint] = PreferencesView.defaultPressureCurve()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox(label: Label("Pressure Sensitivity", systemImage: "hand.draw").font(.headline)) {
                VStack(alignment: .leading, spacing: 12) {

                    PressureCurveEditor(curve: $pressureCurve, size: 300)
                        .padding(.vertical, 8)

                    HStack(spacing: 8) {
                        Button("Linear") {
                            pressureCurve = PreferencesView.defaultPressureCurve()
                        }
                        .buttonStyle(.bordered)

                        Button("Soft") {
                            pressureCurve = [
                                CGPoint(x: 0.0, y: 0.0),
                                CGPoint(x: 0.25, y: 0.4),
                                CGPoint(x: 0.5, y: 0.65),
                                CGPoint(x: 0.75, y: 0.85),
                                CGPoint(x: 1.0, y: 1.0)
                            ]
                        }
                        .buttonStyle(.bordered)

                        Button("Hard") {
                            pressureCurve = [
                                CGPoint(x: 0.0, y: 0.0),
                                CGPoint(x: 0.25, y: 0.1),
                                CGPoint(x: 0.5, y: 0.35),
                                CGPoint(x: 0.75, y: 0.6),
                                CGPoint(x: 1.0, y: 1.0)
                            ]
                        }
                        .buttonStyle(.bordered)

                        Spacer()
                    }
                }
                .padding(.vertical, 8)
            }

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 400, minHeight: 550)
        .onAppear {
            loadPressureCurve()
        }
        .onChange(of: pressureCurve) { oldValue, newValue in
            savePressureCurve()
        }
    }

    private func loadPressureCurve() {
        if let data = UserDefaults.standard.array(forKey: "pressureCurve") as? [[String: Double]] {
            let loadedCurve = data.compactMap { dict -> CGPoint? in
                guard let x = dict["x"], let y = dict["y"] else { return nil }
                return CGPoint(x: x, y: y)
            }
            if loadedCurve.count >= 2 {
                pressureCurve = loadedCurve
            }
        }
    }

    private func savePressureCurve() {
        let data = pressureCurve.map { ["x": $0.x, "y": $0.y] }
        UserDefaults.standard.set(data, forKey: "pressureCurve")
        UserDefaults.standard.synchronize()

        appState.pressureCurve = pressureCurve

    }

    static func defaultPressureCurve() -> [CGPoint] {
        return [
            CGPoint(x: 0.0, y: 0.0),
            CGPoint(x: 0.25, y: 0.25),
            CGPoint(x: 0.5, y: 0.5),
            CGPoint(x: 0.75, y: 0.75),
            CGPoint(x: 1.0, y: 1.0)
        ]
    }

    static func defaultPressureCurveData() -> Data {
        let defaultCurve = defaultPressureCurve()
        return (try? JSONEncoder().encode(defaultCurve)) ?? Data()
    }
}
