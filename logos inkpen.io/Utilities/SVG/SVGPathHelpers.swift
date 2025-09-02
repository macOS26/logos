//
//  SVGPathHelpers.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 9/2/25.
//  Extracted from SVGParser.swift for better organization
//

import Foundation

extension SVGParser {
    
    // MARK: - Path Helper Methods
    
    func parsePoints(_ pointsString: String) -> [CGPoint] {
        let coordinates = pointsString
            .replacingOccurrences(of: ",", with: " ")
            .split(separator: " ")
            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        
        var points: [CGPoint] = []
        for i in stride(from: 0, to: coordinates.count - 1, by: 2) {
            points.append(CGPoint(x: coordinates[i], y: coordinates[i + 1]))
        }
        
        return points
    }
    
    // MARK: - Professional SVG Path Tokenization
    func tokenizeSVGPath(_ pathData: String) -> [String] {
        var tokens: [String] = []
        let chars = Array(pathData)
        var i = 0
        
        while i < chars.count {
            let char = chars[i]
            
            // Skip whitespace and commas
            if char.isWhitespace || char == "," {
                i += 1
                continue
            }
            
            // Handle commands (letters)
            if char.isLetter {
                tokens.append(String(char))
                i += 1
                continue
            }
            
            // Handle numbers (including negative and decimal)
            if char.isNumber || char == "." || (char == "-" || char == "+") {
                var numberStr = ""
                var hasDecimal = false
                let _ = i  // Track starting index for potential debugging
                
                // Handle sign only if it's at the start of a number
                if char == "-" || char == "+" {
                    // Look ahead to see if this is actually a number
                    if i + 1 < chars.count && (chars[i + 1].isNumber || chars[i + 1] == ".") {
                        numberStr.append(char)
                        i += 1
                    } else {
                        // Not a number, skip this character
                        i += 1
                        continue
                    }
                }
                
                // Collect digits and decimal point
                while i < chars.count {
                    let currentChar = chars[i]
                    
                    if currentChar.isNumber {
                        numberStr.append(currentChar)
                        i += 1
                    } else if currentChar == "." && !hasDecimal {
                        // Only accept decimal point if followed by digit or if we haven't started collecting digits yet
                        if i + 1 < chars.count && chars[i + 1].isNumber || numberStr.isEmpty || numberStr == "-" || numberStr == "+" {
                            numberStr.append(currentChar)
                            hasDecimal = true
                            i += 1
                        } else {
                            break
                        }
                    } else {
                        break
                    }
                }
                
                // Handle scientific notation (e/E)
                if i < chars.count && (chars[i] == "e" || chars[i] == "E") {
                    numberStr.append(chars[i])
                    i += 1
                    
                    // Handle sign after e/E
                    if i < chars.count && (chars[i] == "+" || chars[i] == "-") {
                        numberStr.append(chars[i])
                        i += 1
                    }
                    
                    // Collect exponent digits
                    while i < chars.count && chars[i].isNumber {
                        numberStr.append(chars[i])
                        i += 1
                    }
                }
                
                // Only add if we actually collected a valid number
                if !numberStr.isEmpty && numberStr != "-" && numberStr != "+" {
                    tokens.append(numberStr)
                }
                continue
            }
            
            // Unknown character, skip it
            i += 1
        }
        
        return tokens
    }
    
    // MARK: - SVG Path Data Parsing
    func parsePathData(_ pathData: String) -> [PathElement] {
        var elements: [PathElement] = []
        var currentPoint = CGPoint.zero
        var subpathStart = CGPoint.zero
        var lastControlPoint: CGPoint?
        
        Log.info("🔍 RAW PATH DATA: \(pathData.prefix(100))...", category: .general)
        
        // Professional SVG tokenization using proper regex patterns
        let tokens = tokenizeSVGPath(pathData)
        Log.fileOperation("🎯 FIRST 15 TOKENS: \(tokens.prefix(15))", level: .info)
        
        // Check for basic parsing issues
        var coordinateCount = 0
        var commandCount = 0
        for token in tokens {
            if token.rangeOfCharacter(from: .letters) != nil {
                commandCount += 1
            } else if Double(token) != nil {
                coordinateCount += 1
            }
        }
        Log.fileOperation("📊 PARSED: \(commandCount) commands, \(coordinateCount) coordinates", level: .info)
        
        var i = 0
        var currentCommand: String = ""
        
        while i < tokens.count {
            let token = tokens[i]
            
            // Check if this is a command or a parameter
            if token.rangeOfCharacter(from: .letters) != nil {
                // It's a command
                currentCommand = token
                Log.fileOperation("🔧 COMMAND: \(currentCommand)", level: .info)
                i += 1
                continue
            }
            
            // It's a parameter - process based on current command
            switch currentCommand {
            case "M": // Move to (absolute)
                if i + 1 < tokens.count {
                    let x = Double(tokens[i]) ?? 0
                    let y = Double(tokens[i + 1]) ?? 0
                    Log.info("   Move to: (\(x), \(y))", category: .general)
                    currentPoint = CGPoint(x: x, y: y)
                    subpathStart = currentPoint
                    elements.append(.move(to: VectorPoint(currentPoint)))
                    i += 2
                    // After first moveto, subsequent coordinate pairs are treated as lineto
                    currentCommand = "L"
                } else {
                    Log.info("   ⚠️ Not enough tokens for M command", category: .general)
                    i += 1
                }
                
            case "m": // Move to (relative)
                if i + 1 < tokens.count {
                    let dx = Double(tokens[i]) ?? 0
                    let dy = Double(tokens[i + 1]) ?? 0
                    currentPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y + dy)
                    subpathStart = currentPoint
                    elements.append(.move(to: VectorPoint(currentPoint)))
                    i += 2
                    currentCommand = "l"
                } else {
                    i += 1
                }
                
            case "L": // Line to (absolute)
                if i + 1 < tokens.count {
                    let x = Double(tokens[i]) ?? 0
                    let y = Double(tokens[i + 1]) ?? 0
                    Log.info("   Line to: (\(x), \(y))", category: .general)
                    currentPoint = CGPoint(x: x, y: y)
                    lastControlPoint = nil // Reset control point after line command
                    elements.append(.line(to: VectorPoint(currentPoint)))
                    i += 2
                } else {
                    Log.info("   ⚠️ Not enough tokens for L command", category: .general)
                    i += 1
                }
                
            case "l": // Line to (relative)
                if i + 1 < tokens.count {
                    let dx = Double(tokens[i]) ?? 0
                    let dy = Double(tokens[i + 1]) ?? 0
                    currentPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y + dy)
                    lastControlPoint = nil // Reset control point after line command
                    elements.append(.line(to: VectorPoint(currentPoint)))
                    i += 2
                } else {
                    i += 1
                }
                
            case "H": // Horizontal line to (absolute)
                if i < tokens.count {
                    let x = Double(tokens[i]) ?? 0
                    currentPoint = CGPoint(x: x, y: currentPoint.y)
                    lastControlPoint = nil // Reset control point after line command
                    elements.append(.line(to: VectorPoint(currentPoint)))
                    i += 1
                } else {
                    i += 1
                }
                
            case "h": // Horizontal line to (relative)
                if i < tokens.count {
                    let dx = Double(tokens[i]) ?? 0
                    currentPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y)
                    lastControlPoint = nil // Reset control point after line command
                    elements.append(.line(to: VectorPoint(currentPoint)))
                    i += 1
                } else {
                    i += 1
                }
                
            case "V": // Vertical line to (absolute)
                if i < tokens.count {
                    let y = Double(tokens[i]) ?? 0
                    currentPoint = CGPoint(x: currentPoint.x, y: y)
                    lastControlPoint = nil // Reset control point after line command
                    elements.append(.line(to: VectorPoint(currentPoint)))
                    i += 1
                } else {
                    i += 1
                }
                
            case "v": // Vertical line to (relative)
                if i < tokens.count {
                    let dy = Double(tokens[i]) ?? 0
                    currentPoint = CGPoint(x: currentPoint.x, y: currentPoint.y + dy)
                    lastControlPoint = nil // Reset control point after line command
                    elements.append(.line(to: VectorPoint(currentPoint)))
                    i += 1
                } else {
                    i += 1
                }
                
            case "C": // Cubic bezier curve (absolute)
                if i + 5 < tokens.count {
                    let x1 = Double(tokens[i]) ?? 0
                    let y1 = Double(tokens[i + 1]) ?? 0
                    let x2 = Double(tokens[i + 2]) ?? 0
                    let y2 = Double(tokens[i + 3]) ?? 0
                    let x = Double(tokens[i + 4]) ?? 0
                    let y = Double(tokens[i + 5]) ?? 0
                    
                    currentPoint = CGPoint(x: x, y: y)
                    lastControlPoint = CGPoint(x: x2, y: y2)
                    
                    elements.append(.curve(
                        to: VectorPoint(currentPoint),
                        control1: VectorPoint(x1, y1),
                        control2: VectorPoint(x2, y2)
                    ))
                    i += 6
                } else {
                    i += 1
                }
                
            case "c": // Cubic bezier curve (relative)
                if i + 5 < tokens.count {
                    let dx1 = Double(tokens[i]) ?? 0
                    let dy1 = Double(tokens[i + 1]) ?? 0
                    let dx2 = Double(tokens[i + 2]) ?? 0
                    let dy2 = Double(tokens[i + 3]) ?? 0
                    let dx = Double(tokens[i + 4]) ?? 0
                    let dy = Double(tokens[i + 5]) ?? 0
                    
                    let x1 = currentPoint.x + dx1
                    let y1 = currentPoint.y + dy1
                    let x2 = currentPoint.x + dx2
                    let y2 = currentPoint.y + dy2
                    let newPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y + dy)
                    
                    Log.info("   Curve from (\(currentPoint.x), \(currentPoint.y)) to (\(newPoint.x), \(newPoint.y))", category: .general)
                    Log.info("   Controls: (\(x1), \(y1)), (\(x2), \(y2))", category: .general)
                    
                    currentPoint = newPoint
                    lastControlPoint = CGPoint(x: x2, y: y2)
                    
                    elements.append(.curve(
                        to: VectorPoint(currentPoint),
                        control1: VectorPoint(x1, y1),
                        control2: VectorPoint(x2, y2)
                    ))
                    i += 6
                } else {
                    Log.info("   ⚠️ Not enough tokens for c command", category: .general)
                    i += 1
                }
                
            case "S": // Smooth cubic bezier curve (absolute)
                while i + 3 < tokens.count && tokens[i].rangeOfCharacter(from: .letters) == nil {
                    let x2 = Double(tokens[i]) ?? 0
                    let y2 = Double(tokens[i + 1]) ?? 0
                    let x = Double(tokens[i + 2]) ?? 0
                    let y = Double(tokens[i + 3]) ?? 0
                    
                    // Calculate reflected control point - if no previous control point, use current point
                    let x1: Double
                    let y1: Double
                    
                    if let lastCP = lastControlPoint {
                        // Reflect the previous control point across the current point
                        x1 = 2 * currentPoint.x - lastCP.x
                        y1 = 2 * currentPoint.y - lastCP.y
                    } else {
                        // No previous control point, use current point (creates a straight line start)
                        x1 = currentPoint.x
                        y1 = currentPoint.y
                    }
                    
                    Log.info("   Smooth curve from (\(currentPoint.x), \(currentPoint.y)) to (\(x), \(y))", category: .general)
                    Log.info("   Controls: (\(x1), \(y1)), (\(x2), \(y2))", category: .general)
                    
                    currentPoint = CGPoint(x: x, y: y)
                    lastControlPoint = CGPoint(x: x2, y: y2)
                    
                    elements.append(.curve(
                        to: VectorPoint(currentPoint),
                        control1: VectorPoint(x1, y1),
                        control2: VectorPoint(x2, y2)
                    ))
                    i += 4
                }
                
            case "s": // Smooth cubic bezier curve (relative)
                while i + 3 < tokens.count && tokens[i].rangeOfCharacter(from: .letters) == nil {
                    let dx2 = Double(tokens[i]) ?? 0
                    let dy2 = Double(tokens[i + 1]) ?? 0
                    let dx = Double(tokens[i + 2]) ?? 0
                    let dy = Double(tokens[i + 3]) ?? 0
                    
                    // Calculate reflected control point - if no previous control point, use current point
                    let reflectedX: Double
                    let reflectedY: Double
                    
                    if let lastCP = lastControlPoint {
                        // CRITICAL FIX: Reflect the previous control point across the current point
                        reflectedX = 2.0 * currentPoint.x - lastCP.x
                        reflectedY = 2.0 * currentPoint.y - lastCP.y
                    } else {
                        // No previous control point, use current point (creates a straight line start)
                        reflectedX = currentPoint.x
                        reflectedY = currentPoint.y
                    }
                    
                    // Calculate second control point (relative to current point)
                    let secondControlX = currentPoint.x + dx2
                    let secondControlY = currentPoint.y + dy2
                    
                    // Calculate end point (relative to current point)
                    let endX = currentPoint.x + dx
                    let endY = currentPoint.y + dy
                    
                    // Create explicit VectorPoint objects to avoid any variable mixup
                    let firstControl = VectorPoint(reflectedX, reflectedY)
                    let secondControl = VectorPoint(secondControlX, secondControlY)
                    let endPointVector = VectorPoint(endX, endY)
                    
                    // Update state
                    currentPoint = CGPoint(x: endX, y: endY)
                    lastControlPoint = CGPoint(x: secondControlX, y: secondControlY)
                    
                    // Create curve element with explicit control point order
                    // SVG 's' command: control1 = reflected, control2 = second control
                    let smoothCurveElement = PathElement.curve(
                        to: endPointVector,
                        control1: firstControl,
                        control2: secondControl
                    )
                    
                    elements.append(smoothCurveElement)
                    i += 4
                }
                
            case "Q": // Quadratic bezier curve (absolute)
                if i + 3 < tokens.count {
                    let x1 = Double(tokens[i]) ?? 0
                    let y1 = Double(tokens[i + 1]) ?? 0
                    let x = Double(tokens[i + 2]) ?? 0
                    let y = Double(tokens[i + 3]) ?? 0
                    
                    currentPoint = CGPoint(x: x, y: y)
                    lastControlPoint = CGPoint(x: x1, y: y1)
                    
                    elements.append(.quadCurve(
                        to: VectorPoint(currentPoint),
                        control: VectorPoint(x1, y1)
                    ))
                    i += 4
                } else {
                    i += 1
                }
                
            case "q": // Quadratic bezier curve (relative)
                if i + 3 < tokens.count {
                    let dx1 = Double(tokens[i]) ?? 0
                    let dy1 = Double(tokens[i + 1]) ?? 0
                    let dx = Double(tokens[i + 2]) ?? 0
                    let dy = Double(tokens[i + 3]) ?? 0
                    
                    let x1 = currentPoint.x + dx1
                    let y1 = currentPoint.y + dy1
                    currentPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y + dy)
                    lastControlPoint = CGPoint(x: x1, y: y1)
                    
                    elements.append(.quadCurve(
                        to: VectorPoint(currentPoint),
                        control: VectorPoint(x1, y1)
                    ))
                    i += 4
                } else {
                    i += 1
                }
                
            case "Z", "z": // Close path
                Log.info("   Close path", category: .general)
                elements.append(.close)
                currentPoint = subpathStart
                lastControlPoint = nil
                i += 1
                
            default:
                // Skip unknown commands
                i += 1
            }
        }
        
        Log.info("🏁 FINAL ELEMENTS: \(elements.count) total", category: .general)
        for (index, element) in elements.enumerated() {
            Log.info("  [\(index)] \(element)", category: .general)
        }
        return elements
    }
}