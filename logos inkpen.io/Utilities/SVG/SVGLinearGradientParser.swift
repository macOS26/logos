//
//  SVGLinearGradientParser.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 9/2/25.
//  Extracted from SVGParser.swift for better organization
//

import Foundation
import SwiftUI

extension SVGParser {
    
    // MARK: - Linear Gradient Parsing Methods
    
    internal func parseLinearGradient(attributes: [String: String]) {
        guard let id = attributes["id"] else {
            Log.fileOperation("⚠️ Linear gradient missing id attribute", level: .info)
            return
        }
        
        currentGradientId = id
        currentGradientType = "linearGradient"
        currentGradientAttributes = attributes
        currentGradientStops = []
        isParsingGradient = true
        
        Log.fileOperation("🎨 Parsing linear gradient: \(id)", level: .info)
        print("   - x1: \(attributes["x1"] ?? "0%"), y1: \(attributes["y1"] ?? "0%")")
        print("   - x2: \(attributes["x2"] ?? "100%"), y2: \(attributes["y2"] ?? "0%")")
        print("   - gradientUnits: \(attributes["gradientUnits"] ?? "objectBoundingBox")")
    }
    
    internal func finishLinearGradientElement(inheritedGradient: VectorGradient?) -> VectorGradient {
        let attributes = currentGradientAttributes
        
        let gradientUnits = parseGradientUnits(from: attributes)
        
        let x1Raw = attributes["x1"] ?? "0%"
        let y1Raw = attributes["y1"] ?? "0%"
        let x2Raw = attributes["x2"] ?? "100%"
        let y2Raw = attributes["y2"] ?? "0%"
        
        Log.fileOperation("🔧 Parsing coordinates: x1=\(x1Raw), y1=\(y1Raw), x2=\(x2Raw), y2=\(y2Raw), units=\(gradientUnits)", level: .info)
        
        let x1 = parseGradientCoordinate(x1Raw, gradientUnits: gradientUnits, isXCoordinate: true)
        let y1 = parseGradientCoordinate(y1Raw, gradientUnits: gradientUnits, isXCoordinate: false)
        let x2 = parseGradientCoordinate(x2Raw, gradientUnits: gradientUnits, isXCoordinate: true)
        let y2 = parseGradientCoordinate(y2Raw, gradientUnits: gradientUnits, isXCoordinate: false)
        
        Log.fileOperation("🔧 Parsed coordinates: x1=\(x1), y1=\(y1), x2=\(x2), y2=\(y2)", level: .info)
        
        let transformInfo = parseGradientTransformFromAttributes(attributes)
        
        let startPoint: CGPoint
        let endPoint: CGPoint
        
        if let inherited = inheritedGradient, case .linear(let inh) = inherited,
           attributes["x1"] == nil && attributes["y1"] == nil && attributes["x2"] == nil && attributes["y2"] == nil {
            startPoint = inh.startPoint
            endPoint = inh.endPoint
        } else {
            startPoint = CGPoint(x: x1, y: y1)
            endPoint = CGPoint(x: x2, y: y2)
        }
        
        var deltaX = x2 - x1
        var deltaY = y2 - y1
        
        if transformInfo.scaleX != 1.0 || transformInfo.scaleY != 1.0 {
            deltaX *= transformInfo.scaleX
            deltaY *= transformInfo.scaleY
        }
        
        var computedAngle = radiansToDegrees(atan2(deltaY, deltaX))
        
        if transformInfo.angle != 0.0 {
            computedAngle += transformInfo.angle
        }
        
        let angleDegrees = computedAngle
        
        print("🎯 GRADIENT FROM SVG: angle=\(String(format: "%.2f", angleDegrees))° (transform: \(transformInfo.angle)°)")
        print("   Start: (\(String(format: "%.3f", startPoint.x)), \(String(format: "%.3f", startPoint.y)))")
        print("   End: (\(String(format: "%.3f", endPoint.x)), \(String(format: "%.3f", endPoint.y)))")
        Log.fileOperation("🔥 FINAL GRADIENT: Linear gradient with original coordinates, stops=\(currentGradientStops.count)", level: .info)
        
        let spreadMethod = parseSpreadMethod(from: attributes)
        
        let originX = clamp((startPoint.x + endPoint.x) / 2.0, 0.0, 1.0)
        let originY = clamp((startPoint.y + endPoint.y) / 2.0, 0.0, 1.0)
        
        var linearGradient = LinearGradient(
            startPoint: startPoint,
            endPoint: endPoint,
            stops: currentGradientStops,
            spreadMethod: spreadMethod,
            units: .objectBoundingBox
        )
        
        if let inherited = inheritedGradient, case .linear(let inh) = inherited {
            if attributes["gradientUnits"] == nil { linearGradient.units = inh.units }
            if attributes["spreadMethod"] == nil { linearGradient.spreadMethod = inh.spreadMethod }
        }
        
        linearGradient.originPoint = CGPoint(x: originX, y: originY)
        linearGradient.angle = angleDegrees
        
        let vectorGradient = VectorGradient.linear(linearGradient)
        Log.info("✅ Created linear gradient: \(currentGradientId ?? "") with \(currentGradientStops.count) stops (FORCED objectBoundingBox)", category: .fileOperations)
        print("   - Start: \(startPoint), End: \(endPoint), Angle: \(String(format: "%.1f", angleDegrees))° (shape-relative)")
        
        return vectorGradient
    }
}