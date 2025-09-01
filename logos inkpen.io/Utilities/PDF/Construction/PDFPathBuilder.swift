//
//  PDFPathBuilder.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import Foundation
import SwiftUI
import CoreGraphics

// MARK: - Path Construction for Rendering Pipeline

/// Manages path construction and building for the rendering pipeline
class PDFPathBuilder {
    
    // MARK: - Path State
    
    /// Current path commands being built
    private(set) var currentPath: [PathCommand] = []
    
    /// Current drawing point
    private(set) var currentPoint = CGPoint.zero
    
    /// Path starting point for close operations
    private(set) var pathStartPoint = CGPoint.zero
    
    /// Page size for boundary detection
    private let pageSize: CGSize
    
    // MARK: - Compound Path Detection
    
    /// Whether we're building a compound path (multiple MoveTo before fill)
    private(set) var isInCompoundPath = false
    
    /// Individual path parts for compound paths
    private(set) var compoundPathParts: [[PathCommand]] = []
    
    /// Count of MoveTo operations to detect compound paths
    private var moveToCount = 0
    
    init(pageSize: CGSize) {
        self.pageSize = pageSize
    }
    
    // MARK: - Path Building Operations
    
    /// Add MoveTo command to current path
    func addMoveTo(to point: CGPoint) {
        // COMPOUND PATH DETECTION: Multiple MoveTo operations = compound path
        if !currentPath.isEmpty {
            print("PDF: COMPOUND PATH DETECTED - MoveTo with existing path")
            compoundPathParts.append(currentPath)
            isInCompoundPath = true
            moveToCount += 1
            currentPath.removeAll()
            print("PDF: Compound path part #\(compoundPathParts.count) stored")
        } else {
            moveToCount = 1
            if !isInCompoundPath {
                compoundPathParts.removeAll()
            }
        }
        
        currentPoint = point
        pathStartPoint = point
        currentPath.append(.moveTo(point))
        print("PDF: MoveTo(\(point.x), \(point.y))")
    }
    
    /// Add LineTo command to current path
    func addLineTo(to point: CGPoint) {
        currentPoint = point
        currentPath.append(.lineTo(point))
        print("PDF: LineTo(\(point.x), \(point.y))")
    }
    
    /// Add cubic curve command with optimization to quadratic if possible
    func addCurveTo(cp1: CGPoint, cp2: CGPoint, to point: CGPoint) {
        currentPoint = point
        
        // Attempt optimization to quadratic curve using vectoring module
        if let quadCommand = PDFCurveOptimizer.convertToQuadCurve(
            from: pathStartPoint, // Use path start as reference
            cp1: cp1, 
            cp2: cp2, 
            to: point
        ) {
            currentPath.append(quadCommand)
            print("PDF: Optimized cubic to quadratic curve")
        } else {
            currentPath.append(.curveTo(cp1: cp1, cp2: cp2, to: point))
            print("PDF: CurveTo(\(cp1), \(cp2), \(point))")
        }
    }
    
    /// Add quadratic curve command
    func addQuadCurveTo(cp: CGPoint, to point: CGPoint) {
        currentPoint = point
        currentPath.append(.quadCurveTo(cp: cp, to: point))
        print("PDF: QuadCurveTo(\(cp), \(point))")
    }
    
    /// Add close path command
    func addClosePath() {
        currentPath.append(.closePath)
        currentPoint = pathStartPoint
        print("PDF: ClosePath")
    }
    
    /// Add rectangle with page boundary filtering
    func addRectangle(_ rect: CGRect) -> Bool {
        // Use geometry module to filter page boundaries
        if PDFBoundsCalculator.isPageBoundaryRectangle(rect, pageSize: pageSize) {
            print("PDF: Filtered page boundary rectangle (\(rect.width) x \(rect.height))")
            return false
        }
        
        // Convert rectangle to path commands
        let startPoint = rect.origin
        let topRight = CGPoint(x: rect.maxX, y: rect.minY)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)
        let bottomLeft = CGPoint(x: rect.minX, y: rect.maxY)
        
        currentPath.append(.moveTo(startPoint))
        currentPath.append(.lineTo(topRight))
        currentPath.append(.lineTo(bottomRight))
        currentPath.append(.lineTo(bottomLeft))
        currentPath.append(.closePath)
        
        currentPoint = startPoint
        pathStartPoint = startPoint
        
        print("PDF: Rectangle(\(rect))")
        return true
    }
    
    // MARK: - Path State Management
    
    /// Check if current path has content
    var hasCurrentPath: Bool {
        return !currentPath.isEmpty
    }
    
    /// Check if building compound paths
    var hasCompoundPaths: Bool {
        return !compoundPathParts.isEmpty
    }
    
    /// Get current path for shape creation
    func getCurrentPath() -> [PathCommand] {
        return currentPath
    }
    
    /// Get all compound path parts including current path
    func getAllCompoundParts() -> [[PathCommand]] {
        var allParts = compoundPathParts
        if !currentPath.isEmpty {
            allParts.append(currentPath)
        }
        return allParts
    }
    
    /// Clear current path after shape creation
    func clearCurrentPath() {
        currentPath.removeAll()
        print("PDF: Path cleared")
    }
    
    /// Reset compound path state
    func resetCompoundPath() {
        compoundPathParts.removeAll()
        isInCompoundPath = false
        moveToCount = 0
        print("PDF: Compound path state reset")
    }
    
    /// Clear all path state
    func clearAllPaths() {
        clearCurrentPath()
        resetCompoundPath()
    }
}

// MARK: - Path Construction Operations Handler

/// Handles path construction PDF operations for the rendering pipeline
struct PDFPathConstructionOperations {
    
    /// Handle MoveTo operation (m operator)
    static func handleMoveTo(scanner: CGPDFScannerRef, pathBuilder: PDFPathBuilder) {
        var x: CGFloat = 0, y: CGFloat = 0
        
        guard CGPDFScannerPopNumber(scanner, &y),
              CGPDFScannerPopNumber(scanner, &x) else { return }
        
        let point = CGPoint(x: x, y: y)
        pathBuilder.addMoveTo(to: point)
    }
    
    /// Handle LineTo operation (l operator)
    static func handleLineTo(scanner: CGPDFScannerRef, pathBuilder: PDFPathBuilder) {
        var x: CGFloat = 0, y: CGFloat = 0
        
        guard CGPDFScannerPopNumber(scanner, &y),
              CGPDFScannerPopNumber(scanner, &x) else { return }
        
        let point = CGPoint(x: x, y: y)
        pathBuilder.addLineTo(to: point)
    }
    
    /// Handle cubic curve operation (c operator)
    static func handleCurveTo(scanner: CGPDFScannerRef, pathBuilder: PDFPathBuilder) {
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
        
        pathBuilder.addCurveTo(cp1: cp1, cp2: cp2, to: endPoint)
    }
    
    /// Handle curve variant V operation (v operator - current point is first control point)
    static func handleCurveToV(scanner: CGPDFScannerRef, pathBuilder: PDFPathBuilder) {
        var x2: CGFloat = 0, y2: CGFloat = 0  // Second control point
        var x3: CGFloat = 0, y3: CGFloat = 0  // End point
        
        guard CGPDFScannerPopNumber(scanner, &y3),
              CGPDFScannerPopNumber(scanner, &x3),
              CGPDFScannerPopNumber(scanner, &y2),
              CGPDFScannerPopNumber(scanner, &x2) else { return }
        
        let cp1 = pathBuilder.currentPoint  // Current point is first control point
        let cp2 = CGPoint(x: x2, y: y2)
        let endPoint = CGPoint(x: x3, y: y3)
        
        pathBuilder.addCurveTo(cp1: cp1, cp2: cp2, to: endPoint)
    }
    
    /// Handle curve variant Y operation (y operator - end point is second control point)
    static func handleCurveToY(scanner: CGPDFScannerRef, pathBuilder: PDFPathBuilder) {
        var x1: CGFloat = 0, y1: CGFloat = 0  // First control point
        var x3: CGFloat = 0, y3: CGFloat = 0  // End point (also second control point)
        
        guard CGPDFScannerPopNumber(scanner, &y3),
              CGPDFScannerPopNumber(scanner, &x3),
              CGPDFScannerPopNumber(scanner, &y1),
              CGPDFScannerPopNumber(scanner, &x1) else { return }
        
        let cp1 = CGPoint(x: x1, y: y1)
        let endPoint = CGPoint(x: x3, y: y3)
        let cp2 = endPoint  // End point is also second control point
        
        pathBuilder.addCurveTo(cp1: cp1, cp2: cp2, to: endPoint)
    }
    
    /// Handle close path operation (h operator)
    static func handleClosePath(pathBuilder: PDFPathBuilder) {
        pathBuilder.addClosePath()
    }
    
    /// Handle rectangle operation (re operator)
    static func handleRectangle(scanner: CGPDFScannerRef, pathBuilder: PDFPathBuilder) {
        var x: CGFloat = 0, y: CGFloat = 0, width: CGFloat = 0, height: CGFloat = 0
        
        guard CGPDFScannerPopNumber(scanner, &height),
              CGPDFScannerPopNumber(scanner, &width),
              CGPDFScannerPopNumber(scanner, &y),
              CGPDFScannerPopNumber(scanner, &x) else { return }
        
        let rect = CGRect(x: x, y: y, width: width, height: height)
        _ = pathBuilder.addRectangle(rect)
    }
}