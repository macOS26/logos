//
//  GradientStop.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation
import SwiftUI

// MARK: - Enhanced Professional Gradient System

/// Enhanced gradient stop with more professional features
struct GradientStop: Codable, Hashable, Identifiable {
    var id = UUID()
    var position: Double // 0.0 to 1.0 (normalized position along gradient)
    var color: VectorColor
    var opacity: Double // Individual stop opacity (0.0 to 1.0)
    
    init(position: Double, color: VectorColor, opacity: Double = 1.0) {
        self.position = max(0.0, min(1.0, position)) // Clamp to 0-1 range
        self.color = color
        self.opacity = max(0.0, min(1.0, opacity))   // Clamp to 0-1 range
    }
}

/// Gradient spread method (how gradient extends beyond defined area)
enum GradientSpreadMethod: String, Codable, CaseIterable {
    case pad = "pad"           // Extend with end colors (default)
    case reflect = "reflect"   // Mirror the gradient 
    case `repeat` = "repeat"   // Repeat the gradient pattern
    
    var description: String {
        switch self {
        case .pad: return "Pad"
        case .reflect: return "Reflect"
        case .`repeat`: return "Repeat"
        }
    }
}

/// Gradient coordinate units (SVG specification)
enum GradientUnits: String, Codable {
    case objectBoundingBox = "objectBoundingBox" // Default: 0-1 relative to object bounds
    case userSpaceOnUse = "userSpaceOnUse"       // Absolute coordinates in user space
}

/// Enhanced linear gradient with professional features
struct LinearGradient: Codable, Hashable, Identifiable {
    var id = UUID()
    var startPoint: CGPoint     // Start point (in unit coordinates 0-1)
    var endPoint: CGPoint       // End point (in unit coordinates 0-1)  
    var stops: [GradientStop]   // Unlimited color stops
    var spreadMethod: GradientSpreadMethod = .pad
    var units: GradientUnits = .objectBoundingBox
    
    // NEW: User control properties
    var originPoint: CGPoint = CGPoint(x: 0.5, y: 0.5)  // Origin point for gradient positioning
    var scale: Double = 1.0  // Scale factor (-200% to 200% = -2.0 to 2.0) - DEPRECATED, use scaleX/scaleY
    var scaleX: Double = 1.0  // Scale X factor (1% to 800% = 0.01 to 8.0)
    var scaleY: Double = 1.0  // Scale Y factor (1% to 800% = 0.01 to 8.0)
    
    // NEW: Store angle as a separate property to avoid recalculation issues
    var storedAngle: Double = 0.0
    
    init(startPoint: CGPoint, endPoint: CGPoint, stops: [GradientStop], spreadMethod: GradientSpreadMethod = .pad, units: GradientUnits = .objectBoundingBox) {
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.stops = stops.sorted { $0.position < $1.position } // Auto-sort stops by position for proper gradient rendering
        self.spreadMethod = spreadMethod
        self.units = units
        
        // Calculate and store the initial angle from the provided coordinates
        let deltaX = endPoint.x - startPoint.x
        let deltaY = endPoint.y - startPoint.y
        let radians = atan2(deltaY, deltaX)
        self.storedAngle = radians * 180.0 / .pi
    }
    
    /// Professional angle support -180° to +180° range
    var angle: Double {
        get {
            // Return the stored angle, not calculated from coordinates
            return storedAngle
        }
        set {
            setAngle(newValue)
        }
    }
    
    /// Set gradient angle while preserving gradient center
    mutating func setAngle(_ degrees: Double) {
        // Store the exact angle the user wants
        storedAngle = degrees
        
        let radians = degrees * .pi / 180.0
        
        // FIXED: Use originPoint as center, or calculate a properly normalized center
        var centerX = originPoint.x
        var centerY = originPoint.y
        
        // If start/end points are valid (within 0-1 range), use their midpoint as center
        if units == .objectBoundingBox && 
           startPoint.x >= 0 && startPoint.x <= 1 && startPoint.y >= 0 && startPoint.y <= 1 &&
           endPoint.x >= 0 && endPoint.x <= 1 && endPoint.y >= 0 && endPoint.y <= 1 {
            centerX = (startPoint.x + endPoint.x) / 2.0
            centerY = (startPoint.y + endPoint.y) / 2.0
        }
        
        // Calculate current gradient length (default to 0.25 for objectBoundingBox)
        let currentLength = sqrt(pow(endPoint.x - startPoint.x, 2) + pow(endPoint.y - startPoint.y, 2))
        let halfLength = currentLength > 0 ? currentLength / 2.0 : (units == .objectBoundingBox ? 0.25 : 50.0)
        
        // Calculate new start and end points based on angle
        let deltaX = cos(radians) * halfLength
        let deltaY = sin(radians) * halfLength
        
        startPoint = CGPoint(x: centerX - deltaX, y: centerY - deltaY)
        endPoint = CGPoint(x: centerX + deltaX, y: centerY + deltaY)
        
        // FIXED: Only clamp if using objectBoundingBox, allow userSpaceOnUse to extend beyond 0-1
        if units == .objectBoundingBox {
            startPoint.x = max(0, min(1, startPoint.x))
            startPoint.y = max(0, min(1, startPoint.y))
            endPoint.x = max(0, min(1, endPoint.x))
            endPoint.y = max(0, min(1, endPoint.y))
            Log.fileOperation("🔧 ANGLE SET: Clamped to objectBoundingBox range (0-1)", level: .info)
        } else {
            Log.fileOperation("🔧 ANGLE SET: userSpaceOnUse - coordinates can extend beyond 0-1", level: .info)
        }
        
        Log.fileOperation("🔧 ANGLE UPDATE: \(degrees)° → center=(\(centerX), \(centerY)), start=\(startPoint), end=\(endPoint)", level: .info)
    }
    
    /// Create a simple two-color linear gradient
    static func simple(from startColor: VectorColor, to endColor: VectorColor, angle: Double = 0) -> LinearGradient {
        let radians = angle * .pi / 180
        let endX = cos(radians) * 0.5 + 0.5
        let endY = sin(radians) * 0.5 + 0.5
        
        return LinearGradient(
            startPoint: CGPoint(x: 0.5 - (endX - 0.5), y: 0.5 - (endY - 0.5)),
            endPoint: CGPoint(x: endX, y: endY),
            stops: [
                GradientStop(position: 0.0, color: startColor),
                GradientStop(position: 1.0, color: endColor)
            ]
        )
    }
}

/// Enhanced radial gradient with professional features  
struct RadialGradient: Codable, Hashable, Identifiable {
    var id = UUID()
    var centerPoint: CGPoint           // Center of gradient (in unit coordinates 0-1)
    var focalPoint: CGPoint?           // Focal point for elliptical gradients (optional)
    var radius: Double                 // Radius (in unit coordinates 0-1)
    var stops: [GradientStop]          // Unlimited color stops
    var spreadMethod: GradientSpreadMethod = .pad
    var units: GradientUnits = .objectBoundingBox
    
    // NEW: User control properties
    var originPoint: CGPoint = CGPoint(x: 0.5, y: 0.5)  // Origin point for gradient positioning
    var scale: Double = 1.0  // Scale factor (-200% to 200% = -2.0 to 2.0) - DEPRECATED, use scaleX/scaleY
    var scaleX: Double = 1.0  // Scale X factor (1% to 800% = 0.01 to 8.0)
    var scaleY: Double = 1.0  // Scale Y factor (1% to 800% = 0.01 to 8.0)
    
    // NEW: Transform properties to
    var angle: Double = 0.0             // Rotation angle in degrees (-180 to 180)
    
    init(centerPoint: CGPoint, radius: Double, stops: [GradientStop], focalPoint: CGPoint? = nil, spreadMethod: GradientSpreadMethod = .pad, units: GradientUnits = .objectBoundingBox) {
        self.centerPoint = centerPoint
        self.radius = max(0.0, radius)
        self.stops = stops.sorted { $0.position < $1.position } // Auto-sort stops by position for proper gradient rendering
        self.focalPoint = focalPoint
        self.spreadMethod = spreadMethod
        self.units = units
    }
    
    /// Create a simple two-color radial gradient
    static func simple(from innerColor: VectorColor, to outerColor: VectorColor, center: CGPoint = CGPoint(x: 0.5, y: 0.5), radius: Double = 0.5) -> RadialGradient {
        return RadialGradient(
            centerPoint: center,
            radius: radius,
            stops: [
                GradientStop(position: 0.0, color: innerColor),
                GradientStop(position: 1.0, color: outerColor)
            ]
        )
    }
}

/// Enhanced vector gradient enum supporting professional gradient types
enum VectorGradient: Codable, Hashable {
    case linear(LinearGradient)
    case radial(RadialGradient)
    
    /// Get all color stops regardless of gradient type
    var stops: [GradientStop] {
        switch self {
        case .linear(let gradient):
            return gradient.stops
        case .radial(let gradient):
            return gradient.stops
        }
    }
    
    /// Get the primary color (first stop)
    var primaryColor: VectorColor {
        return stops.first?.color ?? .black
    }
    
    /// Check if gradient has multiple color stops
    var isMultiColor: Bool {
        return stops.count > 2
    }
    
    /// Get gradient type name
    var typeName: String {
        switch self {
        case .linear: return "Linear"
        case .radial: return "Radial"
        }
    }
    
    // Generate a stable signature used for deduplicating identical gradients across shapes
    var signature: String {
        func stopSig(_ s: GradientStop) -> String {
            switch s.color {
            case .rgb(let rgb):
                return String(format: "p=%.6f,r=%.6f,g=%.6f,b=%.6f,a=%.6f,so=%.6f", s.position, rgb.red, rgb.green, rgb.blue, rgb.alpha, s.opacity)
            case .cmyk(let c):
                return String(format: "p=%.6f,c=%.6f,m=%.6f,y=%.6f,k=%.6f,so=%.6f", s.position, c.cyan, c.magenta, c.yellow, c.black, s.opacity)
            case .hsb(let h):
                return String(format: "p=%.6f,h=%.6f,s=%.6f,b=%.6f,a=%.6f,so=%.6f", s.position, h.hue, h.saturation, h.brightness, h.alpha, s.opacity)
            case .appleSystem(let sys):
                return "p=\(s.position),sys=\(sys.name),so=\(s.opacity)"
            case .pantone(let p):
                return "p=\(s.position),pantone=\(p.pantone),so=\(s.opacity)"
            case .spot(let sp):
                return "p=\(s.position),spot=\(sp.name),so=\(s.opacity)"
            case .black:
                return "p=\(s.position),black,so=\(s.opacity)"
            case .white:
                return "p=\(s.position),white,so=\(s.opacity)"
            case .clear:
                return "p=\(s.position),clear,so=\(s.opacity)"
            case .gradient:
                return "p=\(s.position),gradref,so=\(s.opacity)"
            }
        }
        
        switch self {
        case .linear(let lg):
            let stopsSig = lg.stops.map(stopSig).joined(separator: "|")
            return String(format: "lin:x1=%.6f,y1=%.6f,x2=%.6f,y2=%.6f,units=%@,spread=%@,ox=%.6f,oy=%.6f,scx=%.6f,scy=%.6f,ang=%.6f::%@",
                          lg.startPoint.x, lg.startPoint.y, lg.endPoint.x, lg.endPoint.y,
                          lg.units.rawValue, lg.spreadMethod.rawValue,
                          lg.originPoint.x, lg.originPoint.y, lg.scaleX, lg.scaleY, lg.storedAngle, stopsSig)
        case .radial(let rg):
            let stopsSig = rg.stops.map(stopSig).joined(separator: "|")
            let fx = rg.focalPoint?.x ?? .nan
            let fy = rg.focalPoint?.y ?? .nan
            return String(format: "rad:cx=%.6f,cy=%.6f,r=%.6f,fx=%.6f,fy=%.6f,units=%@,spread=%@,ox=%.6f,oy=%.6f,scx=%.6f,scy=%.6f,ang=%.6f::%@",
                          rg.centerPoint.x, rg.centerPoint.y, rg.radius, fx, fy,
                          rg.units.rawValue, rg.spreadMethod.rawValue,
                          rg.originPoint.x, rg.originPoint.y, rg.scaleX, rg.scaleY, rg.angle, stopsSig)
        }
    }
}