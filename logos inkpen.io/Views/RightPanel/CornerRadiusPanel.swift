//
//  CornerRadiusPanel.swift
//  logos inkpen.io
//
//  Professional Corner Radius Panel for Rounded Rectangle Editing
//

import SwiftUI

struct CornerRadiusPanel: View {
    @ObservedObject var document: VectorDocument
    @State private var cornerValues: [Double] = [0, 0, 0, 0] // TL, TR, BR, BL
    @State private var isEditing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().padding(.horizontal, 8)
            content
            Spacer()
        }
        .onAppear {
            updateCornerValues()
        }
        .onChange(of: document.selectedShapeIDs) { _, _ in
            updateCornerValues()
        }
        .onReceive(document.objectWillChange) { _ in
            // Update corner values when document changes (including during dragging)
            updateCornerValues()
        }
    }
    
    private var header: some View {
        HStack {
            Text("Corner Radius")
                .font(.headline)
                .foregroundColor(.primary)
            Spacer()
            Button(action: {
                isEditing.toggle()
            }) {
                Image(systemName: isEditing ? "checkmark" : "pencil")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(PlainButtonStyle())
            .help(isEditing ? "Apply Changes" : "Edit Corner Values")
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }
    
    private var content: some View {
        VStack(spacing: 12) {
            // Corner radius grid
            VStack(spacing: 8) {
                // Top row: TL, TR
                HStack(spacing: 8) {
                    cornerInput(label: "TL", index: 0, position: .topLeading)
                    Spacer()
                    cornerInput(label: "TR", index: 1, position: .topTrailing)
                }
                
                // Bottom row: BL, BR
                HStack(spacing: 8) {
                    cornerInput(label: "BL", index: 3, position: .bottomLeading)
                    Spacer()
                    cornerInput(label: "BR", index: 2, position: .bottomTrailing)
                }
            }
            .padding(.horizontal, 12)
            
            Divider().padding(.horizontal, 8)
            
            // Quick actions
            VStack(spacing: 8) {
                quickActionButton(title: "Make Square", action: makeSquare)
                quickActionButton(title: "Equal Corners", action: makeEqualCorners)
                quickActionButton(title: "Copy Top to Bottom", action: copyTopToBottom)
                quickActionButton(title: "Copy Left to Right", action: copyLeftToRight)
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 8)
    }
    
    private func cornerInput(label: String, index: Int, position: UnitPoint) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if isEditing {
                TextField("0", value: $cornerValues[index], format: .number)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 60)
                    .onChange(of: cornerValues[index]) { _, newValue in
                        applyCornerRadius(index: index, value: newValue)
                    }
            } else {
                Text(String(format: "%.2f", cornerValues[index]))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.primary)
                    .frame(width: 60, alignment: .center)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
            }
        }
    }
    
    private func quickActionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Actions
    
    private func updateCornerValues() {
        guard let selectedShape = getSelectedRoundedRectangle() else {
            cornerValues = [0, 0, 0, 0]
            return
        }
        
        // Get corner radii from the selected shape
        let radii = selectedShape.cornerRadii
        cornerValues = [
            radii[safe: 0] ?? 0, // Top-Left
            radii[safe: 1] ?? 0, // Top-Right
            radii[safe: 2] ?? 0, // Bottom-Right
            radii[safe: 3] ?? 0  // Bottom-Left
        ]
    }
    
    private func applyCornerRadius(index: Int, value: Double) {
        guard let selectedShape = getSelectedRoundedRectangle() else { return }
        
        document.saveToUndoStack()
        
        // Update the corner radius for the selected shape
        if let layerIndex = document.selectedLayerIndex,
           let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == selectedShape.id }) {
            
            var shape = document.layers[layerIndex].shapes[shapeIndex]
            var updatedRadii = shape.cornerRadii
            
            // Ensure array has enough elements
            while updatedRadii.count <= index {
                updatedRadii.append(0.0)
            }
            
            updatedRadii[index] = max(0.0, value) // Ensure non-negative
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
            
            document.layers[layerIndex].shapes[shapeIndex] = shape
        }
    }
    
    private func makeSquare() {
        cornerValues = [0, 0, 0, 0]
        applyAllCornerRadii()
    }
    
    private func makeEqualCorners() {
        let average = cornerValues.reduce(0, +) / Double(cornerValues.count)
        cornerValues = [average, average, average, average]
        applyAllCornerRadii()
    }
    
    private func copyTopToBottom() {
        cornerValues[2] = cornerValues[1] // BR = TR
        cornerValues[3] = cornerValues[0] // BL = TL
        applyAllCornerRadii()
    }
    
    private func copyLeftToRight() {
        cornerValues[1] = cornerValues[0] // TR = TL
        cornerValues[2] = cornerValues[3] // BR = BL
        applyAllCornerRadii()
    }
    
    private func applyAllCornerRadii() {
        for (index, value) in cornerValues.enumerated() {
            applyCornerRadius(index: index, value: value)
        }
    }
    
    // MARK: - Helper Functions
    
    private func getSelectedRoundedRectangle() -> VectorShape? {
        guard let layerIndex = document.selectedLayerIndex,
              let firstSelectedID = document.selectedShapeIDs.first,
              let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }) else {
            return nil
        }
        
        // Only show panel for shapes with corner radii
        return shape.cornerRadii.count > 0 ? shape : nil
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
struct CornerRadiusPanel_Previews: PreviewProvider {
    static var previews: some View {
        CornerRadiusPanel(document: VectorDocument())
            .frame(width: 280, height: 400)
    }
} 