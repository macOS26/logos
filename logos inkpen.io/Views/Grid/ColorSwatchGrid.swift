//
//  ColorSwatchGrid.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation
import SwiftUI

struct ColorSwatchGrid: View {
    @ObservedObject var document: VectorDocument
    @Environment(AppState.self) private var appState
    @State private var selectedFillColor: VectorColor = .white
    @State private var selectedStrokeColor: VectorColor = .black
    @State private var showingColorPicker = false
    
    let columns = [
        GridItem(.fixed(10), spacing: 1),
        GridItem(.fixed(10), spacing: 1),
        GridItem(.fixed(10), spacing: 1),
        GridItem(.fixed(10), spacing: 1)
    ]
    
    // FIXED: Show current colors from text OR shapes
    private var currentFillColor: VectorColor {
        // PRIORITY 1: If text objects are selected, show their fill color
        if let firstSelectedTextID = document.selectedTextIDs.first,
           let textObject = document.textObjects.first(where: { $0.id == firstSelectedTextID }) {
            return textObject.typography.fillColor
        }
        
        // PRIORITY 2: If shapes are selected, show their color
        if let layerIndex = document.selectedLayerIndex,
           let firstSelectedID = document.selectedShapeIDs.first,
           let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }),
           let fillStyle = shape.fillStyle {
            // FIXED: Show the actual gradient, not default color
            return fillStyle.color
        }
        
        // PRIORITY 3: Show default color for new shapes
        return document.defaultFillColor
    }
    
    // FIXED: Show current colors from text OR shapes  
    private var currentStrokeColor: VectorColor {
        // PRIORITY 1: If text objects are selected, show their stroke color
        if let firstSelectedTextID = document.selectedTextIDs.first,
           let textObject = document.textObjects.first(where: { $0.id == firstSelectedTextID }) {
            return textObject.typography.strokeColor
        }
        
        // PRIORITY 2: If shapes are selected, show their color
        if let layerIndex = document.selectedLayerIndex,
           let firstSelectedID = document.selectedShapeIDs.first,
           let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }),
           let strokeColor = shape.strokeStyle?.color {
            return strokeColor
        }
        
        // PRIORITY 3: Show default color for new shapes
        return document.defaultStrokeColor
    }
    
    // Get current fill opacity (from text OR shapes)
    private var currentFillOpacity: Double {
        // PRIORITY 1: If text objects are selected, show their fill opacity
        if let firstSelectedTextID = document.selectedTextIDs.first,
           let textObject = document.textObjects.first(where: { $0.id == firstSelectedTextID }) {
            return textObject.typography.fillOpacity
        }
        
        // PRIORITY 2: If shapes are selected, show their opacity
        if let layerIndex = document.selectedLayerIndex,
           let firstSelectedID = document.selectedShapeIDs.first,
           let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }),
           let opacity = shape.fillStyle?.opacity {
            return opacity
        }
        
        // PRIORITY 3: Show default opacity
        return document.defaultFillOpacity
    }
    
    // Get current stroke opacity (from text OR shapes)
    private var currentStrokeOpacity: Double {
        // PRIORITY 1: If text objects are selected, show their stroke opacity
        if let firstSelectedTextID = document.selectedTextIDs.first,
           let textObject = document.textObjects.first(where: { $0.id == firstSelectedTextID }) {
            return textObject.typography.strokeOpacity
        }
        
        // PRIORITY 2: If shapes are selected, show their opacity
        if let layerIndex = document.selectedLayerIndex,
           let firstSelectedID = document.selectedShapeIDs.first,
           let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }),
           let opacity = shape.strokeStyle?.opacity {
            return opacity
        }
        return document.defaultStrokeOpacity
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Current Fill and Stroke Colors - Professional Style (overlapping squares)
            ZStack {
                // Stroke color (background, bottom-right)
                Button {
                    document.activeColorTarget = .stroke
                } label: {
                    if case .clear = currentStrokeColor {
                        ZStack {
                            // Checkerboard pattern for clear color
                            CheckerboardPattern(size: 4)
                                .frame(width: 22, height: 22)
                                .clipped()
	                            
	                            Rectangle()
	                                .fill(Color.clear)
	                                .frame(width: 22, height: 22)
                            
                            // Selected overlay: 3pt black overprint + 3pt white screen on top (same size)
                            if document.activeColorTarget == .stroke {
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.black.opacity(0.35), lineWidth: 2)
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
                            }

                            Path { path in
                                path.move(to: CGPoint(x: 0, y: 0))
                                path.addLine(to: CGPoint(x: 22, y: 22))
                            }
                            .stroke(Color.red, lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                        }
                    } else if case .gradient(let gradient) = currentStrokeColor {
                        // Handle gradient colors with NSView-based rendering
                        ZStack {
                            GradientSwatchNSView(gradient: gradient, size: 22)
                                .frame(width: 22, height: 22)

                            // Selected overlay: 3pt black overprint + 3pt white screen on top (same size)
                            if document.activeColorTarget == .stroke {
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.black.opacity(0.35), lineWidth: 2)
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
                            }
                        }
                    } else {
                        ZStack {
                            Rectangle()
                                .fill(currentStrokeColor.color.opacity(currentStrokeOpacity))
                                .frame(width: 22, height: 22)

                            // Selected overlay: 3pt black overprint + 3pt white screen on top (same size)
                            if document.activeColorTarget == .stroke {
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.black.opacity(0.35), lineWidth: 2)
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
                            }
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .focusable(false)
                .help("Current Stroke Color: \(currentStrokeColor) (Opacity: \(Int(currentStrokeOpacity * 100))%) - Click to make active")
                .offset(x: 6, y: 6)  // Bottom-right offset
                // Fill color (foreground, top-left)
                Button {
                    document.activeColorTarget = .fill
                } label: {
                    if case .clear = currentFillColor {
                        ZStack {
                            // Checkerboard pattern for clear color
                            CheckerboardPattern(size: 4)
                                .frame(width: 22, height: 22)
                                .clipped()
	                            
	                            Rectangle()
	                                .fill(Color.clear)
	                                .frame(width: 22, height: 22)
                            
                            // Selected overlay: 3pt black overprint + 3pt white screen on top (same size)
                            if document.activeColorTarget == .fill {
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.black.opacity(0.35), lineWidth: 2)
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
                            }

                            Path { path in
                                path.move(to: CGPoint(x: 0, y: 0))
                                path.addLine(to: CGPoint(x: 22, y: 22))
                            }
                            .stroke(Color.red, lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                        }
                    } else if case .gradient(let gradient) = currentFillColor {
                        // Handle gradient colors with NSView-based rendering
                        ZStack {
                            GradientSwatchNSView(gradient: gradient, size: 22)
                                .frame(width: 22, height: 22)

                            // Selected overlay: 3pt black overprint + 3pt white screen on top (same size)
                            if document.activeColorTarget == .fill {
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.black.opacity(0.35), lineWidth: 2)
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
                            }
                        }
                    } else {
                        ZStack {
                            Rectangle()
                                .fill(currentFillColor.color.opacity(currentFillOpacity))
                                .frame(width: 22, height: 22)

                            // Selected overlay: 3pt black overprint + 3pt white screen on top (same size)
                            if document.activeColorTarget == .fill {
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.black.opacity(0.35), lineWidth: 2)
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
                            }
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .focusable(false)
                .help("Current Fill Color: \(currentFillColor) (Opacity: \(Int(currentFillOpacity * 100))%) - Click to make active")
                .offset(x: -6, y: -6)  // Top-left offset
            }
			.frame(width: 28, height: 28)  // Total frame to contain both squares
            .padding(.bottom, 6)
            .padding(.top, 8)

            // Color Swatches
            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(Array(document.currentSwatches.enumerated()), id: \.offset) { index, color in
                    Button {
                        // Apply color to the currently active target (fill or stroke)
                        if document.activeColorTarget == .stroke {
                            selectedStrokeColor = color
                            document.defaultStrokeColor = color  // Set default for new shapes
                            applyStrokeColorToSelected(color)
                            Log.fileOperation("🎨 TOOLBAR: Set stroke color: \(color) (active target)", level: .info)
                            
                            // INK panel auto-updates from document bindings
                        } else {
                            selectedFillColor = color
                            document.defaultFillColor = color  // Set default for new shapes
                            applyFillColorToSelected(color)
                            Log.fileOperation("🎨 TOOLBAR: Set fill color: \(color) (active target)", level: .info)
                            
                            // INK panel auto-updates from document bindings
                        }
                    } label: {
                        ZStack {
                            // Base color (checkerboard for clear, normal color for others)
                            if case .clear = color {
                                ZStack {
                                    // Checkerboard pattern for clear color
                                    CheckerboardPattern(size: 2)
                                        .frame(width: 10, height: 10)
                                        .clipped()
                                    
                                    Rectangle()
                                        .fill(Color.clear)
                                        .frame(width: 10, height: 10)
                                        .border(Color.gray, width: 0.5)
                                    
                                    // Red slash overlay for clear color
                                    Path { path in
                                        path.move(to: CGPoint(x: 0, y: 0))
                                        path.addLine(to: CGPoint(x: 10, y: 10))
                                    }
                                    .stroke(Color.red, lineWidth: 1)
                                    .frame(width: 10, height: 10)
                                }
                            } else if case .gradient(let gradient) = color {
                                // Handle gradient colors with NSView-based rendering
                                GradientSwatchNSView(gradient: gradient, size: 10)
                                    .frame(width: 10, height: 10)
                                    .border(Color.gray, width: 0.5)
                            } else {
                                Rectangle()
                                    .fill(color.color)
                                    .frame(width: 10, height: 10)
                                    .border(Color.gray, width: 0.5)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("\(colorDescription(for: color)) (Click to apply to \(document.activeColorTarget == .fill ? "fill" : "stroke"))")
                }
            }
            .padding(.horizontal, 2)
            
            // Add Color Button
            Button {
                // Show persistent Ink HUD (Ink Color Mixer)
                appState.persistentInkHUD.show(document: document)
            } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Add Custom Color")
            // HUD handles color selection and swatch additions; no sheet here
        }
    }
    
    private func applyFillColorToSelected(_ color: VectorColor) {
        // Apply to selected shapes
        if let layerIndex = document.selectedLayerIndex, !document.selectedShapeIDs.isEmpty {
            document.saveToUndoStack()
            
            for shapeID in document.selectedShapeIDs {
                if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                    if document.layers[layerIndex].shapes[shapeIndex].fillStyle == nil {
                        document.layers[layerIndex].shapes[shapeIndex].fillStyle = FillStyle(color: color)
                    } else {
                        document.layers[layerIndex].shapes[shapeIndex].fillStyle?.color = color
                    }
                }
            }
        }
        
        // FIXED: Also apply to selected text objects - SAME LOGIC AS STROKE
        if !document.selectedTextIDs.isEmpty {
            if !document.selectedShapeIDs.isEmpty {
                // Don't save to undo stack twice
            } else {
                document.saveToUndoStack()
            }
            
            for textID in document.selectedTextIDs {
                if let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) {
                    // MATCH STROKE LOGIC: Always ensure fill is active when setting fill color
                    document.textObjects[textIndex].typography.fillColor = color
                    document.textObjects[textIndex].typography.fillOpacity = document.defaultFillOpacity
                    document.textObjects[textIndex].updateBounds()

                }
            }
            document.objectWillChange.send()
        }
    }
    
    private func applyStrokeColorToSelected(_ color: VectorColor) {
        // Apply to selected shapes
        if let layerIndex = document.selectedLayerIndex, !document.selectedShapeIDs.isEmpty {
            document.saveToUndoStack()
            
            for shapeID in document.selectedShapeIDs {
                if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                    if document.layers[layerIndex].shapes[shapeIndex].strokeStyle == nil {
                        document.layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(color: color, width: document.defaultStrokeWidth, placement: document.defaultStrokePlacement, lineCap: document.defaultStrokeLineCap, lineJoin: document.defaultStrokeLineJoin, miterLimit: document.defaultStrokeMiterLimit, opacity: document.defaultStrokeOpacity)
                    } else {
                        document.layers[layerIndex].shapes[shapeIndex].strokeStyle?.color = color
                    }
                }
            }
        }
        
        // FIXED: Also apply to selected text objects
        if !document.selectedTextIDs.isEmpty {
            if !document.selectedShapeIDs.isEmpty {
                // Don't save to undo stack twice
            } else {
                document.saveToUndoStack()
            }
            
            for textID in document.selectedTextIDs {
                if let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) {
                    document.textObjects[textIndex].typography.hasStroke = true
                    document.textObjects[textIndex].typography.strokeColor = color
                    document.textObjects[textIndex].typography.strokeOpacity = document.defaultStrokeOpacity
                    document.textObjects[textIndex].updateBounds()
                }
            }
            document.objectWillChange.send()
        }
    }
    
    private func colorDescription(for color: VectorColor) -> String {
        switch color {
        case .black: return "Black"
        case .white: return "White"
        case .clear: return "Clear"
        case .rgb(let rgb): return "RGB(\(Int(rgb.red * 255)), \(Int(rgb.green * 255)), \(Int(rgb.blue * 255)))"
        case .cmyk(let cmyk): return "CMYK(\(Int((cmyk.cyan * 100).isFinite ? cmyk.cyan * 100 : 0))%, \(Int((cmyk.magenta * 100).isFinite ? cmyk.magenta * 100 : 0))%, \(Int((cmyk.yellow * 100).isFinite ? cmyk.yellow * 100 : 0))%, \(Int((cmyk.black * 100).isFinite ? cmyk.black * 100 : 0))%)"
        case .hsb(let hsb): return "HSB(\(Int(hsb.hue))°, \(Int(hsb.saturation * 100))%, \(Int(hsb.brightness * 100))%)"
        case .pantone(let pantone): return "Pantone \(pantone.pantone)"
        case .spot(let spot): return "SPOT \(spot.number)"
        case .appleSystem(let systemColor): return "Apple \(systemColor.name.capitalized)"
        case .gradient(let gradient): 
            switch gradient {
            case .linear(_): return "Linear Gradient"
            case .radial(_): return "Radial Gradient"
            }
        }
    }
}
