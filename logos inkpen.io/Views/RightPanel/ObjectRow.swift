import SwiftUI
import Combine

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
    let onSelect: (_ isShiftPressed: Bool, _ isCommandPressed: Bool) -> Void
    let layerIndex: Int
    let document: VectorDocument
    let groupedShapes: [VectorShape]?
    let showBottomIndicator: Bool

    private var isGroupExpanded: Bool {
        document.settings.groupExpansionState[objectId] ?? false
    }

    private func setGroupExpanded(_ value: Bool) {
        var updatedSettings = document.settings
        updatedSettings.groupExpansionState[objectId] = value
        document.settings = updatedSettings
    }

    init(objectType: ObjectType, objectId: UUID, name: String, isSelected: Bool, onSelect: @escaping (_: Bool, _: Bool) -> Void, layerIndex: Int, document: VectorDocument, groupedShapes: [VectorShape]? = nil, showBottomIndicator: Bool = false) {
        self.objectType = objectType
        self.objectId = objectId
        self.name = name
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.layerIndex = layerIndex
        self.document = document
        self.groupedShapes = groupedShapes
        self.showBottomIndicator = showBottomIndicator
    }
    
    private var isVisibleBinding: Binding<Bool> {
        Binding(
            get: {
                if let object = document.findObject(by: objectId) {
                    switch object.objectType {
                    case .text(let shape),
                         .shape(let shape),
                         .warp(let shape),
                         .group(let shape),
                         .clipGroup(let shape),
                         .clipMask(let shape):
                        return shape.isVisible
                    }
                }
                return true
            },
            set: { newValue in
                guard let index = document.findObjectIndex(by: objectId) else { return }
                switch document.unifiedObjects[index].objectType {
                case .text(let shape),
                     .shape(let shape),
                     .warp(let shape),
                     .group(let shape),
                     .clipGroup(let shape),
                     .clipMask(let shape):
                    if shape.isVisible != newValue {
                        let command = VisibilityCommand(
                            objectIDs: [objectId],
                            property: .visibility,
                            oldValues: [objectId: shape.isVisible],
                            newValues: [objectId: newValue]
                        )
                        document.commandManager.execute(command)
                    }
                }
            }
        )
    }
    
    private var isLockedBinding: Binding<Bool> {
        Binding(
            get: {
                if let object = document.findObject(by: objectId) {
                    switch object.objectType {
                    case .text(let shape),
                         .shape(let shape),
                         .warp(let shape),
                         .group(let shape),
                         .clipGroup(let shape),
                         .clipMask(let shape):
                        return shape.isLocked
                    }
                }
                return false
            },
            set: { newValue in
                guard let index = document.findObjectIndex(by: objectId) else { return }
                switch document.unifiedObjects[index].objectType {
                case .text(let shape),
                     .shape(let shape),
                     .warp(let shape),
                     .group(let shape),
                     .clipGroup(let shape),
                     .clipMask(let shape):
                    if shape.isLocked != newValue {
                        let command = VisibilityCommand(
                            objectIDs: [objectId],
                            property: .locked,
                            oldValues: [objectId: shape.isLocked],
                            newValues: [objectId: newValue]
                        )
                        document.commandManager.execute(command)
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
                guard let objIndex = document.findObjectIndex(by: objectId) else { return }
                if case .shape(var parentShape) = document.unifiedObjects[objIndex].objectType {
                    if let childIndex = parentShape.groupedShapes.firstIndex(where: { $0.id == childShapeId }) {
                        parentShape.groupedShapes[childIndex].isVisible = newValue
                        
                        document.unifiedObjects[objIndex] = VectorObject(
                            shape: parentShape,
                            layerIndex: layerIndex,
                        )
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
                guard let objIndex = document.findObjectIndex(by: objectId) else { return }
                if case .shape(var parentShape) = document.unifiedObjects[objIndex].objectType {
                    if let childIndex = parentShape.groupedShapes.firstIndex(where: { $0.id == childShapeId }) {
                        parentShape.groupedShapes[childIndex].isLocked = newValue
                        document.unifiedObjects[objIndex] = VectorObject(
                            shape: parentShape,
                            layerIndex: layerIndex,
                        )
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
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                    setGroupExpanded(!isGroupExpanded)
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
                    .frame(height: kLayerRowHeight)
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
            .draggable(DraggableItem.vectorObject(
                DraggableVectorObject(
                    objectType: objectType == .text ? .text : .shape,
                    objectId: objectId,
                    sourceLayerIndex: layerIndex
                )
            )) {
                HStack(spacing: 4) {
                    Image(systemName: objectIcon)
                        .font(.system(size: 10))
                        .foregroundColor(objectIconColor)
                    Text(name)
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(6)
                .opacity(0.9)
            }
            .dropDestination(for: DraggableItem.self) { items, location in
                guard let droppedItem = items.first else { return false }

                guard case .vectorObject(let vectorObj) = droppedItem else {
                    return false
                }

                let droppedObjectId = vectorObj.objectId
                let sourceLayerIndex = vectorObj.sourceLayerIndex

                if droppedObjectId == objectId {
                    return false
                }

                if sourceLayerIndex == layerIndex {
                    document.reorderObject(objectId: droppedObjectId, targetObjectId: objectId)
                } else {
                    document.moveObjectToLayer(objectId: droppedObjectId, targetLayerIndex: layerIndex)
                    document.reorderObject(objectId: droppedObjectId, targetObjectId: objectId)
                }

                return true
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
                        document.viewState.selectedObjectIDs = [objectId]
                        document.removeSelectedShapes()
                    }
                } else {
                    Button("Duplicate Text") {
                    }
                    Button("Delete Text") {
                        document.viewState.selectedObjectIDs = [objectId]
                        document.removeSelectedText()
                    }
                }
                
                Divider()

                Button(isVisibleBinding.wrappedValue ? "Hide" : "Show") {
                    isVisibleBinding.wrappedValue.toggle()
                }

                Button(isLockedBinding.wrappedValue ? "Unlock" : "Lock") {
                    isLockedBinding.wrappedValue.toggle()
                }
            }
            
            if objectType == .group, isGroupExpanded, let shapes = groupedShapes {
                ForEach(Array(shapes.reversed().enumerated()), id: \.element.id) { index, childShape in
                    let isChildSelected = document.viewState.selectedObjectIDs.contains(childShape.id)
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

                                Image(systemName: childIconFor(childShape, index: index))
                                    .font(.system(size: 10))
                                    .foregroundColor(childIconColorFor(childShape, index: index))
                                    .frame(width: 12)
                                
                                Circle()
                                    .fill(isChildSelected ? Color.blue : Color.clear)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    .frame(width: 8, height: 8)
                                
                                Text(childShape.typography != nil ? (childShape.textContent ?? "Text") : childShape.name)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(isChildSelected ? .blue : .secondary)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 3)
                            .frame(height: kLayerRowHeight)
                            .background(isChildSelected ? Color.blue.opacity(0.08) : Color.clear)
                        }
                        .padding(.horizontal, 4)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        let isShiftPressed = NSEvent.modifierFlags.contains(.shift)
                        let isCommandPressed = NSEvent.modifierFlags.contains(.command)
                        
                        if isCommandPressed {
                            if document.viewState.selectedObjectIDs.contains(childShape.id) {
                                document.viewState.selectedObjectIDs.remove(childShape.id)
                            } else {
                                document.viewState.selectedObjectIDs.insert(childShape.id)
                            }
                        } else if isShiftPressed {
                            document.viewState.selectedObjectIDs.insert(childShape.id)
                        } else {
                            document.viewState.selectedObjectIDs = [childShape.id]
                        }
                    }
                }
            }
        }
    }

    private var objectIcon: String {
        switch objectType {
        case .shape:
            if let object = document.findObject(by: objectId),
               case .shape(let shape) = object.objectType {
                if shape.isWarpObject {
                    return "waveform.path"
                }
                if let geometricType = shape.geometricType {
                    return geometricType.iconName
                }
            }
            return "square"
        case .text: return "textformat"
        case .group: return "square.stack"
        }
    }

    private func childIconName(for shape: VectorShape) -> String {
        if shape.isWarpObject {
            return "waveform.path"
        }
        if let geometricType = shape.geometricType {
            return geometricType.iconName
        }
        return "square"
    }

    private func childIconFor(_ childShape: VectorShape, index: Int) -> String {
        if let object = document.findObject(by: objectId),
           case .shape(let parentShape) = object.objectType,
           parentShape.isClippingGroup,
           index == 0 {
            return "scissors"
        }

        if childShape.typography != nil {
            return "textformat"
        }
        return childIconName(for: childShape)
    }

    private func childIconColorFor(_ childShape: VectorShape, index: Int) -> Color {
        if let object = document.findObject(by: objectId),
           case .shape(let parentShape) = object.objectType,
           parentShape.isClippingGroup,
           index == 0 {
            return .orange
        }

        if childShape.typography != nil {
            return .green
        }
        return .blue
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
