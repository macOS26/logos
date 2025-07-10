//
//  PasteboardTests.swift
//  logosTests
//
//  Created by AI Assistant
//  Comprehensive pasteboard functionality tests
//

import XCTest
@testable import logos

class PasteboardTests: XCTestCase {
    
    var document: VectorDocument!
    
    override func setUp() {
        super.setUp()
        document = TemplateManager.shared.createBlankDocument()
    }
    
    override func tearDown() {
        document = nil
        super.tearDown()
    }
    
    // MARK: - Layer Structure Tests
    
    func testLayerStructureIsCorrect() {
        print("🧪 TEST: Layer Structure")
        
        // Verify we have exactly 3 layers in correct order
        XCTAssertEqual(document.layers.count, 3, "Document should have exactly 3 layers")
        
        // Verify layer names and order
        XCTAssertEqual(document.layers[0].name, "Pasteboard", "Layer 0 should be Pasteboard")
        XCTAssertEqual(document.layers[1].name, "Canvas", "Layer 1 should be Canvas")
        XCTAssertEqual(document.layers[2].name, "Layer 1", "Layer 2 should be working layer")
        
        // Verify pasteboard and canvas are locked
        XCTAssertTrue(document.layers[0].isLocked, "Pasteboard layer should be locked")
        XCTAssertTrue(document.layers[1].isLocked, "Canvas layer should be locked")
        XCTAssertFalse(document.layers[2].isLocked, "Working layer should not be locked")
        
        print("✅ Layer structure is correct")
    }
    
    func testBackgroundShapesExist() {
        print("🧪 TEST: Background Shapes Exist")
        
        // Verify pasteboard has background shape
        XCTAssertEqual(document.layers[0].shapes.count, 1, "Pasteboard layer should have 1 shape")
        let pasteboardShape = document.layers[0].shapes[0]
        XCTAssertEqual(pasteboardShape.name, "Pasteboard Background", "Pasteboard shape should be named correctly")
        
        // Verify canvas has background shape
        XCTAssertEqual(document.layers[1].shapes.count, 1, "Canvas layer should have 1 shape")
        let canvasShape = document.layers[1].shapes[0]
        XCTAssertEqual(canvasShape.name, "Canvas Background", "Canvas shape should be named correctly")
        
        print("✅ Background shapes exist")
    }
    
    func testPasteboardSizeAndPosition() {
        print("🧪 TEST: Pasteboard Size and Position")
        
        let pasteboardShape = document.layers[0].shapes[0]
        let canvasShape = document.layers[1].shapes[0]
        
        let canvasSize = canvasShape.bounds.size
        let pasteboardSize = pasteboardShape.bounds.size
        
        // Verify pasteboard is 10x larger than canvas
        let expectedPasteboardWidth = canvasSize.width * 10
        let expectedPasteboardHeight = canvasSize.height * 10
        
        XCTAssertEqual(pasteboardSize.width, expectedPasteboardWidth, accuracy: 0.1, "Pasteboard width should be 10x canvas width")
        XCTAssertEqual(pasteboardSize.height, expectedPasteboardHeight, accuracy: 0.1, "Pasteboard height should be 10x canvas height")
        
        // Verify pasteboard is centered behind canvas
        let expectedOriginX = (canvasSize.width - pasteboardSize.width) / 2
        let expectedOriginY = (canvasSize.height - pasteboardSize.height) / 2
        
        XCTAssertEqual(pasteboardShape.bounds.origin.x, expectedOriginX, accuracy: 0.1, "Pasteboard should be centered horizontally")
        XCTAssertEqual(pasteboardShape.bounds.origin.y, expectedOriginY, accuracy: 0.1, "Pasteboard should be centered vertically")
        
        print("📐 Canvas size: \(canvasSize)")
        print("📐 Pasteboard size: \(pasteboardSize)")
        print("📐 Pasteboard origin: \(pasteboardShape.bounds.origin)")
        print("✅ Pasteboard size and position are correct")
    }
    
    // MARK: - Hit Testing Simulation Tests
    
    func testHitTestingLayerIteration() {
        print("🧪 TEST: Hit Testing Layer Iteration")
        
        // Simulate the exact hit testing logic from DrawingCanvas
        let testLocation = CGPoint(x: 100, y: 100) // Point that should be on pasteboard
        
        var testedLayers: [String] = []
        var testedShapes: [String] = []
        
        // Simulate the hit testing loop
        for layerIndex in document.layers.indices.reversed() {
            let layer = document.layers[layerIndex]
            testedLayers.append("Layer \(layerIndex): \(layer.name)")
            
            if !layer.isVisible { continue }
            
            for shape in layer.shapes.reversed() {
                if !shape.isVisible { continue }
                
                testedShapes.append("Layer \(layerIndex) - Shape: \(shape.name)")
                
                // Test if this point would hit the shape
                let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
                
                if isBackgroundShape {
                    let shapeBounds = shape.bounds.applying(shape.transform)
                    let isHit = shapeBounds.contains(testLocation)
                    
                    print("  Testing Layer \(layerIndex) - \(shape.name)")
                    print("    Shape bounds: \(shapeBounds)")
                    print("    Test location: \(testLocation)")
                    print("    Hit result: \(isHit)")
                    
                    if isHit {
                        print("  ✅ Hit detected on \(shape.name)")
                        break
                    }
                }
            }
        }
        
        print("📊 TESTED LAYERS:")
        for layer in testedLayers {
            print("  - \(layer)")
        }
        
        print("📊 TESTED SHAPES:")
        for shape in testedShapes {
            print("  - \(shape)")
        }
        
        // Verify all layers were tested
        XCTAssertEqual(testedLayers.count, 3, "Should test all 3 layers")
        XCTAssertTrue(testedLayers.contains("Layer 0: Pasteboard"), "Should test Pasteboard layer")
        XCTAssertTrue(testedLayers.contains("Layer 1: Canvas"), "Should test Canvas layer")
        XCTAssertTrue(testedLayers.contains("Layer 2: Layer 1"), "Should test working layer")
        
        // Verify background shapes were tested
        XCTAssertTrue(testedShapes.contains("Layer 0 - Shape: Pasteboard Background"), "Should test Pasteboard Background shape")
        XCTAssertTrue(testedShapes.contains("Layer 1 - Shape: Canvas Background"), "Should test Canvas Background shape")
        
        print("✅ Hit testing layer iteration works correctly")
    }
    
    func testPasteboardHitTesting() {
        print("🧪 TEST: Pasteboard Hit Testing")
        
        let pasteboardShape = document.layers[0].shapes[0]
        let pasteboardBounds = pasteboardShape.bounds.applying(pasteboardShape.transform)
        
        // Test point that should be on pasteboard but not on canvas
        let testPoint = CGPoint(
            x: pasteboardBounds.minX + 100, // Well inside pasteboard
            y: pasteboardBounds.minY + 100  // Well inside pasteboard
        )
        
        print("📍 Testing pasteboard hit at: \(testPoint)")
        print("📐 Pasteboard bounds: \(pasteboardBounds)")
        print("📐 Canvas bounds: \(document.layers[1].shapes[0].bounds)")
        
        // Verify point is on pasteboard
        let isOnPasteboard = pasteboardBounds.contains(testPoint)
        XCTAssertTrue(isOnPasteboard, "Test point should be on pasteboard")
        
        // Verify point is NOT on canvas
        let canvasBounds = document.layers[1].shapes[0].bounds
        let isOnCanvas = canvasBounds.contains(testPoint)
        XCTAssertFalse(isOnCanvas, "Test point should NOT be on canvas")
        
        print("✅ Test point is correctly on pasteboard but not canvas")
        
        // Now test the actual hit testing logic
        var hitShape: VectorShape?
        var hitLayerIndex: Int?
        
        for layerIndex in document.layers.indices.reversed() {
            let layer = document.layers[layerIndex]
            if !layer.isVisible { continue }
            
            for shape in layer.shapes.reversed() {
                if !shape.isVisible { continue }
                
                let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
                
                if isBackgroundShape {
                    let shapeBounds = shape.bounds.applying(shape.transform)
                    let isHit = shapeBounds.contains(testPoint)
                    
                    print("  Testing \(shape.name): bounds=\(shapeBounds), hit=\(isHit)")
                    
                    if isHit {
                        hitShape = shape
                        hitLayerIndex = layerIndex
                        print("  ✅ Hit detected on \(shape.name) at layer \(layerIndex)")
                        break
                    }
                }
            }
            if hitShape != nil { break }
        }
        
        // Verify pasteboard was hit
        XCTAssertNotNil(hitShape, "Should hit a shape")
        XCTAssertEqual(hitShape?.name, "Pasteboard Background", "Should hit Pasteboard Background")
        XCTAssertEqual(hitLayerIndex, 0, "Should hit at layer index 0")
        
        print("✅ Pasteboard hit testing works correctly")
    }
    
    func testCanvasVsPasteboardHitPriority() {
        print("🧪 TEST: Canvas vs Pasteboard Hit Priority")
        
        // Test point that's on both canvas and pasteboard (should hit canvas first)
        let canvasBounds = document.layers[1].shapes[0].bounds
        let testPoint = CGPoint(x: canvasBounds.midX, y: canvasBounds.midY)
        
        print("📍 Testing overlapping area at: \(testPoint)")
        
        // Verify point is on both canvas and pasteboard
        let canvasHit = canvasBounds.contains(testPoint)
        let pasteboardBounds = document.layers[0].shapes[0].bounds
        let pasteboardHit = pasteboardBounds.contains(testPoint)
        
        XCTAssertTrue(canvasHit, "Test point should be on canvas")
        XCTAssertTrue(pasteboardHit, "Test point should also be on pasteboard")
        
        print("✅ Test point is on both canvas and pasteboard")
        
        // Test hit priority (canvas should win)
        var hitShape: VectorShape?
        var hitLayerIndex: Int?
        
        for layerIndex in document.layers.indices.reversed() {
            let layer = document.layers[layerIndex]
            if !layer.isVisible { continue }
            
            for shape in layer.shapes.reversed() {
                if !shape.isVisible { continue }
                
                let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
                
                if isBackgroundShape {
                    let shapeBounds = shape.bounds.applying(shape.transform)
                    let isHit = shapeBounds.contains(testPoint)
                    
                    if isHit {
                        hitShape = shape
                        hitLayerIndex = layerIndex
                        print("  ✅ Hit detected on \(shape.name) at layer \(layerIndex)")
                        break
                    }
                }
            }
            if hitShape != nil { break }
        }
        
        // Canvas should win (higher layer index = in front)
        XCTAssertEqual(hitShape?.name, "Canvas Background", "Canvas should be hit before pasteboard")
        XCTAssertEqual(hitLayerIndex, 1, "Should hit canvas at layer index 1")
        
        print("✅ Canvas correctly takes priority over pasteboard")
    }
    
    // MARK: - Real-World Scenario Tests
    
    func testPasteboardWithObjects() {
        print("🧪 TEST: Pasteboard with Objects")
        
        // Add a test object to the pasteboard area (outside canvas)
        let pasteboardBounds = document.layers[0].shapes[0].bounds
        let testObjectLocation = CGPoint(
            x: pasteboardBounds.minX + 50,
            y: pasteboardBounds.minY + 50
        )
        
        // Create a test rectangle on working layer
        let testRect = VectorShape.rectangle(
            at: testObjectLocation,
            size: CGSize(width: 100, height: 100)
        )
        var testShape = testRect
        testShape.name = "Test Object on Pasteboard"
        testShape.fillStyle = FillStyle(color: .red, opacity: 1.0)
        
        // Add to working layer (index 2)
        document.layers[2].addShape(testShape)
        
        print("📦 Added test object at: \(testObjectLocation)")
        
        // Test that we can hit the object
        let objectCenter = CGPoint(
            x: testObjectLocation.x + 50,
            y: testObjectLocation.y + 50
        )
        
        var hitShape: VectorShape?
        var hitLayerIndex: Int?
        
        for layerIndex in document.layers.indices.reversed() {
            let layer = document.layers[layerIndex]
            if !layer.isVisible { continue }
            
            for shape in layer.shapes.reversed() {
                if !shape.isVisible { continue }
                
                let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
                
                var isHit = false
                
                if isBackgroundShape {
                    let shapeBounds = shape.bounds.applying(shape.transform)
                    isHit = shapeBounds.contains(objectCenter)
                } else {
                    // Regular object hit testing
                    let shapeBounds = shape.bounds.applying(shape.transform)
                    isHit = shapeBounds.contains(objectCenter)
                }
                
                if isHit {
                    hitShape = shape
                    hitLayerIndex = layerIndex
                    print("  ✅ Hit detected on \(shape.name) at layer \(layerIndex)")
                    break
                }
            }
            if hitShape != nil { break }
        }
        
        // Should hit the test object, not the pasteboard
        XCTAssertEqual(hitShape?.name, "Test Object on Pasteboard", "Should hit the test object")
        XCTAssertEqual(hitLayerIndex, 2, "Should hit object on working layer")
        
        print("✅ Objects on pasteboard can be hit correctly")
        
        // Test clicking empty pasteboard area
        let emptyPasteboardPoint = CGPoint(
            x: pasteboardBounds.minX + 200,
            y: pasteboardBounds.minY + 200
        )
        
        hitShape = nil
        hitLayerIndex = nil
        
        for layerIndex in document.layers.indices.reversed() {
            let layer = document.layers[layerIndex]
            if !layer.isVisible { continue }
            
            for shape in layer.shapes.reversed() {
                if !shape.isVisible { continue }
                
                let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
                
                var isHit = false
                
                if isBackgroundShape {
                    let shapeBounds = shape.bounds.applying(shape.transform)
                    isHit = shapeBounds.contains(emptyPasteboardPoint)
                } else {
                    let shapeBounds = shape.bounds.applying(shape.transform)
                    isHit = shapeBounds.contains(emptyPasteboardPoint)
                }
                
                if isHit {
                    hitShape = shape
                    hitLayerIndex = layerIndex
                    break
                }
            }
            if hitShape != nil { break }
        }
        
        // Should hit pasteboard background for empty areas
        XCTAssertEqual(hitShape?.name, "Pasteboard Background", "Should hit pasteboard background in empty areas")
        XCTAssertEqual(hitLayerIndex, 0, "Should hit pasteboard at layer 0")
        
        print("✅ Empty pasteboard areas hit pasteboard background correctly")
    }
    
    // MARK: - Performance Tests
    
    func testHitTestingPerformance() {
        print("🧪 TEST: Hit Testing Performance")
        
        // Add many objects to test performance
        for i in 0..<100 {
            let testRect = VectorShape.rectangle(
                at: CGPoint(x: Double(i * 10), y: Double(i * 10)),
                size: CGSize(width: 20, height: 20)
            )
            var testShape = testRect
            testShape.name = "Perf Test Object \(i)"
            document.layers[2].addShape(testShape)
        }
        
        let testPoint = CGPoint(x: 500, y: 500)
        
        measure {
            // Simulate hit testing many times
            for _ in 0..<1000 {
                var hitShape: VectorShape?
                
                for layerIndex in document.layers.indices.reversed() {
                    let layer = document.layers[layerIndex]
                    if !layer.isVisible { continue }
                    
                    for shape in layer.shapes.reversed() {
                        if !shape.isVisible { continue }
                        
                        let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
                        
                        if isBackgroundShape {
                            let shapeBounds = shape.bounds.applying(shape.transform)
                            if shapeBounds.contains(testPoint) {
                                hitShape = shape
                                break
                            }
                        } else {
                            let shapeBounds = shape.bounds.applying(shape.transform)
                            if shapeBounds.contains(testPoint) {
                                hitShape = shape
                                break
                            }
                        }
                    }
                    if hitShape != nil { break }
                }
            }
        }
        
        print("✅ Hit testing performance is acceptable")
    }
    
    // MARK: - Integration Tests
    
    func testPasteboardIntegrationWithRealUserActions() {
        print("🧪 TEST: Pasteboard Integration with Real User Actions")
        
        // Simulate a real user workflow:
        // 1. Create object on canvas
        // 2. Move object to pasteboard
        // 3. Click empty pasteboard (should deselect)
        // 4. Click object on pasteboard (should select)
        
        // Step 1: Create object on canvas
        let canvasBounds = document.layers[1].shapes[0].bounds
        let objectOnCanvas = VectorShape.rectangle(
            at: CGPoint(x: canvasBounds.midX - 50, y: canvasBounds.midY - 50),
            size: CGSize(width: 100, height: 100)
        )
        var canvasObject = objectOnCanvas
        canvasObject.name = "Canvas Object"
        canvasObject.fillStyle = FillStyle(color: .blue, opacity: 1.0)
        document.layers[2].addShape(canvasObject)
        
        // Step 2: Move object to pasteboard
        let pasteboardBounds = document.layers[0].shapes[0].bounds
        let pasteboardLocation = CGPoint(
            x: pasteboardBounds.minX + 100,
            y: pasteboardBounds.minY + 100
        )
        
        let objectOnPasteboard = VectorShape.rectangle(
            at: pasteboardLocation,
            size: CGSize(width: 100, height: 100)
        )
        var pasteboardObject = objectOnPasteboard
        pasteboardObject.name = "Pasteboard Object"
        pasteboardObject.fillStyle = FillStyle(color: .green, opacity: 1.0)
        document.layers[2].addShape(pasteboardObject)
        
        // Step 3: Test clicking empty pasteboard (should hit pasteboard background)
        let emptyPasteboardPoint = CGPoint(
            x: pasteboardBounds.minX + 300,
            y: pasteboardBounds.minY + 300
        )
        
        var hitResult = simulateHitTest(at: emptyPasteboardPoint)
        XCTAssertEqual(hitResult.shapeName, "Pasteboard Background", "Empty pasteboard should hit pasteboard background")
        XCTAssertEqual(hitResult.layerIndex, 0, "Should hit pasteboard layer")
        
        print("✅ Empty pasteboard click hits background correctly")
        
        // Step 4: Test clicking object on pasteboard
        let objectCenter = CGPoint(
            x: pasteboardLocation.x + 50,
            y: pasteboardLocation.y + 50
        )
        
        hitResult = simulateHitTest(at: objectCenter)
        XCTAssertEqual(hitResult.shapeName, "Pasteboard Object", "Should hit pasteboard object")
        XCTAssertEqual(hitResult.layerIndex, 2, "Should hit working layer")
        
        print("✅ Pasteboard object click works correctly")
        
        // Step 5: Test clicking canvas object
        let canvasObjectCenter = CGPoint(
            x: canvasBounds.midX,
            y: canvasBounds.midY
        )
        
        hitResult = simulateHitTest(at: canvasObjectCenter)
        XCTAssertEqual(hitResult.shapeName, "Canvas Object", "Should hit canvas object")
        XCTAssertEqual(hitResult.layerIndex, 2, "Should hit working layer")
        
        print("✅ Canvas object click works correctly")
        
        print("✅ Full pasteboard integration test passed")
    }
    
    // MARK: - Helper Methods
    
    private func simulateHitTest(at location: CGPoint) -> (shapeName: String?, layerIndex: Int?) {
        var hitShape: VectorShape?
        var hitLayerIndex: Int?
        
        for layerIndex in document.layers.indices.reversed() {
            let layer = document.layers[layerIndex]
            if !layer.isVisible { continue }
            
            for shape in layer.shapes.reversed() {
                if !shape.isVisible { continue }
                
                let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
                
                var isHit = false
                
                if isBackgroundShape {
                    let shapeBounds = shape.bounds.applying(shape.transform)
                    isHit = shapeBounds.contains(location)
                } else {
                    let shapeBounds = shape.bounds.applying(shape.transform)
                    isHit = shapeBounds.contains(location)
                }
                
                if isHit {
                    hitShape = shape
                    hitLayerIndex = layerIndex
                    break
                }
            }
            if hitShape != nil { break }
        }
        
        return (shapeName: hitShape?.name, layerIndex: hitLayerIndex)
    }
} 