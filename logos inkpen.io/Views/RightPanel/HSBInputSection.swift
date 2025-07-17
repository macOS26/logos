//
//  HSBInputSection.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

// MARK: - Professional PMS Input Section with Pantone Color Matching

struct HSBInputSection: View {
    @ObservedObject var document: VectorDocument
    @Binding var sharedColor: VectorColor // Shared color state
    
    @State private var hueValue: String = "0"
    @State private var saturationValue: String = "100"
    @State private var brightnessValue: String = "100"
    
    // Slider values
    @State private var hueSlider: Double = 0        // 0-360 degrees
    @State private var saturationSlider: Double = 100 // 0-100%
    @State private var brightnessSlider: Double = 100 // 0-100%
    
    // Computed color from HSB values
    private var currentColor: HSBColorModel {
        let h = Double(hueValue) ?? 0
        let s = (Double(saturationValue) ?? 0) / 100.0
        let b = (Double(brightnessValue) ?? 0) / 100.0
        
        return HSBColorModel(hue: h, saturation: s, brightness: b)
    }
    
    // PMS number entry
    @State private var pmsNumberEntry: String = ""
    @State private var showingPMSLibrary = false
    
    // Find closest Pantone color match
    @ObservedObject private var pantoneLibrary = PantoneLibrary()
    
    private var closestPantoneColor: PantoneLibraryColor? {
        pantoneLibrary.findClosestMatch(to: currentColor)
    }
    

    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // PMS Color Preview and Controls
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("PMS Color")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Add to Swatches") {
                        if let pantoneColor = closestPantoneColor {
                            let pantColor = VectorColor.pantone(pantoneColor)
                            document.addColorSwatch(pantColor)
                        }
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                    .disabled(closestPantoneColor == nil)
                }
                
                HStack(spacing: 12) {
                    // Current PMS Color
                    VStack(spacing: 4) {
                        Rectangle()
                            .fill(currentColor.color)
                            .frame(width: 50, height: 50)
                            .overlay(
                                Rectangle()
                                    .stroke(Color.gray, lineWidth: 1)
                            )
                        
                        Text("Current")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Arrow
                    Image(systemName: "arrow.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    // Closest PMS Match
                    if let pantoneColor = closestPantoneColor {
                        VStack(spacing: 4) {
                            Button {
                                // Apply closest Pantone color
                                let pantColor = VectorColor.pantone(pantoneColor)
                                sharedColor = pantColor
                                document.addColorToCurrentMode(pantColor)
                                updateHSBFromColor(pantColor)
                            } label: {
                                Rectangle()
                                    .fill(pantoneColor.color)
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Rectangle()
                                            .stroke(Color.purple, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help("Click to use closest PMS color: \(pantoneColor.pantone)")
                            
                            Text("PMS \(pantoneColor.pantone.replacingOccurrences(of: "-c", with: "").replacingOccurrences(of: " C", with: ""))")
                                .font(.caption2)
                                .foregroundColor(.purple)
                                .lineLimit(1)
                        }
                    } else {
                        VStack(spacing: 4) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Rectangle()
                                        .stroke(Color.gray, lineWidth: 1)
                                )
                            
                            Text("Loading...")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                
                // PMS Number Entry and Library Access
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PMS Number")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            TextField("e.g. 185", text: $pmsNumberEntry)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.caption)
                                .onSubmit {
                                    searchForPMSNumber()
                                }
                            
                            Button("Find") {
                                searchForPMSNumber()
                            }
                            .buttonStyle(.bordered)
                            .font(.caption)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PMS Library")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Button("Browse Library") {
                            showingPMSLibrary = true
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    }
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
            .cornerRadius(8)
            
            // Hue Slider (0-360°)
            HStack {
                Text("H")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .frame(width: 12)
                
                Slider(value: $hueSlider, in: 0...360, step: 1)
                    .onChange(of: hueSlider) { _ in
                        syncHueValue()
                        updateSharedColor()
                    }
                
                TextField("", text: $hueValue)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 45)
                    .font(.caption)
                    .onChange(of: hueValue) { _ in
                        syncHueSlider()
                        updateSharedColor()
                    }
                
                Text("°")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 15)
            }
            
            // Saturation Slider (0-100%)
            HStack {
                Text("S")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .frame(width: 12)
                
                Slider(value: $saturationSlider, in: 0...100, step: 1)
                    .onChange(of: saturationSlider) { _ in
                        syncSaturationValue()
                        updateSharedColor()
                    }
                
                TextField("", text: $saturationValue)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 45)
                    .font(.caption)
                    .onChange(of: saturationValue) { _ in
                        syncSaturationSlider()
                        updateSharedColor()
                    }
                
                Text("%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 15)
            }
            
            // Brightness Slider (0-100%)
            HStack {
                Text("B")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .frame(width: 12)
                
                Slider(value: $brightnessSlider, in: 0...100, step: 1)
                    .onChange(of: brightnessSlider) { _ in
                        syncBrightnessValue()
                        updateSharedColor()
                    }
                
                TextField("", text: $brightnessValue)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 45)
                    .font(.caption)
                    .onChange(of: brightnessValue) { _ in
                        syncBrightnessSlider()
                        updateSharedColor()
                    }
                
                Text("%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 15)
            }
        }
        .onAppear {
            updateHSBFromSharedColor()
        }
        .onChange(of: sharedColor) { _ in
            updateHSBFromSharedColor()
        }
        .sheet(isPresented: $showingPMSLibrary) {
            PantoneColorPickerSheet(document: document)
        }
    }
    
    // MARK: - Helper Methods
    
    private func syncHueValue() {
        hueValue = String(Int(hueSlider))
    }
    
    private func syncHueSlider() {
        if let value = Double(hueValue) {
            hueSlider = max(0, min(360, value))
        }
    }
    
    private func syncSaturationValue() {
        saturationValue = String(Int(saturationSlider))
    }
    
    private func syncSaturationSlider() {
        if let value = Double(saturationValue) {
            saturationSlider = max(0, min(100, value))
        }
    }
    
    private func syncBrightnessValue() {
        brightnessValue = String(Int(brightnessSlider))
    }
    
    private func syncBrightnessSlider() {
        if let value = Double(brightnessValue) {
            brightnessSlider = max(0, min(100, value))
        }
    }
    
    private func updateSharedColor() {
        sharedColor = .hsb(currentColor)
    }
    
    private func updateHSBFromSharedColor() {
        updateHSBFromColor(sharedColor)
    }
    
    private func searchForPMSNumber() {
        let cleanedNumber = pmsNumberEntry
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        
        if cleanedNumber.isEmpty { return }
        
        // Search for PMS color by number
        let searchResults = pantoneLibrary.searchColors(query: cleanedNumber)
        
        if let foundColor = searchResults.first {
            let pantoneColor = VectorColor.pantone(foundColor)
            sharedColor = pantoneColor
            document.addColorToCurrentMode(pantoneColor)
            updateHSBFromColor(pantoneColor)
            pmsNumberEntry = "" // Clear the search field
        }
    }
    
    private func updateHSBFromColor(_ color: VectorColor) {
        var hsbColor: HSBColorModel
        
        switch color {
        case .hsb(let hsb):
            hsbColor = hsb
        case .rgb(let rgb):
            hsbColor = HSBColorModel.fromRGB(rgb)
        case .cmyk(let cmyk):
            hsbColor = HSBColorModel.fromRGB(cmyk.rgbColor)
        case .spot(let spot):
            hsbColor = spot.hsbEquivalent
        case .pantone(let pantone):
            hsbColor = HSBColorModel.fromRGB(pantone.rgbEquivalent)
        case .appleSystem(let system):
            hsbColor = HSBColorModel.fromRGB(system.rgbEquivalent)
        case .black:
            hsbColor = HSBColorModel(hue: 0, saturation: 0, brightness: 0)
        case .white:
            hsbColor = HSBColorModel(hue: 0, saturation: 0, brightness: 1)
        case .clear:
            hsbColor = HSBColorModel(hue: 0, saturation: 0, brightness: 1)
        }
        
        // Update sliders and text fields
        hueSlider = hsbColor.hue
        saturationSlider = hsbColor.saturation * 100
        brightnessSlider = hsbColor.brightness * 100
        
        hueValue = String(Int(hueSlider))
        saturationValue = String(Int(saturationSlider))
        brightnessValue = String(Int(brightnessSlider))
    }
} 