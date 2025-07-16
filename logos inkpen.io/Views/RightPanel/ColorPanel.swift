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
    let onColorSelected: ((VectorColor) -> Void)?
    
    init(document: VectorDocument, onColorSelected: ((VectorColor) -> Void)? = nil) {
        self.document = document
        self.onColorSelected = onColorSelected
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
                        document.settings.colorMode = newMode
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
            if document.settings.colorMode == .pantone {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Search Pantone Colors")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        TextField("Enter Pantone number (e.g. 032 C)", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.caption)
                        
                        Button("Search") {
                            searchPantoneColor(searchText)
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    }
                }
                .padding(.horizontal, 12)
            } else if document.settings.colorMode == .cmyk {
                CMYKInputSection(document: document)
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
                    }
                }
                .padding(.horizontal, 12)
            }
            
            // Add Color Button
            HStack {
                if document.settings.colorMode == .pantone {
                    Button("Browse Pantone Library") {
                        showingPantoneSearch = true
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                } else {
                    Button("Add Custom Color") {
                        showingPantoneSearch = true // Will be used for general color picker
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            
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
        case .pantone:
            return "Pantone spot colors for professional printing"
        }
    }
    
    private var filteredColors: [VectorColor] {
        if searchText.isEmpty {
            return document.colorSwatches
        } else {
            return document.colorSwatches.filter { color in
                colorDescription(for: color).localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private func selectColor(_ color: VectorColor) {
        // If we have a callback, just use it (we're in a modal for specific purpose)
        if let onColorSelected = onColorSelected {
            onColorSelected(color)
        } else {
            // Otherwise, apply color to selected objects based on modifier keys
            if !document.selectedShapeIDs.isEmpty {
                // Apply to shapes
                guard let layerIndex = document.selectedLayerIndex else { return }
                
                for shapeID in document.selectedShapeIDs {
                    if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                        if NSEvent.modifierFlags.contains(.option) {
                            // Option+Click = stroke color
                            if document.layers[layerIndex].shapes[shapeIndex].strokeStyle != nil {
                                document.layers[layerIndex].shapes[shapeIndex].strokeStyle?.color = color
                            } else {
                                document.layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(color: color, width: 1.0)
                            }
                        } else {
                            // Regular click = fill color
                            if document.layers[layerIndex].shapes[shapeIndex].fillStyle != nil {
                                document.layers[layerIndex].shapes[shapeIndex].fillStyle?.color = color
                            } else {
                                document.layers[layerIndex].shapes[shapeIndex].fillStyle = FillStyle(color: color)
                            }
                        }
                    }
                }
            }
            
            if !document.selectedTextIDs.isEmpty {
                // Apply to text based on active color target
                for textID in document.selectedTextIDs {
                    if let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) {
                        if document.activeColorTarget == .stroke {
                            // Apply to stroke color
                            document.textObjects[textIndex].typography.hasStroke = true
                            document.textObjects[textIndex].typography.strokeColor = color
                        } else {
                            // Apply to fill color
                            document.textObjects[textIndex].typography.fillColor = color
                        }
                    }
                }
            }
        }
    }
    
    private func searchPantoneColor(_ searchQuery: String) {
        let allPantoneColors = ColorManagement.loadPantoneColors()
        
        if let foundColor = allPantoneColors.first(where: { 
            $0.number.localizedCaseInsensitiveContains(searchQuery) ||
            $0.name.localizedCaseInsensitiveContains(searchQuery)
        }) {
            let pantoneColor = VectorColor.pantone(foundColor)
            // Only add to swatches when explicitly searching and finding
            if !document.colorSwatches.contains(pantoneColor) {
                document.addColorSwatch(pantoneColor)
            }
            searchText = ""
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
        case .pantone(let pantone): 
            return "PANTONE \(pantone.number) - \(pantone.name)"
        case .appleSystem(let systemColor): 
            return "Apple \(systemColor.name.capitalized)"
        }
    }
    
    @ViewBuilder
    private func overlayText(for color: VectorColor) -> some View {
        if case .pantone(let pantone) = color {
            Text(pantone.number)
                .font(.system(size: 6))
                .foregroundColor(.white)
                .shadow(color: .black, radius: 1)
                .lineLimit(1)
        }
    }
} 