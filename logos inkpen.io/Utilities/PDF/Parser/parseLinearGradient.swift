//
//  parseLinearGradient.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import SwiftUI

extension PDFCommandParser {
    
    func parseLinearGradient(from dict: CGPDFDictionaryRef) -> VectorGradient? {
        // DEBUG: Print all available keys in the gradient dictionary
        Log.info("PDF: 🔍 Examining gradient dictionary keys:", category: .debug)
        CGPDFDictionaryApplyFunction(dict, { key, value, info in
            let keyString = String(cString: key)
            let valueType = CGPDFObjectGetType(value)
            Log.info("PDF: 📋 Key: '\(keyString)' Type: \(valueType)", category: .general)
            
            // Check for transform matrices
            if keyString == "Matrix" || keyString == "Transform" {
                var array: CGPDFArrayRef?
                if CGPDFObjectGetValue(value, .array, &array), let matrixArray = array {
                    let count = CGPDFArrayGetCount(matrixArray)
                    var matrixValues: [CGFloat] = []
                    for i in 0..<count {
                        var num: CGFloat = 0
                        CGPDFArrayGetNumber(matrixArray, i, &num)
                        matrixValues.append(num)
                    }
                    Log.info("PDF: 📐 Found transform matrix: \(matrixValues)", category: .general)
                }
            }
            
        }, nil)
        
        // Get coordinates array
        var coordsArray: CGPDFArrayRef?
        guard CGPDFDictionaryGetArray(dict, "Coords", &coordsArray),
              let coords = coordsArray else {
            return nil
        }
        
        var x0: CGFloat = 0, y0: CGFloat = 0, x1: CGFloat = 0, y1: CGFloat = 0
        CGPDFArrayGetNumber(coords, 0, &x0)
        CGPDFArrayGetNumber(coords, 1, &y0)
        CGPDFArrayGetNumber(coords, 2, &x1)
        CGPDFArrayGetNumber(coords, 3, &y1)
        
        Log.info("PDF: 📐 Raw gradient coordinates: (\(x0), \(y0)) -> (\(x1), \(y1))", category: .general)
        Log.info("PDF: 📏 Page size: \(pageSize.width) x \(pageSize.height)", category: .general)
        
        // Check if coordinates appear to be absolute (greater than 1.0) and normalize them
        // PDFs can contain gradients in either normalized (0-1) or absolute coordinates
        let needsNormalization = (abs(x0) > 1.0 || abs(y0) > 1.0 || abs(x1) > 1.0 || abs(y1) > 1.0)
        
        let startPoint: CGPoint
        let endPoint: CGPoint
        
        if needsNormalization && pageSize.width > 0 && pageSize.height > 0 {
            // For absolute coordinates (typically from our own PDFs):
            // Normalize to 0-1 range but DON'T use the Y-flipped coordinates
            // because our export already has the correct orientation
            startPoint = CGPoint(x: Double(x0 / pageSize.width), y: Double(y0 / pageSize.height))
            endPoint = CGPoint(x: Double(x1 / pageSize.width), y: Double(y1 / pageSize.height))
            Log.info("PDF: 🔄 Normalized absolute coordinates to unit space (keeping original Y orientation)", category: .general)
        } else {
            // For normalized coordinates (0-1 range):
            // Keep original coordinates without Y-flip
            startPoint = CGPoint(x: Double(x0), y: Double(y0))
            endPoint = CGPoint(x: Double(x1), y: Double(y1))
        }
        
        // Calculate the actual gradient angle from the original coordinates
        let deltaX = x1 - x0
        let deltaY = y1 - y0  // Always use original Y values
        let coordinateAngle = atan2(deltaY, deltaX) * 180.0 / .pi
        
        // CRITICAL: Use the transformation matrix rotation for the actual gradient angle
        // The CTM's b component is negated in PDF coordinate system, so we need to un-negate it
        let ctmAngle = atan2(-currentTransformMatrix.b, currentTransformMatrix.a) * 180.0 / .pi
        // Combine coordinate angle with CTM angle
        let angleDegrees = coordinateAngle + ctmAngle
        
        Log.info("PDF: 📍 Original PDF coordinates: (\(x0), \(y0)) -> (\(x1), \(y1))", category: .general)
        Log.info("PDF: 🔄 Final coordinates: (\(startPoint.x), \(startPoint.y)) -> (\(endPoint.x), \(endPoint.y))", category: .general)
        Log.info("PDF: 📊 Delta values: ΔX=\(deltaX), ΔY=\(deltaY)", category: .debug)
        Log.info("PDF: 📐 Coordinate angle: \(coordinateAngle)°, CTM angle (corrected): \(ctmAngle)°", category: .general)
        Log.info("PDF: 🎯 FINAL gradient angle: \(angleDegrees)° (coordinate + CTM)", category: .general)
        
        // Get function for color interpolation from the actual PDF data
        let stops = extractGradientStops(from: dict)
        
        var linearGradient = LinearGradient(
            startPoint: startPoint,
            endPoint: endPoint,
            stops: stops,
            spreadMethod: GradientSpreadMethod.pad
        )
        
        // CRITICAL: Override the calculated angle with the CTM-adjusted angle
        linearGradient.storedAngle = angleDegrees
        
        Log.info("PDF: Created linear gradient from (\(startPoint)) to (\(endPoint)) with \(stops.count) stops", category: .general)
        Log.info("PDF: ✅ Applied CTM-corrected angle: \(angleDegrees)° to gradient", category: .general)
        
        return .linear(linearGradient)
    }
}
