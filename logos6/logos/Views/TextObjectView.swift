//
//  TextObjectView.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI
import CoreText

/// Professional text object rendering with Adobe Illustrator-style text editing
struct TextObjectView: View {
    let textObject: VectorText
    let isSelected: Bool
    let isEditing: Bool
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let onTextChange: (String) -> Void
    let onEditingChanged: (Bool) -> Void
    
    @State private var editingText: String = ""
    @State private var showCursor = true
    @State private var cursorPosition: Int = 0
    @FocusState private var isTextFieldFocused: Bool
    
    private let cursorTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            if isEditing {
                // PROFESSIONAL INLINE TEXT EDITING (Adobe Illustrator-style)
                editingTextView
            } else {
                // NORMAL TEXT DISPLAY
                displayTextView
            }
            
            // PROFESSIONAL SELECTION OUTLINE
            if isSelected && !isEditing {
                selectionOutline
            }
        }
        // PROFESSIONAL COORDINATE SYSTEM: Fix text positioning with proper zoom/offset order
        .transformEffect(textObject.transform)
        .position(
            x: (textObject.position.x * zoomLevel) + canvasOffset.x,
            y: (textObject.position.y * zoomLevel) + canvasOffset.y
        )
        .scaleEffect(zoomLevel)
        .onAppear {
            editingText = textObject.content
        }
        .onChange(of: textObject.content) { oldValue, newValue in
            editingText = newValue
        }
        .onChange(of: isEditing) { oldValue, newValue in
            if newValue {
                editingText = textObject.content
                cursorPosition = textObject.content.count
                isTextFieldFocused = true
            } else {
                isTextFieldFocused = false
            }
        }
    }
    
    @ViewBuilder
    private var editingTextView: some View {
        ZStack(alignment: .leading) {
            // Background for editing visibility
            Rectangle()
                .fill(Color.white.opacity(0.9))
                .overlay(
                    Rectangle()
                        .stroke(Color.blue, lineWidth: 1.0)
                )
                .frame(
                    width: max(textSize.width + 20, 100),
                    height: textSize.height + 10
                )
            
            // Professional text field for editing
            TextField("Text", text: $editingText, axis: .vertical)
                .font(nsFont)
                .foregroundColor(textObject.typography.fillColor.color)
                .textFieldStyle(.plain)
                .focused($isTextFieldFocused)
                .multilineTextAlignment(textObject.typography.alignment.textAlignment)
                .onSubmit {
                    finishTextEditing()
                }
                .onChange(of: editingText) { oldValue, newValue in
                    // Real-time text update (Adobe Illustrator behavior)
                    onTextChange(newValue)
                }
                .onChange(of: isTextFieldFocused) { oldValue, newValue in
                    // Professional behavior: Exit editing when focus is lost (Adobe Illustrator standard)
                    if !newValue && isEditing {
                        finishTextEditing()
                    }
                }
                .frame(
                    width: max(textSize.width + 16, 96),
                    height: textSize.height + 6
                )
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
        }
        .onReceive(cursorTimer) { _ in
            if isEditing {
                showCursor.toggle()
            }
        }
    }
    
    @ViewBuilder
    private var displayTextView: some View {
        Text(textObject.content)
            .font(nsFont)
            .foregroundColor(textObject.typography.fillColor.color.opacity(textObject.typography.fillOpacity))
            .multilineTextAlignment(textObject.typography.alignment.textAlignment)
            .lineSpacing(textObject.typography.lineHeight - textObject.typography.fontSize)
            .kerning(textObject.typography.letterSpacing)
            .frame(
                width: textSize.width,
                height: textSize.height,
                alignment: textAlignment
            )
    }
    
    @ViewBuilder
    private var selectionOutline: some View {
        Rectangle()
            .stroke(Color.blue, lineWidth: 1.0) // Fixed line width for visibility
            .fill(Color.clear)
            .frame(
                width: textSize.width + 4,
                height: textSize.height + 4
            )
    }
    
    // MARK: - Professional Typography Calculations
    
    private var nsFont: Font {
        let weight: Font.Weight = {
            switch textObject.typography.fontWeight {
            case .thin: return .thin
            case .ultraLight: return .ultraLight
            case .light: return .light
            case .regular: return .regular
            case .medium: return .medium
            case .semibold: return .semibold
            case .bold: return .bold
            case .heavy: return .heavy
            case .black: return .black
            }
        }()
        
        let design: Font.Design = {
            switch textObject.typography.fontStyle {
            case .normal: return .default
            case .italic: return .default // Note: SwiftUI handles italic through weight/design combinations
            case .oblique: return .monospaced
            }
        }()
        
        return .custom(textObject.typography.fontFamily, size: textObject.typography.fontSize)
            .weight(weight)
    }
    
    private var textSize: CGSize {
        let attributedString = NSAttributedString(
            string: textObject.content.isEmpty ? "Text" : textObject.content,
            attributes: [
                .font: NSFont(name: textObject.typography.fontFamily, size: textObject.typography.fontSize) ?? NSFont.systemFont(ofSize: textObject.typography.fontSize),
                .kern: textObject.typography.letterSpacing
            ]
        )
        
        let constraintSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        let textRect = attributedString.boundingRect(
            with: constraintSize,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        
        return CGSize(
            width: max(textRect.width, 20), // Minimum width for empty text
            height: max(textRect.height, textObject.typography.fontSize) // Minimum height based on font size
        )
    }
    
    private var textAlignment: Alignment {
        switch textObject.typography.alignment {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        case .justified: return .leading // SwiftUI doesn't have justified, use leading
        }
    }
    
    // MARK: - Professional Text Editing Actions
    
    private func finishTextEditing() {
        // Professional behavior: finish editing and update final text
        onTextChange(editingText)
        onEditingChanged(false)
    }
}

// MARK: - TextAlignment Extension for SwiftUI Compatibility
extension TextAlignment {
    var textAlignment: SwiftUI.TextAlignment {
        switch self {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        case .justified: return .leading // SwiftUI limitation
        }
    }
}

// MARK: - Preview
struct TextObjectView_Previews: PreviewProvider {
    static var previews: some View {
        let typography = TypographyProperties(
            fontFamily: "Helvetica",
            fontWeight: .regular,
            fontStyle: .normal,
            fontSize: 24.0,
            lineHeight: 28.8,
            letterSpacing: 0.0,
            alignment: .left,
            fillColor: .black,
            fillOpacity: 1.0
        )
        
        let textObject = VectorText(
            content: "Sample Text",
            typography: typography,
            position: CGPoint(x: 100, y: 100)
        )
        
        return ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(width: 400, height: 300)
            
            TextObjectView(
                textObject: textObject,
                isSelected: true,
                isEditing: false,
                zoomLevel: 1.0,
                canvasOffset: .zero,
                onTextChange: { _ in },
                onEditingChanged: { _ in }
            )
        }
        .previewLayout(.sizeThatFits)
    }
} 