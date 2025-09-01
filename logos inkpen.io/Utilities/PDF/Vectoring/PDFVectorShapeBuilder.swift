//
//  PDFVectorShapeBuilder.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import Foundation
import SwiftUI
import CoreGraphics

// MARK: - Vector Shape Creation from PDF Path Commands

/// Builds vector shapes from PDF path commands
class PDFVectorShapeBuilder {
    private let geometryTransformer: PDFGeometryTransformer
    
    init(pageSize: CGSize) {
        self.geometryTransformer = PDFGeometryTransformer(pageSize: pageSize)
    }
    
    /// Convert a series of path commands to vector path elements
    func buildVectorPath(from commands: [PathCommand]) -> VectorPath {
        var vectorElements: [PathElement] = []
        
        for command in commands {
            switch command {
            case .moveTo(let point):
                let transformedPoint = geometryTransformer.transformPoint(point)
                vectorElements.append(.move(to: transformedPoint))
                
            case .lineTo(let point):
                let transformedPoint = geometryTransformer.transformPoint(point)
                vectorElements.append(.line(to: transformedPoint))
                
            case .curveTo(let cp1, let cp2, let to):
                let transformedCP1 = geometryTransformer.transformPoint(cp1)
                let transformedCP2 = geometryTransformer.transformPoint(cp2)
                let transformedTo = geometryTransformer.transformPoint(to)
                vectorElements.append(.curve(
                    to: transformedTo,
                    control1: transformedCP1,
                    control2: transformedCP2
                ))
                
            case .quadCurveTo(let cp, let to):
                let transformedCP = geometryTransformer.transformPoint(cp)
                let transformedTo = geometryTransformer.transformPoint(to)
                vectorElements.append(.quadCurve(
                    to: transformedTo,
                    control: transformedCP
                ))
                
            case .closePath:
                vectorElements.append(.close)
                
            case .rectangle(let rect):
                let transformedRect = geometryTransformer.transformRect(rect)
                let minX = transformedRect.minX
                let minY = transformedRect.minY
                let maxX = transformedRect.maxX
                let maxY = transformedRect.maxY
                
                vectorElements.append(.move(to: VectorPoint(Double(minX), Double(minY))))
                vectorElements.append(.line(to: VectorPoint(Double(maxX), Double(minY))))
                vectorElements.append(.line(to: VectorPoint(Double(maxX), Double(maxY))))
                vectorElements.append(.line(to: VectorPoint(Double(minX), Double(maxY))))
                vectorElements.append(.close)
            }
        }
        
        let isClosed = commands.contains { command in
            if case .closePath = command { return true }
            return false
        }
        return VectorPath(elements: vectorElements, isClosed: isClosed)
    }
    
    /// Create a vector shape from path commands and styling information
    func createVectorShape(
        from commands: [PathCommand],
        name: String,
        fillColor: CGColor?,
        fillOpacity: Double,
        fillGradient: VectorGradient?,
        strokeColor: CGColor?,
        strokeOpacity: Double,
        strokeGradient: VectorGradient?
    ) -> VectorShape? {
        
        guard !commands.isEmpty else { return nil }
        
        let vectorPath = buildVectorPath(from: commands)
        
        // Create fill style
        var fillStyle: FillStyle? = nil
        if let gradient = fillGradient {
            fillStyle = FillStyle(gradient: gradient)
        } else if let color = fillColor {
            let r = Double(color.components?[0] ?? 0.0)
            let g = Double(color.components?[1] ?? 0.0)
            let b = Double(color.components?[2] ?? 1.0)
            let vectorColor = VectorColor.rgb(RGBColor(red: r, green: g, blue: b, alpha: 1.0))
            fillStyle = FillStyle(color: vectorColor, opacity: fillOpacity)
        }
        
        // Create stroke style
        var strokeStyle: StrokeStyle? = nil
        if strokeGradient != nil {
            // Stroke gradients need special handling - for now use solid color fallback
            if let color = strokeColor {
                let r = Double(color.components?[0] ?? 0.0)
                let g = Double(color.components?[1] ?? 0.0)
                let b = Double(color.components?[2] ?? 0.0)
                let vectorColor = VectorColor.rgb(RGBColor(red: r, green: g, blue: b, alpha: 1.0))
                strokeStyle = StrokeStyle(color: vectorColor, width: 1.0, placement: .center, opacity: strokeOpacity)
            }
        } else if let color = strokeColor {
            let r = Double(color.components?[0] ?? 0.0)
            let g = Double(color.components?[1] ?? 0.0)
            let b = Double(color.components?[2] ?? 0.0)
            let vectorColor = VectorColor.rgb(RGBColor(red: r, green: g, blue: b, alpha: 1.0))
            strokeStyle = StrokeStyle(color: vectorColor, width: 1.0, placement: .center, opacity: strokeOpacity)
        }
        
        // Ensure at least one style exists
        if fillStyle == nil && strokeStyle == nil {
            let defaultColor = VectorColor.rgb(RGBColor(red: 0.0, green: 0.7, blue: 1.0, alpha: 1.0))
            fillStyle = FillStyle(color: defaultColor)
        }
        
        return VectorShape(
            name: name,
            path: vectorPath,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle
        )
    }
    
    /// Create compound vector shape from multiple path arrays
    func createCompoundVectorShape(
        from pathParts: [[PathCommand]],
        name: String,
        fillColor: CGColor?,
        fillOpacity: Double,
        fillGradient: VectorGradient?,
        strokeColor: CGColor?,
        strokeOpacity: Double,
        strokeGradient: VectorGradient?
    ) -> VectorShape? {
        
        guard !pathParts.isEmpty else { return nil }
        
        // Combine all path elements into one compound path
        var allElements: [PathElement] = []
        
        for pathPart in pathParts {
            let partPath = buildVectorPath(from: pathPart)
            allElements.append(contentsOf: partPath.elements)
        }
        
        let compoundPath = VectorPath(elements: allElements, isClosed: false, fillRule: .evenOdd)
        
        // Create fill style
        var fillStyle: FillStyle? = nil
        if let gradient = fillGradient {
            fillStyle = FillStyle(gradient: gradient)
        } else if let color = fillColor {
            let r = Double(color.components?[0] ?? 0.0)
            let g = Double(color.components?[1] ?? 0.0)
            let b = Double(color.components?[2] ?? 1.0)
            let vectorColor = VectorColor.rgb(RGBColor(red: r, green: g, blue: b, alpha: 1.0))
            fillStyle = FillStyle(color: vectorColor, opacity: fillOpacity)
        }
        
        // Create stroke style
        var strokeStyle: StrokeStyle? = nil
        if let color = strokeColor {
            let r = Double(color.components?[0] ?? 0.0)
            let g = Double(color.components?[1] ?? 0.0)
            let b = Double(color.components?[2] ?? 0.0)
            let vectorColor = VectorColor.rgb(RGBColor(red: r, green: g, blue: b, alpha: 1.0))
            strokeStyle = StrokeStyle(color: vectorColor, width: 1.0, placement: .center, opacity: strokeOpacity)
        }
        
        return VectorShape(
            name: name,
            path: compoundPath,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle
        )
    }
}

/// Utilities for curve optimization and path simplification
struct PDFCurveOptimizer {
    
    /// Check if a cubic curve can be represented as a quadratic curve
    static func convertToQuadCurve(
        from start: CGPoint,
        cp1: CGPoint,
        cp2: CGPoint,
        to end: CGPoint
    ) -> PathCommand? {
        
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
}