//
//  BrushStrokeTaperingTests.swift
//  logos inkpen.io Tests
//
//  Tests for brush stroke tapering to ensure no bulbous/phallic appearance at stroke beginnings
//

import XCTest
@testable import logos_inkpen_io

class BrushStrokeTaperingTests: XCTestCase {

    var canvas: DrawingCanvas!
    var document: Document!
    var appState: AppState!

    override func setUp() {
        super.setUp()
        document = Document()
        appState = AppState()

        // Add a layer for testing
        document.layers.append(Layer(name: "Test Layer", isVisible: true, isLocked: false, opacity: 1.0))
        document.selectedLayerIndex = 0

        // Create canvas
        canvas = DrawingCanvas(
            document: document,
            appState: appState,
            selectedObject: .constant(nil),
            selectedVector: .constant(nil)
        )
    }

    override func tearDown() {
        canvas = nil
        document = nil
        appState = nil
        super.tearDown()
    }

    // Test that stroke starts very thin (not bulbous)
    func testStrokeStartsThin() {
        // Create test points for a straight line
        let startPoint = CGPoint(x: 100, y: 100)
        let endPoint = CGPoint(x: 200, y: 100)

        let centerPoints = [startPoint, endPoint]
        let rawPoints = [
            BrushPoint(location: startPoint, pressure: 1.0, timestamp: Date()),
            BrushPoint(location: endPoint, pressure: 1.0, timestamp: Date())
        ]

        // Generate path with our tapering algorithm
        let path = canvas.generateSmoothVariableWidthPath(
            centerPoints: centerPoints,
            rawPoints: rawPoints,
            thickness: 20.0,
            pressureSensitivity: 1.0,
            taper: 1.0
        )

        // Extract the first few points from the generated path
        let cgPath = path.cgPath
        var firstPointThickness: CGFloat = 0

        // Measure thickness at the beginning
        cgPath.applyWithBlock { element in
            switch element.pointee.type {
            case .moveToPoint:
                let point = element.pointee.points[0]
                // The initial point should be very close to the center line
                // indicating a very thin start
                let distanceFromCenter = abs(point.y - startPoint.y)
                firstPointThickness = distanceFromCenter
            default:
                break
            }
        }

        // Assert that the beginning is thin (less than 20% of max thickness)
        XCTAssertLessThan(firstPointThickness, 4.0, "Stroke beginning should be very thin, not bulbous")
    }

    // Test curved stroke tapering
    func testCurvedStrokeTapering() {
        // Create test points for a curved line
        let points = [
            CGPoint(x: 100, y: 100),
            CGPoint(x: 120, y: 105),
            CGPoint(x: 140, y: 115),
            CGPoint(x: 160, y: 130),
            CGPoint(x: 180, y: 150),
            CGPoint(x: 200, y: 175)
        ]

        let rawPoints = points.map {
            BrushPoint(location: $0, pressure: 1.0, timestamp: Date())
        }

        // Generate path
        let path = canvas.generateSmoothVariableWidthPath(
            centerPoints: points,
            rawPoints: rawPoints,
            thickness: 20.0,
            pressureSensitivity: 1.0,
            taper: 1.0
        )

        // Verify the path is not empty
        XCTAssertFalse(path.cgPath.isEmpty, "Generated path should not be empty")

        // Check that bounds are reasonable
        let bounds = path.cgPath.boundingBox
        XCTAssertTrue(bounds.width > 0 && bounds.height > 0, "Path should have valid bounds")
    }

    // Test that straight lines get aggressive tapering
    func testStraightLineTapering() {
        let startPoint = CGPoint(x: 100, y: 100)
        let endPoint = CGPoint(x: 300, y: 100)

        // Add interpolated points for proper tapering
        var interpolatedPoints: [CGPoint] = [startPoint]
        for i in 1...5 {
            let t = Double(i) / 6.0
            interpolatedPoints.append(CGPoint(
                x: startPoint.x + (endPoint.x - startPoint.x) * t,
                y: startPoint.y
            ))
        }
        interpolatedPoints.append(endPoint)

        let rawPoints = interpolatedPoints.map {
            BrushPoint(location: $0, pressure: 1.0, timestamp: Date())
        }

        // Generate path
        let path = canvas.generateSmoothVariableWidthPath(
            centerPoints: interpolatedPoints,
            rawPoints: rawPoints,
            thickness: 20.0,
            pressureSensitivity: 1.0,
            taper: 1.0
        )

        // Verify path generation
        XCTAssertFalse(path.cgPath.isEmpty, "Straight line path should not be empty")

        // Check that the path has reasonable bounds
        let bounds = path.cgPath.boundingBox
        XCTAssertGreaterThan(bounds.width, 100, "Path should span horizontally")
        XCTAssertGreaterThan(bounds.height, 0, "Path should have some thickness")
        XCTAssertLessThan(bounds.height, 25, "Path thickness should be controlled")
    }

    // Test preview matches final path
    func testPreviewMatchesFinal() {
        let points = [
            CGPoint(x: 100, y: 100),
            CGPoint(x: 150, y: 120),
            CGPoint(x: 200, y: 100)
        ]

        let rawPoints = points.map {
            BrushPoint(location: $0, pressure: 0.8, timestamp: Date())
        }

        // Generate preview path
        canvas.brushRawPoints = rawPoints
        let previewPath = canvas.generateLivePreviewPath()

        // Generate final path
        let finalPath = canvas.generateSmoothVariableWidthPath(
            centerPoints: points,
            rawPoints: rawPoints,
            thickness: 15.0,
            pressureSensitivity: 1.0,
            taper: 1.0
        )

        // Both paths should have similar bounds
        let previewBounds = previewPath.cgPath.boundingBox
        let finalBounds = finalPath.cgPath.boundingBox

        XCTAssertEqual(previewBounds.width, finalBounds.width, accuracy: 5.0,
                      "Preview and final widths should be similar")
        XCTAssertEqual(previewBounds.height, finalBounds.height, accuracy: 5.0,
                      "Preview and final heights should be similar")
    }
}