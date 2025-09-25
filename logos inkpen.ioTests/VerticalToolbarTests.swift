//
//  VerticalToolbarTests.swift
//  logos inkpen.ioTests
//
//  Created by Assistant on 2025/09/24.
//

import XCTest
import SwiftUI
@testable import logos_inkpen_io

class VerticalToolbarTests: XCTestCase {

    var document: VectorDocument!
    var toolGroupManager: ToolGroupManager!

    override func setUp() {
        super.setUp()
        document = VectorDocument()
        toolGroupManager = ToolGroupManager.shared
    }

    override func tearDown() {
        document = nil
        super.tearDown()
    }

    func testToolSelection() {
        // Test that selecting a tool updates the document's currentTool
        let tool = DrawingTool.rectangle
        document.currentTool = tool
        XCTAssertEqual(document.currentTool, tool, "Tool selection should update document.currentTool")
    }

    func testToolGroupExpansion() {
        // Test that long pressing a tool expands its group
        let tool = DrawingTool.rectangle
        let groupName = toolGroupManager.getGroupName(for: tool)

        // Initially collapsed
        toolGroupManager.expandedGroups.remove(groupName)
        XCTAssertFalse(toolGroupManager.expandedGroups.contains(groupName), "Group should be initially collapsed")

        // Long press to expand
        toolGroupManager.longPressedTool(tool)
        XCTAssertTrue(toolGroupManager.expandedGroups.contains(groupName), "Group should be expanded after long press")

        // Long press again to collapse
        toolGroupManager.longPressedTool(tool)
        XCTAssertFalse(toolGroupManager.expandedGroups.contains(groupName), "Group should be collapsed after second long press")
    }

    func testStarVariantSelection() {
        // Test star variant selection
        let variant = StarVariant.fivePoint
        toolGroupManager.selectStarVariant(variant)
        XCTAssertEqual(toolGroupManager.selectedVariant, variant, "Star variant should be updated")
    }

    func testStarVariantLongPress() {
        // Test star variant long press behavior
        let groupName = toolGroupManager.getGroupName(for: .star)

        // Initially ensure group is collapsed
        toolGroupManager.expandedGroups.remove(groupName)

        // Long press star variant
        toolGroupManager.longPressedTool(.star, variantIndex: 0)
        XCTAssertTrue(toolGroupManager.expandedGroups.contains(groupName), "Star group should be expanded after long press")
        XCTAssertEqual(toolGroupManager.selectedVariant, StarVariant.allCases[0], "Star variant should be selected")

        // Long press again to collapse
        toolGroupManager.longPressedTool(.star, variantIndex: 0)
        XCTAssertFalse(toolGroupManager.expandedGroups.contains(groupName), "Star group should be collapsed after second long press")
    }

    func testToolGroupPersistence() {
        // Test that selected tools and expanded groups are persisted
        let tool = DrawingTool.circle
        let groupName = toolGroupManager.getGroupName(for: tool)

        // Set a selected tool for a group
        toolGroupManager.selectedToolByGroup[groupName] = tool

        // Expand a group
        toolGroupManager.expandedGroups.insert(groupName)

        // Verify persistence by checking UserDefaults
        let savedGroups = UserDefaults.standard.array(forKey: "ToolGroupManager.expandedGroups") as? [String] ?? []
        XCTAssertTrue(savedGroups.contains(groupName), "Expanded groups should be persisted to UserDefaults")

        let savedTools = UserDefaults.standard.dictionary(forKey: "ToolGroupManager.selectedTools") as? [String: String] ?? [:]
        XCTAssertEqual(savedTools[groupName], tool.rawValue, "Selected tools should be persisted to UserDefaults")
    }

    func testMultipleGroupIndependence() {
        // Test that multiple groups can be expanded/collapsed independently
        let rectangleGroup = toolGroupManager.getGroupName(for: .rectangle)
        let circleGroup = toolGroupManager.getGroupName(for: .circle)

        // Ensure both are initially collapsed
        toolGroupManager.expandedGroups.removeAll()

        // Expand rectangle group
        toolGroupManager.longPressedTool(.rectangle)
        XCTAssertTrue(toolGroupManager.expandedGroups.contains(rectangleGroup), "Rectangle group should be expanded")
        XCTAssertFalse(toolGroupManager.expandedGroups.contains(circleGroup), "Circle group should remain collapsed")

        // Expand circle group
        toolGroupManager.longPressedTool(.circle)
        XCTAssertTrue(toolGroupManager.expandedGroups.contains(rectangleGroup), "Rectangle group should remain expanded")
        XCTAssertTrue(toolGroupManager.expandedGroups.contains(circleGroup), "Circle group should be expanded")

        // Collapse rectangle group
        toolGroupManager.longPressedTool(.rectangle)
        XCTAssertFalse(toolGroupManager.expandedGroups.contains(rectangleGroup), "Rectangle group should be collapsed")
        XCTAssertTrue(toolGroupManager.expandedGroups.contains(circleGroup), "Circle group should remain expanded")
    }

    func testGestureConflictResolution() {
        // Test that tap and long press gestures don't conflict
        // This is more of an integration test that would need UI testing
        // But we can test the underlying logic

        let tool = DrawingTool.pentagon
        let groupName = toolGroupManager.getGroupName(for: tool)

        // Tap should select tool
        document.currentTool = tool
        toolGroupManager.currentToolInGroup = tool
        toolGroupManager.setSelectedToolInGroup(tool)
        XCTAssertEqual(document.currentTool, tool, "Tap should select tool")
        XCTAssertEqual(toolGroupManager.currentToolInGroup, tool, "Tool group manager should track selected tool")

        // Long press should expand group without changing selection
        let previousTool = document.currentTool
        toolGroupManager.longPressedTool(tool)
        XCTAssertEqual(document.currentTool, previousTool, "Long press should not change tool selection")
        XCTAssertTrue(toolGroupManager.expandedGroups.contains(groupName), "Long press should expand group")
    }
}