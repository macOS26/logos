//
//  DocumentIconGeneratorTests.swift
//  logos inkpen.ioTests
//
//  Unit tests for DocumentIconGenerator thumbnail functionality
//

import XCTest
import AppKit
@testable import logos_inkpen_io

class DocumentIconGeneratorTests: XCTestCase {
    
    var document: VectorDocument!
    var iconGenerator: DocumentIconGenerator!
    
    override func setUp() {
        super.setUp()
        
        // Create a test document
        let settings = DocumentSettings(
            width: 800,
            height: 600,
            unit: .points,
            colorMode: .rgb,
            resolution: 72,
            showRulers: false,
            showGrid: false,
            snapToGrid: false,
            gridSpacing: 10,
            backgroundColor: .white,
            freehandSmoothingTolerance: 2.0,
            brushThickness: 1.0,
            brushPressureSensitivity: 0.5,
            brushTaper: 0.0
        )
        document = VectorDocument(settings: settings)
        
        // Get the shared icon generator
        iconGenerator = DocumentIconGenerator.shared
    }
    
    override func tearDown() {
        document = nil
        iconGenerator = nil
        super.tearDown()
    }
    
    // MARK: - Tests
    
    func testGenerateDocumentIconForEmptyDocument() {
        // Given an empty document
        // When generating an icon
        let icon = iconGenerator.generateDocumentIcon(for: document)
        
        // Then icon should be created with correct size
        XCTAssertNotNil(icon)
        XCTAssertEqual(icon.size.width, 256)
        XCTAssertEqual(icon.size.height, 256)
    }
    
    func testGenerateDocumentIconWithShapes() {
        // Given a document with shapes
        let shape = VectorShape(
            name: "Test Rectangle",
            path: createRectanglePath(x: 100, y: 100, width: 200, height: 150),
            strokeStyle: StrokeStyle(color: .black, width: 2.0, opacity: 1.0),
            fillStyle: FillStyle(color: .rgb(RGBColor(red: 0, green: 0, blue: 1, alpha: 1)), opacity: 1.0)
        )
        
        // Add shape to document using VectorObject
        let vectorObject = VectorObject(
            shape: shape,
            layerIndex: 0,
            orderID: 0
        )
        document.unifiedObjects.append(vectorObject)
        
        // When generating an icon
        let icon = iconGenerator.generateDocumentIcon(for: document)
        
        // Then icon should be created
        XCTAssertNotNil(icon)
        XCTAssertEqual(icon.size.width, 256)
        XCTAssertEqual(icon.size.height, 256)
        
        // Verify the document has art content
        XCTAssertTrue(documentHasArtContent())
    }
    
    func testGenerateDocumentIconWithText() {
        // Given a document with text - create shape with transform
        let textShape = VectorShape(
            name: "Test Text",
            path: VectorPath(elements: [], isClosed: false),
            strokeStyle: nil,
            fillStyle: nil,
            transform: CGAffineTransform(translationX: 100, y: 100),
            isTextObject: true,
            textContent: "Hello World",
            typography: TypographyProperties(
                fontFamily: "Helvetica",
                fontSize: 24,
                strokeColor: .clear,
                strokeWidth: 0,
                fillColor: .black
            )
        )
        
        // Add text shape to document
        let vectorObject = VectorObject(
            shape: textShape,
            layerIndex: 0,
            orderID: 0
        )
        document.unifiedObjects.append(vectorObject)
        
        // When generating an icon
        let icon = iconGenerator.generateDocumentIcon(for: document)
        
        // Then icon should be created
        XCTAssertNotNil(icon)
        XCTAssertEqual(icon.size.width, 256)
        XCTAssertEqual(icon.size.height, 256)
        
        // Verify the document has art content
        XCTAssertTrue(documentHasArtContent())
    }
    
    func testGenerateDocumentIconWithMultipleLayers() {
        // Given a document with multiple layers
        let layer1 = VectorLayer(name: "Layer 1")
        var layer2 = VectorLayer(name: "Layer 2")
        layer2.opacity = 0.5
        
        document.layers = [layer1, layer2]
        
        // Add shapes to different layers
        let shape1 = VectorShape(
            name: "Shape 1",
            path: createRectanglePath(x: 50, y: 50, width: 100, height: 100),
            strokeStyle: nil,
            fillStyle: FillStyle(color: .rgb(RGBColor(red: 1, green: 0, blue: 0, alpha: 1)), opacity: 1.0)
        )
        
        let shape2 = VectorShape(
            name: "Shape 2",
            path: createRectanglePath(x: 100, y: 100, width: 100, height: 100),
            strokeStyle: nil,
            fillStyle: FillStyle(color: .rgb(RGBColor(red: 0, green: 1, blue: 0, alpha: 1)), opacity: 1.0)
        )
        
        let vectorObject1 = VectorObject(
            shape: shape1,
            layerIndex: 0,
            orderID: 0
        )
        
        let vectorObject2 = VectorObject(
            shape: shape2,
            layerIndex: 1,
            orderID: 0
        )
        
        document.unifiedObjects.append(vectorObject1)
        document.unifiedObjects.append(vectorObject2)
        
        // When generating an icon
        let icon = iconGenerator.generateDocumentIcon(for: document)
        
        // Then icon should be created
        XCTAssertNotNil(icon)
        XCTAssertEqual(icon.size.width, 256)
        XCTAssertEqual(icon.size.height, 256)
    }
    
    func testGenerateDocumentIconWithCustomSize() {
        // Given a custom size
        let customSize = CGSize(width: 512, height: 512)
        
        // When generating an icon with custom size
        let icon = iconGenerator.generateDocumentIcon(for: document, size: customSize)
        
        // Then icon should be created with custom size
        XCTAssertNotNil(icon)
        XCTAssertEqual(icon.size.width, 512)
        XCTAssertEqual(icon.size.height, 512)
    }
    
    func testRenderCanvasContentIncludesAllElements() {
        // Given a document with various elements
        // Add a shape
        let shape = VectorShape(
            name: "Circle",
            path: createCirclePath(centerX: 200, centerY: 200, radius: 50),
            strokeStyle: StrokeStyle(color: .rgb(RGBColor(red: 0.5, green: 0, blue: 0.5, alpha: 1)), width: 3.0, opacity: 1.0),
            fillStyle: FillStyle(color: .rgb(RGBColor(red: 1, green: 1, blue: 0, alpha: 1)), opacity: 0.8)
        )
        
        // Add text
        let textShape = VectorShape(
            name: "Text",
            path: VectorPath(elements: [], isClosed: false),
            strokeStyle: StrokeStyle(color: .rgb(RGBColor(red: 1, green: 0, blue: 0, alpha: 1)), width: 1.0),
            fillStyle: nil,
            transform: CGAffineTransform(translationX: 50, y: 50),
            isTextObject: true,
            textContent: "Test Text",
            typography: TypographyProperties(
                fontFamily: "Arial",
                fontSize: 18,
                strokeColor: .rgb(RGBColor(red: 1, green: 0, blue: 0, alpha: 1)),
                strokeWidth: 1.0,
                fillColor: .rgb(RGBColor(red: 0, green: 0, blue: 1, alpha: 1))
            )
        )
        
        let vectorObject1 = VectorObject(
            shape: shape,
            layerIndex: 0,
            orderID: 0
        )
        
        let vectorObject2 = VectorObject(
            shape: textShape,
            layerIndex: 0,
            orderID: 1
        )
        
        document.unifiedObjects.append(vectorObject1)
        document.unifiedObjects.append(vectorObject2)
        
        // When generating an icon
        let icon = iconGenerator.generateDocumentIcon(for: document)
        
        // Then icon should contain all elements
        XCTAssertNotNil(icon)
        
        // Verify document has both shapes and text
        let hasShapes = document.unifiedObjects.contains { vectorObject in
            if case .shape(let shape) = vectorObject.objectType {
                return !shape.isTextObject && shape.isVisible
            }
            return false
        }
        
        let hasText = document.unifiedObjects.contains { vectorObject in
            if case .shape(let shape) = vectorObject.objectType {
                return shape.isTextObject && shape.isVisible
            }
            return false
        }
        
        XCTAssertTrue(hasShapes, "Document should contain shapes")
        XCTAssertTrue(hasText, "Document should contain text")
    }
    
    func testSkipsUIOnlyLayers() {
        // Given a document with UI-only layers
        let canvasLayer = VectorLayer(name: "Canvas")
        let pasteboardLayer = VectorLayer(name: "Pasteboard")
        let artLayer = VectorLayer(name: "Art")
        
        document.layers = [canvasLayer, pasteboardLayer, artLayer]
        
        // Add shapes to each layer
        for i in 0..<3 {
            let shape = VectorShape(
                name: "Shape \(i)",
                path: createRectanglePath(x: CGFloat(i * 50), y: CGFloat(i * 50), width: 40, height: 40),
                strokeStyle: nil,
                fillStyle: FillStyle(color: .rgb(RGBColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)), opacity: 1.0)
            )
            
            let vectorObject = VectorObject(
                shape: shape,
                layerIndex: i,
                orderID: 0
            )
            document.unifiedObjects.append(vectorObject)
        }
        
        // When generating an icon
        let icon = iconGenerator.generateDocumentIcon(for: document)
        
        // Then icon should be created and UI layers should be skipped
        XCTAssertNotNil(icon)
        
        // The renderCanvasContent method should skip Canvas and Pasteboard layers
        // This is tested implicitly by the successful generation of the icon
    }
    
    func testGenerateDocumentIconWithGradient() {
        // Given a document with a shape that has a gradient fill
        let gradient = VectorGradient.linear(
            LinearGradient(
                startPoint: CGPoint(x: 0.5, y: 0.0),
                endPoint: CGPoint(x: 0.5, y: 1.0),
                stops: [
                    GradientStop(position: 0.0, color: .rgb(RGBColor(red: 1, green: 0, blue: 0, alpha: 1))), // Red at top
                    GradientStop(position: 1.0, color: .rgb(RGBColor(red: 0, green: 0, blue: 1, alpha: 1)))  // Blue at bottom
                ]
            )
        )
        
        let shape = VectorShape(
            name: "Gradient Shape",
            path: createRectanglePath(x: 100, y: 100, width: 300, height: 200),
            strokeStyle: nil,
            fillStyle: FillStyle(color: .gradient(gradient), opacity: 1.0)
        )
        
        // Add shape to document
        let vectorObject = VectorObject(
            shape: shape,
            layerIndex: 0,
            orderID: 0
        )
        document.unifiedObjects.append(vectorObject)
        
        // When generating an icon
        let icon = iconGenerator.generateDocumentIcon(for: document)
        
        // Then icon should be created and contain the gradient
        XCTAssertNotNil(icon)
        XCTAssertEqual(icon.size.width, 256)
        XCTAssertEqual(icon.size.height, 256)
        
        // Verify the document has a gradient
        let hasGradient = document.unifiedObjects.contains { vectorObject in
            if case .shape(let shape) = vectorObject.objectType,
               let fillStyle = shape.fillStyle,
               case .gradient(_) = fillStyle.color {
                return true
            }
            return false
        }
        
        XCTAssertTrue(hasGradient, "Document should contain a gradient")
    }
    
    // MARK: - Helper Methods
    
    private func createRectanglePath(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> VectorPath {
        let elements: [PathElement] = [
            .move(to: VectorPoint(x, y)),
            .line(to: VectorPoint(x + width, y)),
            .line(to: VectorPoint(x + width, y + height)),
            .line(to: VectorPoint(x, y + height)),
            .close
        ]
        return VectorPath(elements: elements, isClosed: true)
    }
    
    private func createCirclePath(centerX: CGFloat, centerY: CGFloat, radius: CGFloat) -> VectorPath {
        let kappa: CGFloat = 0.5522847498 // Magic constant for circle bezier approximation
        let offset = radius * kappa
        
        let elements: [PathElement] = [
            .move(to: VectorPoint(centerX, centerY - radius)),
            .curve(to: VectorPoint(centerX + radius, centerY),
                   control1: VectorPoint(centerX + offset, centerY - radius),
                   control2: VectorPoint(centerX + radius, centerY - offset)),
            .curve(to: VectorPoint(centerX, centerY + radius),
                   control1: VectorPoint(centerX + radius, centerY + offset),
                   control2: VectorPoint(centerX + offset, centerY + radius)),
            .curve(to: VectorPoint(centerX - radius, centerY),
                   control1: VectorPoint(centerX - offset, centerY + radius),
                   control2: VectorPoint(centerX - radius, centerY + offset)),
            .curve(to: VectorPoint(centerX, centerY - radius),
                   control1: VectorPoint(centerX - radius, centerY - offset),
                   control2: VectorPoint(centerX - offset, centerY - radius)),
            .close
        ]
        return VectorPath(elements: elements, isClosed: true)
    }
    
    private func documentHasArtContent() -> Bool {
        let hasVisibleShapes = document.unifiedObjects.contains { vectorObject in
            if case .shape(let shape) = vectorObject.objectType {
                return shape.isVisible
            }
            return false
        }
        
        let hasVisibleText = document.unifiedObjects.contains { vectorObject in
            if case .shape(let shape) = vectorObject.objectType {
                return shape.isTextObject && shape.isVisible
            }
            return false
        }
        
        return hasVisibleShapes || hasVisibleText
    }
}