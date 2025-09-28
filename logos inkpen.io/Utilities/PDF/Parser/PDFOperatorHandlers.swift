//
//  PDFOperatorHandlers.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import SwiftUI

// MARK: - PDF Path Construction Operators
extension PDFCommandParser {
    
    // MARK: - Path Construction Operators
    
    func handleMoveTo(scanner: CGPDFScannerRef) {
        // COMPOUND PATH DETECTION: Multiple MoveTo operations before fill = compound path
        if !currentPath.isEmpty {
            Log.info("PDF: COMPOUND PATH DETECTED - MoveTo with existing path, storing current path as part of compound", category: .general)
            
            // Store the current path as part of a compound path
            compoundPathParts.append(currentPath)
            isInCompoundPath = true
            moveToCount += 1
            
            Log.info("PDF: Compound path part #\(compoundPathParts.count) stored (\(currentPath.count) commands)", category: .general)
            
            // CRITICAL: Clear currentPath after storing it to prevent accumulation
            currentPath.removeAll()
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
        Log.info("PDF: MoveTo(\(x), \(y))", category: .general)
    }
    
    func handleLineTo(scanner: CGPDFScannerRef) {
        var x: CGFloat = 0, y: CGFloat = 0
        
        guard CGPDFScannerPopNumber(scanner, &y),
              CGPDFScannerPopNumber(scanner, &x) else { return }
        
        let point = CGPoint(x: x, y: y)
        currentPath.append(.lineTo(point))
        currentPoint = point
    }
    
    func handleCurveTo(scanner: CGPDFScannerRef) {
        var x1: CGFloat = 0, y1: CGFloat = 0
        var x2: CGFloat = 0, y2: CGFloat = 0
        var x3: CGFloat = 0, y3: CGFloat = 0
        
        guard CGPDFScannerPopNumber(scanner, &y3),
              CGPDFScannerPopNumber(scanner, &x3),
              CGPDFScannerPopNumber(scanner, &y2),
              CGPDFScannerPopNumber(scanner, &x2),
              CGPDFScannerPopNumber(scanner, &y1),
              CGPDFScannerPopNumber(scanner, &x1) else { return }
        
        let cp1 = CGPoint(x: x1, y: y1)
        let cp2 = CGPoint(x: x2, y: y2)
        let to = CGPoint(x: x3, y: y3)
        
        currentPath.append(.curveTo(cp1: cp1, cp2: cp2, to: to))
        currentPoint = to
    }
    
    func handleCurveToV(scanner: CGPDFScannerRef) {
        // v operator - curve with first control point same as current point
        var x2: CGFloat = 0, y2: CGFloat = 0
        var x3: CGFloat = 0, y3: CGFloat = 0
        
        guard CGPDFScannerPopNumber(scanner, &y3),
              CGPDFScannerPopNumber(scanner, &x3),
              CGPDFScannerPopNumber(scanner, &y2),
              CGPDFScannerPopNumber(scanner, &x2) else { return }
        
        let cp1 = currentPoint
        let cp2 = CGPoint(x: x2, y: y2)
        let to = CGPoint(x: x3, y: y3)
        
        currentPath.append(.curveTo(cp1: cp1, cp2: cp2, to: to))
        currentPoint = to
    }
    
    func handleCurveToY(scanner: CGPDFScannerRef) {
        // y operator - curve with second control point same as endpoint
        var x1: CGFloat = 0, y1: CGFloat = 0
        var x3: CGFloat = 0, y3: CGFloat = 0
        
        guard CGPDFScannerPopNumber(scanner, &y3),
              CGPDFScannerPopNumber(scanner, &x3),
              CGPDFScannerPopNumber(scanner, &y1),
              CGPDFScannerPopNumber(scanner, &x1) else { return }
        
        let cp1 = CGPoint(x: x1, y: y1)
        let to = CGPoint(x: x3, y: y3)
        let cp2 = to
        
        currentPath.append(.curveTo(cp1: cp1, cp2: cp2, to: to))
        currentPoint = to
    }
    
    func handleRectangle(scanner: CGPDFScannerRef) {
        var x: CGFloat = 0, y: CGFloat = 0
        var width: CGFloat = 0, height: CGFloat = 0
        
        guard CGPDFScannerPopNumber(scanner, &height),
              CGPDFScannerPopNumber(scanner, &width),
              CGPDFScannerPopNumber(scanner, &y),
              CGPDFScannerPopNumber(scanner, &x) else { return }
        
        let rect = CGRect(x: x, y: y, width: width, height: height)
        
        // Skip page boundary rectangles
        if rect.width == pageSize.width && rect.height == pageSize.height {
            Log.info("PDF: Skipping page boundary rectangle (\(rect.width) x \(rect.height))", category: .general)
            return
        }
        
        // Convert rectangle to individual path commands (moves and lines)
        currentPath.append(.moveTo(CGPoint(x: rect.minX, y: rect.minY)))
        currentPath.append(.lineTo(CGPoint(x: rect.maxX, y: rect.minY)))
        currentPath.append(.lineTo(CGPoint(x: rect.maxX, y: rect.maxY)))
        currentPath.append(.lineTo(CGPoint(x: rect.minX, y: rect.maxY)))
        currentPath.append(.closePath)
        
        currentPoint = CGPoint(x: rect.minX, y: rect.minY)
    }
    
    func handleClosePath() {
        currentPath.append(.closePath)
        currentPoint = pathStartPoint
    }
}