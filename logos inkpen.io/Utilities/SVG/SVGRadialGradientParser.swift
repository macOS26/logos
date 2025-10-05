//
//  SVGRadialGradientParser.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 9/2/25.
//  Extracted from SVGParser.swift for better organization
//

import SwiftUI

extension SVGParser {
    
    // MARK: - Radial Gradient Parsing Methods
    
    internal func parseRadialGradientCoordinates(from attributes: [String: String]) -> (cx: String, cy: String, r: String, fx: String?, fy: String?) {
        return (
            cx: attributes["cx"] ?? "50%",
            cy: attributes["cy"] ?? "50%", 
            r: attributes["r"] ?? "50%",
            fx: attributes["fx"],
            fy: attributes["fy"]
        )
    }
    
    internal func parseRadialGradient(attributes: [String: String]) {
        guard let id = attributes["id"] else {
            Log.fileOperation("⚠️ Radial gradient missing id attribute", level: .info)
            return
        }
        
        currentGradientId = id
        currentGradientType = "radialGradient"
        currentGradientAttributes = attributes
        currentGradientStops = []
        isParsingGradient = true
        
        let (cxRaw, cyRaw, rRaw, fxRaw, fyRaw) = parseRadialGradientCoordinates(from: attributes)
        
        let hasExtremeValues = detectExtremeValuesInRadialGradient(
            cx: cxRaw, cy: cyRaw, r: rRaw, fx: fxRaw, fy: fyRaw
        )
        
        if hasExtremeValues {
            detectedExtremeValues = true
            useExtremeValueHandling = true
            Log.fileOperation("🚨 EXTREME VALUES DETECTED in radial gradient: \(id)", level: .info)
            Log.info("   Enabling extreme value handling for this gradient", category: .general)
        }
        
        Log.fileOperation("🎨 Parsing radial gradient: \(id) (extreme handling: \(useExtremeValueHandling))", level: .info)
    }
    
    internal func detectExtremeValuesInRadialGradient(cx: String, cy: String, r: String, fx: String?, fy: String?) -> Bool {
        let coordinates = [cx, cy, r, fx, fy].compactMap { $0 }
        
        for coord in coordinates {
            if coord.hasSuffix("%") { continue }
            
            if let value = Double(coord) {
                if value < -10000 || value > 10000 {
                    Log.fileOperation("🚨 EXTREME VALUE DETECTED: \(coord) = \(value)", level: .info)
                    return true
                }
                
                if viewBoxWidth > 0 && viewBoxHeight > 0 {
                    let normalizer = coord == cx || coord == fx ? viewBoxWidth : viewBoxHeight
                    let normalizedValue = value / normalizer
                    
                    if normalizedValue < 0.0 || normalizedValue > 1.0 {
                        Log.fileOperation("🚨 NORMALIZED VALUE OUT OF RANGE: \(coord) = \(value) → \(normalizedValue) (not 0-1)", level: .info)
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    internal func finishRadialGradientElement(inheritedGradient: VectorGradient?) -> VectorGradient {
        let attributes = currentGradientAttributes
        
        let gradientUnits = parseGradientUnits(from: attributes)
        
        let (cxRaw, cyRaw, rRaw, fxRaw, fyRaw) = parseRadialGradientCoordinates(from: attributes)
        
        Log.fileOperation("🔧 Parsing radial coordinates: cx=\(cxRaw), cy=\(cyRaw), r=\(rRaw), units=\(gradientUnits)", level: .info)
        
        let useExtremeHandling = useExtremeValueHandling && detectedExtremeValues
        
        let cx = parseGradientCoordinate(cxRaw, gradientUnits: gradientUnits, isXCoordinate: true, useExtremeValueHandling: useExtremeHandling)
        let cy = parseGradientCoordinate(cyRaw, gradientUnits: gradientUnits, isXCoordinate: false, useExtremeValueHandling: useExtremeHandling)
        let r = parseGradientCoordinate(rRaw, gradientUnits: gradientUnits, isXCoordinate: true, useExtremeValueHandling: useExtremeHandling)
        
        let fx = fxRaw != nil ? parseGradientCoordinate(fxRaw!, gradientUnits: gradientUnits, isXCoordinate: true, useExtremeValueHandling: useExtremeHandling) : cx
        let fy = fyRaw != nil ? parseGradientCoordinate(fyRaw!, gradientUnits: gradientUnits, isXCoordinate: false, useExtremeValueHandling: useExtremeHandling) : cy
        
        Log.fileOperation("🔧 Parsed radial coordinates: cx=\(cx), cy=\(cy), r=\(r), fx=\(fx), fy=\(fy)", level: .info)
        Log.info("🔧 Raw values: cxRaw=\(cxRaw), cyRaw=\(cyRaw), rRaw=\(rRaw), fxRaw=\(fxRaw ?? "nil"), fyRaw=\(fyRaw ?? "nil")", category: .general)
        
        var centerPoint: CGPoint
        var focalPoint: CGPoint
        
        if useExtremeHandling {
            centerPoint = CGPoint(x: 0.5, y: 0.5)
            focalPoint = CGPoint(x: 0.5, y: 0.5)
            Log.fileOperation("🎯 AUTO-CENTERED RADIAL: center=(0.5,0.5), focal=(0.5,0.5) (extreme value mode)", level: .info)
        } else {
            centerPoint = CGPoint(x: cx, y: cy)
            focalPoint = CGPoint(x: fx, y: fy)
            Log.fileOperation("🎯 STANDARD RADIAL: center=(\(cx),\(cy)), focal=(\(fx),\(fy))", level: .info)
        }
        
        let finalRadius: Double
        if useExtremeHandling {
            finalRadius = 0.5
            Log.fileOperation("🎯 AUTO-CENTERED RADIAL: radius=0.5 (spans center to object edge)", level: .info)
        } else {
            finalRadius = r
            Log.fileOperation("🎯 STANDARD RADIAL: radius=\(r)", level: .info)
        }
        
        Log.fileOperation("🎯 GRADIENT COORDINATES: center=(\(centerPoint.x),\(centerPoint.y)), focal=(\(focalPoint.x),\(focalPoint.y)), radius=\(finalRadius)", level: .info)
        Log.info("   Original: cx=\(cxRaw), cy=\(cyRaw), r=\(rRaw), fx=\(fxRaw ?? "nil"), fy=\(fyRaw ?? "nil")", category: .general)
        Log.info("   Converted: cx=\(cx), cy=\(cy), r=\(r), fx=\(fx), fy=\(fy)", category: .general)
        Log.info("   Final: center=(\(centerPoint.x),\(centerPoint.y)), radius=\(finalRadius)", category: .general)
        Log.info("   Units: \(gradientUnits) - parseGradientCoordinate handled conversion", category: .general)
        
        let spreadMethod = parseSpreadMethod(from: attributes)
        
        let (gradientAngle, gradientScaleX, gradientScaleY) = parseGradientTransformFromAttributes(attributes)
        
        var radialGradient = RadialGradient(
            centerPoint: centerPoint,
            radius: max(0.001, finalRadius),
            stops: currentGradientStops,
            focalPoint: focalPoint,
            spreadMethod: spreadMethod,
            units: .objectBoundingBox
        )
        
        if let inherited = inheritedGradient, case .radial(let inh) = inherited {
            if attributes["cx"] == nil && attributes["cy"] == nil { radialGradient.centerPoint = inh.centerPoint }
            if attributes["r"] == nil { radialGradient.radius = inh.radius }
            if attributes["gradientUnits"] == nil { radialGradient.units = inh.units }
            if attributes["spreadMethod"] == nil { radialGradient.spreadMethod = inh.spreadMethod }
        }
        
        radialGradient.originPoint = centerPoint
        radialGradient.angle = gradientAngle
        radialGradient.scaleX = abs(gradientScaleX)
        radialGradient.scaleY = abs(gradientScaleY)
        
        let vectorGradient = VectorGradient.radial(radialGradient)
        Log.info("✅ Created radial gradient: \(currentGradientId ?? "") with \(currentGradientStops.count) stops (FORCED objectBoundingBox)", category: .fileOperations)
        Log.info("   - Center: \(centerPoint), Radius: \(String(format: "%.3f", finalRadius)) (shape-relative)", category: .general)
        Log.info("   - Origin Point: \(radialGradient.originPoint)", category: .general)
        Log.info("   - Scale: X=\(gradientScaleX), Y=\(gradientScaleY)", category: .general)
        if useExtremeHandling {
            Log.info("   - Mode: AUTO-CENTERED (extreme value handling)", category: .general)
        } else {
            Log.info("   - Mode: STANDARD (parsed coordinates)", category: .general)
        }
        if fxRaw != nil || fyRaw != nil {
            Log.info("   - Focal point: \(focalPoint)", category: .general)
        }
        
        return vectorGradient
    }
}
