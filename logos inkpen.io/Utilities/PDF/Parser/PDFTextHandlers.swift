//
//  PDFTextHandlers.swift
//  logos inkpen.io
//
//  PDF text operator handlers for text extraction
//

import SwiftUI

extension PDFCommandParser {

    // MARK: - Text Object Operators

    /// Begin text object (BT) - SIMD optimized
    func handleBeginText() {

        isInTextObject = true
        // Reset text matrices - text starts at origin (SIMD-accelerated)
        currentTextMatrix = .identity
        currentLineMatrix = .identity
        simdTextMatrix = PDFSIMDMatrix() // Identity matrix
        simdLineMatrix = PDFSIMDMatrix() // Identity matrix

        // Store start position from current transform matrix
        currentTextStartPosition = CGPoint(
            x: currentTransformMatrix.tx,
            y: currentTransformMatrix.ty
        )

        // Clear accumulated text
        currentTextContent = ""

        // Text state should persist between text objects within a page
        // But reset position-related state
    }

    /// End text object (ET) - SIMD optimized
    func handleEndText() {

        guard isInTextObject else { return }
        isInTextObject = false

        // If we have accumulated text, create a VectorText object
        if !currentTextContent.isEmpty {
            createVectorTextFromAccumulated()
        }

        // Reset text state (SIMD-accelerated)
        currentTextContent = ""
        currentTextMatrix = .identity
        currentLineMatrix = .identity
        simdTextMatrix = PDFSIMDMatrix() // Identity matrix
        simdLineMatrix = PDFSIMDMatrix() // Identity matrix
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


            // Try to resolve actual font from resources and get font dictionary
            if let (resolvedFont, fontDict) = resolveFontFromResourcesWithDict(fontName) {
                currentFontName = resolvedFont
                currentFontDict = fontDict
            } else if let resolvedFont = resolveFontFromResources(fontName) {
                currentFontName = resolvedFont
                currentFontDict = nil
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
        }
    }

    /// Set word spacing (Tw)
    func handleSetWordSpacing(scanner: CGPDFScannerRef) {
        var wordSpace: CGPDFReal = 0
        if CGPDFScannerPopNumber(scanner, &wordSpace) {
            textWordSpacing = Double(wordSpace)
        }
    }

    /// Set horizontal scaling (Tz)
    func handleSetHorizontalScaling(scanner: CGPDFScannerRef) {
        var scale: CGPDFReal = 100
        if CGPDFScannerPopNumber(scanner, &scale) {
            textHorizontalScaling = Double(scale)
        }
    }

    /// Set text leading (TL)
    func handleSetTextLeading(scanner: CGPDFScannerRef) {
        var leading: CGPDFReal = 0
        if CGPDFScannerPopNumber(scanner, &leading) {
            textLeading = Double(leading)
        }
    }

    /// Set text rendering mode (Tr)
    func handleSetTextRenderingMode(scanner: CGPDFScannerRef) {
        var mode: CGPDFInteger = 0
        if CGPDFScannerPopInteger(scanner, &mode) {
            textRenderingMode = Int(mode)
        }
    }

    /// Set text rise (Ts)
    func handleSetTextRise(scanner: CGPDFScannerRef) {
        var rise: CGPDFReal = 0
        if CGPDFScannerPopNumber(scanner, &rise) {
            textRise = Double(rise)
        }
    }

    // MARK: - Text Positioning Operators

    /// Move text position (Td) - SIMD optimized
    func handleTextMove(scanner: CGPDFScannerRef) {
        var tx: CGPDFReal = 0
        var ty: CGPDFReal = 0

        if CGPDFScannerPopNumber(scanner, &ty),
           CGPDFScannerPopNumber(scanner, &tx) {

            // If we have accumulated text, flush it before moving
            if !currentTextContent.isEmpty {
                createVectorTextFromAccumulated()
                currentTextContent = ""
            }

            // SIMD-accelerated matrix operations (3-6x faster)
            let translation = PDFSIMDMatrix.translation(tx: CGFloat(tx), ty: CGFloat(ty))
            simdLineMatrix.concatenate(translation)
            simdTextMatrix = simdLineMatrix

            // Sync standard matrices only when needed for external APIs
            currentLineMatrix = simdLineMatrix.cgAffineTransform
            currentTextMatrix = simdTextMatrix.cgAffineTransform

            // Capture new start position using SIMD properties directly (faster)
            currentTextStartPosition = CGPoint(x: simdTextMatrix.tx, y: simdTextMatrix.ty)

        }
    }

    /// Move text position and set leading (TD) - SIMD optimized
    func handleTextMoveWithLeading(scanner: CGPDFScannerRef) {
        var tx: CGPDFReal = 0
        var ty: CGPDFReal = 0

        if CGPDFScannerPopNumber(scanner, &ty),
           CGPDFScannerPopNumber(scanner, &tx) {

            // If we have accumulated text, flush it before moving
            if !currentTextContent.isEmpty {
                createVectorTextFromAccumulated()
                currentTextContent = ""
            }

            // Set leading to -ty
            textLeading = -Double(ty)

            // SIMD-accelerated matrix operations (3-6x faster)
            let translation = PDFSIMDMatrix.translation(tx: CGFloat(tx), ty: CGFloat(ty))
            simdLineMatrix.concatenate(translation)
            simdTextMatrix = simdLineMatrix

            // Sync standard matrices only when needed for external APIs
            currentLineMatrix = simdLineMatrix.cgAffineTransform
            currentTextMatrix = simdTextMatrix.cgAffineTransform

            // Capture new start position using SIMD properties directly (faster)
            currentTextStartPosition = CGPoint(x: simdTextMatrix.tx, y: simdTextMatrix.ty)

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

            // CRITICAL FIX: If we have accumulated text and Tm is setting a new position,
            // create a text object from the accumulated content BEFORE updating matrix
            // This ensures each text segment gets positioned correctly
            if !currentTextContent.isEmpty && isInTextObject {
                // Check if position is actually changing (not just scale/rotation)
                let newPosition = CGPoint(x: CGFloat(e), y: CGFloat(f))
                let startPosition = currentTextStartPosition

                // If position changed significantly (more than 1 unit), flush accumulated text
                if abs(newPosition.x - startPosition.x) > 1 || abs(newPosition.y - startPosition.y) > 1 {
                    createVectorTextFromAccumulated()
                    currentTextContent = ""
                }
            }

            // SIMD-accelerated text matrix operations (3-6x faster)
            simdTextMatrix = PDFSIMDMatrix(a: CGFloat(a), b: CGFloat(b),
                                           c: CGFloat(c), d: CGFloat(d),
                                           tx: CGFloat(e), ty: CGFloat(f))
            simdLineMatrix = simdTextMatrix

            // Keep standard matrices in sync for compatibility
            currentTextMatrix = simdTextMatrix.cgAffineTransform
            currentLineMatrix = simdLineMatrix.cgAffineTransform

            // DETECT COORDINATE SYSTEM: Check where the actual position is stored
            if usesTextMatrixForPosition == nil {
                // Check if Tm has significant position values
                let tmHasPosition = abs(e) > 1.0 || abs(f) > 1.0
                // Check if CTM has significant position values
                let ctmHasPosition = abs(currentTransformMatrix.tx) > 1.0 || abs(currentTransformMatrix.ty) > 1.0

                // If Tm has position but CTM doesn't, it's InkPen style
                // If CTM has position but Tm doesn't (or just scale), it's Pages style
                if tmHasPosition && !ctmHasPosition {
                    usesTextMatrixForPosition = true
                    Log.info("PDF: Detected text position in Tm (InkPen style)", category: .general)
                } else if ctmHasPosition && (!tmHasPosition || (abs(e) < 1.0 && abs(f) < 1.0)) {
                    usesTextMatrixForPosition = false
                    Log.info("PDF: Detected text position in CTM (Pages style)", category: .general)
                }
            }

            // CRITICAL: Capture the start position for text accumulation
            // This prevents X position drift when multiple text segments are shown
            if currentTextContent.isEmpty {
                currentTextStartPosition = CGPoint(x: CGFloat(e), y: CGFloat(f))
            }

        }
    }

    /// Move to start of next line (T*)
    func handleTextNewLine() {
        // If we have accumulated text, flush it before moving to new line
        if !currentTextContent.isEmpty {
            createVectorTextFromAccumulated()
            currentTextContent = ""
        }

        // Equivalent to: 0 -TL Td
        let translation = CGAffineTransform(translationX: 0, y: -CGFloat(textLeading))
        currentLineMatrix = currentLineMatrix.concatenating(translation)
        currentTextMatrix = currentLineMatrix

        // Capture new start position
        currentTextStartPosition = CGPoint(x: currentTextMatrix.tx, y: currentTextMatrix.ty)

    }

    // MARK: - Text Showing Operators

    /// Show text string (Tj)
    func handleShowText(scanner: CGPDFScannerRef) {
        var stringRef: CGPDFStringRef?

        if CGPDFScannerPopString(scanner, &stringRef),
           let stringRef = stringRef {

            let text = extractTextFromPDFString(stringRef)
            currentTextContent += text


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


                advanceTextPosition(for: text)
            }
        }
    }

    // MARK: - Helper Methods

    /// Extract text from PDF string
    private func extractTextFromPDFString(_ pdfString: CGPDFStringRef) -> String {
        // PRIORITY: Try manual ToUnicode CMap first if font dictionary is available
        // This handles cases where CGPDFStringCopyTextString doesn't properly decode ligatures
        if let fontDict = currentFontDict {
            if let decodedText = decodeTextUsingToUnicode(pdfString, fontDict: fontDict) {
                return decodedText
            }
        }

        // Fallback: try using CGPDFStringCopyTextString which should handle ToUnicode CMap
        // This is usually reliable but may not handle all custom encodings
        if let cfString = CGPDFStringCopyTextString(pdfString) {
            let result = cfString as String

            if result.contains("\u{FB00}") || result.contains("\u{FB01}") ||
               result.contains("\u{FB02}") || result.contains("\u{FB03}") || result.contains("\u{FB04}") {
            }

            return result
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

            // Last resort: log the raw bytes for debugging
            Log.warning("   Could not decode text, raw bytes: \(data.map { String(format: "%02X", $0) }.joined(separator: " "))", category: .general)
        }

        return ""
    }

    /// Decode text using ToUnicode CMap from font dictionary
    private func decodeTextUsingToUnicode(_ pdfString: CGPDFStringRef, fontDict: CGPDFDictionaryRef) -> String? {
        // Get ToUnicode CMap stream
        var toUnicodeStream: CGPDFStreamRef?
        guard CGPDFDictionaryGetStream(fontDict, "ToUnicode", &toUnicodeStream),
              let toUnicodeStream = toUnicodeStream else {
            return nil
        }

        // Get the stream format and data
        var format = CGPDFDataFormat.raw
        guard let streamData = CGPDFStreamCopyData(toUnicodeStream, &format) as Data? else {
            return nil
        }

        // Parse the CMap to build character code to Unicode mapping
        // CMaps are PostScript-like text files
        guard let cmapString = String(data: streamData, encoding: .utf8) ??
                               String(data: streamData, encoding: .ascii) else {
            return nil
        }

        // Build a mapping from character codes to Unicode strings
        let codeToUnicode = parseCMap(cmapString)

        // Now decode the PDF string using this mapping
        let length = CGPDFStringGetLength(pdfString)
        guard length > 0, let bytes = CGPDFStringGetBytePtr(pdfString) else {
            return nil
        }

        var result = ""
        for i in 0..<length {
            let charCode = UInt16(bytes[i])
            if let unicodeString = codeToUnicode[charCode] {
                result += unicodeString
            } else {
                // Fallback: use the character code as-is
                result += String(UnicodeScalar(UInt8(charCode)))
            }
        }

        return result.isEmpty ? nil : result
    }

    /// Parse a CMap string to extract character code to Unicode mappings
    private func parseCMap(_ cmapString: String) -> [UInt16: String] {
        var mapping: [UInt16: String] = [:]

        // Look for bfchar mappings: <charcode> <unicode>
        // Example: <21> <FB00>  maps code 0x21 to Unicode ligature ff (U+FB00)
        let bfcharPattern = "<([0-9A-Fa-f]+)>\\s*<([0-9A-Fa-f]+)>"
        if let regex = try? NSRegularExpression(pattern: bfcharPattern, options: []) {
            let range = NSRange(cmapString.startIndex..., in: cmapString)
            regex.enumerateMatches(in: cmapString, options: [], range: range) { match, _, _ in
                guard let match = match,
                      match.numberOfRanges == 3,
                      let charCodeRange = Range(match.range(at: 1), in: cmapString),
                      let unicodeRange = Range(match.range(at: 2), in: cmapString) else {
                    return
                }

                let charCodeHex = String(cmapString[charCodeRange])
                let unicodeHex = String(cmapString[unicodeRange])

                if let charCode = UInt16(charCodeHex, radix: 16) {
                    // Convert Unicode hex to string
                    // Handle multi-character Unicode sequences (like "006600 66" for "ff")
                    var unicodeString = ""
                    let hexChars = Array(unicodeHex)
                    for i in stride(from: 0, to: hexChars.count, by: 4) {
                        if i + 4 <= hexChars.count {
                            let hexValue = String(hexChars[i..<min(i+4, hexChars.count)])
                            if let scalar = UInt32(hexValue, radix: 16),
                               let unicodeScalar = UnicodeScalar(scalar) {
                                unicodeString.append(Character(unicodeScalar))
                            }
                        }
                    }

                    if !unicodeString.isEmpty {
                        mapping[charCode] = unicodeString
                    }
                }
            }
        }

        // Look for bfrange mappings: <start> <end> <unicode>
        // Example: <21><21><FB00>  maps code 0x21 to Unicode ligature ff (U+FB00)
        let bfrangePattern = "<([0-9A-Fa-f]+)>\\s*<([0-9A-Fa-f]+)>\\s*<([0-9A-Fa-f]+)>"
        if let regex = try? NSRegularExpression(pattern: bfrangePattern, options: []) {
            let range = NSRange(cmapString.startIndex..., in: cmapString)
            regex.enumerateMatches(in: cmapString, options: [], range: range) { match, _, _ in
                guard let match = match,
                      match.numberOfRanges == 4,
                      let startCodeRange = Range(match.range(at: 1), in: cmapString),
                      let endCodeRange = Range(match.range(at: 2), in: cmapString),
                      let unicodeRange = Range(match.range(at: 3), in: cmapString) else {
                    return
                }

                let startCodeHex = String(cmapString[startCodeRange])
                let endCodeHex = String(cmapString[endCodeRange])
                let unicodeHex = String(cmapString[unicodeRange])

                if let startCode = UInt16(startCodeHex, radix: 16),
                   let endCode = UInt16(endCodeHex, radix: 16),
                   let baseUnicode = UInt32(unicodeHex, radix: 16) {

                    // Map each character code in the range
                    for charCode in startCode...endCode {
                        let unicodeValue = baseUnicode + UInt32(charCode - startCode)

                        // Convert Unicode value to string
                        var unicodeString = ""
                        let hexChars = String(format: "%04X", unicodeValue)
                        for i in stride(from: 0, to: hexChars.count, by: 4) {
                            let startIdx = hexChars.index(hexChars.startIndex, offsetBy: i)
                            let endIdx = hexChars.index(startIdx, offsetBy: min(4, hexChars.count - i))
                            let hexValue = String(hexChars[startIdx..<endIdx])
                            if let scalar = UInt32(hexValue, radix: 16),
                               let unicodeScalar = UnicodeScalar(scalar) {
                                unicodeString.append(Character(unicodeScalar))
                            }
                        }

                        if !unicodeString.isEmpty {
                            mapping[charCode] = unicodeString
                        }
                    }
                }
            }
        }

        return mapping
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

    /// Resolve font name and dictionary from PDF resources
    private func resolveFontFromResourcesWithDict(_ resourceName: String) -> (String, CGPDFDictionaryRef)? {
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
                    let cleanName: String
                    if let plusIndex = fontName.firstIndex(of: "+") {
                        cleanName = String(fontName[fontName.index(after: plusIndex)...])
                    } else {
                        cleanName = fontName
                    }
                    return (mapPDFFontToSystem(cleanName), fontRef)
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

        // CRITICAL FIX: Use the STARTING position captured when text matrix was set,
        // NOT the current text matrix which has been advanced by advanceTextPosition()
        // This prevents X position drift for multi-segment text on the same line
        var pdfX = currentTextStartPosition.x
        var pdfY = currentTextStartPosition.y

        // Get matrix scale for font size calculation
        let tm = currentTextMatrix

        // CRITICAL: Font size is Tf size × matrix scale
        // Common pattern: Tf sets size 1.0, matrix scale sets actual size
        let matrixFontSize = abs(tm.d)  // d is vertical scale (font height)
        let actualFontSize = currentFontSize * matrixFontSize

        // Use detected coordinate system pattern
        if let usesTm = usesTextMatrixForPosition {
            if !usesTm {
                // Pages style: Position is in CTM, not text matrix
                pdfX = currentTransformMatrix.tx
                pdfY = currentTransformMatrix.ty
            }
        }

        // For Pages PDFs, we need to check each text element individually
        // Some might need flipping, others might not
        let finalY: CGFloat

        // If position came from CTM (Pages style), always flip Y
        if usesTextMatrixForPosition == false {
            // Pages style with CTM positioning - needs Y flip
            let flippedY = pageSize.height - pdfY
            finalY = flippedY - actualFontSize
        } else {
            // InkPen style or text matrix positioning - no flip needed
            // PDF Y position is at text BASELINE, subtract to get top of text box
            finalY = pdfY - actualFontSize
        }

        let position = CGPoint(x: pdfX, y: finalY)


        // Determine font attributes and parse weight from font name
        let fullFontName = currentFontName ?? "Helvetica"
        var fontFamily = fullFontName
        var fontWeight: FontWeight = .regular
        var fontStyle: FontStyle = .normal
        var fontVariant: String? = nil

        // Parse weight and style from font name (e.g. "Helvetica-Bold", "HelveticaNeue-LightItalic")
        if let dashIndex = fullFontName.lastIndex(of: "-") {
            fontFamily = String(fullFontName[..<dashIndex])
            let variantPart = String(fullFontName[fullFontName.index(after: dashIndex)...])

            // Map common PDF font names to system font families
            if fontFamily == "HelveticaNeue" {
                fontFamily = "Helvetica Neue"
            } else if fontFamily == "TimesNewRomanPS" {
                fontFamily = "Times New Roman"
            } else if fontFamily == "ArialMT" {
                fontFamily = "Arial"
            }

            // Try to find exact variant match
            let fontManager = NSFontManager.shared
            let members = fontManager.availableMembers(ofFontFamily: fontFamily) ?? []

            for member in members {
                if let postScriptName = member[0] as? String,
                   let displayName = member[1] as? String {
                    // Check if this PostScript name matches
                    if postScriptName == fullFontName {
                        fontVariant = displayName
                        // Also extract weight and style for compatibility
                        if let weightNumber = member[2] as? NSNumber,
                           let traits = member[3] as? NSNumber {
                            let nsWeight = weightNumber.intValue
                            // Map weight from NSFont weight value
                            switch nsWeight {
                            case 0...2: fontWeight = .thin
                            case 3: fontWeight = .ultraLight
                            case 4: fontWeight = .light
                            case 5: fontWeight = .regular
                            case 6: fontWeight = .medium
                            case 7...8: fontWeight = .semibold
                            case 9: fontWeight = .bold
                            case 10...11: fontWeight = .heavy
                            default: fontWeight = .black
                            }

                            let traitMask = NSFontDescriptor.SymbolicTraits(rawValue: UInt32(traits.intValue))
                            fontStyle = traitMask.contains(.italic) ? .italic : .normal
                        }
                        break
                    }
                }
            }

            // If no exact match, parse weight/style from variant part
            if fontVariant == nil {
                let lowerVariant = variantPart.lowercased()

                // Parse weight
                if lowerVariant.contains("ultralight") || lowerVariant.contains("ultra-light") {
                    fontWeight = .ultraLight
                } else if lowerVariant.contains("thin") {
                    fontWeight = .thin
                } else if lowerVariant.contains("light") && !lowerVariant.contains("ultralight") {
                    fontWeight = .light
                } else if lowerVariant.contains("medium") {
                    fontWeight = .medium
                } else if lowerVariant.contains("semibold") || lowerVariant.contains("semi-bold") || lowerVariant.contains("demibold") {
                    fontWeight = .semibold
                } else if lowerVariant.contains("bold") && !lowerVariant.contains("semibold") {
                    fontWeight = .bold
                } else if lowerVariant.contains("heavy") || lowerVariant.contains("black") {
                    fontWeight = .heavy
                }

                // Parse style
                if lowerVariant.contains("italic") || lowerVariant.contains("oblique") {
                    fontStyle = .italic
                }
            }
        }

        let fontSize = actualFontSize

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
            fontVariant: fontVariant,  // Include the variant if found
            fontWeight: fontWeight,    // Use parsed weight
            fontStyle: fontStyle,      // Use parsed style
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

        // Calculate proper bounds for text
        let lines = currentTextContent.components(separatedBy: .newlines)
        let maxLineLength = lines.map { $0.count }.max() ?? 0
        let estimatedWidth = Double(maxLineLength) * fontSize * 0.6  // Better width estimation
        let estimatedHeight = Double(lines.count) * fontSize * 1.2   // Line height estimation

        // Create VectorText with proper areaSize for display
        var vectorText = VectorText(
            content: currentTextContent,
            typography: typography,
            position: position,
            areaSize: CGSize(width: max(100, estimatedWidth), height: max(fontSize, estimatedHeight))  // Ensure minimum size
        )

        // Set bounds explicitly for visibility
        vectorText.bounds = CGRect(
            x: position.x,
            y: position.y,
            width: max(100, estimatedWidth),
            height: max(fontSize, estimatedHeight)
        )

        // Convert to VectorShape
        let shape = vectorText.toVectorShape()
        shapes.append(shape)

    }
}
