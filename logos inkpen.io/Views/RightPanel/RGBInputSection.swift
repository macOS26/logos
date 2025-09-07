//
//  RGBInputSection.swift
//  logos inkpen.io
//
//  RGB input section for the color panel
//

import SwiftUI

struct RGBColorData: Hashable {
    let red: Int
    let green: Int
    let blue: Int
}

struct RGBInputSection: View {
    @ObservedObject var document: VectorDocument
    @Binding var sharedColor: VectorColor // Shared color state
    @Environment(AppState.self) private var appState
    
    // Callback indicates we're in gradient editing mode
    let onColorSelected: ((VectorColor) -> Void)?
    let showGradientEditing: Bool  // 🔥 NEW: Controls whether this section allows gradient editing
    
    @State private var redValue: String = "133"
    @State private var greenValue: String = "78" 
    @State private var blueValue: String = "68"
    @State private var hexValue: String = "854e44"
    
    // Slider values (0-255)
    @State private var redSlider: Double = 133
    @State private var greenSlider: Double = 78
    @State private var blueSlider: Double = 68
    
    // Flag to prevent automatic gradient updates during programmatic changes
    @State private var isProgrammaticallyUpdating: Bool = false
    
    // Computed color from RGB values
    private var currentColor: RGBColor {
        let r = Double(redValue) ?? 0
        let g = Double(greenValue) ?? 0
        let b = Double(blueValue) ?? 0
        
        return RGBColor(
            red: min(255, max(0, r)) / 255.0,
            green: min(255, max(0, g)) / 255.0,
            blue: min(255, max(0, b)) / 255.0,
            alpha: 1.0
        )
    }
    
    // Helper function to get SwiftUI Color from RGB values
    private func swiftUIColor(r: Double, g: Double, b: Double) -> Color {
        return Color(.sRGB, red: r/255.0, green: g/255.0, blue: b/255.0)
    }
    
    // Red slider gradient (morphs from current color with R=0 to current color with R=255)
    private var redGradient: SwiftUI.LinearGradient {
        let g = Double(greenValue) ?? 0
        let b = Double(blueValue) ?? 0
        return SwiftUI.LinearGradient(
            gradient: Gradient(colors: [
                swiftUIColor(r: 0, g: g, b: b),
                swiftUIColor(r: 255, g: g, b: b)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    // Green slider gradient (morphs from current color with G=0 to current color with G=255)
    private var greenGradient: SwiftUI.LinearGradient {
        let r = Double(redValue) ?? 0
        let b = Double(blueValue) ?? 0
        return SwiftUI.LinearGradient(
            gradient: Gradient(colors: [
                swiftUIColor(r: r, g: 0, b: b),
                swiftUIColor(r: r, g: 255, b: b)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    // Blue slider gradient (morphs from current color with B=0 to current color with B=255)
    private var blueGradient: SwiftUI.LinearGradient {
        let r = Double(redValue) ?? 0
        let g = Double(greenValue) ?? 0
        return SwiftUI.LinearGradient(
            gradient: Gradient(colors: [
                swiftUIColor(r: r, g: g, b: 0),
                swiftUIColor(r: r, g: g, b: 255)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // RGB Sliders with Native Apple Sliders and Gradients
            VStack(spacing: 8) {
                // Red Slider
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                    
                    Text("R")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 12)
                    
                    ZStack {
                        // White background for slider track
                        Capsule()
                            .fill(Color.white)
                            .frame(height: 6)
                            .overlay(
                                Capsule()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                            )
                        
                        // Native Apple Slider
                        Slider(value: $redSlider, in: 0...255)
                            .tint(Color.clear)
                            .onChange(of: redSlider) {
                                guard !isProgrammaticallyUpdating else { 
                                    // Removed logging spam
                                    return 
                                }
                                // Removed logging for performance
                                redValue = String(Int(redSlider))
                                updateHexFromRGB()
                            }
                        
                        // Gradient overlay
                        Capsule()
                            .fill(redGradient)
                            .frame(height: 6)
                            .allowsHitTesting(false)
                    }
                    
                    TextField("", text: $redValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 45)
                        .font(.system(size: 11))
                        .onChange(of: redValue) {
                            guard !isProgrammaticallyUpdating else { 
                                // Removed logging spam
                                return 
                            }
                            // Removed logging for performance
                            if let intValue = Double(redValue) {
                                redSlider = min(255, max(0, intValue))
                                updateHexFromRGB()
                            }
                        }
                }
                
                // Green Slider
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                    
                    Text("G")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 12)
                    
                    ZStack {
                        // White background for slider track
                        Capsule()
                            .fill(Color.white)
                            .frame(height: 6)
                            .overlay(
                                Capsule()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                            )
        
                        // Natve Apple Slider
                        Slider(value: $greenSlider, in: 0...255)
                            .tint(Color.clear)
                            .onChange(of: greenSlider) {
                                guard !isProgrammaticallyUpdating else { return }
                                greenValue = String(Int(greenSlider))
                                updateHexFromRGB()
                            }
                        
                        // Gradient overlay
                        Capsule()
                            .fill(greenGradient)
                            .frame(height: 6)
                            .allowsHitTesting(false)
                    }
                    
                    TextField("", text: $greenValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 45)
                        .font(.system(size: 11))
                        .onChange(of: greenValue) {
                            guard !isProgrammaticallyUpdating else { return }
                            if let intValue = Double(greenValue) {
                                greenSlider = min(255, max(0, intValue))
                                updateHexFromRGB()
                            }
                        }
                }
                
                // Blue Slider
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 12, height: 12)
                    
                    Text("B")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 12)
                    
                    ZStack {
                        // White background for slider track
                        Capsule()
                            .fill(Color.white)
                            .frame(height: 6)
                            .overlay(
                                Capsule()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                            )
                        
                        // Native Apple Slider
                        Slider(value: $blueSlider, in: 0...255)
                            .tint(Color.clear)
                            .onChange(of: blueSlider) {
                                guard !isProgrammaticallyUpdating else { return }
                                blueValue = String(Int(blueSlider))
                                updateHexFromRGB()
                            }
                        
                        // Gradient overlay
                        Capsule()
                            .fill(blueGradient)
                            .frame(height: 6)
                            .allowsHitTesting(false)
                    }
                    
                    TextField("", text: $blueValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 45)
                        .font(.system(size: 11))
                        .onChange(of: blueValue) {
                            guard !isProgrammaticallyUpdating else { return }
                            if let intValue = Double(blueValue) {
                                blueSlider = min(255, max(0, intValue))
                                updateHexFromRGB()
                            }
                        }
                }
            }
            
            // Compact Hex Input and Swatch Preview
            HStack(spacing: 8) {
                // Square Color Swatch Preview (30x30 like other swatches)
                Button(action: {
                    applyColorToActiveSelection()
                }) {
                    Rectangle()
                        .fill(Color(.sRGB, 
                            red: currentColor.red, 
                            green: currentColor.green, 
                            blue: currentColor.blue))
                        .frame(width: 30, height: 30)
                        .overlay(
                            Rectangle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .help("Click to apply color to active fill or stroke")
                
                VStack(alignment: .leading, spacing: 2) {
                    Button("Add to Swatches") {
                        addColorToSwatches()
                    }
                    .font(.system(size: 10))
                    .foregroundColor(.primary)
                }
                
                Spacer()
                
                Text("#")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                TextField("854e44", text: $hexValue)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 11))
                    .frame(width: 70)
                    .onChange(of: hexValue) {
                        updateRGBFromHex()
                    }
                
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            loadFromSharedColor()
        }
        .onChange(of: sharedColor) { _, newColor in
            loadFromSharedColor()
        }
    }
    
    private func updateHexFromRGB() {
        let r = Int(Double(redValue) ?? 0)
        let g = Int(Double(greenValue) ?? 0)
        let b = Int(Double(blueValue) ?? 0)
        hexValue = String(format: "%02x%02x%02x", r, g, b)
    }
    
    private func updateRGBFromHex() {
        let cleanHex = hexValue.replacingOccurrences(of: "#", with: "")
        if cleanHex.count == 6 {
            let scanner = Scanner(string: cleanHex)
            var hexNumber: UInt64 = 0
            
            if scanner.scanHexInt64(&hexNumber) {
                let r = Int((hexNumber & 0xff0000) >> 16)
                let g = Int((hexNumber & 0x00ff00) >> 8)
                let b = Int(hexNumber & 0x0000ff)
                
                redValue = String(r)
                greenValue = String(g)
                blueValue = String(b)
                redSlider = Double(r)
                greenSlider = Double(g)
                blueSlider = Double(b)
            }
        }
    }
    
    private func updateSharedColor() {
        let vectorColor = VectorColor.rgb(currentColor)
        // Removed excessive logging for performance
        
        sharedColor = .rgb(currentColor)
        
        // CRITICAL FIX: Don't update gradients during programmatic changes OR when just browsing
        // Only update gradients when user explicitly applies/selects colors
        if isProgrammaticallyUpdating {
            // Removed logging spam
            return
        }
        
        // 🔥 CRITICAL FIX: COMMON CODE NEVER UPDATES GRADIENT STOPS OR FILL/STROKE AUTOMATICALLY
        // The common RGB/CMYK/HSB input sections are used by BOTH:
        // 1. INK PANEL (Fill/Stroke mode) - should only update fill/stroke when swatch clicked
        // 2. GRADIENT SELECT COLOR PANEL (Gradient mode) - should only update via callbacks
        // 
        // NO automatic updates - only explicit user actions should update colors!
        
        // Update document defaults only (for preview purposes)
        switch document.activeColorTarget {
        case .fill:
            document.defaultFillColor = vectorColor
        case .stroke:
            document.defaultStrokeColor = vectorColor
        }
        
        // 🔥 NO AUTOMATIC FILL/STROKE UPDATES - only when swatches are clicked!
        
        // Priority 3: Apply color to selected objects and update document defaults
        // Update document defaults based on active color target
        switch document.activeColorTarget {
        case .fill:
            document.defaultFillColor = vectorColor
        case .stroke:
            document.defaultStrokeColor = vectorColor
        }
        
        // Apply to active shapes (regular or direct selection)
        let activeShapeIDs = document.getActiveShapeIDs()
        if !activeShapeIDs.isEmpty {
            document.saveToUndoStack()
            
            for shapeID in activeShapeIDs {
                // Find the shape across all layers
                for layerIndex in document.layers.indices {
                    let shapes = document.getShapesForLayer(layerIndex)
                    if let shapeIndex = shapes.firstIndex(where: { $0.id == shapeID }),
                       let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {
                        switch document.activeColorTarget {
                        case .fill:
                            // UNIFIED HELPER: Use unified system helper instead of direct manipulation
                            document.updateShapeFillColorInUnified(id: shape.id, color: vectorColor)
                        case .stroke:
                            // UNIFIED HELPER: Use unified system helper instead of direct manipulation
                            document.updateShapeStrokeColorInUnified(id: shape.id, color: vectorColor)
                        }
                        break // Found the shape, no need to check other layers
                    }
                }
            }
        }
        
        // OPTIMIZED: Update unified objects directly during live color changes
        if !activeShapeIDs.isEmpty {
            for shapeID in activeShapeIDs {
                // Update the specific unified object directly for targeted rendering
                if let unifiedIndex = document.unifiedObjects.firstIndex(where: { unifiedObj in
                    if case .shape(let unifiedShape) = unifiedObj.objectType {
                        return unifiedShape.id == shapeID
                    }
                    return false
                }) {
                    // Find updated shape data
                    for layerIndex in document.layers.indices {
                        let shapes = document.getShapesForLayer(layerIndex)
                        if let shapeIndex = shapes.firstIndex(where: { $0.id == shapeID }),
                           let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {
                            document.unifiedObjects[unifiedIndex] = VectorObject(shape: shape, layerIndex: layerIndex, orderID: document.unifiedObjects[unifiedIndex].orderID)
                            break
                        }
                    }
                }
            }
        }
        
        // Force immediate UI update for visual responsiveness
        document.objectWillChange.send()
        
        // 🔥 NO AUTOMATIC TEXT UPDATES - only when swatches are clicked!
        
        // Log.fileOperation("🎨 RGB INPUT: Updated \(document.activeColorTarget) color: \(vectorColor)", level: .info)
    }
    
    private func loadFromSharedColor() {
        // Removed excessive logging for performance
        
        switch sharedColor {
        case .rgb(let rgb):
            setRGBValues(
                red: Int(rgb.red * 255),
                green: Int(rgb.green * 255),
                blue: Int(rgb.blue * 255)
            )
        case .cmyk(let cmyk):
            let rgb = cmyk.rgbColor
            setRGBValues(
                red: Int(rgb.red * 255),
                green: Int(rgb.green * 255),
                blue: Int(rgb.blue * 255)
            )
        case .hsb(let hsb):
            let rgb = hsb.rgbColor
            setRGBValues(
                red: Int(rgb.red * 255),
                green: Int(rgb.green * 255),
                blue: Int(rgb.blue * 255)
            )
        case .pantone(let pantone):
            let rgb = pantone.rgbEquivalent
            setRGBValues(
                red: Int(rgb.red * 255),
                green: Int(rgb.green * 255),
                blue: Int(rgb.blue * 255)
            )
        case .spot(let spot):
            let rgb = spot.rgbEquivalent
            setRGBValues(
                red: Int(rgb.red * 255),
                green: Int(rgb.green * 255),
                blue: Int(rgb.blue * 255)
            )
        case .appleSystem(let system):
            let rgb = system.rgbEquivalent
            setRGBValues(
                red: Int(rgb.red * 255),
                green: Int(rgb.green * 255),
                blue: Int(rgb.blue * 255)
            )
        case .gradient(let gradient):
            // For gradients, use the first stop color as representative  
            if let firstStop = gradient.stops.first {
                switch firstStop.color {
                case .rgb(let rgb):
                    setRGBValues(
                        red: Int(rgb.red * 255),
                        green: Int(rgb.green * 255),
                        blue: Int(rgb.blue * 255)
                    )
                default:
                    // Convert any other color type to RGB for display
                    let swiftUIColor = firstStop.color.color
                    let components = swiftUIColor.components
                    setRGBValues(
                        red: Int(components.red * 255),
                        green: Int(components.green * 255),
                        blue: Int(components.blue * 255)
                    )
                }
            } else {
                setRGBValues(red: 0, green: 0, blue: 0)
            }
        case .clear:
            // For clear colors, we don't update RGB values since they're not applicable
            // The clear color should be handled separately
            return
        case .black:
            setRGBValues(red: 0, green: 0, blue: 0)
        case .white:
            setRGBValues(red: 255, green: 255, blue: 255)
        }
    }
    
    private func setRGBValues(red: Int, green: Int, blue: Int) {
        // Removed excessive logging for performance
        
        isProgrammaticallyUpdating = true
        redValue = String(red)
        greenValue = String(green)
        blueValue = String(blue)
        redSlider = Double(red)
        greenSlider = Double(green)
        blueSlider = Double(blue)
        updateHexFromRGB()
        isProgrammaticallyUpdating = false
        
        // Removed excessive logging for performance
    }
    
    private func applyColorToActiveSelection() {
        let vectorColor = VectorColor.rgb(currentColor)
        
        // Log.fileOperation("🎨 RGB INPUT: applyColorToActiveSelection called", level: .info)
        // Log.fileOperation("🎨 RGB INPUT: showGradientEditing = \(showGradientEditing)", level: .info)
        // Log.fileOperation("🎨 RGB INPUT: Gradient editing state: \(appState.gradientEditingState != nil)", level: .info)
        
        // 🔥 CRITICAL FIX: Only use gradient callback if THIS section allows gradient editing
        // Priority 1: If we're in gradient editing mode AND this section supports it, use gradient callback
        if showGradientEditing, let gradientCallback = appState.gradientEditingState?.onColorSelected {
            // Log.fileOperation("🎨 RGB INPUT: Using gradient callback (gradient mode section)", level: .info)
            gradientCallback(vectorColor)
            return
        }
        
        // Priority 2: Otherwise, apply to document's active selection
        // Log.fileOperation("🎨 RGB INPUT: Using document setActiveColor (fill/stroke mode)", level: .info)
        document.setActiveColor(vectorColor)
    }
    
    private func addColorToSwatches() {
        let vectorColor = VectorColor.rgb(currentColor)
        document.addColorToSwatches(vectorColor)
    }
}

#Preview {
    RGBInputSection(document: VectorDocument(), sharedColor: .constant(.black), onColorSelected: nil, showGradientEditing: false)
        .padding()
        .environment(AppState.shared)
}
