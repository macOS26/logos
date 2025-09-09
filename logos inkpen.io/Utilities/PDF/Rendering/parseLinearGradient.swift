//
//  parseLinearGradient.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import Foundation
import SwiftUI
import CoreGraphics

extension PDFCommandParser {
    
    func parseLinearGradient(from dict: CGPDFDictionaryRef) -> VectorGradient? {
        // DEBUG: Print all available keys in the gradient dictionary
        print("PDF: 🔍 Examining gradient dictionary keys:")
        CGPDFDictionaryApplyFunction(dict, { key, value, info in
            let keyString = String(cString: key)
            let valueType = CGPDFObjectGetType(value)
            print("PDF: 📋 Key: '\(keyString)' Type: \(valueType)")
            
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
                    print("PDF: 📐 Found transform matrix: \(matrixValues)")
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
        
        print("PDF: 📐 Raw gradient coordinates: (\(x0), \(y0)) -> (\(x1), \(y1))")
        print("PDF: 📏 Page size: \(pageSize.width) x \(pageSize.height)")
        
        // Apply the same coordinate system transformation as other PDF elements
        // Transform coordinates: flip Y coordinate system (PDF has origin at bottom-left, we need top-left)
        let transformedY0 = pageSize.height - y0
        let transformedY1 = pageSize.height - y1
        
        let startPoint = CGPoint(x: Double(x0), y: Double(transformedY0))
        let endPoint = CGPoint(x: Double(x1), y: Double(transformedY1))
        
        // Calculate the actual gradient angle from the transformed vector
        let deltaX = x1 - x0
        let deltaY = transformedY1 - transformedY0  // Use transformed Y coordinates
        let coordinateAngle = atan2(deltaY, deltaX) * 180.0 / .pi
        
        // CRITICAL: Use the transformation matrix rotation for the actual gradient angle
        let ctmAngle = atan2(currentTransformMatrix.b, currentTransformMatrix.a) * 180.0 / .pi
        // No need to flip the CTM angle - use it directly
        let angleDegrees = coordinateAngle + ctmAngle
        
        print("PDF: 📍 Original PDF coordinates: (\(x0), \(y0)) -> (\(x1), \(y1))")
        print("PDF: 🔄 Transformed coordinates: (\(x0), \(transformedY0)) -> (\(x1), \(transformedY1))")
        print("PDF: 📊 Delta values: ΔX=\(deltaX), ΔY=\(deltaY)")
        print("PDF: 📐 Coordinate angle: \(coordinateAngle)°, CTM angle: \(ctmAngle)°")
        print("PDF: 🎯 FINAL gradient angle: \(angleDegrees)° (coordinate + CTM)")
        
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
        
        print("PDF: Created linear gradient from (\(startPoint)) to (\(endPoint)) with \(stops.count) stops")
        print("PDF: ✅ Applied CTM-corrected angle: \(angleDegrees)° to gradient")
        
        return .linear(linearGradient)
    }
}