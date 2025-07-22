//
//  TextEditorViewModel.swift
//  Test
//
//  Created by Todd Bruss on 7/21/25.
//

import SwiftUI
import CoreText
import CoreGraphics

class TextEditorViewModel: ObservableObject {
    @Published var text: String = "Sample Text" {
        didSet {
            scheduleAutoResize()
        }
    }
    @Published var fontSize: CGFloat = 24 {
        didSet {
            guard !isUpdatingProperties else { return }
            isUpdatingProperties = true
            
            // Update the font when size changes
            if selectedFont.pointSize != fontSize {
                let fontName = selectedFont.fontName
                selectedFont = NSFont(name: fontName, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
            }
            
            isUpdatingProperties = false
            scheduleUpdateCursorPosition()
            scheduleAutoResize()
        }
    }
    @Published var selectedFont: NSFont = NSFont.systemFont(ofSize: 24) {
        didSet {
            guard !isUpdatingProperties else { return }
            isUpdatingProperties = true
            
            // Update the font size when font changes
            if fontSize != selectedFont.pointSize {
                fontSize = selectedFont.pointSize
            }
            
            isUpdatingProperties = false
            scheduleUpdateCursorPosition()
            scheduleAutoResize()
        }
    }
    @Published var cursorPosition: Int = 0
    @Published var textBoxFrame: CGRect = CGRect(x: 50, y: 50, width: 300, height: 100)
    @Published var isEditing: Bool = false
    @Published var showPath: Bool = false
    @Published var textPath: CGPath?
    @Published var textColor: Color = .black {
        didSet {
            if isEditing {
                updateCursorColor()
            }
        }
    }
    @Published var textAlignment: NSTextAlignment = .left {
        didSet {
            scheduleUpdateCursorPosition()
            scheduleAutoResize()
            if isEditing {
                updateCursorColor()
            }
        }
    }
    @Published var lineSpacing: CGFloat = 0.0 {
        didSet {
            scheduleUpdateCursorPosition()
            scheduleAutoResize()
        }
    } // Line spacing in points
    @Published var autoExpandVertically: Bool = true // New property to control auto-expansion
    
    // Computed properties
    var safeFontName: String {
        return selectedFont.familyName ?? "System Font"
    }
    
    // Cursor properties
    @Published var cursorOffset: CGPoint = .zero
    @Published var cursorHeight: CGFloat = 24
    @Published var showCursor: Bool = false
    @Published var cursorColor: Color = .blue
    
    // Flag to prevent infinite loops during property updates
    private var isUpdatingProperties: Bool = false
    private var cursorTimer: Timer?
    private var minTextBoxHeight: CGFloat = 50 // Minimum height for the text box
    private var cursorFlashState: Bool = false // Track cursor flash state

    init() {
        // Don't start editing mode at initialization
        // startCursorBlinking() - only start when editing begins
        updateCursorPosition()
        scheduleAutoResize()
    }
    
    deinit {
        cursorTimer?.invalidate()
    }
    
    func startEditing() {
        isEditing = true
        showCursor = true
        startCursorBlinking()
    }
    
    func stopEditing() {
        isEditing = false
        showCursor = false
        cursorTimer?.invalidate()
    }
    
    private func startCursorBlinking() {
        cursorTimer?.invalidate()
        // Set initial cursor color
        updateCursorColor()
        
        cursorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            if self.isEditing {
                self.cursorFlashState.toggle()
                self.updateCursorColor()
            }
        }
    }
    
    private func updateCursorColor() {
        // Determine the two colors to flash between
        let isWhiteOrPastel = isColorWhiteOrPastel(textColor)
        let isRightJustified = textAlignment == .right
        
        if cursorFlashState {
            // First color: visible color based on conditions
            if isRightJustified {
                cursorColor = .white
            } else if isWhiteOrPastel {
                cursorColor = .black
            } else {
                cursorColor = textColor
            }
        } else {
            // Second color: always clear/transparent
            cursorColor = .clear
        }
    }
    
    private func isColorWhiteOrPastel(_ color: Color) -> Bool {
        // Convert SwiftUI Color to NSColor and ensure it's in RGB color space
        let nsColor = NSColor(color)
        
        // Convert to device RGB color space to ensure getRed:green:blue:alpha: works
        guard let rgbColor = nsColor.usingColorSpace(.deviceRGB) else {
            // Fallback: assume it's not white or pastel if we can't convert
            return false
        }
        
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        rgbColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Consider it white if all RGB values are close to 1.0
        let isWhite = red > 0.9 && green > 0.9 && blue > 0.9
        
        // Consider it pastel if all RGB values are above 0.7 (light/pale colors)
        let isPastel = red > 0.7 && green > 0.7 && blue > 0.7
        
        return isWhite || isPastel
    }
    
    // MARK: - Helper Methods
    
    private func scheduleUpdateCursorPosition() {
        DispatchQueue.main.async { [weak self] in
            self?.updateCursorPosition()
        }
    }
    
    private func scheduleAutoResize() {
        guard autoExpandVertically else { return }
        DispatchQueue.main.async { [weak self] in
            self?.autoResizeTextBoxHeight()
        }
    }
    

    
    private func autoResizeTextBoxHeight() {
        guard autoExpandVertically else { return }
        
        let requiredHeight = calculateRequiredHeight()
        let newHeight = max(minTextBoxHeight, requiredHeight)
        
        // Only update if height needs to change (reduced threshold for better responsiveness)
        if abs(textBoxFrame.height - newHeight) > 0.1 {
            let newFrame = CGRect(
                x: textBoxFrame.minX,
                y: textBoxFrame.minY,
                width: textBoxFrame.width,
                height: newHeight
            )
            textBoxFrame = newFrame
            scheduleUpdateCursorPosition()
        }
    }
    
    private func calculateRequiredHeight() -> CGFloat {
        guard !text.isEmpty else { return minTextBoxHeight }
        
        let fontName = selectedFont.fontName
        let font = CTFontCreateWithName(fontName as CFString, fontSize, nil)
        
        // Create paragraph style with alignment and line spacing
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = textAlignment
        paragraphStyle.lineSpacing = lineSpacing
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        
        let textWidth = textBoxFrame.width
        
        // Use Core Text to get the actual required size
        let suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter, 
            CFRangeMake(0, 0), 
            nil, 
            CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude), 
            nil
        )
        
        // Add some padding to ensure text fits properly
        return suggestedSize.height + 20
    }

    func insertText(_ newText: String) {
        let index = text.index(text.startIndex, offsetBy: min(cursorPosition, text.count))
        text.insert(contentsOf: newText, at: index)
        cursorPosition += newText.count
        scheduleUpdateCursorPosition()
        
        // Immediately trigger auto-resize for newlines
        if newText.contains("\n") {
            scheduleAutoResize()
        }
    }
    
    func deleteBackward() {
        guard cursorPosition > 0 else { return }
        let index = text.index(text.startIndex, offsetBy: cursorPosition - 1)
        text.remove(at: index)
        cursorPosition -= 1
        scheduleUpdateCursorPosition()
    }
    
    func moveCursor(to position: Int) {
        cursorPosition = max(0, min(position, text.count))
        scheduleUpdateCursorPosition()
    }
    
    func deleteForward() {
        guard cursorPosition < text.count else { return }
        let index = text.index(text.startIndex, offsetBy: cursorPosition)
        text.remove(at: index)
        scheduleUpdateCursorPosition()
    }
    
    func moveCursorUp() {
        let lines = getWrappedLines()
        guard lines.count > 1 else { return }
        
        // Find current line and position within line
        var currentLine = 0
        var charactersProcessed = 0
        var positionInLine = cursorPosition
        
        for (index, lineText) in lines.enumerated() {
            let lineLength = lineText.count + 1 // Add 1 for newline
            if charactersProcessed + lineLength > cursorPosition || index == lines.count - 1 {
                currentLine = index
                positionInLine = cursorPosition - charactersProcessed
                break
            }
            charactersProcessed += lineLength
        }
        
        // Move to previous line if possible
        if currentLine > 0 {
            let previousLineLength = lines[currentLine - 1].count
            let previousLineStart = charactersProcessed - (lines[currentLine].count + 1) - (lines[currentLine - 1].count + 1)
            let targetPosition = previousLineStart + min(positionInLine, previousLineLength)
            moveCursor(to: max(0, targetPosition))
        }
    }
    
    func moveCursorDown() {
        let lines = getWrappedLines()
        guard lines.count > 1 else { return }
        
        // Find current line and position within line
        var currentLine = 0
        var charactersProcessed = 0
        var positionInLine = cursorPosition
        
        for (index, lineText) in lines.enumerated() {
            let lineLength = lineText.count + 1 // Add 1 for newline
            if charactersProcessed + lineLength > cursorPosition || index == lines.count - 1 {
                currentLine = index
                positionInLine = cursorPosition - charactersProcessed
                break
            }
            charactersProcessed += lineLength
        }
        
        // Move to next line if possible
        if currentLine < lines.count - 1 {
            let nextLineLength = lines[currentLine + 1].count
            let nextLineStart = charactersProcessed + lines[currentLine].count + 1 // +1 for newline
            let targetPosition = nextLineStart + min(positionInLine, nextLineLength)
            moveCursor(to: min(targetPosition, text.count))
        }
    }
    
    func updateCursorPosition() {
        let fontName = selectedFont.fontName
        let font = CTFontCreateWithName(fontName as CFString, fontSize, nil)
        
        // Create paragraph style with alignment
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        paragraphStyle.alignment = textAlignment
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]
        
        // Calculate position within text box
        let padding: CGFloat = 0
        let lines = getWrappedLines()
        
        // Get proper line height using Core Text metrics including line spacing
        let lineHeight: CGFloat
        if !lines.isEmpty {
            let sampleAttributedString = NSAttributedString(string: "Ag", attributes: attributes)
            let sampleLine = CTLineCreateWithAttributedString(sampleAttributedString)
            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            var leading: CGFloat = 0
            CTLineGetTypographicBounds(sampleLine, &ascent, &descent, &leading)
            lineHeight = ascent + descent + leading + lineSpacing
        } else {
            lineHeight = fontSize + lineSpacing
        }
        
        guard !lines.isEmpty else {
            cursorOffset = CGPoint(
                x: textBoxFrame.minX + padding,
                y: textBoxFrame.minY + padding
            )
            cursorHeight = lineHeight
            return
        }
        
        var currentLine = 0
        var charactersProcessed = 0
        var cursorXPosition: CGFloat = 0
        
        // Improved line detection - use actual text structure instead of line count + 1
        for (index, lineText) in lines.enumerated() {
            let nextCharacterCount = charactersProcessed + lineText.count
            
            if cursorPosition <= nextCharacterCount || index == lines.count - 1 {
                currentLine = index
                break
            }
            
            // Add line length + 1 for newline (except for last line)
            charactersProcessed = nextCharacterCount + 1
        }
        
        let characterIndexInLine = cursorPosition - charactersProcessed
        let currentLineText = lines[currentLine]
        
        // Special handling for justified text - use NSTextView layout for accurate positioning
        if textAlignment == .justified && !currentLineText.isEmpty {
            // Create the same NSTextView setup as our display to get accurate positioning
            let textView = NSTextView()
            textView.textContainerInset = NSSize(width: 0, height: 0)
            textView.textContainer?.lineFragmentPadding = 0
            textView.textContainer?.containerSize = NSSize(width: textBoxFrame.width, height: textBoxFrame.height)
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .justified
            paragraphStyle.lineSpacing = lineSpacing
            
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont(name: selectedFont.fontName, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize),
                .paragraphStyle: paragraphStyle
            ]
            
            let attributedString = NSAttributedString(string: text, attributes: attrs)
            textView.textStorage?.setAttributedString(attributedString)
            textView.layoutManager?.ensureLayout(for: textView.textContainer!)
            
            // Get the actual cursor position from the NSTextView layout
            if let layoutManager = textView.layoutManager {
                
                // Ensure cursor position is within bounds
                let safeCursorPosition = min(cursorPosition, text.count)
                
                // Get the line fragment rect for this character position
                let glyphIndex = layoutManager.glyphIndexForCharacter(at: safeCursorPosition)
                let lineFragmentRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
                let glyphLocation = layoutManager.location(forGlyphAt: glyphIndex)
                
                // Calculate cursor position within the text box coordinate system
                cursorXPosition = padding + glyphLocation.x
                
                // Use line fragment Y position for vertical positioning
                let lineY = lineFragmentRect.minY
                currentLine = Int(lineY / lineHeight) // Update current line
                
                // Override the Y calculation for justified text
                cursorOffset = CGPoint(
                    x: textBoxFrame.minX + cursorXPosition,
                    y: textBoxFrame.minY + padding + lineY + lineFragmentRect.height * 0.8 // Position near baseline
                )
                
                // Set appropriate cursor height
                cursorHeight = lineFragmentRect.height * 0.8
                
                return // Exit early since we set cursorOffset directly
            } else {
                cursorXPosition = padding
            }
        }
        // Handle empty lines
        else if currentLineText.isEmpty {
            cursorXPosition = padding
        } else {
            let textInCurrentLineUpToCursor = String(currentLineText.prefix(characterIndexInLine))
            
            let currentLineAttributedString = NSAttributedString(string: textInCurrentLineUpToCursor, attributes: attributes)
            let currentLineCTLine = CTLineCreateWithAttributedString(currentLineAttributedString)
            let currentLineWidth = CTLineGetTypographicBounds(currentLineCTLine, nil, nil, nil)
            
            // Calculate alignment offset using trimmed line to ignore trailing spaces
            let textBoxWidth = textBoxFrame.width - (padding * 2)
            let trimmedLineText = currentLineText.trimmingTrailingWhitespace()
            let trimmedLineAttributedString = NSAttributedString(string: trimmedLineText, attributes: attributes)
            let trimmedLineCTLine = CTLineCreateWithAttributedString(trimmedLineAttributedString)
            let trimmedLineWidth = CTLineGetTypographicBounds(trimmedLineCTLine, nil, nil, nil)
            
            let alignmentOffset: CGFloat
            switch textAlignment {
            case .center:
                alignmentOffset = (textBoxWidth - trimmedLineWidth) / 2
            case .right:
                alignmentOffset = textBoxWidth - trimmedLineWidth
            default: // .left
                alignmentOffset = 0
            }
            
            cursorXPosition = padding + CGFloat(currentLineWidth) + alignmentOffset
        }
        
        // Get baseline offset for proper vertical alignment
        let sampleAttributedString = NSAttributedString(string: "Ag", attributes: attributes)
        let sampleLine = CTLineCreateWithAttributedString(sampleAttributedString)
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        CTLineGetTypographicBounds(sampleLine, &ascent, &descent, nil)
        
        // Calculate final cursor position with consistent line height
        let yPosition = textBoxFrame.minY + padding + CGFloat(currentLine) * lineHeight + ascent * 0.1
        
        cursorOffset = CGPoint(
            x: textBoxFrame.minX + cursorXPosition,
            y: yPosition
        )
        cursorHeight = ascent + descent // Use actual text height for cursor
    }
    
    func getWrappedLines() -> [String] {
        let fontName = selectedFont.fontName
        let font = CTFontCreateWithName(fontName as CFString, fontSize, nil)
        
        // Create paragraph style with line spacing and text alignment
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        paragraphStyle.alignment = textAlignment
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]
        
        // Split text by newlines first to handle empty lines properly
        let lines = text.components(separatedBy: "\n")
        var wrappedLines: [String] = []
        
        for line in lines {
            if line.isEmpty {
                // Add empty line to preserve newlines
                wrappedLines.append("")
            } else {
                // Process non-empty lines for text wrapping
                let attributedString = NSAttributedString(string: line, attributes: attributes)
                let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
                
                let textWidth = textBoxFrame.width
                let path = CGPath(rect: CGRect(x: 0, y: 0, width: textWidth, height: CGFloat.greatestFiniteMagnitude), transform: nil)
                let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, nil)
                
                let ctLines = CTFrameGetLines(frame)
                let lineCount = CFArrayGetCount(ctLines)
                
                if lineCount == 0 {
                    // Fallback: add the line as-is if Core Text can't process it
                    wrappedLines.append(line)
                } else {
                    var characterIndex = 0
                    for i in 0..<lineCount {
                        let ctLine = unsafeBitCast(CFArrayGetValueAtIndex(ctLines, i), to: CTLine.self)
                        let lineRange = CTLineGetStringRange(ctLine)
                        let lineText = String(line[line.index(line.startIndex, offsetBy: characterIndex)..<line.index(line.startIndex, offsetBy: characterIndex + lineRange.length)])
                        wrappedLines.append(lineText)
                        characterIndex += lineRange.length
                    }
                }
            }
        }
        
        return wrappedLines
    }
    
    func convertToPath() {
        convertToCoreTextPath()
    }
    
    private func convertToCoreTextPath() {
        let fontName = selectedFont.fontName
        let font = CTFontCreateWithName(fontName as CFString, fontSize, nil)
        
        // Create paragraph style with alignment and line spacing
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = textAlignment
        paragraphStyle.lineSpacing = lineSpacing
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        
        // Calculate the actual required height to prevent truncation
        let textWidth = textBoxFrame.width
        
        // First, get the suggested height for the text
        let suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter, 
            CFRangeMake(0, 0), 
            nil, 
            CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude), 
            nil
        )
        
        // Use the larger of the text box height or the required height to prevent truncation
        let frameHeight = max(textBoxFrame.height, suggestedSize.height + 20)
        
        let frameRect = CGRect(
            x: 0, 
            y: 0, 
            width: textWidth, 
            height: frameHeight
        )
        let framePath = CGPath(rect: frameRect, transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), framePath, nil)
        
        let path = CGMutablePath()
        let lines = CTFrameGetLines(frame)
        let lineCount = CFArrayGetCount(lines)
        
        // Get line origins - CRITICAL for correct positioning
        var lineOrigins = Array<CGPoint>(repeating: .zero, count: lineCount)
        CTFrameGetLineOrigins(frame, CFRangeMake(0, lineCount), &lineOrigins)
        
        for lineIndex in 0..<lineCount {
            let line = unsafeBitCast(CFArrayGetValueAtIndex(lines, lineIndex), to: CTLine.self)
            let lineOrigin = lineOrigins[lineIndex]
            
            let runs = CTLineGetGlyphRuns(line)
            let runCount = CFArrayGetCount(runs)
            
            for runIndex in 0..<runCount {
                let run = unsafeBitCast(CFArrayGetValueAtIndex(runs, runIndex), to: CTRun.self)
                let glyphCount = CTRunGetGlyphCount(run)
                
                for glyphIndex in 0..<glyphCount {
                    var glyph = CGGlyph()
                    var position = CGPoint()
                    
                    CTRunGetGlyphs(run, CFRangeMake(glyphIndex, 1), &glyph)
                    CTRunGetPositions(run, CFRangeMake(glyphIndex, 1), &position)
                    
                    if let glyphPath = CTFontCreatePathForGlyph(font, glyph, nil) {
                        // Use EXACT Core Text positioning - no manual line height calculation
                                            let glyphX = position.x + lineOrigin.x + textBoxFrame.minX
                    let glyphY = textBoxFrame.minY + (frameRect.height - lineOrigin.y)
                        
                        // Create transform that fixes the upside-down issue
                        var transform = CGAffineTransform(scaleX: 1.0, y: -1.0) // Flip Y axis
                        transform = transform.translatedBy(x: glyphX, y: -glyphY)
                        
                        path.addPath(glyphPath, transform: transform)
                    }
                }
            }
        }
        
        textPath = path
        showPath = true
    }
    
    func clearPaths() {
        showPath = false
        textPath = nil
    }
    
    func toggleDisplay() {
        showPath.toggle()
    }
    
    func updateTextBoxFrame(_ newFrame: CGRect) {
        textBoxFrame = newFrame
        scheduleUpdateCursorPosition()
        scheduleAutoResize()
    }
    
    // Create a rendered image for live text display with proper alignment support
    func createLiveTextImage() -> NSImage? {
        
        let padding: CGFloat = 0 // Match the same padding as text display
        let textWidth = textBoxFrame.width - (padding * 2)
        let textHeight = textBoxFrame.height - (padding * 2)
        
        // Create NSImage with proper size
        let image = NSImage(size: NSSize(width: textWidth, height: textHeight))
        
        image.lockFocus()
        
        // Get current graphics context
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return nil
        }
        
        // Clear the background
        context.clear(CGRect(x: 0, y: 0, width: textWidth, height: textHeight))
        
        // Create font
        let nsFont = NSFont(name: selectedFont.fontName, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
        
        // Calculate text rect for drawing
        let textRect = CGRect(x: 0, y: 0, width: textWidth, height: textHeight)
        
        // Create paragraph style with alignment and line spacing
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = textAlignment
        paragraphStyle.lineSpacing = lineSpacing
        
        // Draw fill text
        let fillAttributes: [NSAttributedString.Key: Any] = [
            .font: nsFont,
            .foregroundColor: NSColor(textColor),
            .paragraphStyle: paragraphStyle
        ]
        
        let fillAttributedString = NSAttributedString(string: text, attributes: fillAttributes)
        fillAttributedString.draw(in: textRect)
        
        image.unlockFocus()
        
        return image
    }
} 

