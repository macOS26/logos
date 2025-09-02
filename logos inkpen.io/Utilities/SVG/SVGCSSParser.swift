//
//  SVGCSSParser.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 9/2/25.
//

import Foundation

/// Helper class for parsing CSS styles within SVG documents
class SVGCSSParser {
    
    /// Parse CSS styles from CSS content string
    static func parseCSSStyles(_ cssContent: String) -> [String: [String: String]] {
        Log.fileOperation("🎨 Parsing CSS styles", level: .info)
        
        var cssStyles: [String: [String: String]] = [:]
        
        // Parse CSS rules from style content
        let rules = cssContent.components(separatedBy: "}")
        
        for rule in rules {
            let parts = rule.components(separatedBy: "{")
            if parts.count == 2 {
                let selector = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let declarations = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                
                var styles: [String: String] = [:]
                
                // Parse individual declarations
                let declParts = declarations.components(separatedBy: ";")
                for decl in declParts {
                    let keyValue = decl.components(separatedBy: ":")
                    if keyValue.count >= 2 {
                        let key = keyValue[0].trimmingCharacters(in: .whitespacesAndNewlines)
                        // Join back in case the value contains colons (like in URLs)
                        let value = keyValue[1...].joined(separator: ":").trimmingCharacters(in: .whitespacesAndNewlines)
                        styles[key] = value
                    }
                }
                
                cssStyles[selector] = styles
                Log.fileOperation("📋 Added CSS rule: \(selector) -> \(styles)", level: .info)
            }
        }
        
        Log.info("✅ CSS parsing complete - \(cssStyles.count) rules parsed", category: .fileOperations)
        return cssStyles
    }
    
    /// Apply space-separated CSS classes from a class attribute into an attribute dictionary
    static func applyCSSClasses(_ classAttr: String, cssStyles: [String: [String: String]], into attributes: inout [String: String]) {
        let classNames = classAttr.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        for cls in classNames {
            let selector = "." + cls
            if let classStyles = cssStyles[selector] {
                for (key, value) in classStyles {
                    if attributes[key] == nil { attributes[key] = value }
                }
            }
        }
        // Handle comma-joined selectors like ".st3, .st4"
        for (selector, styles) in cssStyles where selector.contains(",") {
            let selectors = selector.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            for cls in classNames {
                if selectors.contains("." + cls) {
                    for (key, value) in styles {
                        if attributes[key] == nil { attributes[key] = value }
                    }
                }
            }
        }
    }
    
    /// Parse inline style attribute into key-value pairs
    static func parseStyleAttribute(_ style: String) -> [String: String] {
        var result: [String: String] = [:]
        let declarations = style.components(separatedBy: ";")
        
        for declaration in declarations {
            let keyValue = declaration.components(separatedBy: ":")
            if keyValue.count >= 2 {
                let key = keyValue[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let value = keyValue[1...].joined(separator: ":").trimmingCharacters(in: .whitespacesAndNewlines)
                result[key] = value
            }
        }
        
        return result
    }
}