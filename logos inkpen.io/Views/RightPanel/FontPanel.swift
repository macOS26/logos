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
    
    // TRACK CURRENTLY EDITING TEXT BOX UUID
    private var editingText: VectorText? {
        document.textObjects.first { $0.isEditing }
    }
    
    // GET CURRENT TEXT BOX STATE
    private func getTextBoxState(_ textBox: VectorText) -> TextBoxState {
        if textBox.isEditing {
            return .editing
        } else if document.selectedTextIDs.contains(textBox.id) {
            return .selected
        } else {
            return .unselected
        }
    }
    
    private var currentFontFamily: String {
        guard let selectedText = selectedText else { return document.fontManager.selectedFontFamily }
        return selectedText.typography.fontFamily
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
                        // Header with UUID Tracking
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Font Properties")
                                    .font(.headline)
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            
                            // TEXTBOX UUID TRACKING - Shows which text box is active
                            if let editingText = editingText {
                                HStack {
                                    Text("Editing TextBox UUID:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(editingText.id.uuidString.prefix(8))
                                        .font(.caption.monospaced())
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(4)
                                        .help("Currently editing text box: \(editingText.id.uuidString)")
                                    
                                    Text("(BLUE - Edit Mode)")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                    
                                    Spacer()
                                }
                            } else if let selectedText = selectedText {
                                HStack {
                                    Text("Selected TextBox UUID:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(selectedText.id.uuidString.prefix(8))
                                        .font(.caption.monospaced())
                                        .foregroundColor(.green)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.green.opacity(0.1))
                                        .cornerRadius(4)
                                        .help("Currently selected text box: \(selectedText.id.uuidString)")
                                    
                                    Text("(GREEN - Selected)")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                    
                                    Spacer()
                                }
                            } else {
                                HStack {
                                    Text("No TextBox Selected")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    
                                    Text("(Showing defaults for new text)")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                    
                                    Spacer()
                                }
                            }
                            
                            // CRITICAL: Show isolation status
                            if selectedText != nil {
                                HStack {
                                    Image(systemName: "lock.shield")
                                        .foregroundColor(.green)
                                        .font(.caption2)
                                    Text("Font settings isolated per text box UUID")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                    Spacer()
                                }
                                .padding(.top, 4)
                            }
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
                                    get: { 
                                        guard let selectedText = selectedText else { return document.fontManager.selectedFontFamily }
                                        return selectedText.typography.fontFamily
                                    },
                                    set: { newFamily in
                                        if let _ = selectedText {
                                            // Update selected text only - NO document.fontManager changes
                                            updateSelectedTextProperties(action: "Changed font family") { text in
                                                text.typography.fontFamily = newFamily
                                                validateAndUpdateWeightAndStyle()
                                            }
                                        } else {
                                            // Update document font manager for new text creation only
                                            document.fontManager.selectedFontFamily = newFamily
                                        }
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
                                // REMOVED: onChange handler that was causing property sync when switching tools
                            }
                            
                            // Font Weight
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Weight")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                
                                Picker("Weight", selection: Binding(
                                    get: { 
                                        guard let selectedText = selectedText else { 
                                            return availableFontWeights.contains(document.fontManager.selectedFontWeight) ? document.fontManager.selectedFontWeight : availableFontWeights.first ?? .regular
                                        }
                                        return availableFontWeights.contains(selectedText.typography.fontWeight) ? selectedText.typography.fontWeight : availableFontWeights.first ?? .regular
                                    },
                                    set: { newWeight in
                                        if let _ = selectedText {
                                            // Update selected text only - NO document.fontManager changes
                                            updateSelectedTextProperties(action: "Changed font weight") { text in
                                                text.typography.fontWeight = newWeight
                                            }
                                        } else {
                                            // Update document font manager for new text creation only
                                            document.fontManager.selectedFontWeight = newWeight
                                        }
                                    }
                                )) {
                                    ForEach(availableFontWeights, id: \.self) { weight in
                                        Text(weight.rawValue)
                                            .font(createPreviewFont(weight: weight, style: document.fontManager.selectedFontStyle))
                                            .tag(weight)
                                    }
                                }
                                .pickerStyle(.menu)
                                // REMOVED: onChange handler that was causing property sync when switching tools
                            }
                            
                            // Font Style  
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Style")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                
                                Picker("Style", selection: Binding(
                                    get: { 
                                        guard let selectedText = selectedText else { 
                                            return availableFontStyles.contains(document.fontManager.selectedFontStyle) ? document.fontManager.selectedFontStyle : availableFontStyles.first ?? .normal
                                        }
                                        return availableFontStyles.contains(selectedText.typography.fontStyle) ? selectedText.typography.fontStyle : availableFontStyles.first ?? .normal
                                    },
                                    set: { newStyle in
                                        if let _ = selectedText {
                                            // Update selected text only - NO document.fontManager changes
                                            updateSelectedTextProperties(action: "Changed font style") { text in
                                                text.typography.fontStyle = newStyle
                                            }
                                        } else {
                                            // Update document font manager for new text creation only
                                            document.fontManager.selectedFontStyle = newStyle
                                        }
                                    }
                                )) {
                                    ForEach(availableFontStyles, id: \.self) { style in
                                        Text(style.rawValue)
                                            .font(createPreviewFont(weight: document.fontManager.selectedFontWeight, style: style))
                                            .tag(style)
                                    }
                                }
                                .pickerStyle(.menu)
                                // REMOVED: onChange handler that was causing property sync when switching tools
                            }
                            
                            // Font Size - Slider from 1pt to 288pt
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Font Size")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(String(format: "%.1f", selectedText?.typography.fontSize ?? document.fontManager.selectedFontSize)) pt")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Slider(value: Binding(
                                    get: { 
                                        guard let selectedText = selectedText else { return document.fontManager.selectedFontSize }
                                        return selectedText.typography.fontSize
                                    },
                                    set: { newSize in
                                        if let _ = selectedText {
                                            // Update selected text only - NO document.fontManager changes
                                            updateSelectedTextProperties(action: "Changed font size") { text in
                                                text.typography.fontSize = newSize
                                                // Update line height to maintain proportion when font size changes
                                                if text.typography.lineHeight > 0 {
                                                    text.typography.lineHeight = newSize
                                                }
                                            }
                                        } else {
                                            // Update document font manager for new text creation only
                                            document.fontManager.selectedFontSize = newSize
                                        }
                                    }
                                ), in: 1...288)
                                .controlSize(.small)
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
                            
                            // Line Spacing Control (0 to fontSize/2)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Line Spacing")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(currentLineSpacing == 0 ? "0 pt" : "\(String(format: "%.0f", currentLineSpacing)) pt")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Slider(value: Binding(
                                    get: { currentLineSpacing },
                                    set: { newSpacing in
                                        updateLineSpacing(newSpacing)
                                    }
                                ), in: {
                                    let fontSize = selectedText?.typography.fontSize ?? document.fontManager.selectedFontSize
                                    return 0...(fontSize / 2)
                                }())
                                .controlSize(.small)
                            }
                            
                            // Line Height Control (fontSize/2 to fontSize*2)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Line Height")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(String(format: "%.0f", currentLineHeight)) pt")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Slider(value: Binding(
                                    get: { currentLineHeight },
                                    set: { newHeight in
                                        updateLineHeight(newHeight)
                                    }
                                ), in: {
                                    let fontSize = selectedText?.typography.fontSize ?? document.fontManager.selectedFontSize
                                    return (fontSize / 2)...(fontSize * 2)
                                }())
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
            // REMOVED: validateAndUpdateWeightAndStyle() that was causing property changes when switching tools
            DispatchQueue.main.async {
                document.objectWillChange.send()
            }
        }
        .onChange(of: document.currentTool) { oldTool, newTool in
            // CRITICAL PROTECTION: Prevent font settings from changing during tool switches
            print("🔧 FONT PANEL: Tool changed from \(oldTool.rawValue) to \(newTool.rawValue)")
            print("🔒 PROTECTION: Font settings remain isolated per text box UUID - no syncing")
            
            // Log current text box states for debugging
            if let editingText = editingText {
                print("🎯 EDITING UUID: \(editingText.id.uuidString.prefix(8)) - BLUE state maintained")
            }
            if let selectedText = selectedText {
                print("🎯 SELECTED UUID: \(selectedText.id.uuidString.prefix(8)) - GREEN state maintained")
            }
            if selectedText == nil && editingText == nil {
                print("🎯 NO TEXT SELECTED - showing document defaults for new text creation")
            }
        }
        .onChange(of: document.selectedTextIDs) { oldIDs, newIDs in
            // CRITICAL PROTECTION: Log text selection changes to ensure UUID tracking works
            let removedIDs = oldIDs.subtracting(newIDs)
            let addedIDs = newIDs.subtracting(oldIDs)
            
            for removedID in removedIDs {
                print("🎯 TEXT DESELECTED: \(removedID.uuidString.prefix(8)) - font settings preserved")
            }
            for addedID in addedIDs {
                print("🎯 TEXT SELECTED: \(addedID.uuidString.prefix(8)) - loading unique font settings")
            }
        }
    }
    
    // NEW: Helper properties for text alignment and line spacing
    private var currentTextAlignment: NSTextAlignment {
        selectedText?.typography.alignment.nsTextAlignment ?? .left
    }
    
    private var currentLineSpacing: CGFloat {
        guard let selectedText = selectedText else { return 0.0 }
        // RAW LINE SPACING VALUE (0 to fontSize/2) - SINGLE SOURCE OF TRUTH
        return selectedText.typography.lineSpacing
    }
    
    private var currentLineHeight: CGFloat {
        guard let selectedText = selectedText else { return document.fontManager.selectedFontSize }
        // RAW LINE HEIGHT VALUE (fontSize/2 to fontSize*2) - SINGLE SOURCE OF TRUTH
        return selectedText.typography.lineHeight
    }
    
    private var currentFontSize: CGFloat {
        return selectedText?.typography.fontSize ?? document.fontManager.selectedFontSize
    }
    
    // CONSOLIDATED: Generic text property updater with UUID validation
    private func updateSelectedTextProperties(action: String, update: (inout VectorText) -> Void) {
        guard !document.selectedTextIDs.isEmpty else { return }
        
        document.saveToUndoStack()
        
        // CRITICAL: Prevent duplicate settings - each text box maintains its own UUID-specific settings
        var processedUUIDs: Set<UUID> = []
        
        // Update ALL selected text objects (same as fill color)
        for textID in document.selectedTextIDs {
            // Prevent duplicate processing of the same UUID
            guard !processedUUIDs.contains(textID) else {
                print("⚠️ PREVENTED DUPLICATE: Skipping already processed textbox UUID \(textID.uuidString.prefix(8))")
                continue
            }
            
            if let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) {
                let originalTypography = document.textObjects[textIndex].typography
                update(&document.textObjects[textIndex])
                let updatedTypography = document.textObjects[textIndex].typography
                
                // Log the specific changes for this UUID
                if originalTypography != updatedTypography {
                    print("🎯 FONT SETTINGS UPDATE: UUID \(textID.uuidString.prefix(8))")
                    print("  - Action: \(action)")
                    print("  - Font: \(updatedTypography.fontFamily) \(updatedTypography.fontWeight.rawValue) \(updatedTypography.fontStyle.rawValue)")
                    print("  - Size: \(updatedTypography.fontSize)pt")
                } else {
                    print("🎯 NO CHANGE: UUID \(textID.uuidString.prefix(8)) - font settings unchanged")
                }
                
                processedUUIDs.insert(textID)
            }
        }
        
        print("🔧 FONT PANEL: \(action) - Processed \(processedUUIDs.count) unique text box UUIDs")
    }
    
    // SIMPLE WRAPPERS: Clean individual functions
    private func updateTextAlignment(_ alignment: TextAlignment) {
        updateSelectedTextProperties(action: "Updated text alignment to \(alignment)") { text in
            text.typography.alignment = alignment
        }
    }
    
    private func updateLineSpacing(_ spacing: CGFloat) {
        updateSelectedTextProperties(action: "Updated line spacing to \(spacing)pt") { text in
            // RAW LINE SPACING VALUE (0 to fontSize/2)
            text.typography.lineSpacing = Double(spacing)
        }
    }
    
    private func updateLineHeight(_ height: CGFloat) {
        updateSelectedTextProperties(action: "Updated line height to \(height)pt") { text in
            // RAW LINE HEIGHT VALUE (fontSize/2 to fontSize*2)
            text.typography.lineHeight = Double(height)
        }
    }
    
    // REMOVED: updateSelectedTextFont() - now using targeted updates for single source of truth
    
    // Create preview font for picker display
    private func createPreviewFont(weight: FontWeight, style: FontStyle) -> Font {
        let descriptor = NSFontDescriptor(name: currentFontFamily, size: 12)
        let traits: NSFontDescriptor.SymbolicTraits = style == .italic ? .italic : []
        let weightedDescriptor = descriptor.addingAttributes([
            .traits: [
                NSFontDescriptor.TraitKey.weight: weight.nsWeight.rawValue,
                NSFontDescriptor.TraitKey.symbolic: traits.rawValue
            ]
        ])
        
        if let nsFont = NSFont(descriptor: weightedDescriptor, size: 12) {
            return Font.custom(nsFont.fontName, size: 12)
        } else {
            return Font.custom(currentFontFamily, size: 12)
        }
    }
    
    // Validate and update weight/style when font changes
    private func validateAndUpdateWeightAndStyle() {
        let weights = availableFontWeights
        let styles = availableFontStyles
        
        if let _ = selectedText {
            // Update selected text's weight/style if invalid - NO document.fontManager changes
            updateSelectedTextProperties(action: "Validated font weight/style") { text in
                if !weights.contains(text.typography.fontWeight) {
                    text.typography.fontWeight = weights.first ?? .regular
                }
                if !styles.contains(text.typography.fontStyle) {
                    text.typography.fontStyle = styles.first ?? .normal
                }
            }
        } else {
            // Update document font manager for new text creation only
            if !weights.contains(document.fontManager.selectedFontWeight) {
                document.fontManager.selectedFontWeight = weights.first ?? .regular
            }
            if !styles.contains(document.fontManager.selectedFontStyle) {
                document.fontManager.selectedFontStyle = styles.first ?? .normal
            }
        }
    }
    
    // REMOVED: stroke support functions - keeping only fill
    
    private func convertSelectedTextToOutlines() {
        guard !document.selectedTextIDs.isEmpty else { return }
        
        // Use the CORRECT method that calls YOUR multi-line Core Text implementation
        document.convertSelectedTextToOutlines()
        
        print("🎯 FONT PANEL: Converting text to vector outlines using YOUR multi-line Core Text implementation")
    }
} 
