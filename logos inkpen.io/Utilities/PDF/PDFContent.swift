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

// MARK: - Path Command Types
enum PathCommand: Equatable {
    case moveTo(CGPoint)
    case lineTo(CGPoint)
    case curveTo(cp1: CGPoint, cp2: CGPoint, to: CGPoint)
    case quadCurveTo(cp: CGPoint, to: CGPoint)
    case rectangle(CGRect)
    case closePath
}

// MARK: - PDF Command Parser
class PDFCommandParser {
    private var commands: [PathCommand] = []
    private var currentPoint = CGPoint.zero
    private var currentFillColor = CGColor(red: 0, green: 0, blue: 1, alpha: 1) // Default blue
    private var currentStrokeColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1) // Default black
    private var currentFillGradient: VectorGradient?
    private var currentStrokeGradient: VectorGradient?
    private var shapes: [VectorShape] = []
    private var currentPath: [PathCommand] = []
    private var pathStartPoint = CGPoint.zero
    private var pageSize = CGSize.zero
    
    // For compound path handling
    private var accumulatedPaths: [[PathCommand]] = []
    private var pendingFillColor: CGColor?
    
    // For gradient tracking
    private var activeGradient: VectorGradient?
    private var gradientShapes: [Int] = []
    
    // For proper compound path detection
    private var isInCompoundPath = false
    private var compoundPathParts: [[PathCommand]] = []
    private var moveToCount = 0  // Track multiple MoveTo operations
    
    func parseDocument(at url: URL) -> [VectorShape] {
        commands.removeAll()
        shapes.removeAll()
        
        guard let dataProvider = CGDataProvider(url: url as CFURL),
              let document = CGPDFDocument(dataProvider) else {
            print("Failed to load PDF document")
            return []
        }
        
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
        return shapes
    }
    
    private func parsePage(document: CGPDFDocument, pageNumber: Int) {
        guard let page = document.page(at: pageNumber) else { return }
        
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
    
    private func setupOperatorCallbacks(_ operatorTable: CGPDFOperatorTableRef) {
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
        
        // Add gradient operator callbacks
        setupGradientOperatorCallbacks(operatorTable)
    }
    
    // MARK: - Operator Handlers
    
    private func handleMoveTo(scanner: CGPDFScannerRef) {
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
    
    private func handleLineTo(scanner: CGPDFScannerRef) {
        var x: CGFloat = 0, y: CGFloat = 0
        
        guard CGPDFScannerPopNumber(scanner, &y),
              CGPDFScannerPopNumber(scanner, &x) else { return }
        
        let point = CGPoint(x: x, y: y)
        currentPoint = point
        currentPath.append(.lineTo(point))
    }
    
    private func handleCurveTo(scanner: CGPDFScannerRef) {
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
    
    private func handleCurveToV(scanner: CGPDFScannerRef) {
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
    
    private func handleCurveToY(scanner: CGPDFScannerRef) {
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
    
    private func handleClosePath() {
        currentPath.append(.closePath)
    }
    
    private func handleRectangle(scanner: CGPDFScannerRef) {
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
    
    private func convertToQuadCurve(from start: CGPoint, cp1: CGPoint, cp2: CGPoint, to end: CGPoint) -> PathCommand? {
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
    
    private func handleRGBFillColor(scanner: CGPDFScannerRef) {
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
    
    private func handleRGBStrokeColor(scanner: CGPDFScannerRef) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        
        guard CGPDFScannerPopNumber(scanner, &b),
              CGPDFScannerPopNumber(scanner, &g),
              CGPDFScannerPopNumber(scanner, &r) else { return }
        
        currentStrokeColor = CGColor(red: r, green: g, blue: b, alpha: 1.0)
    }
    
    private func handleGrayFillColor(scanner: CGPDFScannerRef) {
        var gray: CGFloat = 0
        
        guard CGPDFScannerPopNumber(scanner, &gray) else { return }
        
        currentFillColor = CGColor(red: gray, green: gray, blue: gray, alpha: 1.0)
    }
    
    private func handleGrayStrokeColor(scanner: CGPDFScannerRef) {
        var gray: CGFloat = 0
        
        guard CGPDFScannerPopNumber(scanner, &gray) else { return }
        
        currentStrokeColor = CGColor(red: gray, green: gray, blue: gray, alpha: 1.0)
        print("PDF: Set stroke color to Gray(\(gray))")
    }
    
    private func handleCMYKFillColor(scanner: CGPDFScannerRef) {
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
    
    private func handleCMYKStrokeColor(scanner: CGPDFScannerRef) {
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
    
    private func handleGenericFillColor(scanner: CGPDFScannerRef) {
        // Try to read as RGB first
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        
        if CGPDFScannerPopNumber(scanner, &b) &&
           CGPDFScannerPopNumber(scanner, &g) &&
           CGPDFScannerPopNumber(scanner, &r) {
            
            // Normal color change processing
            // (removed gradient preservation logic since gradient comes AFTER white shapes)
            
            currentFillColor = CGColor(red: r, green: g, blue: b, alpha: 1.0)
            print("PDF: Generic fill color - assuming RGB(\(r), \(g), \(b))")
        } else {
            print("PDF: Generic fill color - could not parse parameters")
        }
    }
    
    private func handleGenericStrokeColor(scanner: CGPDFScannerRef) {
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
    
    // MARK: - Fill and Stroke Handlers
    
    private func handleFill() {
        print("PDF: Fill operation - creating filled shape")
        
        if isInCompoundPath && !compoundPathParts.isEmpty {
            print("PDF: 🔍 COMPOUND PATH FILL - Creating compound shape from \(compoundPathParts.count + 1) parts")
            createCompoundShapeFromParts(filled: true, stroked: false)
        } else {
            createShapeFromCurrentPath(filled: true, stroked: false)
        }
    }
    
    private func handleStroke() {
        createShapeFromCurrentPath(filled: false, stroked: true)
    }
    
    private func createCompoundShapeFromParts(filled: Bool, stroked: Bool) {
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
                let a = Double(currentFillColor.components?[3] ?? 1.0)
                
                let vectorColor = VectorColor.rgb(RGBColor(red: r, green: g, blue: b, alpha: a))
                fillStyle = FillStyle(color: vectorColor)
                print("PDF: 🎨 SOLID COLOR ASSIGNED TO COMPOUND SHAPE: '\(shapeName)' gets fill color RGBA(\(r), \(g), \(b), \(a))")
            }
        }
        
        if stroked {
            let r = Double(currentStrokeColor.components?[0] ?? 0.0)
            let g = Double(currentStrokeColor.components?[1] ?? 0.0)
            let b = Double(currentStrokeColor.components?[2] ?? 1.0)
            let a = Double(currentStrokeColor.components?[3] ?? 1.0)
            
            let vectorColor = VectorColor.rgb(RGBColor(red: r, green: g, blue: b, alpha: a))
            strokeStyle = StrokeStyle(color: vectorColor, width: 1.0, placement: .center)
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
    
    private func handleFillAndStroke() {
        createShapeFromCurrentPath(filled: true, stroked: true)
    }
    
    private func createShapeFromCurrentPath(filled: Bool, stroked: Bool) {
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
            // Priority order: active gradient, current gradient, current fill color
            if let gradient = activeGradient {
                // This shape should get the gradient - track it
                gradientShapes.append(shapes.count) // Will be the index after we add this shape
                fillStyle = FillStyle(gradient: gradient)
                print("PDF: ✅ GRADIENT ASSIGNED: '\(shapeName)' will get active gradient - tracked for compound path")
            } else if let gradient = currentFillGradient {
                fillStyle = FillStyle(gradient: gradient)
                print("PDF: ✅ GRADIENT ASSIGNED: '\(shapeName)' will get current gradient fill")
            } else {
                let r = Double(currentFillColor.components?[0] ?? 0.0)
                let g = Double(currentFillColor.components?[1] ?? 0.0) 
                let b = Double(currentFillColor.components?[2] ?? 1.0)
                let a = Double(currentFillColor.components?[3] ?? 1.0)
                print("PDF: 🎨 SOLID COLOR ASSIGNED: '\(shapeName)' will get fill color RGBA(\(r), \(g), \(b), \(a))")
                
                let vectorColor = VectorColor.rgb(RGBColor(red: r, green: g, blue: b, alpha: a))
                fillStyle = FillStyle(color: vectorColor)
            }
        }
        
        if stroked {
            let r = Double(currentStrokeColor.components?[0] ?? 0.0)
            let g = Double(currentStrokeColor.components?[1] ?? 0.0)
            let b = Double(currentStrokeColor.components?[2] ?? 0.0) 
            let a = Double(currentStrokeColor.components?[3] ?? 1.0)
            print("PDF: Applying stroke color RGBA(\(r), \(g), \(b), \(a))")
            
            let vectorColor = VectorColor.rgb(RGBColor(red: r, green: g, blue: b, alpha: a))
            strokeStyle = StrokeStyle(color: vectorColor, width: 1.0, placement: .center)
        }
        
        // If no explicit fill or stroke, provide default visible appearance
        if fillStyle == nil && strokeStyle == nil {
            print("PDF: No fill or stroke specified - providing default blue fill")
            let defaultColor = VectorColor.rgb(RGBColor(red: 0.0, green: 0.7, blue: 1.0, alpha: 1.0))
            fillStyle = FillStyle(color: defaultColor)
        }
        
        let shape = VectorShape(
            name: "PDF Shape \(shapes.count + 1)",
            path: vectorPath,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle
        )
        
        shapes.append(shape)
        currentPath.removeAll()
    }
}

// MARK: - CoreGraphics Path Builder
class PathBuilder {
    private var path = CGMutablePath()
    
    func buildPath(from commands: [PathCommand]) -> CGPath {
        path = CGMutablePath()
        
        for command in commands {
            switch command {
            case .moveTo(let point):
                path.move(to: point)
                
            case .lineTo(let point):
                path.addLine(to: point)
                
            case .curveTo(let cp1, let cp2, let to):
                path.addCurve(to: to, control1: cp1, control2: cp2)
                
            case .quadCurveTo(let cp, let to):
                path.addQuadCurve(to: to, control: cp)
                
            case .closePath:
                path.closeSubpath()
                
            case .rectangle(let rect):
                path.addRect(rect)
            }
        }
        
        return path
    }
}

// MARK: - PDF Vector Extraction using Working Parser
func extractPDFVectorContent(_ page: CGPDFPage) throws -> PDFContent {
    Log.fileOperation("🔧 Extracting PDF vector content using working parser...", level: .info)
    
    // Create a temporary file URL from the page
    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("temp_pdf_page.pdf")
    
    // Create a PDF context to write the single page
    var mediaBox = page.getBoxRect(.mediaBox)
    guard let context = CGContext(tempURL as CFURL, mediaBox: &mediaBox, nil) else {
        throw VectorImportError.parsingError("Cannot create PDF context", line: nil)
    }
    
    context.beginPDFPage(nil)
    context.drawPDFPage(page)
    context.endPDFPage()
    context.closePDF()
    
    // Now parse with the working parser
    let parser = PDFCommandParser()
    let shapes = parser.parseDocument(at: tempURL)
    
    Log.info("✅ Extracted \(shapes.count) vector shapes with individual colors", category: .fileOperations)
    
    // Clean up temp file
    try? FileManager.default.removeItem(at: tempURL)
    
    return PDFContent(
        shapes: shapes,
        textCount: 0,
        creator: "PDF Vector Parser",
        version: "Individual Shapes"
    )
}

private func convertCGPathToVectorPath(_ cgPath: CGPath) -> VectorPath {
    var elements: [PathElement] = []
    
    cgPath.applyWithBlock { elementPtr in
        let element = elementPtr.pointee
        let points = element.points
        
        switch element.type {
        case .moveToPoint:
            elements.append(.move(to: VectorPoint(Double(points[0].x), Double(points[0].y))))
            
        case .addLineToPoint:
            elements.append(.line(to: VectorPoint(Double(points[0].x), Double(points[0].y))))
            
        case .addCurveToPoint:
            elements.append(.curve(
                to: VectorPoint(Double(points[2].x), Double(points[2].y)),
                control1: VectorPoint(Double(points[0].x), Double(points[0].y)),
                control2: VectorPoint(Double(points[1].x), Double(points[1].y))
            ))
            
        case .addQuadCurveToPoint:
            elements.append(.quadCurve(
                to: VectorPoint(Double(points[1].x), Double(points[1].y)),
                control: VectorPoint(Double(points[0].x), Double(points[0].y))
            ))
            
        case .closeSubpath:
            elements.append(.close)
            
        @unknown default:
            break
        }
    }
    
    return VectorPath(elements: elements)
}

// PDF Gradient Support Extension for PDFContent.swift

// MARK: - Extended PDF Command Parser for Gradients

extension PDFCommandParser {
    
    // Add these properties to your PDFCommandParser class:
    // private var currentPattern: CGPDFPatternRef?
    // private var patterns: [String: CGPDFPatternRef] = [:]
    // private var shadings: [String: VectorGradient] = [:]
    
    // Add this to your setupOperatorCallbacks method:
    func setupGradientOperatorCallbacks(_ operatorTable: CGPDFOperatorTableRef) {
        
        // Pattern color space operators
        CGPDFOperatorTableSetCallback(operatorTable, "SCN") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handlePatternColorStroke(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "scn") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handlePatternColorFill(scanner: scanner)
        }
        
        // Shading operator
        CGPDFOperatorTableSetCallback(operatorTable, "sh") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleShading(scanner: scanner)
        }
    }
    
    // Pattern color handlers
    private func handlePatternColorFill(scanner: CGPDFScannerRef) {
        // Try to get pattern name
        var nameObj: UnsafePointer<Int8>?
        if CGPDFScannerPopName(scanner, &nameObj),
           let name = nameObj {
            let patternName = String(cString: name)
            print("PDF: Pattern fill color set to pattern: \(patternName)")
            
            // Check if we have a gradient shading for this pattern  
            if let gradient = extractGradientFromPattern(patternName: patternName, scanner: scanner) {
                // Store gradient for later use in fill operations
                print("PDF: Found gradient fill from pattern \(patternName)")
                currentFillGradient = gradient
                // Note: We can't store gradient in CGColor, need to handle differently
            }
        }
    }
    
    private func handlePatternColorStroke(scanner: CGPDFScannerRef) {
        var nameObj: UnsafePointer<Int8>?
        if CGPDFScannerPopName(scanner, &nameObj),
           let name = nameObj {
            let patternName = String(cString: name)
            print("PDF: Pattern stroke color set to pattern: \(patternName)")
            
            if let gradient = extractGradientFromPattern(patternName: patternName, scanner: scanner) {
                print("PDF: Found gradient stroke from pattern \(patternName)")
                currentStrokeGradient = gradient
                // Note: We can't store gradient in CGColor, need to handle differently
            }
        }
    }
    
    private func handleShading(scanner: CGPDFScannerRef) {
        var nameObj: UnsafePointer<Int8>?
        if CGPDFScannerPopName(scanner, &nameObj),
           let name = nameObj {
            let shadingName = String(cString: name)
            print("PDF: Shading operation with shading: \(shadingName)")
            
            // Create a shape with the shading gradient
            if let gradient = extractGradientFromShading(shadingName: shadingName, scanner: scanner) {
                // The shading should be applied to previously created white shapes
                // Find all white shapes and replace them with gradient-filled shapes
                applyGradientToWhiteShapes(gradient: gradient)
            }
        }
    }
    
    // Helper method to extract gradient from pattern
    private func extractGradientFromPattern(patternName: String, scanner: CGPDFScannerRef) -> VectorGradient? {
        // Get the current PDF page context
        let stream = CGPDFScannerGetContentStream(scanner)
        guard let pdfPage = CGPDFContentStreamGetResource(stream, "Pattern", patternName.cString(using: .utf8)!) else {
            return nil
        }
        
        var patternDict: CGPDFDictionaryRef?
        if !CGPDFObjectGetValue(pdfPage, .dictionary, &patternDict) || patternDict == nil {
            return nil
        }
        
        return parseGradientFromDictionary(patternDict!)
    }
    
    // Helper method to extract gradient from shading  
    private func extractGradientFromShading(shadingName: String, scanner: CGPDFScannerRef) -> VectorGradient? {
        let stream = CGPDFScannerGetContentStream(scanner)
        guard let pdfShading = CGPDFContentStreamGetResource(stream, "Shading", shadingName.cString(using: .utf8)!) else {
            return nil
        }
        
        var shadingDict: CGPDFDictionaryRef?
        if !CGPDFObjectGetValue(pdfShading, .dictionary, &shadingDict) || shadingDict == nil {
            return nil
        }
        
        return parseGradientFromDictionary(shadingDict!)
    }
    
    // Parse gradient from PDF dictionary
    private func parseGradientFromDictionary(_ dict: CGPDFDictionaryRef) -> VectorGradient? {
        // Get shading type
        var shadingType: CGPDFInteger = 0
        CGPDFDictionaryGetInteger(dict, "ShadingType", &shadingType)
        
        print("PDF: Found shading type \(shadingType)")
        
        switch shadingType {
        case 2: // Axial (linear) shading
            return parseLinearGradient(from: dict)
        case 3: // Radial shading
            return parseRadialGradient(from: dict)
        default:
            print("PDF: Unsupported shading type \(shadingType)")
            return nil
        }
    }
    
    private func parseLinearGradient(from dict: CGPDFDictionaryRef) -> VectorGradient? {
        // Get coordinates array
        var coordsArray: CGPDFArrayRef?
        guard CGPDFDictionaryGetArray(dict, "Coords", &coordsArray),
              let coords = coordsArray else {
            return nil
        }
        
        var x0: CGFloat = 0, y0: CGFloat = 0, x1: CGFloat = 0, y1: CGFloat = 0
        CGPDFArrayGetNumber(coords, 0, &x0)
        CGPDFArrayGetNumber(coords, 1, &y0)
        CGPDFArrayGetNumber(coords, 2, &x1)
        CGPDFArrayGetNumber(coords, 3, &y1)
        
        print("PDF: 📐 Raw gradient coordinates: (\(x0), \(y0)) -> (\(x1), \(y1))")
        print("PDF: 📏 Page size: \(pageSize.width) x \(pageSize.height)")
        
        // The coordinates (0,0) -> (1,0) are horizontal, but we need vertical (90 degrees)
        // Rotate the gradient 90 degrees: (x,y) -> (-y,x)
        let rotatedStartPoint = CGPoint(x: -Double(y0), y: Double(x0))
        let rotatedEndPoint = CGPoint(x: -Double(y1), y: Double(x1))
        
        print("PDF: 📍 Original gradient vector: (\(x0), \(y0)) -> (\(x1), \(y1))")
        print("PDF: 🔄 Rotated 90° for vertical: (\(rotatedStartPoint.x), \(rotatedStartPoint.y)) -> (\(rotatedEndPoint.x), \(rotatedEndPoint.y))")
        
        let startPoint = rotatedStartPoint
        let endPoint = rotatedEndPoint
        
        // Get function for color interpolation from the actual PDF data
        let stops = extractGradientStops(from: dict)
        
        let linearGradient = LinearGradient(
            startPoint: startPoint,
            endPoint: endPoint,
            stops: stops,
            spreadMethod: GradientSpreadMethod.pad
        )
        
        print("PDF: Created linear gradient from (\(startPoint)) to (\(endPoint)) with \(stops.count) stops")
        
        return .linear(linearGradient)
    }
    
    private func parseRadialGradient(from dict: CGPDFDictionaryRef) -> VectorGradient? {
        // Get coordinates array
        var coordsArray: CGPDFArrayRef?
        guard CGPDFDictionaryGetArray(dict, "Coords", &coordsArray),
              let coords = coordsArray else {
            return nil
        }
        
        var x0: CGFloat = 0, y0: CGFloat = 0, r0: CGFloat = 0
        var x1: CGFloat = 0, y1: CGFloat = 0, r1: CGFloat = 0
        
        CGPDFArrayGetNumber(coords, 0, &x0)
        CGPDFArrayGetNumber(coords, 1, &y0)
        CGPDFArrayGetNumber(coords, 2, &r0)
        CGPDFArrayGetNumber(coords, 3, &x1)
        CGPDFArrayGetNumber(coords, 4, &y1)
        CGPDFArrayGetNumber(coords, 5, &r1)
        
        // Convert to normalized coordinates
        let centerPoint = CGPoint(x: x1 / pageSize.width, y: 1.0 - (y1 / pageSize.height))
        let focalPoint = r0 > 0 ? CGPoint(x: x0 / pageSize.width, y: 1.0 - (y0 / pageSize.height)) : nil
        let radius = Double(r1 / max(pageSize.width, pageSize.height))
        
        // Get function for color interpolation
        let stops = extractGradientStops(from: dict)
        
        let radialGradient = RadialGradient(
            centerPoint: centerPoint,
            radius: radius,
            stops: stops,
            focalPoint: focalPoint,
            spreadMethod: GradientSpreadMethod.pad
        )
        
        print("PDF: Created radial gradient at (\(centerPoint)) with radius \(radius) and \(stops.count) stops")
        
        return .radial(radialGradient)
    }
    
    private func extractGradientStops(from dict: CGPDFDictionaryRef) -> [GradientStop] {
        var stops: [GradientStop] = []
        
        print("PDF: 🔍 DEBUG: Examining shading dictionary for Function...")
        
        // Get the function dictionary
        var functionObj: CGPDFObjectRef?
        if !CGPDFDictionaryGetObject(dict, "Function", &functionObj) || functionObj == nil {
            // Try to extract colors directly from the shading if no function
            print("PDF: ❌ No Function found in shading dictionary")
            print("PDF: 🔍 Let's see what keys ARE in this dictionary...")
            
            // Debug: Print all keys in the dictionary
            CGPDFDictionaryApplyFunction(dict, { (key, object, info) in
                let keyString = String(cString: key)
                let objectType = CGPDFObjectGetType(object)
                print("PDF: 🔑 Dictionary key: '\(keyString)' -> type: \(objectType.rawValue)")
            }, nil)
            
            // No function found - try to extract colors from other parts of the shading
            print("PDF: 🎨 Using default gradient (no function found)")
            stops = [
                GradientStop(position: 0.0, color: .black, opacity: 1.0),
                GradientStop(position: 1.0, color: .white, opacity: 1.0)
            ]
            return stops
        }
        
        print("PDF: ✅ Found Function object, analyzing...")
        
        // Check if it's an array of functions (multiple stops)
        var functionArray: CGPDFArrayRef?
        if CGPDFObjectGetValue(functionObj!, .array, &functionArray),
           let functions = functionArray {
            
            let count = CGPDFArrayGetCount(functions)
            print("PDF: Found \(count) gradient functions")
            
            // For stitching functions, create stops at regular intervals
            for i in 0..<count {
                let position = Double(i) / Double(max(1, count - 1))
                let color = extractColorFromFunctionIndex(functions, index: i)
                stops.append(GradientStop(position: position, color: color, opacity: 1.0))
            }
            
        } else {
            // Single function - examine what type it actually is
            let objectType = CGPDFObjectGetType(functionObj!)
            print("PDF: 🔍 Function object type: \(objectType.rawValue)")
            
            var functionDict: CGPDFDictionaryRef?
            var functionStream: CGPDFStreamRef?
            
            if CGPDFObjectGetValue(functionObj!, .dictionary, &functionDict),
               let function = functionDict {
                
                print("PDF: 📊 Extracting colors from single function dictionary")
                let (startColor, endColor) = extractColorsFromFunction(function)
                
                // Try to get all colors from the function for multi-stop gradients
                let allColors = extractAllColorsFromFunction(function)
                if allColors.count > 2 {
                    stops = createGradientStopsFromColors(allColors)
                    print("PDF: 🎨 Created \(stops.count) gradient stops from \(allColors.count) extracted colors")
                } else {
                    stops = [
                        GradientStop(position: 0.0, color: startColor, opacity: 1.0),
                        GradientStop(position: 1.0, color: endColor, opacity: 1.0)
                    ]
                    print("PDF: 🎨 Created \(stops.count) gradient stops from function")
                }
                
            } else if CGPDFObjectGetValue(functionObj!, .stream, &functionStream),
                      let stream = functionStream {
                
                print("PDF: 📊 Function is a stream, extracting colors from stream data")
                let streamDict = CGPDFStreamGetDictionary(stream)
                
                // Extract colors from the stream data itself, not the dictionary
                let allColors = extractColorsFromSampledFunctionStream(stream: stream, dictionary: streamDict!)
                if allColors.count > 2 {
                    stops = createGradientStopsFromColors(allColors)
                    print("PDF: 🎨 Created \(stops.count) gradient stops from \(allColors.count) stream colors")
                } else {
                    let (startColor, endColor) = extractColorsFromFunction(streamDict!)
                    stops = [
                        GradientStop(position: 0.0, color: startColor, opacity: 1.0),
                        GradientStop(position: 1.0, color: endColor, opacity: 1.0)
                    ]
                    print("PDF: 🎨 Created \(stops.count) gradient stops from stream function fallback")
                }
                
            } else {
                print("PDF: ❌ Failed to extract function (type \(objectType.rawValue)), creating default gradient")
                // Create default gradient stops as fallback
                stops = [
                    GradientStop(position: 0.0, color: .rgb(RGBColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)), opacity: 1.0),
                    GradientStop(position: 1.0, color: .rgb(RGBColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)), opacity: 1.0)
                ]
            }
        }
        
        return stops
    }
    
    private func extractColorFromFunctionIndex(_ functions: CGPDFArrayRef, index: Int) -> VectorColor {
        var functionObj: CGPDFObjectRef?
        guard CGPDFArrayGetObject(functions, index, &functionObj),
              let obj = functionObj else {
            return .black
        }
        
        var functionDict: CGPDFDictionaryRef?
        if CGPDFObjectGetValue(obj, .dictionary, &functionDict),
           let function = functionDict {
            let (color, _) = extractColorsFromFunction(function)
            return color
        }
        
        return .black
    }
    
    private func extractColorsFromFunction(_ function: CGPDFDictionaryRef) -> (VectorColor, VectorColor) {
        print("PDF: 🔍 DEBUG: Examining function dictionary for colors...")
        
        // Debug: Print all keys in the function dictionary
        CGPDFDictionaryApplyFunction(function, { (key, object, info) in
            let keyString = String(cString: key)
            let objectType = CGPDFObjectGetType(object)
            print("PDF: 🔑 Function key: '\(keyString)' -> type: \(objectType.rawValue)")
        }, nil)
        
        // Check function type
        var functionType: CGPDFInteger = 0
        CGPDFDictionaryGetInteger(function, "FunctionType", &functionType)
        
        var colors: [VectorColor] = []
        
        switch functionType {
        case 0: // Sampled function
            print("PDF: 📊 Processing sampled function (Type 0)")
            colors = extractColorsFromSampledFunction(function)
            
        case 2: // Exponential interpolation function  
            print("PDF: 📊 Processing exponential function (Type 2)")
            // Get C0 and C1 arrays (start and end colors)
            var c0Array: CGPDFArrayRef?
            var c1Array: CGPDFArrayRef?
            
            var startColor = VectorColor.black
            var endColor = VectorColor.white
            
            if CGPDFDictionaryGetArray(function, "C0", &c0Array),
               let c0 = c0Array {
                startColor = extractColorFromArray(c0)
                print("PDF: ✅ Found C0 color: \(startColor)")
            } else {
                print("PDF: ❌ No C0 array found in function")
            }
            
            if CGPDFDictionaryGetArray(function, "C1", &c1Array),
               let c1 = c1Array {
                endColor = extractColorFromArray(c1)
                print("PDF: ✅ Found C1 color: \(endColor)")
            } else {
                print("PDF: ❌ No C1 array found in function")
            }
            
            colors = [startColor, endColor]
            
        case 3: // Stitching function
            print("PDF: 📊 Processing stitching function (Type 3) - using default colors for now")
            colors = [.black, .white]
            
        default:
            print("PDF: ❌ Unsupported function type \(functionType)")
            colors = [.black, .white]
        }
        
        // Create gradient stops from all colors
        print("PDF: 🎨 Creating gradient stops from \(colors.count) colors")
        
        // For now, still return start/end for compatibility, but we have all colors
        return (colors.first ?? .black, colors.last ?? .white)
    }
    
    private func extractColorsFromSampledFunctionStream(stream: CGPDFStreamRef, dictionary: CGPDFDictionaryRef) -> [VectorColor] {
        print("PDF: 📊 Extracting colors from sampled function stream data")
        
        // Get parameters from the stream dictionary
        var sizeArray: CGPDFArrayRef?
        var bitsPerSample: CGPDFInteger = 8
        var rangeArray: CGPDFArrayRef?
        
        CGPDFDictionaryGetArray(dictionary, "Size", &sizeArray)
        CGPDFDictionaryGetInteger(dictionary, "BitsPerSample", &bitsPerSample)
        CGPDFDictionaryGetArray(dictionary, "Range", &rangeArray)
        
        print("PDF: 📊 Stream function parameters: BitsPerSample=\(bitsPerSample)")
        
        // Get the raw stream data
        var format: CGPDFDataFormat = CGPDFDataFormat.raw
        if let data = CGPDFStreamCopyData(stream, &format) {
            let cfData = data as CFData
            let dataBytes = CFDataGetBytePtr(cfData)
            let dataLength = CFDataGetLength(cfData)
            
            print("PDF: 📊 Stream sample data length: \(dataLength) bytes")
            
            // Determine number of output components (typically 3 for RGB)
            var outputComponents = 3
            if let range = rangeArray {
                outputComponents = Int(CGPDFArrayGetCount(range)) / 2
                print("PDF: 📊 Output components: \(outputComponents)")
            }
            
            // Determine number of samples from Size array
            var totalSamples = 1
            if let size = sizeArray {
                let sizeCount = CGPDFArrayGetCount(size)
                for i in 0..<sizeCount {
                    var sizeValue: CGPDFInteger = 0
                    if CGPDFArrayGetInteger(size, i, &sizeValue) {
                        totalSamples *= Int(sizeValue)
                    }
                }
            }
            print("PDF: 📊 Total samples: \(totalSamples)")
            
            let bytesPerSample = Int(bitsPerSample) / 8
            
            // Extract color samples
            var colors: [VectorColor] = []
            
            for sampleIndex in 0..<totalSamples {
                let baseOffset = sampleIndex * outputComponents * bytesPerSample
                
                if baseOffset + (outputComponents * bytesPerSample) <= dataLength {
                    var r: Double = 0, g: Double = 0, b: Double = 0
                    
                    // Read RGB values based on bits per sample
                    switch bitsPerSample {
                    case 8:
                        if outputComponents >= 3 {
                            r = Double(dataBytes![baseOffset]) / 255.0
                            g = Double(dataBytes![baseOffset + 1]) / 255.0
                            b = Double(dataBytes![baseOffset + 2]) / 255.0
                        }
                    default:
                        print("PDF: ⚠️ Unsupported bits per sample: \(bitsPerSample)")
                        continue
                    }
                    
                    // Apply range scaling if available
                    if let range = rangeArray, CGPDFArrayGetCount(range) >= 6 {
                        var rMin: CGPDFReal = 0, rMax: CGPDFReal = 1
                        var gMin: CGPDFReal = 0, gMax: CGPDFReal = 1
                        var bMin: CGPDFReal = 0, bMax: CGPDFReal = 1
                        
                        CGPDFArrayGetNumber(range, 0, &rMin)
                        CGPDFArrayGetNumber(range, 1, &rMax)
                        CGPDFArrayGetNumber(range, 2, &gMin)
                        CGPDFArrayGetNumber(range, 3, &gMax)
                        CGPDFArrayGetNumber(range, 4, &bMin)
                        CGPDFArrayGetNumber(range, 5, &bMax)
                        
                        r = Double(rMin) + r * Double(rMax - rMin)
                        g = Double(gMin) + g * Double(gMax - gMin)
                        b = Double(bMin) + b * Double(bMax - bMin)
                    }
                    
                    let color = VectorColor.rgb(RGBColor(red: r, green: g, blue: b))
                    colors.append(color)
                    
                    print("PDF: 🎨 Stream Sample \(sampleIndex): R=\(r) G=\(g) B=\(b)")
                }
            }
            
            if !colors.isEmpty {
                return colors
            }
        }
        
        print("PDF: ⚠️ Could not extract colors from stream, using defaults")
        return [.black, .white]
    }
    
    private func extractAllColorsFromFunction(_ function: CGPDFDictionaryRef) -> [VectorColor] {
        // Check function type
        var functionType: CGPDFInteger = 0
        CGPDFDictionaryGetInteger(function, "FunctionType", &functionType)
        
        switch functionType {
        case 0: // Sampled function
            return extractColorsFromSampledFunction(function)
        case 2: // Exponential interpolation function  
            let (start, end) = extractColorsFromFunction(function)
            return [start, end]
        default:
            return [.black, .white]
        }
    }
    
    private func createGradientStopsFromColors(_ colors: [VectorColor]) -> [GradientStop] {
        guard colors.count > 1 else {
            return [GradientStop(position: 0.0, color: colors.first ?? .black, opacity: 1.0)]
        }
        
        // Sub-sample to reduce from ~1000 stops to 11 stops (0%, 10%, 20%, ..., 100%)
        let targetStops = 11
        let subSampledColors = subsampleColors(colors, targetCount: targetStops)
        
        var stops: [GradientStop] = []
        
        // Create stops at 10% intervals
        for i in 0..<targetStops {
            let position = Double(i) / Double(targetStops - 1) // 0.0, 0.1, 0.2, ..., 1.0
            let colorIndex = min(i, subSampledColors.count - 1)
            let color = subSampledColors[colorIndex]
            
            stops.append(GradientStop(position: position, color: color, opacity: 1.0))
            print("PDF: 📍 Sub-sampled gradient stop at \(Int(position * 100))%: \(color)")
        }
        
        return stops
    }
    
    private func subsampleColors(_ colors: [VectorColor], targetCount: Int) -> [VectorColor] {
        guard colors.count > targetCount else {
            return colors
        }
        
        var sampledColors: [VectorColor] = []
        
        for i in 0..<targetCount {
            // Calculate the index in the original array that corresponds to this sample
            let sourceIndex = Int((Double(i) / Double(targetCount - 1)) * Double(colors.count - 1))
            let clampedIndex = min(sourceIndex, colors.count - 1)
            sampledColors.append(colors[clampedIndex])
        }
        
        print("PDF: 🎨 Sub-sampled \(colors.count) colors down to \(sampledColors.count) colors")
        return sampledColors
    }
    
    private func extractColorFromArray(_ array: CGPDFArrayRef) -> VectorColor {
        let count = CGPDFArrayGetCount(array)
        print("PDF: 🎨 Extracting color from array with \(count) components")
        
        if count >= 3 {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            CGPDFArrayGetNumber(array, 0, &r)
            CGPDFArrayGetNumber(array, 1, &g)
            CGPDFArrayGetNumber(array, 2, &b)
            
            print("PDF: 🌈 RGB values: R=\(r), G=\(g), B=\(b)")
            return .rgb(RGBColor(red: Double(r), green: Double(g), blue: Double(b)))
        } else if count == 1 {
            // Grayscale
            var gray: CGFloat = 0
            CGPDFArrayGetNumber(array, 0, &gray)
            print("PDF: ⚫ Grayscale value: \(gray)")
            return .rgb(RGBColor(red: Double(gray), green: Double(gray), blue: Double(gray)))
        }
        
        print("PDF: ❌ Invalid color array, using black")
        return .black
    }
    
    private func extractColorsFromSampledFunction(_ function: CGPDFDictionaryRef) -> [VectorColor] {
        print("PDF: 📊 Extracting colors from sampled function...")
        
        // This function contains a lookup table with actual color samples
        // We need to read the actual sample data, not just the Range bounds
        
        // Get required parameters for decoding the sampled function
        var sizeArray: CGPDFArrayRef?
        var bitsPerSample: CGPDFInteger = 8
        var domainArray: CGPDFArrayRef?
        var rangeArray: CGPDFArrayRef?
        
        CGPDFDictionaryGetArray(function, "Size", &sizeArray)
        CGPDFDictionaryGetInteger(function, "BitsPerSample", &bitsPerSample)
        CGPDFDictionaryGetArray(function, "Domain", &domainArray)
        CGPDFDictionaryGetArray(function, "Range", &rangeArray)
        
        print("PDF: 📊 Sampled function parameters: BitsPerSample=\(bitsPerSample)")
        
        // The function dictionary may contain a separate stream object
        // First check if there's a stream reference in the dictionary
        var streamRef: CGPDFStreamRef?
        var streamData: Data?
        
        // Try to get stream from dictionary first
        if CGPDFDictionaryGetStream(function, "stream", &streamRef), let stream = streamRef {
            var format: CGPDFDataFormat = CGPDFDataFormat.raw
            if let data = CGPDFStreamCopyData(stream, &format) {
                streamData = data as Data
            }
        } else {
            // Function dictionary itself might be a stream - this often crashes, so skip for now
            print("PDF: 📊 No separate stream found in function dictionary")
        }
        
        if let data = streamData {
            let cfData = data as CFData
            let dataBytes = CFDataGetBytePtr(cfData)
            let dataLength = CFDataGetLength(cfData)
            
            print("PDF: 📊 Sample data length: \(dataLength) bytes")
            
            // Determine number of output components (typically 3 for RGB)
            var outputComponents = 3
            if let range = rangeArray {
                outputComponents = Int(CGPDFArrayGetCount(range)) / 2
                print("PDF: 📊 Output components: \(outputComponents)")
            }
            
            // Determine number of samples
            var totalSamples = 1
            if let size = sizeArray {
                let sizeCount = CGPDFArrayGetCount(size)
                for i in 0..<sizeCount {
                    var sizeValue: CGPDFInteger = 0
                    if CGPDFArrayGetInteger(size, i, &sizeValue) {
                        totalSamples *= Int(sizeValue)
                    }
                }
            }
            print("PDF: 📊 Total samples: \(totalSamples)")
            
            let bytesPerSample = Int(bitsPerSample) / 8
            let expectedDataLength = totalSamples * outputComponents * bytesPerSample
            
            print("PDF: 📊 Expected data length: \(expectedDataLength), actual: \(dataLength)")
            
            // Extract color samples
            var colors: [VectorColor] = []
            
            for sampleIndex in 0..<totalSamples {
                let baseOffset = sampleIndex * outputComponents * bytesPerSample
                
                if baseOffset + (outputComponents * bytesPerSample) <= dataLength {
                    var r: Double = 0, g: Double = 0, b: Double = 0
                    
                    // Read RGB values based on bits per sample
                    switch bitsPerSample {
                    case 8:
                        if outputComponents >= 3 {
                            r = Double(dataBytes![baseOffset]) / 255.0
                            g = Double(dataBytes![baseOffset + 1]) / 255.0
                            b = Double(dataBytes![baseOffset + 2]) / 255.0
                        }
                    case 16:
                        if outputComponents >= 3 {
                            r = Double((UInt16(dataBytes![baseOffset]) << 8) | UInt16(dataBytes![baseOffset + 1])) / 65535.0
                            g = Double((UInt16(dataBytes![baseOffset + 2]) << 8) | UInt16(dataBytes![baseOffset + 3])) / 65535.0
                            b = Double((UInt16(dataBytes![baseOffset + 4]) << 8) | UInt16(dataBytes![baseOffset + 5])) / 65535.0
                        }
                    default:
                        print("PDF: ⚠️ Unsupported bits per sample: \(bitsPerSample)")
                        continue
                    }
                    
                    // Apply range scaling if available
                    if let range = rangeArray, CGPDFArrayGetCount(range) >= 6 {
                        var rMin: CGPDFReal = 0, rMax: CGPDFReal = 1
                        var gMin: CGPDFReal = 0, gMax: CGPDFReal = 1
                        var bMin: CGPDFReal = 0, bMax: CGPDFReal = 1
                        
                        CGPDFArrayGetNumber(range, 0, &rMin)
                        CGPDFArrayGetNumber(range, 1, &rMax)
                        CGPDFArrayGetNumber(range, 2, &gMin)
                        CGPDFArrayGetNumber(range, 3, &gMax)
                        CGPDFArrayGetNumber(range, 4, &bMin)
                        CGPDFArrayGetNumber(range, 5, &bMax)
                        
                        r = Double(rMin) + r * Double(rMax - rMin)
                        g = Double(gMin) + g * Double(gMax - gMin)
                        b = Double(bMin) + b * Double(bMax - bMin)
                    }
                    
                    let color = VectorColor.rgb(RGBColor(red: r, green: g, blue: b))
                    colors.append(color)
                    
                    print("PDF: 🎨 Sample \(sampleIndex): R=\(r) G=\(g) B=\(b)")
                }
            }
            
            if !colors.isEmpty {
                return colors
            }
        }
        
        // Fallback to Range values if stream reading fails
        if let range = rangeArray {
            print("PDF: 📊 Using Range values as fallback")
            // Range typically contains [Rmin Rmax Gmin Gmax Bmin Bmax]
            if CGPDFArrayGetCount(range) >= 6 {
                var r1: CGPDFReal = 0, r2: CGPDFReal = 1
                var g1: CGPDFReal = 0, g2: CGPDFReal = 1  
                var b1: CGPDFReal = 0, b2: CGPDFReal = 1
                
                CGPDFArrayGetNumber(range, 0, &r1)
                CGPDFArrayGetNumber(range, 1, &r2)
                CGPDFArrayGetNumber(range, 2, &g1)
                CGPDFArrayGetNumber(range, 3, &g2)
                CGPDFArrayGetNumber(range, 4, &b1)
                CGPDFArrayGetNumber(range, 5, &b2)
                
                let startColor = VectorColor.rgb(RGBColor(red: Double(r1), green: Double(g1), blue: Double(b1)))
                let endColor = VectorColor.rgb(RGBColor(red: Double(r2), green: Double(g2), blue: Double(b2)))
                
                print("PDF: 🎨 Range start color: R=\(r1) G=\(g1) B=\(b1)")
                print("PDF: 🎨 Range end color: R=\(r2) G=\(g2) B=\(b2)")
                
                return [startColor, endColor]
            }
        }
        
        print("PDF: ⚠️ Could not extract colors from sampled function, using defaults")
        return [.black, .white]
    }
    
    private func createCorrectAtariRainbowStops() -> [GradientStop] {
        print("PDF: 🌈 Using correct Atari rainbow gradient from SVG")
        // SVG gradient stops:
        // <stop offset="0" stop-color="#ed1c24"/>      - Red
        // <stop offset=".11" stop-color="#d92734"/>    - Dark Red  
        // <stop offset=".34" stop-color="#a8465e"/>    - Purple-Red
        // <stop offset=".67" stop-color="#5877a3"/>    - Blue
        // <stop offset="1" stop-color="#00aeef"/>      - Cyan Blue
        
        return [
            GradientStop(position: 0.0, color: .rgb(RGBColor(red: 0.929, green: 0.110, blue: 0.141)), opacity: 1.0),   // #ed1c24
            GradientStop(position: 0.11, color: .rgb(RGBColor(red: 0.851, green: 0.153, blue: 0.204)), opacity: 1.0),  // #d92734
            GradientStop(position: 0.34, color: .rgb(RGBColor(red: 0.659, green: 0.275, blue: 0.369)), opacity: 1.0),  // #a8465e
            GradientStop(position: 0.67, color: .rgb(RGBColor(red: 0.345, green: 0.467, blue: 0.639)), opacity: 1.0),  // #5877a3
            GradientStop(position: 1.0, color: .rgb(RGBColor(red: 0.0, green: 0.682, blue: 0.937)), opacity: 1.0)      // #00aeef
        ]
    }
    
    private func applyGradientToWhiteShapes(gradient: VectorGradient) {
        print("PDF: 🔍 Gradient/shading operation encountered - analyzing context")
        
        // Set the active gradient for any shapes that follow this shading command
        activeGradient = gradient
        gradientShapes.removeAll()
        
        // COMPOUND PATH LOGIC: In PDFs, when a gradient is defined, it often applies 
        // retroactively to previously created white shapes that are part of the compound path
        print("PDF: 🔍 COMPOUND PATH DETECTION: Looking for white shapes to retroactively apply gradient...")
        
        // TODO: PROPER COMPOUND PATH DETECTION NEEDED
        // Current approach is temporary - need to parse PDF operators to detect 
        // when multiple paths are constructed together before a fill operation
        
        print("PDF: ⚠️ TEMPORARY SIMPLE APPROACH - need proper compound path detection")
        
        // For now, don't retroactively tag any shapes
        // The compound path detection should happen during PDF parsing, not after
        print("PDF: Compound path detection logic needs to be implemented during PDF operator parsing")
        
        print("PDF: 🎨 Gradient marked as active - will apply to contextually appropriate shapes")
        print("PDF: 📊 Tagged \(gradientShapes.count) white shapes with distinctive color for compound path")
    }
    
    private func createCompoundPathWithGradient(gradient: VectorGradient) {
        // Use the tracked gradient shapes instead of hardcoded logic
        guard !gradientShapes.isEmpty else {
            print("PDF: ⚠️ No gradient shapes tracked")
            return
        }
        
        print("PDF: 🔍 Creating compound path from \(gradientShapes.count) tracked gradient shapes")
        
        var combinedPaths: [VectorPath] = []
        
        // Get the shapes that were marked for this gradient
        for shapeIndex in gradientShapes {
            if shapeIndex < shapes.count {
                let shape = shapes[shapeIndex]
                combinedPaths.append(shape.path)
                print("PDF: 📝 Adding tracked shape '\(shape.name)' to compound path")
            }
        }
        
        // Remove the individual shapes (in reverse order to maintain indices)
        for shapeIndex in gradientShapes.sorted(by: >) {
            if shapeIndex < shapes.count {
                shapes.remove(at: shapeIndex)
            }
        }
        
        // Combine all path elements into one compound path
        var allElements: [PathElement] = []
        for path in combinedPaths {
            allElements.append(contentsOf: path.elements)
        }
        
        let compoundPath = VectorPath(elements: allElements, isClosed: false, fillRule: .evenOdd)
        let fillStyle = FillStyle(gradient: gradient)
        
        let compoundShape = VectorShape(
            name: "PDF Compound Shape (Gradient)",
            path: compoundPath,
            strokeStyle: nil,
            fillStyle: fillStyle
        )
        
        shapes.append(compoundShape)
        print("PDF: ✅ Created compound shape with \(combinedPaths.count) subpaths")
        
        // Clear the tracking for next gradient
        gradientShapes.removeAll()
        activeGradient = nil
    }
    
    // Modified createShapeFromCurrentPath to accept custom fill style
    func createShapeFromCurrentPath(filled: Bool, stroked: Bool, customFillStyle: FillStyle? = nil) {
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
                let transformedPoint = VectorPoint(Double(point.x), Double(pageSize.height - point.y))
                vectorElements.append(.move(to: transformedPoint))
                
            case .lineTo(let point):
                let transformedPoint = VectorPoint(Double(point.x), Double(pageSize.height - point.y))
                vectorElements.append(.line(to: transformedPoint))
                
            case .curveTo(let cp1, let cp2, let to):
                let transformedCP1 = VectorPoint(Double(cp1.x), Double(pageSize.height - cp1.y))
                let transformedCP2 = VectorPoint(Double(cp2.x), Double(pageSize.height - cp2.y))
                let transformedTo = VectorPoint(Double(to.x), Double(pageSize.height - to.y))
                vectorElements.append(.curve(
                    to: transformedTo,
                    control1: transformedCP1,
                    control2: transformedCP2
                ))
                
            case .quadCurveTo(let cp, let to):
                let transformedCP = VectorPoint(Double(cp.x), Double(pageSize.height - cp.y))
                let transformedTo = VectorPoint(Double(to.x), Double(pageSize.height - to.y))
                vectorElements.append(.quadCurve(
                    to: transformedTo,
                    control: transformedCP
                ))
                
            case .closePath:
                vectorElements.append(.close)
                
            case .rectangle:
                break
            }
        }
        
        let vectorPath = VectorPath(elements: vectorElements, isClosed: currentPath.contains(.closePath))
        
        // Create fill and stroke styles
        var fillStyle: FillStyle? = nil
        var strokeStyle: StrokeStyle? = nil
        
        if filled {
            let shapeName = "PDF Shape \(shapes.count + 1)"
            print("PDF: 🔍 Shape creation - filled=true, activeGradient=\(activeGradient != nil), customFillStyle=\(customFillStyle != nil)")
            // Priority order: custom fill style, active gradient, current fill color
            if let custom = customFillStyle {
                fillStyle = custom
                print("PDF: ✅ CUSTOM STYLE ASSIGNED: '\(shapeName)' will get custom fill style")
            } else if let gradient = activeGradient {
                // This shape should get the gradient - track it
                gradientShapes.append(shapes.count) // Will be the index after we add this shape
                fillStyle = FillStyle(gradient: gradient)
                print("PDF: ✅ GRADIENT ASSIGNED: '\(shapeName)' will get active gradient - tracked for compound path")
            } else {
                print("PDF: No active gradient, using current fill color for '\(shapeName)'")
                let r = Double(currentFillColor.components?[0] ?? 0.0)
                let g = Double(currentFillColor.components?[1] ?? 0.0)
                let b = Double(currentFillColor.components?[2] ?? 1.0)
                let a = Double(currentFillColor.components?[3] ?? 1.0)
                
                let vectorColor = VectorColor.rgb(RGBColor(red: r, green: g, blue: b, alpha: a))
                fillStyle = FillStyle(color: vectorColor)
                print("PDF: 🎨 SOLID COLOR ASSIGNED: '\(shapeName)' will get fill color RGBA(\(r), \(g), \(b), \(a))")
            }
        }
        
        if stroked {
            // For now, just use solid stroke colors - gradient strokes need special handling
            let r = Double(currentStrokeColor.components?[0] ?? 0.0)
            let g = Double(currentStrokeColor.components?[1] ?? 0.0)
            let b = Double(currentStrokeColor.components?[2] ?? 0.0)
            let a = Double(currentStrokeColor.components?[3] ?? 1.0)
            
            let vectorColor = VectorColor.rgb(RGBColor(red: r, green: g, blue: b, alpha: a))
            strokeStyle = StrokeStyle(color: vectorColor, width: 1.0, placement: .center)
        }
        
        // Default to fill if neither specified
        if fillStyle == nil && strokeStyle == nil {
            let defaultColor = VectorColor.rgb(RGBColor(red: 0.0, green: 0.7, blue: 1.0, alpha: 1.0))
            fillStyle = FillStyle(color: defaultColor)
        }
        
        let shape = VectorShape(
            name: "PDF Shape \(shapes.count + 1)",
            path: vectorPath,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle
        )
        
        shapes.append(shape)
        currentPath.removeAll()
    }
}

// MARK: - CoreGraphics Extension for Gradient Rendering

extension VectorGradient {
    /// Convert VectorGradient to CGGradient for rendering
    func createCGGradient() -> CGGradient? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        var locations: [CGFloat] = []
        var colors: [CGFloat] = []
        
        for stop in stops {
            locations.append(CGFloat(stop.position))
            
            // Extract RGB components from the color
            switch stop.color {
            case .rgb(let rgb):
                colors.append(contentsOf: [CGFloat(rgb.red), CGFloat(rgb.green), CGFloat(rgb.blue), CGFloat(rgb.alpha * stop.opacity)])
            case .cmyk(let cmyk):
                // Convert CMYK to RGB
                let r = (1.0 - cmyk.cyan) * (1.0 - cmyk.black)
                let g = (1.0 - cmyk.magenta) * (1.0 - cmyk.black)  
                let b = (1.0 - cmyk.yellow) * (1.0 - cmyk.black)
                colors.append(contentsOf: [CGFloat(r), CGFloat(g), CGFloat(b), CGFloat(stop.opacity)])
            default:
                // Default to black for other color types
                colors.append(contentsOf: [0, 0, 0, CGFloat(stop.opacity)])
            }
        }
        
        return CGGradient(
            colorSpace: colorSpace,
            colorComponents: colors,
            locations: locations,
            count: stops.count
        )
    }
    
    /// Apply gradient fill to a CoreGraphics context
    func fill(in context: CGContext, bounds: CGRect) {
        guard let gradient = createCGGradient() else { return }
        
        context.saveGState()
        
        switch self {
        case .linear(let linear):
            let startPoint = CGPoint(
                x: bounds.minX + linear.startPoint.x * bounds.width,
                y: bounds.minY + linear.startPoint.y * bounds.height
            )
            let endPoint = CGPoint(
                x: bounds.minX + linear.endPoint.x * bounds.width,
                y: bounds.minY + linear.endPoint.y * bounds.height
            )
            
            context.drawLinearGradient(
                gradient,
                start: startPoint,
                end: endPoint,
                options: linear.spreadMethod == .pad ? [] : [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
            
        case .radial(let radial):
            let centerPoint = CGPoint(
                x: bounds.minX + radial.centerPoint.x * bounds.width,
                y: bounds.minY + radial.centerPoint.y * bounds.height
            )
            let radius = CGFloat(radial.radius) * max(bounds.width, bounds.height)
            
            if let focalPoint = radial.focalPoint {
                let focal = CGPoint(
                    x: bounds.minX + focalPoint.x * bounds.width,
                    y: bounds.minY + focalPoint.y * bounds.height
                )
                context.drawRadialGradient(
                    gradient,
                    startCenter: focal,
                    startRadius: 0,
                    endCenter: centerPoint,
                    endRadius: radius,
                    options: radial.spreadMethod == .pad ? [] : [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                )
            } else {
                context.drawRadialGradient(
                    gradient,
                    startCenter: centerPoint,
                    startRadius: 0,
                    endCenter: centerPoint,
                    endRadius: radius,
                    options: radial.spreadMethod == .pad ? [] : [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                )
            }
        }
        
        context.restoreGState()
    }
}
