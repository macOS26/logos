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
        "rectangles": [.rectangle, .square, .roundedRectangle, .pill],
        "circles": [.ellipse, .oval, .circle, .egg],
        "triangles": [.equilateralTriangle, .isoscelesTriangle, .rightTriangle, .acuteTriangle, .cone],
        "polygons": [.polygon, .pentagon, .hexagon, .heptagon, .octagon],
        "lines": [.line, .bezierPen],
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
        return [
            [.selection, .directSelection],
            [.scale, .rotate, .shear, .warp],
            [.bezierPen, .convertAnchorPoint, .line],
            [.brush, .marker, .freehand],
            [.font],
            [.rectangle, .square, .roundedRectangle, .pill], // Rectangle group
            [.ellipse, .oval, .circle, .egg], // Circle group  
            [.equilateralTriangle, .isoscelesTriangle, .rightTriangle, .acuteTriangle, .cone], // Triangle group
            [.polygon, .pentagon, .hexagon, .heptagon, .octagon], // Multi-sided polygon group
            [.star], // Star variants (handled separately)
            [.eyedropper],
            [.hand],
            [.zoom],
            [.gradient]
        ]
    }
} 