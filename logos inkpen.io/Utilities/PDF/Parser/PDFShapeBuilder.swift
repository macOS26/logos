//
//  PDFShapeBuilder.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 9/1/25.
//  Extracted from PDFContent.swift - Shape creation and building functions
//

import Foundation
import CoreGraphics

// MARK: - PDF Shape Builder Extension
extension PDFCommandParser {
    
    // MARK: - Fill and Stroke Handlers
    
    func handleFill() {
        print("PDF: Fill operation - creating filled shape")
        
        if isInCompoundPath && !compoundPathParts.isEmpty {
            print("PDF: 🔍 COMPOUND PATH FILL - Creating compound shape from \(compoundPathParts.count + 1) parts")
            createCompoundShapeFromParts(filled: true, stroked: false)
        } else {
            createShapeFromCurrentPath(filled: true, stroked: false)
        }
    }
    
    func handleStroke() {
        createShapeFromCurrentPath(filled: false, stroked: true)
    }
    
    func handleFillAndStroke() {
        createShapeFromCurrentPath(filled: true, stroked: true)
    }
    
    // MARK: - Shape Creation Methods
    
    func createCompoundShapeFromParts(filled: Bool, stroked: Bool) {
        // Add the current path as the final part
        var allParts = compoundPathParts
        if !currentPath.isEmpty {
            allParts.append(currentPath)
        }
        
        print("PDF: 🔧 Creating compound shape with \(allParts.count) subpaths")
        
        // Convert all parts to VectorPath elements
        var combinedElements: [PathElement] = []
        
        for (partIndex, part) in allParts.enumerated() {
            print("PDF: Processing compound part #\(partIndex + 1) with \(part.count) commands")
            
            for command in part {
                switch command {
                case .moveTo(let point):
                    let adjustedPoint = CGPoint(x: point.x, y: pageSize.height - point.y)
                    let vectorPoint = VectorPoint(adjustedPoint)
                    combinedElements.append(.move(to: vectorPoint))
                case .lineTo(let point):
                    let adjustedPoint = CGPoint(x: point.x, y: pageSize.height - point.y)
                    let vectorPoint = VectorPoint(adjustedPoint)
                    combinedElements.append(.line(to: vectorPoint))
                case .curveTo(let cp1, let cp2, let point):
                    let adjustedCP1 = CGPoint(x: cp1.x, y: pageSize.height - cp1.y)
                    let adjustedCP2 = CGPoint(x: cp2.x, y: pageSize.height - cp2.y)
                    let adjustedPoint = CGPoint(x: point.x, y: pageSize.height - point.y)
                    let vectorCP1 = VectorPoint(adjustedCP1)
                    let vectorCP2 = VectorPoint(adjustedCP2)
                    let vectorPoint = VectorPoint(adjustedPoint)
                    combinedElements.append(.curve(to: vectorPoint, control1: vectorCP1, control2: vectorCP2))
                case .quadCurveTo(let cp, let point):
                    let adjustedCP = CGPoint(x: cp.x, y: pageSize.height - cp.y)
                    let adjustedPoint = CGPoint(x: point.x, y: pageSize.height - point.y)
                    let vectorCP = VectorPoint(adjustedCP)
                    let vectorPoint = VectorPoint(adjustedPoint)
                    combinedElements.append(.quadCurve(to: vectorPoint, control: vectorCP))
                case .rectangle(let rect):
                    // Convert rectangle to path elements
                    let adjustedRect = CGRect(x: rect.origin.x, y: pageSize.height - rect.origin.y - rect.height, width: rect.width, height: rect.height)
                    combinedElements.append(.move(to: VectorPoint(Double(adjustedRect.minX), Double(adjustedRect.minY))))
                    combinedElements.append(.line(to: VectorPoint(Double(adjustedRect.maxX), Double(adjustedRect.minY))))
                    combinedElements.append(.line(to: VectorPoint(Double(adjustedRect.maxX), Double(adjustedRect.maxY))))
                    combinedElements.append(.line(to: VectorPoint(Double(adjustedRect.minX), Double(adjustedRect.maxY))))
                    combinedElements.append(.close)
                case .closePath:
                    combinedElements.append(.close)
                }
            }
        }
        
        let vectorPath = VectorPath(elements: combinedElements, isClosed: combinedElements.contains(.close))
        
        // Create fill and stroke styles
        var fillStyle: FillStyle? = nil
        var strokeStyle: StrokeStyle? = nil
        
        if filled {
            let shapeName = "PDF Compound Shape \(shapes.count + 1)"
            print("PDF: 🔍 Compound shape creation - filled=true, activeGradient=\(activeGradient != nil)")
            
            if let gradient = activeGradient {
                fillStyle = FillStyle(gradient: gradient)
                print("PDF: ✅ GRADIENT ASSIGNED TO COMPOUND SHAPE: '\(shapeName)' gets active gradient with \(allParts.count) subpaths")
            } else {
                let r = Double(currentFillColor.components?[0] ?? 0.0)
                let g = Double(currentFillColor.components?[1] ?? 0.0)
                let b = Double(currentFillColor.components?[2] ?? 1.0)
                
                let vectorColor = VectorColor.rgb(RGBColor(red: r, green: g, blue: b, alpha: 1.0))
                fillStyle = FillStyle(color: vectorColor, opacity: currentFillOpacity)
                print("PDF: 🎨 SOLID COLOR ASSIGNED TO COMPOUND SHAPE: '\(shapeName)' gets fill color RGB(\(r), \(g), \(b)) with opacity: \(currentFillOpacity)")
            }
        }
        
        if stroked {
            let r = Double(currentStrokeColor.components?[0] ?? 0.0)
            let g = Double(currentStrokeColor.components?[1] ?? 0.0)
            let b = Double(currentStrokeColor.components?[2] ?? 1.0)
            
            let vectorColor = VectorColor.rgb(RGBColor(red: r, green: g, blue: b, alpha: 1.0))
            strokeStyle = StrokeStyle(color: vectorColor, width: 1.0, placement: .center, opacity: currentStrokeOpacity)
        }
        
        let compoundShape = VectorShape(
            name: activeGradient != nil ? "PDF Compound Shape (Gradient)" : "PDF Compound Shape \(shapes.count + 1)",
            path: vectorPath,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle
        )
        
        shapes.append(compoundShape)
        
        // Reset compound path state
        compoundPathParts.removeAll()
        currentPath.removeAll()
        isInCompoundPath = false
        moveToCount = 0
        
        // Clear the active gradient since it's been applied
        activeGradient = nil
        
        print("PDF: ✅ Compound shape created with \(allParts.count) subpaths")
    }
    
    func createShapeFromCurrentPath(filled: Bool, stroked: Bool) {
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
                // Transform coordinates: flip Y coordinate system
                let transformedPoint = VectorPoint(Double(point.x), Double(pageSize.height - point.y))
                vectorElements.append(.move(to: transformedPoint))
                
            case .lineTo(let point):
                let transformedPoint = VectorPoint(Double(point.x), Double(pageSize.height - point.y))
                vectorElements.append(.line(to: transformedPoint))
                
            case .curveTo(let cp1, let cp2, let to):
                let transformedCP1 = VectorPoint(Double(cp1.x), Double(pageSize.height - cp1.y))
                let transformedCP2 = VectorPoint(Double(cp2.x), Double(pageSize.height - cp2.y))
                let transformedTo = VectorPoint(Double(to.x), Double(pageSize.height - to.y))
                vectorElements.append(.curve(to: transformedTo, control1: transformedCP1, control2: transformedCP2))
                
            case .quadCurveTo(let cp, let to):
                let transformedCP = VectorPoint(Double(cp.x), Double(pageSize.height - cp.y))
                let transformedTo = VectorPoint(Double(to.x), Double(pageSize.height - to.y))
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
            let shapeName = "PDF Shape \(shapes.count + 1)"
            print("PDF: 🔍 OLD Shape creation - filled=true, activeGradient=\(activeGradient != nil), currentFillGradient=\(currentFillGradient != nil)")
            print("PDF: 🎨 OPACITY DEBUG - currentFillOpacity=\(currentFillOpacity), currentStrokeOpacity=\(currentStrokeOpacity)")
            // Check if this is a white shape first
            let r = Double(currentFillColor.components?[0] ?? 0.0)
            let g = Double(currentFillColor.components?[1] ?? 0.0) 
            let b = Double(currentFillColor.components?[2] ?? 1.0)
            let isWhiteShape = (r > 0.95 && g > 0.95 && b > 0.95) // Nearly white
            
            // IMPROVED GRADIENT LOGIC: Handle both compound paths and direct shape gradients
            if let gradient = activeGradient {
                // Check if this should be a compound path or direct gradient application
                if isWhiteShape && (isInCompoundPath || !compoundPathParts.isEmpty || gradientShapes.count > 0) {
                    // White shape + compound path context = track for compound path
                    gradientShapes.append(shapes.count) // Will be the index after we add this shape
                    fillStyle = FillStyle(gradient: gradient)
                    print("PDF: ✅ COMPOUND GRADIENT: '\(shapeName)' (WHITE) tracked for compound path")
                } else {
                    // Direct gradient application - regardless of color
                    fillStyle = FillStyle(gradient: gradient)
                    print("PDF: ✅ DIRECT GRADIENT: '\(shapeName)' gets gradient directly (not compound)")
                    // Note: Don't clear activeGradient here - will be cleared after shape creation
                }
            } else if let gradient = currentFillGradient {
                fillStyle = FillStyle(gradient: gradient)
                print("PDF: ✅ PATTERN GRADIENT: '\(shapeName)' gets pattern gradient fill")
            } else {
                print("PDF: 🎨 SOLID COLOR: '\(shapeName)' gets fill color RGB(\(r), \(g), \(b)) with separate opacity: \(currentFillOpacity)")
                let vectorColor = VectorColor.rgb(RGBColor(red: r, green: g, blue: b, alpha: 1.0))
                fillStyle = FillStyle(color: vectorColor, opacity: currentFillOpacity)
            }
        }
        
        if stroked {
            let r = Double(currentStrokeColor.components?[0] ?? 0.0)
            let g = Double(currentStrokeColor.components?[1] ?? 0.0)
            let b = Double(currentStrokeColor.components?[2] ?? 0.0)
            print("PDF: Applying stroke color RGB(\(r), \(g), \(b)) with separate opacity: \(currentStrokeOpacity)")
            
            let vectorColor = VectorColor.rgb(RGBColor(red: r, green: g, blue: b, alpha: 1.0))
            strokeStyle = StrokeStyle(color: vectorColor, width: 1.0, placement: .center, opacity: currentStrokeOpacity)
        }
        
        // If no explicit fill or stroke, skip creating the shape - it's likely a construction path
        if fillStyle == nil && strokeStyle == nil {
            print("PDF: No fill or stroke specified - skipping invisible construction path")
            currentPath.removeAll()
            return
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