import SwiftUI
import AppKit
import Combine

struct GradientPanel: View {
    let snapshot: DocumentSnapshot
    let selectedObjectIDs: Set<UUID>
    let document: VectorDocument
    @Binding var activeGradientDelta: VectorGradient?
    @Binding var activeColorTarget: ColorTarget

    var body: some View {
        ScrollView {
            VStack() {
                GradientFillSection(
                    snapshot: snapshot,
                    selectedObjectIDs: selectedObjectIDs,
                    document: document,
                    activeGradientDelta: $activeGradientDelta,
                    activeColorTarget: $activeColorTarget
                )
                Spacer()
            }
        }
    }
}

struct GradientFillSection: View {
    let snapshot: DocumentSnapshot
    let selectedObjectIDs: Set<UUID>
    let document: VectorDocument
    @Binding var activeGradientDelta: VectorGradient?
    @Binding var activeColorTarget: ColorTarget
    @Environment(AppState.self) private var appState
    @State private var gradientType: GradientType = .linear
    @State private var currentGradient: VectorGradient? = nil
    @State private var gradientId: UUID = UUID()
    @State private var isEditingAngle: Bool = false
    @State private var showingGradientColorPicker = false
    @State private var editingGradientStopId: UUID?
    @State private var editingGradientStopColor: VectorColor = .black
    @State private var dragStartGradient: VectorGradient? = nil
    @State private var dragStartOpacities: [UUID: Double] = [:]
    @State private var dragStartGradients: [UUID: VectorGradient?] = [:]

    enum GradientType: String, CaseIterable {
        case linear = "Linear"
        case radial = "Radial"
    }

    init(snapshot: DocumentSnapshot, selectedObjectIDs: Set<UUID>, document: VectorDocument, activeGradientDelta: Binding<VectorGradient?>, activeColorTarget: Binding<ColorTarget>) {
        self.snapshot = snapshot
        self.selectedObjectIDs = selectedObjectIDs
        self.document = document
        self._activeGradientDelta = activeGradientDelta
        self._activeColorTarget = activeColorTarget

        if let selectedGradient = Self.getSelectedShapeGradient(snapshot: snapshot, selectedObjectIDs: selectedObjectIDs, activeColorTarget: activeColorTarget.wrappedValue) {
            _currentGradient = State(initialValue: selectedGradient)
            switch selectedGradient {
            case .linear:
                _gradientType = State(initialValue: .linear)
            case .radial:
                _gradientType = State(initialValue: .radial)
            }
        } else {
            _currentGradient = State(initialValue: Self.createDefaultGradient(type: .linear))
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Gradient Fill")
                .font(.headline)
                .fontWeight(.medium)

            GradientTypePickerView(
                gradientType: $gradientType,
                currentGradient: $currentGradient,
                gradientId: $gradientId,
                getGradientStops: getGradientStops,
                createGradientPreservingProperties: Self.createGradientPreservingProperties,
                createDefaultGradient: Self.createDefaultGradient,
                onGradientChange: applyGradientToSelectedShapes
            )

            GradientAngleControlView(
                currentGradient: currentGradient,
                document: document,
                onAngleChange: updateGradientAngle,
                onEditingChanged: { isEditing in
                    if isEditing {
                        // Drag started - capture old gradient state
                        captureOldGradientState()
                    } else {
                        // Drag ended - commit with undo
                        commitGradientChangeWithUndo()
                    }
                }
            )

            GradientOriginControlView(
                currentGradient: currentGradient,
                document: document,
                updateOriginX: { newX in
                    updateGradientOrigin(x: newX, y: nil)
                },
                updateOriginY: { newY in
                    updateGradientOrigin(x: nil, y: newY)
                },
                onEditingChanged: { isEditing in
                    if isEditing {
                        // Drag started - capture old gradient state
                        captureOldGradientState()
                    } else {
                        // Drag ended - commit with undo
                        commitGradientChangeWithUndo()
                    }
                }
            )

            GradientScaleControlView(
                currentGradient: currentGradient,
                document: document,
                getScale: getGradientScale,
                updateScale: updateGradientScale,
                getAspectRatio: getGradientAspectRatio,
                updateAspectRatio: updateGradientAspectRatio,
                getRadius: getGradientRadius,
                updateRadius: updateGradientRadius,
                onEditingChanged: { isEditing in
                    if isEditing {
                        captureOldGradientState()
                    } else {
                        commitGradientChangeWithUndo()
                    }
                }
            )

            GradientPreviewAndStopsView(
                currentGradient: currentGradient,
                document: document,
                activeColorTarget: activeColorTarget,
                editingGradientStopId: $editingGradientStopId,
                editingGradientStopColor: $editingGradientStopColor,
                showingGradientColorPicker: $showingGradientColorPicker,
                getGradientStops: getGradientStops,
                getOriginX: getGradientOriginX,
                getOriginY: getGradientOriginY,
                getScale: getGradientScale,
                getAspectRatio: getGradientAspectRatio,
                updateOriginX: { _, _ in },  // Deprecated - using delta pattern
                updateOriginY: { _, _ in },  // Deprecated - using delta pattern
                updateOriginXOptimized: { newX, _, _ in updateGradientOrigin(x: newX, y: nil) },
                updateOriginYOptimized: { newY, _, _ in updateGradientOrigin(x: nil, y: newY) },
                onOriginEditingChanged: { isEditing in
                    if isEditing {
                        captureOldGradientState()
                    } else {
                        commitGradientChangeWithUndo()
                    }
                },
                addColorStop: addColorStop,
                updateStopPosition: updateStopPosition,
                updateStopOpacity: updateStopOpacity,
                removeColorStop: removeColorStop,
                applyGradientToSelectedShapes: applyGradientToSelectedShapes,
                applyGradientToSelectedShapesOptimized: applyGradientToSelectedShapesOptimized,
                activateGradientStop: updateStopColor,
                onStopEditingChanged: { isEditing in
                    if isEditing {
                        captureOldGradientState()
                    } else {
                        commitGradientChangeWithUndo()
                    }
                }
            )

            GradientApplyButtonView(
                currentGradient: currentGradient,
                onApply: applyGradientToSelectedShapes,
                onAddSwatch: addGradientToSwatches,
                addColorStop: addColorStop
            )
        }
        .padding()
        .background(Color.ui.semiTransparentControlBackground)
        .cornerRadius(12)
        .onChange(of: selectedObjectIDs) { _, _ in
            updateSelectedGradient()
        }
        .onChange(of: activeColorTarget) { _, _ in
            updateSelectedGradient()
        }
        .onChange(of: document.changeNotifier.changeToken) { _, _ in
            // Sync gradient state from document when snapshot changes (e.g., after undo)
            updateSelectedGradient()
        }
    }

    private func turnOffEditingState() {
        editingGradientStopId = nil

        DispatchQueue.main.async {
            if self.editingGradientStopId != nil {
                self.editingGradientStopId = nil
            }
        }
    }

    private func activateGradientStop(_ stopId: UUID, color: VectorColor) {
        // Simply update the stop color - popover handles the UI
        updateStopColor(stopId: stopId, color: color)
    }

    private func updateSelectedGradient() {

        if let selectedGradient = Self.getSelectedShapeGradient(snapshot: snapshot, selectedObjectIDs: selectedObjectIDs, activeColorTarget: activeColorTarget) {
            currentGradient = selectedGradient
            switch selectedGradient {
            case .linear:
                gradientType = .linear
            case .radial:
                gradientType = .radial
            }
            gradientId = UUID()
            // Clear delta so canvas uses snapshot gradient
            activeGradientDelta = nil
        }
    }


    private func updateGradientAngle(_ newAngle: Double) {
        guard let gradient = currentGradient else { return }

        var normalizedAngle = newAngle
        while normalizedAngle > 180 {
            normalizedAngle -= 360
        }
        while normalizedAngle < -180 {
            normalizedAngle += 360
        }

        // print("🎨 GRADIENT ANGLE DRAG: Updating to \(normalizedAngle)")

        switch gradient {
        case .linear(var linear):
            linear.angle = normalizedAngle
            currentGradient = .linear(linear)
            activeGradientDelta = currentGradient
            // print("🎨 GRADIENT ANGLE DRAG: Set activeGradientDelta = \(String(describing: activeGradientDelta))")
        case .radial(var radial):
            radial.angle = normalizedAngle
            currentGradient = .radial(radial)
            activeGradientDelta = currentGradient
            // print("🎨 GRADIENT ANGLE DRAG: Set activeGradientDelta = \(String(describing: activeGradientDelta))")
        }
    }

    private func updateGradientOrigin(x: Double?, y: Double?) {
        guard let gradient = currentGradient else { return }

        switch gradient {
        case .linear(var linear):
            if let newX = x {
                linear.originPoint.x = newX
            }
            if let newY = y {
                linear.originPoint.y = newY
            }
            currentGradient = .linear(linear)
            activeGradientDelta = currentGradient
        case .radial(var radial):
            if let newX = x {
                radial.originPoint.x = newX
            }
            if let newY = y {
                radial.originPoint.y = newY
            }
            currentGradient = .radial(radial)
            activeGradientDelta = currentGradient
        }
    }

    private func commitGradientChange() {
        guard currentGradient != nil else { return }

        // print("🎨 GRADIENT DRAG END: Committing gradient change")

        // Clear the delta
        activeGradientDelta = nil
        // print("🎨 GRADIENT DRAG END: Cleared activeGradientDelta")

        // Apply to document snapshot + record undo
        applyGradientToSelectedShapes()
        // print("🎨 GRADIENT DRAG END: Applied to snapshot + recorded undo")
    }

    private func captureOldGradientState() {
        // Capture old gradients and opacities from LIVE document.snapshot before drag starts
        dragStartGradients.removeAll()
        dragStartOpacities.removeAll()

        let isStroke = activeColorTarget == .stroke

        for objectID in selectedObjectIDs {
            if let obj = document.snapshot.objects[objectID] {
                let shape = obj.shape
                if isStroke {
                    if let strokeStyle = shape.strokeStyle, case .gradient(let gradient) = strokeStyle.color {
                        dragStartGradients[objectID] = gradient
                        dragStartOpacities[objectID] = strokeStyle.opacity
                    } else {
                        dragStartGradients[objectID] = nil
                        dragStartOpacities[objectID] = 1.0
                    }
                } else {
                    if let fillStyle = shape.fillStyle, case .gradient(let gradient) = fillStyle.color {
                        dragStartGradients[objectID] = gradient
                        dragStartOpacities[objectID] = fillStyle.opacity
                    } else {
                        dragStartGradients[objectID] = nil
                        dragStartOpacities[objectID] = 1.0
                    }
                }
            }
        }
    }

    private func commitGradientChangeWithUndo() {
        guard let newGradient = currentGradient else { return }

        // print("🎨 COMMIT START: activeGradientDelta = \(activeGradientDelta != nil ? "SET" : "nil")")
        // print("🎨 COMMIT START: currentGradient stops = \(newGradient.stops.map { $0.color })")

        // Collect new gradients and opacities BEFORE the command updates anything
        var newGradients: [UUID: VectorGradient?] = [:]
        var newOpacities: [UUID: Double] = [:]

        for objectID in selectedObjectIDs {
            newGradients[objectID] = newGradient
            if let obj = document.snapshot.objects[objectID] {
                // Use the correct opacity based on activeColorTarget
                if activeColorTarget == .fill {
                    newOpacities[objectID] = obj.shape.fillStyle?.opacity ?? 1.0
                } else {
                    newOpacities[objectID] = obj.shape.strokeStyle?.opacity ?? 1.0
                }
            }
        }

        // Create and execute undo command - this will update the snapshot and trigger layer updates
        let target: GradientCommand.GradientTarget = activeColorTarget == .fill ? .fill : .stroke
        let command = GradientCommand(
            objectIDs: Array(selectedObjectIDs),
            target: target,
            oldGradients: dragStartGradients,
            newGradients: newGradients,
            oldOpacities: dragStartOpacities,
            newOpacities: newOpacities
        )
        document.commandManager.execute(command)

        // print("🎨 COMMIT END: Command executed")

        // Check snapshot after command
        // for objectID in selectedObjectIDs {
        //     if let obj = document.snapshot.objects[objectID] {
        //         if let fillGradient = obj.shape.fillStyle?.gradient {
        //             print("🎨 COMMIT: Snapshot AFTER has gradient stops = \(fillGradient.stops.map { $0.color })")
        //         }
        //     }
        // }

        // DON'T clear delta - snapshot is updated, delta will show same gradient anyway
        // Clearing it causes a flash because SwiftUI renders before snapshot propagates
        // print("🎨 COMMIT END: Leaving activeGradientDelta set (snapshot now matches)")
    }

    private func getGradientOriginX(_ gradient: VectorGradient) -> Double {
        switch gradient {
        case .linear(let linear):
            return linear.originPoint.x
        case .radial(let radial):
            let originX = radial.originPoint.x
            return originX
        }
    }

    private func getGradientOriginY(_ gradient: VectorGradient) -> Double {
        switch gradient {
        case .linear(let linear):
            return linear.originPoint.y
        case .radial(let radial):
            let originY = radial.originPoint.y
            return originY
        }
    }

    private func updateGradientOriginX(_ newX: Double, applyToShapes: Bool = true) {
        updateGradientOriginXOptimized(newX, applyToShapes: applyToShapes, isLiveDrag: false)
    }

    private func updateGradientOriginY(_ newY: Double, applyToShapes: Bool = true) {
        updateGradientOriginYOptimized(newY, applyToShapes: applyToShapes, isLiveDrag: false)
    }

    private func updateGradientOriginXOptimized(_ newX: Double, applyToShapes: Bool = true, isLiveDrag: Bool) {
        // print("🔴 updateGradientOriginXOptimized called: newX=\(newX), applyToShapes=\(applyToShapes), isLiveDrag=\(isLiveDrag)")
        guard let gradient = currentGradient else { return }

        switch gradient {
        case .linear(var linear):
            linear.originPoint.x = newX
            currentGradient = .linear(linear)
        case .radial(var radial):
            radial.originPoint.x = newX
            radial.focalPoint = CGPoint(x: newX, y: radial.originPoint.y)
            currentGradient = .radial(radial)
        }
        if applyToShapes {
            if isLiveDrag {
                document.viewState.liveGradientOriginX = newX
            } else {
                document.viewState.liveGradientOriginX = nil
            }
            // print("🔴 CALLING applyGradientToSelectedShapesOptimized - THIS UPDATES SNAPSHOT!")
            applyGradientToSelectedShapesOptimized(isLiveDrag: isLiveDrag)
        }
    }

    private func updateGradientOriginYOptimized(_ newY: Double, applyToShapes: Bool = true, isLiveDrag: Bool) {
        guard let gradient = currentGradient else { return }

        switch gradient {
        case .linear(var linear):
            linear.originPoint.y = newY
            currentGradient = .linear(linear)
        case .radial(var radial):
            radial.originPoint.y = newY
            radial.focalPoint = CGPoint(x: radial.originPoint.x, y: newY)
            currentGradient = .radial(radial)
        }
        if applyToShapes {
            if isLiveDrag {
                document.viewState.liveGradientOriginY = newY
            } else {
                document.viewState.liveGradientOriginY = nil
            }
            applyGradientToSelectedShapesOptimized(isLiveDrag: isLiveDrag)
        }
    }

    private func getGradientScale(_ gradient: VectorGradient) -> Double {
        switch gradient {
        case .linear(let linear):
            return linear.scaleX
        case .radial(let radial):
            return radial.scaleX
        }
    }

    private func getGradientAspectRatio(_ gradient: VectorGradient) -> Double {
        switch gradient {
        case .linear(let linear):
            return linear.scaleX != 0 ? linear.scaleY / linear.scaleX : 1.0
        case .radial(let radial):
            return radial.scaleX != 0 ? radial.scaleY / radial.scaleX : 1.0
        }
    }

    private func updateGradientScale(_ newScale: Double) {
        guard let gradient = currentGradient else { return }

        switch gradient {
        case .linear(var linear):
            let currentAspectRatio = linear.scaleX != 0 ? linear.scaleY / linear.scaleX : 1.0
            linear.scaleX = newScale
            linear.scaleY = newScale * currentAspectRatio
            currentGradient = .linear(linear)
        case .radial(var radial):
            let currentAspectRatio = radial.scaleX != 0 ? radial.scaleY / radial.scaleX : 1.0
            radial.scaleX = newScale
            radial.scaleY = newScale * currentAspectRatio
            currentGradient = .radial(radial)
        }
        activeGradientDelta = currentGradient
        // Removed: Canvas will redraw automatically when activeGradientDelta changes
    }

    private func updateGradientAspectRatio(_ newAspectRatio: Double) {
        guard let gradient = currentGradient else { return }

        switch gradient {
        case .linear(_):
            return
        case .radial(var radial):
            radial.scaleY = radial.scaleX * newAspectRatio
            currentGradient = .radial(radial)
            activeGradientDelta = currentGradient
            // Removed: Canvas will redraw automatically when activeGradientDelta changes
        }
    }

    private func getGradientRadius(_ gradient: VectorGradient) -> Double {
        switch gradient {
        case .linear(_):
            return 0.5
        case .radial(let radial):
            return radial.radius
        }
    }

    private func updateGradientRadius(_ newRadius: Double) {
        guard let gradient = currentGradient else { return }

        switch gradient {
        case .linear(_):
            return
        case .radial(var radial):
            radial.radius = newRadius
            currentGradient = .radial(radial)
            activeGradientDelta = currentGradient
            // Removed: Canvas will redraw automatically when activeGradientDelta changes
        }
    }

    func getGradientStops(_ gradient: VectorGradient) -> [GradientStop] {
        switch gradient {
        case .linear(let linear):
            return linear.stops
        case .radial(let radial):
            return radial.stops
        }
    }

    func updateStopPosition(stopId: UUID, position: Double) {
        guard let gradient = currentGradient else { return }

        switch gradient {
        case .linear(var linear):
            if let index = linear.stops.firstIndex(where: { $0.id == stopId }) {
                linear.stops[index].position = position
                linear.stops.sort { $0.position < $1.position }
                currentGradient = .linear(linear)
                activeGradientDelta = currentGradient
                // Removed: Canvas will redraw automatically when activeGradientDelta changes
            }
        case .radial(var radial):
            if let index = radial.stops.firstIndex(where: { $0.id == stopId }) {
                radial.stops[index].position = position
                radial.stops.sort { $0.position < $1.position }
                currentGradient = .radial(radial)
                activeGradientDelta = currentGradient
                // Removed: Canvas will redraw automatically when activeGradientDelta changes
            }
        }
    }

    func updateStopOpacity(stopId: UUID, opacity: Double) {
        guard let gradient = currentGradient else { return }

        switch gradient {
        case .linear(var linear):
            if let index = linear.stops.firstIndex(where: { $0.id == stopId }) {
                linear.stops[index].opacity = opacity
                currentGradient = .linear(linear)
                activeGradientDelta = currentGradient
                // Removed: Canvas will redraw automatically when activeGradientDelta changes
            }
        case .radial(var radial):
            if let index = radial.stops.firstIndex(where: { $0.id == stopId }) {
                radial.stops[index].opacity = opacity
                currentGradient = .radial(radial)
                activeGradientDelta = currentGradient
                // Removed: Canvas will redraw automatically when activeGradientDelta changes
            }
        }
    }

    func updateStopColor(stopId: UUID, color: VectorColor) {
        guard let gradient = currentGradient else { return }

        print("🎨🎨🎨 updateStopColor: activeColorTarget = \(activeColorTarget)")
        print("🎨🎨🎨 updateStopColor: setting activeGradientDelta")

        switch gradient {
        case .linear(var linear):
            if let index = linear.stops.firstIndex(where: { $0.id == stopId }) {
                linear.stops[index].color = color
                currentGradient = .linear(linear)
                activeGradientDelta = currentGradient
                print("🎨🎨🎨 updateStopColor: SET activeGradientDelta for LINEAR")
            }
        case .radial(var radial):
            if let index = radial.stops.firstIndex(where: { $0.id == stopId }) {
                radial.stops[index].color = color
                currentGradient = .radial(radial)
                activeGradientDelta = currentGradient
                print("🎨🎨🎨 updateStopColor: SET activeGradientDelta for RADIAL")
            }
        }
    }

    func addColorStop() {
        guard let gradient = currentGradient else { return }
        let oldGradient = gradient

        let stops = getGradientStops(gradient)
        let newPosition = stops.count > 1 ? (stops[stops.count-2].position + stops[stops.count-1].position) / 2 : 0.5
        let newStop = GradientStop(position: newPosition, color: .black, opacity: 1.0)

        switch gradient {
        case .linear(var linear):
            linear.stops.append(newStop)
            linear.stops.sort { $0.position < $1.position }
            currentGradient = .linear(linear)
            applyGradientToSelectedShapes()
        case .radial(var radial):
            radial.stops.append(newStop)
            radial.stops.sort { $0.position < $1.position }
            currentGradient = .radial(radial)
            applyGradientToSelectedShapes()
        }

        // Create undo command
        if let newGradient = currentGradient {
            createGradientUndoCommand(oldGradient: oldGradient, newGradient: newGradient)
        }
    }

    func removeColorStop(stopId: UUID) {
        guard let gradient = currentGradient else { return }
        let oldGradient = gradient

        switch gradient {
        case .linear(var linear):
            guard linear.stops.count > 2 else { return }
            if let index = linear.stops.firstIndex(where: { $0.id == stopId }) {
                linear.stops.remove(at: index)
                currentGradient = .linear(linear)
                applyGradientToSelectedShapes()
            }
        case .radial(var radial):
            guard radial.stops.count > 2 else { return }
            if let index = radial.stops.firstIndex(where: { $0.id == stopId }) {
                radial.stops.remove(at: index)
                currentGradient = .radial(radial)
                applyGradientToSelectedShapes()
            }
        }

        // Create undo command
        if let newGradient = currentGradient {
            createGradientUndoCommand(oldGradient: oldGradient, newGradient: newGradient)
        }
    }

    private func createGradientUndoCommand(oldGradient: VectorGradient, newGradient: VectorGradient) {
        var oldGradients: [UUID: VectorGradient?] = [:]
        var newGradients: [UUID: VectorGradient?] = [:]
        var oldOpacities: [UUID: Double] = [:]
        var newOpacities: [UUID: Double] = [:]

        let isStroke = activeColorTarget == .stroke

        for objectID in selectedObjectIDs {
            if let shape = document.findShape(by: objectID) {
                oldGradients[objectID] = oldGradient
                newGradients[objectID] = newGradient
                let opacity = isStroke ? (shape.strokeStyle?.opacity ?? 1.0) : (shape.fillStyle?.opacity ?? 1.0)
                oldOpacities[objectID] = opacity
                newOpacities[objectID] = opacity
            }
        }

        let target: GradientCommand.GradientTarget = isStroke ? .stroke : .fill
        let command = GradientCommand(
            objectIDs: Array(selectedObjectIDs),
            target: target,
            oldGradients: oldGradients,
            newGradients: newGradients,
            oldOpacities: oldOpacities,
            newOpacities: newOpacities
        )
        document.commandManager.execute(command)
    }

    func applyGradientToSelectedShapes() {
        guard let newGradient = currentGradient else { return }

        // Capture old gradients before applying
        var oldGradients: [UUID: VectorGradient?] = [:]
        var oldOpacities: [UUID: Double] = [:]

        for objectID in selectedObjectIDs {
            if let newVectorObject = snapshot.objects[objectID] {
                let shape = newVectorObject.shape
                if let fillStyle = shape.fillStyle, case .gradient(let gradient) = fillStyle.color {
                    oldGradients[objectID] = gradient
                    oldOpacities[objectID] = fillStyle.opacity
                } else {
                    oldGradients[objectID] = nil
                    oldOpacities[objectID] = 1.0
                }
            }
        }

        applyGradientToSelectedShapesOptimized(isLiveDrag: false)

        // Create undo command
        var newGradients: [UUID: VectorGradient?] = [:]
        var newOpacities: [UUID: Double] = [:]

        for objectID in selectedObjectIDs {
            if let newVectorObject = snapshot.objects[objectID] {
                let shape = newVectorObject.shape
                newGradients[objectID] = newGradient
                newOpacities[objectID] = shape.fillStyle?.opacity ?? 1.0
            }
        }

        let command = GradientCommand(
            objectIDs: Array(selectedObjectIDs),
            target: .fill,
            oldGradients: oldGradients,
            newGradients: newGradients,
            oldOpacities: oldOpacities,
            newOpacities: newOpacities
        )
        document.commandManager.execute(command)
    }

    func applyGradientToSelectedShapesOptimized(isLiveDrag: Bool) {
        guard let gradient = currentGradient else { return }
        var affectedLayers = Set<Int>()

        if isLiveDrag {
            for objectID in selectedObjectIDs {
                if let newVectorObject = document.snapshot.objects[objectID] {
                    var shape = newVectorObject.shape

                    switch activeColorTarget {
                    case .fill:
                        let currentOpacity = shape.fillStyle?.opacity ?? 1.0
                        shape.fillStyle = FillStyle(gradient: gradient, opacity: currentOpacity)
                    case .stroke:
                        let currentStroke = shape.strokeStyle
                        shape.strokeStyle = StrokeStyle(
                            gradient: gradient,
                            width: currentStroke?.width ?? document.defaultStrokeWidth,
                            placement: currentStroke?.placement ?? document.strokeDefaults.placement,
                            lineCap: currentStroke?.lineCap.cgLineCap ?? document.strokeDefaults.lineCap,
                            lineJoin: currentStroke?.lineJoin.cgLineJoin ?? document.strokeDefaults.lineJoin,
                            miterLimit: currentStroke?.miterLimit ?? document.strokeDefaults.miterLimit,
                            opacity: currentStroke?.opacity ?? 1.0,
                            blendMode: currentStroke?.blendMode ?? .normal
                        )
                    }

                    let updatedObject = VectorObject(shape: shape, layerIndex: newVectorObject.layerIndex)
                    document.snapshot.objects[objectID] = updatedObject
                    affectedLayers.insert(updatedObject.layerIndex)
                }
            }
            document.triggerLayerUpdates(for: affectedLayers)
            return
        }

        for objectID in selectedObjectIDs {
            if let newVectorObject = document.snapshot.objects[objectID] {
                var shape = newVectorObject.shape

                switch activeColorTarget {
                case .fill:
                    let currentOpacity = shape.fillStyle?.opacity ?? 1.0
                    shape.fillStyle = FillStyle(gradient: gradient, opacity: currentOpacity)
                case .stroke:
                    let currentStroke = shape.strokeStyle
                    shape.strokeStyle = StrokeStyle(
                        gradient: gradient,
                        width: currentStroke?.width ?? document.defaultStrokeWidth,
                        placement: currentStroke?.placement ?? document.strokeDefaults.placement,
                        lineCap: currentStroke?.lineCap.cgLineCap ?? document.strokeDefaults.lineCap,
                        lineJoin: currentStroke?.lineJoin.cgLineJoin ?? document.strokeDefaults.lineJoin,
                        miterLimit: currentStroke?.miterLimit ?? document.strokeDefaults.miterLimit,
                        opacity: currentStroke?.opacity ?? 1.0,
                        blendMode: currentStroke?.blendMode ?? .normal
                    )
                }

                let updatedObject = VectorObject(shape: shape, layerIndex: newVectorObject.layerIndex)
                document.snapshot.objects[objectID] = updatedObject
                affectedLayers.insert(updatedObject.layerIndex)
            }
        }
        document.triggerLayerUpdates(for: affectedLayers)
    }

    func addGradientToSwatches() {
        guard let gradient = currentGradient else { return }

        let gradientColor = VectorColor.gradient(gradient)

        document.addColorToSwatches(gradientColor)

    }

    static func getSelectedShapeGradient(snapshot: DocumentSnapshot, selectedObjectIDs: Set<UUID>, activeColorTarget: ColorTarget) -> VectorGradient? {
        guard let firstID = selectedObjectIDs.first,
              let obj = snapshot.objects[firstID] else {
            return nil
        }

        let shape = obj.shape

        // Check fill or stroke based on activeColorTarget
        switch activeColorTarget {
        case .fill:
            guard let fillStyle = shape.fillStyle,
                  case .gradient(let gradient) = fillStyle.color else {
                return nil
            }
            return gradient
        case .stroke:
            guard let strokeStyle = shape.strokeStyle,
                  case .gradient(let gradient) = strokeStyle.color else {
                return nil
            }
            return gradient
        }
    }

    @MainActor static func createDefaultGradient(type: GradientType) -> VectorGradient {
        let stops = [
            GradientStop(position: 0.0, color: .black, opacity: 1.0),
            GradientStop(position: 1.0, color: .white, opacity: 1.0)
        ]

        return createGradientWithStops(type: type, stops: stops)
    }

    @MainActor static func createGradientWithStops(type: GradientType, stops: [GradientStop]) -> VectorGradient {
        let validStops = stops.isEmpty ? [
            GradientStop(position: 0.0, color: .black, opacity: 1.0),
            GradientStop(position: 1.0, color: .white, opacity: 1.0)
        ] : stops

        switch type {
        case .linear:
            var linear = LinearGradient(
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 1, y: 0),
                stops: validStops,
                spreadMethod: .pad,
                units: .objectBoundingBox
            )
            linear.originPoint = CGPoint(x: 0.5, y: 0.5)
            linear.scaleX = 1.0
            linear.scaleY = 1.0
            return .linear(linear)
        case .radial:
            var radial = RadialGradient(
                centerPoint: CGPoint(x: 0, y: 0),
                radius: 0.5,
                stops: validStops,
                focalPoint: CGPoint(x: 0.5, y: 0.5),
                spreadMethod: .pad,
                units: .objectBoundingBox
            )
            radial.originPoint = CGPoint(x: 0.5, y: 0.5)
            radial.scaleX = 1.0
            radial.scaleY = 1.0
            return .radial(radial)
        }
    }

    @MainActor static func createGradientPreservingProperties(type: GradientType, stops: [GradientStop], from existingGradient: VectorGradient) -> VectorGradient {
        let validStops = stops.isEmpty ? [
            GradientStop(position: 0.0, color: .black, opacity: 1.0),
            GradientStop(position: 1.0, color: .white, opacity: 1.0)
        ] : stops

        switch type {
        case .linear:
            var linear = LinearGradient(
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 1, y: 0),
                stops: validStops,
                spreadMethod: .pad,
                units: .objectBoundingBox
            )

            switch existingGradient {
            case .linear(let existingLinear):
                linear.originPoint = existingLinear.originPoint
                linear.scale = existingLinear.scale
                linear.scaleX = existingLinear.scaleX
                linear.scaleY = existingLinear.scaleY
                linear.units = existingLinear.units
                linear.spreadMethod = existingLinear.spreadMethod
            case .radial(let existingRadial):
                linear.originPoint = existingRadial.originPoint
                linear.scale = existingRadial.scale
                linear.scaleX = existingRadial.scaleX
                linear.scaleY = existingRadial.scaleY
                linear.units = existingRadial.units
                linear.spreadMethod = existingRadial.spreadMethod
            }

            return .linear(linear)

        case .radial:
            let (centerPoint, radius, _) = {
                switch existingGradient {
                case .radial(let existingRadial):
                    return (existingRadial.centerPoint, existingRadial.radius, existingRadial.focalPoint)
                case .linear(_):
                    return (CGPoint(x: 0.5, y: 0.5), 0.5, nil as CGPoint?)
                }
            }()

            var radial = RadialGradient(
                centerPoint: centerPoint,
                radius: radius,
                stops: validStops,
                focalPoint: centerPoint,
                spreadMethod: .pad,
                units: .objectBoundingBox
            )

            switch existingGradient {
            case .linear(let existingLinear):
                radial.originPoint = existingLinear.originPoint
                radial.scale = existingLinear.scale
                radial.scaleX = existingLinear.scaleX
                radial.scaleY = existingLinear.scaleY
                radial.units = existingLinear.units
                radial.spreadMethod = existingLinear.spreadMethod
            case .radial(let existingRadial):
                radial.originPoint = existingRadial.originPoint
                radial.scale = existingRadial.scale
                radial.scaleX = existingRadial.scaleX
                radial.scaleY = existingRadial.scaleY
                radial.angle = existingRadial.angle
                radial.units = existingRadial.units
                radial.spreadMethod = existingRadial.spreadMethod
            }

            return .radial(radial)
        }
    }

    private func findGradientStopColor(stopId: UUID) -> VectorColor {
        if let gradient = currentGradient {
            let stops: [GradientStop]
            switch gradient {
            case .linear(let linear):
                stops = linear.stops
            case .radial(let radial):
                stops = radial.stops
            }

            if let stop = stops.first(where: { $0.id == stopId }) {
                return stop.color
            }
        }

        guard let firstSelectedID = selectedObjectIDs.first else {
            return .black
        }

        guard let shape = document.findShape(by: firstSelectedID),
              let fillStyle = shape.fillStyle else {
            return .black
        }

        switch fillStyle.color {
        case .gradient(let gradient):
            if let stop = gradient.stops.first(where: { $0.id == stopId }) {
                return stop.color
            } else {
                return .black
            }
        default:
            return .black
        }
    }
}
