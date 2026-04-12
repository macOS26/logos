import XCTest
import SwiftUI
@testable import logos_inkpen_io

final class TextLivePreviewTests: XCTestCase {
    var document = VectorDocument()

    override func setUpWithError() throws {
        document = VectorDocument()
        document.width = 800
        document.height = 600
    }

    override func tearDownWithError() throws {
    }

    func testTextPreviewTypographyStorage() throws {
        let textID = UUID()
        let typography = TypographyProperties(
            fontName: "Helvetica",
            fontSize: 24,
            lineSpacing: 5,
            lineHeight: 30
        )

        let shape = VectorShape(
            path: CGPath(rect: CGRect(x: 100, y: 100, width: 200, height: 100), transform: nil),
            fillStyle: FillStyle(color: .black),
            strokeStyle: nil,
            name: "Text: Test",
            isEditable: false
        )
        shape.id = textID
        shape.isTextObject = true
        shape.textContent = "Test text"
        shape.typography = typography

        let unifiedObj = UnifiedObject(
            id: textID,
            objectType: .shape(shape),
            zIndex: 0
        )
        document.unifiedObjects.append(unifiedObj)

        document.updateTextFontSizePreview(id: textID, fontSize: 48)

        XCTAssertNotNil(document.textPreviewTypography[textID])
        XCTAssertEqual(document.textPreviewTypography[textID]?.fontSize, 48)

        document.clearTextPreviewTypography(id: textID)
        XCTAssertNil(document.textPreviewTypography[textID])
    }

    func testLineSpacingPreviewUpdate() throws {
        let textID = UUID()
        let shape = createTestTextShape(id: textID)
        let unifiedObj = UnifiedObject(
            id: textID,
            objectType: .shape(shape),
            zIndex: 0
        )
        document.unifiedObjects.append(unifiedObj)

        document.updateTextLineSpacingPreview(id: textID, lineSpacing: 10)

        XCTAssertNotNil(document.textPreviewTypography[textID])
        XCTAssertEqual(document.textPreviewTypography[textID]?.lineSpacing, 10)
    }

    func testLineHeightPreviewUpdate() throws {
        let textID = UUID()
        let shape = createTestTextShape(id: textID)
        let unifiedObj = UnifiedObject(
            id: textID,
            objectType: .shape(shape),
            zIndex: 0
        )
        document.unifiedObjects.append(unifiedObj)

        document.updateTextLineHeightPreview(id: textID, lineHeight: 36)

        XCTAssertNotNil(document.textPreviewTypography[textID])
        XCTAssertEqual(document.textPreviewTypography[textID]?.lineHeight, 36)
    }

    func testNotificationSentForPreviewUpdate() throws {
        let textID = UUID()
        let shape = createTestTextShape(id: textID)
        let unifiedObj = UnifiedObject(
            id: textID,
            objectType: .shape(shape),
            zIndex: 0
        )
        document.unifiedObjects.append(unifiedObj)

        let expectation = XCTestExpectation(description: "TextPreviewUpdate notification received")
        var receivedTextID: UUID?
        var receivedTypography: TypographyProperties?
        let observer = NotificationCenter.default.addObserver(
            forName: Notification.Name("TextPreviewUpdate"),
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo {
                receivedTextID = userInfo["textID"] as? UUID
                receivedTypography = userInfo["typography"] as? TypographyProperties
                expectation.fulfill()
            }
        }

        document.updateTextFontSizePreview(id: textID, fontSize: 36)

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(receivedTextID, textID)
        XCTAssertNotNil(receivedTypography)
        XCTAssertEqual(receivedTypography?.fontSize, 36)

        NotificationCenter.default.removeObserver(observer)
    }

    func testMultipleDocumentPreviewIndependence() throws {
        let document1 = VectorDocument()
        let document2 = VectorDocument()
        let textID1 = UUID()
        let textID2 = UUID()
        let shape1 = createTestTextShape(id: textID1)
        let shape2 = createTestTextShape(id: textID2)

        document1.unifiedObjects.append(UnifiedObject(
            id: textID1,
            objectType: .shape(shape1),
            zIndex: 0
        ))

        document2.unifiedObjects.append(UnifiedObject(
            id: textID2,
            objectType: .shape(shape2),
            zIndex: 0
        ))

        document1.updateTextFontSizePreview(id: textID1, fontSize: 48)

        document2.updateTextLineSpacingPreview(id: textID2, lineSpacing: 12)

        XCTAssertEqual(document1.textPreviewTypography[textID1]?.fontSize, 48)
        XCTAssertNil(document1.textPreviewTypography[textID2])

        XCTAssertEqual(document2.textPreviewTypography[textID2]?.lineSpacing, 12)
        XCTAssertNil(document2.textPreviewTypography[textID1])
    }

    func testTextViewCoordinatorHandlesCorrectNotification() throws {
        let textID = UUID()
        let shape = createTestTextShape(id: textID)

        document.unifiedObjects.append(UnifiedObject(
            id: textID,
            objectType: .shape(shape),
            zIndex: 0
        ))

        let vectorText = VectorText.from(shape)!
        let viewModel = ProfessionalTextViewModel(
            document: document,
            textObject: vectorText,
            textBoxFrame: CGRect(x: 0, y: 0, width: 200, height: 100),
            isEditing: false
        )

        let textView = ProfessionalUniversalTextView(
            viewModel: viewModel,
            textBoxState: .gray
        )

        XCTAssertEqual(viewModel.textObject.id, textID)

        let typography = TypographyProperties(fontSize: 72)
        NotificationCenter.default.post(
            name: Notification.Name("TextPreviewUpdate"),
            object: nil,
            userInfo: ["textID": textID, "typography": typography]
        )

        XCTAssertEqual(viewModel.textObject.id, textID)

        let otherTextID = UUID()
        NotificationCenter.default.post(
            name: Notification.Name("TextPreviewUpdate"),
            object: nil,
            userInfo: ["textID": otherTextID, "typography": typography]
        )

        XCTAssertEqual(viewModel.textObject.id, textID)
        XCTAssertNotEqual(viewModel.textObject.id, otherTextID)
    }

    func testRapidPreviewUpdatesPerformance() throws {
        let textID = UUID()
        let shape = createTestTextShape(id: textID)

        document.unifiedObjects.append(UnifiedObject(
            id: textID,
            objectType: .shape(shape),
            zIndex: 0
        ))

        self.measure {
            for size in stride(from: 12, to: 72, by: 1) {
                document.updateTextFontSizePreview(id: textID, fontSize: CGFloat(size))
            }
        }
    }

    private func createTestTextShape(id: UUID) -> VectorShape {
        let shape = VectorShape(
            path: CGPath(rect: CGRect(x: 100, y: 100, width: 200, height: 100), transform: nil),
            fillStyle: FillStyle(color: .black),
            strokeStyle: nil,
            name: "Text: Test",
            isEditable: false
        )
        shape.id = id
        shape.isTextObject = true
        shape.textContent = "Test text content"
        shape.typography = TypographyProperties(
            fontName: "Helvetica",
            fontSize: 24,
            lineSpacing: 5,
            lineHeight: 30
        )
        return shape
    }
}
