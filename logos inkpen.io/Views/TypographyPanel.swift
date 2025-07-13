//
//  TypographyPanel.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI
import AppKit

/// Professional typography controls panel matching Adobe Illustrator standards
struct TypographyPanel: View {
    @ObservedObject var document: VectorDocument
    @State private var availableFonts: [String] = []
    @State private var fontSizeText: String = "24"
    @State private var letterSpacingText: String = "0"
    @State private var lineHeightText: String = "28.8"
    
    var selectedText: VectorText? {
        document.textObjects.first { document.selectedTextIDs.contains($0.id) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Panel Header
            HStack {
                Image(systemName: "textformat")
                    .foregroundColor(.primary)
                Text("Typography")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Typography Controls
            VStack(spacing: 12) {
                    // Font Family Selection (Professional)
                    fontFamilySection
                    
                    Divider()
                    
                    // Font Weight and Style
                    fontWeightStyleSection
                    
                    Divider()
                    
                    // Font Size and Measurements
                    fontSizeSection
                    
                    Divider()
                    
                    // Text Alignment
                    textAlignmentSection
                    
                    Divider()
                    
                    // Text Color and Opacity
                    textColorSection
                    
                    Divider()
                    
                    // Text Stroke/Fill (Professional Adobe Illustrator Style)
                    textStrokeFillSection
                    
                    Divider()
                    
                    // Professional Text Actions
                    textActionsSection
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
        .onAppear {
            loadAvailableFonts()
            updateUIFromSelectedText()
        }
        .onChange(of: document.selectedTextIDs) { oldValue, newValue in
            updateUIFromSelectedText()
        }
    }
    
    // MARK: - Font Family Section
    @ViewBuilder
    private var fontFamilySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Font Family")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            // Professional font picker dropdown
            Menu {
                ForEach(availableFonts.prefix(50), id: \.self) { fontName in // Limit for performance
                    Button(fontName) {
                        applyFontFamily(fontName)
                    }
                    .font(.custom(fontName, size: 14))
                }
            } label: {
                HStack {
                    Text(selectedText?.typography.fontFamily ?? "Helvetica")
                        .font(.custom(selectedText?.typography.fontFamily ?? "Helvetica", size: 14))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(NSColor.textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Font Weight and Style Section
    @ViewBuilder
    private var fontWeightStyleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Weight & Style")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            HStack(spacing: 8) {
                // Font Weight Picker
                Menu {
                    ForEach(FontWeight.allCases, id: \.self) { weight in
                        Button(weight.rawValue.capitalized) {
                            applyFontWeight(weight)
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedText?.typography.fontWeight.rawValue.capitalized ?? "Regular")
                            .font(.system(size: 12))
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                    )
                }
                
                // Font Style Toggle Buttons
                HStack(spacing: 4) {
                    // Italic Toggle
                    Button(action: { toggleFontStyle(.italic) }) {
                        Text("I")
                            .font(.system(size: 12, weight: .medium, design: .serif))
                            .italic()
                            .foregroundColor(selectedText?.typography.fontStyle == .italic ? .white : .primary)
                            .frame(width: 24, height: 24)
                            .background(selectedText?.typography.fontStyle == .italic ? Color.blue : Color(NSColor.textBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Font Size Section
    @ViewBuilder
    private var fontSizeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Size & Spacing")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Text("Size")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 35, alignment: .leading)
                    
                    TextField("Size", text: $fontSizeText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                        .font(.system(size: 11, design: .monospaced))
                        .onSubmit {
                            if let size = Double(fontSizeText), size > 0 {
                                applyFontSize(size)
                            }
                        }
                }
                
                HStack(spacing: 6) {
                    Text("Track")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 35, alignment: .leading)
                    
                    TextField("0", text: $letterSpacingText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                        .font(.system(size: 11, design: .monospaced))
                        .onSubmit {
                            if let spacing = Double(letterSpacingText) {
                                applyLetterSpacing(spacing)
                            }
                        }
                }
                
                HStack(spacing: 6) {
                    Text("Lead")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 35, alignment: .leading)
                    
                    TextField("Auto", text: $lineHeightText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                        .font(.system(size: 11, design: .monospaced))
                        .onSubmit {
                            if let height = Double(lineHeightText), height > 0 {
                                applyLineHeight(height)
                            }
                        }
                }
            }
        }
    }
    
    // MARK: - Text Alignment Section
    @ViewBuilder
    private var textAlignmentSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Alignment")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            HStack(spacing: 4) {
                ForEach(TextAlignment.allCases, id: \.self) { alignment in
                    Button(action: { applyTextAlignment(alignment) }) {
                        Image(systemName: alignment.iconName)
                            .font(.system(size: 12))
                            .foregroundColor(selectedText?.typography.alignment == alignment ? .white : .primary)
                            .frame(width: 28, height: 24)
                            .background(selectedText?.typography.alignment == alignment ? Color.blue : Color(NSColor.textBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(alignment.rawValue)
                }
            }
        }
    }
    
    // MARK: - Text Color Section
    @ViewBuilder
    private var textColorSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Color & Opacity")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            HStack(spacing: 8) {
                // Color Picker
                ColorPicker("Color", selection: textColorBinding)
                    .labelsHidden()
                    .frame(width: 40, height: 24)
                
                // Opacity Slider
                VStack(alignment: .leading, spacing: 2) {
                    Text("Opacity")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Slider(value: textOpacityBinding, in: 0...1)
                        .frame(width: 80)
                }
                
                // Opacity Value
                Text("\(Int((selectedText?.typography.fillOpacity ?? 1.0) * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 35)
            }
        }
    }
    
    // MARK: - Text Stroke/Fill Section
    @ViewBuilder
    private var textStrokeFillSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Stroke & Fill")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            // Stroke Controls
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Text("Stroke")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 35, alignment: .leading)
                    
                    ColorPicker("Stroke", selection: textStrokeColorBinding)
                        .labelsHidden()
                        .frame(width: 32, height: 20)
                    
                    Slider(value: textStrokeOpacityBinding, in: 0...1)
                        .frame(maxWidth: .infinity)
                    
                    Text("\(Int((selectedText?.typography.strokeOpacity ?? 1.0) * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 30)
                }
                
                HStack(spacing: 6) {
                    Text("Fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 35, alignment: .leading)
                    
                    ColorPicker("Fill", selection: textFillColorBinding)
                        .labelsHidden()
                        .frame(width: 32, height: 20)
                    
                    Slider(value: textFillOpacityBinding, in: 0...1)
                        .frame(maxWidth: .infinity)
                    
                    Text("\(Int((selectedText?.typography.fillOpacity ?? 1.0) * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 30)
                }
            }
        }
    }
    
    // MARK: - Computed Bindings
    private var textColorBinding: Binding<Color> {
        Binding(
            get: { selectedText?.typography.fillColor.color ?? .black },
            set: { color in
                // Convert SwiftUI Color to VectorColor
                let cgColor = color.cgColor
                if let components = cgColor?.components, components.count >= 3 {
                    let vectorColor = VectorColor.rgb(RGBColor(
                        red: Double(components[0]),
                        green: Double(components[1]),
                        blue: Double(components[2]),
                        alpha: components.count > 3 ? Double(components[3]) : 1.0
                    ))
                    applyTextColor(vectorColor)
                }
            }
        )
    }
    
    private var textOpacityBinding: Binding<Double> {
        Binding(
            get: { selectedText?.typography.fillOpacity ?? 1.0 },
            set: { applyTextOpacity($0) }
        )
    }
    
    // MARK: - Text Stroke/Fill Bindings
    private var textStrokeColorBinding: Binding<Color> {
        Binding(
            get: { selectedText?.typography.strokeColor.color ?? .black },
            set: { color in
                let cgColor = color.cgColor
                if let components = cgColor?.components, components.count >= 3 {
                    let vectorColor = VectorColor.rgb(RGBColor(
                        red: Double(components[0]),
                        green: Double(components[1]),
                        blue: Double(components[2]),
                        alpha: components.count > 3 ? Double(components[3]) : 1.0
                    ))
                    applyTextStrokeColor(vectorColor)
                }
            }
        )
    }
    
    private var textStrokeOpacityBinding: Binding<Double> {
        Binding(
            get: { selectedText?.typography.strokeOpacity ?? 1.0 },
            set: { applyTextStrokeOpacity($0) }
        )
    }
    
    private var textFillColorBinding: Binding<Color> {
        Binding(
            get: { selectedText?.typography.fillColor.color ?? .black },
            set: { color in
                let cgColor = color.cgColor
                if let components = cgColor?.components, components.count >= 3 {
                    let vectorColor = VectorColor.rgb(RGBColor(
                        red: Double(components[0]),
                        green: Double(components[1]),
                        blue: Double(components[2]),
                        alpha: components.count > 3 ? Double(components[3]) : 1.0
                    ))
                    applyTextFillColor(vectorColor)
                }
            }
        )
    }
    
    private var textFillOpacityBinding: Binding<Double> {
        Binding(
            get: { selectedText?.typography.fillOpacity ?? 1.0 },
            set: { applyTextFillOpacity($0) }
        )
    }
    
    // MARK: - Text Actions Section
    @ViewBuilder
    private var textActionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Actions")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            HStack(spacing: 8) {
                // CRITICAL: Text to Outlines Button (Professional Feature)
                Button("Convert to Outlines") {
                    convertSelectedTextToOutlines()
                }
                .buttonStyle(.borderedProminent)
                .font(.caption)
                .help("Convert text to vector paths (Cmd+Shift+O)")
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .disabled(selectedText == nil)
                
                // Duplicate Text
                Button("Duplicate") {
                    document.duplicateSelectedText()
                }
                .buttonStyle(.bordered)
                .font(.caption)
                .disabled(selectedText == nil)
                
                // Delete Text
                Button("Delete") {
                    document.removeSelectedText()
                }
                .buttonStyle(.bordered)
                .font(.caption)
                .foregroundColor(.red)
                .disabled(selectedText == nil)
            }
        }
    }
    
    // MARK: - Professional Typography Actions
    
    private func loadAvailableFonts() {
        availableFonts = NSFontManager.shared.availableFontFamilies.sorted()
    }
    
    private func updateUIFromSelectedText() {
        guard let text = selectedText else { return }
        
        fontSizeText = String(format: "%.1f", text.typography.fontSize)
        letterSpacingText = String(format: "%.1f", text.typography.letterSpacing)
        lineHeightText = String(format: "%.1f", text.typography.lineHeight)
    }
    
    private func applyFontFamily(_ fontFamily: String) {
        guard let textID = document.selectedTextIDs.first else { return }
        document.updateTextTypography(textID) { typography in
            typography.fontFamily = fontFamily
        }
    }
    
    private func applyFontWeight(_ weight: FontWeight) {
        guard let textID = document.selectedTextIDs.first else { return }
        document.updateTextTypography(textID) { typography in
            typography.fontWeight = weight
        }
    }
    
    private func toggleFontStyle(_ style: FontStyle) {
        guard let textID = document.selectedTextIDs.first else { return }
        document.updateTextTypography(textID) { typography in
            typography.fontStyle = typography.fontStyle == style ? .normal : style
        }
    }
    
    private func applyFontSize(_ size: Double) {
        guard let textID = document.selectedTextIDs.first else { return }
        document.updateTextTypography(textID) { typography in
            typography.fontSize = size
            // Auto-adjust line height (120% of font size)
            typography.lineHeight = size * 1.2
        }
        lineHeightText = String(format: "%.1f", size * 1.2)
    }
    
    private func applyLetterSpacing(_ spacing: Double) {
        guard let textID = document.selectedTextIDs.first else { return }
        document.updateTextTypography(textID) { typography in
            typography.letterSpacing = spacing
        }
    }
    
    private func applyLineHeight(_ height: Double) {
        guard let textID = document.selectedTextIDs.first else { return }
        document.updateTextTypography(textID) { typography in
            typography.lineHeight = height
        }
    }
    
    private func applyTextAlignment(_ alignment: TextAlignment) {
        guard let textID = document.selectedTextIDs.first else { return }
        document.updateTextTypography(textID) { typography in
            typography.alignment = alignment
        }
    }
    
    private func applyTextColor(_ color: VectorColor) {
        guard let textID = document.selectedTextIDs.first else { return }
        document.updateTextTypography(textID) { typography in
            typography.fillColor = color
        }
    }
    
    private func applyTextOpacity(_ opacity: Double) {
        guard let textID = document.selectedTextIDs.first else { return }
        document.updateTextTypography(textID) { typography in
            typography.fillOpacity = opacity
        }
    }
    
    private func applyTextStrokeColor(_ color: VectorColor) {
        guard let textID = document.selectedTextIDs.first else { return }
        document.updateTextTypography(textID) { typography in
            typography.strokeColor = color
        }
    }
    
    private func applyTextStrokeOpacity(_ opacity: Double) {
        guard let textID = document.selectedTextIDs.first else { return }
        document.updateTextTypography(textID) { typography in
            typography.strokeOpacity = opacity
        }
    }
    
    private func applyTextFillColor(_ color: VectorColor) {
        guard let textID = document.selectedTextIDs.first else { return }
        document.updateTextTypography(textID) { typography in
            typography.fillColor = color
        }
    }
    
    private func applyTextFillOpacity(_ opacity: Double) {
        guard let textID = document.selectedTextIDs.first else { return }
        document.updateTextTypography(textID) { typography in
            typography.fillOpacity = opacity
        }
    }
    
    // CRITICAL PROFESSIONAL FEATURE: Text to Outlines
    private func convertSelectedTextToOutlines() {
        guard let textID = document.selectedTextIDs.first else { return }
        
        // This will trigger the text-to-outlines conversion
        document.convertTextToOutlines(textID)
        
        print("🎯 Converting text to vector outlines (Adobe Illustrator / FreeHand professional feature)")
    }
}

// MARK: - Preview
struct TypographyPanel_Previews: PreviewProvider {
    static var previews: some View {
        let document = VectorDocument()
        
        return TypographyPanel(document: document)
            .frame(width: 280)
            .padding()
            .previewLayout(.sizeThatFits)
    }
} 
