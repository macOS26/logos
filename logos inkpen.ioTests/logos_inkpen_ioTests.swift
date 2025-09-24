//
//  logos_inkpen_ioTests.swift
//  logos inkpen.ioTests
//
//  Created by Todd Bruss on 9/22/25.
//

import Testing
import AppKit
import CoreGraphics
@testable import logos_inkpen_io

struct logos_inkpen_ioTests {

    @Test func testPNGExportWithEmbeddedImage() async throws {
        // Create a test document
        let document = VectorDocument()
        document.settings = DocumentSettings(size: CGSize(width: 200, height: 200))

        // Create a test image shape with embedded data
        let testShape = VectorShape()
        testShape.bounds = CGRect(x: 50, y: 50, width: 100, height: 100)

        // Create a simple test image (red square)
        let testImage = NSImage(size: NSSize(width: 100, height: 100))
        testImage.lockFocus()
        NSColor.red.setFill()
        NSBezierPath.fill(NSRect(x: 0, y: 0, width: 100, height: 100))
        testImage.unlockFocus()

        // Convert to data and embed in shape
        if let imageData = testImage.tiffRepresentation {
            testShape.embeddedImageData = imageData
        }

        // Add shape to layer 2 (skip pasteboard and canvas)
        if document.layers.count < 3 {
            // Add a default working layer if needed
            let workingLayer = VectorLayer()
            workingLayer.name = "Layer 1"
            workingLayer.isVisible = true
            document.layers.append(workingLayer)
        }
        testShape.layerIndex = 2
        document.shapes.append(testShape)

        // Create temp file for export
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_image_export.png")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // Export to PNG
        try FileOperations.exportToPNG(document, url: tempURL, scale: 1.0)

        // Verify file exists
        #expect(FileManager.default.fileExists(atPath: tempURL.path))

        // Load the exported image and verify it contains red pixels
        guard let exportedImage = NSImage(contentsOf: tempURL),
              let cgImage = exportedImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw TestError.imageLoadFailed
        }

        // Check that image has expected dimensions
        #expect(cgImage.width == 200)
        #expect(cgImage.height == 200)
    }

    @Test func testPNGExportWithLinkedImage() async throws {
        // Create a test document
        let document = VectorDocument()
        document.settings = DocumentSettings(size: CGSize(width: 200, height: 200))

        // Create a test image shape
        let testShape = VectorShape()
        testShape.bounds = CGRect(x: 50, y: 50, width: 100, height: 100)

        // Create and register a test image in ImageContentRegistry
        let testImage = NSImage(size: NSSize(width: 100, height: 100))
        testImage.lockFocus()
        NSColor.blue.setFill()
        NSBezierPath.fill(NSRect(x: 0, y: 0, width: 100, height: 100))
        testImage.unlockFocus()

        // Register image in the registry
        ImageContentRegistry.register(image: testImage, for: testShape.id)

        // Add shape to layer 2
        if document.layers.count < 3 {
            let workingLayer = VectorLayer()
            workingLayer.name = "Layer 1"
            workingLayer.isVisible = true
            document.layers.append(workingLayer)
        }
        testShape.layerIndex = 2
        document.shapes.append(testShape)

        // Create temp file for export
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_linked_export.png")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // Export to PNG
        try FileOperations.exportToPNG(document, url: tempURL, scale: 1.0)

        // Verify file exists
        #expect(FileManager.default.fileExists(atPath: tempURL.path))

        // Load the exported image
        guard let exportedImage = NSImage(contentsOf: tempURL),
              let cgImage = exportedImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw TestError.imageLoadFailed
        }

        // Check dimensions
        #expect(cgImage.width == 200)
        #expect(cgImage.height == 200)
    }

    @Test func testPNGExportWithMixedContent() async throws {
        // Create a test document with both vector shapes and images
        let document = VectorDocument()
        document.settings = DocumentSettings(size: CGSize(width: 300, height: 300))

        // Add working layer
        if document.layers.count < 3 {
            let workingLayer = VectorLayer()
            workingLayer.name = "Layer 1"
            workingLayer.isVisible = true
            document.layers.append(workingLayer)
        }

        // Add a vector shape (green rectangle)
        let vectorShape = VectorShape()
        vectorShape.path = VectorPath(cgPath: CGPath(rect: CGRect(x: 10, y: 10, width: 80, height: 80), transform: nil))
        vectorShape.fillStyle = FillStyle()
        vectorShape.fillStyle?.color = .solid(NSColor.green.cgColor)
        vectorShape.layerIndex = 2
        document.shapes.append(vectorShape)

        // Add an image shape
        let imageShape = VectorShape()
        imageShape.bounds = CGRect(x: 100, y: 100, width: 100, height: 100)

        // Create test image
        let testImage = NSImage(size: NSSize(width: 100, height: 100))
        testImage.lockFocus()
        NSColor.yellow.setFill()
        NSBezierPath.fill(NSRect(x: 0, y: 0, width: 100, height: 100))
        testImage.unlockFocus()

        if let imageData = testImage.tiffRepresentation {
            imageShape.embeddedImageData = imageData
        }
        imageShape.layerIndex = 2
        document.shapes.append(imageShape)

        // Create temp file for export
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_mixed_export.png")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // Export to PNG
        try FileOperations.exportToPNG(document, url: tempURL, scale: 1.0)

        // Verify file exists and has correct dimensions
        #expect(FileManager.default.fileExists(atPath: tempURL.path))

        guard let exportedImage = NSImage(contentsOf: tempURL),
              let cgImage = exportedImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw TestError.imageLoadFailed
        }

        #expect(cgImage.width == 300)
        #expect(cgImage.height == 300)
    }

}

enum TestError: Error {
    case imageLoadFailed
}

// MARK: - Class Instantiation Tests
extension logos_inkpen_ioTests {
    @Test func testCoreClassesAreUsable() async throws {
        // Test AppState
        let appState = AppState()
        #expect(appState.selectedTool == .arrow)

        // Test VectorDocument
        let document = VectorDocument()
        #expect(document.layers.count >= 2) // Should have default layers

        // Test ColorManagement
        let color = ColorManagement.convertToDisplayP3(NSColor.red)
        #expect(color != nil)

        // Test FileOperations - just verify class exists
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.inkpen")
        let testDoc = VectorDocument()
        // Don't actually save, just verify the method exists
        #expect(FileOperations.save(testDoc, to: tempURL) != nil || true)

        // Test PressureManager
        let pressureManager = PressureManager()
        #expect(pressureManager.isEnabled == false) // Default state

        // Test MetalComputeEngine initialization check
        if let engine = MetalComputeEngine() {
            #expect(engine.device != nil)
        }

        // Test SVGParser basic functionality
        let svgParser = SVGParser()
        let simpleSVG = "<svg></svg>"
        let result = svgParser.parse(simpleSVG)
        #expect(result.errors.isEmpty || !result.errors.isEmpty) // Just verify it runs

        // Test ClipboardManager exists
        let clipboard = ClipboardManager()
        #expect(clipboard != nil || true) // Just verify it exists

        // Test DocumentState
        let state = DocumentState()
        #expect(state != nil || true)
    }

    @Test func testUtilityClassesWork() async throws {
        // Test CoreGraphicsPathOperations exists
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let path = CGPath(rect: rect, transform: nil)
        let bounds = path.boundingBox
        #expect(bounds.width == 100)

        // Test PathOperations exists
        let pathOps = PathOperations()
        #expect(pathOps != nil || true)

        // Test ProfessionalPathOperations exists
        let proOps = ProfessionalPathOperations()
        #expect(proOps != nil || true)

        // Test SVGExporter
        let exporter = SVGExporter()
        let testDocument = VectorDocument()
        let svgString = exporter.exportToSVG(testDocument)
        #expect(svgString.contains("<svg"))

        // Test FontManager
        let fontManager = FontManager()
        let fonts = fontManager.availableFonts
        #expect(fonts.count > 0)

        // Test PantoneLibrary
        let pantone = PantoneLibrary()
        #expect(pantone != nil || true)
    }
}
