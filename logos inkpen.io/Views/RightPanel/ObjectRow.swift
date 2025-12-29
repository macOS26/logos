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
    let onSelect: (_ isShiftPressed: Bool, _ isCommandPressed: Bool) -> Void
    let layerIndex: Int
    let document: VectorDocument
    let memberIDs: [UUID]
    let showBottomIndicator: Bool

    private var isGroupExpanded: Bool {
        document.settings.groupExpansionState[objectId] ?? false
    }

    private func setGroupExpanded(_ value: Bool) {
        var updatedSettings = document.settings
        updatedSettings.groupExpansionState[objectId] = value
        document.settings = updatedSettings
    }

    init(objectType: ObjectType, objectId: UUID, name: String, isSelected: Bool, onSelect: @escaping (_: Bool, _: Bool) -> Void, layerIndex: Int, document: VectorDocument, memberIDs: [UUID] = [], showBottomIndicator: Bool = false) {
        self.objectType = objectType
        self.objectId = objectId
        self.name = name
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.layerIndex = layerIndex
        self.document = document
        self.memberIDs = memberIDs
        self.showBottomIndicator = showBottomIndicator
    }
    
    private var isVisibleBinding: Binding<Bool> {
        Binding(
            get: {
                if let object = document.snapshot.objects[objectId] {
                    switch object.objectType {
                    case .text(let shape),
                         .shape(let shape),
                         .image(let shape),
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
                guard let object = document.snapshot.objects[objectId] else { return }
                switch object.objectType {
                case .text(let shape),
                     .shape(let shape),
                     .image(let shape),
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
                if let object = document.snapshot.objects[objectId] {
                    switch object.objectType {
                    case .text(let shape),
                         .shape(let shape),
                         .image(let shape),
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
                guard let object = document.snapshot.objects[objectId] else { return }
                switch object.objectType {
                case .text(let shape),
                     .shape(let shape),
                     .image(let shape),
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
                // Members are now in snapshot.objects with their own UUIDs
                if let childObject = document.snapshot.objects[childShapeId] {
                    print("🔵 childVisibilityBinding GET: childShapeId=\(childShapeId), isVisible=\(childObject.shape.isVisible)")
                    return childObject.shape.isVisible
                }
                print("🔴 childVisibilityBinding GET: childShapeId=\(childShapeId) NOT FOUND in snapshot.objects")
                return true
            },
            set: { newValue in
                print("🟡 childVisibilityBinding SET: childShapeId=\(childShapeId), newValue=\(newValue)")
                // Update the child object directly in snapshot.objects
                guard let childObject = document.snapshot.objects[childShapeId] else {
                    print("🔴 childVisibilityBinding SET: childShapeId=\(childShapeId) NOT FOUND in snapshot.objects")
                    return
                }
                var shape = childObject.shape
                print("🟡 childVisibilityBinding SET: oldValue=\(shape.isVisible), newValue=\(newValue)")
                if shape.isVisible != newValue {
                    shape.isVisible = newValue
                    let updatedObject = VectorObject(
                        id: childShapeId,
                        layerIndex: childObject.layerIndex,
                        objectType: VectorObject.determineType(for: shape)
                    )
                    document.snapshot.objects[childShapeId] = updatedObject
                    document.changeNotifier.notifyObjectChanged(childShapeId)
                    document.triggerLayerUpdate(for: layerIndex)
                    print("🟢 childVisibilityBinding SET: Updated successfully")
                }
            }
        )
    }

    private func childLockBinding(for childShapeId: UUID) -> Binding<Bool> {
        Binding(
            get: {
                // Members are now in snapshot.objects with their own UUIDs
                if let childObject = document.snapshot.objects[childShapeId] {
                    return childObject.shape.isLocked
                }
                return false
            },
            set: { newValue in
                // Update the child object directly in snapshot.objects
                guard let childObject = document.snapshot.objects[childShapeId] else { return }
                var shape = childObject.shape
                if shape.isLocked != newValue {
                    shape.isLocked = newValue
                    let updatedObject = VectorObject(
                        id: childShapeId,
                        layerIndex: childObject.layerIndex,
                        objectType: VectorObject.determineType(for: shape)
                    )
                    document.snapshot.objects[childShapeId] = updatedObject
                    document.changeNotifier.notifyObjectChanged(childShapeId)
                    document.triggerLayerUpdate(for: layerIndex)
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

                            // Show member count for groups (like layers show object count)
                            if objectType == .group && !memberIDs.isEmpty {
                                Spacer()
                                Text("\(memberIDs.count)")
                                    .font(.system(size: 9))
                                    .multilineTextAlignment(.trailing)
                                    .foregroundColor(.secondary.opacity(0.8))
                                    .padding(.trailing, 4)
                            }
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

                Button("Duplicate") {
                }
                Button("Delete") {
                    document.viewState.orderedSelectedObjectIDs = [objectId]
                    document.viewState.selectedObjectIDs = [objectId]
                    if objectType == .shape {
                        document.removeSelectedShapes()
                    } else {
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
            
            if objectType == .group, isGroupExpanded, !memberIDs.isEmpty {
                // Resolve member shapes from snapshot.objects using memberIDs
                let memberShapes = memberIDs.compactMap { document.findShape(by: $0) }
                // Reverse for regular groups to match layer display order, but not for clip groups (mask must be first)
                let displayShapes = document.snapshot.objects[objectId].map { obj -> [VectorShape] in
                    if case .clipGroup = obj.objectType {
                        return memberShapes
                    } else {
                        return Array(memberShapes.reversed())
                    }
                } ?? memberShapes
                ForEach(Array(displayShapes.enumerated()), id: \.element.id) { index, childShape in
                    let isChildSelected = document.viewState.selectedObjectIDs.contains(childShape.id)
                    let childVisBinding = childVisibilityBinding(for: childShape.id)
                    let childLockBinding = childLockBinding(for: childShape.id)
                    let originalIndex = index

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
                                // Check if child is a nested group
                                if childShape.isGroupContainer {
                                    let isChildGroupExpanded = document.settings.groupExpansionState[childShape.id] ?? false
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                            var updatedSettings = document.settings
                                            updatedSettings.groupExpansionState[childShape.id] = !isChildGroupExpanded
                                            document.settings = updatedSettings
                                        }
                                    }) {
                                        Image(systemName: isChildGroupExpanded ? "chevron.down" : "chevron.right")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.secondary)
                                            .frame(width: 12, height: 12)
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                    .help("Expand/collapse nested group")
                                } else {
                                    Color.clear.frame(width: 12, height: 12)
                                }

                                Image(systemName: childIconFor(childShape, index: originalIndex))
                                    .font(.system(size: 10))
                                    .foregroundColor(childIconColorFor(childShape, index: originalIndex))
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

                                // Show member count for nested groups
                                if childShape.isGroupContainer {
                                    Spacer()
                                    let childMemberCount = childShape.memberIDs.isEmpty ? childShape.groupedShapes.count : childShape.memberIDs.count
                                    Text("\(childMemberCount)")
                                        .font(.system(size: 9))
                                        .multilineTextAlignment(.trailing)
                                        .foregroundColor(.secondary.opacity(0.8))
                                        .padding(.trailing, 4)
                                }
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
                                document.viewState.orderedSelectedObjectIDs.removeAll { $0 == childShape.id }
                                document.viewState.selectedObjectIDs.remove(childShape.id)
                            } else {
                                document.viewState.orderedSelectedObjectIDs.append(childShape.id)
                                document.viewState.selectedObjectIDs.insert(childShape.id)
                            }
                        } else if isShiftPressed {
                            if !document.viewState.selectedObjectIDs.contains(childShape.id) {
                                document.viewState.orderedSelectedObjectIDs.append(childShape.id)
                            }
                            document.viewState.selectedObjectIDs.insert(childShape.id)
                        } else {
                            document.viewState.orderedSelectedObjectIDs = [childShape.id]
                            document.viewState.selectedObjectIDs = [childShape.id]
                        }
                    }

                    // Recursively render nested group children if this child is an expanded group
                    if childShape.isGroupContainer {
                        let isNestedGroupExpanded = document.settings.groupExpansionState[childShape.id] ?? false
                        if isNestedGroupExpanded {
                            let nestedMemberIDs = childShape.memberIDs.isEmpty ? childShape.groupedShapes.map { $0.id } : childShape.memberIDs
                            NestedGroupChildrenView(
                                memberIDs: nestedMemberIDs,
                                layerIndex: layerIndex,
                                document: document
                            )
                        }
                    }
                }
            }
        }
    }
}

// Recursive view for nested group children
struct NestedGroupChildrenView: View {
    let memberIDs: [UUID]
    let layerIndex: Int
    @ObservedObject var document: VectorDocument

    private func childVisibilityBinding(for childShapeId: UUID) -> Binding<Bool> {
        Binding(
            get: {
                if let childObject = document.snapshot.objects[childShapeId] {
                    return childObject.shape.isVisible
                }
                return true
            },
            set: { newValue in
                guard let childObject = document.snapshot.objects[childShapeId] else { return }
                var shape = childObject.shape
                if shape.isVisible != newValue {
                    shape.isVisible = newValue
                    let updatedObject = VectorObject(
                        id: childShapeId,
                        layerIndex: childObject.layerIndex,
                        objectType: VectorObject.determineType(for: shape)
                    )
                    document.snapshot.objects[childShapeId] = updatedObject
                    document.changeNotifier.notifyObjectChanged(childShapeId)
                    document.triggerLayerUpdate(for: layerIndex)
                }
            }
        )
    }

    private func childLockBinding(for childShapeId: UUID) -> Binding<Bool> {
        Binding(
            get: {
                if let childObject = document.snapshot.objects[childShapeId] {
                    return childObject.shape.isLocked
                }
                return false
            },
            set: { newValue in
                guard let childObject = document.snapshot.objects[childShapeId] else { return }
                var shape = childObject.shape
                if shape.isLocked != newValue {
                    shape.isLocked = newValue
                    let updatedObject = VectorObject(
                        id: childShapeId,
                        layerIndex: childObject.layerIndex,
                        objectType: VectorObject.determineType(for: shape)
                    )
                    document.snapshot.objects[childShapeId] = updatedObject
                    document.changeNotifier.notifyObjectChanged(childShapeId)
                    document.triggerLayerUpdate(for: layerIndex)
                }
            }
        )
    }

    var body: some View {
        let memberShapes = memberIDs.compactMap { document.findShape(by: $0) }
        let displayShapes = Array(memberShapes.reversed())

        ForEach(Array(displayShapes.enumerated()), id: \.element.id) { index, childShape in
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

                    Button(action: {
                        childLockBinding.wrappedValue.toggle()
                    }) {
                        Image(systemName: childLockBinding.wrappedValue ? "lock.fill" : "lock.open")
                            .lockButton(isLocked: childLockBinding.wrappedValue)
                    }
                    .buttonStyle(BorderlessButtonStyle())

                    HStack(spacing: 4) {
                        if childShape.isGroupContainer {
                            let isChildGroupExpanded = document.settings.groupExpansionState[childShape.id] ?? false
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                    var updatedSettings = document.settings
                                    updatedSettings.groupExpansionState[childShape.id] = !isChildGroupExpanded
                                    document.settings = updatedSettings
                                }
                            }) {
                                Image(systemName: isChildGroupExpanded ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .frame(width: 12, height: 12)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        } else {
                            Color.clear.frame(width: 12, height: 12)
                        }

                        Image(systemName: childShape.isGroupContainer ? "folder" : "square")
                            .font(.system(size: 10))
                            .foregroundColor(childShape.isGroupContainer ? .purple : .blue)
                            .frame(width: 12)

                        Circle()
                            .fill(isChildSelected ? Color.blue : Color.clear)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            .frame(width: 8, height: 8)

                        Text(childShape.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(isChildSelected ? .blue : .secondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if childShape.isGroupContainer {
                            Spacer()
                            let childMemberCount = childShape.memberIDs.isEmpty ? childShape.groupedShapes.count : childShape.memberIDs.count
                            Text("\(childMemberCount)")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary.opacity(0.8))
                                .padding(.trailing, 4)
                        }
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
                        document.viewState.orderedSelectedObjectIDs.removeAll { $0 == childShape.id }
                        document.viewState.selectedObjectIDs.remove(childShape.id)
                    } else {
                        document.viewState.orderedSelectedObjectIDs.append(childShape.id)
                        document.viewState.selectedObjectIDs.insert(childShape.id)
                    }
                } else if isShiftPressed {
                    if !document.viewState.selectedObjectIDs.contains(childShape.id) {
                        document.viewState.orderedSelectedObjectIDs.append(childShape.id)
                    }
                    document.viewState.selectedObjectIDs.insert(childShape.id)
                } else {
                    document.viewState.orderedSelectedObjectIDs = [childShape.id]
                    document.viewState.selectedObjectIDs = [childShape.id]
                }
            }

            // Recursively render deeper nested groups
            if childShape.isGroupContainer {
                let isNestedGroupExpanded = document.settings.groupExpansionState[childShape.id] ?? false
                if isNestedGroupExpanded {
                    let nestedMemberIDs = childShape.memberIDs.isEmpty ? childShape.groupedShapes.map { $0.id } : childShape.memberIDs
                    NestedGroupChildrenView(
                        memberIDs: nestedMemberIDs,
                        layerIndex: layerIndex,
                        document: document
                    )
                }
            }
        }
    }
}

extension ObjectRow {
    private var objectIcon: String {
        switch objectType {
        case .shape:
            if let object = document.snapshot.objects[objectId],
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
        case .group: return "folder.fill"
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
        if let object = document.snapshot.objects[objectId] {
            switch object.objectType {
            case .clipGroup:
                if index == 0 {
                    return "scissors"
                }
            default:
                break
            }
        }

        if childShape.typography != nil {
            return "textformat"
        }
        // Use outlined folder icon for nested groups
        if childShape.isGroupContainer {
            return "folder"
        }
        return childIconName(for: childShape)
    }

    private func childIconColorFor(_ childShape: VectorShape, index: Int) -> Color {
        if let object = document.snapshot.objects[objectId] {
            switch object.objectType {
            case .clipGroup:
                if index == 0 {
                    return .orange
                }
            default:
                break
            }
        }

        if childShape.typography != nil {
            return .green
        }
        // Use purple for nested groups
        if childShape.isGroupContainer {
            return .purple
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
