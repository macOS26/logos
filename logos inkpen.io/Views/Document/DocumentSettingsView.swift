//
//  DocumentSettingsView.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation
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
                    
                    // Color Settings Section
                    colorSettingsSection
                    
                    // Display Settings Section
                    displaySettingsSection
                    
                    // Drawing Tools Section
                    drawingToolsSection
                    
                    // Advanced Smoothing Section
                    advancedSmoothingSection
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
                .buttonStyle(PlainButtonStyle())
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
            
            VStack(spacing: 16) {
                // Dimensions
                HStack(spacing: 16) {
                    // Width
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Width")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            TextField("Width", value: $document.settings.width, format: .number)
                                .textFieldStyle(ProfessionalTextFieldStyle())
                                .frame(width: 100)
                                .onChange(of: document.settings.width) {
                                    document.onSettingsChanged()
                                }
                            
                            Text(document.settings.unit.rawValue)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
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
                                .frame(width: 100)
                                .onChange(of: document.settings.height) {
                                    document.onSettingsChanged()
                                }
                            
                            Text(document.settings.unit.rawValue)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
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
                    .onChange(of: document.settings.unit) {
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
    
    // MARK: - Display Settings Section
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
            
            VStack(spacing: 16) {
                // Resolution
                VStack(alignment: .leading, spacing: 6) {
                    Text("Resolution")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        TextField("Resolution", value: $document.settings.resolution, format: .number)
                            .textFieldStyle(ProfessionalTextFieldStyle())
                            .frame(width: 100)
                        
                        Text("DPI")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Display Options
                VStack(alignment: .leading, spacing: 8) {
                    Text("Display Options")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 6) {
                        ProfessionalToggle(title: "Show Rulers", isOn: $document.settings.showRulers)
                        ProfessionalToggle(title: "Show Grid", isOn: $document.settings.showGrid)
                        ProfessionalToggle(title: "Snap to Grid", isOn: $document.settings.snapToGrid)
                            .disabled(!document.settings.showGrid)
                    }
                }
                
                // Grid Spacing
                if document.settings.showGrid {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Grid Spacing")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            TextField("Grid Spacing", value: $document.settings.gridSpacing, format: .number)
                                .textFieldStyle(ProfessionalTextFieldStyle())
                                .frame(width: 100)
                            
                            Text(document.settings.unit.rawValue)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Drawing Tools Section
    private var drawingToolsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                
                Text("Drawing Tools")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Freehand Smoothing")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(String(format: "%.1f", document.settings.freehandSmoothingTolerance))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blue.opacity(0.1))
                        )
                }
                
                VStack(spacing: 8) {
                    Slider(
                        value: $document.settings.freehandSmoothingTolerance,
                        in: 0.1...10.0,
                        step: 0.1
                    ) {
                        Text("Freehand Smoothing")
                    } minimumValueLabel: {
                        Text("Detail")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    } maximumValueLabel: {
                        Text("Smooth")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .onChange(of: document.settings.freehandSmoothingTolerance) {
                        document.onSettingsChanged()
                    }
                    
                    Text("Lower values preserve more detail, higher values create smoother curves")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
        }
    }
    
    // MARK: - Advanced Smoothing Section
    private var advancedSmoothingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "waveform.path")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.purple)
                
                Text("Advanced Smoothing")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Toggle("", isOn: $document.settings.advancedSmoothingEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .purple))
                    .onChange(of: document.settings.advancedSmoothingEnabled) {
                        document.onSettingsChanged()
                    }
            }
            
            if document.settings.advancedSmoothingEnabled {
                VStack(alignment: .leading, spacing: 12) {
                    // Real-time smoothing
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Real-time Smoothing")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Toggle("", isOn: $document.settings.realTimeSmoothingEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .purple))
                                .onChange(of: document.settings.realTimeSmoothingEnabled) {
                                    document.onSettingsChanged()
                                }
                        }
                        
                        if document.settings.realTimeSmoothingEnabled {
                            HStack {
                                Text("Strength")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text(String(format: "%.1f", document.settings.realTimeSmoothingStrength))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.purple)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.purple.opacity(0.1))
                                    )
                            }
                            
                            Slider(
                                value: $document.settings.realTimeSmoothingStrength,
                                in: 0.0...1.0,
                                step: 0.1
                            ) {
                                Text("Real-time Smoothing Strength")
                            } minimumValueLabel: {
                                Text("Light")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.secondary)
                            } maximumValueLabel: {
                                Text("Strong")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .onChange(of: document.settings.realTimeSmoothingStrength) {
                                document.onSettingsChanged()
                            }
                        }
                    }
                    
                    // Chaikin smoothing iterations
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Chaikin Iterations")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("\(document.settings.chaikinSmoothingIterations)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.purple)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.purple.opacity(0.1))
                                )
                        }
                        
                        Slider(
                            value: Binding<Double>(
                                get: { Double(document.settings.chaikinSmoothingIterations) },
                                set: { document.settings.chaikinSmoothingIterations = Int($0) }
                            ),
                            in: 1...3,
                            step: 1
                        ) {
                            Text("Chaikin Smoothing Iterations")
                        } minimumValueLabel: {
                            Text("1")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        } maximumValueLabel: {
                            Text("3")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .onChange(of: document.settings.chaikinSmoothingIterations) {
                            document.onSettingsChanged()
                        }
                        
                        Text("More iterations create smoother curves but may lose detail")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    // Advanced options
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Adaptive Tension")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Toggle("", isOn: $document.settings.adaptiveTensionEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .purple))
                                .scaleEffect(0.8)
                                .onChange(of: document.settings.adaptiveTensionEnabled) {
                                    document.onSettingsChanged()
                                }
                        }
                        
                        HStack {
                            Text("Preserve Sharp Corners")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Toggle("", isOn: $document.settings.preserveSharpCorners)
                                .toggleStyle(SwitchToggleStyle(tint: .purple))
                                .scaleEffect(0.8)
                                .onChange(of: document.settings.preserveSharpCorners) {
                                    document.onSettingsChanged()
                                }
                        }
                    }
                }
                .padding(.leading, 12)
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Professional Footer
    private var professionalFooter: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack {
                Spacer()
                
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(ProfessionalPrimaryButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}
