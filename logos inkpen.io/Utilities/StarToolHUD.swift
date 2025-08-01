import SwiftUI

// MARK: - Tool Group Manager
class ToolGroupManager: ObservableObject {
    @Published var currentToolInGroup: DrawingTool? = nil
    @Published var selectedVariant: StarVariant = .fivePoint
    @Published var selectedVariantIndex: Int? = nil // For star variants
    @Published var showingAllItems: Bool = false
    var toolButtonFrames: [DrawingTool: CGRect] = [:]
    
    func longPressedTool(_ tool: DrawingTool, variantIndex: Int? = nil) {
        let toolGroup = getToolGroup(for: tool)
        
        // Handle star variants separately
        if tool == .star && variantIndex != nil {
            handleStarVariantLongPress(variantIndex: variantIndex!)
            return
        }
        
        // For non-star tools
        if currentToolInGroup == tool && toolGroup.count > 1 {
            // Same tool long-pressed - toggle state
            showingAllItems.toggle()
            print("🔧 Toggled \(tool.rawValue): showing all = \(showingAllItems)")
        } else if let current = currentToolInGroup, getToolGroup(for: current) == toolGroup {
            // Different tool in same group - hide others, show only this one
            currentToolInGroup = tool
            showingAllItems = false
            print("🔧 Switched to \(tool.rawValue) in same group, hiding others")
        } else {
            // New tool group - show all items
            currentToolInGroup = tool
            showingAllItems = true
            print("🔧 New tool group \(tool.rawValue), showing all items")
        }
    }
    
    private func handleStarVariantLongPress(variantIndex: Int) {
        if currentToolInGroup == .star && selectedVariantIndex == variantIndex {
            // Same variant long-pressed - toggle showing all
            showingAllItems.toggle()
            print("⭐ Toggled star variant \(variantIndex): showing all = \(showingAllItems)")
        } else if currentToolInGroup == .star {
            // Different variant in same group - hide others, show only this one
            selectedVariantIndex = variantIndex
            selectedVariant = StarVariant.allCases[variantIndex]
            showingAllItems = false
            print("⭐ Switched to star variant \(variantIndex), hiding others")
        } else {
            // New star group - show all variants
            currentToolInGroup = .star
            selectedVariantIndex = variantIndex
            selectedVariant = StarVariant.allCases[variantIndex]
            showingAllItems = true
            print("⭐ New star group, showing all variants")
        }
    }
    
    func selectStarVariant(_ variant: StarVariant) {
        selectedVariant = variant
        print("⭐ Selected star variant: \(variant.rawValue)")
    }
    
    func setToolButtonFrame(_ tool: DrawingTool, frame: CGRect) {
        toolButtonFrames[tool] = frame
    }
    
    private func getToolGroup(for tool: DrawingTool) -> [DrawingTool] {
        switch tool {
        case .star:
            return [.star] // Star is its own group with variants
        case .rectangle, .circle, .polygon:
            return [.rectangle, .circle, .polygon]
        case .line, .bezierPen, .freehand:
            return [.line, .bezierPen, .freehand]
        case .brush, .marker:
            return [.brush, .marker]
        default:
            return [tool]
        }
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
                            // Long press to show all variants again
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
                            // Long press to show all tools in group again
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
        switch tool {
        case .star:
            // For star, we'll show all star variants
            return Array(repeating: .star, count: StarVariant.allCases.count)
        case .rectangle, .circle, .polygon:
            return [.rectangle, .circle, .polygon]
        case .line, .bezierPen, .freehand:
            return [.line, .bezierPen, .freehand]
        case .brush, .marker:
            return [.brush, .marker]
        default:
            return [tool]
        }
    }
    
    private func selectTool(_ tool: DrawingTool) {
        document.currentTool = tool
        // Reset cursor
        NSCursor.arrow.set()
        print("🔧 Selected tool: \(tool.rawValue)")
    }
    
    private func selectStarVariant(_ variant: StarVariant) {
        groupManager.selectStarVariant(variant)
        document.currentTool = .star
        // Reset cursor
        NSCursor.arrow.set()
        print("⭐ Selected star variant: \(variant.rawValue)")
    }
}

// MARK: - Tool Dock Button
struct ToolDockButton: View {
    let tool: DrawingTool
    let isSelected: Bool
    let isExpanded: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    let variantIndex: Int? // For star variants
    
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
            Group {
                if tool == .star, let index = variantIndex, index < StarVariant.allCases.count {
                    // Show specific star variant
                    let variant = StarVariant.allCases[index]
                    variant.iconView(
                        isSelected: isSelected,
                        color: .white
                    )
                } else if tool == .star {
                    // Fallback for star tool
                    Image(systemName: "star.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: tool.iconName)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 32, height: 32)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? Color.blue : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .help(toolTooltip(for: tool))
        .onLongPressGesture {
            onLongPress()
        }
    }
    
    private func toolTooltip(for tool: DrawingTool) -> String {
        if tool == .star, let index = variantIndex, index < StarVariant.allCases.count {
            let variant = StarVariant.allCases[index]
            return variant.rawValue
        }
        return tool.rawValue.capitalized
    }
}

// MARK: - Legacy HUD Manager (for backward compatibility)
class StarToolHUDManager: ObservableObject {
    @Published var selectedVariant: StarVariant = .fivePoint
    @Published var isHUDVisible: Bool = false
    var starButtonFrame: CGRect = .zero
    
    func showHUD() {
        guard starButtonFrame != .zero else {
            print("⭐ Cannot show HUD - no button frame")
            return
        }
        
        isHUDVisible = true
        print("⭐ HUD visibility set to true")
    }
    
    func hideHUD() {
        isHUDVisible = false
        print("⭐ HUD visibility set to false")
    }
    
    func selectVariant(_ variant: StarVariant) {
        selectedVariant = variant
        hideHUD()
        print("⭐ HUD: Selected star variant: \(variant.rawValue)")
    }
}

// MARK: - Legacy HUD Views (keeping for now)
struct StarToolHUDView: View {
    @ObservedObject var hudManager: StarToolHUDManager
    
    private var availableVariants: [StarVariant] {
        StarVariant.allCases.filter { $0 != hudManager.selectedVariant }
    }
    
    var body: some View {
        VStack(spacing: 2) {
            ForEach(availableVariants, id: \.self) { variant in
                Button {
                    print("⭐ HUD: Button tapped for variant: \(variant.rawValue)")
                    hudManager.selectVariant(variant)
                } label: {
                    variant.iconView(
                        isSelected: false,
                        color: .white
                    )
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .help(variant.rawValue.capitalized)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.9))
                .shadow(radius: 8)
        )
        .transition(.opacity.combined(with: .scale))
        .animation(.easeInOut(duration: 0.2), value: hudManager.isHUDVisible)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                if hudManager.isHUDVisible {
                    hudManager.hideHUD()
                }
            }
        }
    }
}

struct StarToolHUDContainer: View {
    @ObservedObject var hudManager: StarToolHUDManager
    
    var body: some View {
        if hudManager.isHUDVisible {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    print("⭐ HUD: Tap detected outside HUD - dismissing")
                    hudManager.hideHUD()
                }
                .overlay(
                    StarToolHUDView(hudManager: hudManager)
                        .position(
                            x: hudManager.starButtonFrame.midX,
                            y: hudManager.starButtonFrame.maxY + 50
                        )
                        .allowsHitTesting(true)
                        .onTapGesture {
                            print("⭐ HUD: Tap detected on HUD content")
                        }
                )
                .allowsHitTesting(true)
        }
    }
}
