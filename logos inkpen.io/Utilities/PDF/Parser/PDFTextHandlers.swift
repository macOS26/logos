//
//  PDFTextHandlers.swift
//  logos inkpen.io
//
//  PDF text operator handlers for text extraction
//

import SwiftUI

extension PDFCommandParser {

    // MARK: - Text Object Operators

    /// Begin text object (BT)
    func handleBeginText() {
        Log.info("📝 PDF Text: Begin text object (BT)", category: .general)

        isInTextObject = true
        // Reset text matrices
        currentTextMatrix = .identity
        currentLineMatrix = .identity

        // Store start position
        currentTextStartPosition = CGPoint(
            x: currentTransformMatrix.tx,
            y: currentTransformMatrix.ty
        )

        // Clear accumulated text
        currentTextContent = ""
    }

    /// End text object (ET)
    func handleEndText() {
        Log.info("📝 PDF Text: End text object (ET) - Content: '\(currentTextContent)'", category: .general)

        guard isInTextObject else { return }
        isInTextObject = false

        // If we have accumulated text, create a VectorText object
        if !currentTextContent.isEmpty {
            createVectorTextFromAccumulated()
        }

        // Reset text state
        currentTextContent = ""
        currentTextMatrix = .identity
        currentLineMatrix = .identity
    }

    // MARK: - Text State Operators

    /// Set font and size (Tf)
    func handleSetFont(scanner: CGPDFScannerRef) {
        var fontNamePointer: UnsafePointer<CChar>?
        var fontSize: CGPDFReal = 12.0

        // PDF format: /FontName size Tf
        if CGPDFScannerPopNumber(scanner, &fontSize),
           CGPDFScannerPopName(scanner, &fontNamePointer) {

            let fontName = fontNamePointer.map { String(cString: $0) } ?? "Helvetica"
            currentFontName = fontName
            currentFontSize = Double(fontSize)

            Log.info("PDF Text: Set font '\(fontName)' size \(fontSize) (Tf)", category: .general)

            // Try to resolve actual font from resources
            if let resolvedFont = resolveFontFromResources(fontName) {
                currentFontName = resolvedFont
                Log.info("   Resolved to: '\(resolvedFont)'", category: .general)
            }
        } else {
            Log.error("PDF Text: Failed to parse Tf operator", category: .error)
        }
    }

    /// Set character spacing (Tc)
    func handleSetCharacterSpacing(scanner: CGPDFScannerRef) {
        var charSpace: CGPDFReal = 0
        if CGPDFScannerPopNumber(scanner, &charSpace) {
            textCharacterSpacing = Double(charSpace)
            Log.info("PDF Text: Set character spacing \(charSpace) (Tc)", category: .general)
        }
    }

    /// Set word spacing (Tw)
    func handleSetWordSpacing(scanner: CGPDFScannerRef) {
        var wordSpace: CGPDFReal = 0
        if CGPDFScannerPopNumber(scanner, &wordSpace) {
            textWordSpacing = Double(wordSpace)
            Log.info("PDF Text: Set word spacing \(wordSpace) (Tw)", category: .general)
        }
    }

    /// Set horizontal scaling (Tz)
    func handleSetHorizontalScaling(scanner: CGPDFScannerRef) {
        var scale: CGPDFReal = 100
        if CGPDFScannerPopNumber(scanner, &scale) {
            textHorizontalScaling = Double(scale)
            Log.info("PDF Text: Set horizontal scaling \(scale)% (Tz)", category: .general)
        }
    }

    /// Set text leading (TL)
    func handleSetTextLeading(scanner: CGPDFScannerRef) {
        var leading: CGPDFReal = 0
        if CGPDFScannerPopNumber(scanner, &leading) {
            textLeading = Double(leading)
            Log.info("PDF Text: Set text leading \(leading) (TL)", category: .general)
        }
    }

    /// Set text rendering mode (Tr)
    func handleSetTextRenderingMode(scanner: CGPDFScannerRef) {
        var mode: CGPDFInteger = 0
        if CGPDFScannerPopInteger(scanner, &mode) {
            textRenderingMode = Int(mode)
            let modeDesc = ["fill", "stroke", "fill+stroke", "invisible", "fill+clip", "stroke+clip", "fill+stroke+clip", "clip"][min(Int(mode), 7)]
            Log.info("PDF Text: Set rendering mode \(mode) (\(modeDesc)) (Tr)", category: .general)
        }
    }

    /// Set text rise (Ts)
    func handleSetTextRise(scanner: CGPDFScannerRef) {
        var rise: CGPDFReal = 0
        if CGPDFScannerPopNumber(scanner, &rise) {
            textRise = Double(rise)
            Log.info("PDF Text: Set text rise \(rise) (Ts)", category: .general)
        }
    }

    // MARK: - Text Positioning Operators

    /// Move text position (Td)
    func handleTextMove(scanner: CGPDFScannerRef) {
        var tx: CGPDFReal = 0
        var ty: CGPDFReal = 0

        if CGPDFScannerPopNumber(scanner, &ty),
           CGPDFScannerPopNumber(scanner, &tx) {

            // Update line matrix
            let translation = CGAffineTransform(translationX: CGFloat(tx), y: CGFloat(ty))
            currentLineMatrix = currentLineMatrix.concatenating(translation)
            currentTextMatrix = currentLineMatrix

            Log.info("PDF Text: Move text position (\(tx), \(ty)) (Td)", category: .general)
        }
    }

    /// Move text position and set leading (TD)
    func handleTextMoveWithLeading(scanner: CGPDFScannerRef) {
        var tx: CGPDFReal = 0
        var ty: CGPDFReal = 0

        if CGPDFScannerPopNumber(scanner, &ty),
           CGPDFScannerPopNumber(scanner, &tx) {

            // Set leading to -ty
            textLeading = -Double(ty)

            // Update line matrix
            let translation = CGAffineTransform(translationX: CGFloat(tx), y: CGFloat(ty))
            currentLineMatrix = currentLineMatrix.concatenating(translation)
            currentTextMatrix = currentLineMatrix

            Log.info("PDF Text: Move text position (\(tx), \(ty)) and set leading (TD)", category: .general)
        }
    }

    /// Set text matrix and line matrix (Tm)
    func handleSetTextMatrix(scanner: CGPDFScannerRef) {
        var a: CGPDFReal = 1, b: CGPDFReal = 0
        var c: CGPDFReal = 0, d: CGPDFReal = 1
        var e: CGPDFReal = 0, f: CGPDFReal = 0

        if CGPDFScannerPopNumber(scanner, &f),
           CGPDFScannerPopNumber(scanner, &e),
           CGPDFScannerPopNumber(scanner, &d),
           CGPDFScannerPopNumber(scanner, &c),
           CGPDFScannerPopNumber(scanner, &b),
           CGPDFScannerPopNumber(scanner, &a) {

            currentTextMatrix = CGAffineTransform(a: CGFloat(a), b: CGFloat(b),
                                                   c: CGFloat(c), d: CGFloat(d),
                                                   tx: CGFloat(e), ty: CGFloat(f))
            currentLineMatrix = currentTextMatrix

            Log.info("PDF Text: Set text matrix [\(a) \(b) \(c) \(d) \(e) \(f)] (Tm)", category: .general)
        }
    }

    /// Move to start of next line (T*)
    func handleTextNewLine() {
        // Equivalent to: 0 -TL Td
        let translation = CGAffineTransform(translationX: 0, y: -CGFloat(textLeading))
        currentLineMatrix = currentLineMatrix.concatenating(translation)
        currentTextMatrix = currentLineMatrix

        // Add newline to accumulated text
        if !currentTextContent.isEmpty {
            currentTextContent += "\n"
        }

        Log.info("PDF Text: Move to next line (T*)", category: .general)
    }

    // MARK: - Text Showing Operators

    /// Show text string (Tj)
    func handleShowText(scanner: CGPDFScannerRef) {
        var stringRef: CGPDFStringRef?

        if CGPDFScannerPopString(scanner, &stringRef),
           let stringRef = stringRef {

            let text = extractTextFromPDFString(stringRef)
            currentTextContent += text

            Log.info("📝 PDF Text: Show text '\(text)' (Tj) - Total: '\(currentTextContent)'", category: .general)

            // Advance text position based on text width
            advanceTextPosition(for: text)
        }
    }

    /// Show text with individual glyph positioning (TJ)
    func handleShowTextWithPositioning(scanner: CGPDFScannerRef) {
        var arrayRef: CGPDFArrayRef?

        if CGPDFScannerPopArray(scanner, &arrayRef),
           let arrayRef = arrayRef {

            let count = CGPDFArrayGetCount(arrayRef)
            var combinedText = ""

            for index in 0..<count {
                var stringRef: CGPDFStringRef?
                var numberValue: CGPDFReal = 0

                if CGPDFArrayGetString(arrayRef, index, &stringRef),
                   let stringRef = stringRef {
                    // It's a string - add to text
                    let text = extractTextFromPDFString(stringRef)
                    combinedText += text
                } else if CGPDFArrayGetNumber(arrayRef, index, &numberValue) {
                    // It's a number - adjust spacing
                    // Negative values move text closer (kerning)
                    if numberValue < -100 {
                        // Large negative value might indicate word break
                        combinedText += " "
                    }
                }
            }

            currentTextContent += combinedText
            Log.info("PDF Text: Show text with positioning '\(combinedText)' (TJ)", category: .general)

            // Advance text position
            advanceTextPosition(for: combinedText)
        }
    }

    /// Move to next line and show text (')
    func handleMoveAndShowText(scanner: CGPDFScannerRef) {
        // First move to next line
        handleTextNewLine()

        // Then show text
        handleShowText(scanner: scanner)
    }

    /// Set word and char spacing, move to next line, show text (")
    func handleSpacingMoveAndShowText(scanner: CGPDFScannerRef) {
        var stringRef: CGPDFStringRef?
        var wordSpace: CGPDFReal = 0
        var charSpace: CGPDFReal = 0

        if CGPDFScannerPopString(scanner, &stringRef),
           CGPDFScannerPopNumber(scanner, &charSpace),
           CGPDFScannerPopNumber(scanner, &wordSpace) {

            // Set spacing values
            textWordSpacing = Double(wordSpace)
            textCharacterSpacing = Double(charSpace)

            // Move to next line
            handleTextNewLine()

            // Show text
            if let stringRef = stringRef {
                let text = extractTextFromPDFString(stringRef)
                currentTextContent += text

                Log.info("PDF Text: Set spacing and show '\(text)' (\")", category: .general)

                advanceTextPosition(for: text)
            }
        }
    }

    // MARK: - Helper Methods

    /// Extract text from PDF string
    private func extractTextFromPDFString(_ pdfString: CGPDFStringRef) -> String {
        if let cfString = CGPDFStringCopyTextString(pdfString) {
            return cfString as String
        }

        // Fallback to raw bytes - get pointer to bytes
        let length = CGPDFStringGetLength(pdfString)
        if length > 0, let bytes = CGPDFStringGetBytePtr(pdfString) {
            let data = Data(bytes: bytes, count: length)

            // Try UTF-8 first, then fall back to ASCII
            if let text = String(data: data, encoding: .utf8) {
                return text
            } else if let text = String(data: data, encoding: .ascii) {
                return text
            } else {
                // Try MacRoman encoding (common in older PDFs)
                if let text = String(data: data, encoding: .macOSRoman) {
                    return text
                }
            }
        }

        return ""
    }

    /// Resolve font name from PDF resources
    private func resolveFontFromResources(_ resourceName: String) -> String? {
        guard let resources = pageResourcesDict else { return nil }

        var fontDict: CGPDFDictionaryRef?
        if CGPDFDictionaryGetDictionary(resources, "Font", &fontDict),
           let fontDict = fontDict {

            var fontRef: CGPDFDictionaryRef?
            if CGPDFDictionaryGetDictionary(fontDict, resourceName, &fontRef),
               let fontRef = fontRef {

                // Try to get BaseFont name
                var baseFontName: UnsafePointer<CChar>?
                if CGPDFDictionaryGetName(fontRef, "BaseFont", &baseFontName),
                   let baseFontName = baseFontName {
                    let fontName = String(cString: baseFontName)

                    // Clean up font name (remove subset prefix like "ABCDEF+")
                    if let plusIndex = fontName.firstIndex(of: "+") {
                        let cleanName = String(fontName[fontName.index(after: plusIndex)...])
                        return mapPDFFontToSystem(cleanName)
                    }
                    return mapPDFFontToSystem(fontName)
                }
            }
        }

        return nil
    }

    /// Map PDF font names to system fonts
    private func mapPDFFontToSystem(_ pdfFontName: String) -> String {
        // Remove PostScript suffixes
        let cleanName = pdfFontName
            .replacingOccurrences(of: "-Roman", with: "")
            .replacingOccurrences(of: "-Regular", with: "")
            .replacingOccurrences(of: "-Book", with: "")
            .replacingOccurrences(of: ",Bold", with: "-Bold")
            .replacingOccurrences(of: ",Italic", with: "-Italic")
            .replacingOccurrences(of: ",BoldItalic", with: "-BoldItalic")

        // Map common PDF fonts to system equivalents
        let fontMapping: [String: String] = [
            "Times-Roman": "Times New Roman",
            "Times-Bold": "Times New Roman Bold",
            "Times-Italic": "Times New Roman Italic",
            "Times-BoldItalic": "Times New Roman Bold Italic",
            "Helvetica": "Helvetica",
            "Helvetica-Bold": "Helvetica-Bold",
            "Helvetica-Oblique": "Helvetica-Oblique",
            "Helvetica-BoldOblique": "Helvetica-BoldOblique",
            "Courier": "Courier",
            "Courier-Bold": "Courier-Bold",
            "Courier-Oblique": "Courier-Oblique",
            "Courier-BoldOblique": "Courier-BoldOblique",
            "Symbol": "Symbol",
            "ZapfDingbats": "Zapf Dingbats",
            "ArialMT": "Arial",
            "Arial-BoldMT": "Arial-Bold",
            "Arial-ItalicMT": "Arial-Italic",
            "Arial-BoldItalicMT": "Arial-BoldItalic"
        ]

        return fontMapping[cleanName] ?? cleanName
    }

    /// Advance text position after showing text
    private func advanceTextPosition(for text: String) {
        // This is simplified - actual calculation would need font metrics
        let estimatedWidth = Double(text.count) * currentFontSize * 0.5
        let advance = estimatedWidth * (textHorizontalScaling / 100.0)

        // Update text matrix with advance
        let translation = CGAffineTransform(translationX: CGFloat(advance), y: 0)
        currentTextMatrix = currentTextMatrix.concatenating(translation)
    }

    /// Create VectorText object from accumulated text
    private func createVectorTextFromAccumulated() {
        guard !currentTextContent.isEmpty else { return }

        // Calculate actual position from matrices
        // PDF uses bottom-left origin, we need to flip Y
        let ctm = currentTransformMatrix
        let tm = currentTextMatrix
        let combined = tm.concatenating(ctm)  // Apply text matrix first, then CTM

        // Get position from combined transform and flip Y coordinate
        let position = CGPoint(x: combined.tx, y: pageSize.height - combined.ty)

        Log.info("📝 Creating text at position: \(position) from matrices - TM: \(tm), CTM: \(ctm)", category: .general)

        // Determine font attributes
        let fontFamily = currentFontName ?? "Helvetica"
        let fontSize = currentFontSize

        // Determine fill/stroke based on rendering mode
        let hasFill = textRenderingMode == 0 || textRenderingMode == 2 || textRenderingMode == 4 || textRenderingMode == 6
        let hasStroke = textRenderingMode == 1 || textRenderingMode == 2 || textRenderingMode == 5 || textRenderingMode == 6

        // Create TypographyProperties
        // Convert CGColor to VectorColor
        let fillColor: VectorColor
        let strokeColor: VectorColor

        // Extract RGB components from CGColor
        if hasFill, let components = currentFillColor.components, components.count >= 3 {
            fillColor = .rgb(RGBColor(red: Double(components[0]), green: Double(components[1]), blue: Double(components[2])))
        } else {
            fillColor = .black
        }

        if hasStroke, let components = currentStrokeColor.components, components.count >= 3 {
            strokeColor = .rgb(RGBColor(red: Double(components[0]), green: Double(components[1]), blue: Double(components[2])))
        } else {
            strokeColor = .black
        }

        let typography = TypographyProperties(
            fontFamily: fontFamily,
            fontWeight: .regular,
            fontStyle: .normal,
            fontSize: fontSize,
            lineHeight: fontSize * 1.2,  // Default line height
            lineSpacing: textLeading,
            letterSpacing: textCharacterSpacing,
            alignment: .left,
            hasStroke: hasStroke,
            strokeColor: strokeColor,
            strokeWidth: hasStroke ? currentLineWidth : 1.0,
            strokeOpacity: hasStroke ? currentStrokeOpacity : 1.0,
            fillColor: fillColor,
            fillOpacity: hasFill ? currentFillOpacity : 1.0
        )

        // Create VectorText
        let vectorText = VectorText(
            content: currentTextContent,
            typography: typography,
            position: position
        )

        // Convert to VectorShape
        let shape = vectorText.toVectorShape()
        shapes.append(shape)

        Log.info("✅ PDF Text: Created text object with '\(currentTextContent.prefix(50))...' at \(position)", category: .general)
    }
}

// MARK: - VectorText Extensions for Conversion

extension VectorText {
    /// Convert VectorText to VectorShape for unified storage
    func toVectorShape() -> VectorShape {
        // Create fill and stroke styles from typography
        let fillStyle = FillStyle(
            color: typography.fillColor,
            opacity: typography.fillOpacity
        )

        let strokeStyle = typography.hasStroke ? StrokeStyle(
            color: typography.strokeColor,
            width: typography.strokeWidth,
            opacity: typography.strokeOpacity
        ) : nil

        var shape = VectorShape(
            name: "Text: \(content.prefix(20))",
            path: VectorPath(elements: []), // Empty path for text objects
            strokeStyle: strokeStyle,
            fillStyle: fillStyle,
            transform: transform
        )

        // Mark as text object
        shape.isTextObject = true
        shape.textContent = content
        shape.textPosition = position

        // Store font info in metadata for PDF import reconstruction
        shape.metadata["fontFamily"] = typography.fontFamily
        shape.metadata["fontSize"] = "\(typography.fontSize)"
        shape.metadata["letterSpacing"] = "\(typography.letterSpacing)"
        // Note: wordSpacing doesn't exist in TypographyProperties but we track it for PDF import
        shape.metadata["wordSpacing"] = "0"  // Default to 0 since it's not in Typography
        shape.metadata["lineSpacing"] = "\(typography.lineSpacing)"

        return shape
    }
}