//
//  FileOperations+PDF.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

extension FileOperations {
    /// Generate PDF data from VectorDocument
    static func generatePDFData(from document: VectorDocument) throws -> Data {
        Log.fileOperation("📄 Generating PDF data from document", level: .info)

        // Use the new method with clipping path and image support
        return try generatePDFDataWithClippingSupport(from: document)
    }

    /// Render VectorDocument to PDF context
    static func renderDocumentToPDF(document: VectorDocument, context: CGContext, canvasSize: CGSize) throws {
        Log.fileOperation("🎨 Rendering document to PDF context", level: .info)

        // Save graphics state
        context.saveGState()

        // Render layers (skip pasteboard and canvas background)
        for (index, layer) in document.layers.enumerated() {
            // Skip pasteboard (index 0) and canvas (index 1) for PDF export
            guard index >= 2, !layer.isLocked, layer.isVisible else { continue }

            Log.fileOperation("🎨 Rendering layer: \(layer.name)", level: .info)

            // Render shapes in layer using unified objects
            let shapesInLayer = document.getShapesForLayer(index)
            for shape in shapesInLayer where shape.isVisible {
                try renderShapeToPDF(shape: shape, context: context)
            }
        }

        // Restore graphics state
        context.restoreGState()

        Log.fileOperation("✅ Document rendered to PDF context", level: .info)
    }

    /// Render individual shape to PDF context
    static func renderShapeToPDF(shape: VectorShape, context: CGContext) throws {
        // Convert VectorShape path to CGPath
        let cgPath = convertVectorPathToCGPath(shape.path)

        // Save graphics state for this shape
        context.saveGState()

        // Apply shape transform
        context.concatenate(shape.transform)

        // Check if we have a valid fill (not clear/none)
        var hasValidFill = false
        if let fillStyle = shape.fillStyle {
            // DO NOT EXPORT FILL IF COLOR IS CLEAR!
            if case .clear = fillStyle.color {
                // Skip fill completely - this is the "none" fill (checkerboard)
                hasValidFill = false
            } else if fillStyle.opacity > 0 {
                // Only export fill if it has a real color and opacity
                hasValidFill = true
            }
        }

        // Handle fill
        if hasValidFill, let fillStyle = shape.fillStyle {
            // Check if fill is a gradient
            if case .gradient(let gradient) = fillStyle.color {
                // For gradients, we need to clip first then draw
                context.addPath(cgPath)
                context.saveGState()
                context.clip()

                // Draw the gradient
                drawPDFGradient(gradient, in: context, bounds: cgPath.boundingBox, opacity: fillStyle.opacity)

                context.restoreGState()
            } else {
                // Regular color fill
                context.addPath(cgPath)
                setFillStyle(fillStyle, context: context)
                context.fillPath()
            }
        }

        // Check if we have a valid stroke (not clear/none)
        var hasValidStroke = false
        if let strokeStyle = shape.strokeStyle {
            // DO NOT EXPORT STROKE IF COLOR IS CLEAR!
            if case .clear = strokeStyle.color {
                // Skip stroke completely - this is the "none" stroke (checkerboard)
                hasValidStroke = false
            } else if strokeStyle.width > 0 && strokeStyle.opacity > 0 {
                // Only export stroke if it has a real color, width, and opacity
                hasValidStroke = true
            }
        }

        // Handle stroke
        if hasValidStroke, let strokeStyle = shape.strokeStyle {
            context.addPath(cgPath)
            setStrokeStyle(strokeStyle, context: context)
            context.strokePath()
        }

        // Restore graphics state
        context.restoreGState()
    }

    /// Set fill style in PDF context
    static func setFillStyle(_ fillStyle: FillStyle, context: CGContext) {
        // Use the universal cgColor property which handles all color types
        let cgColor = fillStyle.color.cgColor

        // Get color components and apply opacity
        if let components = cgColor.components, components.count >= 3 {
            // RGB or similar color space
            context.setFillColor(red: components[0], green: components[1], blue: components[2], alpha: fillStyle.opacity)
        } else if let components = cgColor.components, components.count == 2 {
            // Grayscale color space
            context.setFillColor(gray: components[0], alpha: fillStyle.opacity)
        } else {
            // Fallback - use CGColor directly with setFillColor
            var modifiedColor = cgColor
            if let colorSpace = cgColor.colorSpace,
               let components = cgColor.components {
                var componentsWithAlpha = components
                if componentsWithAlpha.count > 0 {
                    componentsWithAlpha[componentsWithAlpha.count - 1] = fillStyle.opacity
                    if let newColor = CGColor(colorSpace: colorSpace, components: componentsWithAlpha) {
                        modifiedColor = newColor
                    }
                }
            }
            context.setFillColor(modifiedColor)
        }
    }

    /// Set stroke style in PDF context
    static func setStrokeStyle(_ strokeStyle: StrokeStyle, context: CGContext) {
        // Use the universal cgColor property which handles all color types
        let cgColor = strokeStyle.color.cgColor

        // Get color components and apply opacity
        if let components = cgColor.components, components.count >= 3 {
            // RGB or similar color space
            context.setStrokeColor(red: components[0], green: components[1], blue: components[2], alpha: strokeStyle.opacity)
        } else if let components = cgColor.components, components.count == 2 {
            // Grayscale color space
            context.setStrokeColor(gray: components[0], alpha: strokeStyle.opacity)
        } else {
            // Fallback - use CGColor directly
            var modifiedColor = cgColor
            if let colorSpace = cgColor.colorSpace,
               let components = cgColor.components {
                var componentsWithAlpha = components
                if componentsWithAlpha.count > 0 {
                    componentsWithAlpha[componentsWithAlpha.count - 1] = strokeStyle.opacity
                    if let newColor = CGColor(colorSpace: colorSpace, components: componentsWithAlpha) {
                        modifiedColor = newColor
                    }
                }
            }
            context.setStrokeColor(modifiedColor)
        }

        // Set line width
        context.setLineWidth(strokeStyle.width)

        // Set line cap
        context.setLineCap(strokeStyle.lineCap.cgLineCap)

        // Set line join
        context.setLineJoin(strokeStyle.lineJoin.cgLineJoin)

        // Set dash pattern if present
        if !strokeStyle.dashPattern.isEmpty {
            let dashPatternCGFloat = strokeStyle.dashPattern.map { CGFloat($0) }
            context.setLineDash(phase: 0, lengths: dashPatternCGFloat)
        }
    }

    /// Draw gradient for PDF using CGGradient for better PDF compatibility
    static func drawPDFGradient(_ gradient: VectorGradient, in context: CGContext, bounds: CGRect, opacity: Double) {
        // Apply opacity
        context.setAlpha(CGFloat(opacity))

        switch gradient {
        case .linear(let linearGradient):
            // CRITICAL FIX: Use CGGradient instead of CGShading for proper vector gradients in PDF
            // CGGradient is better supported in PDF export and doesn't get rasterized

            // Create color space - use ColorManager's working color space
            let colorSpace = ColorManager.shared.workingCGColorSpace

            // Extract colors and locations from gradient stops
            var colors: [CGFloat] = []
            var locations: [CGFloat] = []

            for stop in linearGradient.stops {
                locations.append(stop.position)

                switch stop.color {
                case .rgb(let rgb):
                    colors.append(contentsOf: [rgb.red, rgb.green, rgb.blue, rgb.alpha * stop.opacity])
                case .white:
                    colors.append(contentsOf: [1.0, 1.0, 1.0, CGFloat(stop.opacity)])
                case .black:
                    colors.append(contentsOf: [0.0, 0.0, 0.0, CGFloat(stop.opacity)])
                case .clear:
                    colors.append(contentsOf: [0.0, 0.0, 0.0, 0.0])
                case .cmyk(let cmyk):
                    let r = (1.0 - cmyk.cyan) * (1.0 - cmyk.black)
                    let g = (1.0 - cmyk.magenta) * (1.0 - cmyk.black)
                    let b = (1.0 - cmyk.yellow) * (1.0 - cmyk.black)
                    colors.append(contentsOf: [r, g, b, CGFloat(stop.opacity)])
                case .hsb(let hsb):
                    let rgb = hsb.rgbColor
                    colors.append(contentsOf: [rgb.red, rgb.green, rgb.blue, rgb.alpha * stop.opacity])
                default:
                    colors.append(contentsOf: [0.0, 0.0, 0.0, CGFloat(stop.opacity)])
                }
            }

            // Create CGGradient
            guard let cgGradient = CGGradient(
                colorSpace: colorSpace,
                colorComponents: colors,
                locations: locations,
                count: locations.count
            ) else { return }

            // Calculate gradient points based on the gradient's angle
            let angle = linearGradient.angle * .pi / 180.0
            let centerX = bounds.midX
            let centerY = bounds.midY
            let radius = max(bounds.width, bounds.height) / 2.0

            let startX = centerX - radius * cos(angle)
            let startY = centerY - radius * sin(angle)
            let endX = centerX + radius * cos(angle)
            let endY = centerY + radius * sin(angle)

            let startPoint = CGPoint(x: startX, y: startY)
            let endPoint = CGPoint(x: endX, y: endY)

            // Draw the gradient using CGGradient (preserves vector in PDF)
            context.drawLinearGradient(
                cgGradient,
                start: startPoint,
                end: endPoint,
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )

        case .radial(let radialGradient):
            // CRITICAL FIX: Use CGGradient for radial gradients too
            let colorSpace = CGColorSpaceCreateDeviceRGB()

            // Extract colors and locations
            var colors: [CGFloat] = []
            var locations: [CGFloat] = []

            for stop in radialGradient.stops {
                locations.append(stop.position)

                switch stop.color {
                case .rgb(let rgb):
                    colors.append(contentsOf: [rgb.red, rgb.green, rgb.blue, rgb.alpha * stop.opacity])
                case .white:
                    colors.append(contentsOf: [1.0, 1.0, 1.0, CGFloat(stop.opacity)])
                case .black:
                    colors.append(contentsOf: [0.0, 0.0, 0.0, CGFloat(stop.opacity)])
                case .clear:
                    colors.append(contentsOf: [0.0, 0.0, 0.0, 0.0])
                case .cmyk(let cmyk):
                    let r = (1.0 - cmyk.cyan) * (1.0 - cmyk.black)
                    let g = (1.0 - cmyk.magenta) * (1.0 - cmyk.black)
                    let b = (1.0 - cmyk.yellow) * (1.0 - cmyk.black)
                    colors.append(contentsOf: [r, g, b, CGFloat(stop.opacity)])
                case .hsb(let hsb):
                    let rgb = hsb.rgbColor
                    colors.append(contentsOf: [rgb.red, rgb.green, rgb.blue, rgb.alpha * stop.opacity])
                default:
                    colors.append(contentsOf: [0.0, 0.0, 0.0, CGFloat(stop.opacity)])
                }
            }

            // Create CGGradient
            guard let cgGradient = CGGradient(
                colorSpace: colorSpace,
                colorComponents: colors,
                locations: locations,
                count: locations.count
            ) else { return }

            // Calculate center and radius using bounds parameter
            let centerX = bounds.minX + bounds.width * radialGradient.centerPoint.x
            let centerY = bounds.minY + bounds.height * radialGradient.centerPoint.y
            let center = CGPoint(x: centerX, y: centerY)
            let radius = min(bounds.width, bounds.height) * radialGradient.radius

            // Handle focal point if it exists (for non-centered radial gradients)
            let focalCenter: CGPoint
            if let focalPoint = radialGradient.focalPoint {
                let focalX = bounds.minX + bounds.width * focalPoint.x
                let focalY = bounds.minY + bounds.height * focalPoint.y
                focalCenter = CGPoint(x: focalX, y: focalY)
            } else {
                // If no focal point, use the center point (standard radial gradient)
                focalCenter = center
            }

            // Draw the radial gradient using CGGradient
            // startCenter is the focal point (inner circle), endCenter is the outer circle
            context.drawRadialGradient(
                cgGradient,
                startCenter: focalCenter,
                startRadius: 0,
                endCenter: center,
                endRadius: radius,
                options: [.drawsAfterEndLocation]
            )
        }
    }

    static func exportToPDF(_ document: VectorDocument, url: URL, includeBackground: Bool = true) throws {
        Log.info("📄 Exporting document to PDF: \(url.path)", category: .general)

        // Create PDF context
        let pageSize = document.settings.sizeInPoints
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        let pdfContext = CGContext(url as CFURL, mediaBox: &mediaBox, nil)

        guard let context = pdfContext else {
            throw VectorImportError.parsingError("Failed to create PDF context", line: nil)
        }

        // Begin PDF page
        var pageRect = CGRect(origin: .zero, size: pageSize)
        context.beginPage(mediaBox: &pageRect)

        // Set coordinate system to match our canvas (flip Y axis)
        context.translateBy(x: 0, y: pageSize.height)
        context.scaleBy(x: 1, y: -1)

        // Draw background only if includeBackground is true
        if includeBackground {
            context.setFillColor(document.settings.backgroundColor.cgColor)
            context.fill(CGRect(origin: .zero, size: pageSize))
        }

        // Draw each layer
        for (index, layer) in document.layers.enumerated() {
            if !layer.isVisible { continue }

            // ALWAYS skip Pasteboard layer (index 0)
            if index == 0 || layer.name == "Pasteboard" { continue }

            // Skip Canvas layer (index 1) if not including background
            if !includeBackground && (index == 1 || layer.name == "Canvas") { continue }

            // Apply layer opacity
            context.saveGState()
            context.setAlpha(layer.opacity)

            // Draw shapes in layer
            let layerIndex = document.layers.firstIndex(where: { $0.id == layer.id }) ?? 0
            let shapesInLayer = document.getShapesForLayer(layerIndex)
            for shape in shapesInLayer {
                if !shape.isVisible { continue }

                drawShapeInPDF(shape, context: context)
            }

            context.restoreGState()
        }

        // Draw text objects
        document.forEachTextInOrder { text in
            if !text.isVisible { return }

            drawTextInPDF(text, context: context)
        }

        // End PDF page
        context.endPage()

        // Close PDF context
        context.closePDF()

        Log.info("✅ Successfully exported PDF document", category: .fileOperations)
    }
}