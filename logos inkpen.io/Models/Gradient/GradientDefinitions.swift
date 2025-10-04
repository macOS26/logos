//
//  GradientDefinitions.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI

// MARK: - Enhanced Professional Gradient System

/// Enhanced gradient stop with more professional features
struct GradientStop: Codable, Hashable, Identifiable {
    var id: UUID
    var position: Double // 0.0 to 1.0 (normalized position along gradient)
    var color: VectorColor
    var opacity: Double // Individual stop opacity (0.0 to 1.0)

    init(position: Double, color: VectorColor, opacity: Double = 1.0, id: UUID = UUID()) {
        self.id = id
        self.position = max(0.0, min(1.0, position)) // Clamp to 0-1 range
        self.color = color
        self.opacity = max(0.0, min(1.0, opacity))   // Clamp to 0-1 range
    }

    // CRITICAL FIX: Explicit CodingKeys to ensure ID is properly encoded/decoded
    private enum CodingKeys: String, CodingKey {
        case id, position, color, opacity
    }
}

/// Gradient spread method (how gradient extends beyond defined area)
enum GradientSpreadMethod: String, Codable, CaseIterable {
    case pad = "pad"           // Extend with end colors (default)
    case reflect = "reflect"   // Mirror the gradient 
    case `repeat` = "repeat"   // Repeat the gradient pattern
}

/// Gradient coordinate units (SVG specification)
enum GradientUnits: String, Codable {
    case objectBoundingBox = "objectBoundingBox" // Default: 0-1 relative to object bounds
    case userSpaceOnUse = "userSpaceOnUse"       // Absolute coordinates in user space
}

/// Enhanced linear gradient with professional features
struct LinearGradient: Codable, Hashable, Identifiable {
    var id: UUID
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
    
    init(startPoint: CGPoint, endPoint: CGPoint, stops: [GradientStop], spreadMethod: GradientSpreadMethod = .pad, units: GradientUnits = .objectBoundingBox, id: UUID = UUID()) {
        self.id = id
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

    // CRITICAL FIX: Explicit CodingKeys to ensure ID is properly encoded/decoded
    private enum CodingKeys: String, CodingKey {
        case id, startPoint, endPoint, stops, spreadMethod, units
        case originPoint, scaleX, scaleY, storedAngle, scale
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
        } else {
        }
        
    }
}

/// Enhanced radial gradient with professional features
struct RadialGradient: Codable, Hashable, Identifiable {
    var id: UUID
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
    
    init(centerPoint: CGPoint, radius: Double, stops: [GradientStop], focalPoint: CGPoint? = nil, spreadMethod: GradientSpreadMethod = .pad, units: GradientUnits = .objectBoundingBox, id: UUID = UUID()) {
        self.id = id
        self.centerPoint = centerPoint
        self.radius = max(0.0, radius)
        self.stops = stops.sorted { $0.position < $1.position } // Auto-sort stops by position for proper gradient rendering
        self.focalPoint = focalPoint
        self.spreadMethod = spreadMethod
        self.units = units
    }

    // CRITICAL FIX: Explicit CodingKeys to ensure ID is properly encoded/decoded
    private enum CodingKeys: String, CodingKey {
        case id, centerPoint, focalPoint, radius, stops, spreadMethod, units
        case originPoint, scaleX, scaleY, angle, scale
    }
}
