//
//  createShapeFromShading.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import Foundation
import SwiftUI
import CoreGraphics

extension PDFCommandParser {
    
    func createShapeFromShading(gradient: VectorGradient) {
        // For standalone shadings, we need to create a shape that covers the entire page
        // or the current clipping area. This is common for background gradients.
        
        print("PDF: 📐 Creating standalone shading shape covering page bounds")
        
        // Create a rectangle covering the entire page
        let pageRect = [
            PathCommand.moveTo(CGPoint(x: 0, y: 0)),
            PathCommand.lineTo(CGPoint(x: pageSize.width, y: 0)),
            PathCommand.lineTo(CGPoint(x: pageSize.width, y: pageSize.height)),
            PathCommand.lineTo(CGPoint(x: 0, y: pageSize.height)),
            PathCommand.closePath
        ]
        
        // Convert to VectorPath elements
        var vectorElements: [PathElement] = []
        for command in pageRect {
            switch command {
            case .moveTo(let point):
                let transformedPoint = VectorPoint(Double(point.x), Double(pageSize.height - point.y))
                vectorElements.append(.move(to: transformedPoint))
            case .lineTo(let point):
                let transformedPoint = VectorPoint(Double(point.x), Double(pageSize.height - point.y))
                vectorElements.append(.line(to: transformedPoint))
            case .closePath:
                vectorElements.append(.close)
            default:
                break
            }
        }
        
        let vectorPath = VectorPath(elements: vectorElements, isClosed: true)
        let fillStyle = FillStyle(gradient: gradient)
        
        let shadingShape = VectorShape(
            name: "PDF Shading Shape \(shapes.count + 1)",
            path: vectorPath,
            strokeStyle: nil,
            fillStyle: fillStyle
        )
        
        shapes.append(shadingShape)
        print("PDF: ✅ Created standalone shading shape")
    }
}