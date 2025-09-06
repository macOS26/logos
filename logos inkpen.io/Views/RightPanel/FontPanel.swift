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
    
    // FIXED: Track last logged values to prevent repeated logging
    @State private var lastLoggedSelection: UUID?
    @State private var lastLoggedEditing: UUID?
    
    // NEW: Force UI refresh when font family changes
    @State private var fontFamilyUpdateTrigger: Bool = false
    
    // FIXED: Simple computed property that doesn't modify state during view update
    private var selectedText: VectorText? {
        document.textObjects.first { document.selectedTextIDs.contains($0.id) }
    }
    
    // FIXED: Simple computed property that doesn't modify state during view update
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
    
    // REMOVED: Caching mechanism that was causing infinite loops
    
    // FIXED: Simple computed property without state modifications
    private var currentFontFamily: String {
        if let selectedText = selectedText {
            return selectedText.typography.fontFamily
        } else if let editingText = editingText {
            return editingText.typography.fontFamily
        } else {
            return document.fontManager.selectedFontFamily
        }
    }
    
    // FIXED: Simple computed property without state modifications
    private var availableFontWeights: [FontWeight] {
        let family = currentFontFamily
        return document.fontManager.getAvailableWeights(for: family)
    }
    
    // FIXED: Simple computed property without state modifications
    private var availableFontStyles: [FontStyle] {
        let family = currentFontFamily
        return document.fontManager.getAvailableStyles(for: family)
    }
    
    // REMOVED: clearFontCache function - no longer needed without caching
    
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
                                            .onAppear {
                                                // Ensure font is loaded
                                                _ = NSFont(name: fontFamily, size: 12)
                                            }
                                    }
                                }
                                .pickerStyle(.menu)
                                .onChange(of: currentFontFamily) { oldFamily, newFamily in
                                    // When font family changes, validate and update weight/style for the new family
                                    Log.fileOperation("🎯 FONT PANEL: Font family changed from \(oldFamily) to \(newFamily)", level: .info)
                                    validateAndUpdateWeightAndStyle()
                                    // Force UI refresh to update weight and style pickers
                                    fontFamilyUpdateTrigger.toggle()
                                }
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
                                            .font(createPreviewFont(family: currentFontFamily, weight: weight, style: selectedText?.typography.fontStyle ?? document.fontManager.selectedFontStyle))
                                            .tag(weight)
                                    }
                                }
                                .pickerStyle(.menu)
                                .id(fontFamilyUpdateTrigger) // Force refresh when font family changes
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
                                            .font(createPreviewFont(family: currentFontFamily, weight: selectedText?.typography.fontWeight ?? document.fontManager.selectedFontWeight, style: style))
                                            .tag(style)
                                    }
                                }
                                .pickerStyle(.menu)
                                .id(fontFamilyUpdateTrigger) // Force refresh when font family changes
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
                                        if let selectedText = selectedText {
                                            return selectedText.typography.fontSize
                                        } else if let editingText = editingText {
                                            return editingText.typography.fontSize
                                        } else {
                                            return document.fontManager.selectedFontSize
                                        }
                                    },
                                    set: { newSize in
                                        if let _ = selectedText {
                                            updateSelectedTextProperties(action: "Changed font size") { text in
                                                text.typography.fontSize = newSize
                                                if text.typography.lineHeight > 0 {
                                                    text.typography.lineHeight = newSize
                                                }
                                            }
                                        } else {
                                            document.fontManager.selectedFontSize = newSize
                                            // keep default line height synced
                                            document.fontManager.selectedLineHeight = newSize
                                            document.objectWillChange.send()
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
                                        if let _ = selectedText {
                                            updateTextAlignment(.left)
                                        } else {
                                            document.fontManager.selectedTextAlignment = .left
                                            document.objectWillChange.send()
                                        }
                                    } label: {
                                        Image(systemName: "text.alignleft")
                                            .font(.system(size: 14))
                                            .foregroundColor(currentTextAlignment == .left ? .white : .primary)
                                            .frame(width: 36, height: 28)
                                            .background(currentTextAlignment == .left ? Color.blue : Color.clear)
                                            .cornerRadius(4)
                                            .contentShape(Rectangle()) // Extend hit area to match entire frame area
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .help("Align Left")
                                    
                                    // Center Align
                                    Button {
                                        if let _ = selectedText {
                                            updateTextAlignment(.center)
                                        } else {
                                            document.fontManager.selectedTextAlignment = .center
                                            document.objectWillChange.send()
                                        }
                                    } label: {
                                        Image(systemName: "text.aligncenter")
                                            .font(.system(size: 14))
                                            .foregroundColor(currentTextAlignment == .center ? .white : .primary)
                                            .frame(width: 36, height: 28)
                                            .background(currentTextAlignment == .center ? Color.blue : Color.clear)
                                            .cornerRadius(4)
                                            .contentShape(Rectangle()) // Extend hit area to match entire frame area
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .help("Align Center")
                                    
                                    // Right Align
                                    Button {
                                        if let _ = selectedText {
                                            updateTextAlignment(.right)
                                        } else {
                                            document.fontManager.selectedTextAlignment = .right
                                            document.objectWillChange.send()
                                        }
                                    } label: {
                                        Image(systemName: "text.alignright")
                                            .font(.system(size: 14))
                                            .foregroundColor(currentTextAlignment == .right ? .white : .primary)
                                            .frame(width: 36, height: 28)
                                            .background(currentTextAlignment == .right ? Color.blue : Color.clear)
                                            .cornerRadius(4)
                                            .contentShape(Rectangle()) // Extend hit area to match entire frame area
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .help("Align Right")
                                    
                                    // Justify
                                    Button {
                                        if let _ = selectedText {
                                            updateTextAlignment(.justified)
                                        } else {
                                            document.fontManager.selectedTextAlignment = .justified
                                            document.objectWillChange.send()
                                        }
                                    } label: {
                                        Image(systemName: "text.justify")
                                            .font(.system(size: 14))
                                            .foregroundColor(currentTextAlignment == .justified ? .white : .primary)
                                            .frame(width: 36, height: 28)
                                            .background(currentTextAlignment == .justified ? Color.blue : Color.clear)
                                            .cornerRadius(4)
                                            .contentShape(Rectangle()) // Extend hit area to match entire frame area
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .help("Justify")
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 8) // Apply same hit area padding as vertical toolbar
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
                                        if let _ = selectedText {
                                            updateLineSpacing(newSpacing)
                                        } else {
                                            document.fontManager.selectedLineSpacing = Double(newSpacing)
                                            document.objectWillChange.send()
                                        }
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
                                        if let _ = selectedText {
                                            updateLineHeight(newHeight)
                                        } else {
                                            document.fontManager.selectedLineHeight = Double(newHeight)
                                            document.objectWillChange.send()
                                        }
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
                            
                            // PROFESSIONAL TEXT TO OUTLINES CONVERSION (Professional Standard)
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
            Log.fileOperation("🔧 FONT PANEL: Tool changed from \(oldTool.rawValue) to \(newTool.rawValue)", level: .info)
            Log.info("🔒 PROTECTION: Font settings remain isolated per text box UUID - no syncing", category: .general)
            
            // Log current text box states for debugging
            if let editingText = editingText {
                Log.fileOperation("🎯 EDITING UUID: \(editingText.id.uuidString.prefix(8)) - BLUE state maintained", level: .info)
            }
            if let selectedText = selectedText {
                Log.fileOperation("🎯 SELECTED UUID: \(selectedText.id.uuidString.prefix(8)) - GREEN state maintained", level: .info)
            }
            if selectedText == nil && editingText == nil {
                Log.fileOperation("🎯 NO TEXT SELECTED - showing document defaults for new text creation", level: .info)
            }
            
            // REMOVED: Property cache clearing - no longer needed
        }
        .onChange(of: document.selectedTextIDs) { oldIDs, newIDs in
            // CRITICAL PROTECTION: Log text selection changes to ensure UUID tracking works
            let removedIDs = oldIDs.subtracting(newIDs)
            let addedIDs = newIDs.subtracting(oldIDs)
            
            for removedID in removedIDs {
                Log.fileOperation("🎯 TEXT DESELECTED: \(removedID.uuidString.prefix(8)) - font settings preserved", level: .info)
            }
            for addedID in addedIDs {
                Log.fileOperation("🎯 TEXT SELECTED: \(addedID.uuidString.prefix(8)) - loading unique font settings", level: .info)
            }
            
            // Update last logged selection state safely
            if let newSelectedText = selectedText {
                if newSelectedText.id != lastLoggedSelection {
                    lastLoggedSelection = newSelectedText.id
                    Log.fileOperation("🎯 FONT PANEL: Found selected text - UUID: \(newSelectedText.id.uuidString.prefix(8)), Line Spacing: \(newSelectedText.typography.lineSpacing)", level: .info)
                }
            } else {
                if lastLoggedSelection != nil {
                    lastLoggedSelection = nil
                    Log.fileOperation("🎯 FONT PANEL: No selected text found - selectedTextIDs count: \(document.selectedTextIDs.count)", level: .info)
                }
            }
        }
        .onChange(of: document.textObjects) { oldTextObjects, newTextObjects in
            // Update last logged editing state safely
            if let newEditingText = editingText {
                if newEditingText.id != lastLoggedEditing {
                    lastLoggedEditing = newEditingText.id
                    Log.fileOperation("🎯 FONT PANEL: Found editing text - UUID: \(newEditingText.id.uuidString.prefix(8))", level: .info)
                }
            } else {
                if lastLoggedEditing != nil {
                    lastLoggedEditing = nil
                    Log.fileOperation("🎯 FONT PANEL: No editing text found", level: .info)
                }
            }
        }
    }
    
    // REMOVED: Property caching state variables that were causing infinite loops
    
    // NEW: Helper properties for text alignment and line spacing
    private var currentTextAlignment: NSTextAlignment {
        if let selectedText = selectedText {
            return selectedText.typography.alignment.nsTextAlignment
        } else if let editingText = editingText {
            return editingText.typography.alignment.nsTextAlignment
        } else {
            return document.fontManager.selectedTextAlignment.nsTextAlignment
        }
    }
    
    // FIXED: Simple computed property without state modifications
    private var currentLineSpacing: CGFloat {
        if let selectedText = selectedText {
            return selectedText.typography.lineSpacing
        } else if let editingText = editingText {
            return editingText.typography.lineSpacing
        } else {
            return document.fontManager.selectedLineSpacing
        }
    }
    
    // FIXED: Simple computed property without state modifications
    private var currentLineHeight: CGFloat {
        if let selectedText = selectedText {
            return selectedText.typography.lineHeight
        } else if let editingText = editingText {
            return editingText.typography.lineHeight
        } else {
            return document.fontManager.selectedLineHeight
        }
    }
    
    // FIXED: Simple computed property without state modifications
    private var currentFontSize: CGFloat {
        if let selectedText = selectedText {
            return selectedText.typography.fontSize
        } else if let editingText = editingText {
            return editingText.typography.fontSize
        } else {
            return document.fontManager.selectedFontSize
        }
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
                Log.fileOperation("⚠️ PREVENTED DUPLICATE: Skipping already processed textbox UUID \(textID.uuidString.prefix(8))", level: .info)
                continue
            }
            
            if let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) {
                let originalTypography = document.textObjects[textIndex].typography
                update(&document.textObjects[textIndex])
                let updatedTypography = document.textObjects[textIndex].typography
                
                // Log the specific changes for this UUID
                if originalTypography != updatedTypography {
                    Log.fileOperation("🎯 FONT SETTINGS UPDATE: UUID \(textID.uuidString.prefix(8))", level: .info)
                    Log.info("  - Action: \(action)", category: .general)
                    Log.info("  - Font: \(updatedTypography.fontFamily) \(updatedTypography.fontWeight.rawValue) \(updatedTypography.fontStyle.rawValue)", category: .general)
                    Log.info("  - Size: \(updatedTypography.fontSize)pt", category: .general)
                    
                    // CRITICAL FIX: Update typography in unified objects and layers array to prevent reset on color change
                    document.updateTextTypographyInUnified(id: textID, typography: updatedTypography)
                } else {
                    Log.fileOperation("🎯 NO CHANGE: UUID \(textID.uuidString.prefix(8)) - font settings unchanged", level: .info)
                }
                
                processedUUIDs.insert(textID)
            }
        }
        
        Log.fileOperation("🔧 FONT PANEL: \(action) - Processed \(processedUUIDs.count) unique text box UUIDs", level: .info)
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
    private func createPreviewFont(family: String, weight: FontWeight, style: FontStyle) -> Font {
        // First try to get the exact font name from the font manager
        let fontManager = NSFontManager.shared
        let members = fontManager.availableMembers(ofFontFamily: family) ?? []
        
        // Find the best matching font member for the weight and style
        for member in members {
            if let fontName = member[1] as? String,
               let weightNumber = member[2] as? NSNumber,
               let traits = member[3] as? NSNumber {
                
                let memberWeight = mapNSWeightToFontWeight(weightNumber.intValue)
                let traitMask = NSFontDescriptor.SymbolicTraits(rawValue: UInt32(traits.intValue))
                let memberStyle: FontStyle = traitMask.contains(.italic) ? .italic : .normal
                
                // Check if this member matches our desired weight and style
                if memberWeight == weight && memberStyle == style {
                    if NSFont(name: fontName, size: 12) != nil {
                        return Font.custom(fontName, size: 12)
                    }
                }
            }
        }
        
        // Fallback: try to create font with descriptor
        let descriptor = NSFontDescriptor(name: family, size: 12)
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
            // Final fallback: use system font with weight
            return Font.system(size: 12, weight: weight.systemWeight, design: .default)
        }
    }
    
    // Helper function to map NS weight to FontWeight
    private func mapNSWeightToFontWeight(_ nsWeight: Int) -> FontWeight {
        switch nsWeight {
        case 0...2: return .thin
        case 3: return .ultraLight
        case 4: return .light
        case 5: return .regular
        case 6: return .medium
        case 7...8: return .semibold
        case 9: return .bold
        case 10...11: return .heavy
        default: return .black
        }
    }
    
    // Validate and update weight/style when font changes
    private func validateAndUpdateWeightAndStyle() {
        let weights = availableFontWeights
        let styles = availableFontStyles
        
        Log.fileOperation("🎯 FONT PANEL: Validating font options for family: \(currentFontFamily)", level: .info)
        Log.info("  - Available weights: \(weights.map { $0.rawValue })", category: .general)
        Log.info("  - Available styles: \(styles.map { $0.rawValue })", category: .general)
        
        if let _ = selectedText {
            // Update selected text's weight/style if invalid - NO document.fontManager changes
            updateSelectedTextProperties(action: "Validated font weight/style") { text in
                if !weights.contains(text.typography.fontWeight) {
                    print("🎯 FONT PANEL: Updating weight from \(text.typography.fontWeight.rawValue) to \(weights.first?.rawValue ?? "regular")")
                    text.typography.fontWeight = weights.first ?? .regular
                }
                if !styles.contains(text.typography.fontStyle) {
                    print("🎯 FONT PANEL: Updating style from \(text.typography.fontStyle.rawValue) to \(styles.first?.rawValue ?? "normal")")
                    text.typography.fontStyle = styles.first ?? .normal
                }
            }
        } else {
            // Update document font manager for new text creation only
            if !weights.contains(document.fontManager.selectedFontWeight) {
                print("🎯 FONT PANEL: Updating document weight from \(document.fontManager.selectedFontWeight.rawValue) to \(weights.first?.rawValue ?? "regular")")
                document.fontManager.selectedFontWeight = weights.first ?? .regular
            }
            if !styles.contains(document.fontManager.selectedFontStyle) {
                print("🎯 FONT PANEL: Updating document style from \(document.fontManager.selectedFontStyle.rawValue) to \(styles.first?.rawValue ?? "normal")")
                document.fontManager.selectedFontStyle = styles.first ?? .normal
            }
        }
    }
    
    // REMOVED: stroke support functions - keeping only fill
    
    private func convertSelectedTextToOutlines() {
        guard !document.selectedTextIDs.isEmpty else { 
            Log.error("❌ CONVERT TO OUTLINES: No text selected", category: .error)
            return 
        }
        
        Log.fileOperation("🎯 FONT PANEL: Starting text to outlines conversion", level: .info)
        Log.info("   Selected text IDs: \(document.selectedTextIDs.map { $0.uuidString.prefix(8) })", category: .general)
        Log.info("   Selected layer index: \(document.selectedLayerIndex ?? -1)", category: .general)
        Log.info("   Total layers: \(document.layers.count)", category: .general)
        
        // Check if we have a valid layer selection
        if let layerIndex = document.selectedLayerIndex {
            if layerIndex >= 0 && layerIndex < document.layers.count {
                let layer = document.layers[layerIndex]
                Log.info("   Target layer: '\(layer.name)' (locked: \(layer.isLocked))", category: .general)
                
                if layer.isLocked {
                    Log.error("❌ CONVERT TO OUTLINES FAILED: Selected layer '\(layer.name)' is locked", category: .error)
                    return
                }
            } else {
                Log.error("❌ CONVERT TO OUTLINES FAILED: Invalid layer index \(layerIndex)", category: .error)
                return
            }
        } else {
            Log.info("   No layer selected - will use fallback layer", category: .general)
        }
        
        // Use the CORRECT method that calls YOUR multi-line Core Text implementation
        document.convertSelectedTextToOutlines()
        
        Log.fileOperation("🎯 FONT PANEL: Converting text to vector outlines using YOUR multi-line Core Text implementation", level: .info)
        
        // VERIFICATION: Check if text was actually removed
        let remainingTextCount = document.allTextObjects.count
        Log.fileOperation("🎯 VERIFICATION: \(remainingTextCount) text objects remaining after conversion", level: .info)
        
        if remainingTextCount > 0 {
            Log.info("📋 REMAINING TEXT OBJECTS:", category: .general)
            for (index, textObj) in document.allTextObjects.enumerated() {
                Log.info("   \(index): '\(textObj.content)' (ID: \(textObj.id.uuidString.prefix(8)))", category: .general)
            }
        }
        
        // FINAL VERIFICATION: Check unified objects system
        let textUnifiedObjects = document.unifiedObjects.filter { unifiedObject in
            if case .shape(let shape) = unifiedObject.objectType {
                return shape.isTextObject
            }
            return false
        }
        
        Log.fileOperation("🎯 FINAL VERIFICATION: \(textUnifiedObjects.count) text objects in unified system", level: .info)
        
        if textUnifiedObjects.count != remainingTextCount {
            Log.error("❌ UNIFIED OBJECTS MISMATCH: \(textUnifiedObjects.count) in unified system vs \(remainingTextCount) in textObjects array", category: .error)
        } else {
            Log.info("✅ UNIFIED OBJECTS VERIFICATION: Text objects properly synchronized", category: .general)
        }
    }
} 