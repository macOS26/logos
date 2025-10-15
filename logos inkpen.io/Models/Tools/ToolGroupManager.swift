import SwiftUI
import Combine

class ToolGroupManager: ObservableObject {
    static let shared = ToolGroupManager()

    @Published var selectedVariant: StarVariant = .fivePoint {
        didSet {
            saveStarVariant()
        }
    }

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
    @Published var customToolOrder: [String: [DrawingTool]] = [:] {
        didSet {
            saveCustomToolOrder()
        }
    }

    private let expandedGroupsKey = "ToolGroupManager.expandedGroups"
    private let selectedToolsKey = "ToolGroupManager.selectedTools"
    private let starVariantKey = "ToolGroupManager.starVariant"
    private let hasInitializedGroupsKey = "ToolGroupManager.hasInitializedGroups"
    private let customToolOrderKey = "ToolGroupManager.customToolOrder"

    private init() {
        loadSavedState()
    }

    private func saveExpandedGroups() {
        UserDefaults.standard.set(Array(expandedGroups), forKey: expandedGroupsKey)
    }

    private func saveSelectedTools() {
        let stringDict = selectedToolByGroup.reduce(into: [String: String]()) { result, pair in
            result[pair.key] = pair.value.rawValue
        }
        UserDefaults.standard.set(stringDict, forKey: selectedToolsKey)
    }

    private func saveStarVariant() {
        UserDefaults.standard.set(selectedVariant.rawValue, forKey: starVariantKey)
    }

    private func saveCustomToolOrder() {
        let stringDict = customToolOrder.reduce(into: [String: [String]]()) { result, pair in
            result[pair.key] = pair.value.map { $0.rawValue }
        }
        UserDefaults.standard.set(stringDict, forKey: customToolOrderKey)
    }

    private func loadSavedState() {
        let hasInitialized = UserDefaults.standard.bool(forKey: hasInitializedGroupsKey)

        if let savedGroups = UserDefaults.standard.array(forKey: expandedGroupsKey) as? [String] {
            expandedGroups = Set(savedGroups)

            if !hasInitialized {
                expandedGroups.insert("navigation")
                expandedGroups.insert("utilities")
                UserDefaults.standard.set(true, forKey: hasInitializedGroupsKey)
                saveExpandedGroups()
            }
        } else {
            expandedGroups = Set(["navigation", "utilities"])
            UserDefaults.standard.set(true, forKey: hasInitializedGroupsKey)
        }

        if let savedTools = UserDefaults.standard.dictionary(forKey: selectedToolsKey) as? [String: String] {
            selectedToolByGroup = savedTools.reduce(into: [String: DrawingTool]()) { result, pair in
                if let tool = DrawingTool(rawValue: pair.value) {
                    result[pair.key] = tool
                }
            }
        }

        if let savedVariant = UserDefaults.standard.string(forKey: starVariantKey),
           let variant = StarVariant(rawValue: savedVariant) {
            selectedVariant = variant
        }

        if let savedOrder = UserDefaults.standard.dictionary(forKey: customToolOrderKey) as? [String: [String]] {
            customToolOrder = savedOrder.reduce(into: [String: [DrawingTool]]()) { result, pair in
                let tools = pair.value.compactMap { DrawingTool(rawValue: $0) }
                if !tools.isEmpty {
                    result[pair.key] = tools
                }
            }
        }
    }

    func handleKeyboardToolSwitch(tool: DrawingTool) {
        let groupName = getGroupName(for: tool)
        selectedToolByGroup[groupName] = tool
    }

    func longPressedTool(_ tool: DrawingTool, variantIndex: Int? = nil) {
        let groupName = getGroupName(for: tool)
        if tool == .star, let variantIndex {
            handleStarVariantLongPress(variantIndex: variantIndex)
            anchorVariantByGroup[groupName] = selectedVariant
            return
        }

        selectedToolByGroup[groupName] = tool

        if expandedGroups.contains(groupName) {
            expandedGroups.remove(groupName)
        } else {
            let toolGroup = ToolGroupConfiguration.getToolGroup(for: tool)
            var reorderedTools = [tool]
            for groupTool in toolGroup {
                if groupTool != tool {
                    reorderedTools.append(groupTool)
                }
            }
            customToolOrder[groupName] = reorderedTools

            expandedGroups.insert(groupName)
        }
    }

    private func handleStarVariantLongPress(variantIndex: Int) {
        let groupName = "stars"

        if variantIndex < StarVariant.allCases.count {
            let variant = StarVariant.allCases[variantIndex]

            if expandedGroups.contains(groupName) {
                expandedGroups.remove(groupName)
            } else {
                expandedGroups.insert(groupName)
                anchorVariantByGroup[groupName] = variant
            }
        }
    }

    func selectStarVariant(_ variant: StarVariant) {
        selectedVariant = variant
    }

    func setSelectedToolInGroup(_ tool: DrawingTool) {
        let groupName = getGroupName(for: tool)
        selectedToolByGroup[groupName] = tool
    }

    private func getGroupName(for tool: DrawingTool) -> String {
        return ToolGroupConfiguration.getToolGroupName(for: tool) ?? "single:\(tool.rawValue)"
    }

    func getOrderedToolsForGroup(_ groupName: String, defaultTools: [DrawingTool]) -> [DrawingTool] {
        if let customOrder = customToolOrder[groupName] {
            return customOrder
        }
        return defaultTools
    }

    func setToolButtonFrame(_ tool: DrawingTool, frame: CGRect) {
        toolButtonFrames[tool] = frame
    }
}
