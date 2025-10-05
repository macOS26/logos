//
//  GradientStrokeNSView.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/20/25.
//

import SwiftUI
import SwiftUI

class GradientStrokeNSView: NSView {
    var gradient: VectorGradient
    var path: CGPath
    var strokeStyle: StrokeStyle

    init(gradient: VectorGradient, path: CGPath, strokeStyle: StrokeStyle) {
        self.gradient = gradient
        self.path = path
        self.strokeStyle = strokeStyle
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
        
        // Set stroke properties
        context.setLineWidth(strokeStyle.width)
        context.setLineCap(strokeStyle.lineCap.cgLineCap)
        context.setLineJoin(strokeStyle.lineJoin.cgLineJoin)
        context.setMiterLimit(strokeStyle.miterLimit)
        
        // Use CoreGraphics native gradient stroke support
        // Set the gradient as the stroke color
        context.setStrokeColorSpace(CGColorSpaceCreateDeviceRGB())
        
        // Draw gradient stroke using native CoreGraphics support
        switch gradient {
        case .linear(let linear):
            // Use CoreGraphics native gradient stroke
            context.addPath(path)
            context.replacePathWithStrokedPath()
            
            // Get the actual stroke outline bounds for proper gradient positioning
            let strokeBounds = context.boundingBoxOfPath
            
            // Calculate gradient coordinates based on the actual stroke outline bounds
            let startPoint = CGPoint(x: strokeBounds.minX, y: strokeBounds.minY + strokeBounds.height * CGFloat(linear.originPoint.y))
            let endPoint = CGPoint(x: strokeBounds.maxX, y: strokeBounds.minY + strokeBounds.height * CGFloat(linear.originPoint.y))
            
            context.clip()
            context.drawLinearGradient(cgGradient, start: startPoint, end: endPoint, options: [])
            
        case .radial(let radial):
            // Use CoreGraphics native gradient stroke
            context.addPath(path)
            context.replacePathWithStrokedPath()
            
            // Get the actual stroke outline bounds for proper gradient positioning
            let strokeBounds = context.boundingBoxOfPath
            
            // Calculate gradient coordinates based on the actual stroke outline bounds
            let center = CGPoint(x: strokeBounds.minX + strokeBounds.width * CGFloat(radial.originPoint.x),
                                y: strokeBounds.minY + strokeBounds.height * CGFloat(radial.originPoint.y))
            let radius = max(strokeBounds.width, strokeBounds.height) * CGFloat(radial.radius)
            
            context.clip()
            context.drawRadialGradient(cgGradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
        }
        
        context.restoreGState()
    }
}

    // MARK: - Oriented Bounding Box Calculation
    
    /// Calculate TRUE AXIS DETECTION for ANY shape on ANY axis/plane
    func calculateOrientedBoundingBox(for shape: VectorShape) -> [CGPoint] {
        Log.info("📐 TRUE AXIS DETECTION for \(shape.geometricType?.rawValue ?? "unknown")", category: .general)
        
        // NOTE: Warp objects are handled in initializeEnvelopeCorners() 
        // This function only handles fresh objects for TRUE AXIS DETECTION
        
        // Special handling for groups and compound shapes
        if shape.isGroup || shape.isGroupContainer {
            Log.info("   👥 GROUP/COMPOUND SHAPE: Using composite bounds", category: .general)
            let bounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
            
            // For groups, use the overall bounds (already computed across all grouped shapes)
            let objectSpaceCorners = [
                CGPoint(x: bounds.minX, y: bounds.minY), // Top-left
                CGPoint(x: bounds.maxX, y: bounds.minY), // Top-right
                CGPoint(x: bounds.maxX, y: bounds.maxY), // Bottom-right
                CGPoint(x: bounds.minX, y: bounds.maxY)  // Bottom-left
            ]
            
            // Apply group transform
            let worldSpaceCorners = objectSpaceCorners.map { corner in
                corner.applying(shape.transform)
            }
            
            Log.info("   📍 Group Bounds: (\(String(format: "%.1f", bounds.origin.x)), \(String(format: "%.1f", bounds.origin.y))) size (\(String(format: "%.1f", bounds.width)) × \(String(format: "%.1f", bounds.height)))", category: .general)
            Log.info("   📐 World Corners: [\(worldSpaceCorners.map { "(\(String(format: "%.1f", $0.x)),\(String(format: "%.1f", $0.y)))" }.joined(separator: ", "))]", category: .general)
            
            return worldSpaceCorners
        }
        
        // TRUE AXIS DETECTION: Extract actual path corners for rotated objects
        let pathElements = shape.path.elements
        var actualCorners: [CGPoint] = []
        
        Log.info("   🔍 EXTRACTING ACTUAL PATH CORNERS from \(pathElements.count) elements", category: .general)
        
        // Try to extract the actual corner points from the path
        for element in pathElements {
            switch element {
            case .move(let to):
                actualCorners.append(to.cgPoint)
                Log.info("     ➤ Move to: (\(String(format: "%.1f", to.cgPoint.x)), \(String(format: "%.1f", to.cgPoint.y)))", category: .general)
            case .line(let to):
                actualCorners.append(to.cgPoint)
                Log.info("     ➤ Line to: (\(String(format: "%.1f", to.cgPoint.x)), \(String(format: "%.1f", to.cgPoint.y)))", category: .general)
            case .curve(let to, _, _):
                actualCorners.append(to.cgPoint)
                Log.info("     ➤ Curve to: (\(String(format: "%.1f", to.cgPoint.x)), \(String(format: "%.1f", to.cgPoint.y)))", category: .general)
            case .quadCurve(let to, _):
                actualCorners.append(to.cgPoint)
                Log.info("     ➤ Quad curve to: (\(String(format: "%.1f", to.cgPoint.x)), \(String(format: "%.1f", to.cgPoint.y)))", category: .general)
            case .close:
                Log.info("     ➤ Close path", category: .general)
                break
            }
            
            // For rectangles and simple shapes, we expect 4 corners
            if actualCorners.count >= 4 && (shape.geometricType == .rectangle || pathElements.count <= 6) {
                break
            }
        }
        
        // TRUE AXIS DETECTION: Use actual path corners if we found them
        if actualCorners.count >= 4 && (shape.geometricType == .rectangle || shape.geometricType == .star || pathElements.count <= 8) {
            let detectedCorners = Array(actualCorners.prefix(4))
            Log.info("   ✅ TRUE AXIS DETECTION: Using ACTUAL PATH CORNERS", category: .general)
            Log.info("   📐 Detected Corners: [\(detectedCorners.map { "(\(String(format: "%.1f", $0.x)),\(String(format: "%.1f", $0.y)))" }.joined(separator: ", "))]", category: .general)
            return detectedCorners
        }
        
        // FALLBACK: Use transformed bounds for complex shapes
        Log.info("   ⚠️ FALLBACK: Using transformed bounds for complex shape", category: .general)
        let objectSpaceBounds = shape.path.cgPath.boundingBoxOfPath
        
        // Create the 4 corners of the bounding box in object space
        let objectSpaceCorners = [
            CGPoint(x: objectSpaceBounds.minX, y: objectSpaceBounds.minY), // Top-left
            CGPoint(x: objectSpaceBounds.maxX, y: objectSpaceBounds.minY), // Top-right
            CGPoint(x: objectSpaceBounds.maxX, y: objectSpaceBounds.maxY), // Bottom-right
            CGPoint(x: objectSpaceBounds.minX, y: objectSpaceBounds.maxY)  // Bottom-left
        ]
        
        // Apply the shape's transform to get world space coordinates
        let worldSpaceCorners = objectSpaceCorners.map { corner in
            corner.applying(shape.transform)
        }
        
        Log.info("   📍 Object Bounds: (\(String(format: "%.1f", objectSpaceBounds.origin.x)), \(String(format: "%.1f", objectSpaceBounds.origin.y))) size (\(String(format: "%.1f", objectSpaceBounds.width)) × \(String(format: "%.1f", objectSpaceBounds.height)))", category: .general)
        Log.info("   🔄 Transform: [\(String(format: "%.3f", shape.transform.a)), \(String(format: "%.3f", shape.transform.b)), \(String(format: "%.3f", shape.transform.c)), \(String(format: "%.3f", shape.transform.d)), \(String(format: "%.1f", shape.transform.tx)), \(String(format: "%.1f", shape.transform.ty))]", category: .general)
        Log.info("   📐 World Corners: [\(worldSpaceCorners.map { "(\(String(format: "%.1f", $0.x)),\(String(format: "%.1f", $0.y)))" }.joined(separator: ", "))]", category: .general)
        return worldSpaceCorners
    }
