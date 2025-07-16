//
//  FontPanel.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

struct FontPanel: View {
    @ObservedObject var document: VectorDocument
    @State private var showingTextFillColorPicker = false
    @State private var showingTextStrokeColorPicker = false
    
    private var selectedText: VectorText? {
        document.textObjects.first { document.selectedTextIDs.contains($0.id) }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if document.currentTool == .font || !document.selectedTextIDs.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        // Header
                        HStack {
                            Text("Font Properties")
                                .font(.headline)
                                .fontWeight(.medium)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        
                        VStack(spacing: 16) {
                            // Font Family (Foundry) Picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Font Family")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                
                                Picker("Font Family", selection: Binding(
                                    get: { selectedText?.typography.fontFamily ?? document.fontManager.selectedFontFamily },
                                    set: { newFamily in
                                        document.fontManager.selectedFontFamily = newFamily
                                        updateSelectedTextFont()
                                    }
                                )) {
                                    ForEach(document.fontManager.availableFonts, id: \.self) { fontFamily in
                                        Text(fontFamily)
                                            .font(.custom(fontFamily, size: 12))
                                            .tag(fontFamily)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity)
                            }
                            
                            // Font Weight and Style Row
                            HStack(spacing: 12) {
                                // Font Weight
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Weight")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                    
                                    Picker("Weight", selection: Binding(
                                        get: { selectedText?.typography.fontWeight ?? document.fontManager.selectedFontWeight },
                                        set: { newWeight in
                                            document.fontManager.selectedFontWeight = newWeight
                                            updateSelectedTextFont()
                                        }
                                    )) {
                                        ForEach(FontWeight.allCases, id: \.self) { weight in
                                            Text(weight.rawValue)
                                                .tag(weight)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                                
                                // Font Style
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Style")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                    
                                    Picker("Style", selection: Binding(
                                        get: { selectedText?.typography.fontStyle ?? document.fontManager.selectedFontStyle },
                                        set: { newStyle in
                                            document.fontManager.selectedFontStyle = newStyle
                                            updateSelectedTextFont()
                                        }
                                    )) {
                                        ForEach(FontStyle.allCases, id: \.self) { style in
                                            Text(style.rawValue)
                                                .tag(style)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                            }
                            
                            // Font Size
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Font Size")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    TextField("Size", value: Binding(
                                        get: { selectedText?.typography.fontSize ?? document.fontManager.selectedFontSize },
                                        set: { newSize in
                                            document.fontManager.selectedFontSize = newSize
                                            updateSelectedTextFont()
                                        }
                                    ), format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    
                                    Text("pt")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            // Fill and Stroke integration
                            if let selectedText = selectedText {
                                Divider()
                                
                                // Text Fill Color
                                HStack {
                                    Text("Fill")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Button {
                                        showingTextFillColorPicker = true
                                    } label: {
                                        renderColorSwatchRightPanel(selectedText.typography.fillColor, width: 30, height: 30, cornerRadius: 0, borderWidth: 1)
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                // Text Stroke Toggle and Color
                                HStack {
                                    Toggle("Stroke", isOn: Binding(
                                        get: { selectedText.typography.hasStroke },
                                        set: { hasStroke in
                                            updateTextStroke(hasStroke: hasStroke)
                                        }
                                    ))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    if selectedText.typography.hasStroke {
                                        Button {
                                            showingTextStrokeColorPicker = true
                                        } label: {
                                            renderColorSwatchRightPanel(selectedText.typography.strokeColor, width: 30, height: 30, cornerRadius: 0, borderWidth: 1)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                
                                // Text Stroke Width (NEW)
                                if selectedText.typography.hasStroke {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("Stroke Width")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            Text("\(String(format: "%.1f", selectedText.typography.strokeWidth)) pt")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Slider(value: Binding(
                                            get: { selectedText.typography.strokeWidth },
                                            set: { newWidth in
                                                updateTextStrokeWidth(newWidth)
                                            }
                                        ), in: 0...10)
                                        .controlSize(.small)
                                    }
                                }
                            }
                            
                            // PROFESSIONAL TEXT TO OUTLINES CONVERSION (Adobe Illustrator Standard)
                            if selectedText != nil {
                                Divider()
                                
                                HStack {
                                    Button("Convert to Outlines") {
                                        convertSelectedTextToOutlines()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .font(.caption)
                                    .help("Convert text to vector paths (⌘⇧O)")
                                    .keyboardShortcut("o", modifiers: [.command, .shift])
                                    
                                    Spacer()
                                    
                                    Text("Creates vector paths")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                    }
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    .cornerRadius(12)
                    .padding(.horizontal, 12)
                } else {
                    // No text selected message
                    VStack(spacing: 16) {
                        Image(systemName: "textformat")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No text selected")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Select text or use the Font tool to edit typography")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
                
                Spacer()
            }
        }
        .sheet(isPresented: $showingTextFillColorPicker) {
            ColorPickerModal(
                document: document,
                title: "Text Fill Color",
                onColorSelected: { color in
                    updateTextFillColor(color)
                    if !document.colorSwatches.contains(color) {
                        document.addColorSwatch(color)
                    }
                }
            )
        }
        .sheet(isPresented: $showingTextStrokeColorPicker) {
            ColorPickerModal(
                document: document,
                title: "Text Stroke Color",
                onColorSelected: { color in
                    updateTextStrokeColor(color)
                    if !document.colorSwatches.contains(color) {
                        document.addColorSwatch(color)
                    }
                }
            )
        }
    }
    
    private func updateSelectedTextFont() {
        guard let textID = document.selectedTextIDs.first,
              let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) else { return }
        
        // Update the text object's typography
        document.textObjects[textIndex].typography.fontFamily = document.fontManager.selectedFontFamily
        document.textObjects[textIndex].typography.fontWeight = document.fontManager.selectedFontWeight
        document.textObjects[textIndex].typography.fontStyle = document.fontManager.selectedFontStyle
        document.textObjects[textIndex].typography.fontSize = document.fontManager.selectedFontSize
        
        // Update bounds
        document.textObjects[textIndex].updateBounds()
        
        // Notify UI update
        document.objectWillChange.send()
    }
    
    private func updateTextFillColor(_ color: VectorColor) {
        guard let textID = document.selectedTextIDs.first,
              let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) else { return }
        
        document.textObjects[textIndex].typography.fillColor = color
        document.objectWillChange.send()
    }
    
    private func updateTextStroke(hasStroke: Bool) {
        guard let textID = document.selectedTextIDs.first,
              let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) else { return }
        
        document.textObjects[textIndex].typography.hasStroke = hasStroke
        if hasStroke {
            document.textObjects[textIndex].typography.strokeColor = document.defaultStrokeColor
        }
        document.objectWillChange.send()
    }
    
    private func updateTextStrokeColor(_ color: VectorColor) {
        guard let textID = document.selectedTextIDs.first,
              let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) else { return }
        
        document.textObjects[textIndex].typography.strokeColor = color
        document.objectWillChange.send()
    }
    
    private func updateTextStrokeWidth(_ width: Double) {
        guard let textID = document.selectedTextIDs.first,
              let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) else { return }
        
        document.textObjects[textIndex].typography.strokeWidth = width
        document.textObjects[textIndex].updateBounds()
        document.objectWillChange.send()
    }
    
    private func convertSelectedTextToOutlines() {
        guard let textID = document.selectedTextIDs.first else { return }
        
        // Convert text to vector outlines using professional Core Graphics implementation
        document.convertTextToOutlines(textID)
        
        print("🎯 FONT TOOL: Converting text to vector outlines (Adobe Illustrator standard)")
    }
} 