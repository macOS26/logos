import SwiftUI

struct ObjectRowIconStyle: ViewModifier {
    let size: CGFloat
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: size))
    }
}

struct ObjectRowTextStyle: ViewModifier {
    let size: CGFloat
    let isSelected: Bool
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: size))
            .foregroundColor(isSelected ? .blue : .primary)
            .lineLimit(1)
    }
}

struct ObjectRowChildTextStyle: ViewModifier {
    let size: CGFloat
    let isSelected: Bool
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: size))
            .foregroundColor(isSelected ? .blue : .secondary)
            .lineLimit(1)
    }
}

struct ObjectRowIndicatorStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 8))
            .foregroundColor(.secondary)
    }
}

extension View {
    func objectRowIcon(size: CGFloat) -> some View {
        modifier(ObjectRowIconStyle(size: size))
    }
    
    func objectRowText(size: CGFloat, isSelected: Bool) -> some View {
        modifier(ObjectRowTextStyle(size: size, isSelected: isSelected))
    }
    
    func objectRowChildText(size: CGFloat, isSelected: Bool) -> some View {
        modifier(ObjectRowChildTextStyle(size: size, isSelected: isSelected))
    }
    
    func objectRowIndicator() -> some View {
        modifier(ObjectRowIndicatorStyle())
    }
}

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
    
    private var isVisibleBinding: Binding<Bool> {
        Binding(
            get: { isVisible },
            set: { newValue in
                if let object = document.findObject(by: objectId) {
                    if case .shape(var shape) = object.objectType {
                        if shape.isVisible != newValue {
                            document.saveToUndoStack()
                            shape.isVisible = newValue
                            if let index = document.unifiedObjects.firstIndex(where: { $0.id == objectId }) {
                                document.unifiedObjects[index] = VectorObject(
                                    shape: shape,
                                    layerIndex: layerIndex,
                                    orderID: object.orderID
                                )
                            }
                        }
                    }
                }
            }
        )
    }
    
    private var isLockedBinding: Binding<Bool> {
        Binding(
            get: { isLocked },
            set: { newValue in
                if let object = document.findObject(by: objectId) {
                    if case .shape(var shape) = object.objectType {
                        if shape.isLocked != newValue {
                            document.saveToUndoStack()
                            shape.isLocked = newValue
                            if let index = document.unifiedObjects.firstIndex(where: { $0.id == objectId }) {
                                document.unifiedObjects[index] = VectorObject(
                                    shape: shape,
                                    layerIndex: layerIndex,
                                    orderID: object.orderID
                                )
                            }
                        }
                    }
                }
            }
        )
    }
    
    private func childVisibilityBinding(for childShapeId: UUID) -> Binding<Bool> {
        Binding(
            get: {
                if let object = document.findObject(by: objectId),
                   case .shape(let parentShape) = object.objectType,
                   let child = parentShape.groupedShapes.first(where: { $0.id == childShapeId }) {
                    return child.isVisible
                }
                return true
            },
            set: { newValue in
                if let object = document.findObject(by: objectId) {
                    if case .shape(var parentShape) = object.objectType {
                        if let childIndex = parentShape.groupedShapes.firstIndex(where: { $0.id == childShapeId }) {
                            parentShape.groupedShapes[childIndex].isVisible = newValue
                            document.saveToUndoStack()
                            if let objIndex = document.unifiedObjects.firstIndex(where: { $0.id == objectId }) {
                                document.unifiedObjects[objIndex] = VectorObject(
                                    shape: parentShape,
                                    layerIndex: layerIndex,
                                    orderID: document.unifiedObjects[objIndex].orderID
                                )
                            }
                        }
                    }
                }
            }
        )
    }
    
    private func childLockBinding(for childShapeId: UUID) -> Binding<Bool> {
        Binding(
            get: {
                if let object = document.findObject(by: objectId),
                   case .shape(let parentShape) = object.objectType,
                   let child = parentShape.groupedShapes.first(where: { $0.id == childShapeId }) {
                    return child.isLocked
                }
                return false
            },
            set: { newValue in
                if let object = document.findObject(by: objectId) {
                    if case .shape(var parentShape) = object.objectType {
                        if let childIndex = parentShape.groupedShapes.firstIndex(where: { $0.id == childShapeId }) {
                            parentShape.groupedShapes[childIndex].isLocked = newValue
                            document.saveToUndoStack()
                            if let objIndex = document.unifiedObjects.firstIndex(where: { $0.id == objectId }) {
                                document.unifiedObjects[objIndex] = VectorObject(
                                    shape: parentShape,
                                    layerIndex: layerIndex,
                                    orderID: document.unifiedObjects[objIndex].orderID
                                )
                            }
                        }
                    }
                }
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
                            .visibilityButton(isVisible: isVisibleBinding.wrappedValue)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .help(isVisibleBinding.wrappedValue ? "Hide Object" : "Show Object")
                    
                    Button(action: {
                        isLockedBinding.wrappedValue.toggle()
                    }) {
                        Image(systemName: isLockedBinding.wrappedValue ? "lock.fill" : "lock.open")
                            .lockButton(isLocked: isLockedBinding.wrappedValue)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .help(isLockedBinding.wrappedValue ? "Unlock Object" : "Lock Object")
                    
                    HStack(spacing: 4) {
                        if objectType == .group {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    isGroupExpanded.toggle()
                                }
                            }) {
                                Image(systemName: isGroupExpanded ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .frame(width: 12, height: 12)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .help("Expand/collapse group")
                        } else {
                            Color.clear.frame(width: 12, height: 12)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: objectIcon)
                                .font(.system(size: 10))
                                .foregroundColor(objectIconColor)
                                .frame(width: 12)
                            
                            Circle()
                                .fill(isSelected ? Color.blue : Color.clear)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                .frame(width: 8, height: 8)
                            
                            Text(name)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(isSelected ? Color.accentColor.opacity(0.2) : Color.clear, lineWidth: 1)
                            )
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        let isShiftPressed = NSEvent.modifierFlags.contains(.shift)
                        let isCommandPressed = NSEvent.modifierFlags.contains(.command)
                        onSelect(isShiftPressed, isCommandPressed)
                    }
                }
                .padding(.horizontal, 4)
            }
            .opacity(isDragging ? 0.5 : 1.0)
            .scaleEffect(isDragging ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isDragging)
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
                    isVisibleBinding.wrappedValue.toggle()
                }
                
                Button(isLocked ? "Unlock" : "Lock") {
                    isLockedBinding.wrappedValue.toggle()
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
                    let childVisBinding = childVisibilityBinding(for: childShape.id)
                    let childLockBinding = childLockBinding(for: childShape.id)
                    
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
                                childVisBinding.wrappedValue.toggle()
                            }) {
                                Image(systemName: childVisBinding.wrappedValue ? "eye" : "eye.slash")
                                    .visibilityButton(isVisible: childVisBinding.wrappedValue)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .help(childVisBinding.wrappedValue ? "Hide Object" : "Show Object")
                            
                            Button(action: {
                                childLockBinding.wrappedValue.toggle()
                            }) {
                                Image(systemName: childLockBinding.wrappedValue ? "lock.fill" : "lock.open")
                                    .lockButton(isLocked: childLockBinding.wrappedValue)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .help(childLockBinding.wrappedValue ? "Unlock Object" : "Lock Object")
                            
                            HStack(spacing: 4) {
                                Color.clear.frame(width: 12, height: 12)
                                
                                Image(systemName: childShape.isTextObject ? "textformat" : "square")
                                    .font(.system(size: 10))
                                    .foregroundColor(childShape.isTextObject ? .green : .blue)
                                    .frame(width: 12)
                                
                                Circle()
                                    .fill(isChildSelected ? Color.blue : Color.clear)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    .frame(width: 8, height: 8)
                                
                                Text(childShape.isTextObject ? (childShape.textContent ?? "Text") : childShape.name)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(isChildSelected ? .blue : .secondary)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 3)
                            .background(isChildSelected ? Color.blue.opacity(0.08) : Color.clear)
                        }
                        .padding(.horizontal, 4)
                    }
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
