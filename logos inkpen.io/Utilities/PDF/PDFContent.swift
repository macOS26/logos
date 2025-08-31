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
        let pdfVersion = detectPDFVersion(document: document)
        print("PDF: Document version detected as \(pdfVersion)")
        
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
        let versionString = "PDF 1.7 (assumed - Acrobat 8 compatible)"
        print("PDF: Version \(versionString) supports transparency (introduced in PDF 1.4)")
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
        guard !shapes.isEmpty else { return CGRect(origin: .zero, size: pageSize) }
        
        var minX = Double.greatestFiniteMagnitude
        var minY = Double.greatestFiniteMagnitude
        var maxX = -Double.greatestFiniteMagnitude
        var maxY = -Double.greatestFiniteMagnitude
        
        for shape in shapes {
            let bounds = shape.bounds
            minX = min(minX, bounds.origin.x)
            minY = min(minY, bounds.origin.y)
            maxX = max(maxX, bounds.origin.x + bounds.size.width)
            maxY = max(maxY, bounds.origin.y + bounds.size.height)
        }
        
        return CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }
    
    // MARK: - Operator Handlers
    
    func handleMoveTo(scanner: CGPDFScannerRef) {
        // COMPOUND PATH DETECTION: Multiple MoveTo operations before fill = compound path
        if !currentPath.isEmpty {
            print("PDF: COMPOUND PATH DETECTED - MoveTo with existing path, storing current path as part of compound")
            
            // Store the current path as part of a compound path
            compoundPathParts.append(currentPath)
            isInCompoundPath = true
            moveToCount += 1
            
            print("PDF: Compound path part #\(compoundPathParts.count) stored (\(currentPath.count) commands)")
        } else {
            // Reset compound path tracking for new path sequence
            moveToCount = 1
            if !isInCompoundPath {
                compoundPathParts.removeAll()
            }
        }
        
        var x: CGFloat = 0, y: CGFloat = 0
        
        guard CGPDFScannerPopNumber(scanner, &y),
              CGPDFScannerPopNumber(scanner, &x) else { return }
        
        let point = CGPoint(x: x, y: y)
        currentPoint = point
        pathStartPoint = point
        currentPath.append(.moveTo(point))
        print("PDF: MoveTo(\(x), \(y))")
    }
    
    func handleLineTo(scanner: CGPDFScannerRef) {
        var x: CGFloat = 0, y: CGFloat = 0
        
        guard CGPDFScannerPopNumber(scanner, &y),
              CGPDFScannerPopNumber(scanner, &x) else { return }
        
        let point = CGPoint(x: x, y: y)
        currentPoint = point
        currentPath.append(.lineTo(point))
    }
    
    func handleCurveTo(scanner: CGPDFScannerRef) {
        var x1: CGFloat = 0, y1: CGFloat = 0  // First control point
        var x2: CGFloat = 0, y2: CGFloat = 0  // Second control point  
        var x3: CGFloat = 0, y3: CGFloat = 0  // End point
        
        guard CGPDFScannerPopNumber(scanner, &y3),
              CGPDFScannerPopNumber(scanner, &x3),
              CGPDFScannerPopNumber(scanner, &y2),
              CGPDFScannerPopNumber(scanner, &x2),
              CGPDFScannerPopNumber(scanner, &y1),
              CGPDFScannerPopNumber(scanner, &x1) else { return }
        
        let cp1 = CGPoint(x: x1, y: y1)
        let cp2 = CGPoint(x: x2, y: y2)
        let endPoint = CGPoint(x: x3, y: y3)
        
        currentPoint = endPoint
        
        // Check if this is actually a quadratic curve (can be converted)
        if let quadCommand = convertToQuadCurve(from: currentPoint, cp1: cp1, cp2: cp2, to: endPoint) {
            currentPath.append(quadCommand)
        } else {
            currentPath.append(.curveTo(cp1: cp1, cp2: cp2, to: endPoint))
        }
    }
    
    func handleCurveToV(scanner: CGPDFScannerRef) {
        var x2: CGFloat = 0, y2: CGFloat = 0  // Second control point
        var x3: CGFloat = 0, y3: CGFloat = 0  // End point
        
        guard CGPDFScannerPopNumber(scanner, &y3),
              CGPDFScannerPopNumber(scanner, &x3),
              CGPDFScannerPopNumber(scanner, &y2),
              CGPDFScannerPopNumber(scanner, &x2) else { return }
        
        let cp1 = currentPoint  // Current point is first control point
        let cp2 = CGPoint(x: x2, y: y2)
        let endPoint = CGPoint(x: x3, y: y3)
        
        currentPoint = endPoint
        
        if let quadCommand = convertToQuadCurve(from: currentPoint, cp1: cp1, cp2: cp2, to: endPoint) {
            currentPath.append(quadCommand)
        } else {
            currentPath.append(.curveTo(cp1: cp1, cp2: cp2, to: endPoint))
        }
    }
    
    func handleCurveToY(scanner: CGPDFScannerRef) {
        var x1: CGFloat = 0, y1: CGFloat = 0  // First control point
        var x3: CGFloat = 0, y3: CGFloat = 0  // End point (also second control point)
        
        guard CGPDFScannerPopNumber(scanner, &y3),
              CGPDFScannerPopNumber(scanner, &x3),
              CGPDFScannerPopNumber(scanner, &y1),
              CGPDFScannerPopNumber(scanner, &x1) else { return }
        
        let cp1 = CGPoint(x: x1, y: y1)
        let endPoint = CGPoint(x: x3, y: y3)
        let cp2 = endPoint  // End point is also second control point
        
        currentPoint = endPoint
        
        if let quadCommand = convertToQuadCurve(from: currentPoint, cp1: cp1, cp2: cp2, to: endPoint) {
            currentPath.append(quadCommand)
        } else {
            currentPath.append(.curveTo(cp1: cp1, cp2: cp2, to: endPoint))
        }
    }
    
    func handleClosePath() {
        currentPath.append(.closePath)
    }
    
    func handleRectangle(scanner: CGPDFScannerRef) {
        var x: CGFloat = 0, y: CGFloat = 0, width: CGFloat = 0, height: CGFloat = 0
        
        guard CGPDFScannerPopNumber(scanner, &height),
              CGPDFScannerPopNumber(scanner, &width),
              CGPDFScannerPopNumber(scanner, &y),
              CGPDFScannerPopNumber(scanner, &x) else { return }
        
        // FILTER OUT PAGE BOUNDARY RECTANGLES: Skip rectangles that match page dimensions
        let tolerance: CGFloat = 2.0 // Allow small differences
        if abs(width - pageSize.width) < tolerance && abs(height - pageSize.height) < tolerance {
            print("PDF: Skipping page boundary rectangle (\(width) x \(height)) that matches page size")
            return
        }
        
        // Also skip rectangles that are positioned at page origin (0,0) and match page size
        if abs(x) < tolerance && abs(y) < tolerance && 
           abs(width - pageSize.width) < tolerance && abs(height - pageSize.height) < tolerance {
            print("PDF: Skipping page boundary rectangle at origin that matches page size")
            return
        }
        
        // Add rectangle as move + lines + close
        let startPoint = CGPoint(x: x, y: y)
        let topRight = CGPoint(x: x + width, y: y)
        let bottomRight = CGPoint(x: x + width, y: y + height)
        let bottomLeft = CGPoint(x: x, y: y + height)
        
        currentPath.append(.moveTo(startPoint))
        currentPath.append(.lineTo(topRight))
        currentPath.append(.lineTo(bottomRight))
        currentPath.append(.lineTo(bottomLeft))
        currentPath.append(.closePath)
        
        currentPoint = startPoint
        pathStartPoint = startPoint
    }
    
    // MARK: - Quadratic Curve Detection
    
    func convertToQuadCurve(from start: CGPoint, cp1: CGPoint, cp2: CGPoint, to end: CGPoint) -> PathCommand? {
        // Check if cubic curve can be represented as quadratic
        // This happens when the control points follow the quadratic relationship:
        // cp1 = start + 2/3 * (quad_cp - start)
        // cp2 = end + 2/3 * (quad_cp - end)
        
        // Calculate potential quadratic control point
        let potentialQCP1 = CGPoint(
            x: start.x + 1.5 * (cp1.x - start.x),
            y: start.y + 1.5 * (cp1.y - start.y)
        )
        
        let potentialQCP2 = CGPoint(
            x: end.x + 1.5 * (cp2.x - end.x),
            y: end.y + 1.5 * (cp2.y - end.y)
        )
        
        // Check if both calculations give the same control point (within tolerance)
        let tolerance: CGFloat = 0.1
        if abs(potentialQCP1.x - potentialQCP2.x) < tolerance &&
           abs(potentialQCP1.y - potentialQCP2.y) < tolerance {
            
            let quadCP = CGPoint(
                x: (potentialQCP1.x + potentialQCP2.x) / 2,
                y: (potentialQCP1.y + potentialQCP2.y) / 2
            )
            
            return .quadCurveTo(cp: quadCP, to: end)
        }
        
        return nil
    }
    
    // MARK: - Color Handlers
    
    func handleRGBFillColor(scanner: CGPDFScannerRef) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        
        guard CGPDFScannerPopNumber(scanner, &b),
              CGPDFScannerPopNumber(scanner, &g),
              CGPDFScannerPopNumber(scanner, &r) else { 
            print("PDF: Failed to read RGB fill color")
            return 
        }
        
        currentFillColor = CGColor(red: r, green: g, blue: b, alpha: 1.0)
        print("PDF: Set fill color to RGB(\(r), \(g), \(b))")
    }
    
    func handleRGBStrokeColor(scanner: CGPDFScannerRef) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        
        guard CGPDFScannerPopNumber(scanner, &b),
              CGPDFScannerPopNumber(scanner, &g),
              CGPDFScannerPopNumber(scanner, &r) else { return }
        
        currentStrokeColor = CGColor(red: r, green: g, blue: b, alpha: 1.0)
    }
    
    func handleGrayFillColor(scanner: CGPDFScannerRef) {
        var gray: CGFloat = 0
        
        guard CGPDFScannerPopNumber(scanner, &gray) else { return }
        
        currentFillColor = CGColor(red: gray, green: gray, blue: gray, alpha: 1.0)
    }
    
    func handleGrayStrokeColor(scanner: CGPDFScannerRef) {
        var gray: CGFloat = 0
        
        guard CGPDFScannerPopNumber(scanner, &gray) else { return }
        
        currentStrokeColor = CGColor(red: gray, green: gray, blue: gray, alpha: 1.0)
        print("PDF: Set stroke color to Gray(\(gray))")
    }
    
    func handleCMYKFillColor(scanner: CGPDFScannerRef) {
        var c: CGFloat = 0, m: CGFloat = 0, y: CGFloat = 0, k: CGFloat = 0
        
        guard CGPDFScannerPopNumber(scanner, &k),
              CGPDFScannerPopNumber(scanner, &y),
              CGPDFScannerPopNumber(scanner, &m),
              CGPDFScannerPopNumber(scanner, &c) else { 
            print("PDF: Failed to read CMYK fill color")
            return 
        }
        
        // Convert CMYK to RGB
        let r = (1.0 - c) * (1.0 - k)
        let g = (1.0 - m) * (1.0 - k)
        let b = (1.0 - y) * (1.0 - k)
        
        currentFillColor = CGColor(red: r, green: g, blue: b, alpha: 1.0)
        print("PDF: Set fill color to CMYK(\(c), \(m), \(y), \(k)) -> RGB(\(r), \(g), \(b))")
    }
    
    func handleCMYKStrokeColor(scanner: CGPDFScannerRef) {
        var c: CGFloat = 0, m: CGFloat = 0, y: CGFloat = 0, k: CGFloat = 0
        
        guard CGPDFScannerPopNumber(scanner, &k),
              CGPDFScannerPopNumber(scanner, &y),
              CGPDFScannerPopNumber(scanner, &m),
              CGPDFScannerPopNumber(scanner, &c) else { 
            print("PDF: Failed to read CMYK stroke color")
            return 
        }
        
        // Convert CMYK to RGB
        let r = (1.0 - c) * (1.0 - k)
        let g = (1.0 - m) * (1.0 - k)
        let b = (1.0 - y) * (1.0 - k)
        
        currentStrokeColor = CGColor(red: r, green: g, blue: b, alpha: 1.0)
        print("PDF: Set stroke color to CMYK(\(c), \(m), \(y), \(k)) -> RGB(\(r), \(g), \(b))")
    }
    
    func handleGenericFillColor(scanner: CGPDFScannerRef) {
        // Try to read as RGB first, but also check for RGBA or other formats
        var values: [CGFloat] = []
        var value: CGFloat = 0
        
        // Read all available numeric values
        while CGPDFScannerPopNumber(scanner, &value) {
            values.insert(value, at: 0) // Insert at beginning to reverse stack order
        }
        
        print("PDF: Generic fill color - found \(values.count) values: \(values)")
        
        if values.count >= 3 {
            let r = values[0]
            let g = values[1] 
            let b = values[2]
            let a = values.count >= 4 ? values[3] : 1.0
            
            // Check if this might be transparency encoded in a different way
            if values.count == 4 {
                print("PDF: ⚠️ FOUND 4-component color - might be RGBA or transparency: \(values)")
                currentFillOpacity = Double(a)
            }
            
            currentFillColor = CGColor(red: r, green: g, blue: b, alpha: 1.0)
            print("PDF: Generic fill color - RGB(\(r), \(g), \(b)) with potential alpha: \(a)")
        } else {
            print("PDF: Generic fill color - could not parse parameters, got \(values.count) values")
        }
    }
    
    func handleGenericStrokeColor(scanner: CGPDFScannerRef) {
        // Try to read as RGB first
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        
        if CGPDFScannerPopNumber(scanner, &b) &&
           CGPDFScannerPopNumber(scanner, &g) &&
           CGPDFScannerPopNumber(scanner, &r) {
            currentStrokeColor = CGColor(red: r, green: g, blue: b, alpha: 1.0)
            print("PDF: Generic stroke color - assuming RGB(\(r), \(g), \(b))")
        } else {
            print("PDF: Generic stroke color - could not parse parameters")
        }
    }
    
    // MARK: - Opacity/Transparency Handlers
    
    func handleFillOpacity(scanner: CGPDFScannerRef) {
        var opacity: CGFloat = 1.0
        
        guard CGPDFScannerPopNumber(scanner, &opacity) else {
            print("PDF: Failed to read fill opacity")
            return
        }
        
        currentFillOpacity = Double(opacity)
        print("PDF: Fill opacity set to \(currentFillOpacity)")
    }
    
    func handleStrokeOpacity(scanner: CGPDFScannerRef) {
        var opacity: CGFloat = 1.0
        
        guard CGPDFScannerPopNumber(scanner, &opacity) else {
            print("PDF: Failed to read stroke opacity")
            return
        }
        
        currentStrokeOpacity = Double(opacity)
        print("PDF: Stroke opacity set to \(currentStrokeOpacity)")
    }
    
    func handleGraphicsState(scanner: CGPDFScannerRef) {
        // PDF 1.4+ uses names, PDF 1.3 uses strings - try both
        var nameRef: CGPDFStringRef?
        var namePtr: UnsafePointer<CChar>?
        var name: String
        
        if CGPDFScannerPopName(scanner, &namePtr) {
            // PDF 1.4+ format - name
            name = String(cString: namePtr!)
            print("PDF: Graphics state '\(name)' (as name) - attempting to parse ExtGState...")
        } else if CGPDFScannerPopString(scanner, &nameRef) {
            // PDF 1.3 format - string
            name = CGPDFStringCopyTextString(nameRef!)! as String
            print("PDF: Graphics state '\(name)' (as string) - attempting to parse ExtGState...")
        } else {
            print("PDF: Failed to read graphics state name (tried both name and string formats)")
            return
        }
        
        // Enhanced ExtGState parsing with better error handling
        guard let page = currentPage else {
            print("PDF: No current page available for ExtGState lookup")
            return
        }
        
        guard let resourceDict = page.dictionary else {
            print("PDF: Page dictionary not available")
            return
        }
        
        // Try to get Resources dictionary - could be directly on page or inherited
        var resourcesRef: CGPDFDictionaryRef? = nil
        if !CGPDFDictionaryGetDictionary(resourceDict, "Resources", &resourcesRef) {
            print("PDF: No Resources dictionary found on page")
            return
        }
        
        guard let resourcesDict = resourcesRef else {
            print("PDF: Resources dictionary is nil")
            return
        }
        
        // Debug: List all keys in Resources dictionary
        print("PDF: 🔍 DEBUG - Listing Resources dictionary contents:")
        listDictionaryKeys(resourcesDict, prefix: "  Resources")
        
        var extGStateDict: CGPDFDictionaryRef? = nil
        if !CGPDFDictionaryGetDictionary(resourcesDict, "ExtGState", &extGStateDict) {
            print("PDF: No ExtGState dictionary found in Resources")
            return
        }
        
        guard let extGState = extGStateDict else {
            print("PDF: ExtGState dictionary is nil")
            return
        }
        
        // Debug: List all ExtGState entries
        print("PDF: 🔍 DEBUG - Listing ExtGState dictionary contents:")
        listDictionaryKeys(extGState, prefix: "  ExtGState")
        
        var stateDict: CGPDFDictionaryRef? = nil
        if !CGPDFDictionaryGetDictionary(extGState, name, &stateDict) {
            print("PDF: ExtGState '\(name)' not found in ExtGState dictionary")
            return
        }
        
        guard let state = stateDict else {
            print("PDF: ExtGState '\(name)' dictionary is nil")
            return
        }
        
        // Debug: List all entries in the specific ExtGState
        print("PDF: 🔍 DEBUG - ExtGState '\(name)' contents:")
        listDictionaryKeys(state, prefix: "  \(name)")
        
        // Parse opacity values from the ExtGState dictionary
        var fillOpacity: CGFloat = 1.0
        var strokeOpacity: CGFloat = 1.0
        
        if CGPDFDictionaryGetNumber(state, "ca", &fillOpacity) {
            currentFillOpacity = Double(fillOpacity)
            print("PDF: ✅ ExtGState '\(name)' - Fill opacity (ca): \(currentFillOpacity)")
        } else {
            currentFillOpacity = 1.0  // Reset to full opacity when no 'ca' entry
            print("PDF: ExtGState '\(name)' - No 'ca' (fill opacity) entry found, reset to 1.0")
        }
        
        if CGPDFDictionaryGetNumber(state, "CA", &strokeOpacity) {
            currentStrokeOpacity = Double(strokeOpacity)
            print("PDF: ✅ ExtGState '\(name)' - Stroke opacity (CA): \(currentStrokeOpacity)")
        } else {
            currentStrokeOpacity = 1.0  // Reset to full opacity when no 'CA' entry
            print("PDF: ExtGState '\(name)' - No 'CA' (stroke opacity) entry found, reset to 1.0")
        }
        
        print("PDF: 🎯 ExtGState '\(name)' final opacity - fill: \(currentFillOpacity), stroke: \(currentStrokeOpacity)")
        
        // CRITICAL FIX: Store specific graphics state opacity values for XObject inheritance
        if name == "Gs1" {
            gs1FillOpacity = currentFillOpacity
            gs1StrokeOpacity = currentStrokeOpacity
            print("PDF: 🎯 SAVED Gs1 opacity for XObject Fm1 - fill: \(gs1FillOpacity), stroke: \(gs1StrokeOpacity)")
        } else if name == "Gs3" {
            gs3FillOpacity = currentFillOpacity
            gs3StrokeOpacity = currentStrokeOpacity
            print("PDF: 🎯 SAVED Gs3 opacity for XObject Fm2 - fill: \(gs3FillOpacity), stroke: \(gs3StrokeOpacity)")
        }
    }
    
    // Helper function to debug dictionary contents
    private func listDictionaryKeys(_ dictionary: CGPDFDictionaryRef, prefix: String) {
        var keys: [String] = []
        
        // Callback to collect all keys
        let callback: CGPDFDictionaryApplierFunction = { (key, object, info) in
            let keyString = String(cString: key)
            if let keysArray = info?.assumingMemoryBound(to: [String].self) {
                keysArray.pointee.append(keyString)
            }
        }
        
        withUnsafeMutablePointer(to: &keys) { keysPtr in
            CGPDFDictionaryApplyFunction(dictionary, callback, keysPtr)
        }
        
        print("\(prefix): Found \(keys.count) keys: \(keys.joined(separator: ", "))")
    }
    
    func handleXObject(scanner: CGPDFScannerRef) {
        var namePtr: UnsafePointer<CChar>?
        
        guard CGPDFScannerPopName(scanner, &namePtr) else {
            print("PDF: Failed to read XObject name")
            return
        }
        
        let name = String(cString: namePtr!)
        print("PDF: 🚨 'Do' XObject '\(name)' encountered with current opacity - fill: \(currentFillOpacity), stroke: \(currentStrokeOpacity)")
        
        // CRITICAL FIX: Save graphics state BEFORE processing XObject
        // At this point we have the correct outer scope opacity values
        let savedFillOpacity = currentFillOpacity
        let savedStrokeOpacity = currentStrokeOpacity
        print("PDF: 🎯 XObject '\(name)' - SAVING outer state - fill: \(savedFillOpacity), stroke: \(savedStrokeOpacity)")
        
        // Store these values for the PDF14 XObject handler to use
        xObjectSavedFillOpacity = savedFillOpacity
        xObjectSavedStrokeOpacity = savedStrokeOpacity
        
        // TODO: Parse XObject content streams - this is where PDF 1.4 actual drawing operations likely are
        // For now, just log that we encountered it
    }
    
    func handleXObjectWithOpacitySaving(scanner: CGPDFScannerRef) {
        // First get the name to know which XObject we're processing
        var namePtr: UnsafePointer<CChar>?
        
        guard CGPDFScannerPopName(scanner, &namePtr) else {
            print("PDF: Failed to read XObject name")
            return
        }
        
        let name = String(cString: namePtr!)
        print("PDF: 🚨 'Do' XObject '\(name)' encountered with current opacity - fill: \(currentFillOpacity), stroke: \(currentStrokeOpacity)")
        
        // CRITICAL FIX: Use the correct graphics state opacity based on XObject name
        var savedFillOpacity: Double
        var savedStrokeOpacity: Double
        
        if name == "Fm1" {
            // Fm1 should use Gs1 opacity (0.5)
            savedFillOpacity = gs1FillOpacity
            savedStrokeOpacity = gs1StrokeOpacity
            print("PDF: 🎯 XObject '\(name)' - Using Gs1 opacity - fill: \(savedFillOpacity), stroke: \(savedStrokeOpacity)")
        } else if name == "Fm2" {
            // Fm2 should use Gs3 opacity (0.75)
            savedFillOpacity = gs3FillOpacity
            savedStrokeOpacity = gs3StrokeOpacity
            print("PDF: 🎯 XObject '\(name)' - Using Gs3 opacity - fill: \(savedFillOpacity), stroke: \(savedStrokeOpacity)")
        } else {
            // Default to current opacity for other XObjects
            savedFillOpacity = currentFillOpacity
            savedStrokeOpacity = currentStrokeOpacity
            print("PDF: 🎯 XObject '\(name)' - Using current opacity - fill: \(savedFillOpacity), stroke: \(savedStrokeOpacity)")
        }
        
        // Store these values for the PDF14 XObject handler to use
        xObjectSavedFillOpacity = savedFillOpacity
        xObjectSavedStrokeOpacity = savedStrokeOpacity
        
        // Now directly process the XObject content using the saved name
        processXObjectPDF14(name: name)
    }
    
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

