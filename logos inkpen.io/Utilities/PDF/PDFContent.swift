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
    private var shapes: [VectorShape] = []
    private var currentPath: [PathCommand] = []
    private var pathStartPoint = CGPoint.zero
    
    func parseDocument(at url: URL) -> [VectorShape] {
        commands.removeAll()
        shapes.removeAll()
        
        guard let dataProvider = CGDataProvider(url: url as CFURL),
              let document = CGPDFDocument(dataProvider) else {
            print("Failed to load PDF document")
            return []
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
    }
    
    // MARK: - Operator Handlers
    
    private func handleMoveTo(scanner: CGPDFScannerRef) {
        // If we have an existing path and start a new one, finalize the current path
        if !currentPath.isEmpty {
            print("PDF: Starting new path - finalizing previous path as default filled shape")
            createShapeFromCurrentPath(filled: true, stroked: false)
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
        createShapeFromCurrentPath(filled: true, stroked: false)
    }
    
    private func handleStroke() {
        createShapeFromCurrentPath(filled: false, stroked: true)
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
                // Transform coordinates: flip Y and center on canvas
                let transformedPoint = VectorPoint(Double(point.x - 512), Double(512 - point.y))
                vectorElements.append(.move(to: transformedPoint))
                
            case .lineTo(let point):
                let transformedPoint = VectorPoint(Double(point.x - 512), Double(512 - point.y))
                vectorElements.append(.line(to: transformedPoint))
                
            case .curveTo(let cp1, let cp2, let to):
                let transformedCP1 = VectorPoint(Double(cp1.x - 512), Double(512 - cp1.y))
                let transformedCP2 = VectorPoint(Double(cp2.x - 512), Double(512 - cp2.y))
                let transformedTo = VectorPoint(Double(to.x - 512), Double(512 - to.y))
                vectorElements.append(.curve(to: transformedTo, control1: transformedCP1, control2: transformedCP2))
                
            case .quadCurveTo(let cp, let to):
                let transformedCP = VectorPoint(Double(cp.x - 512), Double(512 - cp.y))
                let transformedTo = VectorPoint(Double(to.x - 512), Double(512 - to.y))
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
            let r = Double(currentFillColor.components?[0] ?? 0.0)
            let g = Double(currentFillColor.components?[1] ?? 0.0) 
            let b = Double(currentFillColor.components?[2] ?? 1.0)
            let a = Double(currentFillColor.components?[3] ?? 1.0)
            print("PDF: Applying fill color RGBA(\(r), \(g), \(b), \(a))")
            
            let vectorColor = VectorColor.rgb(RGBColor(red: r, green: g, blue: b, alpha: a))
            fillStyle = FillStyle(color: vectorColor)
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