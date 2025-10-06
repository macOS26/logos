//
//  GradientPreviewAndStopsView.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 9/1/25.
//

import SwiftUI

// MARK: - Gradient Preview and Color Stops View

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
    // NEW: Optimized versions for live dragging
    let updateOriginXOptimized: (Double, Bool, Bool) -> Void
    let updateOriginYOptimized: (Double, Bool, Bool) -> Void
    let addColorStop: () -> Void
    let updateStopPosition: (UUID, Double) -> Void
    let updateStopOpacity: (UUID, Double) -> Void
    let removeColorStop: (UUID) -> Void
    let applyGradientToSelectedShapes: () -> Void
    let applyGradientToSelectedShapesOptimized: (Bool) -> Void
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
                        // For CartesianGrid clicks, use normal (non-live drag) version
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
                        // OPTIMIZED: Use live drag optimized versions for smooth performance
                        updateOriginXOptimized(normalizedX, true, true)
                        updateOriginYOptimized(normalizedY, true, true)
                    }
                    .onEnded { _ in
                        // OPTIMIZATION: Do full sync after drag completes
                        applyGradientToSelectedShapesOptimized(false)
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
                // For tap gestures, use normal (non-live drag) version
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
                        .buttonStyle(BorderlessButtonStyle())
                    }
                    
                    // Memoize gradient stops calculation for performance
                    let stops = currentGradient.map { getGradientStops($0).sorted { $0.position < $1.position } } ?? []
                    ForEach(stops, id: \.id) { stop in
                        HStack(spacing: 8) {
                            Button(action: {
                                // Always activate the clicked gradient stop, even if it was already set
                                activateGradientStop(stop.id, stop.color)
                            }) {
                                renderColorSwatchRightPanel(stop.color, width: 20, height: 20, cornerRadius: 0, borderWidth: 1, opacity: stop.opacity)
                            }
                            .buttonStyle(BorderlessButtonStyle())
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
                                    .controlSize(.regular)
                                    
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
                                .buttonStyle(BorderlessButtonStyle())
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
