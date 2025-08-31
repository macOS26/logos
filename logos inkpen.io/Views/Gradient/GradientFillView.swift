//
//  GradientFillView.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/20/25.
//

// MARK: - NSViewRepresentable Gradient Renderer

import CoreGraphics
import SwiftUI

struct GradientFillView: NSViewRepresentable {
    let gradient: VectorGradient
    let path: CGPath

    func makeNSView(context: Context) -> GradientNSView {
        return GradientNSView(gradient: gradient, path: path)
    }

    func updateNSView(_ nsView: GradientNSView, context: Context) {
        nsView.gradient = gradient
        nsView.path = path
        nsView.needsDisplay = true
    }
}

struct GradientStrokeView: NSViewRepresentable {
    let gradient: VectorGradient
    let path: CGPath
    let strokeStyle: StrokeStyle

    func makeNSView(context: Context) -> GradientStrokeNSView {
        return GradientStrokeNSView(gradient: gradient, path: path, strokeStyle: strokeStyle)
    }

    func updateNSView(_ nsView: GradientStrokeNSView, context: Context) {
        nsView.gradient = gradient
        nsView.path = path
        nsView.strokeStyle = strokeStyle
        nsView.needsDisplay = true
    }
}

class GradientNSView: NSView {
    var gradient: VectorGradient
    var path: CGPath

    init(gradient: VectorGradient, path: CGPath) {
        self.gradient = gradient
        self.path = path
        super.init(frame: .zero)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool {
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        context.saveGState()
        
        // The path we receive is already pre-transformed into the document's coordinate space.
        // SwiftUI will handle scaling/offsetting this NSView. We just draw the path as-is.
        let pathBounds = path.boundingBoxOfPath

        // Create CGGradient with proper clear color handling
        let colors = gradient.stops.map { stop -> CGColor in
            if case .clear = stop.color {
                // For clear colors, use the clear color's cgColor directly (don't apply opacity)
                return stop.color.cgColor
            } else {
                // For non-clear colors, apply the stop opacity
                return stop.color.color.opacity(stop.opacity).cgColor ?? stop.color.cgColor
            }
        }
        let locations: [CGFloat] = gradient.stops.map { CGFloat($0.position) }
        guard let cgGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locations) else {
            context.restoreGState()
            return
        }
        
        // Add path for clipping
        context.addPath(path)
        context.clip()

        // Draw gradient
        switch gradient {
        case .linear(let linear):
            // FIXED: Use the same coordinate system as the preview and gradient edit tool
            // The origin point represents the center of the gradient, just like radial gradients
            let originX = linear.originPoint.x
            let originY = linear.originPoint.y
            
            // Apply scale factor to match the coordinate system
            let scale = CGFloat(linear.scaleX)
            let scaledOriginX = originX * scale
            let scaledOriginY = originY * scale
            
            // Calculate the center of the gradient in path coordinates
            let centerX = pathBounds.minX + pathBounds.width * scaledOriginX
            let centerY = pathBounds.minY + pathBounds.height * scaledOriginY
            
            // Use the stored angle instead of recalculating from coordinates
            // This preserves angles from PDF transformation matrices and other sources
            let gradientAngle = CGFloat(linear.storedAngle * .pi / 180.0)  // Convert degrees to radians
            let gradientVector = CGPoint(x: linear.endPoint.x - linear.startPoint.x, y: linear.endPoint.y - linear.startPoint.y)
            let gradientLength = sqrt(gradientVector.x * gradientVector.x + gradientVector.y * gradientVector.y)
            
            // Apply scale to gradient length
            let scaledLength = gradientLength * CGFloat(scale) * max(pathBounds.width, pathBounds.height)
            
            // Calculate start and end points
            let startX = centerX - cos(gradientAngle) * scaledLength / 2
            let startY = centerY - sin(gradientAngle) * scaledLength / 2
            let endX = centerX + cos(gradientAngle) * scaledLength / 2
            let endY = centerY + sin(gradientAngle) * scaledLength / 2
            
            let startPoint = CGPoint(x: startX, y: startY)
            let endPoint = CGPoint(x: endX, y: endY)
            
            context.drawLinearGradient(cgGradient, start: startPoint, end: endPoint, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

        case .radial(let radial):
            // FIXED: Radial gradient coordinate system - centerPoint is already in 0-1 range
            
            // FIXED: Origin point should NOT be scaled - it defines the center position
            let originX = radial.originPoint.x
            let originY = radial.originPoint.y
            
            // Calculate the center position in path coordinates (no scaling applied to position)
            let center = CGPoint(x: pathBounds.minX + pathBounds.width * originX,
                                 y: pathBounds.minY + pathBounds.height * originY)
            
            // Apply transforms for angle and aspect ratio support
            context.saveGState()
            
            // Translate to gradient center for transformation
            context.translateBy(x: center.x, y: center.y)
            
            // Apply rotation (convert degrees to radians)
            let angleRadians = CGFloat(radial.angle * .pi / 180.0)
            context.rotate(by: angleRadians)
            
            // Apply independent X/Y scaling (elliptical gradient) - this affects the shape, not the position
            let scaleX = CGFloat(radial.scaleX)
            let scaleY = CGFloat(radial.scaleY)
            context.scaleBy(x: scaleX, y: scaleY)
            
            // FIXED: Focal point should NOT be scaled - it's already in the correct coordinate space
            let focalPoint: CGPoint
            if let focal = radial.focalPoint {
                // Focal point is already in the correct coordinate space relative to center
                focalPoint = CGPoint(x: focal.x, y: focal.y)
            } else {
                // No focal point specified, use center
                focalPoint = CGPoint.zero
            }
            
            // Calculate radius - use the original calculation that was working before
            let radius = max(pathBounds.width, pathBounds.height) * CGFloat(radial.radius)
            
            // Draw gradient with focal point in original coordinate space
            context.drawRadialGradient(cgGradient, startCenter: focalPoint, startRadius: 0, endCenter: CGPoint.zero, endRadius: radius, options: [.drawsAfterEndLocation])
            
            context.restoreGState()
        }
        
        context.restoreGState()
    }
}

