//
//  VerticalToolbar.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI
import AppKit


struct VerticalToolbar: View {
    @ObservedObject var document: VectorDocument
    @StateObject private var toolGroupManager = ToolGroupManager.shared
    
    // MARK: - Tool Group Functions
    
    private func handleToolLongPress(_ tool: DrawingTool, variantIndex: Int? = nil) {
        toolGroupManager.longPressedTool(tool, variantIndex: variantIndex)
    }
    
    // MARK: - Icon Display Functions
    
    @ViewBuilder
    private func toolIconView(for toolItem: ToolItem) -> some View {
        if toolItem.tool == .shear {
            // Use custom skewed rectangle icon for shear tool
            SkewedRectangleIcon(isSelected: document.currentTool == toolItem.tool)
        } else if toolItem.tool == .star, let starVariant = toolItem.starVariant {
            // Use specific star variant custom icon
            starVariant.iconView(
                isSelected: document.currentTool == .star && toolGroupManager.selectedVariant == starVariant,
                color: (document.currentTool == .star && toolGroupManager.selectedVariant == starVariant) ? .white : .primary
            )
        } else if toolItem.tool == .star {
            // Use selected star variant custom icon
            toolGroupManager.selectedVariant.iconView(
                isSelected: document.currentTool == toolItem.tool,
                color: document.currentTool == toolItem.tool ? .white : .primary
            )
        } else {
            customShapeIconView(for: toolItem)
        }
    }
    
    @ViewBuilder
    private func customShapeIconView(for toolItem: ToolItem) -> some View {
        switch toolItem.tool {
        case .rectangle:
            RectangleIcon(isSelected: document.currentTool == toolItem.tool)
        case .square:
            SquareIcon(isSelected: document.currentTool == toolItem.tool)
        case .roundedRectangle:
            RoundedRectangleIcon(isSelected: document.currentTool == toolItem.tool)
        case .pill:
            PillIcon(isSelected: document.currentTool == toolItem.tool)
        case .ellipse:
            EllipseIcon(isSelected: document.currentTool == toolItem.tool)
        case .oval:
            OvalIcon(isSelected: document.currentTool == toolItem.tool)
        case .circle:
            CircleIcon(isSelected: document.currentTool == toolItem.tool)
        case .egg:
            EggIcon(isSelected: document.currentTool == toolItem.tool)
        case .cone:
            ConeIcon(isSelected: document.currentTool == toolItem.tool)
        case .equilateralTriangle:
            EquilateralTriangleIcon(isSelected: document.currentTool == toolItem.tool)
        case .rightTriangle:
            RightTriangleIcon(isSelected: document.currentTool == toolItem.tool)
        case .acuteTriangle:
            AcuteTriangleIcon(isSelected: document.currentTool == toolItem.tool)
        case .pentagon:
            PentagonIcon(isSelected: document.currentTool == toolItem.tool)
        case .hexagon:
            HexagonIcon(isSelected: document.currentTool == toolItem.tool)
        case .heptagon:
            HeptagonIcon(isSelected: document.currentTool == toolItem.tool)
        case .octagon:
            OctagonIcon(isSelected: document.currentTool == toolItem.tool)
        case .nonagon:
            NonagonIcon(isSelected: document.currentTool == toolItem.tool)
        default:
            // Use SF Symbols for all other tools
            Image(systemName: toolItem.tool.iconName)
                .font(.system(size: 16))
                .foregroundColor(isToolSelected(toolItem) ? .white : .primary)
        }
    }
    
    
    private func getToolsToDisplayByGroup() -> [[ToolItem]] {
        var toolGroups: [[ToolItem]] = []
        
        // Get all unique tool groups
        let allToolGroups = getAllToolGroups()
        
        for toolGroup in allToolGroups {
            var groupTools: [ToolItem] = []
            let primaryTool = toolGroup[0]
            let groupName = ToolGroupConfiguration.getToolGroupName(for: primaryTool) ?? "single:\(primaryTool.rawValue)"
            
            // Expanded state is now per-group
            if toolGroupManager.expandedGroups.contains(groupName) {
                if primaryTool == .star {
                    // If we have a per-group anchor variant, put it first; otherwise natural order
                    if let anchorVariant = (toolGroupManager.anchorVariantByGroup[groupName] ?? nil) {
                        groupTools.append(ToolItem(tool: .star, starVariant: anchorVariant))
                        let otherVariants = StarVariant.allCases.filter { $0 != anchorVariant }
                        for variant in otherVariants {
                            groupTools.append(ToolItem(tool: .star, starVariant: variant))
                        }
                    } else {
                        for variant in StarVariant.allCases {
                            groupTools.append(ToolItem(tool: .star, starVariant: variant))
                        }
                    }
                } else {
                    // Use custom order if available, otherwise use default order
                    let orderedTools = toolGroupManager.getOrderedToolsForGroup(groupName, defaultTools: toolGroup)
                    for tool in orderedTools {
                        groupTools.append(ToolItem(tool: tool, starVariant: nil))
                    }
                }
            } else {
                // Collapsed state shows the group's selected tool (falls back to primary)
                if primaryTool == .star {
                    groupTools.append(ToolItem(tool: .star, starVariant: toolGroupManager.selectedVariant))
                } else {
                    let selectedTool = toolGroupManager.selectedToolByGroup[groupName] ?? primaryTool
                    groupTools.append(ToolItem(tool: selectedTool, starVariant: nil))
                }
            }
            
            if !groupTools.isEmpty {
                toolGroups.append(groupTools)
            }
        }
        
        return toolGroups
    }
    
    private func getToolsToDisplay() -> [ToolItem] {
        var toolsToShow: [ToolItem] = []
        
        // Get all unique tool groups
        let allToolGroups = getAllToolGroups()
        
        for toolGroup in allToolGroups {
            let primaryTool = toolGroup[0]
            let groupName = ToolGroupConfiguration.getToolGroupName(for: primaryTool) ?? "single:\(primaryTool.rawValue)"
            
            // Expanded state is now per-group
            if toolGroupManager.expandedGroups.contains(groupName) {
                if primaryTool == .star {
                    // If we have a per-group anchor variant, put it first; otherwise natural order
                    if let anchorVariant = (toolGroupManager.anchorVariantByGroup[groupName] ?? nil) {
                        toolsToShow.append(ToolItem(tool: .star, starVariant: anchorVariant))
                        let otherVariants = StarVariant.allCases.filter { $0 != anchorVariant }
                        for variant in otherVariants {
                            toolsToShow.append(ToolItem(tool: .star, starVariant: variant))
                        }
                    } else {
                        for variant in StarVariant.allCases {
                            toolsToShow.append(ToolItem(tool: .star, starVariant: variant))
                        }
                    }
                } else {
                    for tool in toolGroup {
                        toolsToShow.append(ToolItem(tool: tool, starVariant: nil))
                    }
                }
            } else {
                // Collapsed state shows the group's selected tool (falls back to primary)
                if primaryTool == .star {
                    toolsToShow.append(ToolItem(tool: .star, starVariant: toolGroupManager.selectedVariant))
                } else {
                    let selectedTool = toolGroupManager.selectedToolByGroup[groupName] ?? primaryTool
                    toolsToShow.append(ToolItem(tool: selectedTool, starVariant: nil))
                }
            }
        }
        
        return toolsToShow
    }
    
    private func getAllToolGroups() -> [[DrawingTool]] {
        // Ensure polygon group appears as 5,6,7,8,9 specifically
        var groups = ToolGroupConfiguration.getAllToolGroupsAsArrays()
        if let idx = groups.firstIndex(where: { $0.contains(.pentagon) && $0.contains(.octagon) }) {
            groups[idx] = [.pentagon, .hexagon, .heptagon, .octagon, .nonagon]
        }
        return groups
    }
    
    private func isToolSelected(_ toolItem: ToolItem) -> Bool {
        if let starVariant = toolItem.starVariant {
            return document.currentTool == .star && toolGroupManager.selectedVariant == starVariant
        } else {
            return document.currentTool == toolItem.tool
        }
    }
    
    private func isToolInExpandableGroup(_ toolItem: ToolItem) -> Bool {
        // Check if the tool belongs to a group with more than one tool
        let tool = toolItem.tool
        let group = ToolGroupConfiguration.getToolGroup(for: tool)
        
        // Star tool always has expandable variants
        if tool == .star {
            return true
        }
        
        // Other tools are expandable if their group has more than 1 tool
        return group.count > 1
    }
    
    private func isGroupExpanded(for toolItem: ToolItem) -> Bool {
        // Check if this tool's group is currently expanded
        let tool = toolItem.tool
        
        if tool == .star {
            let groupName = "stars"
            return toolGroupManager.expandedGroups.contains(groupName)
        } else if let groupName = ToolGroupConfiguration.getToolGroupName(for: tool) {
            return toolGroupManager.expandedGroups.contains(groupName)
        }
        
        return false
    }
    
    
    var body: some View {
        ZStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Drawing Tools
                    ToolSection {
                        VStack(spacing: 0) {
                            let toolsByGroup = getToolsToDisplayByGroup()
                            ForEach(Array(toolsByGroup.enumerated()), id: \.offset) { index, toolGroup in
                                // Add separator between groups (but not before the first group)
                                if index > 0 {
                                    Rectangle()
                                        .fill(Color.primary.opacity(0.2))
                                        .frame(height: 0.5)
                                        .frame(maxWidth: .infinity)
                                }
                                
                                ForEach(toolGroup, id: \.toolIdentifier) { toolItem in
                                    VerticalToolbarButton(
                                        toolItem: toolItem,
                                        isSelected: isToolSelected(toolItem),
                                        isExpandable: isToolInExpandableGroup(toolItem),
                                        isGroupExpanded: isGroupExpanded(for: toolItem),
                                        onTap: {
                                            // Handle tool selection
                                            if let starVariant = toolItem.starVariant {
                                                toolGroupManager.selectStarVariant(starVariant)
                                                document.currentTool = .star
                                                toolGroupManager.currentToolInGroup = .star
                                                toolGroupManager.setSelectedToolInGroup(.star)
                                            } else {
                                                document.currentTool = toolItem.tool
                                                toolGroupManager.currentToolInGroup = toolItem.tool
                                                toolGroupManager.setSelectedToolInGroup(toolItem.tool)
                                            }
                                        },
                                        onLongPress: {
                                            // Long press for expanding tool groups
                                            if let starVariant = toolItem.starVariant {
                                                let variantIndex = StarVariant.allCases.firstIndex(of: starVariant) ?? 0
                                                handleToolLongPress(.star, variantIndex: variantIndex)
                                            } else {
                                                handleToolLongPress(toolItem.tool)
                                            }
                                        },
                                        toolIconView: { toolIconView(for: toolItem) }
                                    )
                                    .help(toolTooltip(for: toolItem.tool, variant: toolItem.starVariant))
                                    .background(
                                        GeometryReader { geometry in
                                            Color.clear
                                                .onAppear {
                                                    // Store the button's frame for tool group positioning
                                                    let globalFrame = geometry.frame(in: .global)
                                                    toolGroupManager.setToolButtonFrame(toolItem.tool, frame: globalFrame)
                                                }
                                                .onChange(of: geometry.frame(in: .global)) { _, newFrame in
                                                    // Update frame if it changes (e.g., during scrolling)
                                                    toolGroupManager.setToolButtonFrame(toolItem.tool, frame: newFrame)
                                                }
                                        }
                                    )
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Quick Color Swatches
                    ToolSection {
                        ColorSwatchGrid(document: document)
                    }
                    
                    Spacer()
                }
                .padding(.bottom, 4)
                .frame(width: 48) // ENSURE: Maintain fixed toolbar width
            }
            .background(Color(NSColor.controlBackgroundColor))
            .overlay(
                Rectangle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 0.5),
                alignment: .trailing
            )
        }
    }
    
    
    
    private func toolTooltip(for tool: DrawingTool, variant: StarVariant? = nil) -> String {
        if let starVariant = variant {
            return "Star Tool - Draw \(starVariant.rawValue) (Long press for more variants)"
        }
        
        switch tool {
        case .selection:
            return "Selection Tool (V) - Select and move objects"
        case .scale:
            return "Scale Tool (S) - Scale objects with corner handles"
        case .rotate:
            return "Rotate Tool (R) - Rotate objects around anchor points"
        case .shear:
            return "Shear Tool (X) - Shear/skew objects around anchor points"
        case .directSelection:
            return "Direct Selection Tool (A) - Edit individual points and handles"
        case .convertAnchorPoint:
            return "Convert Anchor Point Tool (C) - Convert between smooth and corner points"
        case .penPlusMinus:
            return "Pen +/- Tool (+/-) - Add points to curves or delete points from paths"
        case .bezierPen:
            return "Bezier Pen Tool (P) - Draw bezier curves and paths"
        case .freehand:
            return "Freehand Tool (F) - Draw freehand with smooth curves"
        case .brush:
            return "Brush Tool (B) - Draw variable width brush strokes"
        case .marker:
            return "Marker Tool (M) - Draw with pressure-sensitive marker strokes"
        case .font:
            return "Font Tool (T) - Add and edit text"
        case .line:
            return "Line Tool (L) - Draw straight lines"
        case .rectangle:
            return "Rectangle Tool (⌥R) - Draw rectangles"
        case .square:
            return "Square Tool (⌥S) - Draw perfect squares"
        case .roundedRectangle:
            return "Rounded Rectangle Tool (⇧⌥R) - Draw rectangles with rounded corners"
        case .pill:
            return "Pill Tool (⇧⌥P) - Draw capsule/pill shapes"
        case .circle:
            return "Circle Tool (⌥C) - Draw perfect circles"
        case .ellipse:
            return "Ellipse Tool (E) - Draw ellipses and ovals"
        case .oval:
            return "Oval Tool (O) - Draw oval shapes"
        case .egg:
            return "Egg Tool (⇧E) - Draw egg shapes"
        case .cone:
            return "Cone Tool (⇧⌥C) - Draw triangle/cone shapes"
        case .equilateralTriangle:
            return "Equilateral Triangle Tool (⇧T) - Draw triangles with equal sides"
        case .isoscelesTriangle:
            return "Isosceles Triangle Tool (I) - Draw triangles with two equal sides"
        case .rightTriangle:
            return "Right Triangle Tool (⇧⌥R) - Draw 90-degree triangles"
        case .acuteTriangle:
            return "Acute Triangle Tool (⇧A) - Draw triangles with all angles less than 90°"
        case .star:
            return "Star Tool (⇧S) - Draw \(toolGroupManager.selectedVariant.rawValue) (Long press for more variants)"
        case .polygon:
            return "Polygon Tool (⌥P) - Draw polygon shapes"
        case .pentagon:
            return "Pentagon Tool (5) - Draw 5-sided polygons"
        case .hexagon:
            return "Hexagon Tool (6) - Draw 6-sided polygons"
        case .heptagon:
            return "Heptagon Tool (7) - Draw 7-sided polygons"
        case .octagon:
            return "Octagon Tool (8) - Draw 8-sided polygons"
        case .nonagon:
            return "Nonagon Tool (9) - Draw 9-sided polygons"
        case .eyedropper:
            return "Eyedropper Tool (I) - Sample colors"
        case .hand:
            return "Hand Tool (H) - Pan the canvas"
        case .zoom:
            return "Zoom Tool (Z) - Zoom in and out"
        case .warp:
            return "Warp Tool (W) - Warp and distort objects"
        case .gradient:
            return "Gradient Tool (G) - Edit gradient origin and focal points"
        case .cornerRadius:
            return "Corner Radius Tool (⌥R) - Edit corner radius of rectangles"
        }
    }
}

// MARK: - Vertical Toolbar Button
struct VerticalToolbarButton: View {
    let toolItem: ToolItem
    let isSelected: Bool
    let isExpandable: Bool
    let isGroupExpanded: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    let toolIconView: () -> AnyView

    @State private var inc: Double = 0.0
    @State private var shouldRepeat: Bool = true
    @State private var lastTappedTool: String = ""

    init(toolItem: ToolItem,
         isSelected: Bool,
         isExpandable: Bool,
         isGroupExpanded: Bool,
         onTap: @escaping () -> Void,
         onLongPress: @escaping () -> Void,
         toolIconView: @escaping () -> some View) {
        self.toolItem = toolItem
        self.isSelected = isSelected
        self.isExpandable = isExpandable
        self.isGroupExpanded = isGroupExpanded
        self.onTap = onTap
        self.onLongPress = onLongPress
        self.toolIconView = { AnyView(toolIconView()) }
    }

    fileprivate func FreeHandMXLongPress() {
        inc += 0.1
        
        // always handle tap
        lastTappedTool = toolItem.tool.rawValue
        onTap()
        
        if inc <= 0.1 {
            shouldRepeat = true
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            inc = 0.0
            shouldRepeat = true
            lastTappedTool = ""
        }
        
        if shouldRepeat {
            if inc > 0.1 {
                Thread.sleep(forTimeInterval: 0.1)
            }
            
            if inc >= 0.3 && lastTappedTool == toolItem.tool.rawValue  {
                // Check if the tool being long-pressed is the same as the one that was tapped
                onLongPress()
                shouldRepeat = false  // Stop repeating after long press
                inc = 0.0
            }
        }
    }
    
    var body: some View {
        Button(action: {
            FreeHandMXLongPress()
        }) {
            ZStack {
                // Background highlight - always present but transparent when not selected
                RoundedRectangle(cornerRadius: 100)
                    .fill(isSelected
                          ? InkPenUIColors.shared.toolSelectionBlue
                          : Color.clear)
                    .frame(width: 47, height: 34)

                toolIconView()
                    .frame(width: 47)

                // Orange triangle indicator - always present but transparent when not needed
                Path { path in
                    // Triangle pointing to bottom-right corner
                    path.move(to: CGPoint(x: 0, y: 6))    // Left point
                    path.addLine(to: CGPoint(x: 6, y: 0)) // Top point
                    path.addLine(to: CGPoint(x: 6, y: 6)) // Bottom-right corner
                    path.closeSubpath()
                }
                .fill((isSelected && isExpandable && !isGroupExpanded)
                      ? Color(.displayP3, red: 1.0, green: 0.584, blue: 0.0) // Display P3 orange at full 1.0 opacity
                      : Color.clear)
                .frame(width: 6, height: 6)
                .position(x: 42, y: 26)
            }
            .contentShape(Rectangle()) // Extend hit area to match entire button area
            .frame(width: 58, height: 34)
            .position(x: 24.5, y: 17)
        }
        .buttonStyle(BorderlessButtonStyle())
        .buttonRepeatBehavior(shouldRepeat ? .enabled : .disabled)
    }
}

// Preview
#Preview {
    VerticalToolbar(document: VectorDocument())
        .frame(height: 600)
}

