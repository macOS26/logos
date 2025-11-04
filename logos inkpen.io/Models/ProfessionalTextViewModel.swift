import SwiftUI
import AppKit
import CoreText
import Combine

@MainActor
class ProfessionalTextViewModel: ObservableObject {
    @Published var text: String = ""
    @Published var fontSize: CGFloat = 24.0
    @Published var selectedFont: NSFont = NSFont.systemFont(ofSize: 24.0)
    @Published var textAlignment: NSTextAlignment = .center
    @Published var isEditing: Bool = false
    @Published var textBoxFrame: CGRect = CGRect(x: 100, y: 100, width: 200, height: 100)
    @Published var userInitiatedCursorPosition: Int = 0
    @Published var textObject: VectorText
    let document: VectorDocument
    var linePaths: [CGPath] = []

    init(textObject: VectorText, document: VectorDocument) {
        self.textObject = textObject
        self.document = document

        self.text = textObject.content
        self.fontSize = CGFloat(textObject.typography.fontSize)
        self.selectedFont = textObject.typography.nsFont
        self.textAlignment = textObject.typography.alignment.nsTextAlignment

        let width = textObject.areaSize?.width ?? 200.0
        let height = textObject.areaSize?.height ?? calculateTextHeight(for: textObject.content)

        self.textBoxFrame = CGRect(
            x: textObject.position.x,
            y: textObject.position.y,
            width: width,
            height: height
        )

        self.isEditing = textObject.isEditing
    }

    private func calculateTextHeight(for content: String) -> CGFloat {
        guard !content.isEmpty else { return 50.0 }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = textAlignment
        paragraphStyle.lineSpacing = max(0, textObject.typography.lineSpacing)
        paragraphStyle.minimumLineHeight = textObject.typography.lineHeight
        paragraphStyle.maximumLineHeight = textObject.typography.lineHeight

        let attributes: [NSAttributedString.Key: Any] = [
            .font: selectedFont,
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSAttributedString(string: content, attributes: attributes)
        let textStorage = NSTextStorage(attributedString: attributedString)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(size: CGSize(width: textBoxFrame.width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = .byWordWrapping
        layoutManager.addTextContainer(textContainer)

        layoutManager.ensureGlyphs(forGlyphRange: NSRange(location: 0, length: content.count))
        layoutManager.ensureLayout(for: textContainer)

        let usedRect = layoutManager.usedRect(for: textContainer)
        return max(50.0, ceil(usedRect.height + 10))
    }

    func syncFromDocument(_ textObject: VectorText) {
        guard self.textObject.id == textObject.id else {
            Log.error("❌ SYNC ERROR: Mismatched text IDs", category: .error)
            return
        }

        if isEditing && Date().timeIntervalSince1970 - lastTypingTime < 0.1 {
            return
        }

        let contentChanged = self.text != textObject.content
        let documentContentEmpty = textObject.content.isEmpty
        let viewModelContentNotEmpty = !self.text.isEmpty
        let shouldSyncContent = contentChanged && !(documentContentEmpty && viewModelContentNotEmpty)

        let fontChanged = self.fontSize != CGFloat(textObject.typography.fontSize)
        let editingChanged = self.isEditing != textObject.isEditing
        let colorChanged = self.textObject.typography.fillColor != textObject.typography.fillColor
        let typographyChanged = (
            self.textObject.typography.alignment != textObject.typography.alignment ||
            self.textObject.typography.fontFamily != textObject.typography.fontFamily ||
            self.textObject.typography.fontVariant != textObject.typography.fontVariant ||
            abs(self.textObject.typography.lineHeight - textObject.typography.lineHeight) > 0.01 ||
            abs(self.textObject.typography.lineSpacing - textObject.typography.lineSpacing) > 0.01
        )

        let positionChanged = (
            abs(self.textBoxFrame.origin.x - textObject.position.x) > 0.1 ||
            abs(self.textBoxFrame.origin.y - textObject.position.y) > 0.1
        )

        let sizeChanged = (
            abs(self.textBoxFrame.width - textObject.bounds.width) > 0.1 ||
            abs(self.textBoxFrame.height - textObject.bounds.height) > 0.1
        )

        if !shouldSyncContent && !fontChanged && !editingChanged && !colorChanged && !typographyChanged && !positionChanged && !sizeChanged {
            return
        }

        let wasAutoResizing = isAutoResizing
        isAutoResizing = true
        defer { isAutoResizing = wasAutoResizing }

        self.textObject = textObject

        if shouldSyncContent {
            self.text = textObject.content
        }

        self.fontSize = CGFloat(textObject.typography.fontSize)

        self.selectedFont = textObject.typography.nsFont

        if !self.isEditing {
            self.isEditing = textObject.isEditing
        }

        if textObject.isEditing && textObject.cursorPosition != self.userInitiatedCursorPosition {
            // Prevent cursor jump when double-clicking already-selected text
            // If new position is exactly -1 from current, it's likely a race condition - ignore it
            let positionDelta = textObject.cursorPosition - self.userInitiatedCursorPosition
            if positionDelta != -1 {
                self.userInitiatedCursorPosition = textObject.cursorPosition
            }
        }

        self.textAlignment = textObject.typography.alignment.nsTextAlignment

        self.textBoxFrame = CGRect(
            x: textObject.position.x,
            y: textObject.position.y,
            width: textObject.bounds.width,
            height: textObject.bounds.height
        )

    }

    private var lastTypingTime: TimeInterval = 0

    func updateLastTypingTime() {
        lastTypingTime = Date().timeIntervalSince1970
    }

    var isAutoResizing = false

    func startEditing() {
        for obj in document.snapshot.objects.values {
            if case .text(let shape) = obj.objectType,
               shape.id != textObject.id,
               shape.isEditing == true {
                document.setTextEditingInUnified(id: shape.id, isEditing: false)
            }
        }

        isEditing = true
    }

    func stopEditing() {
        isEditing = false

        updateDocumentTextBounds(textBoxFrame)
    }

    func updateTextBoxFrame(_ newFrame: CGRect) {
        isAutoResizing = true

        textBoxFrame = newFrame

        updateDocumentTextBounds(newFrame)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.isAutoResizing = false
        }
    }

    func updateDocumentTextBounds(_ frame: CGRect) {
        // Batch all three updates into ONE to avoid multiple layer panel refreshes
        document.updateShapeByID(textObject.id) { shape in
            shape.transform = CGAffineTransform(translationX: frame.minX, y: frame.minY)
            shape.textPosition = CGPoint(x: frame.minX, y: frame.minY)
            shape.bounds = CGRect(x: 0, y: 0, width: frame.width, height: frame.height)
            shape.areaSize = CGSize(width: frame.width, height: frame.height)
        }
    }

    private func isRectangleGlyph(_ path: CGPath) -> Bool {
        var subpaths: [[CGPoint]] = []
        var currentPath: [CGPoint] = []
        var hasCurves = false

        path.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            switch element.type {
            case .moveToPoint:
                if !currentPath.isEmpty {
                    subpaths.append(currentPath)
                }
                currentPath = [element.points[0]]

            case .addLineToPoint:
                currentPath.append(element.points[0])

            case .addQuadCurveToPoint, .addCurveToPoint:
                hasCurves = true

            case .closeSubpath:
                if !currentPath.isEmpty {
                    subpaths.append(currentPath)
                    currentPath = []
                }

            @unknown default:
                break
            }
        }

        if !currentPath.isEmpty {
            subpaths.append(currentPath)
        }

        if hasCurves {
            return false
        }

        if subpaths.count != 2 {
            return false
        }

        for subpath in subpaths {
            if subpath.count < 4 || subpath.count > 5 {
                return false
            }

            if !isRectangularPath(subpath) {
                return false
            }
        }

        let bounds1 = boundingBox(of: subpaths[0])
        let bounds2 = boundingBox(of: subpaths[1])
        let isNested = (bounds1.contains(bounds2) || bounds2.contains(bounds1))

        if isNested {
            Log.warning("⚠️ DETECTED RECTANGLE GLYPH: Missing character placeholder with rectangular counter", category: .general)
            return true
        }

        return false
    }

    private func isRectangularPath(_ points: [CGPoint]) -> Bool {
        guard points.count >= 4 else { return false }

        for i in 0..<points.count - 1 {
            let p1 = points[i]
            let p2 = points[i + 1]
            let dx = abs(p2.x - p1.x)
            let dy = abs(p2.y - p1.y)
            let isHorizontal = dy < 0.1 && dx > 0.1
            let isVertical = dx < 0.1 && dy > 0.1

            if !isHorizontal && !isVertical {
                return false
            }
        }

        return true
    }

    private func boundingBox(of points: [CGPoint]) -> CGRect {
        guard !points.isEmpty else { return .zero }

        var minX = points[0].x
        var maxX = points[0].x
        var minY = points[0].y
        var maxY = points[0].y

        for point in points {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func convertUsingNSLayoutManager() {
        let nsFont = selectedFont
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = textAlignment
        paragraphStyle.lineSpacing = max(0, textObject.typography.lineSpacing)
        paragraphStyle.minimumLineHeight = textObject.typography.lineHeight
        paragraphStyle.maximumLineHeight = textObject.typography.lineHeight

        let attributes: [NSAttributedString.Key: Any] = [
            .font: nsFont,
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textStorage = NSTextStorage(attributedString: attributedString)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(size: CGSize(width: textBoxFrame.width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = .byWordWrapping
        layoutManager.addTextContainer(textContainer)

        layoutManager.ensureGlyphs(forGlyphRange: NSRange(location: 0, length: text.count))
        layoutManager.ensureLayout(for: textContainer)
        linePaths = []
        let combinedPath = CGMutablePath()
        let ctFont = CTFontCreateWithGraphicsFont(
            CTFontCopyGraphicsFont(nsFont as CTFont, nil),
            nsFont.pointSize,
            nil,
            nil
        )

        let glyphRange = layoutManager.glyphRange(for: textContainer)
        var skippedGlyphCount = 0

        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { (lineRect, lineUsedRect, container, lineRange, stop) in
            let linePath = CGMutablePath()

            for glyphIndex in lineRange.location..<NSMaxRange(lineRange) {
                let glyph = layoutManager.cgGlyph(at: glyphIndex)
                let glyphLocation = layoutManager.location(forGlyphAt: glyphIndex)
                var actualLineRect = CGRect.zero
                var actualUsedRect = CGRect.zero
                var effectiveRange = NSRange()
                actualLineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &effectiveRange, withoutAdditionalLayout: true)
                actualUsedRect = layoutManager.lineFragmentUsedRect(forGlyphAt: glyphIndex, effectiveRange: &effectiveRange, withoutAdditionalLayout: true)

                let glyphX: CGFloat

                switch self.textAlignment {
                case .left, .justified:
                    glyphX = self.textBoxFrame.origin.x + actualUsedRect.origin.x + glyphLocation.x

                case .center, .right:
                    glyphX = self.textBoxFrame.origin.x + lineRect.origin.x + glyphLocation.x

                default:
                    glyphX = self.textBoxFrame.origin.x + actualUsedRect.origin.x + glyphLocation.x
                }

                let glyphY = self.textBoxFrame.origin.y + actualLineRect.origin.y + glyphLocation.y

                if let glyphPath = CTFontCreatePathForGlyph(ctFont, CGGlyph(glyph), nil) {
                    if self.isRectangleGlyph(glyphPath) {
                        skippedGlyphCount += 1

                        let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
                        let char = (self.text as NSString).substring(with: NSRange(location: charIndex, length: 1))
                        Log.warning("⚠️ SKIPPING RECTANGLE GLYPH: Character '\(char)' at index \(charIndex) - missing from font", category: .general)
                        continue
                    }

                    var unionedGlyph: CGPath
                    if let unionResult = ProfessionalPathOperations.union([glyphPath, glyphPath]) {
                        unionedGlyph = unionResult.normalized()
                    } else {
                        unionedGlyph = glyphPath
                    }

                    var transform = CGAffineTransform(scaleX: 1.0, y: -1.0)
                    transform = transform.translatedBy(x: glyphX, y: -glyphY)

                    linePath.addPath(unionedGlyph, transform: transform)
                }
            }

            if !linePath.isEmpty {
                self.linePaths.append(linePath)
                combinedPath.addPath(linePath)
            }
        }

        if skippedGlyphCount > 0 {
            Log.warning("⚠️ RECTANGLE DETECTION: Skipped \(skippedGlyphCount) missing character placeholder(s)", category: .fileOperations)
        }
    }

    private func convertToCoreTextPath() {
        convertUsingNSLayoutManager()
    }

    func convertToPath() {
        guard !text.isEmpty else {
            Log.error("❌ CONVERT TO OUTLINES: Cannot convert empty text", category: .error)
            return
        }

        convertToCoreTextPath()

        guard !linePaths.isEmpty else {
            Log.error("❌ CONVERT TO OUTLINES FAILED: No line paths created", category: .error)
            return
        }

        let targetLayerIndex = document.selectedLayerIndex ?? 2
        var createdShapeIDs: [UUID] = []
        for (lineIndex, linePath) in linePaths.enumerated() {
            let vectorPath = convertCGPathToVectorPath(linePath)
            let lineName = "Line \(lineIndex + 1)"
            let outlineShape = VectorShape(
                name: lineName,
                path: vectorPath,
                strokeStyle: nil,
                fillStyle: FillStyle(
                    color: textObject.typography.fillColor,
                    opacity: textObject.typography.fillOpacity
                ),
                transform: .identity,
                isGroup: false,
                textContent: nil,
                typography: nil,
                cursorPosition: nil,
                areaSize: nil,
                isEditing: nil,
                textPosition: nil
            )

            // Force type to .shape (NOT .text)
            let shapeObject = VectorObject(id: outlineShape.id, layerIndex: targetLayerIndex, objectType: .shape(outlineShape))
            document.snapshot.objects[outlineShape.id] = shapeObject
            if !document.snapshot.layers[targetLayerIndex].objectIDs.contains(outlineShape.id) {
                document.snapshot.layers[targetLayerIndex].objectIDs.append(outlineShape.id)
            }
            createdShapeIDs.append(outlineShape.id)
        }

        document.removeTextFromUnifiedSystem(id: textObject.id)
    }

    func convertCGPathToVectorPath(_ cgPath: CGPath) -> VectorPath {
        var elements: [PathElement] = []

        cgPath.applyWithBlock { elementPointer in
            let element = elementPointer.pointee

            switch element.type {
            case .moveToPoint:
                let point = element.points[0]
                elements.append(.move(to: VectorPoint(Double(point.x), Double(point.y))))

            case .addLineToPoint:
                let point = element.points[0]
                elements.append(.line(to: VectorPoint(Double(point.x), Double(point.y))))

            case .addQuadCurveToPoint:
                let control = element.points[0]
                let point = element.points[1]
                elements.append(.quadCurve(
                    to: VectorPoint(Double(point.x), Double(point.y)),
                    control: VectorPoint(Double(control.x), Double(control.y))
                ))

            case .addCurveToPoint:
                let control1 = element.points[0]
                let control2 = element.points[1]
                let point = element.points[2]
                elements.append(.curve(
                    to: VectorPoint(Double(point.x), Double(point.y)),
                    control1: VectorPoint(Double(control1.x), Double(control1.y)),
                    control2: VectorPoint(Double(control2.x), Double(control2.y))
                ))

            case .closeSubpath:
                elements.append(.close)

            @unknown default:
                break
            }
        }

        // Convert near-180-degree handles to perfectly smooth curves
        elements = makeCurvesSmooth(elements)

        return VectorPath(elements: elements, isClosed: false)
    }

    /// Convert curves with nearly-aligned handles (close to 180 degrees) into perfectly smooth curves
    private func makeCurvesSmooth(_ elements: [PathElement]) -> [PathElement] {
        var smoothedElements: [PathElement] = []
        let angleTolerance = 10.0 * .pi / 180.0  // 10 degrees tolerance

        for i in 0..<elements.count {
            let currentElement = elements[i]

            // Only process curve elements
            guard case .curve(let anchor, let incomingHandle, let outgoingHandle) = currentElement else {
                smoothedElements.append(currentElement)
                continue
            }

            // For a smooth curve, incoming and outgoing handles must be 180° apart from the anchor
            // Vector from anchor to incoming handle
            let incomingVec = CGVector(dx: incomingHandle.x - anchor.x, dy: incomingHandle.y - anchor.y)
            // Vector from anchor to outgoing handle
            let outgoingVec = CGVector(dx: outgoingHandle.x - anchor.x, dy: outgoingHandle.y - anchor.y)

            let incomingAngle = atan2(incomingVec.dy, incomingVec.dx)
            let outgoingAngle = atan2(outgoingVec.dy, outgoingVec.dx)

            var angleDiff = abs(incomingAngle - outgoingAngle)
            if angleDiff > .pi { angleDiff = 2 * .pi - angleDiff }

            // If handles are close to 180 degrees apart (π radians), make them perfectly aligned
            if abs(angleDiff - .pi) < angleTolerance {
                let incomingLength = sqrt(incomingVec.dx * incomingVec.dx + incomingVec.dy * incomingVec.dy)
                let outgoingLength = sqrt(outgoingVec.dx * outgoingVec.dx + outgoingVec.dy * outgoingVec.dy)

                // Use the average length for symmetry
                let avgLength = (incomingLength + outgoingLength) / 2.0

                // Make them perfectly opposite using the outgoing handle's direction
                let outgoingNormalized = CGVector(
                    dx: outgoingVec.dx / outgoingLength,
                    dy: outgoingVec.dy / outgoingLength
                )

                let smoothedIncoming = VectorPoint(
                    anchor.x - outgoingNormalized.dx * avgLength,
                    anchor.y - outgoingNormalized.dy * avgLength
                )

                let smoothedOutgoing = VectorPoint(
                    anchor.x + outgoingNormalized.dx * avgLength,
                    anchor.y + outgoingNormalized.dy * avgLength
                )

                smoothedElements.append(.curve(to: anchor, control1: smoothedIncoming, control2: smoothedOutgoing))
                continue
            }

            // No smoothing needed
            smoothedElements.append(currentElement)
        }

        return smoothedElements
    }

    func handleTextBoxInteraction(textID: UUID, isDoubleClick: Bool = false, isCornerClick: Bool = false, at location: CGPoint = .zero) {
        guard let textObject = document.findText(by: textID) else {
            Log.error("❌ TEXT NOT FOUND: ID \(textID)", category: .error)
            return
        }
        let currentState = textObject.getState(in: document)

        if textObject.isLocked {
            Log.warning("🚫 TEXT LOCKED: Cannot interact with locked text", category: .general)
            return
        }

        if isDoubleClick || isCornerClick {
            switch currentState {
            case .unselected:
                document.viewState.selectedObjectIDs = [textID]

                if document.viewState.currentTool == .font && isCornerClick {
                    startEditingText(textID: textID, at: location, isDoubleClickFromArrow: false)
                }

            case .selected:
                if isDoubleClick {
                    // Double-clicking from Arrow tool -> need +1 adjustment
                    let needsAdjustment = document.viewState.currentTool != .font
                    document.viewState.currentTool = .font

                    startEditingText(textID: textID, at: location, isDoubleClickFromArrow: needsAdjustment)
                } else if document.viewState.currentTool == .font {
                    startEditingText(textID: textID, at: location, isDoubleClickFromArrow: false)
                }

            case .editing:
                break
            }
        } else {
            switch currentState {
            case .unselected:
                document.viewState.selectedObjectIDs = [textID]

            case .selected:
                break

            case .editing:
                break
            }
        }
    }

    private func startEditingText(textID: UUID, at location: CGPoint = .zero, isDoubleClickFromArrow: Bool = false) {

        var editingCount = 0
        for obj in document.snapshot.objects.values {
            if case .text(let shape) = obj.objectType, shape.isEditing == true {
                document.setTextEditingInUnified(id: shape.id, isEditing: false)
                editingCount += 1
            }
        }

        if let textObject = document.findText(by: textID) {

            // Calculate and set cursor position FIRST, before triggering view updates
            if location != .zero {
                var cursorPosition = calculateCursorPosition(in: textObject, at: location)

                // ONLY add +1 when double-clicking from Arrow tool
                if isDoubleClickFromArrow {
                    cursorPosition = min(cursorPosition + 1, textObject.content.count)
                }

                document.updateTextCursorPositionInUnified(id: textObject.id, cursorPosition: cursorPosition)
            }

            // NOW set isEditing, which triggers view sync with correct cursor position
            document.setTextEditingInUnified(id: textObject.id, isEditing: true)

            document.viewState.selectedObjectIDs = [textID]

        } else {
            Log.error("❌ TEXT NOT FOUND: Could not find text with ID \(textID)", category: .error)
        }
    }

    private func calculateCursorPosition(in _: VectorText, at _: CGPoint) -> Int {
        return 0
    }
}
