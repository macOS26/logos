//
//  CMYKInputSection.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

// MARK: - Professional CMYK Input Section

struct CMYKInputSection: View {
    @ObservedObject var document: VectorDocument
    @Binding var sharedColor: VectorColor // Shared color state
    @Environment(AppState.self) private var appState
    
    // Callback indicates we're in gradient editing mode
    let onColorSelected: ((VectorColor) -> Void)?
    let showGradientEditing: Bool  // 🔥 NEW: Controls whether this section allows gradient editing
    
    @State private var cyanValue: String = "0"
    @State private var magentaValue: String = "0"
    @State private var yellowValue: String = "0"
    @State private var blackValue: String = "0"
    
    // Slider values (0-100)
    @State private var cyanSlider: Double = 0
    @State private var magentaSlider: Double = 0
    @State private var yellowSlider: Double = 0
    @State private var blackSlider: Double = 0
    
    // Flag to prevent automatic gradient updates during programmatic changes
    @State private var isProgrammaticallyUpdating: Bool = false
    
    // Computed color from CMYK values
    private var currentColor: CMYKColor {
        let c = (Double(cyanValue) ?? 0) / 100.0
        let m = (Double(magentaValue) ?? 0) / 100.0
        let y = (Double(yellowValue) ?? 0) / 100.0
        let k = (Double(blackValue) ?? 0) / 100.0
        
        return CMYKColor(
            cyan: max(0, min(1, c)),
            magenta: max(0, min(1, m)),
            yellow: max(0, min(1, y)),
            black: max(0, min(1, k))
        )
    }
    
    // Helper function to get SwiftUI Color from CMYK values
    private func swiftUIColorFromCMYK(c: Double, m: Double, y: Double, k: Double) -> Color {
        let cmykColor = CMYKColor(cyan: c/100.0, magenta: m/100.0, yellow: y/100.0, black: k/100.0)
        return cmykColor.color
    }
    
    // Cyan slider gradient (morphs from current color with C=0 to current color with C=100)
    private var cyanGradient: SwiftUI.LinearGradient {
        let m = Double(magentaValue) ?? 0
        let y = Double(yellowValue) ?? 0
        let k = Double(blackValue) ?? 0
        return SwiftUI.LinearGradient(
            gradient: Gradient(colors: [
                swiftUIColorFromCMYK(c: 0, m: m, y: y, k: k),
                swiftUIColorFromCMYK(c: 100, m: m, y: y, k: k)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    // Magenta slider gradient
    private var magentaGradient: SwiftUI.LinearGradient {
        let c = Double(cyanValue) ?? 0
        let y = Double(yellowValue) ?? 0
        let k = Double(blackValue) ?? 0
        return SwiftUI.LinearGradient(
            gradient: Gradient(colors: [
                swiftUIColorFromCMYK(c: c, m: 0, y: y, k: k),
                swiftUIColorFromCMYK(c: c, m: 100, y: y, k: k)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    // Yellow slider gradient
    private var yellowGradient: SwiftUI.LinearGradient {
        let c = Double(cyanValue) ?? 0
        let m = Double(magentaValue) ?? 0
        let k = Double(blackValue) ?? 0
        return SwiftUI.LinearGradient(
            gradient: Gradient(colors: [
                swiftUIColorFromCMYK(c: c, m: m, y: 0, k: k),
                swiftUIColorFromCMYK(c: c, m: m, y: 100, k: k)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    // Black slider gradient
    private var blackGradient: SwiftUI.LinearGradient {
        let c = Double(cyanValue) ?? 0
        let m = Double(magentaValue) ?? 0
        let y = Double(yellowValue) ?? 0
        return SwiftUI.LinearGradient(
            gradient: Gradient(colors: [
                swiftUIColorFromCMYK(c: c, m: m, y: y, k: 0),
                swiftUIColorFromCMYK(c: c, m: m, y: y, k: 100)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CMYK Process Colors")
                    .font(.caption)
                .fontWeight(.medium)
                    .foregroundColor(.secondary)
            
            Text("Enter process color values (0-100%)")
                .font(.caption2)
                    .foregroundColor(.secondary)
            
            // CMYK Sliders with Native Apple Sliders and Gradients
            VStack(spacing: 8) {
                // Cyan Slider
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.cyan)
                        .frame(width: 12, height: 12)
                    
                    Text("C")
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
                        Slider(value: $cyanSlider, in: 0...100)
                            .tint(Color.clear)
                            .onChange(of: cyanSlider) {
                                cyanValue = String(Int(cyanSlider))
                            }
                        
                        // Gradient overlay
                        Capsule()
                            .fill(cyanGradient)
                            .frame(height: 6)
                            .allowsHitTesting(false)
                    }
                    
                    TextField("", text: $cyanValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 45)
                        .font(.system(size: 11))
                        .onChange(of: cyanValue) {
                            guard !isProgrammaticallyUpdating else { return }
                            if let intValue = Double(cyanValue) {
                                cyanSlider = min(100, max(0, intValue))
                            }
                        }
                }
                
                // Magenta Slider
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.pink)
                        .frame(width: 12, height: 12)
                    
                    Text("M")
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
                        Slider(value: $magentaSlider, in: 0...100)
                            .tint(Color.clear)
                            .onChange(of: magentaSlider) {
                                magentaValue = String(Int(magentaSlider))
                            }
                        
                        // Gradient overlay
                        Capsule()
                            .fill(magentaGradient)
                            .frame(height: 6)
                            .allowsHitTesting(false)
                    }
                    
                    TextField("", text: $magentaValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 45)
                        .font(.system(size: 11))
                        .onChange(of: magentaValue) {
                            guard !isProgrammaticallyUpdating else { return }
                            if let intValue = Double(magentaValue) {
                                magentaSlider = min(100, max(0, intValue))
                            }
                        }
                }
                
                // Yellow Slider
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 12, height: 12)
                    
                    Text("Y")
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
                        Slider(value: $yellowSlider, in: 0...100)
                            .tint(Color.clear)
                            .onChange(of: yellowSlider) {
                                yellowValue = String(Int(yellowSlider))
                            }
                        
                        // Gradient overlay
                        Capsule()
                            .fill(yellowGradient)
                            .frame(height: 6)
                            .allowsHitTesting(false)
                    }
                    
                    TextField("", text: $yellowValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 45)
                        .font(.system(size: 11))
                        .onChange(of: yellowValue) {
                            guard !isProgrammaticallyUpdating else { return }
                            if let intValue = Double(yellowValue) {
                                yellowSlider = min(100, max(0, intValue))
                            }
                        }
                }
                
                // Black Slider
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 12, height: 12)
                    
                    Text("K")
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
                        Slider(value: $blackSlider, in: 0...100)
                            .tint(Color.clear)
                            .onChange(of: blackSlider) {
                                blackValue = String(Int(blackSlider))
                            }
                        
                        // Gradient overlay
                        Capsule()
                            .fill(blackGradient)
                            .frame(height: 6)
                            .allowsHitTesting(false)
                    }
                    
                    TextField("", text: $blackValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 45)
                        .font(.system(size: 11))
                        .onChange(of: blackValue) {
                            guard !isProgrammaticallyUpdating else { return }
                            if let intValue = Double(blackValue) {
                                blackSlider = min(100, max(0, intValue))
                            }
                        }
                }
            }
            
            // Compact Color Preview and Add Button (similar to RGB)
            HStack(spacing: 8) {
                // Square Color Swatch Preview (30x30 like RGB section)
                Button(action: {
                    applyColorToActiveSelection()
                }) {
                Rectangle()
                        .fill(currentColor.color)
                        .frame(width: 30, height: 30)
                    .overlay(
                        Rectangle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .help("Click to apply color to active fill or stroke")
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("CMYK(\(Int(currentColor.cyan * 100)), \(Int(currentColor.magenta * 100)), \(Int(currentColor.yellow * 100)), \(Int(currentColor.black * 100)))")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Button("Add to Swatches") {
                        addCMYKColorToSwatches()
                    }
                    .font(.system(size: 10))
                    .foregroundColor(.primary)
                }
                
                Spacer()
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
    
    private func updateSharedColor() {
        sharedColor = .cmyk(currentColor)
        let vectorColor = VectorColor.cmyk(currentColor)
        
        // CRITICAL FIX: Don't update gradients during programmatic changes OR when just browsing
        // Only update gradients when user explicitly applies/selects colors
        if isProgrammaticallyUpdating {
            print("🎨 CMYK INPUT: BLOCKED gradient update - programmatic change")
            return
        }
        
        // 🔥 CRITICAL FIX: Don't automatically update gradient stops when in gradient editing mode
        // This prevents unwanted gradient modifications when browsing Color Panel during gradient editing
        if showGradientEditing {
            // When in gradient editing mode, only update document defaults and active selection
            // DO NOT automatically modify gradient stops
            switch document.activeColorTarget {
            case .fill:
                document.defaultFillColor = vectorColor
            case .stroke:
                document.defaultStrokeColor = vectorColor
            }
            
            // Apply to active shapes (regular or direct selection) - but NOT gradients
            let activeShapeIDs = document.getActiveShapeIDs()
            if !activeShapeIDs.isEmpty {
                for shapeID in activeShapeIDs {
                    // Find the shape across all layers
                    for layerIndex in document.layers.indices {
                        if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                            // Only update non-gradient fills/strokes
                            switch document.activeColorTarget {
                            case .fill:
                                if let fillStyle = document.layers[layerIndex].shapes[shapeIndex].fillStyle,
                                   case .gradient = fillStyle.color {
                                    // Skip gradient fills - they should only be updated via explicit gradient callbacks
                                    continue
                                } else {
                                    if document.layers[layerIndex].shapes[shapeIndex].fillStyle == nil {
                                        document.layers[layerIndex].shapes[shapeIndex].fillStyle = FillStyle(color: vectorColor)
                                    } else {
                                        document.layers[layerIndex].shapes[shapeIndex].fillStyle?.color = vectorColor
                                    }
                                }
                            case .stroke:
                                if document.layers[layerIndex].shapes[shapeIndex].strokeStyle == nil {
                                    document.layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(color: vectorColor, width: document.defaultStrokeWidth, lineCap: document.defaultStrokeLineCap, lineJoin: document.defaultStrokeLineJoin, miterLimit: document.defaultStrokeMiterLimit, opacity: document.defaultStrokeOpacity)
                                } else {
                                    document.layers[layerIndex].shapes[shapeIndex].strokeStyle?.color = vectorColor
                                }
                            }
                            break // Found the shape, no need to check other layers
                        }
                    }
                }
            }
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
        
        // 🔥 NO AUTOMATIC TEXT UPDATES - only when swatches are clicked!
        
        print("🎨 CMYK INPUT: Updated \(document.activeColorTarget) color: \(vectorColor)")
    }
    
    private func loadFromSharedColor() {
        switch sharedColor {
        case .rgb(let rgb):
            let cmyk = ColorManagement.rgbToCMYK(rgb)
            setCMYKValues(
                cyan: Int(cmyk.cyan * 100),
                magenta: Int(cmyk.magenta * 100),
                yellow: Int(cmyk.yellow * 100),
                black: Int(cmyk.black * 100)
            )
        case .cmyk(let cmyk):
            setCMYKValues(
                cyan: Int(cmyk.cyan * 100),
                magenta: Int(cmyk.magenta * 100),
                yellow: Int(cmyk.yellow * 100),
                black: Int(cmyk.black * 100)
            )
        case .hsb(let hsb):
            let rgb = hsb.rgbColor
            let cmyk = ColorManagement.rgbToCMYK(rgb)
            setCMYKValues(
                cyan: Int(cmyk.cyan * 100),
                magenta: Int(cmyk.magenta * 100),
                yellow: Int(cmyk.yellow * 100),
                black: Int(cmyk.black * 100)
            )
        case .pantone(let pantone):
            let cmyk = pantone.cmykEquivalent
            setCMYKValues(
                cyan: Int(cmyk.cyan * 100),
                magenta: Int(cmyk.magenta * 100),
                yellow: Int(cmyk.yellow * 100),
                black: Int(cmyk.black * 100)
            )
        case .spot(let spot):
            let cmyk = spot.cmykEquivalent
            setCMYKValues(
                cyan: Int(cmyk.cyan * 100),
                magenta: Int(cmyk.magenta * 100),
                yellow: Int(cmyk.yellow * 100),
                black: Int(cmyk.black * 100)
            )
        case .appleSystem(let system):
            let rgb = system.rgbEquivalent
            let cmyk = ColorManagement.rgbToCMYK(rgb)
            setCMYKValues(
                cyan: Int(cmyk.cyan * 100),
                magenta: Int(cmyk.magenta * 100),
                yellow: Int(cmyk.yellow * 100),
                black: Int(cmyk.black * 100)
            )
        case .gradient(let gradient):
            // For gradients, use the first stop color as representative
            if let firstStop = gradient.stops.first {
                switch firstStop.color {
                case .cmyk(let cmyk):
                    setCMYKValues(
                        cyan: Int(cmyk.cyan * 100),
                        magenta: Int(cmyk.magenta * 100),
                        yellow: Int(cmyk.yellow * 100),
                        black: Int(cmyk.black * 100)
                    )
                default:
                    // Convert any other color type to CMYK for display
                    let swiftUIColor = firstStop.color.color
                    let components = swiftUIColor.components
                    let rgbColor = RGBColor(red: components.red, green: components.green, blue: components.blue, alpha: components.alpha)
                    let cmyk = ColorManagement.rgbToCMYK(rgbColor)
                    setCMYKValues(
                        cyan: Int(cmyk.cyan * 100),
                        magenta: Int(cmyk.magenta * 100),
                        yellow: Int(cmyk.yellow * 100),
                        black: Int(cmyk.black * 100)
                    )
                }
            } else {
                setCMYKValues(cyan: 0, magenta: 0, yellow: 0, black: 0)
            }
        case .clear:
            // For clear colors, we don't update CMYK values since they're not applicable
            // The clear color should be handled separately
            return
        case .black:
            setCMYKValues(cyan: 0, magenta: 0, yellow: 0, black: 100)
        case .white:
            setCMYKValues(cyan: 0, magenta: 0, yellow: 0, black: 0)
        }
    }
    
    private func setCMYKValues(cyan: Int, magenta: Int, yellow: Int, black: Int) {
        print("🎨 CMYK INPUT: setCMYKValues called with C=\(cyan), M=\(magenta), Y=\(yellow), K=\(black)")
        print("🎨 CMYK INPUT: Gradient editing state: \(appState.gradientEditingState != nil)")
        
        isProgrammaticallyUpdating = true
        cyanValue = String(cyan)
        magentaValue = String(magenta)
        yellowValue = String(yellow)
        blackValue = String(black)
        cyanSlider = Double(cyan)
        magentaSlider = Double(magenta)
        yellowSlider = Double(yellow)
        blackSlider = Double(black)
        isProgrammaticallyUpdating = false
        
        print("🎨 CMYK INPUT: setCMYKValues completed")
    }
    
    private func applyColorToActiveSelection() {
        let vectorColor = VectorColor.cmyk(currentColor)
        
        // 🔥 CRITICAL FIX: Only use gradient callback if THIS section allows gradient editing
        // Priority 1: If we're in gradient editing mode AND this section supports it, use gradient callback
        if showGradientEditing, let gradientCallback = appState.gradientEditingState?.onColorSelected {
            gradientCallback(vectorColor)
            return
        }
        
        // Priority 2: Otherwise, apply to document's active selection
        document.setActiveColor(vectorColor)
    }
    
    private func addCMYKColorToSwatches() {
        let vectorColor = VectorColor.cmyk(currentColor)
        document.addColorSwatch(vectorColor)
    }
} 