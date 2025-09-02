//
//  SVGGradientHelpers.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 9/2/25.
//  Extracted from SVGParser.swift for better organization
//

import Foundation
import SwiftUI

extension SVGParser {
    
    // MARK: - Helper Computed Properties and Functions
    
    internal func parseGradientUnits(from attributes: [String: String]) -> GradientUnits {
        return GradientUnits(rawValue: attributes["gradientUnits"] ?? "objectBoundingBox") ?? .objectBoundingBox
    }
    
    internal func parseSpreadMethod(from attributes: [String: String]) -> GradientSpreadMethod {
        return GradientSpreadMethod(rawValue: attributes["spreadMethod"] ?? "pad") ?? .pad
    }
    
    internal func degreesToRadians(_ degrees: Double) -> Double {
        return degrees * .pi / 180.0
    }
    
    internal func radiansToDegrees(_ radians: Double) -> Double {
        return radians * 180.0 / .pi
    }
    
    internal func parseGradientTransformFromAttributes(_ attributes: [String: String]) -> (angle: Double, scaleX: Double, scaleY: Double) {
        var gradientAngle: Double = 0.0
        var gradientScaleX: Double = 1.0
        var gradientScaleY: Double = 1.0
        
        if let gradientTransformRaw = attributes["gradientTransform"] {
            Log.fileOperation("🔄 Parsing gradientTransform: \(gradientTransformRaw)", level: .info)
            let transforms = parseGradientTransform(gradientTransformRaw)
            gradientAngle = transforms.angle
            gradientScaleX = transforms.scaleX
            gradientScaleY = transforms.scaleY
            Log.fileOperation("🔄 Extracted: angle=\(gradientAngle)°, scaleX=\(gradientScaleX), scaleY=\(gradientScaleY)", level: .info)
        }
        
        return (angle: gradientAngle, scaleX: gradientScaleX, scaleY: gradientScaleY)
    }
    
    internal func parseGradientStop(attributes: [String: String]) {
        guard isParsingGradient else { return }
        
        let offset = parseLength(attributes["offset"]) ?? 0.0
        var stopColor = VectorColor.black
        var stopOpacity = 1.0
        
        if let colorValue = attributes["stop-color"] {
            stopColor = parseColor(colorValue) ?? .black
        }
        
        if let opacityValue = attributes["stop-opacity"] {
            stopOpacity = parseLength(opacityValue) ?? 1.0
        }
        
        if let style = attributes["style"] {
            let styleDict = parseStyleAttribute(style)
            if let stopColorValue = styleDict["stop-color"] {
                stopColor = parseColor(stopColorValue) ?? stopColor
            }
            if let stopOpacityValue = styleDict["stop-opacity"] {
                stopOpacity = parseLength(stopOpacityValue) ?? stopOpacity
            }
        }
        
        let gradientStop = GradientStop(position: offset, color: stopColor, opacity: stopOpacity)
        currentGradientStops.append(gradientStop)
        
        Log.fileOperation("🎨 Added gradient stop: offset=\(offset), color=\(stopColor)", level: .info)
    }
    
    internal func parseGradientTransform(_ transform: String) -> (angle: Double, scaleX: Double, scaleY: Double) {
        var angle: Double = 0.0
        var scaleX: Double = 1.0
        var scaleY: Double = 1.0
        
        if let rotateMatch = transform.range(of: #"rotate\(([^)]+)\)"#, options: .regularExpression) {
            let rotateSubstring = String(transform[rotateMatch])
            let numbers = extractNumbers(from: rotateSubstring)
            if let rotateAngle = numbers.first {
                angle = -rotateAngle
                Log.fileOperation("🔄 Extracted rotation: \(rotateAngle)° -> angle: \(angle)°", level: .info)
            }
        }
        
        if let scaleMatch = transform.range(of: #"scale\(([^)]+)\)"#, options: .regularExpression) {
            let scaleSubstring = String(transform[scaleMatch])
            let numbers = extractNumbers(from: scaleSubstring)
            if numbers.count >= 2 {
                scaleX = numbers[0]
                scaleY = numbers[1]
                Log.fileOperation("🔄 Extracted scale: x=\(scaleX), y=\(scaleY)", level: .info)
            } else if numbers.count == 1 {
                scaleX = numbers[0]
                scaleY = numbers[0]
                Log.fileOperation("🔄 Extracted uniform scale: \(numbers[0])", level: .info)
            }
        }
        
        return (angle: angle, scaleX: scaleX, scaleY: scaleY)
    }
    
    internal func extractNumbers(from string: String) -> [Double] {
        let pattern = #"-?\d*\.?\d+"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(string.startIndex..<string.endIndex, in: string)
        let matches = regex.matches(in: string, range: range)
        
        return matches.compactMap { match in
            if let range = Range(match.range, in: string) {
                return Double(String(string[range]))
            }
            return nil
        }
    }
    
    internal func clamp(_ value: Double, _ minValue: Double, _ maxValue: Double) -> Double {
        return max(minValue, min(maxValue, value))
    }
    
    internal func parseStyleAttribute(_ style: String) -> [String: String] {
        var styleDict: [String: String] = [:]
        
        let declarations = style.components(separatedBy: ";")
        for declaration in declarations {
            let keyValue = declaration.components(separatedBy: ":")
            if keyValue.count >= 2 {
                let key = keyValue[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let value = keyValue[1...].joined(separator: ":").trimmingCharacters(in: .whitespacesAndNewlines)
                styleDict[key] = value
            }
        }
        
        return styleDict
    }
}