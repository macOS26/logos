//
//  PDFShapeBuilder.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 9/1/25.
//  Extracted from PDFContent.swift - Shape creation and building functions
//

import SwiftUI

// MARK: - PDF Shape Builder Extension
extension PDFCommandParser {
    
    // MARK: - Fill and Stroke Handlers
    
    func handleFill() {
        // Log.info("PDF: Fill operation - creating filled shape", category: .general)

        // Check if we already processed this as a gradient
        if !isInCompoundPath && currentPath.isEmpty && compoundPathParts.isEmpty {
            // Log.info("PDF: 🚫 Skipping fill - no paths to process (likely already handled by gradient)", category: .general)
            return
        }

        // Check if this is a black background shape for a transparent image
        if shouldSkipBlackBackground() {
            // Log.info("PDF: Skipping black background shape for transparent image", category: .general)
            currentPath.removeAll()
            return
        }

        if isInCompoundPath && !compoundPathParts.isEmpty {
            // Log.info("PDF: 🔍 COMPOUND PATH FILL - Creating compound shape from \(compoundPathParts.count + 1) parts", category: .debug)
            createCompoundShapeFromParts(filled: true, stroked: false)
            // CRITICAL: Return here to prevent creating individual shapes for compound path parts
            return
        }

        // Only create individual shape if NOT in a compound path
        if !isInCompoundPath {
            createShapeFromCurrentPath(filled: true, stroked: false)
        } else {
            // We're in a compound path but haven't collected all parts yet
            // Just store the current path as a part
            if !currentPath.isEmpty {
                compoundPathParts.append(currentPath)
                currentPath.removeAll()
            }
        }
    }

    /// Check if the current shape is a black background that should be skipped
    func shouldSkipBlackBackground() -> Bool {
        // Check if we have a transparent image bounds to compare against
        guard let imageBounds = transparentImageBounds else { return false }

        // Check if current fill color is black
        let r = Double(currentFillColor.components?[0] ?? 0.0)
        let g = Double(currentFillColor.components?[1] ?? 0.0)
        let b = Double(currentFillColor.components?[2] ?? 0.0)
        let isBlack = (r < 0.1 && g < 0.1 && b < 0.1)

        if !isBlack { return false }

        // Check if the current path is a rectangle that matches or contains the image bounds
        for command in currentPath {
            if case .rectangle(let rect) = command {
                // Check if this rectangle contains or matches the transparent image bounds
                if rect.contains(imageBounds) || rect.equalTo(imageBounds) {
                    // Log.info("PDF: Found black rectangle matching transparent image bounds", category: .general)
                    return true
                }
            }
        }

        // Also check if it's a constructed rectangle from moves and lines
        if currentPath.count >= 4 {
            // Try to extract bounds from the path
            var minX = CGFloat.greatestFiniteMagnitude
            var minY = CGFloat.greatestFiniteMagnitude
            var maxX = -CGFloat.greatestFiniteMagnitude
            var maxY = -CGFloat.greatestFiniteMagnitude

            for command in currentPath {
                switch command {
                case .moveTo(let pt), .lineTo(let pt):
                    minX = min(minX, pt.x)
                    minY = min(minY, pt.y)
                    maxX = max(maxX, pt.x)
                    maxY = max(maxY, pt.y)
                default:
                    break
                }
            }

            let pathBounds = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            if pathBounds.contains(imageBounds) || pathBounds.equalTo(imageBounds) {
                // Log.info("PDF: Found black path matching transparent image bounds", category: .general)
                return true
            }
        }

        return false
    }
    
    func handleStroke() {
        // Check if we can merge this stroke with the last shape if it was just filled
        // This handles the case where PDFs have separate fill and stroke operations for the same path
        if let lastShapeIndex = shapes.indices.last {
            let lastShape = shapes[lastShapeIndex]
            if lastShape.fillStyle != nil && lastShape.strokeStyle == nil && !currentPath.isEmpty {
                // Check if the path is similar (might be transformed)
                // For now, just check if it's the same number of path commands
                let lastPathElementCount = lastShape.path.elements.count
                let currentPathCommandCount = currentPath.count

                // If paths are similar, add stroke to the existing shape
                if abs(lastPathElementCount - currentPathCommandCount) <= 1 {
                    // Log.info("PDF: Merging stroke with previous filled shape", category: .general)

                    // Create stroke style using CGColor
                    let r = Double(currentStrokeColor.components?[0] ?? 0.0)
                    let g = Double(currentStrokeColor.components?[1] ?? 0.0)
                    let b = Double(currentStrokeColor.components?[2] ?? 0.0)

                    let strokeColor = VectorColor.rgb(RGBColor(red: r, green: g, blue: b, alpha: 1.0))
                    let strokeStyle = StrokeStyle(
                        color: strokeColor,
                        width: currentLineWidth,
                        placement: .center,
                        dashPattern: currentLineDashPattern,
                        lineCap: currentLineCap,
                        lineJoin: currentLineJoin,
                        miterLimit: currentMiterLimit,
                        opacity: currentStrokeOpacity
                    )

                    // Create new shape with both fill and stroke
                    let mergedShape = VectorShape(
                        name: lastShape.name,
                        path: lastShape.path,
                        strokeStyle: strokeStyle,
                        fillStyle: lastShape.fillStyle
                    )

                    // Replace the last shape with the merged one
                    shapes[lastShapeIndex] = mergedShape
                    currentPath.removeAll()
                    // Log.info("PDF: Successfully merged stroke with filled shape", category: .general)
                    return
                }
            }
        }

        // Otherwise create a new stroked shape
        createShapeFromCurrentPath(filled: false, stroked: true)
    }
    
    func handleFillAndStroke() {
        // Log.info("PDF: Fill and stroke operation (B operator) - creating single shape with both", category: .general)
        createShapeFromCurrentPath(filled: true, stroked: true)
    }
    
    // MARK: - Shape Creation Methods
    
    func createCompoundShapeFromParts(filled: Bool, stroked: Bool) {
        defer {
            // Reset compound path state at the end
            compoundPathParts.removeAll()
            currentPath.removeAll()
            isInCompoundPath = false
            moveToCount = 0

            // Clear the active gradient since it's been applied
            activeGradient = nil

            // Log.info("PDF: 🔄 Deferred cleanup of compound path state", category: .debug)
        }

        // Add the current path as the final part if not empty
        var allParts = compoundPathParts
        if !currentPath.isEmpty {
            allParts.append(currentPath)
        }

        // Handle gradients vs flat shapes differently
        if activeGradient != nil {
            // GRADIENT: Paths were accumulated, use as-is
            // Log.info("PDF: 🎨 GRADIENT compound shape - using accumulated paths", category: .general)
        } else {
            // FLAT SHAPES: Paths were accumulated but we need separate parts
            // Extract the unique portions of each part
            var separateParts: [[PathCommand]] = []
            var previousCommands: [PathCommand] = []

            for part in allParts {
                // Find commands that are NEW in this part
                var newCommands: [PathCommand] = []
                for command in part {
                    if !previousCommands.contains(where: { pathCommandEquals($0, command) }) {
                        newCommands.append(command)
                    }
                }

                if !newCommands.isEmpty {
                    separateParts.append(newCommands)
                    previousCommands = part // Update to full part for next iteration
                    // Log.info("PDF: 📝 Extracted \(newCommands.count) new commands from part with \(part.count) total", category: .debug)
                }
            }

            if !separateParts.isEmpty {
                allParts = separateParts
                // Log.info("PDF: ✂️ Separated accumulated paths into \(separateParts.count) distinct parts", category: .general)
            }
        }

        // Log.info("PDF: 🔧 Creating compound shape with \(allParts.count) unique subpaths (from \(compoundPathParts.count + (currentPath.isEmpty ? 0 : 1)) total)", category: .general)
        
        // Convert all parts to VectorPath elements
        var combinedElements: [PathElement] = []
        
        for (partIndex, part) in allParts.enumerated() {
            // Log.info("PDF: Processing compound part #\(partIndex + 1) with \(part.count) commands", category: .general)
            
            for command in part {
                switch command {
                case .moveTo(let point):
                    // Apply Y-flip for PDF coordinate system
                    let flippedY = pageSize.height - point.y
                    let vectorPoint = VectorPoint(Double(point.x), Double(flippedY))
                    combinedElements.append(.move(to: vectorPoint))
                case .lineTo(let point):
                    // Apply Y-flip for PDF coordinate system
                    let flippedY = pageSize.height - point.y
                    let vectorPoint = VectorPoint(Double(point.x), Double(flippedY))
                    combinedElements.append(.line(to: vectorPoint))
                case .curveTo(let cp1, let cp2, let point):
                    // Apply Y-flip for PDF coordinate system
                    let flippedCP1Y = pageSize.height - cp1.y
                    let flippedCP2Y = pageSize.height - cp2.y
                    let flippedY = pageSize.height - point.y
                    let vectorCP1 = VectorPoint(Double(cp1.x), Double(flippedCP1Y))
                    let vectorCP2 = VectorPoint(Double(cp2.x), Double(flippedCP2Y))
                    let vectorPoint = VectorPoint(Double(point.x), Double(flippedY))
                    combinedElements.append(.curve(to: vectorPoint, control1: vectorCP1, control2: vectorCP2))
                case .quadCurveTo(let cp, let point):
                    // Apply Y-flip for PDF coordinate system
                    let flippedCPY = pageSize.height - cp.y
                    let flippedY = pageSize.height - point.y
                    let vectorCP = VectorPoint(Double(cp.x), Double(flippedCPY))
                    let vectorPoint = VectorPoint(Double(point.x), Double(flippedY))
                    combinedElements.append(.quadCurve(to: vectorPoint, control: vectorCP))
                case .rectangle(let rect):
                    // Convert rectangle with Y-flip for PDF coordinate system
                    let flippedY = pageSize.height - rect.origin.y - rect.height
                    combinedElements.append(.move(to: VectorPoint(Double(rect.minX), Double(flippedY))))
                    combinedElements.append(.line(to: VectorPoint(Double(rect.maxX), Double(flippedY))))
                    combinedElements.append(.line(to: VectorPoint(Double(rect.maxX), Double(flippedY + rect.height))))
                    combinedElements.append(.line(to: VectorPoint(Double(rect.minX), Double(flippedY + rect.height))))
                    combinedElements.append(.close)
                case .closePath:
                    combinedElements.append(.close)
                }
            }
        }
        
        // Use even-odd fill rule for compound paths to properly create holes
        let vectorPath = VectorPath(elements: combinedElements, isClosed: combinedElements.contains(.close), fillRule: .evenOdd)
        
        // Create fill and stroke styles
        var fillStyle: FillStyle? = nil
        var strokeStyle: StrokeStyle? = nil
        
        if filled {
            let shapeName = "PDF Compound Shape \(shapes.count + 1)"
            // Log.info("PDF: 🔍 Compound shape creation - filled=true, activeGradient=\(activeGradient != nil)", category: .debug)
            
            if let gradient = activeGradient {
                fillStyle = FillStyle(gradient: gradient)
                // Log.info("PDF: ✅ GRADIENT ASSIGNED TO COMPOUND SHAPE: '\(shapeName)' gets active gradient with \(allParts.count) subpaths", category: .general)
            } else {
                let r = Double(currentFillColor.components?[0] ?? 0.0)
                let g = Double(currentFillColor.components?[1] ?? 0.0)
                let b = Double(currentFillColor.components?[2] ?? 1.0)
                
                let vectorColor = VectorColor.rgb(RGBColor(red: r, green: g, blue: b, alpha: 1.0))
                fillStyle = FillStyle(color: vectorColor, opacity: currentFillOpacity)
                // Log.info("PDF: 🎨 SOLID COLOR ASSIGNED TO COMPOUND SHAPE: '\(shapeName)' gets fill color RGB(\(r), \(g), \(b)) with opacity: \(currentFillOpacity)", category: .general)
            }
        }
        
        if stroked {
            let r = Double(currentStrokeColor.components?[0] ?? 0.0)
            let g = Double(currentStrokeColor.components?[1] ?? 0.0)
            let b = Double(currentStrokeColor.components?[2] ?? 1.0)

            let vectorColor = VectorColor.rgb(RGBColor(red: r, green: g, blue: b, alpha: 1.0))
            strokeStyle = StrokeStyle(
                color: vectorColor,
                width: currentLineWidth,
                placement: .center,
                dashPattern: currentLineDashPattern,
                lineCap: currentLineCap,
                lineJoin: currentLineJoin,
                miterLimit: currentMiterLimit,
                opacity: currentStrokeOpacity
            )
        }
        
        let compoundShape = VectorShape(
            name: activeGradient != nil ? "PDF Compound Shape (Gradient)" : "PDF Compound Shape \(shapes.count + 1)",
            path: vectorPath,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle,
            transform: .identity,
            isCompoundPath: true  // Mark as compound path for proper hole rendering
        )
        
        shapes.append(compoundShape)

        // Log.info("PDF: ✅ Compound shape created with \(allParts.count) subpaths", category: .general)
    }
    
    func createShapeFromCurrentPath(filled: Bool, stroked: Bool) {
        guard !currentPath.isEmpty else {
            // Log.info("PDF: Cannot create shape - current path is empty", category: .general)
            return
        }

        // Log.info("PDF: Creating shape with \(currentPath.count) path commands, filled: \(filled), stroked: \(stroked)", category: .general)

        // Convert to VectorPath elements with coordinate system fix
        var vectorElements: [PathElement] = []

        // Check if CTM already includes Y-flip (d component is negative)
        let ctmHasYFlip = currentTransformMatrix.d < 0
        // Log.info("PDF: CTM analysis - d=\(currentTransformMatrix.d), has Y-flip: \(ctmHasYFlip)", category: .general)

        // Apply Y-flip based on combination of fill/stroke and CTM state
        // Fill-only: always flip (PDF -> App conversion)
        // Fill+Stroke with CTM Y-flip: don't flip (already correct)
        // Stroke-only: don't flip (coordinates are already correct)
        let shouldApplyFlip = filled && !stroked  // Only flip for fill-only shapes
        // Log.info("PDF: Should apply Y-flip: \(shouldApplyFlip) (filled: \(filled), stroked: \(stroked), ctmHasYFlip: \(ctmHasYFlip))", category: .general)

        for command in currentPath {
            switch command {
            case .moveTo(let point):
                // Apply Y-flip based on shouldApplyFlip flag
                let transformedPoint: VectorPoint
                if shouldApplyFlip {
                    // Apply Y-flip for PDF->App coordinate conversion
                    transformedPoint = VectorPoint(Double(point.x), Double(pageSize.height - point.y))
                } else {
                    // Use coordinates as-is (already correct from CTM)
                    transformedPoint = VectorPoint(Double(point.x), Double(point.y))
                }
                vectorElements.append(.move(to: transformedPoint))

            case .lineTo(let point):
                // Apply Y-flip based on shouldApplyFlip flag
                let transformedPoint: VectorPoint
                if shouldApplyFlip {
                    // Apply Y-flip for PDF->App coordinate conversion
                    transformedPoint = VectorPoint(Double(point.x), Double(pageSize.height - point.y))
                } else {
                    // Use coordinates as-is (already correct from CTM)
                    transformedPoint = VectorPoint(Double(point.x), Double(point.y))
                }
                vectorElements.append(.line(to: transformedPoint))

            case .curveTo(let cp1, let cp2, let to):
                // Apply Y-flip based on shouldApplyFlip flag
                let transformedCP1: VectorPoint
                let transformedCP2: VectorPoint
                let transformedTo: VectorPoint
                if shouldApplyFlip {
                    // Apply Y-flip for PDF->App coordinate conversion
                    transformedCP1 = VectorPoint(Double(cp1.x), Double(pageSize.height - cp1.y))
                    transformedCP2 = VectorPoint(Double(cp2.x), Double(pageSize.height - cp2.y))
                    transformedTo = VectorPoint(Double(to.x), Double(pageSize.height - to.y))
                } else {
                    // Use coordinates as-is (already correct from CTM)
                    transformedCP1 = VectorPoint(Double(cp1.x), Double(cp1.y))
                    transformedCP2 = VectorPoint(Double(cp2.x), Double(cp2.y))
                    transformedTo = VectorPoint(Double(to.x), Double(to.y))
                }
                vectorElements.append(.curve(to: transformedTo, control1: transformedCP1, control2: transformedCP2))

            case .quadCurveTo(let cp, let to):
                // Apply Y-flip based on shouldApplyFlip flag
                let transformedCP: VectorPoint
                let transformedTo: VectorPoint
                if shouldApplyFlip {
                    // Apply Y-flip for PDF->App coordinate conversion
                    transformedCP = VectorPoint(Double(cp.x), Double(pageSize.height - cp.y))
                    transformedTo = VectorPoint(Double(to.x), Double(pageSize.height - to.y))
                } else {
                    // Use coordinates as-is (already correct from CTM)
                    transformedCP = VectorPoint(Double(cp.x), Double(cp.y))
                    transformedTo = VectorPoint(Double(to.x), Double(to.y))
                }
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
            // Log.info("PDF: 🔍 OLD Shape creation - filled=true, activeGradient=\(activeGradient != nil), currentFillGradient=\(currentFillGradient != nil)", category: .debug)
            // Log.info("PDF: 🎨 OPACITY DEBUG - currentFillOpacity=\(currentFillOpacity), currentStrokeOpacity=\(currentStrokeOpacity)", category: .debug)
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
                    // Log.info("PDF: ✅ COMPOUND GRADIENT: '\(shapeName)' (WHITE) tracked for compound path", category: .general)
                } else {
                    // Direct gradient application - regardless of color
                    fillStyle = FillStyle(gradient: gradient)
                    // Log.info("PDF: ✅ DIRECT GRADIENT: '\(shapeName)' gets gradient directly (not compound)", category: .general)
                    // Note: Don't clear activeGradient here - will be cleared after shape creation
                }
            } else if let gradient = currentFillGradient {
                fillStyle = FillStyle(gradient: gradient)
                // Log.info("PDF: ✅ PATTERN GRADIENT: '\(shapeName)' gets pattern gradient fill", category: .general)
            } else {
                // Log.info("PDF: 🎨 SOLID COLOR: '\(shapeName)' gets fill color RGB(\(r), \(g), \(b)) with separate opacity: \(currentFillOpacity)", category: .general)
                let vectorColor = VectorColor.rgb(RGBColor(red: r, green: g, blue: b, alpha: 1.0))
                fillStyle = FillStyle(color: vectorColor, opacity: currentFillOpacity)
            }
        }
        
        if stroked {
            let r = Double(currentStrokeColor.components?[0] ?? 0.0)
            let g = Double(currentStrokeColor.components?[1] ?? 0.0)
            let b = Double(currentStrokeColor.components?[2] ?? 0.0)
            // Log.info("PDF: Applying stroke color RGB(\(r), \(g), \(b)) with width: \(currentLineWidth), opacity: \(currentStrokeOpacity)", category: .general)

            let vectorColor = VectorColor.rgb(RGBColor(red: r, green: g, blue: b, alpha: 1.0))
            strokeStyle = StrokeStyle(
                color: vectorColor,
                width: currentLineWidth,
                placement: .center,
                dashPattern: currentLineDashPattern,
                lineCap: currentLineCap,
                lineJoin: currentLineJoin,
                miterLimit: currentMiterLimit,
                opacity: currentStrokeOpacity
            )
        }
        
        // If no explicit fill or stroke, skip creating the shape - it's likely a construction path
        if fillStyle == nil && strokeStyle == nil {
            // Log.info("PDF: No fill or stroke specified - skipping invisible construction path", category: .general)
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
            // Log.info("PDF: 🔄 Cleared activeGradient after direct application", category: .general)
        }
        
        currentPath.removeAll()
    }

    // Helper function to compare individual path commands
    private func pathCommandEquals(_ cmd1: PathCommand, _ cmd2: PathCommand) -> Bool {
        let tolerance: CGFloat = 0.01

        switch (cmd1, cmd2) {
        case (.moveTo(let p1), .moveTo(let p2)):
            return abs(p1.x - p2.x) < tolerance && abs(p1.y - p2.y) < tolerance
        case (.lineTo(let p1), .lineTo(let p2)):
            return abs(p1.x - p2.x) < tolerance && abs(p1.y - p2.y) < tolerance
        case (.curveTo(let cp1_1, let cp2_1, let to1), .curveTo(let cp1_2, let cp2_2, let to2)):
            return abs(cp1_1.x - cp1_2.x) < tolerance && abs(cp1_1.y - cp1_2.y) < tolerance &&
                   abs(cp2_1.x - cp2_2.x) < tolerance && abs(cp2_1.y - cp2_2.y) < tolerance &&
                   abs(to1.x - to2.x) < tolerance && abs(to1.y - to2.y) < tolerance
        case (.quadCurveTo(let cp1, let to1), .quadCurveTo(let cp2, let to2)):
            return abs(cp1.x - cp2.x) < tolerance && abs(cp1.y - cp2.y) < tolerance &&
                   abs(to1.x - to2.x) < tolerance && abs(to1.y - to2.y) < tolerance
        case (.closePath, .closePath):
            return true
        case (.rectangle(let r1), .rectangle(let r2)):
            return abs(r1.origin.x - r2.origin.x) < tolerance &&
                   abs(r1.origin.y - r2.origin.y) < tolerance &&
                   abs(r1.size.width - r2.size.width) < tolerance &&
                   abs(r1.size.height - r2.size.height) < tolerance
        default:
            return false
        }
    }

    // Helper function to compare path commands for exact equality
    private func pathCommandsAreEqual(_ path1: [PathCommand], _ path2: [PathCommand]) -> Bool {
        guard path1.count == path2.count else { return false }

        let tolerance: CGFloat = 0.01

        for (cmd1, cmd2) in zip(path1, path2) {
            switch (cmd1, cmd2) {
            case (.moveTo(let p1), .moveTo(let p2)):
                if abs(p1.x - p2.x) > tolerance || abs(p1.y - p2.y) > tolerance {
                    return false
                }
            case (.lineTo(let p1), .lineTo(let p2)):
                if abs(p1.x - p2.x) > tolerance || abs(p1.y - p2.y) > tolerance {
                    return false
                }
            case (.curveTo(let cp1_1, let cp2_1, let to1), .curveTo(let cp1_2, let cp2_2, let to2)):
                if abs(cp1_1.x - cp1_2.x) > tolerance || abs(cp1_1.y - cp1_2.y) > tolerance ||
                   abs(cp2_1.x - cp2_2.x) > tolerance || abs(cp2_1.y - cp2_2.y) > tolerance ||
                   abs(to1.x - to2.x) > tolerance || abs(to1.y - to2.y) > tolerance {
                    return false
                }
            case (.quadCurveTo(let cp1, let to1), .quadCurveTo(let cp2, let to2)):
                if abs(cp1.x - cp2.x) > tolerance || abs(cp1.y - cp2.y) > tolerance ||
                   abs(to1.x - to2.x) > tolerance || abs(to1.y - to2.y) > tolerance {
                    return false
                }
            case (.closePath, .closePath):
                continue
            case (.rectangle(let r1), .rectangle(let r2)):
                if abs(r1.origin.x - r2.origin.x) > tolerance || 
                   abs(r1.origin.y - r2.origin.y) > tolerance ||
                   abs(r1.size.width - r2.size.width) > tolerance ||
                   abs(r1.size.height - r2.size.height) > tolerance {
                    return false
                }
            default:
                return false
            }
        }

        return true
    }
}