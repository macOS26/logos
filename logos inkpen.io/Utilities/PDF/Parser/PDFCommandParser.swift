//
//  PDFCommandParser.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI

// MARK: - PDF Command Parser
class PDFCommandParser {
    var commands: [PathCommand] = []
    var currentPoint = CGPoint.zero
    var currentFillColor = CGColor(red: 0, green: 0, blue: 1, alpha: 1) // Default blue
    var currentStrokeColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1) // Default black
    var currentFillGradient: VectorGradient?
    var currentStrokeGradient: VectorGradient?
    var currentTransformMatrix: CGAffineTransform = CGAffineTransform.identity // Track CTM for gradient angles
    var shapes: [VectorShape] = []
    var currentPath: [PathCommand] = []
    var pathStartPoint = CGPoint.zero
    var pageSize = CGSize.zero
    
    // For gradient tracking
    var activeGradient: VectorGradient?
    var gradientShapes: [Int] = []
    
    // For opacity/transparency support
    var currentFillOpacity: Double = 1.0
    var currentStrokeOpacity: Double = 1.0
    var currentPage: CGPDFPage?

    // Stroke properties for proper stroke style creation
    var currentLineWidth: Double = 1.0
    var currentLineCap: CGLineCap = .butt
    var currentLineJoin: CGLineJoin = .miter
    var currentMiterLimit: Double = 10.0
    var currentLineDashPattern: [Double] = []
    
    // For page resources access
    var pageResourcesDict: CGPDFDictionaryRef?
    
    // PDF version tracking for proper logging
    var detectedPDFVersion: String = "PDF 1.4"
    
    // For proper compound path detection
    var isInCompoundPath = false
    var compoundPathParts: [[PathCommand]] = []
    var moveToCount = 0  // Track multiple MoveTo operations
    
    // XObject graphics state inheritance
    var xObjectSavedFillOpacity: Double = 1.0
    var xObjectSavedStrokeOpacity: Double = 1.0
    
    // Track graphics states that should apply to XObjects
    var gs1FillOpacity: Double = 1.0
    var gs1StrokeOpacity: Double = 1.0
    var gs3FillOpacity: Double = 1.0
    var gs3StrokeOpacity: Double = 1.0

    // For clipping path support
    var isInsideClippingPath: Bool = false
    var currentClippingPathId: UUID? = nil
    var pendingClippingPath: VectorShape? = nil  // Store clipping path to add after clipped content
    // Note: currentTransformMatrix already exists and tracks the CTM

    // For transparent image handling
    var hasUpcomingTransparentImage: Bool = false
    var transparentImageBounds: CGRect? = nil

    // For detecting gradient vs image after W operator
    var hasClipOperatorPending: Bool = false  // Track if we just saw a W operator
    var clipOperatorPath: [PathCommand] = []  // Store the path from W operator

    // Graphics state stack for q/Q operators
    struct PDFGraphicsState {
        var transformMatrix: CGAffineTransform
        var fillOpacity: Double
        var strokeOpacity: Double
        var clippingPathId: UUID?
        var isInsideClippingPath: Bool
        var pendingClippingPath: VectorShape?
    }
    var graphicsStateStack: [PDFGraphicsState] = []

    // MARK: - Text State Properties
    var isInTextObject: Bool = false  // Track if we're between BT and ET
    var currentTextMatrix: CGAffineTransform = .identity  // Text matrix (Tm)
    var currentLineMatrix: CGAffineTransform = .identity  // Line matrix
    var currentFontName: String? = nil  // Current font name from resources
    var currentFontSize: Double = 12.0  // Font size in points
    var textCharacterSpacing: Double = 0.0  // Character spacing (Tc)
    var textWordSpacing: Double = 0.0  // Word spacing (Tw)
    var textHorizontalScaling: Double = 100.0  // Horizontal scaling percentage (Tz)
    var textLeading: Double = 0.0  // Text leading (TL)
    var textRise: Double = 0.0  // Text rise (Ts)
    var textRenderingMode: Int = 0  // 0=fill, 1=stroke, 2=fill+stroke, 3=invisible, etc.

    // Text accumulation
    var currentTextContent: String = ""  // Accumulated text in current text object
    var currentTextStartPosition: CGPoint = .zero  // Starting position of text object
    var pendingTextShapes: [VectorShape] = []  // Text shapes waiting to be added

    // Font encoding support for ligatures and custom encodings
    var currentFontDict: CGPDFDictionaryRef? = nil  // Current font dictionary for ToUnicode CMap

    func parseDocument(at url: URL) -> [VectorShape] {
        commands.removeAll()
        shapes.removeAll()
        
        guard let dataProvider = CGDataProvider(url: url as CFURL),
              let document = CGPDFDocument(dataProvider) else {
            Log.error("Failed to load PDF document", category: .error)
            return []
        }
        
        // Detect PDF version
        detectedPDFVersion = detectPDFVersion(document: document)
        
        // Get page size from first page
        if let firstPage = document.page(at: 1) {
            let mediaBox = firstPage.getBoxRect(.mediaBox)
            pageSize = mediaBox.size
        }
        
        // Parse all pages
        for pageNumber in 1...document.numberOfPages {
            parsePage(document: document, pageNumber: pageNumber)
        }
        
        // Finalize any remaining path
        if !currentPath.isEmpty {
            createShapeFromCurrentPath(filled: true, stroked: false)
        }

        // If we still have a pending clipping path at the end, add it now
        if let pendingClip = pendingClippingPath {
            shapes.append(pendingClip)
            pendingClippingPath = nil
        }

        // Remove duplicate shapes that match clipping paths
        removeDuplicateClippingShapes()

        // Final gradient processing (handled by specialized gradient modules)
        // TODO: Implement createCompoundPathWithGradient in gradient handling module

        
        // Calculate actual artwork bounds and update pageSize
        if !shapes.isEmpty {
            let artworkBounds = calculateArtworkBounds()
            pageSize = artworkBounds.size
        }
        
        return shapes
    }
    
    func detectPDFVersion(document: CGPDFDocument) -> String {
        // CGPDFDocument doesn't directly expose version, but we can check its capabilities
        // For now, assume PDF 1.4+ since we're dealing with transparency features
        let versionString = "PDF1.7"  // Shorter format for logging
        return versionString
    }
    
    func parsePage(document: CGPDFDocument, pageNumber: Int) {
        guard let page = document.page(at: pageNumber) else { return }

        // Store current page for resource access
        currentPage = page

        // Get page resources dictionary for font resolution
        if let pageDict = page.dictionary {
            CGPDFDictionaryGetDictionary(pageDict, "Resources", &pageResourcesDict)
        }

        // Create operator table
        guard let operatorTable = CGPDFOperatorTableCreate() else { return }
        
        // Setup operator callbacks
        setupOperatorCallbacks(operatorTable)

        // Suppress CoreGraphics stderr warnings - these are false positives from internal validation
        let savedStderr = dup(STDERR_FILENO)
        let devNull = open("/dev/null", O_WRONLY)
        dup2(devNull, STDERR_FILENO)
        close(devNull)

        // Create scanner for page content
        let contentStream = CGPDFContentStreamCreateWithPage(page)
        let scanner = CGPDFScannerCreate(contentStream, operatorTable, Unmanaged.passUnretained(self).toOpaque())

        // Scan the content stream
        CGPDFScannerScan(scanner)

        // Restore stderr
        dup2(savedStderr, STDERR_FILENO)
        close(savedStderr)
    }
    
    func setupOperatorCallbacks(_ operatorTable: CGPDFOperatorTableRef) {
        // Delegate to the dedicated operator interpreter module
        PDFOperatorInterpreter.setupOperatorCallbacks(operatorTable, parser: self)
    }
    
    // MARK: - Legacy operator callback setup (replaced by PDFOperatorInterpreter)
    
    // MARK: - Utility Methods

    func removeDuplicateClippingShapes() {
        // Find all clipping paths
        let clippingPaths = shapes.filter { $0.isClippingPath }

        // For each clipping path, check if there's a duplicate filled shape
        for clippingPath in clippingPaths {
            // Find shapes with the same path but filled
            let duplicates = shapes.filter { shape in
                !shape.isClippingPath &&
                shape.path.elements.count == clippingPath.path.elements.count &&
                pathsAreEqual(shape.path, clippingPath.path)
            }

            // Remove the duplicates
            for duplicate in duplicates {
                if let index = shapes.firstIndex(where: { $0.id == duplicate.id }) {
                    shapes.remove(at: index)
                }
            }
        }

        // Also remove duplicate outer paths in compound paths
        // Find compound paths
        let compoundPaths = shapes.filter { $0.isCompoundPath || $0.name.contains("Compound") }

        if !compoundPaths.isEmpty {
            // For compound paths, remove any duplicate outer boundary shapes
            var indicesToRemove: Set<Int> = []

            for (index, shape) in shapes.enumerated() {
                // Skip if already marked for removal or is a compound path itself
                if indicesToRemove.contains(index) || shape.isCompoundPath || shape.name.contains("Compound") {
                    continue
                }

                // Check if this shape looks like an outer boundary (single closed path)
                if shape.path.isClosed && !shape.isClippingPath {
                    // Check if it matches the outer boundary of any compound path
                    for compound in compoundPaths {
                        if shapeMatchesOuterBoundary(shape, of: compound) {
                            indicesToRemove.insert(index)
                            break
                        }
                    }
                }
            }

            // Remove in reverse order to maintain indices
            for index in indicesToRemove.sorted(by: >) {
                shapes.remove(at: index)
            }
        }
    }

    func shapeMatchesOuterBoundary(_ shape: VectorShape, of compound: VectorShape) -> Bool {
        // Get the bounding box of both shapes
        let shapeBounds = shape.bounds
        let compoundBounds = compound.bounds

        // Check if the bounds are very similar (within tolerance)
        let tolerance: CGFloat = 1.0
        return abs(shapeBounds.minX - compoundBounds.minX) < tolerance &&
               abs(shapeBounds.minY - compoundBounds.minY) < tolerance &&
               abs(shapeBounds.maxX - compoundBounds.maxX) < tolerance &&
               abs(shapeBounds.maxY - compoundBounds.maxY) < tolerance
    }

    func pathsAreEqual(_ path1: VectorPath, _ path2: VectorPath) -> Bool {
        guard path1.elements.count == path2.elements.count else { return false }

        for (element1, element2) in zip(path1.elements, path2.elements) {
            // Compare path elements with small tolerance for floating point
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
        // Delegate to the dedicated geometry module
        return PDFBoundsCalculator.calculateArtworkBounds(from: shapes, pageSize: pageSize)
    }
    
    // MARK: - Operator Handlers (Moved to PDFOperatorHandlers.swift)
    
    // MARK: - Quadratic Curve Detection (Moved to PDFCurveOptimizer module)
    
    // MARK: - Color Handlers (Moved to PDFColorHandlers.swift)
    
    // MARK: - Opacity/Transparency Handlers (Moved to PDFTransparencyHandlers.swift)
    
}

