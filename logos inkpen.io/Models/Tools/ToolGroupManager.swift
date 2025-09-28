import SwiftUI
import Combine

// MARK: - Tool Group Manager
class ToolGroupManager: ObservableObject {
    static let shared = ToolGroupManager()

    // Keep currentToolInGroup as it's actually used externally
    @Published var currentToolInGroup: DrawingTool? = nil
    @Published var selectedVariant: StarVariant = .fivePoint {
        didSet {
            saveStarVariant()
        }
    }

    // New per-group state so tool groups act independently
    @Published var expandedGroups: Set<String> = [] {
        didSet {
            saveExpandedGroups()
        }
    }
    @Published var selectedToolByGroup: [String: DrawingTool] = [:] {
        didSet {
            saveSelectedTools()
        }
    }
    @Published var anchorVariantByGroup: [String: StarVariant?] = [:]
    var toolButtonFrames: [DrawingTool: CGRect] = [:]

    // Store custom tool order for each group (when expanded, current tool goes first)
    @Published var customToolOrder: [String: [DrawingTool]] = [:] {
        didSet {
            saveCustomToolOrder()
        }
    }

    // UserDefaults keys
    private let expandedGroupsKey = "ToolGroupManager.expandedGroups"
    private let selectedToolsKey = "ToolGroupManager.selectedTools"
    private let starVariantKey = "ToolGroupManager.starVariant"
    private let hasInitializedGroupsKey = "ToolGroupManager.hasInitializedGroups"
    private let customToolOrderKey = "ToolGroupManager.customToolOrder"

    private init() {
        // Load saved state from UserDefaults
        loadSavedState()
    }

    // MARK: - Persistence Methods
    private func saveExpandedGroups() {
        UserDefaults.standard.set(Array(expandedGroups), forKey: expandedGroupsKey)
    }

    private func saveSelectedTools() {
        // Convert to dictionary of strings for UserDefaults
        let stringDict = selectedToolByGroup.reduce(into: [String: String]()) { result, pair in
            result[pair.key] = pair.value.rawValue
        }
        UserDefaults.standard.set(stringDict, forKey: selectedToolsKey)
    }

    private func saveStarVariant() {
        UserDefaults.standard.set(selectedVariant.rawValue, forKey: starVariantKey)
    }

    private func saveCustomToolOrder() {
        // Convert to dictionary of string arrays for UserDefaults
        let stringDict = customToolOrder.reduce(into: [String: [String]]()) { result, pair in
            result[pair.key] = pair.value.map { $0.rawValue }
        }
        UserDefaults.standard.set(stringDict, forKey: customToolOrderKey)
    }

    private func loadSavedState() {
        // Check if this is the first time initializing the new groups
        let hasInitialized = UserDefaults.standard.bool(forKey: hasInitializedGroupsKey)

        // Load expanded groups
        if let savedGroups = UserDefaults.standard.array(forKey: expandedGroupsKey) as? [String] {
            expandedGroups = Set(savedGroups)

            // Only set defaults for new groups if we haven't initialized them before
            if !hasInitialized {
                // First time seeing these groups - expand them by default
                expandedGroups.insert("navigation")
                expandedGroups.insert("utilities")
                // Mark as initialized and save
                UserDefaults.standard.set(true, forKey: hasInitializedGroupsKey)
                saveExpandedGroups()
            }
        } else {
            // No saved groups at all - set defaults
            expandedGroups = Set(["navigation", "utilities"])
            UserDefaults.standard.set(true, forKey: hasInitializedGroupsKey)
        }

        // Load selected tools per group
        if let savedTools = UserDefaults.standard.dictionary(forKey: selectedToolsKey) as? [String: String] {
            selectedToolByGroup = savedTools.reduce(into: [String: DrawingTool]()) { result, pair in
                if let tool = DrawingTool(rawValue: pair.value) {
                    result[pair.key] = tool
                }
            }
        }

        // Load star variant
        if let savedVariant = UserDefaults.standard.string(forKey: starVariantKey),
           let variant = StarVariant(rawValue: savedVariant) {
            selectedVariant = variant
        }

        // Load custom tool order
        if let savedOrder = UserDefaults.standard.dictionary(forKey: customToolOrderKey) as? [String: [String]] {
            customToolOrder = savedOrder.reduce(into: [String: [DrawingTool]]()) { result, pair in
                let tools = pair.value.compactMap { DrawingTool(rawValue: $0) }
                if !tools.isEmpty {
                    result[pair.key] = tools
                }
            }
        }
    }

    // Handle tool switching via keyboard shortcuts (per-group, non-interfering)
    func handleKeyboardToolSwitch(tool: DrawingTool) {
        let groupName = getGroupName(for: tool)
        selectedToolByGroup[groupName] = tool
        // Maintain currentToolInGroup for any legacy code paths
        currentToolInGroup = tool
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

        // Set this tool as the selected tool for the group (so it shows when collapsed)
        selectedToolByGroup[groupName] = tool

        // Toggle only this group's expansion
        if expandedGroups.contains(groupName) {
            expandedGroups.remove(groupName)
            Log.fileOperation("🔧 Collapsed group \(groupName), showing tool: \(tool.rawValue)", level: .info)
        } else {
            // When expanding, reorder the group to put current tool first
            let toolGroup = ToolGroupConfiguration.getToolGroup(for: tool)
            var reorderedTools = [tool]
            for groupTool in toolGroup {
                if groupTool != tool {
                    reorderedTools.append(groupTool)
                }
            }
            customToolOrder[groupName] = reorderedTools

            expandedGroups.insert(groupName)
            Log.fileOperation("🔧 Expanded group \(groupName) from tool: \(tool.rawValue) - reordered with \(tool.rawValue) first", level: .info)
        }
        currentToolInGroup = tool
    }

    private func handleStarVariantLongPress(variantIndex: Int) {
        let groupName = "stars"

        // Map index to star variant
        if variantIndex < StarVariant.allCases.count {
            let variant = StarVariant.allCases[variantIndex]

            // Toggle expansion
            if expandedGroups.contains(groupName) {
                expandedGroups.remove(groupName)
                Log.fileOperation("🔧 Collapsed star variants, selected: \(variant.rawValue)", level: .info)
            } else {
                expandedGroups.insert(groupName)
                anchorVariantByGroup[groupName] = variant
                Log.fileOperation("🔧 Expanded star variants from: \(variant.rawValue)", level: .info)
            }
        }
    }

    func selectStarVariant(_ variant: StarVariant) {
        selectedVariant = variant
        Log.fileOperation("⭐ Selected star variant: \(variant.rawValue)", level: .info)
    }

    func collapseAllGroups() {
        expandedGroups.removeAll()
        anchorVariantByGroup.removeAll()
        Log.fileOperation("🔧 Collapsed all tool groups", level: .info)
    }

    func setSelectedToolInGroup(_ tool: DrawingTool) {
        let groupName = getGroupName(for: tool)
        selectedToolByGroup[groupName] = tool
    }

    func getSelectedToolInGroup(for tool: DrawingTool) -> DrawingTool {
        let groupName = getGroupName(for: tool)
        return selectedToolByGroup[groupName] ?? tool
    }

    private func getGroupName(for tool: DrawingTool) -> String {
        return ToolGroupConfiguration.getToolGroupName(for: tool) ?? "single:\(tool.rawValue)"
    }

    // Get the ordered tools for a group (using custom order if available)
    func getOrderedToolsForGroup(_ groupName: String, defaultTools: [DrawingTool]) -> [DrawingTool] {
        if let customOrder = customToolOrder[groupName] {
            return customOrder
        }
        return defaultTools
    }

    // Frame management for button positioning
    func setToolButtonFrame(_ tool: DrawingTool, frame: CGRect) {
        toolButtonFrames[tool] = frame
    }

    func getToolButtonFrame(_ tool: DrawingTool) -> CGRect? {
        return toolButtonFrames[tool]
    }
}