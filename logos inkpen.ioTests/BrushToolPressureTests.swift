//
//  BrushToolPressureTests.swift
//  logos inkpen.ioTests
//
//  Unit tests for brush tool pressure sensitivity and smoothness
//

@testable import logos_inkpen_io
import XCTest
import SwiftUI

final class BrushToolPressureTests: XCTestCase {

    // MARK: - Brush Tool Pressure Sensitivity Tests

    func testBrushPressureSensitivity() throws {
        // Create a test document and canvas
        let document = VectorDocument()
        let canvas = DrawingCanvas(document: document)

        // Enable pressure sensitivity
        AppState.shared.pressureSensitivityEnabled = true
        document.currentTool = .brush
        document.currentBrushPressureSensitivity = 1.0  // Maximum sensitivity
        document.currentBrushThickness = 20.0

        // Reset pressure manager
        PressureManager.shared.resetForNewDrawing()

        // Simulate brush stroke with varying pressure
        let testPoints: [(location: CGPoint, pressure: Double)] = [
            (CGPoint(x: 100, y: 100), 0.2),  // Light pressure
            (CGPoint(x: 150, y: 100), 0.5),  // Medium pressure
            (CGPoint(x: 200, y: 100), 1.0),  // Full pressure
            (CGPoint(x: 250, y: 100), 0.8),  // Heavy pressure
            (CGPoint(x: 300, y: 100), 0.3),  // Light pressure
        ]

        // Start brush stroke
        canvas.handleBrushDragStart(at: testPoints[0].location)

        // Simulate pressure events and drag updates
        for point in testPoints {
            PressureManager.shared.processRealPressure(point.pressure, at: point.location, isTabletEvent: true)
            canvas.handleBrushDragUpdate(at: point.location)
        }

        // End brush stroke
        canvas.handleBrushDragEnd()

        // Verify that brush stroke was created with varying thickness
        XCTAssertFalse(canvas.brushRawPoints.isEmpty, "Brush should have captured raw points")
        XCTAssertEqual(canvas.brushRawPoints.count, testPoints.count + 1, "Should have all test points plus start point")

        // Check pressure values were captured
        for (index, point) in testPoints.enumerated() {
            if index < canvas.brushRawPoints.count - 1 {
                let capturedPoint = canvas.brushRawPoints[index + 1]
                XCTAssertEqual(capturedPoint.location, point.location, "Location should match")
                // Pressure might be processed, so check it's in valid range
                XCTAssertGreaterThan(capturedPoint.pressure, 0.0, "Pressure should be positive")
                XCTAssertLessThanOrEqual(capturedPoint.pressure, 2.0, "Pressure should be <= 2.0")
            }
        }
    }

    func testBrushSmoothness() throws {
        // Create a test document and canvas
        let document = VectorDocument()
        let canvas = DrawingCanvas(document: document)

        document.currentTool = .brush
        document.currentBrushSmoothingTolerance = 1.0  // Default tolerance
        document.advancedSmoothingEnabled = true

        // Create a curved path with many points
        var testPoints: [CGPoint] = []
        for i in 0...50 {
            let angle = Double(i) * .pi / 25.0
            let x = 200 + cos(angle) * 100
            let y = 200 + sin(angle) * 100
            testPoints.append(CGPoint(x: x, y: y))
        }

        // Start brush stroke
        canvas.handleBrushDragStart(at: testPoints[0])

        // Add all points
        for point in testPoints.dropFirst() {
            canvas.handleBrushDragUpdate(at: point)
        }

        // End brush stroke
        canvas.handleBrushDragEnd()

        // Verify smoothing preserved enough points for smooth curve
        XCTAssertFalse(canvas.brushSimplifiedPoints.isEmpty, "Should have simplified points")
        XCTAssertGreaterThanOrEqual(canvas.brushSimplifiedPoints.count, 20, "Should keep at least 20 points for smoothness")

        // Check that simplified points still represent the curve
        let firstPoint = canvas.brushSimplifiedPoints.first
        let lastPoint = canvas.brushSimplifiedPoints.last
        XCTAssertNotNil(firstPoint, "Should have first point")
        XCTAssertNotNil(lastPoint, "Should have last point")
    }

    func testPressureManagerDetection() throws {
        let manager = PressureManager.shared

        // Reset state
        manager.resetForNewDrawing()

        // Test real pressure detection
        manager.processRealPressure(0.7, at: CGPoint(x: 100, y: 100), isTabletEvent: true)
        XCTAssertTrue(manager.hasRealPressureInput, "Should detect real pressure input")
        XCTAssertEqual(manager.currentPressure, 0.7, accuracy: 0.01, "Should store correct pressure")

        // Test pressure sensitivity disabled
        AppState.shared.pressureSensitivityEnabled = false
        manager.processRealPressure(0.5, at: CGPoint(x: 200, y: 200), isTabletEvent: true)
        XCTAssertEqual(manager.currentPressure, 1.0, "Should return 1.0 when disabled")

        // Re-enable and test simulation fallback
        AppState.shared.pressureSensitivityEnabled = true
        manager.hasRealPressureInput = false  // Force simulation mode
        let simulatedPressure = manager.getPressure(for: CGPoint(x: 300, y: 300), sensitivity: 0.5)
        XCTAssertGreaterThan(simulatedPressure, 0.0, "Should return valid simulated pressure")
        XCTAssertLessThanOrEqual(simulatedPressure, 2.0, "Simulated pressure should be in range")
    }

    func testBrushThicknessVariationWithPressure() throws {
        let document = VectorDocument()
        let canvas = DrawingCanvas(document: document)

        // Set up brush with maximum pressure sensitivity
        document.currentTool = .brush
        document.currentBrushPressureSensitivity = 1.0
        document.currentBrushThickness = 30.0
        AppState.shared.pressureSensitivityEnabled = true

        // Create points with extreme pressure variations
        let testPoints: [(location: CGPoint, pressure: Double)] = [
            (CGPoint(x: 100, y: 100), 0.1),   // Very light
            (CGPoint(x: 120, y: 100), 0.3),
            (CGPoint(x: 140, y: 100), 0.5),
            (CGPoint(x: 160, y: 100), 0.7),
            (CGPoint(x: 180, y: 100), 0.9),
            (CGPoint(x: 200, y: 100), 1.0),   // Full pressure
            (CGPoint(x: 220, y: 100), 0.8),
            (CGPoint(x: 240, y: 100), 0.6),
            (CGPoint(x: 260, y: 100), 0.4),
            (CGPoint(x: 280, y: 100), 0.2),
            (CGPoint(x: 300, y: 100), 0.1),   // Very light again
        ]

        // Start and execute stroke
        canvas.handleBrushDragStart(at: testPoints[0].location)

        for point in testPoints {
            PressureManager.shared.processRealPressure(point.pressure, at: point.location, isTabletEvent: true)
            canvas.handleBrushDragUpdate(at: point.location)
        }

        canvas.handleBrushDragEnd()

        // Verify pressure variation was captured
        XCTAssertEqual(canvas.brushRawPoints.count, testPoints.count + 1, "All pressure points should be captured")

        // Check that pressure values show variation
        let pressures = canvas.brushRawPoints.map { $0.pressure }
        let minPressure = pressures.min() ?? 1.0
        let maxPressure = pressures.max() ?? 1.0

        XCTAssertGreaterThan(maxPressure - minPressure, 0.5, "Should have significant pressure variation")
        print("Pressure range: \(minPressure) to \(maxPressure)")
    }
}