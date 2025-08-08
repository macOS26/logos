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
            if cornerCount == 3 || cornerCount == 4 {
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
        if cornerCount == 3 || cornerCount == 4 {
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
                    print("🔄 Converting regular rectangle to corner-radius-enabled rectangle")
                    
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
                
                // FIXED: Handle skewed shapes by using actual corner points instead of bounding box
                let newPath: VectorPath
                
                if isShapeSkewed(shape) {
                    // For skewed shapes, create path from actual corner points
                    let cornerPoints = getActualCornerPoints(from: shape)
                    newPath = createRoundedPathFromCorners(
                        cornerPoints: cornerPoints,
                        cornerRadii: updatedRadii
                    )
                } else {
                    // For regular shapes, use original bounds approach
                    if let originalBounds = shape.originalBounds {
                        newPath = GeometricShapes.createRoundedRectPathWithIndividualCorners(
                            rect: originalBounds,
                            cornerRadii: updatedRadii
                        )
                    } else {
                        // Fallback to current bounds
                        let currentBounds = shape.path.cgPath.boundingBox
                        newPath = GeometricShapes.createRoundedRectPathWithIndividualCorners(
                            rect: currentBounds,
                            cornerRadii: updatedRadii
                        )
                    }
                }
                shape.path = newPath
                shape.updateBounds()
                
                // Update the shape in the document
                document.layers[layerIndex].shapes[shapeIndex] = shape
                
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
    
    /// Check if a shape is skewed (not a regular rectangle)
    private func isShapeSkewed(_ shape: VectorShape) -> Bool {
        guard !shape.transform.isIdentity else { return false }
        
        // Check if the transform has skew/shear components
        let transform = shape.transform
        let hasSkew = abs(transform.c) > 0.01 || abs(transform.b) > 0.01
        
        return hasSkew
    }
    
    /// Extract actual corner points from a shape path (handles skewed shapes)
    private func getActualCornerPoints(from shape: VectorShape) -> [CGPoint] {
        let path = shape.path.cgPath
        
        // For skewed shapes, we need to extract the actual corner points from the path
        // This is more complex than using bounding box corners
        var cornerPoints: [CGPoint] = []
        
        // Try to extract corner points from the path elements
        path.applyWithBlock { element in
            let points = element.pointee.points
            
            switch element.pointee.type {
            case .moveToPoint:
                if cornerPoints.isEmpty {
                    cornerPoints.append(points[0])
                }
            case .addLineToPoint:
                // For rectangles, line segments connect corners
                if cornerPoints.count < 4 {
                    cornerPoints.append(points[0])
                }
            case .addCurveToPoint:
                // For rounded rectangles, curve endpoints are corner points
                if cornerPoints.count < 4 {
                    cornerPoints.append(points[2]) // End point of curve
                }
            default:
                break
            }
        }
        
        // If we couldn't extract enough points, fall back to bounding box corners
        if cornerPoints.count < 4 {
            let bounds = path.boundingBox
            cornerPoints = [
                CGPoint(x: bounds.minX, y: bounds.minY), // Top-left
                CGPoint(x: bounds.maxX, y: bounds.minY), // Top-right
                CGPoint(x: bounds.maxX, y: bounds.maxY), // Bottom-right
                CGPoint(x: bounds.minX, y: bounds.maxY)  // Bottom-left
            ]
        }
        
        // Apply transform if present
        if !shape.transform.isIdentity {
            cornerPoints = cornerPoints.map { $0.applying(shape.transform) }
        }
        
        return cornerPoints
    }
    
    /// Create a rounded path from actual corner points (for skewed shapes)
    private func createRoundedPathFromCorners(cornerPoints: [CGPoint], cornerRadii: [Double]) -> VectorPath {
        guard cornerPoints.count >= 4 else {
            // Fallback to rectangle if not enough points
            let bounds = CGRect(
                x: cornerPoints.first?.x ?? 0,
                y: cornerPoints.first?.y ?? 0,
                width: 100,
                height: 100
            )
            return GeometricShapes.createRoundedRectPathWithIndividualCorners(rect: bounds, cornerRadii: cornerRadii)
        }
        
        // Ensure we have exactly 4 corner radii
        var radii = cornerRadii
        while radii.count < 4 {
            radii.append(0.0)
        }
        if radii.count > 4 {
            radii = Array(radii.prefix(4))
        }
        
        // Extract the 4 corner points in order: TL, TR, BR, BL
        let tl = cornerPoints[0] // Top-left
        let tr = cornerPoints[1] // Top-right
        let br = cornerPoints[2] // Bottom-right
        let bl = cornerPoints[3] // Bottom-left
        
        // Calculate edge vectors for each side
        let topEdge = CGVector(dx: tr.x - tl.x, dy: tr.y - tl.y)
        let rightEdge = CGVector(dx: br.x - tr.x, dy: br.y - tr.y)
        let bottomEdge = CGVector(dx: bl.x - br.x, dy: bl.y - br.y)
        let leftEdge = CGVector(dx: tl.x - bl.x, dy: tl.y - bl.y)
        
        // Calculate edge lengths for radius clamping
        let topLength = sqrt(topEdge.dx * topEdge.dx + topEdge.dy * topEdge.dy)
        let rightLength = sqrt(rightEdge.dx * rightEdge.dx + rightEdge.dy * rightEdge.dy)
        let bottomLength = sqrt(bottomEdge.dx * bottomEdge.dx + bottomEdge.dy * bottomEdge.dy)
        let leftLength = sqrt(leftEdge.dx * leftEdge.dx + leftEdge.dy * leftEdge.dy)
        
        // Clamp radii to half the shortest adjacent edge
        let clampedRadii = [
            min(radii[0], min(leftLength, topLength) / 2), // Top-left
            min(radii[1], min(topLength, rightLength) / 2), // Top-right
            min(radii[2], min(rightLength, bottomLength) / 2), // Bottom-right
            min(radii[3], min(bottomLength, leftLength) / 2) // Bottom-left
        ]
        
        // Create path elements
        var elements: [PathElement] = []
        
        // Start at top-left corner (after radius)
        if clampedRadii[0] > 0 {
            // Move to start of top-left curve
            let tlCurveStart = CGPoint(
                x: tl.x + clampedRadii[0] * topEdge.dx / topLength,
                y: tl.y + clampedRadii[0] * topEdge.dy / topLength
            )
            elements.append(.move(to: VectorPoint(tlCurveStart.x, tlCurveStart.y)))
        } else {
            elements.append(.move(to: VectorPoint(tl.x, tl.y)))
        }
        
        // Top edge
        if clampedRadii[1] > 0 {
            // Line to start of top-right curve
            let trCurveStart = CGPoint(
                x: tr.x - clampedRadii[1] * topEdge.dx / topLength,
                y: tr.y - clampedRadii[1] * topEdge.dy / topLength
            )
            elements.append(.line(to: VectorPoint(trCurveStart.x, trCurveStart.y)))
            
            // Top-right curve
            let trControl1 = CGPoint(
                x: trCurveStart.x + clampedRadii[1] * 0.552 * topEdge.dx / topLength,
                y: trCurveStart.y + clampedRadii[1] * 0.552 * topEdge.dy / topLength
            )
            let trControl2 = CGPoint(
                x: tr.x - clampedRadii[1] * 0.552 * rightEdge.dx / rightLength,
                y: tr.y - clampedRadii[1] * 0.552 * rightEdge.dy / rightLength
            )
            let trCurveEnd = CGPoint(
                x: tr.x + clampedRadii[1] * rightEdge.dx / rightLength,
                y: tr.y + clampedRadii[1] * rightEdge.dy / rightLength
            )
            elements.append(.curve(
                to: VectorPoint(trCurveEnd.x, trCurveEnd.y),
                control1: VectorPoint(trControl1.x, trControl1.y),
                control2: VectorPoint(trControl2.x, trControl2.y)
            ))
        } else {
            elements.append(.line(to: VectorPoint(tr.x, tr.y)))
        }
        
        // Right edge
        if clampedRadii[2] > 0 {
            // Line to start of bottom-right curve
            let brCurveStart = CGPoint(
                x: br.x - clampedRadii[2] * rightEdge.dx / rightLength,
                y: br.y - clampedRadii[2] * rightEdge.dy / rightLength
            )
            elements.append(.line(to: VectorPoint(brCurveStart.x, brCurveStart.y)))
            
            // Bottom-right curve
            let brControl1 = CGPoint(
                x: brCurveStart.x - clampedRadii[2] * 0.552 * rightEdge.dx / rightLength,
                y: brCurveStart.y - clampedRadii[2] * 0.552 * rightEdge.dy / rightLength
            )
            let brControl2 = CGPoint(
                x: br.x - clampedRadii[2] * 0.552 * bottomEdge.dx / bottomLength,
                y: br.y - clampedRadii[2] * 0.552 * bottomEdge.dy / bottomLength
            )
            let brCurveEnd = CGPoint(
                x: br.x - clampedRadii[2] * bottomEdge.dx / bottomLength,
                y: br.y - clampedRadii[2] * bottomEdge.dy / bottomLength
            )
            elements.append(.curve(
                to: VectorPoint(brCurveEnd.x, brCurveEnd.y),
                control1: VectorPoint(brControl1.x, brControl1.y),
                control2: VectorPoint(brControl2.x, brControl2.y)
            ))
        } else {
            elements.append(.line(to: VectorPoint(br.x, br.y)))
        }
        
        // Bottom edge
        if clampedRadii[3] > 0 {
            // Line to start of bottom-left curve
            let blCurveStart = CGPoint(
                x: bl.x + clampedRadii[3] * bottomEdge.dx / bottomLength,
                y: bl.y + clampedRadii[3] * bottomEdge.dy / bottomLength
            )
            elements.append(.line(to: VectorPoint(blCurveStart.x, blCurveStart.y)))
            
            // Bottom-left curve
            let blControl1 = CGPoint(
                x: blCurveStart.x - clampedRadii[3] * 0.552 * bottomEdge.dx / bottomLength,
                y: blCurveStart.y - clampedRadii[3] * 0.552 * bottomEdge.dy / bottomLength
            )
            let blControl2 = CGPoint(
                x: bl.x - clampedRadii[3] * 0.552 * leftEdge.dx / leftLength,
                y: bl.y - clampedRadii[3] * 0.552 * leftEdge.dy / leftLength
            )
            let blCurveEnd = CGPoint(
                x: bl.x - clampedRadii[3] * leftEdge.dx / leftLength,
                y: bl.y - clampedRadii[3] * leftEdge.dy / leftLength
            )
            elements.append(.curve(
                to: VectorPoint(blCurveEnd.x, blCurveEnd.y),
                control1: VectorPoint(blControl1.x, blControl1.y),
                control2: VectorPoint(blControl2.x, blControl2.y)
            ))
        } else {
            elements.append(.line(to: VectorPoint(bl.x, bl.y)))
        }
        
        // Left edge and close
        if clampedRadii[0] > 0 {
            // Line to start of top-left curve
            let tlCurveStart = CGPoint(
                x: tl.x + clampedRadii[0] * leftEdge.dx / leftLength,
                y: tl.y + clampedRadii[0] * leftEdge.dy / leftLength
            )
            elements.append(.line(to: VectorPoint(tlCurveStart.x, tlCurveStart.y)))
            
            // Top-left curve to close
            let tlControl1 = CGPoint(
                x: tlCurveStart.x + clampedRadii[0] * 0.552 * leftEdge.dx / leftLength,
                y: tlCurveStart.y + clampedRadii[0] * 0.552 * leftEdge.dy / leftLength
            )
            let tlControl2 = CGPoint(
                x: tl.x + clampedRadii[0] * 0.552 * topEdge.dx / topLength,
                y: tl.y + clampedRadii[0] * 0.552 * topEdge.dy / topLength
            )
            let tlCurveEnd = CGPoint(
                x: tl.x + clampedRadii[0] * topEdge.dx / topLength,
                y: tl.y + clampedRadii[0] * topEdge.dy / topLength
            )
            elements.append(.curve(
                to: VectorPoint(tlCurveEnd.x, tlCurveEnd.y),
                control1: VectorPoint(tlControl1.x, tlControl1.y),
                control2: VectorPoint(tlControl2.x, tlControl2.y)
            ))
        } else {
            elements.append(.line(to: VectorPoint(tl.x, tl.y)))
        }
        
        return VectorPath(elements: elements, isClosed: true)
    }
}

// MARK: - Preview
#Preview {
    CornerRadiusToolbar(document: VectorDocument())
        .padding()
}