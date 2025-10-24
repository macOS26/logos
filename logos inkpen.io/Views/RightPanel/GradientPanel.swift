import SwiftUI
import AppKit
import Combine

struct GradientPanel: View {
    let snapshot: DocumentSnapshot
    let selectedObjectIDs: Set<UUID>
    @ObservedObject var document: VectorDocument  // Keep temporarily for methods

    var body: some View {
        ScrollView {
            VStack() {
                GradientFillSection(
                    snapshot: snapshot,
                    selectedObjectIDs: selectedObjectIDs,
                    document: document
                )
                Spacer()
            }
        }
    }
}

struct GradientFillSection: View {
    let snapshot: DocumentSnapshot
    let selectedObjectIDs: Set<UUID>
    @ObservedObject var document: VectorDocument  // Keep temporarily for methods
    @Environment(AppState.self) private var appState
    @State private var gradientType: GradientType = .linear
    @State private var currentGradient: VectorGradient? = nil
    @State private var gradientId: UUID = UUID()
    @State private var isEditingAngle: Bool = false
    @State private var showingGradientColorPicker = false
    @State private var editingGradientStopId: UUID?
    @State private var editingGradientStopColor: VectorColor = .black
    @State private var localOriginX: Double = 0.5
    @State private var localOriginY: Double = 0.5
    @State private var dragStartGradient: VectorGradient? = nil
    @State private var dragStartOpacities: [UUID: Double] = [:]

    enum GradientType: String, CaseIterable {
        case linear = "Linear"
        case radial = "Radial"
    }

    init(snapshot: DocumentSnapshot, selectedObjectIDs: Set<UUID>, document: VectorDocument) {
        self.snapshot = snapshot
        self.selectedObjectIDs = selectedObjectIDs
        self.document = document

        if let selectedGradient = Self.getSelectedShapeGradient(snapshot: snapshot, selectedObjectIDs: selectedObjectIDs, document: document) {
            _currentGradient = State(initialValue: selectedGradient)
            switch selectedGradient {
            case .linear(let linear):
                _gradientType = State(initialValue: .linear)
                _localOriginX = State(initialValue: linear.originPoint.x)
                _localOriginY = State(initialValue: linear.originPoint.y)
            case .radial(let radial):
                _gradientType = State(initialValue: .radial)
                _localOriginX = State(initialValue: radial.originPoint.x)
                _localOriginY = State(initialValue: radial.originPoint.y)
            }
        } else {
            _currentGradient = State(initialValue: Self.createDefaultGradient(type: .linear))
            _localOriginX = State(initialValue: 0.5)
            _localOriginY = State(initialValue: 0.5)
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
                onAngleChange: updateGradientAngle
            )

            GradientOriginControlView(
                currentGradient: currentGradient,
                document: document,
                originX: $localOriginX,
                originY: $localOriginY,
                updateOriginX: { newX in
                    localOriginX = newX
                    updateGradientOriginXOptimized(newX, applyToShapes: true, isLiveDrag: true)
                },
                updateOriginY: { newY in
                    localOriginY = newY
                    updateGradientOriginYOptimized(newY, applyToShapes: true, isLiveDrag: true)
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
                updateRadius: updateGradientRadius
            )

            GradientPreviewAndStopsView(
                currentGradient: currentGradient,
                document: document,
                editingGradientStopId: $editingGradientStopId,
                editingGradientStopColor: $editingGradientStopColor,
                showingGradientColorPicker: $showingGradientColorPicker,
                getGradientStops: getGradientStops,
                getOriginX: getGradientOriginX,
                getOriginY: getGradientOriginY,
                getScale: getGradientScale,
                getAspectRatio: getGradientAspectRatio,
                updateOriginX: { updateGradientOriginX($0, applyToShapes: $1) },
                updateOriginY: { updateGradientOriginY($0, applyToShapes: $1) },
                updateOriginXOptimized: { updateGradientOriginXOptimized($0, applyToShapes: $1, isLiveDrag: $2) },
                updateOriginYOptimized: { updateGradientOriginYOptimized($0, applyToShapes: $1, isLiveDrag: $2) },
                addColorStop: addColorStop,
                updateStopPosition: updateStopPosition,
                updateStopOpacity: updateStopOpacity,
                removeColorStop: removeColorStop,
                applyGradientToSelectedShapes: applyGradientToSelectedShapes,
                applyGradientToSelectedShapesOptimized: applyGradientToSelectedShapesOptimized,
                activateGradientStop: activateGradientStop
            )

            GradientApplyButtonView(
                currentGradient: currentGradient,
                onApply: applyGradientToSelectedShapes,
                onAddSwatch: addGradientToSwatches
            )
        }
        .padding()
        .background(Color.ui.semiTransparentControlBackground)
        .cornerRadius(12)
        .onChange(of: selectedObjectIDs) { _, _ in
            updateSelectedGradient()
        }
    }

    private func turnOffEditingState() {
        appState.gradientEditingState = nil
        appState.persistentGradientHUD.hide()
        editingGradientStopId = nil

        DispatchQueue.main.async {
            if self.editingGradientStopId != nil {
                self.editingGradientStopId = nil
            }
            if appState.gradientEditingState != nil {
                appState.gradientEditingState = nil
            }
        }
    }

    private func activateGradientStop(_ stopId: UUID, color: VectorColor) {

        editingGradientStopId = stopId
        editingGradientStopColor = color

        let actualColor = findGradientStopColor(stopId: stopId)

        if let gradient = currentGradient {
            let stops: [GradientStop]
            switch gradient {
            case .linear(let linear):
                stops = linear.stops
            case .radial(let radial):
                stops = radial.stops
            }
            let stopIndex = stops.firstIndex { $0.id == stopId } ?? 0

            appState.gradientEditingState = GradientEditingState(
                gradientId: stopId,
                stopIndex: stopIndex,
                onColorSelected: { [self] color in
                    self.updateStopColor(stopId: stopId, color: color)
                }
            )
        }

        appState.persistentGradientHUD.show(
            stopId: stopId,
            color: actualColor,
            document: document,
            gradient: currentGradient,
            onColorSelected: { [self] targetStopId, color in
                self.updateStopColor(stopId: targetStopId, color: color)
            },
            onClose: { [self] in
                self.turnOffEditingState()
            }
        )
    }

    private func updateSelectedGradient() {

        if let selectedGradient = Self.getSelectedShapeGradient(snapshot: snapshot, selectedObjectIDs: selectedObjectIDs, document: document) {
            currentGradient = selectedGradient
            switch selectedGradient {
            case .linear(let linear):
                gradientType = .linear
                localOriginX = linear.originPoint.x
                localOriginY = linear.originPoint.y
            case .radial(let radial):
                gradientType = .radial
                localOriginX = radial.originPoint.x
                localOriginY = radial.originPoint.y
            }
            gradientId = UUID()
        }
    }

    private func updateSelectedGradientDisplay() {

        if let selectedGradient = Self.getSelectedShapeGradient(snapshot: snapshot, selectedObjectIDs: selectedObjectIDs, document: document) {
            currentGradient = selectedGradient
            switch selectedGradient {
            case .linear(let linear):
                gradientType = .linear
                localOriginX = linear.originPoint.x
                localOriginY = linear.originPoint.y
            case .radial(let radial):
                gradientType = .radial
                localOriginX = radial.originPoint.x
                localOriginY = radial.originPoint.y
            }
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

        isEditingAngle = true

        switch gradient {
        case .linear(var linear):
            linear.angle = normalizedAngle
            currentGradient = .linear(linear)
            applyGradientToSelectedShapesOptimized(isLiveDrag: true)
        case .radial(var radial):
            radial.angle = normalizedAngle
            currentGradient = .radial(radial)
            applyGradientToSelectedShapesOptimized(isLiveDrag: true)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isEditingAngle = false
        }
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
        applyGradientToSelectedShapesOptimized(isLiveDrag: true)
    }

    private func updateGradientAspectRatio(_ newAspectRatio: Double) {
        guard let gradient = currentGradient else { return }

        switch gradient {
        case .linear(_):
            return
        case .radial(var radial):
            radial.scaleY = radial.scaleX * newAspectRatio
            currentGradient = .radial(radial)
            applyGradientToSelectedShapesOptimized(isLiveDrag: true)
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
            applyGradientToSelectedShapesOptimized(isLiveDrag: true)
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
                applyGradientToSelectedShapesOptimized(isLiveDrag: true)
            }
        case .radial(var radial):
            if let index = radial.stops.firstIndex(where: { $0.id == stopId }) {
                radial.stops[index].position = position
                radial.stops.sort { $0.position < $1.position }
                currentGradient = .radial(radial)
                applyGradientToSelectedShapesOptimized(isLiveDrag: true)
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
                applyGradientToSelectedShapesOptimized(isLiveDrag: true)
            }
        case .radial(var radial):
            if let index = radial.stops.firstIndex(where: { $0.id == stopId }) {
                radial.stops[index].opacity = opacity
                currentGradient = .radial(radial)
                applyGradientToSelectedShapesOptimized(isLiveDrag: true)
            }
        }
    }

    func updateStopColor(stopId: UUID, color: VectorColor) {
        guard let gradient = currentGradient else { return }

        switch gradient {
        case .linear(var linear):
            if let index = linear.stops.firstIndex(where: { $0.id == stopId }) {
                linear.stops[index].color = color
                currentGradient = .linear(linear)
                applyGradientToSelectedShapesOptimized(isLiveDrag: true)
            }
        case .radial(var radial):
            if let index = radial.stops.firstIndex(where: { $0.id == stopId }) {
                radial.stops[index].color = color
                currentGradient = .radial(radial)
                applyGradientToSelectedShapesOptimized(isLiveDrag: true)
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

        for objectID in selectedObjectIDs {
            if let shape = document.findShape(by: objectID) {
                oldGradients[objectID] = oldGradient
                newGradients[objectID] = newGradient
                let opacity = shape.fillStyle?.opacity ?? 1.0
                oldOpacities[objectID] = opacity
                newOpacities[objectID] = opacity
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

        if isLiveDrag {
            for objectID in selectedObjectIDs {
                if let newVectorObject = document.snapshot.objects[objectID] {
                    var shape = newVectorObject.shape

                    switch document.viewState.activeColorTarget {
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
                }
            }
            return
        }

        for objectID in selectedObjectIDs {
            if let newVectorObject = document.snapshot.objects[objectID] {
                var shape = newVectorObject.shape

                switch document.viewState.activeColorTarget {
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
            }
        }
    }

    func addGradientToSwatches() {
        guard let gradient = currentGradient else { return }

        let gradientColor = VectorColor.gradient(gradient)

        document.addColorToSwatches(gradientColor)

    }

    static func getSelectedShapeGradient(snapshot: DocumentSnapshot, selectedObjectIDs: Set<UUID>, document: VectorDocument) -> VectorGradient? {
        let activeShapes = document.getActiveShapes()  // Keep using document method for now
        guard let firstShape = activeShapes.first,
              let fillStyle = firstShape.fillStyle,
              case .gradient(let gradient) = fillStyle.color else {
            return nil
        }
        return gradient
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
