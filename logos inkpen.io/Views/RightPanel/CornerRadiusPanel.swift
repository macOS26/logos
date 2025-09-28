//
//  CornerRadiusPanel.swift
//  logos inkpen.io
//
//  Professional Corner Radius Panel for Rounded Rectangle Editing
//

import SwiftUI
import Combine

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
            .buttonStyle(BorderlessButtonStyle())
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
        .buttonStyle(BorderlessButtonStyle())
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
        if let layerIndex = document.selectedLayerIndex {
            let shapes = document.getShapesForLayer(layerIndex)
            if let shapeIndex = shapes.firstIndex(where: { $0.id == selectedShape.id }),
               let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {
            var updatedRadii = shape.cornerRadii
            
            // Ensure array has enough elements
            while updatedRadii.count <= index {
                updatedRadii.append(0.0)
            }
            
            updatedRadii[index] = max(0.0, value) // Ensure non-negative
            
            // Regenerate path from current bounds + new radii
            let currentBounds = shape.path.cgPath.boundingBox
            let newPath = GeometricShapes.createRoundedRectPathWithIndividualCorners(
                rect: currentBounds,
                cornerRadii: updatedRadii
            )
            
            // Use unified helper to update shape
            document.updateShapeCornerRadiiInUnified(id: selectedShape.id, cornerRadii: updatedRadii, path: newPath)
            }
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
    
    
    
    private func getSelectedRoundedRectangle() -> VectorShape? {
        guard let layerIndex = document.selectedLayerIndex,
              let firstSelectedID = document.selectedShapeIDs.first else {
            return nil
        }
        
        let shapes = document.getShapesForLayer(layerIndex)
        guard let shape = shapes.first(where: { $0.id == firstSelectedID }) else {
            return nil
        }
        
        // Only show panel for shapes with corner radii
        return shape.cornerRadii.count > 0 ? shape : nil
    }
    

}

// MARK: - Preview
struct CornerRadiusPanel_Previews: PreviewProvider {
    static var previews: some View {
        CornerRadiusPanel(document: VectorDocument())
            .frame(width: 280, height: 400)
    }
} 
