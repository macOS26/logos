//
//  File.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import SwiftUI

extension PDFCommandParser {
    
    // Modified createShapeFromCurrentPath to accept custom fill style
    func createShapeFromCurrentPath(filled: Bool, stroked: Bool, customFillStyle: FillStyle? = nil) {
        guard !currentPath.isEmpty else {
            return
        }
        
        
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
            // Priority order: custom fill style, active gradient, current fill color
            if let custom = customFillStyle {
                fillStyle = custom
            } else if let gradient = activeGradient {
                // IMPROVED: Apply same smart gradient detection logic
                let r = Double(currentFillColor.components?[0] ?? 0.0)
                let g = Double(currentFillColor.components?[1] ?? 0.0)
                let b = Double(currentFillColor.components?[2] ?? 1.0)
                let isWhiteShape = (r > 0.95 && g > 0.95 && b > 0.95)
                
                if isWhiteShape && (isInCompoundPath || !compoundPathParts.isEmpty || gradientShapes.count > 0) {
                    // White shape + compound context = track for compound path
                    gradientShapes.append(shapes.count) // Will be the index after we add this shape
                    fillStyle = FillStyle(gradient: gradient)
                } else {
                    // Direct gradient application
                    fillStyle = FillStyle(gradient: gradient)
                    // Note: Don't clear activeGradient here - will be cleared after shape creation
                }
            } else {
                let r = Double(currentFillColor.components?[0] ?? 0.0)
                let g = Double(currentFillColor.components?[1] ?? 0.0)
                let b = Double(currentFillColor.components?[2] ?? 1.0)
                let a = Double(currentFillColor.components?[3] ?? 1.0)
                
                let vectorColor = VectorColor.rgb(RGBColor(red: r, green: g, blue: b, alpha: a))
                fillStyle = FillStyle(color: vectorColor)
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
        
        // Check if this is a gradient shape that should be marked as compound path
        let isGradientShape = fillStyle?.isGradient ?? false

        if isGradientShape {
        }

        let shape = VectorShape(
            name: "PDF Shape \(shapes.count + 1)",
            path: vectorPath,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle,
            isCompoundPath: isGradientShape  // Mark gradient shapes as compound paths for editor compatibility
        )

        shapes.append(shape)
        
        // Clear activeGradient if it was used for direct application (not compound)
        if activeGradient != nil && gradientShapes.isEmpty {
            activeGradient = nil
        }
        
        currentPath.removeAll()
    }
}
