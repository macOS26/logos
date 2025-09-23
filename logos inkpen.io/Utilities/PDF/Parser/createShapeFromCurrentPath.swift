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
                // IMPROVED: Apply same smart gradient detection logic
                let r = Double(currentFillColor.components?[0] ?? 0.0)
                let g = Double(currentFillColor.components?[1] ?? 0.0)
                let b = Double(currentFillColor.components?[2] ?? 1.0)
                let isWhiteShape = (r > 0.95 && g > 0.95 && b > 0.95)
                
                if isWhiteShape && (isInCompoundPath || !compoundPathParts.isEmpty || gradientShapes.count > 0) {
                    // White shape + compound context = track for compound path
                    gradientShapes.append(shapes.count) // Will be the index after we add this shape
                    fillStyle = FillStyle(gradient: gradient)
                    print("PDF: ✅ COMPOUND GRADIENT: '\(shapeName)' (WHITE) tracked for compound path")
                } else {
                    // Direct gradient application
                    fillStyle = FillStyle(gradient: gradient)
                    print("PDF: ✅ DIRECT GRADIENT: '\(shapeName)' gets gradient directly (not compound)")
                    // Note: Don't clear activeGradient here - will be cleared after shape creation
                }
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
        
        // Clear activeGradient if it was used for direct application (not compound)
        if activeGradient != nil && gradientShapes.isEmpty {
            activeGradient = nil
            print("PDF: 🔄 Cleared activeGradient after direct application")
        }
        
        currentPath.removeAll()
    }
}
