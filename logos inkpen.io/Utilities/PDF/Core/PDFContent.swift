//
//  PDFContent.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation
import SwiftUI
import CoreGraphics
import PDFKit

// MARK: - Parser Functions (Implementation Required)
struct PDFContent {
    let shapes: [VectorShape]
    let textCount: Int
    let creator: String?
    let version: String?
}


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
    
    // For compound path handling
    var accumulatedPaths: [[PathCommand]] = []
    var pendingFillColor: CGColor?
    
    // For gradient tracking
    var activeGradient: VectorGradient?
    var gradientShapes: [Int] = []
    
    // For opacity/transparency support
    var currentFillOpacity: Double = 1.0
    var currentStrokeOpacity: Double = 1.0
    var currentPage: CGPDFPage?
    
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
    
    func parseDocument(at url: URL) -> [VectorShape] {
        commands.removeAll()
        shapes.removeAll()
        
        guard let dataProvider = CGDataProvider(url: url as CFURL),
              let document = CGPDFDocument(dataProvider) else {
            print("Failed to load PDF document")
            return []
        }
        
        // Detect PDF version
        detectedPDFVersion = detectPDFVersion(document: document)
        print("PDF: Document version detected as \(detectedPDFVersion)")
        
        // Get page size from first page
        if let firstPage = document.page(at: 1) {
            let mediaBox = firstPage.getBoxRect(.mediaBox)
            pageSize = mediaBox.size
            print("PDF: Page size detected as \(pageSize)")
        }
        
        // Parse all pages
        for pageNumber in 1...document.numberOfPages {
            parsePage(document: document, pageNumber: pageNumber)
        }
        
        // Finalize any remaining path
        if !currentPath.isEmpty {
            print("PDF: End of document - finalizing remaining path as default filled shape")
            createShapeFromCurrentPath(filled: true, stroked: false)
        }
        
        // If we have an active gradient with tracked shapes, create the compound path
        print("PDF: 🔍 Final check - activeGradient: \(activeGradient != nil), gradientShapes count: \(gradientShapes.count)")
        if let gradient = activeGradient, !gradientShapes.isEmpty {
            print("PDF: 📋 Creating final compound path with \(gradientShapes.count) tracked gradient shapes...")
            createCompoundPathWithGradient(gradient: gradient)
        } else if activeGradient != nil {
            print("PDF: ⚠️ Active gradient exists but no shapes tracked")
        } else if !gradientShapes.isEmpty {
            print("PDF: ⚠️ Shapes tracked but no active gradient")
        }
        
        print("PDF: Finished parsing. Total shapes created: \(shapes.count)")
        
        // Calculate actual artwork bounds and update pageSize
        if !shapes.isEmpty {
            let artworkBounds = calculateArtworkBounds()
            pageSize = artworkBounds.size
            print("PDF: 🎯 Updated page size to artwork bounds: \(pageSize)")
        }
        
        return shapes
    }
    
    func detectPDFVersion(document: CGPDFDocument) -> String {
        // CGPDFDocument doesn't directly expose version, but we can check its capabilities
        // For now, assume PDF 1.4+ since we're dealing with transparency features
        let versionString = "PDF1.7"  // Shorter format for logging
        print("PDF: Version \(versionString) (Acrobat 8 compatible) supports transparency (introduced in PDF 1.4)")
        return versionString
    }
    
    func parsePage(document: CGPDFDocument, pageNumber: Int) {
        guard let page = document.page(at: pageNumber) else { return }
        
        // Store current page for resource access
        currentPage = page
        
        // Create operator table
        guard let operatorTable = CGPDFOperatorTableCreate() else { return }
        
        // Setup operator callbacks
        setupOperatorCallbacks(operatorTable)
        
        // Create scanner for page content  
        let contentStream = CGPDFContentStreamCreateWithPage(page)
        
        let scanner = CGPDFScannerCreate(contentStream, operatorTable, Unmanaged.passUnretained(self).toOpaque())
        
        // Scan the content stream
        CGPDFScannerScan(scanner)
    }
    
    func setupOperatorCallbacks(_ operatorTable: CGPDFOperatorTableRef) {
        // Delegate to the dedicated operator interpreter module
        PDFOperatorInterpreter.setupOperatorCallbacks(operatorTable, parser: self)
    }
    
    func setupOperatorCallbacksOld(_ operatorTable: CGPDFOperatorTableRef) {
        // MoveTo operator
        CGPDFOperatorTableSetCallback(operatorTable, "m") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleMoveTo(scanner: scanner)
        }
        
        // LineTo operator
        CGPDFOperatorTableSetCallback(operatorTable, "l") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleLineTo(scanner: scanner)
        }
        
        // CurveTo operator (cubic Bézier)
        CGPDFOperatorTableSetCallback(operatorTable, "c") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleCurveTo(scanner: scanner)
        }
        
        // CurveTo variant 1 (v operator - current point is first control point)
        CGPDFOperatorTableSetCallback(operatorTable, "v") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleCurveToV(scanner: scanner)
        }
        
        // CurveTo variant 2 (y operator - final point is second control point)
        CGPDFOperatorTableSetCallback(operatorTable, "y") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleCurveToY(scanner: scanner)
        }
        
        // ClosePath operator
        CGPDFOperatorTableSetCallback(operatorTable, "h") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleClosePath()
        }
        
        // Rectangle operator
        CGPDFOperatorTableSetCallback(operatorTable, "re") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleRectangle(scanner: scanner)
        }
        
        // Fill color operators
        CGPDFOperatorTableSetCallback(operatorTable, "rg") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleRGBFillColor(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "RG") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleRGBStrokeColor(scanner: scanner)
        }
        
        // Gray color operators
        CGPDFOperatorTableSetCallback(operatorTable, "g") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleGrayFillColor(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "G") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleGrayStrokeColor(scanner: scanner)
        }
        
        // Fill and stroke operators
        CGPDFOperatorTableSetCallback(operatorTable, "f") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleFill()
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "F") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleFill()
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "S") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleStroke()
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "B") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleFillAndStroke()
        }
        
        // More fill/stroke variants
        CGPDFOperatorTableSetCallback(operatorTable, "f*") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleFill()
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "B*") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleFillAndStroke()
        }
        
        // CMYK color operators
        CGPDFOperatorTableSetCallback(operatorTable, "k") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleCMYKFillColor(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "K") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleCMYKStrokeColor(scanner: scanner)
        }
        
        // More color space operators
        CGPDFOperatorTableSetCallback(operatorTable, "cs") { (scanner, info) in
            print("PDF: Color space operator 'cs' (non-stroking)")
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "CS") { (scanner, info) in
            print("PDF: Color space operator 'CS' (stroking)")
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "sc") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleGenericFillColor(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "SC") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleGenericStrokeColor(scanner: scanner)
        }
        
        // Debug callback for unknown operators
        CGPDFOperatorTableSetCallback(operatorTable, "n") { (scanner, info) in
            print("PDF: Path construction (no-op) operator 'n' encountered")
        }
        
        // Add debug callbacks for common PDF 1.4+ operators we might be missing
        CGPDFOperatorTableSetCallback(operatorTable, "q") { (scanner, info) in
            print("PDF: 'q' (save graphics state) operator encountered")
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "Q") { (scanner, info) in
            print("PDF: 'Q' (restore graphics state) operator encountered")
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "Do") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleXObjectWithOpacitySaving(scanner: scanner)
        }
        
        // Add opacity/transparency operator callbacks  
        CGPDFOperatorTableSetCallback(operatorTable, "ca") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleFillOpacity(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "CA") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleStrokeOpacity(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "gs") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleGraphicsState(scanner: scanner)
        }
        
        // Add debugging for potential opacity/transparency operators
        CGPDFOperatorTableSetCallback(operatorTable, "A") { (scanner, info) in
            print("PDF: 'A' operator (potential transparency) encountered")
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "a") { (scanner, info) in
            print("PDF: 'a' operator (potential transparency) encountered")
        }
        
        // Add callbacks for blend mode operators
        CGPDFOperatorTableSetCallback(operatorTable, "BM") { (scanner, info) in
            print("PDF: 'BM' blend mode operator encountered")
        }
        
        // Add callback for soft mask
        CGPDFOperatorTableSetCallback(operatorTable, "SMask") { (scanner, info) in
            print("PDF: 'SMask' soft mask operator encountered")
        }
        
        // Add callback for transparency group
        CGPDFOperatorTableSetCallback(operatorTable, "BDC") { (scanner, info) in
            print("PDF: 'BDC' marked content operator encountered (might be transparency group)")
        }
        
        // Add gradient operator callbacks
        setupGradientOperatorCallbacks(operatorTable)
    }
    
    // MARK: - Utility Methods
    
    func calculateArtworkBounds() -> CGRect {
        // Delegate to the dedicated geometry module
        return PDFBoundsCalculator.calculateArtworkBounds(from: shapes, pageSize: pageSize)
    }
    
    // MARK: - Operator Handlers (Moved to PDFOperatorHandlers.swift)
    
    // MARK: - Quadratic Curve Detection (Moved to PDFCurveOptimizer module)
    
    // MARK: - Color Handlers (Moved to PDFColorHandlers.swift)
    
    // MARK: - Opacity/Transparency Handlers (Moved to PDFTransparencyHandlers.swift)
    
    // MARK: - Fill and Stroke Handlers
    
    func handleFill() {
        print("PDF: Fill operation - creating filled shape")
        
        if isInCompoundPath && !compoundPathParts.isEmpty {
            print("PDF: 🔍 COMPOUND PATH FILL - Creating compound shape from \(compoundPathParts.count + 1) parts")
            createCompoundShapeFromParts(filled: true, stroked: false)
        } else {
            createShapeFromCurrentPath(filled: true, stroked: false)
        }
    }
    
    func handleStroke() {
        createShapeFromCurrentPath(filled: false, stroked: true)
    }
    
    func createCompoundShapeFromParts(filled: Bool, stroked: Bool) {
        // Add the current path as the final part
        var allParts = compoundPathParts
        if !currentPath.isEmpty {
            allParts.append(currentPath)
        }
        
        print("PDF: 🔧 Creating compound shape with \(allParts.count) subpaths")
        
        // Convert all parts to VectorPath elements
        var combinedElements: [PathElement] = []
        
        for (partIndex, part) in allParts.enumerated() {
            print("PDF: Processing compound part #\(partIndex + 1) with \(part.count) commands")
            
            for command in part {
                switch command {
                case .moveTo(let point):
                    let adjustedPoint = CGPoint(x: point.x, y: pageSize.height - point.y)
                    let vectorPoint = VectorPoint(adjustedPoint)
                    combinedElements.append(.move(to: vectorPoint))
                case .lineTo(let point):
                    let adjustedPoint = CGPoint(x: point.x, y: pageSize.height - point.y)
                    let vectorPoint = VectorPoint(adjustedPoint)
                    combinedElements.append(.line(to: vectorPoint))
                case .curveTo(let cp1, let cp2, let point):
                    let adjustedCP1 = CGPoint(x: cp1.x, y: pageSize.height - cp1.y)
                    let adjustedCP2 = CGPoint(x: cp2.x, y: pageSize.height - cp2.y)
                    let adjustedPoint = CGPoint(x: point.x, y: pageSize.height - point.y)
                    let vectorCP1 = VectorPoint(adjustedCP1)
                    let vectorCP2 = VectorPoint(adjustedCP2)
                    let vectorPoint = VectorPoint(adjustedPoint)
                    combinedElements.append(.curve(to: vectorPoint, control1: vectorCP1, control2: vectorCP2))
                case .quadCurveTo(let cp, let point):
                    let adjustedCP = CGPoint(x: cp.x, y: pageSize.height - cp.y)
                    let adjustedPoint = CGPoint(x: point.x, y: pageSize.height - point.y)
                    let vectorCP = VectorPoint(adjustedCP)
                    let vectorPoint = VectorPoint(adjustedPoint)
                    combinedElements.append(.quadCurve(to: vectorPoint, control: vectorCP))
                case .rectangle(let rect):
                    // Convert rectangle to path elements
                    let adjustedRect = CGRect(x: rect.origin.x, y: pageSize.height - rect.origin.y - rect.height, width: rect.width, height: rect.height)
                    combinedElements.append(.move(to: VectorPoint(Double(adjustedRect.minX), Double(adjustedRect.minY))))
                    combinedElements.append(.line(to: VectorPoint(Double(adjustedRect.maxX), Double(adjustedRect.minY))))
                    combinedElements.append(.line(to: VectorPoint(Double(adjustedRect.maxX), Double(adjustedRect.maxY))))
                    combinedElements.append(.line(to: VectorPoint(Double(adjustedRect.minX), Double(adjustedRect.maxY))))
                    combinedElements.append(.close)
                case .closePath:
                    combinedElements.append(.close)
                }
            }
        }
        
        let vectorPath = VectorPath(elements: combinedElements, isClosed: combinedElements.contains(.close))
        
        // Create fill and stroke styles
        var fillStyle: FillStyle? = nil
        var strokeStyle: StrokeStyle? = nil
        
        if filled {
            let shapeName = "PDF Compound Shape \(shapes.count + 1)"
            print("PDF: 🔍 Compound shape creation - filled=true, activeGradient=\(activeGradient != nil)")
            
            if let gradient = activeGradient {
                fillStyle = FillStyle(gradient: gradient)
                print("PDF: ✅ GRADIENT ASSIGNED TO COMPOUND SHAPE: '\(shapeName)' gets active gradient with \(allParts.count) subpaths")
            } else {
                let r = Double(currentFillColor.components?[0] ?? 0.0)
                let g = Double(currentFillColor.components?[1] ?? 0.0)
                let b = Double(currentFillColor.components?[2] ?? 1.0)
                
                let vectorColor = VectorColor.rgb(RGBColor(red: r, green: g, blue: b, alpha: 1.0))
                fillStyle = FillStyle(color: vectorColor, opacity: currentFillOpacity)
                print("PDF: 🎨 SOLID COLOR ASSIGNED TO COMPOUND SHAPE: '\(shapeName)' gets fill color RGB(\(r), \(g), \(b)) with opacity: \(currentFillOpacity)")
            }
        }
        
        if stroked {
            let r = Double(currentStrokeColor.components?[0] ?? 0.0)
            let g = Double(currentStrokeColor.components?[1] ?? 0.0)
            let b = Double(currentStrokeColor.components?[2] ?? 1.0)
            
            let vectorColor = VectorColor.rgb(RGBColor(red: r, green: g, blue: b, alpha: 1.0))
            strokeStyle = StrokeStyle(color: vectorColor, width: 1.0, placement: .center, opacity: currentStrokeOpacity)
        }
        
        let compoundShape = VectorShape(
            name: activeGradient != nil ? "PDF Compound Shape (Gradient)" : "PDF Compound Shape \(shapes.count + 1)",
            path: vectorPath,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle
        )
        
        shapes.append(compoundShape)
        
        // Reset compound path state
        compoundPathParts.removeAll()
        currentPath.removeAll()
        isInCompoundPath = false
        moveToCount = 0
        
        // Clear the active gradient since it's been applied
        activeGradient = nil
        
        print("PDF: ✅ Compound shape created with \(allParts.count) subpaths")
    }
    
    func handleFillAndStroke() {
        createShapeFromCurrentPath(filled: true, stroked: true)
    }
    
    func createShapeFromCurrentPath(filled: Bool, stroked: Bool) {
        guard !currentPath.isEmpty else { 
            print("PDF: Cannot create shape - current path is empty")
            return 
        }
        
        print("PDF: Creating shape with \(currentPath.count) path commands, filled: \(filled), stroked: \(stroked)")
        
        // Convert to VectorPath elements with coordinate system fix
        var vectorElements: [PathElement] = []
        
        for command in currentPath {
            switch command {
            case .moveTo(let point):
                // Transform coordinates: flip Y coordinate system
                let transformedPoint = VectorPoint(Double(point.x), Double(pageSize.height - point.y))
                vectorElements.append(.move(to: transformedPoint))
                
            case .lineTo(let point):
                let transformedPoint = VectorPoint(Double(point.x), Double(pageSize.height - point.y))
                vectorElements.append(.line(to: transformedPoint))
                
            case .curveTo(let cp1, let cp2, let to):
                let transformedCP1 = VectorPoint(Double(cp1.x), Double(pageSize.height - cp1.y))
                let transformedCP2 = VectorPoint(Double(cp2.x), Double(pageSize.height - cp2.y))
                let transformedTo = VectorPoint(Double(to.x), Double(pageSize.height - to.y))
                vectorElements.append(.curve(to: transformedTo, control1: transformedCP1, control2: transformedCP2))
                
            case .quadCurveTo(let cp, let to):
                let transformedCP = VectorPoint(Double(cp.x), Double(pageSize.height - cp.y))
                let transformedTo = VectorPoint(Double(to.x), Double(pageSize.height - to.y))
                vectorElements.append(.quadCurve(to: transformedTo, control: transformedCP))
                
            case .closePath:
                vectorElements.append(.close)
                
            case .rectangle:
                // Rectangle case should not occur here as it's converted to moves/lines
                break
            }
        }
        
        let vectorPath = VectorPath(elements: vectorElements, isClosed: currentPath.contains(.closePath))
        
        // Create fill and stroke styles based on operation
        var fillStyle: FillStyle? = nil
        var strokeStyle: StrokeStyle? = nil
        
        if filled {
            let shapeName = "PDF Shape \(shapes.count + 1)"
            print("PDF: 🔍 OLD Shape creation - filled=true, activeGradient=\(activeGradient != nil), currentFillGradient=\(currentFillGradient != nil)")
            print("PDF: 🎨 OPACITY DEBUG - currentFillOpacity=\(currentFillOpacity), currentStrokeOpacity=\(currentStrokeOpacity)")
            // Check if this is a white shape first
            let r = Double(currentFillColor.components?[0] ?? 0.0)
            let g = Double(currentFillColor.components?[1] ?? 0.0) 
            let b = Double(currentFillColor.components?[2] ?? 1.0)
            let isWhiteShape = (r > 0.95 && g > 0.95 && b > 0.95) // Nearly white
            
            // IMPROVED GRADIENT LOGIC: Handle both compound paths and direct shape gradients
            if let gradient = activeGradient {
                // Check if this should be a compound path or direct gradient application
                if isWhiteShape && (isInCompoundPath || !compoundPathParts.isEmpty || gradientShapes.count > 0) {
                    // White shape + compound path context = track for compound path
                    gradientShapes.append(shapes.count) // Will be the index after we add this shape
                    fillStyle = FillStyle(gradient: gradient)
                    print("PDF: ✅ COMPOUND GRADIENT: '\(shapeName)' (WHITE) tracked for compound path")
                } else {
                    // Direct gradient application - regardless of color
                    fillStyle = FillStyle(gradient: gradient)
                    print("PDF: ✅ DIRECT GRADIENT: '\(shapeName)' gets gradient directly (not compound)")
                    // Note: Don't clear activeGradient here - will be cleared after shape creation
                }
            } else if let gradient = currentFillGradient {
                fillStyle = FillStyle(gradient: gradient)
                print("PDF: ✅ PATTERN GRADIENT: '\(shapeName)' gets pattern gradient fill")
            } else {
                print("PDF: 🎨 SOLID COLOR: '\(shapeName)' gets fill color RGB(\(r), \(g), \(b)) with separate opacity: \(currentFillOpacity)")
                let vectorColor = VectorColor.rgb(RGBColor(red: r, green: g, blue: b, alpha: 1.0))
                fillStyle = FillStyle(color: vectorColor, opacity: currentFillOpacity)
            }
        }
        
        if stroked {
            let r = Double(currentStrokeColor.components?[0] ?? 0.0)
            let g = Double(currentStrokeColor.components?[1] ?? 0.0)
            let b = Double(currentStrokeColor.components?[2] ?? 0.0)
            print("PDF: Applying stroke color RGB(\(r), \(g), \(b)) with separate opacity: \(currentStrokeOpacity)")
            
            let vectorColor = VectorColor.rgb(RGBColor(red: r, green: g, blue: b, alpha: 1.0))
            strokeStyle = StrokeStyle(color: vectorColor, width: 1.0, placement: .center, opacity: currentStrokeOpacity)
        }
        
        // If no explicit fill or stroke, skip creating the shape - it's likely a construction path
        if fillStyle == nil && strokeStyle == nil {
            print("PDF: No fill or stroke specified - skipping invisible construction path")
            currentPath.removeAll()
            return
        }
        
        let shape = VectorShape(
            name: "PDF Shape \(shapes.count + 1)",
            path: vectorPath,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle
        )
        
        shapes.append(shape)
        
        // Clear activeGradient if it was used for direct application (not compound)
        if activeGradient != nil && gradientShapes.isEmpty {
            activeGradient = nil
            print("PDF: 🔄 Cleared activeGradient after direct application")
        }
        
        currentPath.removeAll()
    }
}

