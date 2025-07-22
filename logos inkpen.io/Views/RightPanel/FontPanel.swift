//
//  FontPanel.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

struct FontPanel: View {
    @ObservedObject var document: VectorDocument
    // REMOVED: Separate color pickers - use main color system instead
    
    private var selectedText: VectorText? {
        document.textObjects.first { document.selectedTextIDs.contains($0.id) }
    }
    
    private var currentFontFamily: String {
        selectedText?.typography.fontFamily ?? document.fontManager.selectedFontFamily
    }
    
    private var availableFontWeights: [FontWeight] {
        document.fontManager.getAvailableWeights(for: currentFontFamily)
    }
    
    private var availableFontStyles: [FontStyle] {
        document.fontManager.getAvailableStyles(for: currentFontFamily)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
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
                                            .font(.custom(fontFamily, size: 12)) // Show font name in actual font
                                            .tag(fontFamily)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity)
                                .onChange(of: document.fontManager.selectedFontFamily) { _, _ in
                                    // Force refresh of available weights and styles when font changes
                                    DispatchQueue.main.async {
                                        document.objectWillChange.send()
                                    }
                                }
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
                                        // DYNAMIC FONT WEIGHTS: Only show weights available for this font family
                                        ForEach(availableFontWeights, id: \.self) { weight in
                                            Text(weight.rawValue)
                                                .font(.custom(currentFontFamily, size: 12))
                                                .tag(weight)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .id(currentFontFamily) // Force refresh when font changes
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
                                        // DYNAMIC FONT STYLES: Only show styles available for this font family
                                        ForEach(availableFontStyles, id: \.self) { style in
                                            Text(style.rawValue)
                                                .font(.custom(currentFontFamily, size: 12))
                                                .tag(style)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .id(currentFontFamily) // Force refresh when font changes
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
                            
                            // Text Alignment Controls (NEW)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Alignment")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 4) {
                                    // Left Align
                                    Button {
                                        updateTextAlignment(.left)
                                    } label: {
                                        Image(systemName: "text.alignleft")
                                            .font(.system(size: 14))
                                            .foregroundColor(currentTextAlignment == .left ? .white : .primary)
                                            .frame(width: 30, height: 24)
                                            .background(currentTextAlignment == .left ? Color.blue : Color.clear)
                                            .cornerRadius(4)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .help("Align Left")
                                    
                                    // Center Align
                                    Button {
                                        updateTextAlignment(.center)
                                    } label: {
                                        Image(systemName: "text.aligncenter")
                                            .font(.system(size: 14))
                                            .foregroundColor(currentTextAlignment == .center ? .white : .primary)
                                            .frame(width: 30, height: 24)
                                            .background(currentTextAlignment == .center ? Color.blue : Color.clear)
                                            .cornerRadius(4)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .help("Align Center")
                                    
                                    // Right Align
                                    Button {
                                        updateTextAlignment(.right)
                                    } label: {
                                        Image(systemName: "text.alignright")
                                            .font(.system(size: 14))
                                            .foregroundColor(currentTextAlignment == .right ? .white : .primary)
                                            .frame(width: 30, height: 24)
                                            .background(currentTextAlignment == .right ? Color.blue : Color.clear)
                                            .cornerRadius(4)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .help("Align Right")
                                    
                                    // Justify
                                    Button {
                                        updateTextAlignment(.justified)
                                    } label: {
                                        Image(systemName: "text.justify")
                                            .font(.system(size: 14))
                                            .foregroundColor(currentTextAlignment == .justified ? .white : .primary)
                                            .frame(width: 30, height: 24)
                                            .background(currentTextAlignment == .justified ? Color.blue : Color.clear)
                                            .cornerRadius(4)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .help("Justify")
                                    
                                    Spacer()
                                }
                            }
                            
                            // Line Spacing Control (NEW)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Line Spacing")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(String(format: "%.1f", currentLineSpacing)) pt")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Slider(value: Binding(
                                    get: { currentLineSpacing },
                                    set: { newSpacing in
                                        updateLineSpacing(newSpacing)
                                    }
                                ), in: -20...20)
                                .controlSize(.small)
                            }
                            
                            // REMOVE STROKE SUPPORT - Keep only fill colors
                            if let selectedText = selectedText {
                                Divider()
                                
                                // SIMPLIFIED: Text Colors (shows current colors, use main color panels to change)
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Fill Color")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.secondary)
                                        
                                        Text("Use Stroke/Fill panel to change")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    // Current Fill Color (read-only indicator)
                                    VStack(spacing: 2) {
                                        renderColorSwatchRightPanel(selectedText.typography.fillColor, width: 20, height: 20, cornerRadius: 0, borderWidth: 1)
                                        Text("Fill")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
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
                                    .disabled(selectedText?.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                                    
                                    Spacer()
                                    
                                    Text(selectedText?.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true ? "Type text first" : "Creates vector paths")
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
                
                Spacer()
            }
        }
        // REMOVED: Separate color picker sheets - use main color system instead
        .onAppear {
            // Load available weights and styles for the initially selected font
            DispatchQueue.main.async {
                document.objectWillChange.send()
            }
        }
    }
    
    // NEW: Helper properties for text alignment and line spacing
    private var currentTextAlignment: NSTextAlignment {
        selectedText?.typography.alignment.nsTextAlignment ?? .left
    }
    
    private var currentLineSpacing: CGFloat {
        selectedText?.typography.lineHeight ?? 0.0
    }
    
    // NEW: Update text alignment
    private func updateTextAlignment(_ alignment: TextAlignment) {
        guard let textID = document.selectedTextIDs.first,
              let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) else { return }
        
        document.saveToUndoStack()
        document.textObjects[textIndex].typography.alignment = alignment
        document.textObjects[textIndex].updateBounds()
        document.objectWillChange.send()
        
        // Notify text canvas to sync changes
        NotificationCenter.default.post(name: NSNotification.Name("VectorTextUpdated"), object: nil)
        
        print("🎯 FONT PANEL: Updated text alignment to \(alignment)")
    }
    
    // NEW: Update line spacing
    private func updateLineSpacing(_ spacing: CGFloat) {
        guard let textID = document.selectedTextIDs.first,
              let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) else { return }
        
        document.saveToUndoStack()
        document.textObjects[textIndex].typography.lineHeight = Double(spacing)
        document.textObjects[textIndex].updateBounds()
        document.objectWillChange.send()
        
        // Notify text canvas to sync changes
        NotificationCenter.default.post(name: NSNotification.Name("VectorTextUpdated"), object: nil)
        
        print("🎯 FONT PANEL: Updated line spacing to \(spacing)")
    }
    
    private func updateSelectedTextFont() {
        guard let textID = document.selectedTextIDs.first,
              let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) else { return }
        
        // CRITICAL FIX: Save to undo stack BEFORE making changes
        document.saveToUndoStack()
        
        // Update the text object's typography
        document.textObjects[textIndex].typography.fontFamily = document.fontManager.selectedFontFamily
        document.textObjects[textIndex].typography.fontWeight = document.fontManager.selectedFontWeight
        document.textObjects[textIndex].typography.fontStyle = document.fontManager.selectedFontStyle
        document.textObjects[textIndex].typography.fontSize = document.fontManager.selectedFontSize
        
        // Update bounds
        document.textObjects[textIndex].updateBounds()
        
        // Notify UI update
        document.objectWillChange.send()
        
        // Notify text canvas to sync changes
        NotificationCenter.default.post(name: NSNotification.Name("VectorTextUpdated"), object: nil)
    }
    
    // REMOVED: stroke support functions - keeping only fill
    
    private func convertSelectedTextToOutlines() {
        guard let textID = document.selectedTextIDs.first else { return }
        
        // Convert text to vector outlines using professional Core Graphics implementation
        document.convertTextToOutlines(textID)
        
        print("🎯 FONT TOOL: Converting text to vector outlines (Adobe Illustrator standard)")
    }
} 