//
//  ColorPanel.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

struct ColorPanel: View {
    @ObservedObject var document: VectorDocument
    @State private var searchText = ""
    @State private var showingPantoneSearch = false
    @State private var currentPreviewColor: VectorColor = .black // Shared color state
    let onColorSelected: ((VectorColor) -> Void)?
    
    init(document: VectorDocument, onColorSelected: ((VectorColor) -> Void)? = nil) {
        self.document = document
        self.onColorSelected = onColorSelected
        self._currentPreviewColor = State(initialValue: document.defaultFillColor)
    }
    
    var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                Text("Color")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                
            // Color Mode Picker
            VStack(alignment: .leading, spacing: 4) {
                Text("Color Mode")
                        .font(.caption)
                        .foregroundColor(.secondary)
                
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
                HSBInputSection(document: document, sharedColor: $currentPreviewColor)
                    .padding(.horizontal, 12)
            } else if document.settings.colorMode == .cmyk {
                CMYKInputSection(document: document, sharedColor: $currentPreviewColor)
                        .padding(.horizontal, 12)
            } else if document.settings.colorMode == .rgb {
                RGBInputSection(document: document, sharedColor: $currentPreviewColor)
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
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(30), spacing: 4), count: 8), spacing: 4) {
                                    ForEach(Array(filteredColors.enumerated()), id: \.offset) { index, color in
                    Button {
                        selectColor(color)
                        // Update preview color when swatch is clicked
                        currentPreviewColor = color
                    } label: {
                        ZStack {
                            renderColorSwatchRightPanel(color, width: 32, height: 32, cornerRadius: 0, borderWidth: 1)
                            
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
        // If we have a callback, just use it (we're in a modal for specific purpose)
        if let onColorSelected = onColorSelected {
            onColorSelected(color)
        } else {
            // REMOVED: Default color setting logic is disabled
            
            // Apply to selected objects based on modifier keys
            if !document.selectedShapeIDs.isEmpty {
                // Apply to shapes - CODE REMOVED: All shape color application is disabled
                // The entire shape color selection logic is commented out
                document.saveToUndoStack()

            }
            
            if !document.selectedTextIDs.isEmpty {
                // Apply to text
                if !document.selectedShapeIDs.isEmpty {
                    // Don't save to undo stack twice
                } else {
                    document.saveToUndoStack()
                }
                
                for textID in document.selectedTextIDs {
                    if let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) {
                        document.textObjects[textIndex].typography.fillColor = color
                    }
                }
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
