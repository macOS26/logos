//
//  FileOperations+PDF.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

extension FileOperations {
    /// Generate PDF data from VectorDocument for Save/Save As
    static func generatePDFData(from document: VectorDocument) throws -> Data {
        Log.fileOperation("📄 Generating PDF data from document", level: .info)

        // Use the new method with clipping path and image support
        return try generatePDFDataWithClippingSupport(from: document, isExport: false, useCMYK: false)
    }

    /// Generate PDF data for Export with CMYK option and text rendering mode
    static func generatePDFDataForExport(from document: VectorDocument, useCMYK: Bool, textRenderingMode: AppState.PDFTextRenderingMode = .glyphs) throws -> Data {
        Log.fileOperation("📄 Generating PDF data for export (CMYK: \(useCMYK), Text Mode: \(textRenderingMode.displayName))", level: .info)

        // Use the new method with export flag, CMYK option, and text rendering mode
        return try generatePDFDataWithClippingSupport(from: document, isExport: true, useCMYK: useCMYK, textRenderingMode: textRenderingMode)
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

    /// Draw gradient for PDF Export with optional CMYK
    static func drawPDFGradientForExport(_ gradient: VectorGradient, in context: CGContext, bounds: CGRect, opacity: Double, useCMYK: Bool) {
        if useCMYK {
            drawPDFGradientAsCMYK(gradient, in: context, bounds: bounds, opacity: opacity)
        } else {
            drawPDFGradientWithCGGradient(gradient, in: context, bounds: bounds, opacity: opacity)
        }
    }

    /// Draw gradient for PDF using either CGGradient, CGShading, or discrete bands based on user preference
    /// This is used for Save/Save As operations
    static func drawPDFGradient(_ gradient: VectorGradient, in context: CGContext, bounds: CGRect, opacity: Double) {
        #if DEBUG
        // In debug mode, use the user's preference
        let method = AppState.shared.pdfGradientMethod

        switch method {
        case .cgShading:
            drawPDFGradientWithCGShading(gradient, in: context, bounds: bounds, opacity: opacity)
        case .blend:
            drawPDFGradientAsBlend(gradient, in: context, bounds: bounds, opacity: opacity)
        case .mesh:
            drawPDFGradientAsMesh(gradient, in: context, bounds: bounds, opacity: opacity)
        case .cmyk:
            drawPDFGradientAsCMYK(gradient, in: context, bounds: bounds, opacity: opacity)
        default:
            drawPDFGradientWithCGGradient(gradient, in: context, bounds: bounds, opacity: opacity)
        }
        #else
        // In release mode, always use CGGradient for Save/Save As
        drawPDFGradientWithCGGradient(gradient, in: context, bounds: bounds, opacity: opacity)
        #endif
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

    // Thread-safe gradient data holder for CGShading callbacks
    private final class GradientData {
        let stops: [(position: CGFloat, r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)]

        init(stops: [GradientStop], opacity: Double) {
            self.stops = stops.map { stop in
                let cgColor = stop.color.cgColor
                if let components = cgColor.components, components.count >= 3 {
                    return (
                        CGFloat(stop.position),
                        components[0],
                        components[1],
                        components[2],
                        (components.count > 3 ? components[3] : 1.0) * CGFloat(stop.opacity) * CGFloat(opacity)
                    )
                } else if let components = cgColor.components, components.count == 2 {
                    // Grayscale
                    return (
                        CGFloat(stop.position),
                        components[0],
                        components[0],
                        components[0],
                        components[1] * CGFloat(stop.opacity) * CGFloat(opacity)
                    )
                } else {
                    return (CGFloat(stop.position), 0, 0, 0, CGFloat(stop.opacity) * CGFloat(opacity))
                }
            }
        }

        func interpolateColor(at t: CGFloat) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
            guard !stops.isEmpty else { return (0, 0, 0, 0) }

            // Handle edge cases
            if t <= stops.first!.position {
                let s = stops.first!
                return (s.r, s.g, s.b, s.a)
            }
            if t >= stops.last!.position {
                let s = stops.last!
                return (s.r, s.g, s.b, s.a)
            }

            // Find surrounding stops
            var lower = stops.first!
            var upper = stops.last!

            for i in 0..<(stops.count - 1) {
                if t >= stops[i].position && t <= stops[i + 1].position {
                    lower = stops[i]
                    upper = stops[i + 1]
                    break
                }
            }

            // Interpolate
            let range = upper.position - lower.position
            let factor = range > 0 ? (t - lower.position) / range : 0

            return (
                lower.r + (upper.r - lower.r) * factor,
                lower.g + (upper.g - lower.g) * factor,
                lower.b + (upper.b - lower.b) * factor,
                lower.a + (upper.a - lower.a) * factor
            )
        }
    }

    /// Draw gradient for PDF using CGShading (better vector compatibility with Illustrator)
    /// This implementation uses proper CGShading with CGFunction callbacks for thread-safe gradient interpolation
    private static func drawPDFGradientWithCGShading(_ gradient: VectorGradient, in context: CGContext, bounds: CGRect, opacity: Double) {
        // DO NOT use setAlpha here - bake opacity into gradient colors instead
        // This avoids transparency flattening in Adobe Illustrator

        switch gradient {
        case .linear(let linearGradient):
            drawLinearGradientWithCGShading(linearGradient, in: context, bounds: bounds, opacity: opacity)
        case .radial(let radialGradient):
            drawRadialGradientWithCGShading(radialGradient, in: context, bounds: bounds, opacity: opacity)
        }
    }

    private static func drawLinearGradientWithCGShading(_ linearGradient: LinearGradient, in context: CGContext, bounds: CGRect, opacity: Double) {
        // Create gradient data holder
        let gradientData = GradientData(stops: linearGradient.stops, opacity: opacity)
        
        // Create color space
        let colorSpace = ColorManager.shared.workingCGColorSpace
        
        // Calculate gradient points based on angle
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
        
        // Create CGFunction callbacks for gradient evaluation
        var callbacks = CGFunctionCallbacks(
            version: 0,
            evaluate: { info, input, output in
                guard let info = info else { return }
                let data = Unmanaged<GradientData>.fromOpaque(info).takeUnretainedValue()
                let t = input[0]
                let color = data.interpolateColor(at: t)
                output[0] = color.r
                output[1] = color.g
                output[2] = color.b
                output[3] = color.a
            },
            releaseInfo: { info in
                guard info != nil else { return }
                //_ = Unmanaged<GradientData>.fromOpaque(info).takeRetainedValue()
            }
        )
        
        // Create CGFunction with proper domain and range
        let function = CGFunction(
            info: Unmanaged.passRetained(gradientData).toOpaque(),
            domainDimension: 1,
            domain: [0, 1],  // Input range (t parameter)
            rangeDimension: 4,
            range: [0, 1, 0, 1, 0, 1, 0, 1],  // RGBA output ranges
            callbacks: &callbacks
        )
        
        // Create CGShading for linear gradient
        guard let function = function,
              let shading = CGShading(axialSpace: colorSpace,
                                     start: startPoint,
                                     end: endPoint,
                                     function: function,
                                     extendStart: true,
                                     extendEnd: true) else {
            // Fallback to CGGradient if CGShading fails
            Log.fileOperation("⚠️ CGShading creation failed for linear gradient, falling back to CGGradient", level: .warning)
            drawSimplifiedLinearGradientWithCGGradient(linearGradient, in: context, bounds: bounds, opacity: opacity)
            return
        }
        
        // Draw the shading
        context.saveGState()
        context.clip(to: bounds)
        context.drawShading(shading)
        context.restoreGState()
    }

    private static func drawRadialGradientWithCGShading(_ radialGradient: RadialGradient, in context: CGContext, bounds: CGRect, opacity: Double) {
        // Create gradient data holder
        let gradientData = GradientData(stops: radialGradient.stops, opacity: opacity)
        
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
        
        // Create CGFunction callbacks for gradient evaluation
        var callbacks = CGFunctionCallbacks(
            version: 0,
            evaluate: { info, input, output in
                guard let info = info else { return }
                let data = Unmanaged<GradientData>.fromOpaque(info).takeUnretainedValue()
                let t = input[0]
                let color = data.interpolateColor(at: t)
                output[0] = color.r
                output[1] = color.g
                output[2] = color.b
                output[3] = color.a
            },
            releaseInfo: { info in
                guard info != nil else { return }
                //_ = Unmanaged<GradientData>.fromOpaque(info).takeRetainedValue()
            }
        )
        
        // Create CGFunction with proper domain and range
        let function = CGFunction(
            info: Unmanaged.passRetained(gradientData).toOpaque(),
            domainDimension: 1,
            domain: [0, 1],  // Input range (t parameter)
            rangeDimension: 4,
            range: [0, 1, 0, 1, 0, 1, 0, 1],  // RGBA output ranges
            callbacks: &callbacks
        )
        
        // Create CGShading for radial gradient
        guard let function = function,
              let shading = CGShading(radialSpace: colorSpace,
                                     start: focalCenter,
                                     startRadius: 0,
                                     end: center,
                                     endRadius: radius,
                                     function: function,
                                     extendStart: false,
                                     extendEnd: true) else {
            // Fallback to CGGradient if CGShading fails
            Log.fileOperation("⚠️ CGShading creation failed for radial gradient, falling back to CGGradient", level: .warning)
            drawSimplifiedRadialGradientWithCGGradient(radialGradient, in: context, bounds: bounds, opacity: opacity)
            return
        }
        
        // Draw the shading
        context.saveGState()
        context.clip(to: bounds)
        context.drawShading(shading)
        context.restoreGState()
    }

    // Fallback implementations using CGGradient (kept as backup)
    private static func drawSimplifiedLinearGradientWithCGGradient(_ linearGradient: LinearGradient, in context: CGContext, bounds: CGRect, opacity: Double) {
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

        // Use ALL gradient stops
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

    private static func drawSimplifiedRadialGradientWithCGGradient(_ radialGradient: RadialGradient, in context: CGContext, bounds: CGRect, opacity: Double) {
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

        // Use ALL gradient stops
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

        // Save context and clip to bounds
        context.saveGState()
        context.clip(to: bounds)

        // Calculate gradient extent along its axis
        let halfWidth = bounds.width / 2.0
        let halfHeight = bounds.height / 2.0
        let gradientLength = abs(CGFloat(cos(angle))) * halfWidth + abs(CGFloat(sin(angle))) * halfHeight

        // Create bands
        for i in 0..<bandCount {
            let t0 = Double(i) / Double(bandCount)
            let t1 = Double(i + 1) / Double(bandCount)
            let tMid = (t0 + t1) / 2.0

            // Interpolate color at midpoint
            let color = interpolateGradientColor(at: tMid, stops: stops, opacity: opacity)

            // Create band position along gradient
            let bandStart = -gradientLength + (2.0 * gradientLength * CGFloat(t0))
            let bandEnd = -gradientLength + (2.0 * gradientLength * CGFloat(t1))

            // Create path for band
            context.saveGState()

            // Translate and rotate to gradient angle
            context.translateBy(x: bounds.midX, y: bounds.midY)
            context.rotate(by: -angle)

            // Draw rectangle band (wide enough to cover rotated bounds)
            let bandWidth = max(bounds.width, bounds.height) * 2
            let bandRect = CGRect(x: bandStart, y: -bandWidth/2, width: bandEnd - bandStart, height: bandWidth)
            context.setFillColor(color.cgColor)
            context.fill(bandRect)

            context.restoreGState()
        }

        context.restoreGState()
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

    /// Draw gradient as a mesh grid (similar to Illustrator's gradient mesh)
    /// Creates a grid of Bezier patches with interpolated colors
    private static func drawPDFGradientAsMesh(_ gradient: VectorGradient, in context: CGContext, bounds: CGRect, opacity: Double) {
        context.saveGState()

        switch gradient {
        case .linear(let linearGradient):
            drawLinearGradientAsMesh(linearGradient, in: context, bounds: bounds, opacity: opacity)
        case .radial(let radialGradient):
            drawRadialGradientAsMesh(radialGradient, in: context, bounds: bounds, opacity: opacity)
        }

        context.restoreGState()
    }

    private static func drawLinearGradientAsMesh(_ linearGradient: LinearGradient, in context: CGContext, bounds: CGRect, opacity: Double) {
        let gridSizeX = AppState.shared.pdfMeshGridX
        let gridSizeY = AppState.shared.pdfMeshGridY
        let stops = linearGradient.stops

        guard stops.count >= 2 else { return }

        // Calculate gradient angle
        let angle = linearGradient.angle * .pi / 180.0

        // Create mesh grid
        for row in 0..<gridSizeY {
            for col in 0..<gridSizeX {
                let x0 = bounds.minX + (bounds.width * CGFloat(col) / CGFloat(gridSizeX))
                let x1 = bounds.minX + (bounds.width * CGFloat(col + 1) / CGFloat(gridSizeX))
                let y0 = bounds.minY + (bounds.height * CGFloat(row) / CGFloat(gridSizeY))
                let y1 = bounds.minY + (bounds.height * CGFloat(row + 1) / CGFloat(gridSizeY))

                // Calculate gradient position based on angle and cell position
                let cellCenterX = (x0 + x1) / 2
                let cellCenterY = (y0 + y1) / 2

                // Project cell center onto gradient axis
                let dx = cellCenterX - bounds.midX
                let dy = cellCenterY - bounds.midY
                let cosAngle = CGFloat(cos(angle))
                let sinAngle = CGFloat(sin(angle))
                let maxDim = max(bounds.width, bounds.height)
                let projection = (dx * cosAngle + dy * sinAngle) / maxDim
                let t = (projection + 1.0) / 2.0 // Normalize to 0-1

                // Get color for this position
                let color = interpolateGradientColor(at: t, stops: stops, opacity: opacity)

                // Draw mesh cell as a filled rectangle
                context.setFillColor(color.cgColor)
                context.fill(CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0))
            }
        }
    }

    private static func drawRadialGradientAsMesh(_ radialGradient: RadialGradient, in context: CGContext, bounds: CGRect, opacity: Double) {
        let gridSize = 12 // Use more cells for radial to maintain smoothness
        let stops = radialGradient.stops

        guard stops.count >= 2 else { return }

        // Calculate center
        let centerX = bounds.minX + bounds.width * radialGradient.centerPoint.x
        let centerY = bounds.minY + bounds.height * radialGradient.centerPoint.y
        let center = CGPoint(x: centerX, y: centerY)
        let maxRadius = min(bounds.width, bounds.height) * radialGradient.radius

        // Create polar mesh grid
        let angleStep = (2 * Double.pi) / Double(gridSize)
        let radiusStep = maxRadius / CGFloat(gridSize)

        // Draw from outside to inside
        for r in (0..<gridSize).reversed() {
            let innerRadius = CGFloat(r) * radiusStep
            let outerRadius = CGFloat(r + 1) * radiusStep

            // Calculate gradient position
            let t = (Double(r) + 0.5) / Double(gridSize)
            let color = interpolateGradientColor(at: t, stops: stops, opacity: opacity)

            for a in 0..<gridSize {
                let angle1 = Double(a) * angleStep
                let angle2 = Double(a + 1) * angleStep

                // Create wedge path
                context.saveGState()

                let path = CGMutablePath()
                path.move(to: CGPoint(
                    x: center.x + innerRadius * cos(angle1),
                    y: center.y + innerRadius * sin(angle1)
                ))
                path.addArc(
                    center: center,
                    radius: outerRadius,
                    startAngle: angle1,
                    endAngle: angle2,
                    clockwise: false
                )
                path.addLine(to: CGPoint(
                    x: center.x + innerRadius * cos(angle2),
                    y: center.y + innerRadius * sin(angle2)
                ))
                if innerRadius > 0 {
                    path.addArc(
                        center: center,
                        radius: innerRadius,
                        startAngle: angle2,
                        endAngle: angle1,
                        clockwise: true
                    )
                }
                path.closeSubpath()

                context.addPath(path)
                context.setFillColor(color.cgColor)
                context.fillPath()

                context.restoreGState()
            }
        }
    }

    /// Draw gradient using CMYK color space for print workflows
    private static func drawPDFGradientAsCMYK(_ gradient: VectorGradient, in context: CGContext, bounds: CGRect, opacity: Double) {
        // CMYK color space is used for professional printing workflows
        // This creates smooth gradients in CMYK color space without banding

        let stops = gradient.stops
        guard !stops.isEmpty else {
            return
        }

        context.saveGState()
        context.clip(to: bounds)
        context.setAlpha(CGFloat(opacity))

        // Use CGGradient with CMYK color space for smooth gradients
        switch gradient {
        case .linear(let linearGradient):
            drawCMYKLinearGradient(linearGradient, stops: stops, in: context, bounds: bounds)
        case .radial(let radialGradient):
            drawCMYKRadialGradient(radialGradient, stops: stops, in: context, bounds: bounds)
        }

        context.restoreGState()
    }

    private static func drawCMYKLinearGradient(_ linearGradient: LinearGradient, stops: [GradientStop], in context: CGContext, bounds: CGRect) {
        // Calculate gradient endpoints
        let startX = bounds.minX + bounds.width * linearGradient.startPoint.x
        let startY = bounds.minY + bounds.height * linearGradient.startPoint.y
        let endX = bounds.minX + bounds.width * linearGradient.endPoint.x
        let endY = bounds.minY + bounds.height * linearGradient.endPoint.y

        let start = CGPoint(x: startX, y: startY)
        let end = CGPoint(x: endX, y: endY)

        // Create CMYK color space for print workflows
        let colorSpace = CGColorSpace(name: CGColorSpace.genericCMYK)!

        // Convert all stops to CMYK components
        var cmykComponents: [CGFloat] = []
        var locations: [CGFloat] = []

        for stop in stops {
            let color = NSColor(cgColor: stop.color.cgColor) ?? NSColor.black
            let rgb = color.usingColorSpace(.deviceRGB) ?? color

            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            rgb.getRed(&r, green: &g, blue: &b, alpha: &a)

            // Convert to CMYK
            let k = 1.0 - max(r, g, b)
            let c = k < 1.0 ? (1.0 - r - k) / (1.0 - k) : 0
            let m = k < 1.0 ? (1.0 - g - k) / (1.0 - k) : 0
            let y = k < 1.0 ? (1.0 - b - k) / (1.0 - k) : 0

            // Add CMYK + Alpha components
            cmykComponents.append(contentsOf: [c, m, y, k, CGFloat(stop.opacity)])
            locations.append(CGFloat(stop.position))
        }

        // Create gradient with CMYK colors
        if let gradient = CGGradient(colorSpace: colorSpace,
                                     colorComponents: cmykComponents,
                                     locations: locations,
                                     count: stops.count) {
            // Draw smooth gradient
            context.drawLinearGradient(gradient,
                                      start: start,
                                      end: end,
                                      options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
    }

    private static func drawCMYKRadialGradient(_ radialGradient: RadialGradient, stops: [GradientStop], in context: CGContext, bounds: CGRect) {
        // Calculate center and radius
        let centerX = bounds.minX + bounds.width * radialGradient.centerPoint.x
        let centerY = bounds.minY + bounds.height * radialGradient.centerPoint.y
        let center = CGPoint(x: centerX, y: centerY)
        let maxRadius = min(bounds.width, bounds.height) * radialGradient.radius

        // Create CMYK color space for print workflows
        let colorSpace = CGColorSpace(name: CGColorSpace.genericCMYK)!

        // Convert all stops to CMYK components
        var cmykComponents: [CGFloat] = []
        var locations: [CGFloat] = []

        for stop in stops {
            let color = NSColor(cgColor: stop.color.cgColor) ?? NSColor.black
            let rgb = color.usingColorSpace(.deviceRGB) ?? color

            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            rgb.getRed(&r, green: &g, blue: &b, alpha: &a)

            // Convert to CMYK
            let k = 1.0 - max(r, g, b)
            let c = k < 1.0 ? (1.0 - r - k) / (1.0 - k) : 0
            let m = k < 1.0 ? (1.0 - g - k) / (1.0 - k) : 0
            let y = k < 1.0 ? (1.0 - b - k) / (1.0 - k) : 0

            // Add CMYK + Alpha components
            cmykComponents.append(contentsOf: [c, m, y, k, CGFloat(stop.opacity)])
            locations.append(CGFloat(stop.position))
        }

        // Create gradient with CMYK colors
        if let gradient = CGGradient(colorSpace: colorSpace,
                                     colorComponents: cmykComponents,
                                     locations: locations,
                                     count: stops.count) {
            // Draw smooth gradient
            context.drawRadialGradient(gradient,
                                      startCenter: center,
                                      startRadius: 0,
                                      endCenter: center,
                                      endRadius: maxRadius,
                                      options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
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
