//
//  PDFContent+PathBuilder.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import Foundation
import SwiftUI
import CoreGraphics
import PDFKit



// MARK: - CoreGraphics Path Builder
class PathBuilder {
    var path = CGMutablePath()
    
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

func convertCGPathToVectorPath(_ cgPath: CGPath) -> VectorPath {
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

