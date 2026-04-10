import SwiftUI

class PDFCommandParser {
    var commands: [PathCommand] = []
    var currentPoint = CGPoint.zero
    // PDF 1.7 spec §8.6.8 Table 52: the initial colour in both the fill and stroke
    // colour parameters is black. Reference: pdf.js src/core/operator_list.js sets
    // fillColor = "#000000" as the default. The blue default here was a bug causing
    // all text to render blue when the PDF's `g` (set-gray) operator fired before
    // text extraction but the initial state carried through.
    var currentFillColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
    var currentStrokeColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1)
    var currentFillGradient: VectorGradient?
    var currentStrokeGradient: VectorGradient?
    var currentTransformMatrix: CGAffineTransform = CGAffineTransform.identity
    var simdTransformMatrix: PDFSIMDMatrix = PDFSIMDMatrix()
    var shapes: [VectorShape] = []
    var currentPath: [PathCommand] = []
    var pathStartPoint = CGPoint.zero
    var pageSize = CGSize.zero
    var pageOrigin = CGPoint.zero
    var onShapeCreated: ((VectorShape) -> Void)?

    var activeGradient: VectorGradient?
    var gradientShapes: [Int] = []
    var currentFillOpacity: Double = 1.0
    var currentStrokeOpacity: Double = 1.0
    var currentPage: CGPDFPage?
    var currentLineWidth: Double = 1.0
    var currentLineCap: CGLineCap = .butt
    var currentLineJoin: CGLineJoin = .miter
    var currentMiterLimit: Double = 10.0
    var currentLineDashPattern: [Double] = []
    var pageResourcesDict: CGPDFDictionaryRef?

    var detectedPDFVersion: String = "PDF 1.4"
    var isInCompoundPath = false
    var compoundPathParts: [[PathCommand]] = []
    var moveToCount = 0
    var xObjectSavedFillOpacity: Double = 1.0
    var xObjectSavedStrokeOpacity: Double = 1.0
    var gs1FillOpacity: Double = 1.0
    var gs1StrokeOpacity: Double = 1.0
    var gs3FillOpacity: Double = 1.0
    var gs3StrokeOpacity: Double = 1.0
    var isInsideClippingPath: Bool = false
    var currentClippingPathId: UUID? = nil
    var pendingClippingPath: VectorShape? = nil
    var hasUpcomingTransparentImage: Bool = false
    var transparentImageBounds: CGRect? = nil
    var hasClipOperatorPending: Bool = false
    var clipOperatorPath: [PathCommand] = []

    struct PDFGraphicsState {
        var transformMatrix: CGAffineTransform
        var simdTransformMatrix: PDFSIMDMatrix
        var fillOpacity: Double
        var strokeOpacity: Double
        var clippingPathId: UUID?
        var isInsideClippingPath: Bool
        var pendingClippingPath: VectorShape?
    }
    var graphicsStateStack: [PDFGraphicsState] = []
    var isInTextObject: Bool = false
    var currentTextMatrix: CGAffineTransform = .identity
    var currentLineMatrix: CGAffineTransform = .identity
    var simdTextMatrix: PDFSIMDMatrix = PDFSIMDMatrix()
    var simdLineMatrix: PDFSIMDMatrix = PDFSIMDMatrix()
    var currentFontName: String? = nil
    var currentFontSize: Double = 12.0
    var textCharacterSpacing: Double = 0.0
    var textWordSpacing: Double = 0.0
    var textHorizontalScaling: Double = 100.0
    var textLeading: Double = 0.0
    var textRise: Double = 0.0
    var textRenderingMode: Int = 0
    var currentTextContent: String = ""
    var currentTextStartPosition: CGPoint = .zero
    var pendingTextShapes: [VectorShape] = []
    var currentFontDict: CGPDFDictionaryRef? = nil

    var pdfCreator: String = ""
    var usesTextMatrixForPosition: Bool? = nil
    var needsYFlip: Bool? = nil

    func parseDocument(at url: URL) -> [VectorShape] {
        commands.removeAll()
        shapes.removeAll()

        guard let dataProvider = CGDataProvider(url: url as CFURL),
              let document = CGPDFDocument(dataProvider) else {
            Log.error("Failed to load PDF document", category: .error)
            return []
        }

        detectedPDFVersion = detectPDFVersion(document: document)

        detectPDFCreator(document: document)

        if let firstPage = document.page(at: 1) {
            let mediaBox = firstPage.getBoxRect(.mediaBox)
            pageSize = mediaBox.size
            pageOrigin = mediaBox.origin
        }

        for pageNumber in 1...document.numberOfPages {
            parsePage(document: document, pageNumber: pageNumber)
        }

        if !currentPath.isEmpty {
            createShapeFromCurrentPath(filled: true, stroked: false)
        }

        if let pendingClip = pendingClippingPath {
            shapes.append(pendingClip)
            pendingClippingPath = nil
        }

        removeDuplicateClippingShapes()

        // Post-processing pass: merge per-word text shapes into per-line text
        // shapes. The PDF stream-time merge logic is brittle because some PDFs
        // emit a new Tm/Td per word which the stream parser can't always detect
        // as "same line". This pass operates on the final shapes array and
        // groups adjacent text shapes by visual line (Y within tolerance), then
        // concatenates their content with single spaces into one VectorText per
        // visual line. The merged shape goes through the same CTLine rendering
        // pipeline as native-typed InkPen text.
        shapes = mergeTextShapesByLine(shapes)

        if !shapes.isEmpty {
            let artworkBounds = calculateArtworkBounds()
            pageSize = artworkBounds.size
        }

        return shapes
    }

    // Merges consecutive text shapes on the same visual line into single text
    // shapes with space-separated content. Preserves order — runs through the
    // shapes array linearly and only merges adjacent text shapes whose Y
    // baselines are within 2pt of each other.
    private func mergeTextShapesByLine(_ input: [VectorShape]) -> [VectorShape] {
        guard !input.isEmpty else { return input }
        var result: [VectorShape] = []
        var pending: VectorShape? = nil

        func isTextShape(_ s: VectorShape) -> Bool {
            return s.textContent != nil && !(s.textContent ?? "").isEmpty
        }

        func shapeY(_ s: VectorShape) -> CGFloat {
            // Prefer textPosition (the anchor point), fall back to bounds.
            return s.textPosition?.y ?? s.bounds.minY
        }
        func shapeX(_ s: VectorShape) -> CGFloat {
            return s.textPosition?.x ?? s.bounds.minX
        }

        func canMerge(_ a: VectorShape, _ b: VectorShape) -> Bool {
            guard isTextShape(a) && isTextShape(b) else { return false }
            // Same visual line: Y baseline within tolerance
            let yDelta = abs(shapeY(a) - shapeY(b))
            guard yDelta < 2.0 else { return false }
            // Same typography family — if font families differ by more than
            // the basics, keep them separate (e.g., a bold heading word next
            // to regular body text should stay separate).
            guard a.typography?.fontFamily == b.typography?.fontFamily else { return false }
            guard abs((a.typography?.fontSize ?? 0) - (b.typography?.fontSize ?? 0)) < 0.5 else { return false }
            return true
        }

        for shape in input {
            if let prev = pending, canMerge(prev, shape) {
                // Merge shape into prev: concatenate content with a single space.
                var merged = prev
                let prevContent = (prev.textContent ?? "")
                let nextContent = (shape.textContent ?? "")
                let joiner: String
                if prevContent.last?.isWhitespace == true || nextContent.first?.isWhitespace == true {
                    joiner = ""
                } else {
                    joiner = " "
                }
                merged.textContent = prevContent + joiner + nextContent
                // Anchor the merged text at the leftmost starting position.
                if let prevPos = prev.textPosition {
                    merged.textPosition = CGPoint(x: min(prevPos.x, shapeX(shape)), y: prevPos.y)
                }
                pending = merged
            } else {
                if let prev = pending {
                    result.append(finalizeTextShapeWidth(prev))
                }
                pending = shape
            }
        }
        if let prev = pending {
            result.append(finalizeTextShapeWidth(prev))
        }
        return result
    }

    // After merging, recompute the areaSize width using NSAttributedString layout
    // so the merged line has enough room for its content to render on ONE line
    // without wrapping. Mirrors the measurement logic in the export path.
    private func finalizeTextShapeWidth(_ shape: VectorShape) -> VectorShape {
        guard let content = shape.textContent, !content.isEmpty,
              let typography = shape.typography else {
            return shape
        }
        var result = shape
        let nsFont = typography.nsFont
        let attrs: [NSAttributedString.Key: Any] = [
            .font: nsFont,
            .kern: typography.letterSpacing
        ]
        let measured = (content as NSString).size(withAttributes: attrs)
        // Add a small padding so the text doesn't get clipped at the right edge.
        let padding: CGFloat = 4.0
        let measuredWidth = ceil(measured.width) + padding
        let measuredHeight = max(ceil(measured.height), CGFloat(typography.lineHeight))

        if var area = result.areaSize {
            area.width = max(area.width, measuredWidth)
            area.height = max(area.height, measuredHeight)
            result.areaSize = area
        } else {
            result.areaSize = CGSize(width: measuredWidth, height: measuredHeight)
        }

        // Update bounds to match the measured size, anchored at the text position.
        let originX = result.textPosition?.x ?? result.bounds.minX
        let originY = result.textPosition?.y ?? result.bounds.minY
        result.bounds = CGRect(x: originX, y: originY,
                               width: max(measuredWidth, result.bounds.width),
                               height: max(measuredHeight, result.bounds.height))
        return result
    }

    func detectPDFVersion(document: CGPDFDocument) -> String {
        let versionString = "PDF1.7"
        return versionString
    }

    func detectPDFCreator(document: CGPDFDocument) {
        guard let info = document.info else {
            pdfCreator = ""
            return
        }

        var creatorStringRef: CGPDFStringRef?
        if CGPDFDictionaryGetString(info, "Creator", &creatorStringRef),
           let creatorStringRef = creatorStringRef {
            if let cfString = CGPDFStringCopyTextString(creatorStringRef) {
                pdfCreator = cfString as String
            }
        }
    }

    func parsePage(document: CGPDFDocument, pageNumber: Int) {
        autoreleasepool {
            guard let page = document.page(at: pageNumber) else { return }

            currentPage = page

            if let pageDict = page.dictionary {
                CGPDFDictionaryGetDictionary(pageDict, "Resources", &pageResourcesDict)
            }

            guard let operatorTable = CGPDFOperatorTableCreate() else { return }

            setupOperatorCallbacks(operatorTable)

            let savedStderr = dup(STDERR_FILENO)
            let devNull = open("/dev/null", O_WRONLY)
            dup2(devNull, STDERR_FILENO)
            close(devNull)

            let contentStream = CGPDFContentStreamCreateWithPage(page)
            let scanner = CGPDFScannerCreate(contentStream, operatorTable, Unmanaged.passUnretained(self).toOpaque())

            CGPDFScannerScan(scanner)

            dup2(savedStderr, STDERR_FILENO)
            close(savedStderr)

            currentPage = nil
            pageResourcesDict = nil
        }
    }

    func setupOperatorCallbacks(_ operatorTable: CGPDFOperatorTableRef) {
        PDFOperatorInterpreter.setupOperatorCallbacks(operatorTable, parser: self)
    }

    func removeDuplicateClippingShapes() {
        let clippingPaths = shapes.filter { $0.isClippingPath }

        for clippingPath in clippingPaths {
            let duplicates = shapes.filter { shape in
                !shape.isClippingPath &&
                shape.path.elements.count == clippingPath.path.elements.count &&
                pathsAreEqual(shape.path, clippingPath.path)
            }

            for duplicate in duplicates {
                if let index = shapes.firstIndex(where: { $0.id == duplicate.id }) {
                    shapes.remove(at: index)
                }
            }
        }

        let compoundPaths = shapes.filter { $0.isCompoundPath || $0.name.contains("Compound") }

        if !compoundPaths.isEmpty {
            var indicesToRemove: Set<Int> = []

            for (index, shape) in shapes.enumerated() {
                if indicesToRemove.contains(index) || shape.isCompoundPath || shape.name.contains("Compound") {
                    continue
                }

                if shape.path.isClosed && !shape.isClippingPath {
                    for compound in compoundPaths {
                        if shapeMatchesOuterBoundary(shape, of: compound) {
                            indicesToRemove.insert(index)
                            break
                        }
                    }
                }
            }

            for index in indicesToRemove.sorted(by: >) {
                shapes.remove(at: index)
            }
        }
    }

    func shapeMatchesOuterBoundary(_ shape: VectorShape, of compound: VectorShape) -> Bool {
        let shapeBounds = shape.bounds
        let compoundBounds = compound.bounds
        let tolerance: CGFloat = 1.0
        return abs(shapeBounds.minX - compoundBounds.minX) < tolerance &&
               abs(shapeBounds.minY - compoundBounds.minY) < tolerance &&
               abs(shapeBounds.maxX - compoundBounds.maxX) < tolerance &&
               abs(shapeBounds.maxY - compoundBounds.maxY) < tolerance
    }

    func pathsAreEqual(_ path1: VectorPath, _ path2: VectorPath) -> Bool {
        guard path1.elements.count == path2.elements.count else { return false }

        for (element1, element2) in zip(path1.elements, path2.elements) {
            if !elementsAreEqual(element1, element2) {
                return false
            }
        }
        return true
    }

    func elementsAreEqual(_ e1: PathElement, _ e2: PathElement) -> Bool {
        let tolerance = 0.01
        switch (e1, e2) {
        case (.move(let p1), .move(let p2)):
            return abs(p1.x - p2.x) < tolerance && abs(p1.y - p2.y) < tolerance
        case (.line(let p1), .line(let p2)):
            return abs(p1.x - p2.x) < tolerance && abs(p1.y - p2.y) < tolerance
        case (.curve(let to1, let c1_1, let c2_1), .curve(let to2, let c1_2, let c2_2)):
            return abs(to1.x - to2.x) < tolerance && abs(to1.y - to2.y) < tolerance &&
                   abs(c1_1.x - c1_2.x) < tolerance && abs(c1_1.y - c1_2.y) < tolerance &&
                   abs(c2_1.x - c2_2.x) < tolerance && abs(c2_1.y - c2_2.y) < tolerance
        case (.quadCurve(let to1, let c1), .quadCurve(let to2, let c2)):
            return abs(to1.x - to2.x) < tolerance && abs(to1.y - to2.y) < tolerance &&
                   abs(c1.x - c2.x) < tolerance && abs(c1.y - c2.y) < tolerance
        case (.close, .close):
            return true
        default:
            return false
        }
    }

    func calculateArtworkBounds() -> CGRect {
        return PDFBoundsCalculator.calculateArtworkBounds(from: shapes, pageSize: pageSize)
    }

}
