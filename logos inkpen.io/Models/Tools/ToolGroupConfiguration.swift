import SwiftUI

/*
 🔧 CENTRALIZED TOOL GROUP CONFIGURATION
 
 This is the SINGLE SOURCE OF TRUTH for all tool groupings in the application.
 
 To modify tool groups, edit the `toolGroupConfig` dictionary below.
 
 Example:
 - Keep basic shapes together: [.rectangle, .square, .circle, .ellipse, .egg]
 - Separate polygons: [.polygon, .pentagon, .hexagon, .heptagon, .octagon]
 - Group drawing tools: [.line, .bezierPen]
 - Group paint tools: [.brush, .freehand]
 - Group transformation tools: [.scale, .rotate, .shear, .warp]
 - Group triangle shapes: [.equilateralTriangle, .isoscelesTriangle, .rightTriangle, .acuteTriangle, .cone]
 
 Just add/remove tools from the arrays to change groupings!
*/

// MARK: - Centralized Tool Group Configuration
struct ToolGroupConfiguration {
    
    // MARK: - Single Source of Truth for Tool Groups
    static let toolGroupConfig: [String: [DrawingTool]] = [
        "selection": [.selection, .cornerRadius],  // Selection tool group with corner radius
        "directSelection": [.directSelection, .convertAnchorPoint, .penPlusMinus],
        "rectangles": [.rectangle, .square, .roundedRectangle, .pill],
        "circles": [.ellipse, .oval, .circle, .egg],
        // Triangles: show Equilateral as the primary triangle tool; remove the non-equilateral variant
        "triangles": [.equilateralTriangle, .rightTriangle, .acuteTriangle, .cone],
        // Polygons: show 5–9 sides explicitly
        "polygons": [.pentagon, .hexagon, .heptagon, .octagon, .nonagon],
        "lines": [.bezierPen, .line],
        "brushes": [.marker, .freehand],
        "transforms": [.scale, .rotate, .shear, .warp],
        "stars": [.star], // Star has variants handled separately
        "navigation": [.hand, .zoom], // Navigation tools group
        "utilities": [.eyedropper, .gradient] // Utility tools group
    ]
    
    // MARK: - Helper Methods
    static func getToolGroup(for tool: DrawingTool) -> [DrawingTool] {
        // Find which group this tool belongs to
        for (_, tools) in toolGroupConfig {
            if tools.contains(tool) {
                return tools
            }
        }
        
        // If not in any group, return just the tool itself
        return [tool]
    }
    
    static func getToolGroupName(for tool: DrawingTool) -> String? {
        // Find the group name for this tool (useful for debugging)
        for (groupName, tools) in toolGroupConfig {
            if tools.contains(tool) {
                return groupName
            }
        }
        return nil
    }
    
    static func getAllToolGroupsAsArrays() -> [[DrawingTool]] {
        // Define the specific order for tool groups to appear in the toolbar
        let orderedGroupNames = [
            "selection",      // Selection tool group (arrow + corner radius)
            "directSelection", // Direct selection group
            "lines",          // Drawing tools (bezier pen group) after direct selection
            "transforms",     // Transform tools
            "brushes",        // Paint tools
            "font",           // Font tool (individual)
            "rectangles",     // Shape tools
            "circles",        // Circle tools
            "triangles",      // Triangle tools
            "polygons",       // Polygon tools
            "stars",          // Star tool (individual)
            "utilities",      // Utility tools group (eyedropper, gradient, corner radius)
            "navigation"      // Navigation tools group (hand, zoom)
        ]

        var allGroups: [[DrawingTool]] = []

        // Add groups in the specified order
        for groupName in orderedGroupNames {
            if let group = toolGroupConfig[groupName] {
                allGroups.append(group)
            } else if groupName == "font" {
                allGroups.append([.font])
            }
        }
        
        return allGroups
    }
} 
