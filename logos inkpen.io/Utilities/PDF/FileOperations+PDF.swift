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

    /// Draw gradient for PDF using either CGGradient, CGShading, or discrete bands based on user preference
    static func drawPDFGradient(_ gradient: VectorGradient, in context: CGContext, bounds: CGRect, opacity: Double) {
        // Check user preference for gradient method
        let method = AppState.shared.pdfGradientMethod

        switch method {
        case .cgShading:
            drawPDFGradientWithCGShading(gradient, in: context, bounds: bounds, opacity: opacity)
        case .blend:
            drawPDFGradientAsBlend(gradient, in: context, bounds: bounds, opacity: opacity)
        case .mesh:
            // TODO: Implement mesh gradients
            drawPDFGradientWithCGGradient(gradient, in: context, bounds: bounds, opacity: opacity)
        default:
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
                    colors.append(contentsOf: [0.0, 0.0, 0.0, CGFloat(stop.opacity) * CGFloat(opacity)])
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
                    colors.append(contentsOf: [0.0, 0.0, 0.0, CGFloat(stop.opacity) * CGFloat(opacity)])
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
                    colors.append(contentsOf: [0.0, 0.0, 0.0, CGFloat(stop.opacity) * CGFloat(opacity)])
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
                    colors.append(contentsOf: [0.0, 0.0, 0.0, CGFloat(stop.opacity) * CGFloat(opacity)])
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
    /// Note: This version bakes opacity into the gradient colors instead of using setAlpha
    /// to avoid transparency flattening issues in Adobe Illustrator
    private static func drawPDFGradientWithCGShading(_ gradient: VectorGradient, in context: CGContext, bounds: CGRect, opacity: Double) {
        // DO NOT use setAlpha here - bake opacity into gradient colors instead
        // This avoids transparency flattening in Adobe Illustrator

        switch gradient {
        case .linear(let linearGradient):
            drawSimplifiedLinearGradientWithCGShading(linearGradient, in: context, bounds: bounds, opacity: opacity)
        case .radial(let radialGradient):
            drawSimplifiedRadialGradientWithCGShading(radialGradient, in: context, bounds: bounds, opacity: opacity)
        }
    }

    private static func drawSimplifiedLinearGradientWithCGShading(_ linearGradient: LinearGradient, in context: CGContext, bounds: CGRect, opacity: Double) {
        // For now, use the same implementation as CGGradient but with ALL stops preserved
        // Real CGShading would require C-style callbacks which are complex in Swift
        // This ensures we at least preserve all colors and stops correctly

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

        // Use ALL gradient stops, not just first and last
        var colors: [CGFloat] = []
        var locations: [CGFloat] = []

        for stop in linearGradient.stops {
            locations.append(stop.position)

            // Use the cgColor property to get proper color conversion
            let cgColor = stop.color.cgColor
            if let components = cgColor.components {
                if components.count >= 3 {
                    // RGB or RGBA
                    colors.append(contentsOf: [
                        components[0],
                        components[1],
                        components[2],
                        (components.count > 3 ? components[3] : 1.0) * CGFloat(stop.opacity) * CGFloat(opacity)
                    ])
                } else if components.count == 2 {
                    // Grayscale
                    colors.append(contentsOf: [
                        components[0],
                        components[0],
                        components[0],
                        components[1] * CGFloat(stop.opacity) * CGFloat(opacity)
                    ])
                } else {
                    // Fallback
                    colors.append(contentsOf: [0.0, 0.0, 0.0, CGFloat(stop.opacity) * CGFloat(opacity)])
                }
            } else {
                // Fallback
                colors.append(contentsOf: [0.0, 0.0, 0.0, CGFloat(stop.opacity)])
            }
        }

        // Create CGGradient with all stops
        guard let gradient = CGGradient(
            colorSpace: colorSpace,
            colorComponents: colors,
            locations: locations,
            count: locations.count
        ) else { return }

        // Draw with extended options for better PDF compatibility
        context.saveGState()
        context.drawLinearGradient(
            gradient,
            start: startPoint,
            end: endPoint,
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
        context.restoreGState()
    }

    private static func drawSimplifiedRadialGradientWithCGShading(_ radialGradient: RadialGradient, in context: CGContext, bounds: CGRect, opacity: Double) {
        // For now, use the same implementation as CGGradient but with ALL stops preserved
        // Real CGShading would require C-style callbacks which are complex in Swift

        // Create color space
        let colorSpace = ColorManager.shared.workingCGColorSpace

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

        // Use ALL gradient stops, not just first and last
        var colors: [CGFloat] = []
        var locations: [CGFloat] = []

        for stop in radialGradient.stops {
            locations.append(stop.position)

            // Use the cgColor property to get proper color conversion
            let cgColor = stop.color.cgColor
            if let components = cgColor.components {
                if components.count >= 3 {
                    // RGB or RGBA
                    colors.append(contentsOf: [
                        components[0],
                        components[1],
                        components[2],
                        (components.count > 3 ? components[3] : 1.0) * CGFloat(stop.opacity) * CGFloat(opacity)
                    ])
                } else if components.count == 2 {
                    // Grayscale
                    colors.append(contentsOf: [
                        components[0],
                        components[0],
                        components[0],
                        components[1] * CGFloat(stop.opacity) * CGFloat(opacity)
                    ])
                } else {
                    // Fallback
                    colors.append(contentsOf: [0.0, 0.0, 0.0, CGFloat(stop.opacity) * CGFloat(opacity)])
                }
            } else {
                // Fallback
                colors.append(contentsOf: [0.0, 0.0, 0.0, CGFloat(stop.opacity)])
            }
        }

        // Create CGGradient with all stops
        guard let gradient = CGGradient(
            colorSpace: colorSpace,
            colorComponents: colors,
            locations: locations,
            count: locations.count
        ) else { return }

        // Draw with appropriate options for PDF compatibility
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

    /// Draw gradient as blend (vector shapes) with user-defined steps
    /// This creates an Illustrator-style blend with discrete vector shapes
    private static func drawPDFGradientAsBlend(_ gradient: VectorGradient, in context: CGContext, bounds: CGRect, opacity: Double) {
        context.saveGState()

        switch gradient {
        case .linear(let linearGradient):
            drawLinearGradientAsBlend(linearGradient, in: context, bounds: bounds, opacity: opacity)
        case .radial(let radialGradient):
            drawRadialGradientAsBlend(radialGradient, in: context, bounds: bounds, opacity: opacity)
        }

        context.restoreGState()
    }

    private static func drawLinearGradientAsBlend(_ linearGradient: LinearGradient, in context: CGContext, bounds: CGRect, opacity: Double) {
        let bandCount = AppState.shared.pdfBlendSteps // Use user-defined steps
        let stops = linearGradient.stops

        guard stops.count >= 2 else { return }

        // Calculate gradient direction
        let angle = linearGradient.angle * .pi / 180.0

        // Calculate gradient start and end points
        let centerX = bounds.midX
        let centerY = bounds.midY
        let maxDist = max(bounds.width, bounds.height)

        // Create bands
        for i in 0..<bandCount {
            let t0 = Double(i) / Double(bandCount)
            let t1 = Double(i + 1) / Double(bandCount)
            let tMid = (t0 + t1) / 2.0

            // Interpolate color at midpoint
            let color = interpolateGradientColor(at: tMid, stops: stops, opacity: opacity)

            // Create band rectangle
            let bandStart = -maxDist + (2.0 * maxDist * t0)
            let bandEnd = -maxDist + (2.0 * maxDist * t1)

            // Create path for band
            context.saveGState()

            // Translate and rotate to gradient angle
            context.translateBy(x: centerX, y: centerY)
            context.rotate(by: -angle)

            // Draw rectangle band
            let bandRect = CGRect(x: bandStart, y: -maxDist, width: bandEnd - bandStart, height: 2.0 * maxDist)
            context.setFillColor(color.cgColor)
            context.fill(bandRect)

            context.restoreGState()
        }
    }

    private static func drawRadialGradientAsBlend(_ radialGradient: RadialGradient, in context: CGContext, bounds: CGRect, opacity: Double) {
        let bandCount = AppState.shared.pdfBlendSteps // Use user-defined steps
        let stops = radialGradient.stops

        guard stops.count >= 2 else { return }

        // Calculate center
        let centerX = bounds.minX + bounds.width * radialGradient.centerPoint.x
        let centerY = bounds.minY + bounds.height * radialGradient.centerPoint.y
        let center = CGPoint(x: centerX, y: centerY)
        let maxRadius = min(bounds.width, bounds.height) * radialGradient.radius

        // Draw bands from outside to inside to ensure proper layering
        for i in (0..<bandCount).reversed() {
            let t0 = Double(i) / Double(bandCount)
            let t1 = Double(i + 1) / Double(bandCount)
            let tMid = (t0 + t1) / 2.0

            // Interpolate color at midpoint
            let color = interpolateGradientColor(at: tMid, stops: stops, opacity: opacity)

            // Create circle band
            let outerRadius = maxRadius * t1
            let innerRadius = maxRadius * t0

            context.saveGState()

            // Draw outer circle
            context.setFillColor(color.cgColor)
            context.addEllipse(in: CGRect(x: center.x - outerRadius, y: center.y - outerRadius,
                                         width: outerRadius * 2, height: outerRadius * 2))

            // Clip out inner circle if not the center band
            if i > 0 {
                context.addEllipse(in: CGRect(x: center.x - innerRadius, y: center.y - innerRadius,
                                             width: innerRadius * 2, height: innerRadius * 2))
                context.fillPath(using: .evenOdd)
            } else {
                context.fillPath()
            }

            context.restoreGState()
        }
    }

    // Helper to interpolate color at position t in gradient stops
    private static func interpolateGradientColor(at t: Double, stops: [GradientStop], opacity: Double) -> NSColor {
        // Find surrounding stops
        var lowerStop = stops.first!
        var upperStop = stops.last!

        for i in 0..<(stops.count - 1) {
            if t >= stops[i].position && t <= stops[i + 1].position {
                lowerStop = stops[i]
                upperStop = stops[i + 1]
                break
            }
        }

        // Handle edge cases
        if t <= stops.first!.position {
            let cgColor = stops.first!.color.cgColor
            return NSColor(cgColor: cgColor)!.withAlphaComponent(CGFloat(stops.first!.opacity * opacity))
        }
        if t >= stops.last!.position {
            let cgColor = stops.last!.color.cgColor
            return NSColor(cgColor: cgColor)!.withAlphaComponent(CGFloat(stops.last!.opacity * opacity))
        }

        // Interpolate between stops
        let range = upperStop.position - lowerStop.position
        let factor = range > 0 ? (t - lowerStop.position) / range : 0

        let color1 = NSColor(cgColor: lowerStop.color.cgColor)!
        let color2 = NSColor(cgColor: upperStop.color.cgColor)!

        // Blend colors
        let r = color1.redComponent * (1 - factor) + color2.redComponent * factor
        let g = color1.greenComponent * (1 - factor) + color2.greenComponent * factor
        let b = color1.blueComponent * (1 - factor) + color2.blueComponent * factor
        let a = (lowerStop.opacity * (1 - factor) + upperStop.opacity * factor) * opacity

        return NSColor(red: r, green: g, blue: b, alpha: CGFloat(a))
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
}
