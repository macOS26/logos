//
//  ColorPanel.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

struct ColorPanel: View {
    @ObservedObject var document: VectorDocument
    @Environment(AppState.self) private var appState
    @State private var searchText = ""
    @State private var showingPantoneSearch = false
    @State private var currentPreviewColor: VectorColor = .black // Shared color state
    let onColorSelected: ((VectorColor) -> Void)?
    let showGradientEditing: Bool // New parameter to control gradient editing display
    
    init(document: VectorDocument, onColorSelected: ((VectorColor) -> Void)? = nil, showGradientEditing: Bool = false) {
        self.document = document
        self.onColorSelected = onColorSelected
        self.showGradientEditing = showGradientEditing
        self._currentPreviewColor = State(initialValue: document.defaultFillColor)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Top padding for the color view
            Spacer()
                .frame(height: 8)
            // GRADIENT EDITING INDICATOR - Only show when explicitly enabled
            if showGradientEditing, let gradientState = appState.gradientEditingState {
                HStack {
                    Image(systemName: "circle.fill")
                        .foregroundColor(.blue)
                    Text("Editing Gradient Stop \(gradientState.stopIndex + 1)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Spacer()
                    Text("ID: \(gradientState.gradientId.uuidString.prefix(8))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fontDesign(.monospaced)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .padding(.horizontal, 12)
            }
            
            // Color Mode Picker
            VStack(alignment: .leading, spacing: 4) {
                Picker("Color Mode", selection: Binding(
                    get: { document.settings.colorMode },
                    set: { newMode in
                        let oldMode = document.settings.colorMode
                        document.settings.colorMode = newMode
                        
                        // Convert current preview color to new mode
                        currentPreviewColor = convertColorToMode(currentPreviewColor, from: oldMode, to: newMode)
                        
                        document.updateColorSwatchesForMode()
                    }
                )) {
                    ForEach(ColorMode.allCases, id: \.self) { mode in
                        HStack {
                            Image(systemName: mode.iconName)
                            Text(mode.rawValue)
                        }
                        .tag(mode)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .font(.caption)
            }
            .padding(.horizontal, 12)
            
            // Mode-specific input sections
            if document.settings.colorMode == .pms {
                HSBInputSection(document: document, sharedColor: $currentPreviewColor, onColorSelected: onColorSelected, showGradientEditing: showGradientEditing)
                    .padding(.horizontal, 12)
            } else if document.settings.colorMode == .cmyk {
                CMYKInputSection(document: document, sharedColor: $currentPreviewColor, onColorSelected: onColorSelected, showGradientEditing: showGradientEditing)
                        .padding(.horizontal, 12)
            } else if document.settings.colorMode == .rgb {
                RGBInputSection(document: document, sharedColor: $currentPreviewColor, onColorSelected: onColorSelected, showGradientEditing: showGradientEditing)
                        .padding(.horizontal, 12)
            }
                
            // Color Mode Specific Information
            HStack {
                Text(colorModeDescription)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            
            // Color Swatches
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(28), spacing: 4), count: 8), spacing: 4) {
                                    ForEach(Array(filteredColors.enumerated()), id: \.offset) { index, color in
                    Button {
                        selectColor(color)
                        // Update preview color when swatch is clicked
                        currentPreviewColor = color
                    } label: {
                        ZStack {
                            renderColorSwatchRightPanel(color, width: 30, height: 30, cornerRadius: 0, borderWidth: 1)
                            
                            // Show Pantone number for Pantone colors (if not clear)
                            if case .pantone = color {
                                overlayText(for: color)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(colorDescription(for: color))
                    .contextMenu {
                        Button("Delete Swatch") {
                            document.removeColorSwatch(color)
                        }
                    }
                    }
                }
                .padding(.horizontal, 12)
            }
            

            
            Spacer()
        }
        .sheet(isPresented: $showingPantoneSearch) {
            PantoneColorPickerSheet(document: document)
        }
        .onAppear {
            // Initialize preview to match the active target's current color
            currentPreviewColor = (document.activeColorTarget == .stroke) ? document.defaultStrokeColor : document.defaultFillColor
        }
        // React to document color changes without any notifications
        .onChange(of: document.activeColorTarget) { _, newTarget in
            currentPreviewColor = (newTarget == .stroke) ? document.defaultStrokeColor : document.defaultFillColor
        }
        .onChange(of: document.defaultFillColor) { _, newFill in
            if document.activeColorTarget == .fill {
                currentPreviewColor = newFill
            }
        }
        .onChange(of: document.defaultStrokeColor) { _, newStroke in
            if document.activeColorTarget == .stroke {
                currentPreviewColor = newStroke
            }
        }
    }
    
    // MARK: - Helper Properties and Methods
    
    private var colorModeDescription: String {
        switch document.settings.colorMode {
        case .rgb:
            return "RGB colors for screen display"
        case .cmyk:
            return "CMYK colors for print production"
        case .pms:
            return "PMS colors with Pantone matching"
        }
    }
    
    private var filteredColors: [VectorColor] {
        if searchText.isEmpty {
            return document.currentSwatches
        } else {
            return document.currentSwatches.filter { color in
                colorDescription(for: color).localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private func selectColor(_ color: VectorColor) {
        print("🎨 COLOR PANEL: selectColor called with: \(color)")
        print("🎨 COLOR PANEL: showGradientEditing = \(showGradientEditing)")
        print("🎨 COLOR PANEL: Gradient editing state: \(appState.gradientEditingState != nil)")
        print("🎨 COLOR PANEL: activeColorTarget = \(document.activeColorTarget)")
        
        // If we have a specific callback, use it (we're in a modal for specific purpose)
        if let onColorSelected = onColorSelected {
            print("🎨 COLOR PANEL: Using onColorSelected callback (fill/stroke mode)")
            onColorSelected(color)
        } else {
            // 🔥 FIXED: Apply color to active target when browsing colors in the Color tab
            // This makes the Color Panel behave consistently with the VerticalToolbar
            print("🎨 COLOR PANEL: Applying color to active target: \(document.activeColorTarget)")
            
            // 🔥 CRITICAL FIX: Update the preview color in the INK panel
            currentPreviewColor = color
            
            // Apply color to the currently active target (fill or stroke)
            if document.activeColorTarget == .stroke {
                // Set default stroke color for new shapes
                document.defaultStrokeColor = color
                print("🎨 COLOR PANEL: Set stroke color: \(color) (active target)")
                
                // Apply to selected shapes
                applyStrokeColorToSelected(color)
            } else {
                // Set default fill color for new shapes  
                document.defaultFillColor = color
                print("🎨 COLOR PANEL: Set fill color: \(color) (active target)")
                
                // Apply to selected shapes
                applyFillColorToSelected(color)
            }
        }
    }
    

    
    private func colorDescription(for color: VectorColor) -> String {
        switch color {
        case .black: return "Black"
        case .white: return "White"
        case .clear: return "Clear"
        case .rgb(let rgb): 
            return "RGB(\(Int(rgb.red * 255)), \(Int(rgb.green * 255)), \(Int(rgb.blue * 255)))"
        case .cmyk(let cmyk): 
            return "CMYK(\(Int((cmyk.cyan * 100).isFinite ? cmyk.cyan * 100 : 0))%, \(Int((cmyk.magenta * 100).isFinite ? cmyk.magenta * 100 : 0))%, \(Int((cmyk.yellow * 100).isFinite ? cmyk.yellow * 100 : 0))%, \(Int((cmyk.black * 100).isFinite ? cmyk.black * 100 : 0))%)"
        case .hsb(let hsb):
            return "HSB(\(Int(hsb.hue))°, \(Int(hsb.saturation * 100))%, \(Int(hsb.brightness * 100))%)"
        case .pantone(let pantone): 
            return "PANTONE \(pantone.pantone) - \(pantone.name)"
        case .spot(let spot):
            return "SPOT \(spot.number) - \(spot.name)"
        case .appleSystem(let systemColor): 
            return "Apple \(systemColor.name.capitalized)"
        case .gradient(let gradient): 
            switch gradient {
            case .linear(_): return "Linear Gradient"
            case .radial(_): return "Radial Gradient"
            }
        }
    }
    
    // MARK: - Helper Functions for Color Application
    
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
        
        // Also apply to selected text objects
        if !document.selectedTextIDs.isEmpty {
            if !document.selectedShapeIDs.isEmpty {
                // Don't save to undo stack twice
            } else {
                document.saveToUndoStack()
            }
            
            for textID in document.selectedTextIDs {
                if let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) {
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
                        document.layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(color: color, width: document.defaultStrokeWidth, lineCap: document.defaultStrokeLineCap, lineJoin: document.defaultStrokeLineJoin, miterLimit: document.defaultStrokeMiterLimit, opacity: document.defaultStrokeOpacity)
                    } else {
                        document.layers[layerIndex].shapes[shapeIndex].strokeStyle?.color = color
                    }
                }
            }
        }
        
        // Also apply to selected text objects
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
    
    @ViewBuilder
    private func overlayText(for color: VectorColor) -> some View {
        if case .pantone(let pantone) = color {
            Text(pantone.pantone)
                .font(.system(size: 7, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: .black, radius: 1, x: 0, y: 0)
                .lineLimit(3)
                .minimumScaleFactor(0.5)
                .multilineTextAlignment(.center)
                .frame(width: 30, height: 30)
                .allowsTightening(true)
        }
    }
    
    // MARK: - Color Mode Conversion
    
    // Convert a color to a different color mode
    private func convertColorToMode(_ color: VectorColor, from oldMode: ColorMode, to newMode: ColorMode) -> VectorColor {
        if oldMode == newMode {
            return color
        }
        
        // RGB to CMYK conversion
        if oldMode == .rgb && newMode == .cmyk {
            switch color {
            case .rgb(let rgbColor):
                let cmykColor = ColorManagement.rgbToCMYK(rgbColor)
                return .cmyk(cmykColor)
            case .cmyk:
                return color // Already in CMYK
            case .hsb(let hsb):
                let cmykColor = ColorManagement.rgbToCMYK(hsb.rgbColor)
                return .cmyk(cmykColor)
            case .pantone(let pantone):
                return .cmyk(pantone.cmykEquivalent)
            case .spot(let spot):
                return .cmyk(spot.cmykEquivalent)
            case .appleSystem(let system):
                let cmykColor = ColorManagement.rgbToCMYK(system.rgbEquivalent)
                return .cmyk(cmykColor)
            case .gradient:
                return color // Gradients cannot be converted to simple color modes
            case .clear:
                return .clear
            case .black:
                return .cmyk(CMYKColor(cyan: 0, magenta: 0, yellow: 0, black: 1))
            case .white:
                return .cmyk(CMYKColor(cyan: 0, magenta: 0, yellow: 0, black: 0))
            }
        }
        
        // CMYK to RGB conversion
        if oldMode == .cmyk && newMode == .rgb {
            switch color {
            case .cmyk(let cmykColor):
                let rgbColor = cmykColor.rgbColor
                return .rgb(rgbColor)
            case .rgb:
                return color // Already in RGB
            case .hsb(let hsb):
                return .rgb(hsb.rgbColor)
            case .pantone(let pantone):
                return .rgb(pantone.rgbEquivalent)
            case .spot(let spot):
                return .rgb(spot.rgbEquivalent)
            case .appleSystem:
                return color // Already has RGB representation
            case .gradient:
                return color // Gradients cannot be converted to simple color modes
            case .clear:
                return .clear
            case .black:
                return .rgb(RGBColor(red: 0, green: 0, blue: 0))
            case .white:
                return .rgb(RGBColor(red: 1, green: 1, blue: 1))
            }
        }
        
        // PMS conversions (HSB-based)
        if newMode == .pms {
            switch color {
            case .hsb:
                return color // Already in HSB
            case .rgb(let rgb):
                return .hsb(HSBColorModel.fromRGB(rgb))
            case .cmyk(let cmyk):
                return .hsb(HSBColorModel.fromRGB(cmyk.rgbColor))
            case .pantone(let pantone):
                return .hsb(HSBColorModel.fromRGB(pantone.rgbEquivalent))
            case .spot(let spot):
                return .hsb(spot.hsbEquivalent)
            case .appleSystem(let system):
                return .hsb(HSBColorModel.fromRGB(system.rgbEquivalent))
            case .gradient:
                return color // Gradients cannot be converted to simple color modes
            case .clear:
                return .hsb(HSBColorModel(hue: 0, saturation: 0, brightness: 1, alpha: 0))
            case .black:
                return .hsb(HSBColorModel(hue: 0, saturation: 0, brightness: 0))
            case .white:
                return .hsb(HSBColorModel(hue: 0, saturation: 0, brightness: 1))
            }
        }
        
        // For now, other conversions (to/from SPOT) just return the color
        return color
    }
} 
