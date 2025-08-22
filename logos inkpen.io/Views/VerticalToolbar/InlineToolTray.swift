import SwiftUI

/*
 🔧 INLINE TOOL TRAY
 
 This component provides the expandable tool tray that appears when long-pressing tool buttons.
 It uses the centralized ToolGroupConfiguration for consistent tool grouping across the app.
*/

// MARK: - Tool Group Manager
class ToolGroupManager: ObservableObject {
    static let shared = ToolGroupManager()
    
    // DEPRECATED single-group fields (kept for backward compatibility with any legacy views)
    @Published var currentToolInGroup: DrawingTool? = nil
    @Published var selectedVariant: StarVariant = .fivePoint
    @Published var selectedVariantIndex: Int? = nil // For star variants
    @Published var showingAllItems: Bool = false
    @Published var expansionAnchorTool: DrawingTool? = nil // Tool that triggered expansion
    @Published var expansionAnchorVariant: StarVariant? = nil // Star variant that triggered expansion

    // New per-group state so tool groups act independently
    @Published var expandedGroups: Set<String> = []
    @Published var selectedToolByGroup: [String: DrawingTool] = [:]
    @Published var anchorVariantByGroup: [String: StarVariant?] = [:]
    var toolButtonFrames: [DrawingTool: CGRect] = [:]
    
    private init() {
        // Shared instance for global access
    }
    
    // Handle tool switching via keyboard shortcuts (per-group, non-interfering)
    func handleKeyboardToolSwitch(tool: DrawingTool, toolGroup: [DrawingTool]) {
        let groupName = getGroupName(for: tool)
        selectedToolByGroup[groupName] = tool
        // Do not change expansion state of any group here to avoid side-effects
        // Maintain deprecated fields for any legacy code paths
        currentToolInGroup = tool
        showingAllItems = expandedGroups.contains(groupName)
        expansionAnchorTool = tool
        expansionAnchorVariant = (tool == .star) ? selectedVariant : nil
        Log.fileOperation("🔧 KEYBOARD: Selected \(tool.rawValue) in group \(groupName)", level: .info)
    }
    
    func longPressedTool(_ tool: DrawingTool, variantIndex: Int? = nil) {
        let groupName = getGroupName(for: tool)
        // Handle star variants separately
        if tool == .star, let variantIndex {
            handleStarVariantLongPress(variantIndex: variantIndex)
            anchorVariantByGroup[groupName] = selectedVariant
            return
        }
        // Toggle only this group's expansion
        if expandedGroups.contains(groupName) {
            expandedGroups.remove(groupName)
            showingAllItems = false
            expansionAnchorTool = nil
            expansionAnchorVariant = nil
            Log.fileOperation("🔧 Collapsed group \(groupName)", level: .info)
        } else {
            expandedGroups.insert(groupName)
            showingAllItems = true
            expansionAnchorTool = tool
            expansionAnchorVariant = nil
            Log.fileOperation("🔧 Expanded group \(groupName)", level: .info)
        }
        currentToolInGroup = tool
    }
    
    private func handleStarVariantLongPress(variantIndex: Int) {
        let groupName = getGroupName(for: .star)
        selectedVariantIndex = variantIndex
        selectedVariant = StarVariant.allCases[variantIndex]
        if expandedGroups.contains(groupName) {
            // Collapse only the star group
            expandedGroups.remove(groupName)
            Log.info("⭐ Collapsed star group on long-press of variant \(variantIndex)", category: .general)
        } else {
            expandedGroups.insert(groupName)
            Log.info("⭐ Expanded star group on long-press of variant \(variantIndex)", category: .general)
        }
        currentToolInGroup = .star
        expansionAnchorTool = .star
        expansionAnchorVariant = selectedVariant
    }
    
    func selectStarVariant(_ variant: StarVariant) {
        selectedVariant = variant
        Log.info("⭐ Selected star variant: \(variant.rawValue)", category: .general)
    }
    
    func setToolButtonFrame(_ tool: DrawingTool, frame: CGRect) {
        toolButtonFrames[tool] = frame
    }

    // MARK: - Helpers
    func getGroupName(for tool: DrawingTool) -> String {
        if let name = ToolGroupConfiguration.getToolGroupName(for: tool) {
            return name
        }
        // Unique fallback for single-tool groups not listed in config
        return "single:\(tool.rawValue)"
    }
    
    func setSelectedToolInGroup(_ tool: DrawingTool) {
        let groupName = getGroupName(for: tool)
        selectedToolByGroup[groupName] = tool
        currentToolInGroup = tool
    }
}

// MARK: - Expandable Tool Dock
struct ExpandableToolDock: View {
    @ObservedObject var groupManager: ToolGroupManager
    @ObservedObject var document: VectorDocument
    
    var body: some View {
        if let currentTool = groupManager.currentToolInGroup, groupManager.showingAllItems {
            // Show the expanded tool group
            VStack(spacing: 2) {
                if currentTool == .star {
                    // Show all star variants
                    ForEach(Array(StarVariant.allCases.enumerated()), id: \.element) { index, variant in
                        ToolDockButton(
                            tool: .star,
                            isSelected: document.currentTool == .star && groupManager.selectedVariant == variant,
                            isExpanded: true,
                            onTap: {
                                selectStarVariant(variant)
                            },
                            onLongPress: {
                                // Long press to hide siblings and show only this variant
                                groupManager.longPressedTool(.star, variantIndex: index)
                            },
                            variantIndex: index
                        )
                    }
                } else {
                    // Show all tools in the group
                    ForEach(getAllToolsInGroup(for: currentTool), id: \.self) { tool in
                        ToolDockButton(
                            tool: tool,
                            isSelected: document.currentTool == tool,
                            isExpanded: true,
                            onTap: {
                                selectTool(tool)
                            },
                            onLongPress: {
                                // Long press to hide siblings and show only this tool
                                groupManager.longPressedTool(tool)
                            }
                        )
                    }
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.9))
                    .shadow(radius: 8)
            )
            .transition(.opacity.combined(with: .scale))
            .animation(.easeInOut(duration: 0.2), value: groupManager.currentToolInGroup)
            .animation(.easeInOut(duration: 0.2), value: groupManager.showingAllItems)
            .position(
                x: groupManager.toolButtonFrames[currentTool]?.midX ?? 0,
                y: (groupManager.toolButtonFrames[currentTool]?.maxY ?? 0) + 50
            )
        } else if let currentTool = groupManager.currentToolInGroup, !groupManager.showingAllItems {
            // Show only the current tool/variant
            VStack(spacing: 2) {
                if currentTool == .star, let variantIndex = groupManager.selectedVariantIndex {
                    // Show only the selected star variant
                    ToolDockButton(
                        tool: .star,
                        isSelected: document.currentTool == .star && groupManager.selectedVariant == StarVariant.allCases[variantIndex],
                        isExpanded: false,
                        onTap: {
                            selectStarVariant(StarVariant.allCases[variantIndex])
                        },
                        onLongPress: {
                            // Long press to show all star variants
                            groupManager.longPressedTool(.star, variantIndex: variantIndex)
                        },
                        variantIndex: variantIndex
                    )
                } else {
                    // Show only the current tool
                    ToolDockButton(
                        tool: currentTool,
                        isSelected: document.currentTool == currentTool,
                        isExpanded: false,
                        onTap: {
                            selectTool(currentTool)
                        },
                        onLongPress: {
                            // Long press to show all tools in the group
                            groupManager.longPressedTool(currentTool)
                        }
                    )
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.9))
                    .shadow(radius: 8)
            )
            .transition(.opacity.combined(with: .scale))
            .animation(.easeInOut(duration: 0.2), value: groupManager.currentToolInGroup)
            .animation(.easeInOut(duration: 0.2), value: groupManager.showingAllItems)
            .position(
                x: groupManager.toolButtonFrames[currentTool]?.midX ?? 0,
                y: (groupManager.toolButtonFrames[currentTool]?.maxY ?? 0) + 50
            )
        }
    }
    
    private func getAllToolsInGroup(for tool: DrawingTool) -> [DrawingTool] {
        return ToolGroupConfiguration.getToolGroup(for: tool)
    }
    
    private func selectTool(_ tool: DrawingTool) {
        document.currentTool = tool
        Log.info("🛠️ Selected tool: \(tool.rawValue)", category: .general)
    }
    
    private func selectStarVariant(_ variant: StarVariant) {
        groupManager.selectStarVariant(variant)
        document.currentTool = .star
        Log.info("⭐ Selected star variant: \(variant.rawValue)", category: .general)
    }
}

// MARK: - Tool Dock Button
struct ToolDockButton: View {
    let tool: DrawingTool
    let isSelected: Bool
    let isExpanded: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    let variantIndex: Int?
    
    init(tool: DrawingTool, isSelected: Bool, isExpanded: Bool, onTap: @escaping () -> Void, onLongPress: @escaping () -> Void, variantIndex: Int? = nil) {
        self.tool = tool
        self.isSelected = isSelected
        self.isExpanded = isExpanded
        self.onTap = onTap
        self.onLongPress = onLongPress
        self.variantIndex = variantIndex
    }
    
    var body: some View {
        Button(action: onTap) {
            Image(systemName: toolIconName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isSelected ? .white : .gray)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? Color.blue : Color.clear)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0.3) {
            onLongPress()
        }
    }
    
    private var toolIconName: String {
        if tool == .star, let _ = variantIndex {
            return "star.fill"
        }
        return tool.iconName
    }
}
