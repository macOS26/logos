//
//  GradientPanel.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI
import AppKit

// MARK: - Helper Functions
// Note: formatNumberForDisplay function is imported from StrokeFillPanel.swift

/// Creates a natural number input binding that preserves user input while they're typing
/// and only formats the display when the field loses focus
func createNaturalNumberBinding(
    getValue: @escaping () -> Double,
    setValue: @escaping (Double) -> Void,
    formatter: @escaping (Double) -> String = { formatNumberForDisplay($0) }
) -> Binding<String> {
    return Binding<String>(
        get: {
            let value = getValue()
            return formatter(value)
        },
        set: { newStringValue in
            // Allow natural number input - don't force formatting while typing
            if let doubleValue = Double(newStringValue) {
                setValue(doubleValue)
            }
            // If it's not a valid number, don't update (preserves current value)
        }
    )
}

// MARK: - Gradient Panel

struct GradientPanel: View {
    @ObservedObject var document: VectorDocument
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Gradient Fill Section
                GradientFillSection(document: document)
                
                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - Gradient Fill Section

struct GradientFillSection: View {
    @ObservedObject var document: VectorDocument
    @Environment(AppState.self) private var appState
    @State private var gradientType: GradientType = .linear
    @State private var currentGradient: VectorGradient? = nil
    @State private var gradientId: UUID = UUID() // Unique ID for this gradient editing session
    
    // NEW: State for gradient color stop popup
    @State private var showingGradientColorPicker = false
    @State private var editingGradientStopId: UUID?
    @State private var editingGradientStopColor: VectorColor = .black
    
    enum GradientType: String, CaseIterable {
        case linear = "Linear"
        case radial = "Radial"
    }
    
    init(document: VectorDocument) {
        self.document = document
        
        // Initialize with existing gradient if selected shape has one
        if let selectedGradient = Self.getSelectedShapeGradient(document: document) {
            _currentGradient = State(initialValue: selectedGradient)
            switch selectedGradient {
            case .linear(_):
                _gradientType = State(initialValue: .linear)
            case .radial(_):
                _gradientType = State(initialValue: .radial)
            }
        } else {
            // Create default gradient
            _currentGradient = State(initialValue: Self.createDefaultGradient(type: .linear))
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                getOriginX: getGradientOriginX,
                getOriginY: getGradientOriginY,
                updateOriginX: { updateGradientOriginX($0, applyToShapes: true) },
                updateOriginY: { updateGradientOriginY($0, applyToShapes: true) }
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
                addColorStop: addColorStop,
                updateStopPosition: updateStopPosition,
                updateStopOpacity: updateStopOpacity,
                removeColorStop: removeColorStop,
                applyGradientToSelectedShapes: applyGradientToSelectedShapes,
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
        .onChange(of: document.selectedShapeIDs) { _, _ in updateSelectedGradient() }
        .onChange(of: document.selectedLayerIndex) { _, _ in updateSelectedGradient() }
        .onReceive(document.objectWillChange) { _ in
            // FIXED: Only update UI display, don't modify gradients
            updateSelectedGradientDisplay()
        }
    }
    
    private func turnOffEditingState() {
        print("🎨 GRADIENT PANEL: turnOffEditingState() called")
        // 🔥 FIXED: Clear gradient editing state first to prevent circular calls
        appState.gradientEditingState = nil
        print("🎨 GRADIENT PANEL: Cleared gradientEditingState")
        // 🔥 PROPERLY HIDE THE HUD - This will close the window and reset state
        appState.persistentGradientHUD.hide()
        print("🎨 GRADIENT PANEL: Called persistentGradientHUD.hide()")
        // 🔥 CRITICAL: Clear the editing stop ID last to prevent onChange trigger
        editingGradientStopId = nil
        print("🎨 GRADIENT PANEL: Cleared editingGradientStopId")
        
        // 🔥 ADDITIONAL SAFETY: Force reset any stuck state
        DispatchQueue.main.async {
            if self.editingGradientStopId != nil {
                print("🎨 GRADIENT PANEL: WARNING - editingGradientStopId still not nil, forcing reset")
                self.editingGradientStopId = nil
            }
            if appState.gradientEditingState != nil {
                print("🎨 GRADIENT PANEL: WARNING - gradientEditingState still not nil, forcing reset")
                appState.gradientEditingState = nil
            }
        }
    }
    
    // MARK: - Gradient Stop Activation
    
    private func activateGradientStop(_ stopId: UUID, color: VectorColor) {
        print("🎨 GRADIENT PANEL: activateGradientStop called for stop \(stopId.uuidString.prefix(8))")
        
        // Set the editing state
        editingGradientStopId = stopId
        editingGradientStopColor = color
        
        // Get the actual color from the gradient
        let actualColor = findGradientStopColor(stopId: stopId)
        
        // Set gradient editing state for HUD
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
        
        // Show the persistent HUD
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
    
    // MARK: - Selection and Angle Management
    
    private func updateSelectedGradient() {
        print("🚨 GRADIENT PANEL: updateSelectedGradient called!")
        print("🚨 GRADIENT PANEL: This function might be modifying gradients!")
        
        if let selectedGradient = Self.getSelectedShapeGradient(document: document) {
            print("🚨 GRADIENT PANEL: Found selected gradient: \(selectedGradient)")
            currentGradient = selectedGradient
            switch selectedGradient {
            case .linear(_):
                gradientType = .linear
            case .radial(_):
                gradientType = .radial
            }
            gradientId = UUID() // Generate new ID for loaded gradient
            print("🚨 GRADIENT PANEL: Updated currentGradient and gradientId")
        } else {
            print("🚨 GRADIENT PANEL: No selected gradient found")
        }
    }
    
    // NEW: Only update display, don't generate new IDs or modify state
    private func updateSelectedGradientDisplay() {
        print("🔄 GRADIENT PANEL: updateSelectedGradientDisplay called (display only)")
        
        if let selectedGradient = Self.getSelectedShapeGradient(document: document) {
            print("🔄 GRADIENT PANEL: Found selected gradient for display update")
            // Only update the display values, don't change gradientId or other state
            currentGradient = selectedGradient
            switch selectedGradient {
            case .linear(_):
                gradientType = .linear
            case .radial(_):
                gradientType = .radial
            }
            // DON'T generate new gradientId - preserve existing state
            print("🔄 GRADIENT PANEL: Updated display without modifying state")
        } else {
            print("🔄 GRADIENT PANEL: No selected gradient found for display")
        }
    }
    
    private func updateGradientAngle(_ newAngle: Double) {
        guard let gradient = currentGradient else { return }
        
        switch gradient {
        case .linear(var linear):
            linear.angle = newAngle
            currentGradient = .linear(linear)
            // Apply live to selected shapes
            applyGradientToSelectedShapes()
        case .radial(var radial):
            radial.angle = newAngle
            currentGradient = .radial(radial)
            // Apply live to selected shapes
            applyGradientToSelectedShapes()
        }
    }
    
    // NEW: Origin Point Controls
    private func getGradientOriginX(_ gradient: VectorGradient) -> Double {
        switch gradient {
        case .linear(let linear):
            return linear.originPoint.x
        case .radial(let radial):
            let originX = radial.originPoint.x
            //print("🔍 getGradientOriginX: \(originX) (radial.originPoint.x)")
            return originX
        }
    }
    
    private func getGradientOriginY(_ gradient: VectorGradient) -> Double {
        switch gradient {
        case .linear(let linear):
            return linear.originPoint.y
        case .radial(let radial):
            let originY = radial.originPoint.y
            //print("// print("🔍 getGradientOriginY: \(originY) (radial.originPoint.y)")
            return originY
        }
    }
    
    private func updateGradientOriginX(_ newX: Double, applyToShapes: Bool = true) {
        guard let gradient = currentGradient else { return }
        
        switch gradient {
        case .linear(var linear):
            linear.originPoint.x = newX
            currentGradient = .linear(linear)
        case .radial(var radial):
            radial.originPoint.x = newX
            // Set focal point to match origin point
            radial.focalPoint = CGPoint(x: newX, y: radial.originPoint.y)
            currentGradient = .radial(radial)
        }
        // Only apply to shapes if requested (for performance during drag)
        if applyToShapes {
            applyGradientToSelectedShapes()
        }
    }
    
    private func updateGradientOriginY(_ newY: Double, applyToShapes: Bool = true) {
        guard let gradient = currentGradient else { return }
        
        switch gradient {
        case .linear(var linear):
            linear.originPoint.y = newY
            currentGradient = .linear(linear)
        case .radial(var radial):
            radial.originPoint.y = newY
            // Set focal point to match origin point
            radial.focalPoint = CGPoint(x: radial.originPoint.x, y: newY)
            currentGradient = .radial(radial)
        }
        // Only apply to shapes if requested (for performance during drag)
        if applyToShapes {
            applyGradientToSelectedShapes()
        }
    }
    
    // NEW: Unified Scale Controls
    private func getGradientScale(_ gradient: VectorGradient) -> Double {
        switch gradient {
        case .linear(let linear):
            return linear.scaleX // Use scaleX as the primary scale
        case .radial(let radial):
            return radial.scaleX // Use scaleX as the primary scale
        }
    }
    
    private func getGradientAspectRatio(_ gradient: VectorGradient) -> Double {
        switch gradient {
        case .linear(let linear):
            // Avoid division by zero, return 1.0 if scaleX is 0
            return linear.scaleX != 0 ? linear.scaleY / linear.scaleX : 1.0
        case .radial(let radial):
            // Avoid division by zero, return 1.0 if scaleX is 0
            return radial.scaleX != 0 ? radial.scaleY / radial.scaleX : 1.0
        }
    }
    
    private func updateGradientScale(_ newScale: Double) {
        guard let gradient = currentGradient else { return }
        
        switch gradient {
        case .linear(var linear):
            // Store current aspect ratio before changing scaleX
            let currentAspectRatio = linear.scaleX != 0 ? linear.scaleY / linear.scaleX : 1.0
            linear.scaleX = newScale
            // Apply the same aspect ratio to the new scale
            linear.scaleY = newScale * currentAspectRatio
            currentGradient = .linear(linear)
        case .radial(var radial):
            // Store current aspect ratio before changing scaleX
            let currentAspectRatio = radial.scaleX != 0 ? radial.scaleY / radial.scaleX : 1.0
            radial.scaleX = newScale
            // Apply the same aspect ratio to the new scale
            radial.scaleY = newScale * currentAspectRatio
            currentGradient = .radial(radial)
        }
        // Apply live to selected shapes
        applyGradientToSelectedShapes()
    }
    
    private func updateGradientAspectRatio(_ newAspectRatio: Double) {
        guard let gradient = currentGradient else { return }
        
        // Aspect ratio only works for radial gradients
        switch gradient {
        case .linear(_):
            // Aspect ratio is disabled for linear gradients
            return
        case .radial(var radial):
            // Keep scaleX constant, adjust scaleY based on aspect ratio
            radial.scaleY = radial.scaleX * newAspectRatio
            currentGradient = .radial(radial)
            // Apply live to selected shapes
            applyGradientToSelectedShapes()
        }
    }
    
    // NEW: Radius Controls
    private func getGradientRadius(_ gradient: VectorGradient) -> Double {
        switch gradient {
        case .linear(_):
            return 0.5 // Not applicable for linear gradients
        case .radial(let radial):
            return radial.radius
        }
    }
    
    private func updateGradientRadius(_ newRadius: Double) {
        guard let gradient = currentGradient else { return }
        
        // Radius only works for radial gradients
        switch gradient {
        case .linear(_):
            // Radius is disabled for linear gradients
            return
        case .radial(var radial):
            radial.radius = newRadius
            currentGradient = .radial(radial)
            // Apply live to selected shapes
            applyGradientToSelectedShapes()
        }
    }
    

    

    
    // MARK: - Helper Functions
    
    // createSwiftUIGradient function removed - now using NSView-based gradient preview that matches actual rendering
    
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
                // AUTO SORT after position change to maintain visual order
                linear.stops.sort { $0.position < $1.position }
                currentGradient = .linear(linear)
                // Apply live to selected shapes
                applyGradientToSelectedShapes()
            }
        case .radial(var radial):
            if let index = radial.stops.firstIndex(where: { $0.id == stopId }) {
                radial.stops[index].position = position
                // AUTO SORT after position change to maintain visual order
                radial.stops.sort { $0.position < $1.position }
                currentGradient = .radial(radial)
                // Apply live to selected shapes
                applyGradientToSelectedShapes()
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
                // Apply live to selected shapes
                applyGradientToSelectedShapes()
            }
        case .radial(var radial):
            if let index = radial.stops.firstIndex(where: { $0.id == stopId }) {
                radial.stops[index].opacity = opacity
                currentGradient = .radial(radial)
                // Apply live to selected shapes
                applyGradientToSelectedShapes()
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
                // Apply live to selected shapes
                applyGradientToSelectedShapes()
            }
        case .radial(var radial):
            if let index = radial.stops.firstIndex(where: { $0.id == stopId }) {
                radial.stops[index].color = color
                currentGradient = .radial(radial)
                // Apply live to selected shapes
                applyGradientToSelectedShapes()
            }
        }
    }
    
    func addColorStop() {
        guard let gradient = currentGradient else { return }
        
        // Find a good position for the new stop - between the last two stops
        let stops = getGradientStops(gradient)
        let newPosition = stops.count > 1 ? (stops[stops.count-2].position + stops[stops.count-1].position) / 2 : 0.5
        let newStop = GradientStop(position: newPosition, color: .black, opacity: 1.0)
        
        switch gradient {
        case .linear(var linear):
            linear.stops.append(newStop)
            // AUTO SORT after adding new stop to maintain position order
            linear.stops.sort { $0.position < $1.position }
            currentGradient = .linear(linear)
            // Apply live to selected shapes
            applyGradientToSelectedShapes()
        case .radial(var radial):
            radial.stops.append(newStop)
            // AUTO SORT after adding new stop to maintain position order
            radial.stops.sort { $0.position < $1.position }
            currentGradient = .radial(radial)
            // Apply live to selected shapes
            applyGradientToSelectedShapes()
        }
    }
    
    func removeColorStop(stopId: UUID) {
        guard let gradient = currentGradient else { return }
        
        switch gradient {
        case .linear(var linear):
            guard linear.stops.count > 2 else { return }
            if let index = linear.stops.firstIndex(where: { $0.id == stopId }) {
                linear.stops.remove(at: index)
                currentGradient = .linear(linear)
                // Apply live to selected shapes
                applyGradientToSelectedShapes()
            }
        case .radial(var radial):
            guard radial.stops.count > 2 else { return }
            if let index = radial.stops.firstIndex(where: { $0.id == stopId }) {
                radial.stops.remove(at: index)
                currentGradient = .radial(radial)
                // Apply live to selected shapes
                applyGradientToSelectedShapes()
            }
        }
    }
    
    func applyGradientToSelectedShapes() {
        guard let gradient = currentGradient else { return }
        
        let activeShapeIDs = document.getActiveShapeIDs()
        if activeShapeIDs.isEmpty { return }
        
        // Note: Undo stack saving is now handled by individual controls on mouse up/editing end
        
        for shapeID in activeShapeIDs {
            // Find the shape across all layers
            for layerIndex in document.layers.indices {
                if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                    document.layers[layerIndex].shapes[shapeIndex].fillStyle = FillStyle(gradient: gradient, opacity: 1.0)
                    break // Found the shape, no need to check other layers
                }
            }
        }
    }
    
    func addGradientToSwatches() {
        guard let gradient = currentGradient else { return }
        
        // Create a gradient color from the current gradient
        let gradientColor = VectorColor.gradient(gradient)
        
        // Add the gradient to the document's swatches
        document.addColorToSwatches(gradientColor)
        
        print("🎨 GRADIENT PANEL: Added gradient to swatches")
    }
    
    // MARK: - Static Helper Functions
    
    static func getSelectedShapeGradient(document: VectorDocument) -> VectorGradient? {
        let activeShapes = document.getActiveShapes()
        guard let firstShape = activeShapes.first,
              let fillStyle = firstShape.fillStyle,
              case .gradient(let gradient) = fillStyle.color else {
            return nil
        }
        return gradient
    }
    
    static func createDefaultGradient(type: GradientType) -> VectorGradient {
        let stops = [
            GradientStop(position: 0.0, color: .black, opacity: 1.0),
            GradientStop(position: 1.0, color: .white, opacity: 1.0)
        ]
        
        return createGradientWithStops(type: type, stops: stops)
    }
    
    static func createGradientWithStops(type: GradientType, stops: [GradientStop]) -> VectorGradient {
        // Ensure we have at least 2 stops for a valid gradient
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
            // FIXED: Set default origin point to center (0.5,0.5) to match rendering logic
            linear.originPoint = CGPoint(x: 0.5, y: 0.5)
            // Set default scale values for new gradients
            linear.scaleX = 1.0
            linear.scaleY = 1.0
            return .linear(linear)
        case .radial:
            var radial = RadialGradient(
                centerPoint: CGPoint(x: 0, y: 0),
                radius: 0.5,
                stops: validStops,
                focalPoint: CGPoint(x: 0, y: 0), // Set focal point to match center point
                spreadMethod: .pad,
                units: .objectBoundingBox
            )
            // Set default origin point to center (0,0)
            radial.originPoint = CGPoint(x: 0, y: 0)
            // Set default scale values for new gradients
            radial.scaleX = 1.0
            radial.scaleY = 1.0
            return .radial(radial)
        }
    }
    
    // NEW: Create gradient while preserving properties from existing gradient
    static func createGradientPreservingProperties(type: GradientType, stops: [GradientStop], from existingGradient: VectorGradient) -> VectorGradient {
        // Ensure we have at least 2 stops for a valid gradient
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
            
            // Preserve properties from existing gradient
            switch existingGradient {
            case .linear(let existingLinear):
                // Preserve all properties from existing linear gradient
                linear.originPoint = existingLinear.originPoint
                linear.scale = existingLinear.scale
                linear.scaleX = existingLinear.scaleX
                linear.scaleY = existingLinear.scaleY
                linear.units = existingLinear.units
                linear.spreadMethod = existingLinear.spreadMethod
            case .radial(let existingRadial):
                // Convert radial properties to linear where applicable
                linear.originPoint = existingRadial.originPoint
                linear.scale = existingRadial.scale
                linear.scaleX = existingRadial.scaleX
                linear.scaleY = existingRadial.scaleY
                linear.units = existingRadial.units
                linear.spreadMethod = existingRadial.spreadMethod
            }
            
            return .linear(linear)
            
        case .radial:
            // Start with smart defaults based on existing gradient
            let (centerPoint, radius, _) = {
                switch existingGradient {
                case .radial(let existingRadial):
                    return (existingRadial.centerPoint, existingRadial.radius, existingRadial.focalPoint)
                case .linear(_):
                    // Default values for conversion from linear
                    return (CGPoint(x: 0.5, y: 0.5), 0.5, nil as CGPoint?)
                }
            }()
            
            var radial = RadialGradient(
                centerPoint: centerPoint,
                radius: radius,
                stops: validStops,
                focalPoint: centerPoint, // Set focal point to match center point
                spreadMethod: .pad,
                units: .objectBoundingBox
            )
            
            // Preserve properties from existing gradient
            switch existingGradient {
            case .linear(let existingLinear):
                // Convert linear properties to radial where applicable
                radial.originPoint = existingLinear.originPoint
                radial.scale = existingLinear.scale
                radial.scaleX = existingLinear.scaleX
                radial.scaleY = existingLinear.scaleY
                radial.units = existingLinear.units
                radial.spreadMethod = existingLinear.spreadMethod
            case .radial(let existingRadial):
                // Preserve all properties from existing radial gradient
                radial.originPoint = existingRadial.originPoint
                radial.scale = existingRadial.scale
                radial.scaleX = existingRadial.scaleX
                radial.scaleY = existingRadial.scaleY
                radial.angle = existingRadial.angle
                // Note: aspectRatio removed - using independent scaleX/scaleY instead
                radial.units = existingRadial.units
                radial.spreadMethod = existingRadial.spreadMethod
            }
            
            return .radial(radial)
        }
    }
    
    private func findGradientStopColor(stopId: UUID) -> VectorColor {
        // First try to find color in current gradient state
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
        
        // Fallback: try to find in selected shape's gradient
        guard let layerIndex = document.selectedLayerIndex,
              let firstSelectedID = document.selectedShapeIDs.first,
              let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }),
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

// MARK: - Gradient Section Sub-Views

struct GradientTypePickerView: View {
    @Binding var gradientType: GradientFillSection.GradientType
    @Binding var currentGradient: VectorGradient?
    @Binding var gradientId: UUID
    let getGradientStops: (VectorGradient) -> [GradientStop]
    let createGradientPreservingProperties: (GradientFillSection.GradientType, [GradientStop], VectorGradient) -> VectorGradient
    let createDefaultGradient: (GradientFillSection.GradientType) -> VectorGradient
    let onGradientChange: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Type")
                .font(.caption)
                .foregroundColor(Color.ui.secondaryText)
            
            Picker("Gradient Type", selection: $gradientType) {
                ForEach(GradientFillSection.GradientType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: gradientType) { _, newValue in
                if let currentGradient = currentGradient {
                    let preservedStops = getGradientStops(currentGradient)
                    self.currentGradient = createGradientPreservingProperties(newValue, preservedStops, currentGradient)
                } else {
                    // Create default gradient if none exists
                    currentGradient = createDefaultGradient(newValue)
                }
                gradientId = UUID()
                onGradientChange()
            }
        }
    }
}

struct GradientAngleControlView: View {
    let currentGradient: VectorGradient?
    let document: VectorDocument
    let onAngleChange: (Double) -> Void
    
    var body: some View {
        if let gradient = currentGradient {
            let angle: Double = {
                switch gradient {
                case .linear(let linear):
                    return linear.angle
                case .radial(let radial):
                    return radial.angle
                }
            }()
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Angle")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(formatNumberForDisplay(angle, maxDecimals: 1))°")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }
                
                HStack(spacing: 8) {
                    Slider(value: Binding(
                        get: { angle },
                        set: onAngleChange
                    ), in: -180...180, onEditingChanged: { editing in
                        if !editing { document.saveToUndoStack() }
                    })
                    .controlSize(.small)
                    
                    TextField("", text: createNaturalNumberBinding(
                        getValue: { angle },
                        setValue: onAngleChange,
                        formatter: { formatNumberForDisplay($0, maxDecimals: 1) }
                    ))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 60)
                    .font(.system(size: 11))
                }
            }
        }
    }
}

struct GradientOriginControlView: View {
    let currentGradient: VectorGradient?
    let document: VectorDocument
    let getOriginX: (VectorGradient) -> Double
    let getOriginY: (VectorGradient) -> Double
    let updateOriginX: (Double) -> Void
    let updateOriginY: (Double) -> Void
    
    var body: some View {
        if currentGradient != nil {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Origin Point (0,0 = center, -1 to 1 = scaled range)")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("-8 to 8")
                        .font(.caption2)
                        .foregroundColor(Color.ui.primaryBlue)
                        .padding(.horizontal, 4)
                        .background(Color.ui.lightBlueBackground)
                        .cornerRadius(3)
                }
                
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("X: \(currentGradient != nil ? formatNumberForDisplay(getOriginX(currentGradient!)) : "0")")
                            .font(.caption2)
                            .foregroundColor(Color.ui.secondaryText)
                        
                        HStack(spacing: 8) {
                            Slider(value: Binding(
                                get: { currentGradient != nil ? getOriginX(currentGradient!) : 0.0 },
                                set: updateOriginX
                            ), in: -8.0...8.0, onEditingChanged: { editing in
                                if !editing { document.saveToUndoStack() }
                            })
                            .controlSize(.small)
                            
                            TextField("", text: createNaturalNumberBinding(
                                getValue: { currentGradient != nil ? getOriginX(currentGradient!) : 0.0 },
                                setValue: updateOriginX
                            ))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 50)
                            .font(.system(size: 11))
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Y: \(currentGradient != nil ? formatNumberForDisplay(getOriginY(currentGradient!)) : "0")")
                            .font(.caption2)
                            .foregroundColor(Color.ui.secondaryText)
                        
                        HStack(spacing: 8) {
                            Slider(value: Binding(
                                get: { currentGradient != nil ? getOriginY(currentGradient!) : 0.0 },
                                set: updateOriginY
                            ), in: -8.0...8.0, onEditingChanged: { editing in
                                if !editing { document.saveToUndoStack() }
                            })
                            .controlSize(.small)
                            
                            TextField("", text: createNaturalNumberBinding(
                                getValue: { currentGradient != nil ? getOriginY(currentGradient!) : 0.0 },
                                setValue: updateOriginY
                            ))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 50)
                            .font(.system(size: 11))
                        }
                    }
                }
            }
        }
    }
}

struct GradientScaleControlView: View {
    let currentGradient: VectorGradient?
    let document: VectorDocument
    let getScale: (VectorGradient) -> Double
    let updateScale: (Double) -> Void
    let getAspectRatio: (VectorGradient) -> Double
    let updateAspectRatio: (Double) -> Void
    let getRadius: (VectorGradient) -> Double
    let updateRadius: (Double) -> Void
    
    var body: some View {
        if currentGradient != nil {
            VStack(alignment: .leading, spacing: 8) {
                // Uniform Scale Control
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scale: \(currentGradient != nil ? Int(getScale(currentGradient!) * 100) : 100)%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                    
                    HStack(spacing: 8) {
                        Slider(value: Binding(
                            get: { currentGradient != nil ? getScale(currentGradient!) : 1.0 },
                            set: { newScale in
                                updateScale(newScale)
                            }
                        ), in: 0.01...8.0, onEditingChanged: { editing in
                            if !editing { document.saveToUndoStack() }
                        })
                        .controlSize(.small)
                        
                        TextField("", text: createNaturalNumberBinding(
                            getValue: { currentGradient != nil ? getScale(currentGradient!) : 1.0 },
                            setValue: updateScale
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 50)
                        .font(.system(size: 11))
                    }
                }
                
                // Aspect Ratio Control (X=1, Y=0 to 1) - ONLY for Radial Gradients
                if case .radial = currentGradient {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Aspect Ratio: \(currentGradient != nil ? formatNumberForDisplay(getAspectRatio(currentGradient!)) : "1")")
                            .font(.caption)
                            .foregroundColor(Color.ui.secondaryText)
                        
                        HStack(spacing: 8) {
                            Slider(value: Binding(
                                get: { currentGradient != nil ? getAspectRatio(currentGradient!) : 1.0 },
                                set: { newAspectRatio in
                                    updateAspectRatio(newAspectRatio)
                                }
                            ), in: 0.01...2.0, onEditingChanged: { editing in
                                if !editing { document.saveToUndoStack() }
                            })
                            .controlSize(.small)
                            
                            TextField("", text: createNaturalNumberBinding(
                                getValue: { currentGradient != nil ? getAspectRatio(currentGradient!) : 1.0 },
                                setValue: updateAspectRatio
                            ))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 50)
                            .font(.system(size: 11))
                        }
                    }
                    
                    // Radius Control - ONLY for Radial Gradients
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Radius: \(currentGradient != nil ? formatNumberForDisplay(getRadius(currentGradient!)) : "0.5")")
                            .font(.caption)
                            .foregroundColor(Color.ui.secondaryText)
                        
                        HStack(spacing: 8) {
                            Slider(value: Binding(
                                get: { currentGradient != nil ? getRadius(currentGradient!) : 0.5 },
                                set: { newRadius in
                                    updateRadius(newRadius)
                                }
                            ), in: 0.1...2.0, onEditingChanged: { editing in
                                if !editing { document.saveToUndoStack() }
                            })
                            .controlSize(.small)
                            
                            TextField("", text: createNaturalNumberBinding(
                                getValue: { currentGradient != nil ? getRadius(currentGradient!) : 0.5 },
                                setValue: updateRadius
                            ))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 50)
                            .font(.system(size: 11))
                        }
                    }
                }
            }
        }
    }
}



struct GradientPreviewAndStopsView: View {
    let currentGradient: VectorGradient?
    let document: VectorDocument
    @Binding var editingGradientStopId: UUID?
    @Binding var editingGradientStopColor: VectorColor
    @Binding var showingGradientColorPicker: Bool
    let getGradientStops: (VectorGradient) -> [GradientStop]
    let getOriginX: (VectorGradient) -> Double
    let getOriginY: (VectorGradient) -> Double
    let getScale: (VectorGradient) -> Double
    let getAspectRatio: (VectorGradient) -> Double
    let updateOriginX: (Double, Bool) -> Void
    let updateOriginY: (Double, Bool) -> Void
    let addColorStop: () -> Void
    let updateStopPosition: (UUID, Double) -> Void
    let updateStopOpacity: (UUID, Double) -> Void
    let removeColorStop: (UUID) -> Void
    let applyGradientToSelectedShapes: () -> Void
    let activateGradientStop: (UUID, VectorColor) -> Void
    
    private func calculateDotPosition(geometry: GeometryProxy, squareSize: CGFloat, centerX: CGFloat, centerY: CGFloat) -> CGPoint {
        guard let gradient = currentGradient else { return CGPoint(x: centerX, y: centerY) }
        
        switch gradient {
        case .linear:
            // FIXED: Linear gradients should use origin point directly like radial gradients
            let originX = getOriginX(gradient)
            let originY = getOriginY(gradient)
            
            // Clamp the dot position to stay within preview bounds (0,0 to 1,1)
            let clampedX = max(0.0, min(1.0, originX))
            let clampedY = max(0.0, min(1.0, originY))
            
            return CGPoint(
                x: clampedX * squareSize,
                y: clampedY * squareSize
            )
            
        case .radial:
            // Radial gradients use origin point directly
            let originX = getOriginX(gradient)
            let originY = getOriginY(gradient)
            
            // Clamp the dot position to stay within preview bounds (0,0 to 1,1)
            let clampedX = max(0.0, min(1.0, originX))
            let clampedY = max(0.0, min(1.0, originY))
            
            return CGPoint(
                x: clampedX * squareSize,
                y: clampedY * squareSize
            )
        }
    }
    
    private func createGradientPreview(geometry: GeometryProxy, squareSize: CGFloat) -> some View {
        return Group {
            if let gradient = currentGradient {
                // Use NSView-based gradient preview that matches the actual rendering
                GradientPreviewNSView(gradient: gradient, size: squareSize)
                    .frame(width: squareSize, height: squareSize)
                    .overlay(Rectangle().stroke(Color.ui.lightGrayBorder, lineWidth: 1))
                    .overlay(CartesianGrid(width: squareSize, height: squareSize) { x, y in
                        // Clamp preview to 0,0 to 1,1 bounds for visual clarity
                        let clampedX = max(0.0, min(1.0, x))
                        let clampedY = max(0.0, min(1.0, y))
                        updateOriginX(clampedX, true)
                        updateOriginY(clampedY, true)
                        document.saveToUndoStack()
                    })
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: squareSize, height: squareSize)
                    .overlay(Rectangle().stroke(Color.ui.lightGrayBorder, lineWidth: 1))
            }
        }
    }
    
    private func createDraggableDot(geometry: GeometryProxy, squareSize: CGFloat, centerX: CGFloat, centerY: CGFloat) -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: 8, height: 8)
            .overlay(Circle().stroke(Color.black, lineWidth: 1))
            .position(calculateDotPosition(geometry: geometry, squareSize: squareSize, centerX: centerX, centerY: centerY))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Clamp preview to 0,0 to 1,1 bounds for visual clarity
                        let normalizedX = max(0.0, min(1.0, value.location.x / squareSize))
                        let normalizedY = max(0.0, min(1.0, value.location.y / squareSize))
                        updateOriginX(normalizedX, true) // Enable live preview on shapes
                        updateOriginY(normalizedY, true) // Enable live preview on shapes
                    }
                    .onEnded { _ in 
                        document.saveToUndoStack() 
                    }
            )
    }
    
    private func createPreviewContent(geometry: GeometryProxy) -> some View {
        let fullWidth = geometry.size.width
        let squareSize = fullWidth // Use full width
        let centerX: CGFloat = fullWidth / 2
        let centerY: CGFloat = fullWidth / 2 // Center vertically too for perfect square
        
        return createGradientPreview(geometry: geometry, squareSize: squareSize)
            .onTapGesture { location in
                // Clamp preview to 0,0 to 1,1 bounds for visual clarity
                let normalizedX = max(0.0, min(1.0, location.x / fullWidth))
                let normalizedY = max(0.0, min(1.0, location.y / fullWidth))
                updateOriginX(normalizedX, true)
                updateOriginY(normalizedY, true)
                document.saveToUndoStack()
            }
            .overlay(createDraggableDot(geometry: geometry, squareSize: squareSize, centerX: centerX, centerY: centerY))
    }
    
    var body: some View {
        if currentGradient != nil {
            VStack(alignment: .leading, spacing: 8) {
                Text("Preview")
                    .font(.caption)
                    .foregroundColor(Color.ui.secondaryText)
                
                GeometryReader { geometry in
                    createPreviewContent(geometry: geometry)
                }
                .aspectRatio(1, contentMode: .fit) // Perfect square
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Color Stops")
                            .font(.caption)
                            .foregroundColor(Color.ui.secondaryText)
                        Spacer()
                        Button(action: addColorStop) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(Color.ui.primaryBlue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Memoize gradient stops calculation for performance
                    let stops = getGradientStops(currentGradient!).sorted { $0.position < $1.position }
                    ForEach(stops, id: \.id) { stop in
                        HStack(spacing: 8) {
                            Button(action: {
                                print("🎨 GRADIENT STOP: Clicked on stop \(stop.id.uuidString.prefix(8))")
                                // Always activate the clicked gradient stop, even if it was already set
                                activateGradientStop(stop.id, stop.color)
                            }) {
                                renderColorSwatchRightPanel(stop.color, width: 20, height: 20, cornerRadius: 0, borderWidth: 1, opacity: stop.opacity)
                            }
                            .buttonStyle(PlainButtonStyle())
                            // .overlay(
                            //     // Visual indicator for currently editing stop
                            //     RoundedRectangle(cornerRadius: 0)
                            //         .stroke(Color.blue, lineWidth: editingGradientStopId == stop.id ? 3 : 0)
                            // )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                // HStack {
                                //     // Show "EDITING" indicator for the selected stop
                                //     if editingGradientStopId == stop.id {
                                //         Text("EDITING")
                                //             .font(.caption2)
                                //             .foregroundColor(Color.ui.primaryBlue)
                                //             .fontWeight(.bold)
                                //     }
                                //     Spacer()
                                // }
                                
                                // Position and Opacity on same line
                                HStack(spacing: 8) {
                                    // Position slider
                                    Slider(value: Binding(
                                        get: { stop.position },
                                        set: { updateStopPosition(stop.id, $0) }
                                    ), in: 0...1)
                                    .controlSize(.small)
                                    
                                    // Position text field
                                    TextField("", text: Binding(
                                        get: { 
                                            let percentage = stop.position * 100
                                            // Show clean numbers without decimals for whole percentages
                                            return percentage.truncatingRemainder(dividingBy: 1) == 0 ? 
                                                String(format: "%.0f", percentage) : 
                                                String(format: "%.1f", percentage)
                                        },
                                        set: { newValue in
                                            if let doubleValue = Double(newValue) {
                                                updateStopPosition(stop.id, doubleValue / 100.0)
                                            }
                                        }
                                    ))
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 40)
                                    .font(.system(size: 11))
                                    
                                    // Opacity text field
                                    TextField("", text: Binding(
                                        get: { 
                                            let percentage = stop.opacity * 100
                                            // Show clean numbers without decimals for whole percentages
                                            return percentage.truncatingRemainder(dividingBy: 1) == 0 ? 
                                                String(format: "%.0f", percentage) : 
                                                String(format: "%.1f", percentage)
                                        },
                                        set: { newValue in
                                            if let doubleValue = Double(newValue) {
                                                updateStopOpacity(stop.id, doubleValue / 100.0)
                                            }
                                        }
                                    ))
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 40)
                                    .font(.system(size: 11))
                                }
                            }
                            
                            if stops.count > 2 {
                                Button(action: { removeColorStop(stop.id) }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(Color.ui.errorColor)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.vertical, 4)
                        // .background(
                        //     // Background highlight for currently editing stop
                        //     RoundedRectangle(cornerRadius: 6)
                        //         .fill(editingGradientStopId == stop.id ? Color.blue.opacity(0.1) : Color.clear)
                        // )
                    }
                }
            }
        }
    }
}

struct GradientApplyButtonView: View {
    let currentGradient: VectorGradient?
    let onApply: () -> Void
    let onAddSwatch: () -> Void
    
    var body: some View {
        HStack {
            Spacer()
            Button("Add Swatch", action: onAddSwatch)
                .buttonStyle(.bordered)
                .disabled(currentGradient == nil)
            Button("Apply Gradient", action: onApply)
                .buttonStyle(.borderedProminent)
                .disabled(currentGradient == nil)
        }
    }
}

// MARK: - SwiftUI HUD Window for Gradient Color Picker

// 🔥 PERSISTENT GRADIENT HUD VIEW: Never recreated, only state updates
struct PersistentGradientHUDView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        let hudManager = appState.persistentGradientHUD
        
        if hudManager.isVisible {
            StableGradientHUDContent(hudManager: hudManager)
                // 🔥 POSITION NOT NEEDED - NSWindow handles positioning
                .animation(.none, value: hudManager.isDragging)
        }
    }
}

// 🔥 STABLE HUD CONTENT - Prevents recreation during dragging
struct StableGradientHUDContent: View, Equatable {
    let hudManager: PersistentGradientHUDManager
    
    // Make this view stable by implementing Equatable
    static func == (lhs: StableGradientHUDContent, rhs: StableGradientHUDContent) -> Bool {
        // Only recreate if the essential content changes, not position/dragging
        return lhs.hudManager.editingStopId == rhs.hudManager.editingStopId &&
               lhs.hudManager.editingStopColor == rhs.hudManager.editingStopColor &&
               lhs.hudManager.isVisible == rhs.hudManager.isVisible
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 🔥 STABLE COLOR PANEL - Only recreated when editingStopId changes
            StableColorPanelWrapper(hudManager: hudManager)
                .frame(maxWidth: 350, maxHeight: 500)
            
            // 🔥 CLOSE BUTTON in lower right corner
            HStack {
                Spacer()
                
                // Close button in lower right
                Button("Close") {
                    hudManager.hide()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .padding(.trailing, 16)
                .padding(.bottom, 12)
            }
            .background(Color(NSColor.windowBackgroundColor))
        }
        .fixedSize()
        .background(Color(NSColor.windowBackgroundColor))
        //.cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

// 🔥 STABLE COLOR PANEL WRAPPER - Prevents ColorPanel recreation
struct StableColorPanelWrapper: View, Equatable {
    let hudManager: PersistentGradientHUDManager
    
    static func == (lhs: StableColorPanelWrapper, rhs: StableColorPanelWrapper) -> Bool {
        // Only recreate ColorPanel when the editing stop changes
        return lhs.hudManager.editingStopId == rhs.hudManager.editingStopId
    }
    
    var body: some View {
                                ColorPanel(
            document: hudManager.getStableDocument(),
            onColorSelected: { newColor in
                if let stopId = hudManager.editingStopId {
                    hudManager.updateStopColor(stopId, newColor)
                }
            },
            showGradientEditing: true
        )
        .fixedSize()
    }
}



struct GradientColorPickerSheet: View {
    let document: VectorDocument
    let editingGradientStopId: UUID?
    let editingGradientStopColor: VectorColor
    let currentGradient: VectorGradient? // Add current gradient reference
    @Binding var showingColorPicker: Bool
    let updateStopColor: (UUID, VectorColor) -> Void
    let turnOffEditingState: () -> Void
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    // Create a local document wrapper with the correct initial color
    @State private var localDocument: VectorDocument
    
    // Add close callback for the window
    var onClose: (() -> Void)?
    
    init(document: VectorDocument, editingGradientStopId: UUID?, editingGradientStopColor: VectorColor, currentGradient: VectorGradient?, showingColorPicker: Binding<Bool>, updateStopColor: @escaping (UUID, VectorColor) -> Void, turnOffEditingState: @escaping () -> Void, onClose: (() -> Void)? = nil) {
        self.document = document
        self.editingGradientStopId = editingGradientStopId
        self.editingGradientStopColor = editingGradientStopColor
        self.currentGradient = currentGradient
        self._showingColorPicker = showingColorPicker
        self.updateStopColor = updateStopColor
        self.turnOffEditingState = turnOffEditingState
        self.onClose = onClose
        
        // Create a copy of the document with the correct initial color but preserve important properties
        let localDoc = VectorDocument()
        localDoc.defaultFillColor = editingGradientStopColor
        
        // Copy essential properties from the original document
        localDoc.settings = document.settings  // Includes colorMode, etc.
        
        // Copy color swatches based on current mode
        localDoc.rgbSwatches = document.rgbSwatches
        localDoc.cmykSwatches = document.cmykSwatches
        localDoc.hsbSwatches = document.hsbSwatches
        
        self._localDocument = State(initialValue: localDoc)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ColorPanel(document: localDocument, onColorSelected: { newColor in
                // When a color is selected, update the stop but DON'T close the window
                if let stopId = editingGradientStopId {
                    updateStopColor(stopId, newColor)
                }
                // Window stays open - user controls when to close
            }, showGradientEditing: true)
            .frame(width: 300, height: 500)  // Reduced height to make room for close button
            
            // Close button in lower right corner
            HStack {
                Spacer()
                Button("Close!") {
                    // Turn off editing state
                    turnOffEditingState()
                    // Hide the window
                    if let window = NSApplication.shared.windows.first(where: { $0.title == "Select Gradient Color" }) {
                        window.orderOut(nil)
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
            .frame(height: 50)
        }
        .background(
            Rectangle()
                .fill(Color(NSColor.windowBackgroundColor))
        )
        .clipShape(Rectangle()) // Force sharp square corners
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5) // Professional shadow
        .task {
            // Set up gradient editing state
            if let stopId = editingGradientStopId, let gradient = currentGradient {
                // Find the correct stop and its current color
                let stops: [GradientStop]
                switch gradient {
                case .linear(let linear):
                    stops = linear.stops
                case .radial(let radial):
                    stops = radial.stops
                }
                
                let stopIndex = stops.firstIndex { $0.id == stopId } ?? 0
                
                // CRITICAL: Use the captured stopId to avoid closure issues
                let capturedStopId = stopId
                appState.gradientEditingState = GradientEditingState(
                    gradientId: capturedStopId,
                    stopIndex: stopIndex,
                    onColorSelected: { color in
                        updateStopColor(capturedStopId, color)
                        // Window stays open - user controls when to close
                    }
                )
            }
        }
        .onDisappear {
            // DON'T clean up gradient editing state to prevent SwiftUI crashes
        }
    }
}

// MARK: - Elliptical Gradient for Preview (since SwiftUI doesn't support elliptical radial gradients)

// EllipticalGradient struct removed - now using NSView-based gradient preview that matches actual rendering

// MARK: - Cartesian Grid for Gradient Preview

struct CartesianGrid: View {
    let width: CGFloat
    let height: CGFloat
    let onCoordinateClick: ((Double, Double) -> Void)?
    
    init(width: CGFloat, height: CGFloat, onCoordinateClick: ((Double, Double) -> Void)? = nil) {
        self.width = width
        self.height = height
        self.onCoordinateClick = onCoordinateClick
    }
    
    var body: some View {
        ZStack {
            // Vertical grid lines (X-axis markers) - edge to edge
            ForEach(0..<5) { index in
                let position = CGFloat(index) / 4.0  // 0.0 to 1.0
                let xPosition = position * width
                
                // Full-height vertical line (edge to edge)
                Rectangle()
                    .fill(Color.white.opacity(position == 0.5 ? 0.9 : 0.3))
                    .frame(width: position == 0.5 ? 1 : 0.5, height: height)
                    .position(x: xPosition, y: height / 2)
            }
            
            // Horizontal grid lines (Y-axis markers) - edge to edge
            ForEach(0..<5) { index in
                let position = CGFloat(index) / 4.0  // 0.0 to 1.0
                let yPosition = position * height
                
                // Full-width horizontal line (edge to edge)
                Rectangle()
                    .fill(Color.white.opacity(position == 0.5 ? 0.9 : 0.3))
                    .frame(width: width, height: position == 0.5 ? 1 : 0.5)
                    .position(x: width / 2, y: yPosition)
            }
            
            // Coordinate labels at key positions
            VStack {
                HStack {
                    Text("(0,0)")
                        .font(.caption2)
                        .foregroundColor(Color.ui.white)
                        .offset(x: 2, y: 2)
                    Spacer()
                    Text("(0.5,0)")
                        .font(.caption2)
                        .foregroundColor(Color.ui.white)
                        .offset(y: 2)
                    Spacer()
                    Text("(1,0)")
                        .font(.caption2)
                        .foregroundColor(Color.ui.white)
                        .offset(x: -2, y: 2)
                }
                .padding(.horizontal, 4)
                Spacer()
                HStack {
                    Text("(0,1)")
                        .font(.caption2)
                        .foregroundColor(Color.ui.white)
                        .offset(x: 2, y: -2)
                    Spacer()
                    Text("(0.5,1)")
                        .font(.caption2)
                        .foregroundColor(Color.ui.white)
                        .offset(y: -2)
                    Spacer()
                    Text("(1,1)")
                        .font(.caption2)
                        .foregroundColor(Color.ui.white)
                        .offset(x: -2, y: -2)
                }
                .padding(.horizontal, 4)
            }
            
            // Clickable coordinate points
            if let onCoordinateClick = onCoordinateClick {
                // Corner points
                // Top-left (0,0)
                Circle()
                    .fill(Color.ui.mediumBlueBackground)
                    .frame(width: 12, height: 12)
                    .position(x: 0, y: 0)
                    .onTapGesture {
                        onCoordinateClick(0.0, 0.0)
                    }
                
                // Top-right (1,0)
                Circle()
                    .fill(Color.ui.mediumBlueBackground)
                    .frame(width: 12, height: 12)
                    .position(x: width, y: 0)
                    .onTapGesture {
                        onCoordinateClick(1.0, 0.0)
                    }
                
                // Bottom-left (0,1)
                Circle()
                    .fill(Color.ui.mediumBlueBackground)
                    .frame(width: 12, height: 12)
                    .position(x: 0, y: height)
                    .onTapGesture {
                        onCoordinateClick(0.0, 1.0)
                    }
                
                // Bottom-right (1,1)
                Circle()
                    .fill(Color.ui.mediumBlueBackground)
                    .frame(width: 12, height: 12)
                    .position(x: width, y: height)
                    .onTapGesture {
                        onCoordinateClick(1.0, 1.0)
                    }
                
                // Center (0.5,0.5)
                Circle()
                    .fill(Color.green.opacity(0.6))
                    .frame(width: 12, height: 12)
                    .position(x: width/2, y: height/2)
                    .onTapGesture {
                        onCoordinateClick(0.5, 0.5)
                    }
                
                // Edge midpoints
                // Top center (0.5,0)
                Circle()
                    .fill(Color.ui.mediumBlueBackground)
                    .frame(width: 12, height: 12)
                    .position(x: width/2, y: 0)
                    .onTapGesture {
                        onCoordinateClick(0.5, 0.0)
                    }
                
                // Bottom center (0.5,1)
                Circle()
                    .fill(Color.ui.mediumBlueBackground)
                    .frame(width: 12, height: 12)
                    .position(x: width/2, y: height)
                    .onTapGesture {
                        onCoordinateClick(0.5, 1.0)
                    }
                
                // Left center (0,0.5)
                Circle()
                    .fill(Color.ui.mediumBlueBackground)
                    .frame(width: 12, height: 12)
                    .position(x: 0, y: height/2)
                    .onTapGesture {
                        onCoordinateClick(0.0, 0.5)
                    }
                
                // Right center (1,0.5)
                Circle()
                    .fill(Color.ui.mediumBlueBackground)
                    .frame(width: 12, height: 12)
                    .position(x: width, y: height/2)
                    .onTapGesture {
                        onCoordinateClick(1.0, 0.5)
                    }
                
                // Grid intersections (8 additional points)
                // Top-left quadrant center (0.25,0.25)
                Circle()
                    .fill(Color.ui.mediumBlueBackground)
                    .frame(width: 12, height: 12)
                    .position(x: width * 0.25, y: height * 0.25)
                    .onTapGesture {
                        onCoordinateClick(0.25, 0.25)
                    }
                
                // Top-right quadrant center (0.75,0.25)
                Circle()
                    .fill(Color.ui.mediumBlueBackground)
                    .frame(width: 12, height: 12)
                    .position(x: width * 0.75, y: height * 0.25)
                    .onTapGesture {
                        onCoordinateClick(0.75, 0.25)
                    }
                
                // Bottom-left quadrant center (0.25,0.75)
                Circle()
                    .fill(Color.ui.mediumBlueBackground)
                    .frame(width: 12, height: 12)
                    .position(x: width * 0.25, y: height * 0.75)
                    .onTapGesture {
                        onCoordinateClick(0.25, 0.75)
                    }
                
                // Bottom-right quadrant center (0.75,0.75)
                Circle()
                    .fill(Color.ui.mediumBlueBackground)
                    .frame(width: 12, height: 12)
                    .position(x: width * 0.75, y: height * 0.75)
                    .onTapGesture {
                        onCoordinateClick(0.75, 0.75)
                    }
                
                // Left middle (0.25,0.5)
                Circle()
                    .fill(Color.ui.mediumBlueBackground)
                    .frame(width: 12, height: 12)
                    .position(x: width * 0.25, y: height * 0.5)
                    .onTapGesture {
                        onCoordinateClick(0.25, 0.5)
                    }
                
                // Right middle (0.75,0.5)
                Circle()
                    .fill(Color.ui.mediumBlueBackground)
                    .frame(width: 12, height: 12)
                    .position(x: width * 0.75, y: height * 0.5)
                    .onTapGesture {
                        onCoordinateClick(0.75, 0.5)
                    }
                
                // Top middle (0.5,0.25)
                Circle()
                    .fill(Color.ui.mediumBlueBackground)
                    .frame(width: 12, height: 12)
                    .position(x: width * 0.5, y: height * 0.25)
                    .onTapGesture {
                        onCoordinateClick(0.5, 0.25)
                    }
                
                // Bottom middle (0.5,0.75)
                Circle()
                    .fill(Color.ui.mediumBlueBackground)
                    .frame(width: 12, height: 12)
                    .position(x: width * 0.5, y: height * 0.75)
                    .onTapGesture {
                        onCoordinateClick(0.5, 0.75)
                    }
            }
        }
    }
}

// MARK: - Gradient Window Delegate

// Preview
struct GradientPanel_Previews: PreviewProvider {
    static var previews: some View {
        GradientPanel(document: VectorDocument())
            .frame(width: 300, height: 600)
    }
}

// MARK: - NSView-Based Gradient Preview

struct GradientPreviewNSView: NSViewRepresentable {
    let gradient: VectorGradient
    let size: CGFloat
    
    func makeNSView(context: Context) -> GradientPreviewNSViewClass {
        return GradientPreviewNSViewClass(gradient: gradient, size: size)
    }
    
    func updateNSView(_ nsView: GradientPreviewNSViewClass, context: Context) {
        nsView.gradient = gradient
        nsView.size = size
        nsView.needsDisplay = true
    }
}

class GradientPreviewNSViewClass: NSView {
    var gradient: VectorGradient
    var size: CGFloat
    
    init(gradient: VectorGradient, size: CGFloat) {
        self.gradient = gradient
        self.size = size
        super.init(frame: CGRect(x: 0, y: 0, width: size, height: size))
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var isFlipped: Bool {
        return true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        context.saveGState()
        
        // Create a square path for the preview (same as the preview bounds)
        let pathBounds = CGRect(x: 0, y: 0, width: size, height: size)
        let path = CGPath(rect: pathBounds, transform: nil)
        
        // Create CGGradient with proper clear color handling (EXACTLY like LayerView)
        let colors = gradient.stops.map { stop -> CGColor in
            if case .clear = stop.color {
                // For clear colors, use the clear color's cgColor directly (don't apply opacity)
                return stop.color.cgColor
            } else {
                // For non-clear colors, apply the stop opacity
                return stop.color.color.opacity(stop.opacity).cgColor ?? stop.color.cgColor
            }
        }
        let locations: [CGFloat] = gradient.stops.map { CGFloat($0.position) }
        guard let cgGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locations) else {
            context.restoreGState()
            return
        }
        
        // Add path for clipping
        context.addPath(path)
        context.clip()
        
        // Draw gradient using EXACTLY the same logic as LayerView
        switch gradient {
        case .linear(let linear):
            // FIXED: Use the same coordinate system as the preview and gradient edit tool
            // The origin point represents the center of the gradient, just like radial gradients
            let originX = linear.originPoint.x
            let originY = linear.originPoint.y
            
            // Apply scale factor to match the coordinate system
            let scale = CGFloat(linear.scaleX)
            let scaledOriginX = originX * scale
            let scaledOriginY = originY * scale
            
            // Calculate the center of the gradient in path coordinates
            let centerX = pathBounds.minX + pathBounds.width * scaledOriginX
            let centerY = pathBounds.minY + pathBounds.height * scaledOriginY
            
            // Calculate gradient direction based on startPoint and endPoint
            let gradientVector = CGPoint(x: linear.endPoint.x - linear.startPoint.x, y: linear.endPoint.y - linear.startPoint.y)
            let gradientLength = sqrt(gradientVector.x * gradientVector.x + gradientVector.y * gradientVector.y)
            let gradientAngle = atan2(gradientVector.y, gradientVector.x)
            
            // Apply scale to gradient length
            let scaledLength = gradientLength * CGFloat(scale) * max(pathBounds.width, pathBounds.height)
            
            // Calculate start and end points
            let startX = centerX - cos(gradientAngle) * scaledLength / 2
            let startY = centerY - sin(gradientAngle) * scaledLength / 2
            let endX = centerX + cos(gradientAngle) * scaledLength / 2
            let endY = centerY + sin(gradientAngle) * scaledLength / 2
            
            let startPoint = CGPoint(x: startX, y: startY)
            let endPoint = CGPoint(x: endX, y: endY)
            
            context.drawLinearGradient(cgGradient, start: startPoint, end: endPoint, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            
        case .radial(let radial):
            // FIXED: Radial gradient coordinate system - centerPoint is already in 0-1 range
            
            // FIXED: Origin point should NOT be scaled - it defines the center position
            let originX = radial.originPoint.x
            let originY = radial.originPoint.y
            
            // Calculate the center position in path coordinates (no scaling applied to position)
            let center = CGPoint(x: pathBounds.minX + pathBounds.width * originX,
                                 y: pathBounds.minY + pathBounds.height * originY)
            
            // Apply transforms for angle and aspect ratio support
            context.saveGState()
            
            // Translate to gradient center for transformation
            context.translateBy(x: center.x, y: center.y)
            
            // Apply rotation (convert degrees to radians)
            let angleRadians = CGFloat(radial.angle * .pi / 180.0)
            context.rotate(by: angleRadians)
            
            // Apply independent X/Y scaling (elliptical gradient) - this affects the shape, not the position
            let scaleX = CGFloat(radial.scaleX)
            let scaleY = CGFloat(radial.scaleY)
            context.scaleBy(x: scaleX, y: scaleY)
            
            // FIXED: Focal point should NOT be scaled - it's already in the correct coordinate space
            let focalPoint: CGPoint
            if let focal = radial.focalPoint {
                // Focal point is already in the correct coordinate space relative to center
                focalPoint = CGPoint(x: focal.x, y: focal.y)
            } else {
                // No focal point specified, use center
                focalPoint = CGPoint.zero
            }
            
            // Calculate radius - use the original calculation that was working before
            let radius = max(pathBounds.width, pathBounds.height) * CGFloat(radial.radius)
            
            // Draw gradient with focal point in original coordinate space
            context.drawRadialGradient(cgGradient, startCenter: focalPoint, startRadius: 0, endCenter: CGPoint.zero, endRadius: radius, options: [.drawsAfterEndLocation])
            
            context.restoreGState()
        }
        
        context.restoreGState()
    }
}
