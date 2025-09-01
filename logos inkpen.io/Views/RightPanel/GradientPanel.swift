//
//  GradientPanel.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI
import AppKit

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
    @State private var isEditingAngle: Bool = false // Track when actively editing angle
    
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
        .onChange(of: document.selectedShapeIDs) { _, _ in updateSelectedGradient() }
        .onChange(of: document.selectedLayerIndex) { _, _ in updateSelectedGradient() }
        .onReceive(document.objectWillChange) { _ in
            // FIXED: Only update UI display, don't modify gradients
            // BUT: Don't overwrite currentGradient if we're actively editing
            if editingGradientStopId == nil && !isEditingAngle {
                updateSelectedGradientDisplay()
            }
        }
    }
    
    private func turnOffEditingState() {
        Log.fileOperation("🎨 GRADIENT PANEL: turnOffEditingState() called", level: .info)
        // 🔥 FIXED: Clear gradient editing state first to prevent circular calls
        appState.gradientEditingState = nil
        Log.fileOperation("🎨 GRADIENT PANEL: Cleared gradientEditingState", level: .info)
        // 🔥 PROPERLY HIDE THE HUD - This will close the window and reset state
        appState.persistentGradientHUD.hide()
        Log.fileOperation("🎨 GRADIENT PANEL: Called persistentGradientHUD.hide()", level: .info)
        // 🔥 CRITICAL: Clear the editing stop ID last to prevent onChange trigger
        editingGradientStopId = nil
        Log.fileOperation("🎨 GRADIENT PANEL: Cleared editingGradientStopId", level: .info)
        
        // 🔥 ADDITIONAL SAFETY: Force reset any stuck state
        DispatchQueue.main.async {
            if self.editingGradientStopId != nil {
                Log.fileOperation("🎨 GRADIENT PANEL: WARNING - editingGradientStopId still not nil, forcing reset", level: .info)
                self.editingGradientStopId = nil
            }
            if appState.gradientEditingState != nil {
                Log.fileOperation("🎨 GRADIENT PANEL: WARNING - gradientEditingState still not nil, forcing reset", level: .info)
                appState.gradientEditingState = nil
            }
        }
    }
    
    // MARK: - Gradient Stop Activation
    
    private func activateGradientStop(_ stopId: UUID, color: VectorColor) {
        Log.fileOperation("🎨 GRADIENT PANEL: activateGradientStop called for stop \(stopId.uuidString.prefix(8))", level: .info)
        
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
        Log.fileOperation("🚨 GRADIENT PANEL: updateSelectedGradient called!", level: .info)
        Log.fileOperation("🚨 GRADIENT PANEL: This function might be modifying gradients!", level: .info)
        
        if let selectedGradient = Self.getSelectedShapeGradient(document: document) {
            Log.fileOperation("🚨 GRADIENT PANEL: Found selected gradient: \(selectedGradient)", level: .info)
            currentGradient = selectedGradient
            switch selectedGradient {
            case .linear(_):
                gradientType = .linear
            case .radial(_):
                gradientType = .radial
            }
            gradientId = UUID() // Generate new ID for loaded gradient
            Log.fileOperation("🚨 GRADIENT PANEL: Updated currentGradient and gradientId", level: .info)
        } else {
            Log.fileOperation("🚨 GRADIENT PANEL: No selected gradient found", level: .info)
        }
    }
    
    // NEW: Only update display, don't generate new IDs or modify state
    private func updateSelectedGradientDisplay() {
        Log.fileOperation("🔄 GRADIENT PANEL: updateSelectedGradientDisplay called (display only)", level: .info)
        
        if let selectedGradient = Self.getSelectedShapeGradient(document: document) {
            Log.fileOperation("🔄 GRADIENT PANEL: Found selected gradient for display update", level: .info)
            // Only update the display values, don't change gradientId or other state
            currentGradient = selectedGradient
            switch selectedGradient {
            case .linear(_):
                gradientType = .linear
            case .radial(_):
                gradientType = .radial
            }
            // DON'T generate new gradientId - preserve existing state
            Log.fileOperation("🔄 GRADIENT PANEL: Updated display without modifying state", level: .info)
        } else {
            Log.fileOperation("🔄 GRADIENT PANEL: No selected gradient found for display", level: .info)
        }
    }
    
    private func updateGradientAngle(_ newAngle: Double) {
        guard let gradient = currentGradient else { return }
        
        // Normalize angle to -180 to +180 range
        var normalizedAngle = newAngle
        while normalizedAngle > 180 {
            normalizedAngle -= 360
        }
        while normalizedAngle < -180 {
            normalizedAngle += 360
        }
        
        // Set flag to prevent display update from overwriting our changes
        isEditingAngle = true
        
        switch gradient {
        case .linear(var linear):
            linear.angle = normalizedAngle
            currentGradient = .linear(linear)
            // Apply live to selected shapes
            applyGradientToSelectedShapes()
        case .radial(var radial):
            radial.angle = normalizedAngle
            currentGradient = .radial(radial)
            // Apply live to selected shapes
            applyGradientToSelectedShapes()
        }
        
        // Reset flag after a short delay to allow UI to update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isEditingAngle = false
        }
    }
    
    // NEW: Origin Point Controls
    private func getGradientOriginX(_ gradient: VectorGradient) -> Double {
        switch gradient {
        case .linear(let linear):
            return linear.originPoint.x
        case .radial(let radial):
            let originX = radial.originPoint.x
            //Log.debug("🔍 getGradientOriginX: \(originX) (radial.originPoint.x)", category: .general)
            return originX
        }
    }
    
    private func getGradientOriginY(_ gradient: VectorGradient) -> Double {
        switch gradient {
        case .linear(let linear):
            return linear.originPoint.y
        case .radial(let radial):
            let originY = radial.originPoint.y
            //print("// Log.debug("🔍 getGradientOriginY: \(originY) (radial.originPoint.y)", category: .general)
            return originY
        }
    }
    
    private func updateGradientOriginX(_ newX: Double, applyToShapes: Bool = true) {
        updateGradientOriginXOptimized(newX, applyToShapes: applyToShapes, isLiveDrag: false)
    }
    
    private func updateGradientOriginY(_ newY: Double, applyToShapes: Bool = true) {
        updateGradientOriginYOptimized(newY, applyToShapes: applyToShapes, isLiveDrag: false)
    }
    
    /// Optimized origin X update with live drag support
    private func updateGradientOriginXOptimized(_ newX: Double, applyToShapes: Bool = true, isLiveDrag: Bool) {
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
            applyGradientToSelectedShapesOptimized(isLiveDrag: isLiveDrag)
        }
    }
    
    /// Optimized origin Y update with live drag support
    private func updateGradientOriginYOptimized(_ newY: Double, applyToShapes: Bool = true, isLiveDrag: Bool) {
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
            applyGradientToSelectedShapesOptimized(isLiveDrag: isLiveDrag)
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
        
        // Save to undo stack before making changes
        document.saveToUndoStack()
        
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
        
        // Save to undo stack before making changes
        document.saveToUndoStack()
        
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
        applyGradientToSelectedShapesOptimized(isLiveDrag: false)
    }
    
    /// Optimized gradient application with option to skip expensive operations during live dragging
    func applyGradientToSelectedShapesOptimized(isLiveDrag: Bool) {
        guard let gradient = currentGradient else { return }
        
        // REFACTORED: Use unified objects system for gradient application
        var hasChanges = false
        
        // Apply gradient to selected objects from unified system
        for objectID in document.selectedObjectIDs {
            if let unifiedObject = document.unifiedObjects.first(where: { $0.id == objectID }) {
                switch unifiedObject.objectType {
                case .shape(let shape):
                    // Find the shape in the layers array and update it
                    if let layerIndex = unifiedObject.layerIndex < document.layers.count ? unifiedObject.layerIndex : nil,
                       let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shape.id }) {
                        
                        // Apply gradient based on active color target (fill or stroke)
                        switch document.activeColorTarget {
                        case .fill:
                            document.layers[layerIndex].shapes[shapeIndex].fillStyle = FillStyle(gradient: gradient, opacity: 1.0)
                            Log.fileOperation("🎨 GRADIENT PANEL: Applied fill gradient to shape \(shape.id.uuidString.prefix(8)) (liveDrag: \(isLiveDrag))", level: .info)
                        case .stroke:
                            document.layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(gradient: gradient, width: document.defaultStrokeWidth, placement: document.defaultStrokePlacement, lineCap: document.defaultStrokeLineCap, lineJoin: document.defaultStrokeLineJoin, miterLimit: document.defaultStrokeMiterLimit, opacity: 1.0)
                            Log.fileOperation("🎨 GRADIENT PANEL: Applied stroke gradient to shape \(shape.id.uuidString.prefix(8)) (liveDrag: \(isLiveDrag))", level: .info)
                        }
                        hasChanges = true
                    }
                    
                case .text:
                    // Note: Text objects don't support gradients directly
                    // Could implement gradient text rendering in the future
                    Log.fileOperation("🎨 GRADIENT PANEL: Text objects don't support gradients yet", level: .info)
                }
            }
        }
        
        // Sync unified objects if we made changes
        if hasChanges {
            if isLiveDrag {
                // OPTIMIZED: During live drag, update only the specific shapes in unified objects for targeted rendering
                for objectID in document.selectedObjectIDs {
                    if let unifiedIndex = document.unifiedObjects.firstIndex(where: { $0.id == objectID }) {
                        if case .shape(let unifiedShape) = document.unifiedObjects[unifiedIndex].objectType {
                            // Find the updated shape in layers
                            if let layerIndex = document.unifiedObjects[unifiedIndex].layerIndex < document.layers.count ? document.unifiedObjects[unifiedIndex].layerIndex : nil,
                               let updatedShape = document.layers[layerIndex].shapes.first(where: { $0.id == unifiedShape.id }) {
                                // Update the specific unified object with the new shape data
                                document.unifiedObjects[unifiedIndex] = VectorObject(shape: updatedShape, layerIndex: layerIndex, orderID: document.unifiedObjects[unifiedIndex].orderID)
                            }
                        }
                    }
                }
                
                // Force immediate UI update for visual responsiveness
                document.objectWillChange.send()
            } else {
                // FULL UPDATE: On completion, do full sync for consistency
                document.syncUnifiedObjectsAfterPropertyChange()
                DispatchQueue.main.async {
                    self.document.objectWillChange.send()
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
        
        Log.fileOperation("🎨 GRADIENT PANEL: Added gradient to swatches", level: .info)
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










// MARK: - Preview
struct GradientPanel_Previews: PreviewProvider {
    static var previews: some View {
        GradientPanel(document: VectorDocument())
            .frame(width: 300, height: 600)
    }
}

