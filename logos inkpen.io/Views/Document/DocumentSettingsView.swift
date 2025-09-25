//
//  DocumentSettingsView.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI

struct DocumentSettingsView: View {
    @ObservedObject var document: VectorDocument
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
            // Professional Header
            professionalHeader
            
            // Main Content
            ScrollView {
                VStack(spacing: 24) {
                    // Document Size Section
                    documentSizeSection

                    // Display and Color Settings Side by Side
                    HStack(alignment: .top, spacing: 24) {
                        // Left 50%: Display Settings (Resolution only)
                        VStack(alignment: .leading, spacing: 24) {
                            displaySettingsSection
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)

                        Divider()
                            .frame(height: 100)

                        // Right 50%: Color Settings
                        VStack(alignment: .leading, spacing: 24) {
                            colorSettingsSection
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }

                    // Display Options Section (without Grid Spacing)
                    displayOptionsSection

                    // Layer Selection and Grid Spacing Side by Side at Bottom
                    HStack(alignment: .top, spacing: 24) {
                        // Left: Selected Layer
                        layerSelectionSection
                            .frame(maxWidth: .infinity, alignment: .topLeading)

                        // Right: Grid Spacing
                        gridSpacingSection
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
                .padding(24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Professional Footer
            professionalFooter
        }
        .frame(width: 600, height: 700)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Professional Header
    private var professionalHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // App Icon and Title
                HStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.blue)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.1))
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Document Settings")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("Configure document properties and preferences")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Close Button
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.ui.lightGrayBackground)
                        )
                }
                .buttonStyle(BorderlessButtonStyle())
                .help("Close")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            
            Divider()
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Document Size Section
    private var documentSizeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "ruler")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                
                Text("Document Size")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                // Dimensions - Side by Side
                HStack(spacing: 24) {
                    // Width
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Width")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            TextField("Width", value: $document.settings.width, format: .number)
                                .textFieldStyle(ProfessionalTextFieldStyle())
                                .frame(width: 120)
                                .onChange(of: document.settings.width) {
                                    document.onSettingsChanged()
                                }

                            Text(document.settings.unit.rawValue.capitalized)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(width: 60, alignment: .leading)
                        }
                    }

                    // Height
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Height")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            TextField("Height", value: $document.settings.height, format: .number)
                                .textFieldStyle(ProfessionalTextFieldStyle())
                                .frame(width: 120)
                                .onChange(of: document.settings.height) {
                                    document.onSettingsChanged()
                                }

                            Text(document.settings.unit.rawValue.capitalized)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(width: 60, alignment: .leading)
                        }
                    }

                    Spacer()
                }
                
                // Units
                VStack(alignment: .leading, spacing: 6) {
                    Text("Units")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Picker("Unit", selection: $document.settings.unit) {
                        ForEach(MeasurementUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue.capitalized).tag(unit)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: document.settings.unit) { oldUnit, newUnit in
                        // Convert width and height to new units
                        let convertedWidth = UnitsConverter.convert(value: document.settings.width, from: oldUnit, to: newUnit)
                        let convertedHeight = UnitsConverter.convert(value: document.settings.height, from: oldUnit, to: newUnit)
                        document.settings.width = convertedWidth
                        document.settings.height = convertedHeight

                        // Always convert grid spacing when units change
                        let convertedGridSpacing = UnitsConverter.convert(value: document.settings.gridSpacing, from: oldUnit, to: newUnit)
                        document.settings.gridSpacing = convertedGridSpacing
                        
                        document.onSettingsChanged()
                    }
                }
            }
        }
    }
    
    // MARK: - Color Settings Section
    private var colorSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "paintpalette")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                
                Text("Color Settings")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Color Mode")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                
                Picker("Color Mode", selection: $document.settings.colorMode) {
                    ForEach(ColorMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue.uppercased()).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
        }
    }
    
    // MARK: - Display Settings Section (Resolution only)
    private var displaySettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "eye")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)

                Text("Display Settings")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }

            // Resolution
            VStack(alignment: .leading, spacing: 6) {
                Text("Resolution")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    TextField("Resolution", value: $document.settings.resolution, format: .number)
                        .textFieldStyle(ProfessionalTextFieldStyle())
                        .frame(width: 120)
                        .onChange(of: document.settings.resolution) {
                            document.onSettingsChanged()
                        }

                    Text("DPI")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 60, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Layer Selection Section
    private var layerSelectionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Selected Layer")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)

            Picker("", selection: Binding(
                    get: {
                        // Find the layer with the matching ID, or default to first layer
                        if let selectedId = document.settings.selectedLayerId,
                           let layer = document.layers.first(where: { $0.id == selectedId }) {
                            return layer.id
                        } else if let firstLayer = document.layers.first {
                            // Default to first layer if no selection or selection not found
                            return firstLayer.id
                        } else {
                            // This should never happen, but provide a fallback
                            return UUID()
                        }
                    },
                    set: { newLayerId in
                        // Update both ID and name when selection changes
                        if let selectedLayer = document.layers.first(where: { $0.id == newLayerId }) {
                            document.settings.selectedLayerId = selectedLayer.id
                            document.settings.selectedLayerName = selectedLayer.name
                            document.layerIndex = document.layers.firstIndex(where: { $0.id == newLayerId }) ?? 0
                            document.onSettingsChanged()
                        }
                    }
                )) {
                    ForEach(document.layers) { layer in
                        Text(layer.name).tag(layer.id)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
                .disabled(document.layers.isEmpty)
        }
    }

    // MARK: - Display Options Section (Full Width)
    private var displayOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "eye")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)

                Text("Display Options")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }

            // 2x2 Grid Layout with proper alignment
            VStack(alignment: .leading, spacing: 12) {
                // First row: Show Rulers and Snap to Point
                HStack(spacing: 40) {
                    // Show Rulers
                    HStack {
                        Text("Show Rulers")
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                            .frame(width: 120, alignment: .leading)

                        StylusToggleButton(isOn: $document.settings.showRulers) { newValue in
                            document.showRulers = newValue
                            UserDefaults.standard.set(newValue, forKey: "showRulers")
                            document.onSettingsChanged()
                        }
                    }

                    // Snap to Point
                    HStack {
                        Text("Snap to Point")
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                            .frame(width: 120, alignment: .leading)

                        StylusToggleButton(isOn: $document.settings.snapToPoint) { newValue in
                            document.snapToPoint = newValue
                            UserDefaults.standard.set(newValue, forKey: "snapToPoint")
                            document.onSettingsChanged()
                        }
                    }
                }

                // Second row: Show Grid and Snap to Grid
                HStack(spacing: 40) {
                    // Show Grid
                    HStack {
                        Text("Show Grid")
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                            .frame(width: 120, alignment: .leading)

                        StylusToggleButton(isOn: $document.settings.showGrid) { newValue in
                            document.showGrid = newValue
                            UserDefaults.standard.set(newValue, forKey: "showGrid")
                            document.onSettingsChanged()
                        }
                    }

                    // Snap to Grid
                    HStack {
                        Text("Snap to Grid")
                            .font(.system(size: 13))
                            .foregroundColor(.primary)
                            .frame(width: 120, alignment: .leading)

                        StylusToggleButton(isOn: $document.settings.snapToGrid) { newValue in
                            document.snapToGrid = newValue
                            UserDefaults.standard.set(newValue, forKey: "snapToGrid")
                            document.onSettingsChanged()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Grid Spacing Section
    private var gridSpacingSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Grid Spacing")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                TextField("Grid Spacing", value: $document.settings.gridSpacing, format: .number)
                    .textFieldStyle(ProfessionalTextFieldStyle())
                    .frame(width: 120)
                    .onChange(of: document.settings.gridSpacing) {
                        document.onSettingsChanged()
                    }

                Text(document.settings.unit.rawValue.capitalized)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .leading)
            }
        }
    }
    
    
    
    // MARK: - Professional Footer
    private var professionalFooter: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack {
                Spacer()
                
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Text("Done")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .frame(minHeight: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}
