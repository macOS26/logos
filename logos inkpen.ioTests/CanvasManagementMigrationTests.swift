//
//  CanvasManagementMigrationTests.swift
//  logos inkpen.ioTests
//
//  Test that canvas management uses unified objects instead of layers[].shapes
//

import XCTest
@testable import logos_inkpen_io

final class CanvasManagementMigrationTests: XCTestCase {
    var document: VectorDocument!
    
    override func setUp() {
        super.setUp()
        document = VectorDocument()
    }
    
    override func tearDown() {
        document = nil
        super.tearDown()
    }
    
    func testUpdatePasteboardLayerUsesUnifiedObjects() {
        // Setup: Create canvas and working layers
        document.createCanvasAndWorkingLayers()
        
        // Verify initial state
        XCTAssertEqual(document.layers.count, 3, "Should have 3 layers (Pasteboard, Canvas, Layer 1)")
        XCTAssertEqual(document.layers[0].name, "Pasteboard")
        
        // Verify pasteboard shape exists in unified objects
        let pasteboardObject = document.unifiedObjects.first { object in
            if case .shape(let shape) = object.objectType {
                return shape.name == "Pasteboard Background" && object.layerIndex == 0
            }
            return false
        }
        XCTAssertNotNil(pasteboardObject, "Pasteboard shape should exist in unified objects")
        
        // Change canvas size and update pasteboard
        let newSize = CGSize(width: 800, height: 600)
        document.settings.width = 800
        document.settings.height = 600
        document.updatePasteboardLayer()
        
        // Verify pasteboard was updated in unified objects
        let updatedPasteboardObject = document.unifiedObjects.first { object in
            if case .shape(let shape) = object.objectType {
                return shape.name == "Pasteboard Background" && object.layerIndex == 0
            }
            return false
        }
        
        XCTAssertNotNil(updatedPasteboardObject, "Updated pasteboard should exist in unified objects")
        
        if case .shape(let shape) = updatedPasteboardObject?.objectType {
            // Pasteboard should be 10x canvas size
            let expectedSize = CGSize(width: newSize.width * 10, height: newSize.height * 10)
            let expectedOrigin = CGPoint(
                x: (newSize.width - expectedSize.width) / 2,
                y: (newSize.height - expectedSize.height) / 2
            )
            
            // Check bounds match expected size and position
            let bounds = shape.bounds
            XCTAssertEqual(bounds.size.width, expectedSize.width, accuracy: 0.01)
            XCTAssertEqual(bounds.size.height, expectedSize.height, accuracy: 0.01)
            XCTAssertEqual(bounds.origin.x, expectedOrigin.x, accuracy: 0.01)
            XCTAssertEqual(bounds.origin.y, expectedOrigin.y, accuracy: 0.01)
        }
    }
    
    func testUpdateCanvasLayerUsesUnifiedObjects() {
        // Setup: Create canvas and working layers
        document.createCanvasAndWorkingLayers()
        
        // Verify canvas shape exists in unified objects
        let canvasObject = document.unifiedObjects.first { object in
            if case .shape(let shape) = object.objectType {
                return shape.name == "Canvas Background" && object.layerIndex == 1
            }
            return false
        }
        XCTAssertNotNil(canvasObject, "Canvas shape should exist in unified objects")
        
        // Change canvas size and background color
        let newSize = CGSize(width: 1024, height: 768)
        let newColor = VectorColor.rgb(RGBColor(red: 0.9, green: 0.9, blue: 0.9))
        document.settings.width = 1024
        document.settings.height = 768
        document.settings.backgroundColor = newColor
        document.updateCanvasLayer()
        
        // Verify canvas was updated in unified objects
        let updatedCanvasObject = document.unifiedObjects.first { object in
            if case .shape(let shape) = object.objectType {
                return shape.name == "Canvas Background" && object.layerIndex == 1
            }
            return false
        }
        
        XCTAssertNotNil(updatedCanvasObject, "Updated canvas should exist in unified objects")
        
        if case .shape(let shape) = updatedCanvasObject?.objectType {
            // Check bounds match new size
            let bounds = shape.bounds
            XCTAssertEqual(bounds.size.width, newSize.width, accuracy: 0.01)
            XCTAssertEqual(bounds.size.height, newSize.height, accuracy: 0.01)
            XCTAssertEqual(bounds.origin.x, 0, accuracy: 0.01)
            XCTAssertEqual(bounds.origin.y, 0, accuracy: 0.01)
            
            // Check fill color matches
            if let fillStyle = shape.fillStyle {
                XCTAssertEqual(fillStyle.color, newColor)
            } else {
                XCTFail("Canvas should have a fill style")
            }
        }
    }
    
    func testDebugCurrentStateUsesUnifiedObjects() {
        // Setup: Create canvas and add some shapes
        document.createCanvasAndWorkingLayers()
        
        // Add test shapes to Layer 1 (index 2)
        let testShape1 = VectorShape.rectangle(at: CGPoint(x: 100, y: 100), size: CGSize(width: 50, height: 50))
        // Create an ellipse using path elements
        let ellipsePath = VectorPath(elements: [
            .move(to: VectorPoint(230, 200)),
            .curve(to: VectorPoint(200, 230), control1: VectorPoint(230, 216.57), control2: VectorPoint(216.57, 230)),
            .curve(to: VectorPoint(170, 200), control1: VectorPoint(183.43, 230), control2: VectorPoint(170, 216.57)),
            .curve(to: VectorPoint(200, 170), control1: VectorPoint(170, 183.43), control2: VectorPoint(183.43, 170)),
            .curve(to: VectorPoint(230, 200), control1: VectorPoint(216.57, 170), control2: VectorPoint(230, 183.43))
        ], isClosed: true)
        let testShape2 = VectorShape(path: ellipsePath)
        
        document.addShapeToUnifiedSystem(testShape1, layerIndex: 2)
        document.addShapeToUnifiedSystem(testShape2, layerIndex: 2)
        
        // Verify shape counts are correct from unified objects
        let pasteboardShapeCount = document.getShapesForLayer(0).count
        let canvasShapeCount = document.getShapesForLayer(1).count
        let layer1ShapeCount = document.getShapesForLayer(2).count
        
        XCTAssertEqual(pasteboardShapeCount, 1, "Pasteboard should have 1 shape")
        XCTAssertEqual(canvasShapeCount, 1, "Canvas should have 1 shape")
        XCTAssertEqual(layer1ShapeCount, 2, "Layer 1 should have 2 shapes")
        
        // Call debugCurrentState - it should use getShapesForLayer internally
        document.debugCurrentState() // This should not crash and should log correct counts
    }
    
    func testTranslateAllContentUsesUnifiedObjects() {
        // Setup: Create canvas and add shapes
        document.createCanvasAndWorkingLayers()
        
        // Add test shape to Layer 1
        var testShape = VectorShape.rectangle(at: CGPoint(x: 100, y: 100), size: CGSize(width: 50, height: 50))
        testShape.name = "Test Rectangle"
        document.addShapeToUnifiedSystem(testShape, layerIndex: 2)
        
        // Translate all content
        let delta = CGPoint(x: 50, y: 50)
        document.translateAllContent(by: delta, includeBackgrounds: false)
        
        // Verify shape was translated in unified objects
        let translatedObject = document.unifiedObjects.first { object in
            if case .shape(let shape) = object.objectType {
                return shape.name == "Test Rectangle" && object.layerIndex == 2
            }
            return false
        }
        
        XCTAssertNotNil(translatedObject, "Translated shape should exist in unified objects")
        
        // Background shapes should not be translated
        let pasteboardObject = document.unifiedObjects.first { object in
            if case .shape(let shape) = object.objectType {
                return shape.name == "Pasteboard Background"
            }
            return false
        }
        
        if case .shape(let shape) = pasteboardObject?.objectType {
            // Pasteboard should remain at original position
            let expectedOrigin = CGPoint(
                x: (document.settings.sizeInPoints.width - document.settings.sizeInPoints.width * 10) / 2,
                y: (document.settings.sizeInPoints.height - document.settings.sizeInPoints.height * 10) / 2
            )
            XCTAssertEqual(shape.bounds.origin.x, expectedOrigin.x, accuracy: 0.01)
            XCTAssertEqual(shape.bounds.origin.y, expectedOrigin.y, accuracy: 0.01)
        }
    }
}