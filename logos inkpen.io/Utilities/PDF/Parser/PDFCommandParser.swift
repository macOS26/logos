//
//  PDFCommandParser.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation
import SwiftUI
import CoreGraphics
import PDFKit

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
        
        // Final gradient processing (handled by specialized gradient modules)
        print("PDF: 🔍 Final check - activeGradient: \(activeGradient != nil), gradientShapes count: \(gradientShapes.count)")
        // TODO: Implement createCompoundPathWithGradient in gradient handling module
        if activeGradient != nil || !gradientShapes.isEmpty {
            print("PDF: 📋 Final gradient processing would occur here")
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
    
    // MARK: - Legacy operator callback setup (replaced by PDFOperatorInterpreter)
    
    // MARK: - Utility Methods
    
    func calculateArtworkBounds() -> CGRect {
        // Delegate to the dedicated geometry module
        return PDFBoundsCalculator.calculateArtworkBounds(from: shapes, pageSize: pageSize)
    }
    
    // MARK: - Operator Handlers (Moved to PDFOperatorHandlers.swift)
    
    // MARK: - Quadratic Curve Detection (Moved to PDFCurveOptimizer module)
    
    // MARK: - Color Handlers (Moved to PDFColorHandlers.swift)
    
    // MARK: - Opacity/Transparency Handlers (Moved to PDFTransparencyHandlers.swift)
    
}

