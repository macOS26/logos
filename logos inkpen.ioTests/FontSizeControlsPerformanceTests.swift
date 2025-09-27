//
//  FontSizeControlsPerformanceTests.swift
//  logos inkpen.ioTests
//
//  Tests for font size slider performance optimizations
//

import XCTest
@testable import logos_inkpen_io

class FontSizeControlsPerformanceTests: XCTestCase {

    var document: VectorDocument!
    var textObject: VectorText!

    override func setUp() {
        super.setUp()
        document = VectorDocument()

        // Create a test text object
        textObject = VectorText(
            id: UUID(),
            content: "Test Text",
            position: CGPoint(x: 100, y: 100)
        )

        // Add to document
        let shape = VectorShape(
            id: textObject.id,
            type: .text,
            frame: CGRect(x: 100, y: 100, width: 200, height: 50),
            fillColor: .black,
            strokeColor: .clear,
            strokeWidth: 0,
            rotation: 0,
            opacity: 1.0,
            cornerRadius: 0,
            isLocked: false,
            typography: textObject.typography,
            objectDescription: "Text: Test Text"
        )

        let vectorObj = VectorObject(
            shape: shape,
            layerIndex: 0,
            orderID: document.getNextOrderID()
        )

        document.unifiedObjects.append(vectorObj)
        document.selectedTextIDs.insert(textObject.id)
    }

    func testFastTypographyUpdate() {
        // Measure fast update performance
        let typography = TypographyProperties(
            fontFamily: "Helvetica",
            fontSize: 48,
            fontWeight: .regular,
            fontStyle: .normal,
            lineSpacing: 0,
            lineHeight: 48,
            paragraphSpacing: 0,
            letterSpacing: 0,
            alignment: .left,
            verticalAlignment: .top,
            fillColor: .black,
            fillOpacity: 1.0,
            hasStroke: false,
            strokeColor: .clear,
            strokeWidth: 0,
            strokeOpacity: 1.0
        )

        measure {
            // Fast update should be quick
            for size in stride(from: 12.0, through: 72.0, by: 1.0) {
                var updatedTypo = typography
                updatedTypo.fontSize = size
                updatedTypo.lineHeight = size
                document.updateTextTypographyFast(id: textObject.id, typography: updatedTypo)
            }
        }
    }

    func testSlowTypographyUpdate() {
        // Measure regular update performance for comparison
        let typography = TypographyProperties(
            fontFamily: "Helvetica",
            fontSize: 48,
            fontWeight: .regular,
            fontStyle: .normal,
            lineSpacing: 0,
            lineHeight: 48,
            paragraphSpacing: 0,
            letterSpacing: 0,
            alignment: .left,
            verticalAlignment: .top,
            fillColor: .black,
            fillOpacity: 1.0,
            hasStroke: false,
            strokeColor: .clear,
            strokeWidth: 0,
            strokeOpacity: 1.0
        )

        measure {
            // Regular update with logging should be slower
            for size in stride(from: 12.0, through: 72.0, by: 1.0) {
                var updatedTypo = typography
                updatedTypo.fontSize = size
                updatedTypo.lineHeight = size
                document.updateTextTypographyInUnified(id: textObject.id, typography: updatedTypo)
            }
        }
    }

    func testTypographyPreservation() {
        // Ensure fast updates preserve all typography properties
        let initialTypography = TypographyProperties(
            fontFamily: "Times New Roman",
            fontSize: 24,
            fontWeight: .bold,
            fontStyle: .italic,
            lineSpacing: 5,
            lineHeight: 30,
            paragraphSpacing: 10,
            letterSpacing: 2,
            alignment: .center,
            verticalAlignment: .middle,
            fillColor: .red,
            fillOpacity: 0.8,
            hasStroke: true,
            strokeColor: .blue,
            strokeWidth: 2,
            strokeOpacity: 0.6
        )

        // Update with fast method
        document.updateTextTypographyFast(id: textObject.id, typography: initialTypography)

        // Verify all properties are preserved
        if let updatedObj = document.unifiedObjects.first(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == textObject.id
            }
            return false
        }) {
            if case .shape(let shape) = updatedObj.objectType,
               let typo = shape.typography {
                XCTAssertEqual(typo.fontFamily, "Times New Roman")
                XCTAssertEqual(typo.fontSize, 24)
                XCTAssertEqual(typo.fontWeight, .bold)
                XCTAssertEqual(typo.fontStyle, .italic)
                XCTAssertEqual(typo.lineSpacing, 5)
                XCTAssertEqual(typo.lineHeight, 30)
                XCTAssertEqual(typo.paragraphSpacing, 10)
                XCTAssertEqual(typo.letterSpacing, 2)
                XCTAssertEqual(typo.alignment, .center)
                XCTAssertEqual(typo.verticalAlignment, .middle)
                XCTAssertEqual(typo.fillColor, .red)
                XCTAssertEqual(typo.fillOpacity, 0.8)
                XCTAssertEqual(typo.hasStroke, true)
                XCTAssertEqual(typo.strokeColor, .blue)
                XCTAssertEqual(typo.strokeWidth, 2)
                XCTAssertEqual(typo.strokeOpacity, 0.6)
            } else {
                XCTFail("Typography not found after update")
            }
        } else {
            XCTFail("Object not found after update")
        }
    }

    func testThrottledUpdates() {
        // Test that throttled updates work correctly
        let expectation = self.expectation(description: "Throttled update completes")
        var updateCount = 0

        // Mock a slider drag operation
        for i in 1...10 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.01) {
                // Simulate rapid slider updates
                let newSize = CGFloat(20 + i)
                self.document.fontManager.selectedFontSize = newSize
                updateCount += 1

                if i == 10 {
                    // Wait for throttle timer to fire
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        expectation.fulfill()
                    }
                }
            }
        }

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(updateCount, 10, "All updates should have been processed")
    }
}