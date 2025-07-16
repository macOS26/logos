//
//  PasteboardDiagnostics.swift
//  logos
//
//  Created by AI Assistant
//  Programmatic pasteboard diagnostics and testing
//

import Foundation
import CoreGraphics

class PasteboardDiagnostics {
    
    static let shared = PasteboardDiagnostics()
    private init() {}
    
    /// Run comprehensive pasteboard diagnostics
    func runDiagnostics(on document: VectorDocument) -> DiagnosticReport {
        // print("🔍 RUNNING PASTEBOARD DIAGNOSTICS")
        // print("=" * 50)
        
        var report = DiagnosticReport()
        
        // Test 1: Layer Structure
        report.layerStructure = testLayerStructure(document)
        
        // Test 2: Background Shapes
        report.backgroundShapes = testBackgroundShapes(document)
        
        // Test 3: Hit Testing Simulation
        report.hitTesting = testHitTestingSimulation(document)
        
        // Test 4: Real-world scenarios
        report.realWorldScenarios = testRealWorldScenarios(document)
        
        // Test 5: Performance
        report.performance = testPerformance(document)
        
        // print("🔍 DIAGNOSTICS COMPLETE")
        // print("=" * 50)
        
        return report
    }
    
    // MARK: - Individual Test Functions
    
    private func testLayerStructure(_ document: VectorDocument) -> LayerStructureTest {
        // print("🧪 TEST 1: Layer Structure")
        
        var test = LayerStructureTest()
        
        // Check layer count
        test.layerCount = document.layers.count
        test.expectedLayerCount = 3
        test.layerCountCorrect = (test.layerCount == test.expectedLayerCount)
        
        // Check layer order and names
        if document.layers.count >= 3 {
            test.pasteboardLayerName = document.layers[0].name
            test.canvasLayerName = document.layers[1].name
            test.workingLayerName = document.layers[2].name
            
            test.layerNamesCorrect = (
                test.pasteboardLayerName == "Pasteboard" &&
                test.canvasLayerName == "Canvas" &&
                test.workingLayerName == "Layer 1"
            )
            
            // Check locked status
            test.pasteboardLocked = document.layers[0].isLocked
            test.canvasLocked = document.layers[1].isLocked
            test.workingLayerLocked = document.layers[2].isLocked
            
            test.lockStatusCorrect = (
                test.pasteboardLocked == true &&
                test.canvasLocked == true &&
                test.workingLayerLocked == false
            )
        }
        
        test.passed = test.layerCountCorrect && test.layerNamesCorrect && test.lockStatusCorrect
        
        // print("  Layer count: \(test.layerCount)/\(test.expectedLayerCount) ✓")
        // print("  Layer names: \(test.layerNamesCorrect ? "✓" : "✗")")
        // print("  Lock status: \(test.lockStatusCorrect ? "✓" : "✗")")
        // print("  Overall: \(test.passed ? "✓ PASS" : "✗ FAIL")")
        
        return test
    }
    
    private func testBackgroundShapes(_ document: VectorDocument) -> BackgroundShapesTest {
        // print("🧪 TEST 2: Background Shapes")
        
        var test = BackgroundShapesTest()
        
        if document.layers.count >= 2 {
            // Check pasteboard shape
            let pasteboardLayer = document.layers[0]
            test.pasteboardShapeCount = pasteboardLayer.shapes.count
            if pasteboardLayer.shapes.count > 0 {
                let pasteboardShape = pasteboardLayer.shapes[0]
                test.pasteboardShapeName = pasteboardShape.name
                test.pasteboardBounds = pasteboardShape.bounds
                test.pasteboardFillColor = pasteboardShape.fillStyle?.color
            }
            
            // Check canvas shape
            let canvasLayer = document.layers[1]
            test.canvasShapeCount = canvasLayer.shapes.count
            if canvasLayer.shapes.count > 0 {
                let canvasShape = canvasLayer.shapes[0]
                test.canvasShapeName = canvasShape.name
                test.canvasBounds = canvasShape.bounds
                test.canvasFillColor = canvasShape.fillStyle?.color
            }
            
            // Validate
            test.pasteboardShapeCorrect = (
                test.pasteboardShapeCount == 1 &&
                test.pasteboardShapeName == "Pasteboard Background"
            )
            
            test.canvasShapeCorrect = (
                test.canvasShapeCount == 1 &&
                test.canvasShapeName == "Canvas Background"
            )
            
            // Check sizing (pasteboard should be 10x canvas)
            if let canvasBounds = test.canvasBounds,
               let pasteboardBounds = test.pasteboardBounds {
                let expectedPasteboardWidth = canvasBounds.width * 10
                let expectedPasteboardHeight = canvasBounds.height * 10
                
                test.sizingCorrect = (
                    abs(pasteboardBounds.width - expectedPasteboardWidth) < 1.0 &&
                    abs(pasteboardBounds.height - expectedPasteboardHeight) < 1.0
                )
                
                // Check positioning (pasteboard should be centered)
                let expectedOriginX = (canvasBounds.width - pasteboardBounds.width) / 2
                let expectedOriginY = (canvasBounds.height - pasteboardBounds.height) / 2
                
                test.positioningCorrect = (
                    abs(pasteboardBounds.origin.x - expectedOriginX) < 1.0 &&
                    abs(pasteboardBounds.origin.y - expectedOriginY) < 1.0
                )
            }
        }
        
        test.passed = test.pasteboardShapeCorrect && test.canvasShapeCorrect && test.sizingCorrect && test.positioningCorrect
        
        // print("  Pasteboard shape: \(test.pasteboardShapeCorrect ? "✓" : "✗")")
        // print("  Canvas shape: \(test.canvasShapeCorrect ? "✓" : "✗")")
        // print("  Sizing: \(test.sizingCorrect ? "✓" : "✗")")
        // print("  Positioning: \(test.positioningCorrect ? "✓" : "✗")")
        // print("  Overall: \(test.passed ? "✓ PASS" : "✗ FAIL")")
        
        return test
    }
    
    private func testHitTestingSimulation(_ document: VectorDocument) -> HitTestingTest {
        // print("🧪 TEST 3: Hit Testing Simulation")
        
        var test = HitTestingTest()
        
        guard document.layers.count >= 3 else {
            test.passed = false
            // print("  ✗ FAIL: Insufficient layers")
            return test
        }
        
        // Test 1: Pasteboard-only hit
        let pasteboardBounds = document.layers[0].shapes[0].bounds
        let pasteboardOnlyPoint = CGPoint(
            x: pasteboardBounds.minX + 100,
            y: pasteboardBounds.minY + 100
        )
        
        let pasteboardHit = simulateHitTest(document: document, at: pasteboardOnlyPoint)
        test.pasteboardOnlyHit = pasteboardHit
        test.pasteboardHitCorrect = (
            pasteboardHit.hitShape?.name == "Pasteboard Background" &&
            pasteboardHit.layerIndex == 0
        )
        
        // Test 2: Canvas priority hit
        let canvasBounds = document.layers[1].shapes[0].bounds
        let canvasPoint = CGPoint(x: canvasBounds.midX, y: canvasBounds.midY)
        
        let canvasHit = simulateHitTest(document: document, at: canvasPoint)
        test.canvasPriorityHit = canvasHit
        test.canvasPriorityCorrect = (
            canvasHit.hitShape?.name == "Canvas Background" &&
            canvasHit.layerIndex == 1
        )
        
        // Test 3: Layer iteration completeness
        test.layerIterationTest = testLayerIteration(document)
        
        test.passed = test.pasteboardHitCorrect && test.canvasPriorityCorrect && test.layerIterationTest.passed
        
        // print("  Pasteboard hit: \(test.pasteboardHitCorrect ? "✓" : "✗")")
        // print("  Canvas priority: \(test.canvasPriorityCorrect ? "✓" : "✗")")
        // print("  Layer iteration: \(test.layerIterationTest.passed ? "✓" : "✗")")
        // print("  Overall: \(test.passed ? "✓ PASS" : "✗ FAIL")")
        
        return test
    }
    
    private func testLayerIteration(_ document: VectorDocument) -> LayerIterationTest {
        // print("    🔍 Testing layer iteration...")
        
        var test = LayerIterationTest()
        let testPoint = CGPoint(x: 100, y: 100)
        
        // Track which layers and shapes are tested
        var testedLayers: [String] = []
        var testedShapes: [String] = []
        
        // Simulate the exact hit testing loop from DrawingCanvas
        for layerIndex in document.layers.indices.reversed() {
            let layer = document.layers[layerIndex]
            testedLayers.append("Layer \(layerIndex): \(layer.name)")
            
            if !layer.isVisible { continue }
            
            for shape in layer.shapes.reversed() {
                if !shape.isVisible { continue }
                
                testedShapes.append("Layer \(layerIndex) - Shape: \(shape.name)")
                
                let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
                
                if isBackgroundShape {
                    let shapeBounds = shape.bounds.applying(shape.transform)
                    let isHit = shapeBounds.contains(testPoint)
                    
                    // print("      Testing Layer \(layerIndex) - \(shape.name): \(isHit ? "HIT" : "miss")")
                    
                    if isHit {
                        break
                    }
                }
            }
        }
        
        test.testedLayers = testedLayers
        test.testedShapes = testedShapes
        
        // Verify all expected layers were tested
        let expectedLayers = ["Layer 2: Layer 1", "Layer 1: Canvas", "Layer 0: Pasteboard"]
        test.allLayersTested = expectedLayers.allSatisfy { expected in
            testedLayers.contains(expected)
        }
        
        // Verify background shapes were tested
        let expectedShapes = ["Layer 1 - Shape: Canvas Background", "Layer 0 - Shape: Pasteboard Background"]
        test.allBackgroundShapesTested = expectedShapes.allSatisfy { expected in
            testedShapes.contains(expected)
        }
        
        test.passed = test.allLayersTested && test.allBackgroundShapesTested
        
        // print("      Layers tested: \(test.allLayersTested ? "✓" : "✗")")
        // print("      Background shapes tested: \(test.allBackgroundShapesTested ? "✓" : "✗")")
        
        return test
    }
    
    private func testRealWorldScenarios(_ document: VectorDocument) -> RealWorldScenariosTest {
        // print("🧪 TEST 4: Real-World Scenarios")
        
        var test = RealWorldScenariosTest()
        
        // Add test objects to working layer
        let pasteboardBounds = document.layers[0].shapes[0].bounds
        let canvasBounds = document.layers[1].shapes[0].bounds
        
        // Object on pasteboard
        let pasteboardObjectLocation = CGPoint(
            x: pasteboardBounds.minX + 50,
            y: pasteboardBounds.minY + 50
        )
        
        let pasteboardObject = VectorShape.rectangle(
            at: pasteboardObjectLocation,
            size: CGSize(width: 50, height: 50)
        )
        var pasteboardShape = pasteboardObject
        pasteboardShape.name = "Test Pasteboard Object"
        pasteboardShape.fillStyle = FillStyle(color: .rgb(RGBColor(red: 1, green: 0, blue: 0)), opacity: 1.0)
        
        // Object on canvas
        let canvasObjectLocation = CGPoint(
            x: canvasBounds.midX - 25,
            y: canvasBounds.midY - 25
        )
        
        let canvasObject = VectorShape.rectangle(
            at: canvasObjectLocation,
            size: CGSize(width: 50, height: 50)
        )
        var canvasShape = canvasObject
        canvasShape.name = "Test Canvas Object"
        canvasShape.fillStyle = FillStyle(color: .rgb(RGBColor(red: 0, green: 0, blue: 1)), opacity: 1.0)
        
        // Add to working layer temporarily
        document.layers[2].addShape(pasteboardShape)
        document.layers[2].addShape(canvasShape)
        
        // Test scenarios
        
        // 1. Hit object on pasteboard
        let pasteboardObjectCenter = CGPoint(
            x: pasteboardObjectLocation.x + 25,
            y: pasteboardObjectLocation.y + 25
        )
        
        let pasteboardObjectHit = simulateHitTest(document: document, at: pasteboardObjectCenter)
        test.pasteboardObjectHit = pasteboardObjectHit
        test.pasteboardObjectHitCorrect = (
            pasteboardObjectHit.hitShape?.name == "Test Pasteboard Object" &&
            pasteboardObjectHit.layerIndex == 2
        )
        
        // 2. Hit object on canvas
        let canvasObjectCenter = CGPoint(
            x: canvasObjectLocation.x + 25,
            y: canvasObjectLocation.y + 25
        )
        
        let canvasObjectHit = simulateHitTest(document: document, at: canvasObjectCenter)
        test.canvasObjectHit = canvasObjectHit
        test.canvasObjectHitCorrect = (
            canvasObjectHit.hitShape?.name == "Test Canvas Object" &&
            canvasObjectHit.layerIndex == 2
        )
        
        // 3. Hit empty pasteboard area
        let emptyPasteboardPoint = CGPoint(
            x: pasteboardBounds.minX + 200,
            y: pasteboardBounds.minY + 200
        )
        
        let emptyPasteboardHit = simulateHitTest(document: document, at: emptyPasteboardPoint)
        test.emptyPasteboardHit = emptyPasteboardHit
        test.emptyPasteboardHitCorrect = (
            emptyPasteboardHit.hitShape?.name == "Pasteboard Background" &&
            emptyPasteboardHit.layerIndex == 0
        )
        
        // Clean up test objects
        document.layers[2].shapes.removeAll { shape in
            shape.name == "Test Pasteboard Object" || shape.name == "Test Canvas Object"
        }
        
        test.passed = test.pasteboardObjectHitCorrect && test.canvasObjectHitCorrect && test.emptyPasteboardHitCorrect
        
        // print("  Pasteboard object hit: \(test.pasteboardObjectHitCorrect ? "✓" : "✗")")
        // print("  Canvas object hit: \(test.canvasObjectHitCorrect ? "✓" : "✗")")
        // print("  Empty pasteboard hit: \(test.emptyPasteboardHitCorrect ? "✓" : "✗")")
        // print("  Overall: \(test.passed ? "✓ PASS" : "✗ FAIL")")
        
        return test
    }
    
    private func testPerformance(_ document: VectorDocument) -> PerformanceTest {
        // print("🧪 TEST 5: Performance")
        
        var test = PerformanceTest()
        
        // Add many test objects
        let originalShapeCount = document.layers[2].shapes.count
        
        for i in 0..<100 {
            let testRect = VectorShape.rectangle(
                at: CGPoint(x: Double(i * 5), y: Double(i * 5)),
                size: CGSize(width: 10, height: 10)
            )
            var testShape = testRect
            testShape.name = "Perf Test \(i)"
            document.layers[2].addShape(testShape)
        }
        
        let testPoint = CGPoint(x: 250, y: 250)
        
        // Measure performance
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<1000 {
            _ = simulateHitTest(document: document, at: testPoint)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        test.totalTime = endTime - startTime
        test.averageTimePerHitTest = test.totalTime / 1000.0
        
        // Clean up
        while document.layers[2].shapes.count > originalShapeCount {
            document.layers[2].shapes.removeLast()
        }
        
        test.passed = test.averageTimePerHitTest < 0.001 // Less than 1ms per hit test
        
        // print("  Total time: \(String(format: "%.4f", test.totalTime))s")
        // print("  Average per hit test: \(String(format: "%.6f", test.averageTimePerHitTest))s")
        // print("  Overall: \(test.passed ? "✓ PASS" : "✗ FAIL")")
        
        return test
    }
    
    // MARK: - Helper Functions
    
    private func simulateHitTest(document: VectorDocument, at location: CGPoint) -> HitTestResult {
        var hitShape: VectorShape?
        var hitLayerIndex: Int?
        var testedLayers: [String] = []
        var testedShapes: [String] = []
        
        for layerIndex in document.layers.indices.reversed() {
            let layer = document.layers[layerIndex]
            testedLayers.append("Layer \(layerIndex): \(layer.name)")
            
            if !layer.isVisible { continue }
            
            for shape in layer.shapes.reversed() {
                if !shape.isVisible { continue }
                
                testedShapes.append("Layer \(layerIndex) - Shape: \(shape.name)")
                
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
        
        return HitTestResult(
            hitShape: hitShape,
            layerIndex: hitLayerIndex,
            testedLayers: testedLayers,
            testedShapes: testedShapes,
            testLocation: location
        )
    }
}

// MARK: - Data Structures

struct DiagnosticReport {
    var layerStructure = LayerStructureTest()
    var backgroundShapes = BackgroundShapesTest()
    var hitTesting = HitTestingTest()
    var realWorldScenarios = RealWorldScenariosTest()
    var performance = PerformanceTest()
    
    var overallPassed: Bool {
        return layerStructure.passed &&
               backgroundShapes.passed &&
               hitTesting.passed &&
               realWorldScenarios.passed &&
               performance.passed
    }
    
    func printSummary() {
        // print("\n📊 DIAGNOSTIC REPORT SUMMARY")
        // print("=" * 40)
        // print("Layer Structure:     \(layerStructure.passed ? "✓ PASS" : "✗ FAIL")")
        // print("Background Shapes:   \(backgroundShapes.passed ? "✓ PASS" : "✗ FAIL")")
        // print("Hit Testing:         \(hitTesting.passed ? "✓ PASS" : "✗ FAIL")")
        // print("Real-World Scenarios:\(realWorldScenarios.passed ? "✓ PASS" : "✗ FAIL")")
        // print("Performance:         \(performance.passed ? "✓ PASS" : "✗ FAIL")")
        // print("=" * 40)
        // print("OVERALL:             \(overallPassed ? "✅ PASS" : "❌ FAIL")")
        // print("=" * 40)
    }
}

struct LayerStructureTest {
    var layerCount = 0
    var expectedLayerCount = 3
    var layerCountCorrect = false
    
    var pasteboardLayerName = ""
    var canvasLayerName = ""
    var workingLayerName = ""
    var layerNamesCorrect = false
    
    var pasteboardLocked = false
    var canvasLocked = false
    var workingLayerLocked = false
    var lockStatusCorrect = false
    
    var passed = false
}

struct BackgroundShapesTest {
    var pasteboardShapeCount = 0
    var pasteboardShapeName = ""
    var pasteboardBounds: CGRect?
    var pasteboardFillColor: VectorColor?
    var pasteboardShapeCorrect = false
    
    var canvasShapeCount = 0
    var canvasShapeName = ""
    var canvasBounds: CGRect?
    var canvasFillColor: VectorColor?
    var canvasShapeCorrect = false
    
    var sizingCorrect = false
    var positioningCorrect = false
    
    var passed = false
}

struct HitTestingTest {
    var pasteboardOnlyHit = HitTestResult()
    var pasteboardHitCorrect = false
    
    var canvasPriorityHit = HitTestResult()
    var canvasPriorityCorrect = false
    
    var layerIterationTest = LayerIterationTest()
    
    var passed = false
}

struct LayerIterationTest {
    var testedLayers: [String] = []
    var testedShapes: [String] = []
    var allLayersTested = false
    var allBackgroundShapesTested = false
    var passed = false
}

struct RealWorldScenariosTest {
    var pasteboardObjectHit = HitTestResult()
    var pasteboardObjectHitCorrect = false
    
    var canvasObjectHit = HitTestResult()
    var canvasObjectHitCorrect = false
    
    var emptyPasteboardHit = HitTestResult()
    var emptyPasteboardHitCorrect = false
    
    var passed = false
}

struct PerformanceTest {
    var totalTime: Double = 0.0
    var averageTimePerHitTest: Double = 0.0
    var passed = false
}

struct HitTestResult {
    var hitShape: VectorShape?
    var layerIndex: Int?
    var testedLayers: [String] = []
    var testedShapes: [String] = []
    var testLocation = CGPoint.zero
}

// Helper extension for string repetition
extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
} 
