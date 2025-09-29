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

    /// Draw gradient for PDF using either CGGradient or CGShading based on user preference
    static func drawPDFGradient(_ gradient: VectorGradient, in context: CGContext, bounds: CGRect, opacity: Double) {
        // Check user preference for gradient method
        let method = AppState.shared.pdfGradientMethod

        if method == .cgShading {
            drawPDFGradientWithCGShading(gradient, in: context, bounds: bounds, opacity: opacity)
        } else {
            drawPDFGradientWithCGGradient(gradient, in: context, bounds: bounds, opacity: opacity)
        }
    }

    /// Draw gradient for PDF using CGGradient (faster but may rasterize in Illustrator)
    private static func drawPDFGradientWithCGGradient(_ gradient: VectorGradient, in context: CGContext, bounds: CGRect, opacity: Double) {
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

    /// Draw gradient for PDF using CGShading (better vector compatibility with Illustrator)
    /// Note: CGShading uses a simpler, two-color gradient approach for better compatibility
    private static func drawPDFGradientWithCGShading(_ gradient: VectorGradient, in context: CGContext, bounds: CGRect, opacity: Double) {
        // Apply opacity
        context.setAlpha(CGFloat(opacity))

        switch gradient {
        case .linear(let linearGradient):
            // Simplify to two-color gradient for CGShading
            drawSimplifiedLinearGradientWithCGShading(linearGradient, in: context, bounds: bounds)
        case .radial(let radialGradient):
            // Simplify to two-color gradient for CGShading
            drawSimplifiedRadialGradientWithCGShading(radialGradient, in: context, bounds: bounds)
        }
    }

    private static func drawSimplifiedLinearGradientWithCGShading(_ linearGradient: LinearGradient, in context: CGContext, bounds: CGRect) {
        // Create color space
        let colorSpace = ColorManager.shared.workingCGColorSpace

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

        // Get start and end colors from stops
        let startColor = linearGradient.stops.first ?? GradientStop(position: 0, color: .black, opacity: 1)
        let endColor = linearGradient.stops.last ?? GradientStop(position: 1, color: .white, opacity: 1)

        let color1 = colorFromVectorColor(startColor.color, opacity: startColor.opacity)
        let color2 = colorFromVectorColor(endColor.color, opacity: endColor.opacity)

        // Create a simple two-point gradient function
        let components: [CGFloat] = [
            color1.r, color1.g, color1.b, color1.a,
            color2.r, color2.g, color2.b, color2.a
        ]

        // Create CGGradient first (simpler approach)
        guard let gradient = CGGradient(
            colorSpace: colorSpace,
            colorComponents: components,
            locations: [0, 1],
            count: 2
        ) else { return }

        // Use gradient with shading-like options for better compatibility
        context.saveGState()
        context.drawLinearGradient(
            gradient,
            start: startPoint,
            end: endPoint,
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
        context.restoreGState()
    }

    private static func drawSimplifiedRadialGradientWithCGShading(_ radialGradient: RadialGradient, in context: CGContext, bounds: CGRect) {
        // Create color space
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        // Calculate center and radius
        let centerX = bounds.minX + bounds.width * radialGradient.centerPoint.x
        let centerY = bounds.minY + bounds.height * radialGradient.centerPoint.y
        let center = CGPoint(x: centerX, y: centerY)
        let radius = min(bounds.width, bounds.height) * radialGradient.radius

        // Handle focal point
        let focalCenter: CGPoint
        if let focalPoint = radialGradient.focalPoint {
            let focalX = bounds.minX + bounds.width * focalPoint.x
            let focalY = bounds.minY + bounds.height * focalPoint.y
            focalCenter = CGPoint(x: focalX, y: focalY)
        } else {
            focalCenter = center
        }

        // Get start and end colors from stops
        let startColor = radialGradient.stops.first ?? GradientStop(position: 0, color: .black, opacity: 1)
        let endColor = radialGradient.stops.last ?? GradientStop(position: 1, color: .white, opacity: 1)

        let color1 = colorFromVectorColor(startColor.color, opacity: startColor.opacity)
        let color2 = colorFromVectorColor(endColor.color, opacity: endColor.opacity)

        // Create a simple two-point gradient
        let components: [CGFloat] = [
            color1.r, color1.g, color1.b, color1.a,
            color2.r, color2.g, color2.b, color2.a
        ]

        // Create CGGradient first (simpler approach)
        guard let gradient = CGGradient(
            colorSpace: colorSpace,
            colorComponents: components,
            locations: [0, 1],
            count: 2
        ) else { return }

        // Use gradient with shading-like options for better compatibility
        context.saveGState()
        context.drawRadialGradient(
            gradient,
            startCenter: focalCenter,
            startRadius: 0,
            endCenter: center,
            endRadius: radius,
            options: [.drawsAfterEndLocation]
        )
        context.restoreGState()
    }

    // Helper function to convert VectorColor to RGBA components
    private static func colorFromVectorColor(_ color: VectorColor, opacity: Double) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        // Use VectorColor's built-in cgColor property which handles all conversions through ColorManager
        let cgColor = color.cgColor

        // Get components from CGColor
        if let components = cgColor.components, components.count >= 3 {
            // RGB or RGBA color space
            if components.count == 4 {
                return (components[0], components[1], components[2], components[3] * CGFloat(opacity))
            } else {
                return (components[0], components[1], components[2], CGFloat(opacity))
            }
        } else if let components = cgColor.components, components.count == 2 {
            // Grayscale color space
            return (components[0], components[0], components[0], components[1] * CGFloat(opacity))
        } else {
            // Fallback to black
            return (0.0, 0.0, 0.0, CGFloat(opacity))
        }
    }

    // REMOVED: Old exportToPDF function that didn't handle gradients properly
    // Use generatePDFData instead which calls generatePDFDataWithClippingSupport
}