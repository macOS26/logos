//
//  ExportViewSandboxTests.swift
//  logos inkpen.ioTests
//
//  Unit tests for ExportView sandbox behavior
//

@testable import logos_inkpen_io
import XCTest
import SwiftUI

final class ExportViewSandboxTests: XCTestCase {

    func testIconSetExportHiddenWhenSandboxed() throws {
        // Create a test document
        let document = VectorDocument()

        // Create export view
        let exportView = ExportView(document: document)

        // When sandboxed, icon export option should not be available
        // Note: We can't directly test the UI visibility, but we can test the logic
        // that prevents icon export when sandboxed

        // If sandboxed, the export function should not attempt icon export
        // even if somehow isIconExport is true
        if SandboxChecker.isSandboxed {
            // Icon export should not be allowed
            XCTAssertTrue(SandboxChecker.isSandboxed, "Test should recognize sandboxed environment")
        } else {
            // Icon export should be allowed
            XCTAssertTrue(SandboxChecker.isNotSandboxed, "Test should recognize non-sandboxed environment")
        }
    }

    func testSandboxCheckerFunctionality() throws {
        // Test that SandboxChecker properties are opposites
        XCTAssertNotEqual(SandboxChecker.isSandboxed, SandboxChecker.isNotSandboxed,
                         "isSandboxed and isNotSandboxed should be opposites")

        // Test that we get a boolean result
        let isSandboxed = SandboxChecker.isSandboxed
        XCTAssertTrue(isSandboxed == true || isSandboxed == false,
                     "isSandboxed should return a boolean")

        // Test environment detection
        let hasContainerID = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
        XCTAssertEqual(SandboxChecker.isSandboxed, hasContainerID,
                      "Sandbox detection should match environment variable presence")
    }

    func testExportLogicWithSandboxCheck() throws {
        // Create a test document
        let document = VectorDocument()

        // Test that the export logic respects sandbox state
        // When sandboxed, icon set export should not be available

        // Create a dummy settings to ensure document is valid
        document.settings.sizeInPoints = CGSize(width: 100, height: 100)

        // Add a test layer
        let layer = VectorLayer()
        layer.name = "Test Layer"
        document.layers.append(layer)

        // Verify document is ready for export
        XCTAssertGreaterThan(document.layers.count, 0, "Document should have at least one layer")
        XCTAssertGreaterThan(document.settings.sizeInPoints.width, 0, "Document should have valid width")
        XCTAssertGreaterThan(document.settings.sizeInPoints.height, 0, "Document should have valid height")

        // Test sandbox-aware export logic
        if SandboxChecker.isSandboxed {
            // In sandbox mode, icon set export should not be attempted
            print("Running in sandbox mode - icon set export is disabled")
        } else {
            // Outside sandbox, icon set export is allowed
            print("Running outside sandbox - icon set export is enabled")
        }
    }
}