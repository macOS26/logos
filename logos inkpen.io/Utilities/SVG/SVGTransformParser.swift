//
//  SVGTransformParser.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 9/2/25.
//  Extracted from SVGParser.swift for better organization
//

import SwiftUI

extension SVGParser {
    
    // MARK: - Transform Parsing Helper Methods
    
    func parseTransform(_ transformString: String) -> CGAffineTransform {
        // Professional SVG transform parsing that handles multiple transforms and proper order
        var transform = CGAffineTransform.identity
        
        // Split the transform string into individual transform functions
        let transformRegex = try! NSRegularExpression(pattern: "(\\w+)\\s*\\(([^)]*)\\)", options: [])
        let matches = transformRegex.matches(in: transformString, options: [], range: NSRange(location: 0, length: transformString.count))
        
        // Process transforms in order (they should be applied left to right)
        for match in matches {
            guard match.numberOfRanges >= 3 else { continue }
            
            let transformType = (transformString as NSString).substring(with: match.range(at: 1))
            let paramsString = (transformString as NSString).substring(with: match.range(at: 2))
            
            // Parse parameters - handle both comma and space separated values
            let params = paramsString
                .replacingOccurrences(of: ",", with: " ")
                .split(separator: " ")
                .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            
            switch transformType.lowercased() {
            case "translate":
                if params.count >= 2 {
                    transform = transform.translatedBy(x: params[0], y: params[1])
                } else if params.count == 1 {
                    transform = transform.translatedBy(x: params[0], y: 0)
                }
                
            case "scale":
                if params.count >= 2 {
                    transform = transform.scaledBy(x: params[0], y: params[1])
                } else if params.count == 1 {
                    transform = transform.scaledBy(x: params[0], y: params[0])
                }
                
            case "rotate":
                // Handle rotate(angle [cx cy])
                if params.count >= 3 {
                    // Rotation around a point: translate(-cx,-cy), rotate, translate(cx,cy)
                    let angle = degreesToRadians(params[0])
                    let cx = params[1]
                    let cy = params[2]
                    transform = transform.translatedBy(x: cx, y: cy)
                    transform = transform.rotated(by: angle)
                    transform = transform.translatedBy(x: -cx, y: -cy)
                } else if params.count >= 1 {
                    // Simple rotation around origin
                    let angle = degreesToRadians(params[0])
                    transform = transform.rotated(by: angle)
                }
                
            case "skewx":
                if params.count >= 1 {
                    let angle = degreesToRadians(params[0])
                    transform = CGAffineTransform(a: transform.a, b: transform.b,
                                                 c: transform.c + transform.a * tan(angle),
                                                 d: transform.d + transform.b * tan(angle),
                                                 tx: transform.tx, ty: transform.ty)
                }
                
            case "skewy":
                if params.count >= 1 {
                    let angle = degreesToRadians(params[0])
                    transform = CGAffineTransform(a: transform.a + transform.c * tan(angle),
                                                 b: transform.b + transform.d * tan(angle),
                                                 c: transform.c, d: transform.d,
                                                 tx: transform.tx, ty: transform.ty)
                }
                
            case "matrix":
                if params.count >= 6 {
                    // matrix(a b c d e f) maps to CGAffineTransform(a, b, c, d, tx, ty)
                    let newTransform = CGAffineTransform(a: params[0], b: params[1],
                                                        c: params[2], d: params[3],
                                                        tx: params[4], ty: params[5])
                    transform = transform.concatenating(newTransform)
                }
                
            default:
                Log.fileOperation("⚠️ Unknown transform type: \(transformType)", level: .info)
            }
        }
        
        return transform
    }
    
    // MARK: - Gradient Transform Parsing
    
    /// Helper function to parse gradient transform angle from attributes
    func parseGradientTransformAngle(from attributes: [String: String]) -> Double {
        var finalAngle = 0.0
        if let gradientTransform = attributes["gradientTransform"] {
            Log.fileOperation("🔧 Parsing gradientTransform: \(gradientTransform)", level: .info)
            
            // Parse rotate transform
            let rotatePattern = #"rotate\s*\(\s*([+-]?[0-9]*\.?[0-9]+)\s*\)"#
            if let regex = try? NSRegularExpression(pattern: rotatePattern, options: []),
               let match = regex.firstMatch(in: gradientTransform, options: [], range: NSRange(gradientTransform.startIndex..., in: gradientTransform)) {
                
                if let angleRange = Range(match.range(at: 1), in: gradientTransform) {
                    let angleStr = String(gradientTransform[angleRange])
                    if let transformAngle = Double(angleStr) {
                        finalAngle = transformAngle
                        Log.fileOperation("🔄 Found rotate transform: \(transformAngle)°", level: .info)
                    }
                }
            }
            
            // Parse scale transform to check for Y-flip
            let scalePattern = #"scale\s*\(\s*([+-]?[0-9]*\.?[0-9]+)\s*[,\s]+\s*([+-]?[0-9]*\.?[0-9]+)\s*\)"#
            if let regex = try? NSRegularExpression(pattern: scalePattern, options: []),
               let match = regex.firstMatch(in: gradientTransform, options: [], range: NSRange(gradientTransform.startIndex..., in: gradientTransform)) {
                
                if let scaleYRange = Range(match.range(at: 2), in: gradientTransform) {
                    let scaleYStr = String(gradientTransform[scaleYRange])
                    if let scaleY = Double(scaleYStr), scaleY < 0 {
                        Log.fileOperation("🔄 Found Y-flip scale: \(scaleY)", level: .info)
                    }
                }
            }
        }
        return finalAngle
    }
}
