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
    
    internal func parsePoints(_ pointsString: String) -> [CGPoint] {
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
    internal func tokenizeSVGPath(_ pathData: String) -> [String] {
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
}