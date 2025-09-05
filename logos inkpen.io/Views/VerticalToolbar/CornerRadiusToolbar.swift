//
//  CornerRadiusToolbar.swift
//  logos inkpen.io
//
//  Compact Corner Radius Display for Top Toolbar
//

import SwiftUI

struct CornerRadiusToolbar: View {
    @ObservedObject var document: VectorDocument
    @State private var cornerValues: [Double] = []
    @State private var cornerCount: Int = 0
    
    var body: some View {
        Group {
            if let shape = getSelectedShape(), isRectangleShape(shape) && cornerCount == 4 {
                cornerRadiusDisplay
            }
        }
        .onAppear {
            updateCornerValues()
        }
        .onChange(of: document.selectedShapeIDs) { _, _ in
            updateCornerValues()
        }
        .onChange(of: document.layers) { _, _ in
            updateCornerValues()  // Update when any layer changes
        }
        .onReceive(document.objectWillChange) { _ in
            updateCornerValues()  // Update when document changes
        }
    }
    
    @ViewBuilder
    private var cornerRadiusDisplay: some View {
        HStack(spacing: 4) {
            // Shape type indicator
            Image(systemName: shapeIcon)
                .foregroundColor(Color.ui.secondaryText)
                .font(.caption)
            
            // Corner radius fields based on corner count
            cornerFieldsView
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.ui.controlBackground)
        .cornerRadius(6)
    }
    
    @ViewBuilder
    private var cornerFieldsView: some View {
        // Only show for 3 or 4 sided shapes, single line format
        if cornerCount == 4 {
            HStack(spacing: 4) {
                ForEach(0..<cornerCount, id: \.self) { index in
                    cornerField(index: index, label: "\(index + 1)")
                }
            }
        }
    }
    
    @ViewBuilder
    private func cornerField(index: Int, label: String) -> some View {
        let isRounded = getSelectedShape().map { isCornerRounded(shape: $0, cornerIndex: index) } ?? false
        let cornerValue = cornerValues[safe: index] ?? 0.0
        
        HStack(spacing: 2) {
            // Label with rounded indicator
            HStack(spacing: 1) {
                Text(label + ":")
                    .font(.caption)
                    .foregroundColor(Color.ui.secondaryText)
                
                // Visual indicator for rounded corner
                if isRounded && cornerValue > 0 {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 4))
                        .foregroundColor(Color.ui.primaryBlue)
                } else {
                    Image(systemName: "square.fill")
                        .font(.system(size: 4))
                        .foregroundColor(Color.ui.standardBorder)
                }
            }
            
            // Value field - always editable (WHOLE NUMBERS)
            TextField("0", text: Binding(
                get: {
                    // LIVE VALUES: Always get fresh value from the actual shape (WHOLE NUMBERS)
                    if let shape = getSelectedShape() {
                        let currentRadius = shape.cornerRadii[safe: index] ?? 0.0
                        return String(format: "%.0f", currentRadius)
                    }
                    return "0"
                },
                set: { newValue in
                    if let value = Double(newValue) {
                        updateCornerRadius(index: index, value: max(0, value))
                    }
                }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(width: 50)
            .font(.caption)
            .background(isRounded && (getSelectedShape()?.cornerRadii[safe: index] ?? 0.0) > 0 ? Color.blue.opacity(0.05) : Color.clear)
        }
    }
    
    private var shapeIcon: String {
        switch cornerCount {
        case 3: return "triangle"
        case 4: return "rectangle"
        case 5: return "pentagon"
        case 6: return "hexagon"
        default: return "circle"
        }
    }
    
    private func updateCornerValues() {
        guard let selectedShape = getSelectedShape() else {
            cornerValues = []
            cornerCount = 0
            return
        }
        
        // Count corners by analyzing path elements
        cornerCount = countShapeCorners(shape: selectedShape)
        
        // Get corner radii (extend array if needed)
        let currentRadii = selectedShape.cornerRadii
        cornerValues = Array(0..<cornerCount).map { index in
            currentRadii[safe: index] ?? 0.0
        }
    }
    
    private func countShapeCorners(shape: VectorShape) -> Int {
        // ROBUST DETECTION: Support basic shapes as requested
        let shapeName = shape.name.lowercased()
        
        // Check shape name first (most reliable) - FIXED: Better matching
        if shapeName.contains("triangle") {
            return 3
        } else if shapeName == "rectangle" || shapeName == "square" || 
                  shapeName == "rounded rectangle" || shapeName == "pill" {
            return 4
        }
        
        // Fallback: Count path segments for basic shapes only
        let elements = shape.path.elements
        var lineCount = 0
        var curveCount = 0
        
        for element in elements {
            switch element {
            case .move, .close:
                break
            case .line:
                lineCount += 1
            case .curve, .quadCurve:
                curveCount += 1
            }
        }
        
        let totalSegments = lineCount + curveCount
        
        // BASIC SHAPE DETECTION BY PATH STRUCTURE:
        if totalSegments == 3 {
            return 3
        } else if totalSegments == 4 {
            return 4
        } else if totalSegments == 8 && curveCount == 4 {
            return 4
        } else if curveCount == 4 && lineCount == 0 {
            return 4
        }
        
        return 0  // Unsupported shape
    }
    
    private func getSelectedShape() -> VectorShape? {
        guard document.selectedShapeIDs.count == 1 else { return nil }
        
        let selectedID = document.selectedShapeIDs.first!
        for layer in document.layers {
            if let shape = layer.shapes.first(where: { $0.id == selectedID }) {
                return shape
            }
        }
        return nil
    }
    
    /// Detect if a specific corner is rounded by analyzing path structure
    private func isCornerRounded(shape: VectorShape, cornerIndex: Int) -> Bool {
        let elements = shape.path.elements
        var lineSegments: [PathElement] = []
        var curves: [PathElement] = []
        
        // Collect all line and curve elements
        for element in elements {
            switch element {
            case .line:
                lineSegments.append(element)
            case .curve, .quadCurve:
                curves.append(element)
            case .move, .close:
                break
            }
        }
        
        // For a rounded rectangle, we expect:
        // - 4 line segments (sides)
        // - 4 curve segments (corners)
        // Corner N is rounded if there's a corresponding curve element
        

        
        // If we have the same number of curves as corners, then corner at index is rounded
        if curves.count == cornerCount && cornerIndex < curves.count {
            return true
        }
        
        // If no curves, all corners are sharp
        if curves.count == 0 {
            return false
        }
        
        // For partial rounding, check corner radius values
        let radius = shape.cornerRadii[safe: cornerIndex] ?? 0.0
        return radius > 0.0
    }
    
    private func updateCornerRadius(index: Int, value: Double) {
        guard let selectedShape = getSelectedShape() else { return }
        
        document.saveToUndoStack()
        
        // Find and update the shape
        for layerIndex in document.layers.indices {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == selectedShape.id }) {
                var shape = document.layers[layerIndex].shapes[shapeIndex]
                
                // ENABLE CORNER RADIUS SUPPORT: Convert regular rectangles to corner-radius-enabled rectangles
                if !shape.isRoundedRectangle && isRectangleShape(shape) {
                    Log.fileOperation("🔄 Converting regular rectangle to corner-radius-enabled rectangle", level: .info)
                    
                    // Calculate original bounds from current path
                    let pathBounds = shape.path.cgPath.boundingBox
                    shape.originalBounds = pathBounds
                    shape.isRoundedRectangle = true
                    
                    // Initialize corner radii if empty
                    if shape.cornerRadii.isEmpty {
                        shape.cornerRadii = [0.0, 0.0, 0.0, 0.0]
                    }
                }
                
                // Update corner radii array
                var updatedRadii = shape.cornerRadii
                
                // Extend array if needed
                while updatedRadii.count <= index {
                    updatedRadii.append(0.0)
                }
                updatedRadii[index] = value
                
                shape.cornerRadii = updatedRadii
                
                // Regenerate path with corner radius using current bounds
                let currentBounds = shape.path.cgPath.boundingBox
                let newPath = GeometricShapes.createRoundedRectPathWithIndividualCorners(
                    rect: currentBounds,
                    cornerRadii: updatedRadii
                )
                
                // Use unified helper to update shape
                document.updateShapeCornerRadiiInUnified(id: shape.id, cornerRadii: updatedRadii, path: newPath)
                
                print("🔄 Updated corner \(index + 1) radius to \(String(format: "%.1f", value))pt")
                break
            }
        }
        
        document.objectWillChange.send()
        updateCornerValues()
    }
    
    /// Check if a shape is a rectangle-based shape
    private func isRectangleShape(_ shape: VectorShape) -> Bool {
        let shapeName = shape.name.lowercased()
        return shapeName == "rectangle" || shapeName == "square" ||
               shapeName == "rounded rectangle" || shapeName == "pill"
    }
}

// MARK: - Preview
#Preview {
    CornerRadiusToolbar(document: VectorDocument())
        .padding()
}