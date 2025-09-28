//
//  TextLivePreviewTests.swift
//  logos inkpen.io Tests
//
//  Created by Claude on 2025/01/27.
//

import XCTest
@testable import logos_inkpen_io
import SwiftUI

final class TextLivePreviewTests: XCTestCase {

    var document: VectorDocument?

    override func setUp() {
        super.setUp()
        document = VectorDocument()

        // Add a test text object
        let text = VectorText(
            content: "Test Text",
            typography: TypographyProperties(
                fontFamily: "Helvetica",
                fontSize: 24,
                fontWeight: .regular,
                fontStyle: .normal,
                alignment: .left,
                strokeColor: .black,
                fillColor: .black
            ),
            position: CGPoint(x: 100, y: 100)
        )

        // Add to unified objects
        guard let document = document else { return }
        let shape = VectorShape.from(text)
        let unifiedObject = VectorObject(
            shape: shape,
            layerIndex: document.currentLayerIndex,
            orderID: document.unifiedObjects.count
        )
        document.unifiedObjects.append(unifiedObject)
        document.selectedTextIDs.insert(text.id)
    }

    override func tearDown() {
        document = nil
        super.tearDown()
    }

    func testLiveFontSizePreview() {
        guard let document = document else {
            XCTFail("Document not initialized")
            return
        }
        // Get initial text
        guard let textID = document.selectedTextIDs.first else {
            XCTFail("No text selected")
            return
        }

        // Test preview update
        document.updateTextFontSizePreview(id: textID, fontSize: 48)

        // Verify the font size was updated
        if let updatedObject = document.unifiedObjects.first(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == textID
            }
            return false
        }) {
            if case .shape(let shape) = updatedObject.objectType {
                XCTAssertEqual(shape.typography?.fontSize, 48, "Font size should be updated to 48")

                // Verify line height was proportionally updated
                let expectedLineHeight = 48.0 // Since initial ratio was 1:1
                XCTAssertEqual(shape.typography?.lineHeight, expectedLineHeight, "Line height should be proportionally updated")
            } else {
                XCTFail("Object is not a shape")
            }
        } else {
            XCTFail("Could not find text object after update")
        }
    }

    func testLiveLineSpacingPreview() {
        guard let textID = document.selectedTextIDs.first else {
            XCTFail("No text selected")
            return
        }

        // Test preview update
        document.updateTextLineSpacingPreview(id: textID, lineSpacing: 10)

        // Verify the line spacing was updated
        if let updatedObject = document.unifiedObjects.first(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == textID
            }
            return false
        }) {
            if case .shape(let shape) = updatedObject.objectType {
                XCTAssertEqual(shape.typography?.lineSpacing, 10, "Line spacing should be updated to 10")
            } else {
                XCTFail("Object is not a shape")
            }
        } else {
            XCTFail("Could not find text object after update")
        }
    }

    func testLiveLineHeightPreview() {
        guard let textID = document.selectedTextIDs.first else {
            XCTFail("No text selected")
            return
        }

        // Test preview update
        document.updateTextLineHeightPreview(id: textID, lineHeight: 36)

        // Verify the line height was updated
        if let updatedObject = document.unifiedObjects.first(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == textID
            }
            return false
        }) {
            if case .shape(let shape) = updatedObject.objectType {
                XCTAssertEqual(shape.typography?.lineHeight, 36, "Line height should be updated to 36")
            } else {
                XCTFail("Object is not a shape")
            }
        } else {
            XCTFail("Could not find text object after update")
        }
    }

    func testFontFamilyDirectUpdate() {
        guard let textID = document.selectedTextIDs.first else {
            XCTFail("No text selected")
            return
        }

        // Test direct font family update
        document.updateTextFontFamilyDirect(id: textID, fontFamily: "Arial")

        // Verify the font family was updated
        if let updatedObject = document.unifiedObjects.first(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == textID
            }
            return false
        }) {
            if case .shape(let shape) = updatedObject.objectType {
                XCTAssertEqual(shape.typography?.fontFamily, "Arial", "Font family should be updated to Arial")
            } else {
                XCTFail("Object is not a shape")
            }
        } else {
            XCTFail("Could not find text object after update")
        }
    }

    func testFontWeightDirectUpdate() {
        guard let textID = document.selectedTextIDs.first else {
            XCTFail("No text selected")
            return
        }

        // Test direct font weight update
        document.updateTextFontWeightDirect(id: textID, fontWeight: .bold)

        // Verify the font weight was updated
        if let updatedObject = document.unifiedObjects.first(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == textID
            }
            return false
        }) {
            if case .shape(let shape) = updatedObject.objectType {
                XCTAssertEqual(shape.typography?.fontWeight, .bold, "Font weight should be updated to bold")
            } else {
                XCTFail("Object is not a shape")
            }
        } else {
            XCTFail("Could not find text object after update")
        }
    }

    func testFontStyleDirectUpdate() {
        guard let textID = document.selectedTextIDs.first else {
            XCTFail("No text selected")
            return
        }

        // Test direct font style update
        document.updateTextFontStyleDirect(id: textID, fontStyle: .italic)

        // Verify the font style was updated
        if let updatedObject = document.unifiedObjects.first(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == textID
            }
            return false
        }) {
            if case .shape(let shape) = updatedObject.objectType {
                XCTAssertEqual(shape.typography?.fontStyle, .italic, "Font style should be updated to italic")
            } else {
                XCTFail("Object is not a shape")
            }
        } else {
            XCTFail("Could not find text object after update")
        }
    }

    func testPerformanceOfLivePreview() {
        guard let textID = document.selectedTextIDs.first else {
            XCTFail("No text selected")
            return
        }

        // Measure performance of rapid updates (simulating slider drag)
        measure {
            for size in stride(from: 12.0, through: 72.0, by: 1.0) {
                document.updateTextFontSizePreview(id: textID, fontSize: CGFloat(size))
            }
        }
    }
}