//
//  PDFOperatorHandlers.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 9/1/25.
//  Extracted from PDFContent.swift - Path operation handlers
//

import SwiftUI

// MARK: - PDF Operator Handlers Extension
extension PDFCommandParser {
    
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
        
        // Check if this is actually a quadratic curve (can be converted) using vectoring module
        if let quadCommand = PDFCurveOptimizer.convertToQuadCurve(from: currentPoint, cp1: cp1, cp2: cp2, to: endPoint) {
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
        
        if let quadCommand = PDFCurveOptimizer.convertToQuadCurve(from: currentPoint, cp1: cp1, cp2: cp2, to: endPoint) {
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
        
        if let quadCommand = PDFCurveOptimizer.convertToQuadCurve(from: currentPoint, cp1: cp1, cp2: cp2, to: endPoint) {
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
        
        let rect = CGRect(x: x, y: y, width: width, height: height)
        
        // Use geometry module to filter out page boundary rectangles
        if PDFBoundsCalculator.isPageBoundaryRectangle(rect, pageSize: pageSize) {
            print("PDF: Skipping page boundary rectangle (\(width) x \(height))")
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
}
