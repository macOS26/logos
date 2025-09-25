//
//  ColorSwatchGrid.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

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
    
    // REFACTORED: Use unified objects system for current fill color
    private var currentFillColor: VectorColor {
        // Get the first selected object from unified system
        if let firstSelectedObjectID = document.selectedObjectIDs.first,
           let unifiedObject = document.unifiedObjects.first(where: { $0.id == firstSelectedObjectID }) {
            switch unifiedObject.objectType {
            case .shape(let shape):
                if let fillStyle = shape.fillStyle {
                    return fillStyle.color
                }
            }
        }
        
        // Show default color for new shapes
        return document.defaultFillColor
    }
    
    // REFACTORED: Use unified objects system for current stroke color
    private var currentStrokeColor: VectorColor {
        // Get the first selected object from unified system
        if let firstSelectedObjectID = document.selectedObjectIDs.first,
           let unifiedObject = document.unifiedObjects.first(where: { $0.id == firstSelectedObjectID }) {
            switch unifiedObject.objectType {
            case .shape(let shape):
                if let strokeStyle = shape.strokeStyle {
                    return strokeStyle.color
                } else {
                    return .clear  // Show clear/none when no stroke exists
                }
            }
        }
        
        // Show default color for new shapes
        return document.defaultStrokeColor
    }
    
    // REFACTORED: Use unified objects system for current fill opacity
    private var currentFillOpacity: Double {
        // Get the first selected object from unified system
        if let firstSelectedObjectID = document.selectedObjectIDs.first,
           let unifiedObject = document.unifiedObjects.first(where: { $0.id == firstSelectedObjectID }) {
            switch unifiedObject.objectType {
            case .shape(let shape):
                if let fillStyle = shape.fillStyle {
                    return fillStyle.opacity
                }
            }
        }
        
        // Show default opacity
        return document.defaultFillOpacity
    }
    
    // REFACTORED: Use unified objects system for current stroke opacity
    private var currentStrokeOpacity: Double {
        // Get the first selected object from unified system
        if let firstSelectedObjectID = document.selectedObjectIDs.first,
           let unifiedObject = document.unifiedObjects.first(where: { $0.id == firstSelectedObjectID }) {
            switch unifiedObject.objectType {
            case .shape(let shape):
                if let strokeStyle = shape.strokeStyle {
                    return strokeStyle.opacity
                }
            }
        }
        
        // Show default opacity
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
                .buttonStyle(BorderlessButtonStyle())
                .focusable(false)
                .help("Current Stroke Color (Opacity: \(Int(currentStrokeOpacity * 100))%) - Click to make active")
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
                .buttonStyle(BorderlessButtonStyle())
                .focusable(false)
                .help("Current Fill Color (Opacity: \(Int(currentFillOpacity * 100))%) - Click to make active")
                .offset(x: -6, y: -6)  // Top-left offset
            }
			.frame(width: 28, height: 28)  // Total frame to contain both squares
            .padding(.bottom, 6)
            .padding(.top, 8)

            // Color Swatches
            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(Array(document.currentSwatches.enumerated()), id: \.offset) { index, color in
                    Button {
                        // CRITICAL FIX: Apply color to the currently active target using setActiveColor (like working ColorPanel)
                        if document.activeColorTarget == .stroke {
                            selectedStrokeColor = color
                            document.defaultStrokeColor = color  // Set default for new shapes
                            // CRITICAL FIX: Use setActiveColor to handle text objects properly
                            document.setActiveColor(color)
                            Log.fileOperation("🎨 TOOLBAR: Set stroke color: \(color) (active target)", level: .debug)
                            
                            // INK panel auto-updates from document bindings
                        } else {
                            selectedFillColor = color
                            document.defaultFillColor = color  // Set default for new shapes
                            // CRITICAL FIX: Use setActiveColor to handle text objects properly
                            document.setActiveColor(color)
                            Log.fileOperation("🎨 TOOLBAR: Set fill color: \(color) (active target)", level: .debug)
                            
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
                    .buttonStyle(BorderlessButtonStyle())
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
            .buttonStyle(BorderlessButtonStyle())
            .help("Add Custom Color")
            // HUD handles color selection and swatch additions; no sheet here
        }
    }
    
    private func applyFillColorToSelected(_ color: VectorColor) {
        // CRITICAL FIX: Use unified selection system
        var hasChanges = false
        
        // Apply to selected objects from unified system
        for objectID in document.selectedObjectIDs {
            if let unifiedObject = document.unifiedObjects.first(where: { $0.id == objectID }) {
                switch unifiedObject.objectType {
                case .shape(let shape):
                    // UNIFIED HELPER: Use unified system helper instead of direct manipulation
                    if !shape.isTextObject {
                        document.updateShapeFillColorInUnified(id: shape.id, color: color)
                        hasChanges = true
                    }
                    
                        // MIGRATED: Use unified object system to update text fill color
                    if document.allTextObjects.contains(where: { $0.id == shape.id }) {
                        document.updateTextFillColorInUnified(id: shape.id, color: color)
                        hasChanges = true
                    }
                }
            }
        }
        
        // Save to undo stack and optimize sync if we made changes
        if hasChanges {
            document.saveToUndoStack()
            document.updateUnifiedObjectsOptimized()
        }
    }
    
    private func applyStrokeColorToSelected(_ color: VectorColor) {
        // CRITICAL FIX: Use unified selection system
        var hasChanges = false
        
        // Apply to selected objects from unified system
        for objectID in document.selectedObjectIDs {
            if let unifiedObject = document.unifiedObjects.first(where: { $0.id == objectID }) {
                switch unifiedObject.objectType {
                case .shape(let shape):
                    // UNIFIED HELPER: Use unified system helper instead of direct manipulation  
                    if !shape.isTextObject {
                        document.updateShapeStrokeColorInUnified(id: shape.id, color: color)
                        hasChanges = true
                    }
                    
                        // MIGRATION: Use unified helper instead of direct assignment
                        document.updateTextStrokeColorInUnified(id: shape.id, color: color)
                        hasChanges = true
                }
            }
        }
        
        // Save to undo stack and optimize sync if we made changes
        if hasChanges {
            document.saveToUndoStack()
            document.updateUnifiedObjectsOptimized()
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
