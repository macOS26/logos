//
//  DocumentSettingsTests.swift
//  logos inkpen.ioTests
//
//  Unit tests for document-specific settings including colors and swatches
//

import XCTest
@testable import logos_inkpen_io

class DocumentSettingsTests: XCTestCase {

    // MARK: - Test Document Settings Initialization

    func testDocumentSettingsInitialization() {
        let settings = DocumentSettings()

        // Test default values
        XCTAssertEqual(settings.width, 11.0)
        XCTAssertEqual(settings.height, 8.5)
        XCTAssertEqual(settings.unit, .inches)
        XCTAssertEqual(settings.colorMode, .rgb)

        // Test that colors and swatches are nil by default
        XCTAssertNil(settings.fillColor)
        XCTAssertNil(settings.strokeColor)
        XCTAssertNil(settings.customRgbSwatches)
        XCTAssertNil(settings.customCmykSwatches)
        XCTAssertNil(settings.customHsbSwatches)
    }

    func testDocumentSettingsWithColors() {
        let fillColor = VectorColor.rgb(RGBColor(red: 1, green: 0, blue: 0, colorSpace: .displayP3))
        let strokeColor = VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 1, colorSpace: .displayP3))
        let customSwatches = [VectorColor.rgb(RGBColor(red: 0, green: 1, blue: 0, colorSpace: .displayP3))]

        let settings = DocumentSettings(
            fillColor: fillColor,
            strokeColor: strokeColor,
            customRgbSwatches: customSwatches
        )

        XCTAssertEqual(settings.fillColor, fillColor)
        XCTAssertEqual(settings.strokeColor, strokeColor)
        XCTAssertEqual(settings.customRgbSwatches, customSwatches)
    }

    // MARK: - Test Document Settings Encoding/Decoding

    func testDocumentSettingsCodable() throws {
        let fillColor = VectorColor.rgb(RGBColor(red: 0.5, green: 0.5, blue: 0.5, colorSpace: .displayP3))
        let strokeColor = VectorColor.cmyk(CMYKColor(c: 1, m: 0, y: 0, k: 0))
        let rgbSwatches = [VectorColor.rgb(RGBColor(red: 0.2, green: 0.3, blue: 0.4, colorSpace: .displayP3))]
        let cmykSwatches = [VectorColor.cmyk(CMYKColor(c: 0, m: 1, y: 0, k: 0))]

        let originalSettings = DocumentSettings(
            width: 20.0,
            height: 30.0,
            unit: .pixels,
            colorMode: .cmyk,
            fillColor: fillColor,
            strokeColor: strokeColor,
            customRgbSwatches: rgbSwatches,
            customCmykSwatches: cmykSwatches
        )

        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalSettings)

        // Decode
        let decoder = JSONDecoder()
        let decodedSettings = try decoder.decode(DocumentSettings.self, from: data)

        // Verify
        XCTAssertEqual(decodedSettings.width, originalSettings.width)
        XCTAssertEqual(decodedSettings.height, originalSettings.height)
        XCTAssertEqual(decodedSettings.unit, originalSettings.unit)
        XCTAssertEqual(decodedSettings.colorMode, originalSettings.colorMode)
        XCTAssertEqual(decodedSettings.fillColor, originalSettings.fillColor)
        XCTAssertEqual(decodedSettings.strokeColor, originalSettings.strokeColor)
        XCTAssertEqual(decodedSettings.customRgbSwatches, originalSettings.customRgbSwatches)
        XCTAssertEqual(decodedSettings.customCmykSwatches, originalSettings.customCmykSwatches)
    }

    // MARK: - Test VectorDocument Color Management

    func testVectorDocumentUsesDocumentColors() {
        let fillColor = VectorColor.rgb(RGBColor(red: 0.7, green: 0.2, blue: 0.3, colorSpace: .displayP3))
        let strokeColor = VectorColor.rgb(RGBColor(red: 0.0, green: 0.4, blue: 0.4, colorSpace: .displayP3))

        let settings = DocumentSettings(
            fillColor: fillColor,
            strokeColor: strokeColor
        )

        let document = VectorDocument(settings: settings)

        // Verify document uses settings colors
        XCTAssertEqual(document.defaultFillColor, fillColor)
        XCTAssertEqual(document.defaultStrokeColor, strokeColor)
    }

    func testVectorDocumentCustomSwatches() {
        let customRgb = [
            VectorColor.rgb(RGBColor(red: 0.1, green: 0.2, blue: 0.3, colorSpace: .displayP3)),
            VectorColor.rgb(RGBColor(red: 0.4, green: 0.5, blue: 0.6, colorSpace: .displayP3))
        ]
        let customCmyk = [
            VectorColor.cmyk(CMYKColor(c: 0.5, m: 0.5, y: 0, k: 0))
        ]

        let settings = DocumentSettings(
            customRgbSwatches: customRgb,
            customCmykSwatches: customCmyk
        )

        let document = VectorDocument(settings: settings)

        // Verify custom swatches are loaded
        XCTAssertEqual(document.customRgbSwatches, customRgb)
        XCTAssertEqual(document.customCmykSwatches, customCmyk)

        // Verify combined swatches include both defaults and custom
        XCTAssertTrue(document.rgbSwatches.count > customRgb.count)
        XCTAssertTrue(document.rgbSwatches.contains(customRgb[0]))
        XCTAssertTrue(document.rgbSwatches.contains(customRgb[1]))
    }

    func testAddCustomSwatch() {
        let document = VectorDocument()
        let customColor = VectorColor.rgb(RGBColor(red: 0.9, green: 0.1, blue: 0.5, colorSpace: .displayP3))

        // Initially no custom swatches
        XCTAssertTrue(document.customRgbSwatches.isEmpty)

        // Add custom swatch
        document.addCustomSwatch(customColor)

        // Verify it was added
        XCTAssertEqual(document.customRgbSwatches.count, 1)
        XCTAssertEqual(document.customRgbSwatches[0], customColor)

        // Try adding the same color again - should not duplicate
        document.addCustomSwatch(customColor)
        XCTAssertEqual(document.customRgbSwatches.count, 1)
    }

    func testRemoveCustomSwatch() {
        let customColor = VectorColor.rgb(RGBColor(red: 0.3, green: 0.6, blue: 0.9, colorSpace: .displayP3))
        let settings = DocumentSettings(customRgbSwatches: [customColor])
        let document = VectorDocument(settings: settings)

        // Verify swatch exists
        XCTAssertEqual(document.customRgbSwatches.count, 1)

        // Remove the swatch
        document.removeCustomSwatch(customColor)

        // Verify it was removed
        XCTAssertTrue(document.customRgbSwatches.isEmpty)
    }

    // MARK: - Test Document Persistence

    func testDocumentSavesColorSettings() throws {
        let fillColor = VectorColor.rgb(RGBColor(red: 0.25, green: 0.75, blue: 0.5, colorSpace: .displayP3))
        let strokeColor = VectorColor.cmyk(CMYKColor(c: 0.3, m: 0.6, y: 0.9, k: 0.1))
        let customSwatch = VectorColor.rgb(RGBColor(red: 0.6, green: 0.3, blue: 0.9, colorSpace: .displayP3))

        // Create document with custom colors
        let document = VectorDocument()
        document.defaultFillColor = fillColor
        document.defaultStrokeColor = strokeColor
        document.addCustomSwatch(customSwatch)

        // Encode document
        let encoder = JSONEncoder()
        let data = try encoder.encode(document)

        // Decode document
        let decoder = JSONDecoder()
        let loadedDocument = try decoder.decode(VectorDocument.self, from: data)

        // Verify colors are preserved
        XCTAssertEqual(loadedDocument.defaultFillColor, fillColor)
        XCTAssertEqual(loadedDocument.defaultStrokeColor, strokeColor)

        // Since we're using RGB swatch, verify it was saved
        XCTAssertTrue(loadedDocument.customRgbSwatches.contains(customSwatch))
    }

    // MARK: - Test Display Options in Document

    func testDisplayOptionsInDocumentSettings() {
        let settings = DocumentSettings(
            showRulers: true,
            showGrid: false,
            snapToGrid: true,
            snapToPoint: false
        )

        XCTAssertTrue(settings.showRulers)
        XCTAssertFalse(settings.showGrid)
        XCTAssertTrue(settings.snapToGrid)
        XCTAssertFalse(settings.snapToPoint)

        let document = VectorDocument(settings: settings)

        // Verify document uses settings for display options
        XCTAssertEqual(document.showRulers, settings.showRulers)
        XCTAssertEqual(document.showGrid, settings.showGrid)
        XCTAssertEqual(document.snapToGrid, settings.snapToGrid)
        XCTAssertEqual(document.snapToPoint, settings.snapToPoint)
    }
}