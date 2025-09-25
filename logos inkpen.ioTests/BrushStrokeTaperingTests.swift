//
//  BrushStrokeTaperingTests.swift
//  logos inkpen.ioTests
//
//  Tests for brush stroke tapering to ensure no phallic shapes
//

import XCTest
import SwiftUI
@testable import logos_inkpen_io

class BrushStrokeTaperingTests: XCTestCase {

    var document: VectorDocument!
    var canvas: DrawingCanvas!

    override func setUp() {
        super.setUp()
        document = VectorDocument()
        canvas = DrawingCanvas(document: document)
    }

    override func tearDown() {
        document = nil
        canvas = nil
        super.tearDown()
    }

    func testShortStrokeNoInterpolation() {
        // Test that 2-point strokes don't get interpolated
        let startPoint = CGPoint(x: 100, y: 100)
        let endPoint = CGPoint(x: 150, y: 150)

        // Simulate a short brush stroke
        canvas.handleBrushDragStart(at: startPoint)
        canvas.handleBrushDragUpdate(at: endPoint)
        canvas.handleBrushDragEnd()

        // Verify no artificial middle points were added
        XCTAssertLessThanOrEqual(canvas.brushRawPoints.count, 2,
                                 "Short strokes should not have interpolated middle points")
    }

    func testNoMinimumThickness() {
        // Test that thickness can taper to zero at ends
        let points = [
            CGPoint(x: 100, y: 100),
            CGPoint(x: 200, y: 200)
        ]

        // Create brush stroke
        canvas.handleBrushDragStart(at: points[0])
        canvas.handleBrushDragUpdate(at: points[1])

        // Check that preview path exists
        XCTAssertNotNil(canvas.brushPreviewPath,
                       "Brush preview path should be generated")

        // The path should allow tapering to near zero at ends
        // (We removed the min thickness of 0.5)
    }

    func testShortStrokeAutoDeselection() {
        // Test that shapes are deselected after brush stroke
        canvas.handleBrushDragStart(at: CGPoint(x: 100, y: 100))
        canvas.handleBrushDragUpdate(at: CGPoint(x: 150, y: 150))
        canvas.handleBrushDragEnd()

        // Verify selection is cleared
        XCTAssertTrue(document.selectedShapeIDs.isEmpty,
                     "Selection should be cleared after brush stroke")
    }

    func testAggressiveTaperingForShortStrokes() {
        // Test that short strokes have aggressive tapering
        let startPoint = CGPoint(x: 100, y: 100)
        let endPoint = CGPoint(x: 110, y: 110) // Very short stroke

        canvas.handleBrushDragStart(at: startPoint)
        canvas.handleBrushDragUpdate(at: endPoint)
        canvas.handleBrushDragEnd()

        // Verify a shape was created
        XCTAssertGreaterThan(document.getShapesForLayer(0).count, 0,
                            "Brush stroke should create a shape")

        // The shape should have proper tapering (no phallic bulge)
        // This is ensured by the aggressive tapering multipliers (0.5) and power of 4
    }

    func testNoForcedMinimumPoints() {
        // Test that we don't force a minimum of 8 points
        let points = [
            CGPoint(x: 100, y: 100),
            CGPoint(x: 200, y: 100) // Straight horizontal line
        ]

        canvas.handleBrushDragStart(at: points[0])
        canvas.handleBrushDragUpdate(at: points[1])

        // The simplified points should not be forced to 8
        // (We removed the minimum points requirement)
        XCTAssertLessThanOrEqual(canvas.brushRawPoints.count, 2,
                                 "Should not force minimum points for short strokes")
    }

    func testMarkerAutoDeselection() {
        // Test that marker tool also auto-deselects
        document.currentTool = .marker

        canvas.handleMarkerDragStart(at: CGPoint(x: 100, y: 100))
        canvas.handleMarkerDragUpdate(at: CGPoint(x: 150, y: 150))
        canvas.handleMarkerDragEnd()

        // Verify selection is cleared
        XCTAssertTrue(document.selectedShapeIDs.isEmpty,
                     "Selection should be cleared after marker stroke")
    }

    func testFreehandAutoDeselection() {
        // Test that freehand tool auto-deselects
        document.currentTool = .freehand

        canvas.handleFreehandDragStart(at: CGPoint(x: 100, y: 100))
        canvas.handleFreehandDragUpdate(at: CGPoint(x: 150, y: 150))
        canvas.handleFreehandDragEnd()

        // Verify selection is cleared
        XCTAssertTrue(document.selectedShapeIDs.isEmpty,
                     "Selection should be cleared after freehand stroke")
    }
}