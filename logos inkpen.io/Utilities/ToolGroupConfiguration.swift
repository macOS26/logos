import Foundation

/*
 🔧 CENTRALIZED TOOL GROUP CONFIGURATION
 
 This is the SINGLE SOURCE OF TRUTH for all tool groupings in the application.
 
 To modify tool groups, edit the `toolGroupConfig` dictionary below.
 
 Example:
 - Keep basic shapes together: [.rectangle, .square, .circle, .ellipse, .egg]
 - Separate polygons: [.polygon, .pentagon, .hexagon, .heptagon, .octagon]
 - Group drawing tools: [.line, .bezierPen]
 - Group paint tools: [.brush, .marker, .freehand]
 - Group transformation tools: [.scale, .rotate, .shear, .warp]
 - Group triangle shapes: [.equilateralTriangle, .isoscelesTriangle, .rightTriangle, .acuteTriangle, .cone]
 
 Just add/remove tools from the arrays to change groupings!
*/

// MARK: - Centralized Tool Group Configuration
struct ToolGroupConfiguration {
    
    // MARK: - Single Source of Truth for Tool Groups
    static let toolGroupConfig: [String: [DrawingTool]] = [
        "selection": [.selection, .directSelection, .convertAnchorPoint],
        "rectangles": [.rectangle, .square, .roundedRectangle, .pill],
        "circles": [.ellipse, .oval, .circle, .egg],
        "triangles": [.equilateralTriangle, .isoscelesTriangle, .rightTriangle, .acuteTriangle, .cone],
        "polygons": [.polygon, .pentagon, .hexagon, .heptagon, .octagon],
        "lines": [.bezierPen, .line],
        "brushes": [.brush, .marker, .freehand],
        "transforms": [.scale, .rotate, .shear, .warp],
        "stars": [.star] // Star has variants handled separately
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
    
    static func getAllToolGroups() -> [[DrawingTool]] {
        return Array(toolGroupConfig.values)
    }
    
    static func getAllToolGroupsAsArrays() -> [[DrawingTool]] {
        // Define the specific order for tool groups to appear in the toolbar
        let orderedGroupNames = [
            "selection",      // Selection tools first
            "transforms",     // Transform tools second
            "lines",          // Drawing tools third
            "brushes",        // Paint tools fourth
            "font",           // Font tool (individual)
            "rectangles",     // Shape tools
            "circles",        // Circle tools
            "triangles",      // Triangle tools
            "polygons",       // Polygon tools
            "stars",          // Star tool (individual)
            "eyedropper",     // Utility tools
            "hand",           // Navigation tools
            "zoom",           // Navigation tools
            "gradient",       // Special tools
            "cornerRadius"    // Corner radius tool
        ]
        
        var allGroups: [[DrawingTool]] = []
        
        // Add groups in the specified order
        for groupName in orderedGroupNames {
            if let group = toolGroupConfig[groupName] {
                allGroups.append(group)
            } else if groupName == "font" {
                allGroups.append([.font])
            } else if groupName == "eyedropper" {
                allGroups.append([.eyedropper])
            } else if groupName == "hand" {
                allGroups.append([.hand])
            } else if groupName == "zoom" {
                allGroups.append([.zoom])
            } else if groupName == "gradient" {
                allGroups.append([.gradient])
            } else if groupName == "cornerRadius" {
                allGroups.append([.cornerRadius])
            }
        }
        
        return allGroups
    }
} 