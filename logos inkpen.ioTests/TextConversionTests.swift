//
//  TextConversionTests.swift
//  logos inkpen.io
//
//  Test for text to path conversion
//

import XCTest
@testable import logos_inkpen_io

class TextConversionTests: XCTestCase {

    var document: VectorDocument!
    var textObject: VectorText!

    override func setUpWithError() throws {
        // Create a fresh document for each test
        document = VectorDocument()

        // Create a test text object
        textObject = VectorText(
            content: "Test\nMultiline\nText",
            position: CGPoint(x: 100, y: 100),
            typography: Typography(
                fontSize: 24,
                fontFamily: "Helvetica",
                fillColor: NSColor.black,
                fillOpacity: 1.0
            )
        )
        textObject.bounds = CGRect(x: 0, y: 0, width: 200, height: 100)
        textObject.areaSize = CGSize(width: 200, height: 100)
    }

    override func tearDownWithError() throws {
        document = nil
        textObject = nil
    }

    func testTextToPathConversionVerticalPosition() throws {
        // Add text to document
        document.addText(textObject)

        // Get the original Y position of the text
        let originalY = textObject.position.y
        let originalBounds = textObject.bounds

        // Select the text
        document.selectedTextIDs = [textObject.id]

        // Convert to path
        document.convertSelectedTextToOutlines()

        // Get the created shapes
        let shapes = document.unifiedObjects.compactMap { obj -> VectorShape? in
            if case .shape(let shape) = obj.objectType, !shape.isTextObject {
                return shape
            }
            return nil
        }

        XCTAssertFalse(shapes.isEmpty, "Should have created at least one shape")

        // Check that the shape bounds are at the same vertical position
        for shape in shapes {
            if let pathBounds = shape.path.bounds() {
                // The Y position should match the original text position
                // Allow small tolerance for rounding
                let tolerance: CGFloat = 1.0

                // Calculate the actual Y position from the path bounds
                let shapeY = pathBounds.minY

                // The shape should be positioned close to the original text
                XCTAssertEqual(shapeY, originalY, accuracy: tolerance,
                             "Shape Y position (\(shapeY)) should match original text Y position (\(originalY))")

                print("✅ Text Y: \(originalY), Shape Y: \(shapeY), Difference: \(abs(shapeY - originalY))")
            }
        }
    }

    func testTextToPathConversionPreservesBaseline() throws {
        // Add text to document
        document.addText(textObject)

        // Create view model to test conversion
        let viewModel = ProfessionalTextViewModel(textObject: textObject, document: document)

        // Store original text box frame
        let originalFrame = viewModel.textBoxFrame

        // Convert to path
        viewModel.convertToPath()

        // Check that line paths were created
        XCTAssertFalse(viewModel.linePaths.isEmpty, "Should have created line paths")

        // Verify each line path maintains correct vertical position
        for (index, linePath) in viewModel.linePaths.enumerated() {
            let pathBounds = linePath.boundingBoxOfPath

            print("Line \(index): Original frame Y=\(originalFrame.minY), Path Y=\(pathBounds.minY)")

            // The path should be positioned relative to the text box frame
            // with consistent vertical alignment
            XCTAssertGreaterThanOrEqual(pathBounds.minY, originalFrame.minY - 5,
                                       "Path should not jump above text frame")
            XCTAssertLessThanOrEqual(pathBounds.minY, originalFrame.maxY + 5,
                                    "Path should stay within reasonable bounds of text frame")
        }
    }

    func testMultilineTextConversion() throws {
        // Create multiline text
        let multilineText = VectorText(
            content: "First Line\nSecond Line\nThird Line",
            position: CGPoint(x: 50, y: 50),
            typography: Typography(
                fontSize: 18,
                fontFamily: "Arial",
                fillColor: NSColor.blue,
                fillOpacity: 1.0,
                lineHeight: 22,
                lineSpacing: 4
            )
        )
        multilineText.bounds = CGRect(x: 0, y: 0, width: 300, height: 150)
        multilineText.areaSize = CGSize(width: 300, height: 150)

        document.addText(multilineText)

        // Create view model
        let viewModel = ProfessionalTextViewModel(textObject: multilineText, document: document)

        // Convert to path
        viewModel.convertToPath()

        // Should create one path per line
        XCTAssertEqual(viewModel.linePaths.count, 3, "Should create 3 line paths for 3 lines of text")

        // Check that lines are properly spaced vertically
        var previousY: CGFloat?
        for (index, linePath) in viewModel.linePaths.enumerated() {
            let bounds = linePath.boundingBoxOfPath

            if let prevY = previousY {
                let spacing = bounds.minY - prevY
                print("Line \(index) spacing from previous: \(spacing)")

                // Lines should have consistent spacing based on line height
                XCTAssertGreaterThan(spacing, 0, "Lines should be spaced vertically")
            }

            previousY = bounds.maxY
        }
    }
}